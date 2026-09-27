// Extra coverage for phase 9 of `docs/PLAN-PRIPREMA.md` — „Translate…" on a
// tutorial — beyond what `test/tutorial_translation_doors_test.dart` (the
// frozen gate) asks. Four cases the brief names on its own:
//
//   1. `LessonApiService.translateTutorial` on its own: 201 answers the row,
//      422 and a network failure both answer a sentence, and neither call
//      throws.
//   2. The guard against a second start is released after a refusal, not only
//      after a success — a second, later translation of the same tutorial
//      still sends its request.
//   3. The language dialog at 360 x 640: every offered language is on screen
//      and „Translate" is reachable.
//   4. The Library's door is absent from a tutorial shared by a trainer.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_translation_flow.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final _session =
    UserSession(token: 'tok', id: 1, email: 'e', name: 'N', role: 'trener');

Map<String, dynamic> _lesson({int id = 21, String? language = 'en'}) => {
      'id': id,
      'title': 'A tutorial',
      'language': language,
      'position_list': [
        {
          'id': 'step-$id',
          'title': 'First',
          'fen': _start,
          'pgn': '1. e4 *',
          'blackOrientation': false,
        },
      ],
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LessonApiService.translateTutorial', () {
    test('201 answers the new tutorial\'s row', () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/lessons/21/translate');
        expect(jsonDecode(req.body), {'language': 'de'});
        return _json(_lesson(id: 99, language: 'de'), 201);
      });
      final api = LessonApiService(authToken: 'tok', client: client);
      final result = await api.translateTutorial(lessonId: 21, language: 'de');
      expect(result.ok, isTrue);
      expect(result.id, 99);
      expect(result.language, 'de');
    });

    test('422 answers the server\'s sentence rather than throwing', () async {
      final client = MockClient((req) async => _json({
            'error': 'The translation could not be used, so no copy was '
                'made. It can be asked for again.',
            'reason': 'bad-translation',
          }, 422));
      final api = LessonApiService(authToken: 'tok', client: client);
      final result = await api.translateTutorial(lessonId: 21, language: 'de');
      expect(result.ok, isFalse);
      expect(result.error, contains('no copy was made'));
    });

    test(
        'a network failure answers a sentence of the app\'s, and does not '
        'throw', () async {
      final client = MockClient((req) async => throw Exception('offline'));
      final api = LessonApiService(authToken: 'tok', client: client);
      final result = await api.translateTutorial(lessonId: 21, language: 'de');
      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('the guard after a refusal', () {
    testWidgets(
        'a refused translation is followed by a second request for the same '
        'tutorial', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await TutorialDraftService.instance.clear();
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var translateCalls = 0;
      final client = MockClient((req) async {
        if (req.method == 'POST' && req.url.path == '/lessons/21/translate') {
          translateCalls++;
          if (translateCalls == 1) {
            return _json(
                {'error': 'Refused.', 'reason': 'bad-translation'}, 422);
          }
          return _json(_lesson(id: 88, language: 'de'), 201);
        }
        if (req.method == 'GET' && req.url.path == '/lessons/88') {
          return _json(_lesson(id: 88, language: 'de'));
        }
        return _json(<Object>[], 200);
      });
      final api = LessonApiService(authToken: 'tok', client: client);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => translateTutorialCopy(context,
                  session: _session, lessonId: 21, language: 'en', api: api),
              child: const Text('translate'),
            ),
          ),
        ),
      ));

      // First run: refused.
      await tester.tap(find.text('translate'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-language-de')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();
      expect(translateCalls, 1);

      // Second run, on the same tutorial: the guard let it through.
      await tester.tap(find.text('translate'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('translate-language-de')), findsOneWidget,
          reason: 'a second translation of this tutorial must be askable');
      await tester.tap(find.byKey(const Key('translate-language-de')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();
      expect(translateCalls, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('the dialog on a phone', () {
    testWidgets(
        'every offered language is on screen and „Translate" is reachable '
        'at 360 x 640', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await TutorialDraftService.instance.clear();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockClient((req) async => _json(<Object>[], 200));
      final api = LessonApiService(authToken: 'tok', client: client);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => translateTutorialCopy(context,
                  session: _session, lessonId: 21, language: 'en', api: api),
              child: const Text('translate'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('translate'));
      await tester.pumpAndSettle();

      for (final code in ['sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr']) {
        expect(find.byKey(Key('translate-language-$code')), findsOneWidget,
            reason: code);
      }
      await tester.tap(find.byKey(const Key('translate-language-de')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('translate-start')))
              .enabled,
          isTrue);
      await tester.ensureVisible(find.byKey(const Key('translate-start')));
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('the Library door and a trainer\'s tutorial', () {
    testWidgets('a tutorial shared by a trainer has no „Translate…"',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await TutorialDraftService.instance.clear();
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/library/positions')) {
          return _json({
            'items': [
              {
                'kind': 'tutorial',
                'id': '21',
                'title': 'A tutorial',
                'fen': _start,
                'partsCount': 1,
                'fromTrainer': true,
              },
            ],
          });
        }
        if (req.method == 'GET' && path == '/lessons') {
          return _json([_lesson()]);
        }
        if (path.endsWith('/lessons/labels')) return _json(<Object>[]);
        return _json(<Object>[], 200);
      });
      AnalysisPersistenceService.setInstance(
          AnalysisPersistenceService.withClient(client));
      addTearDown(AnalysisPersistenceService.resetInstance);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: LibraryScreen(
          session: _session,
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
          recordingApi: LessonRecordingApi(authToken: 'tok', client: client),
          scannerApi: ScannerApiService(authToken: 'tok', client: client),
          client: client,
        ),
      ));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('library-row-tutorial-21'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.byTooltip('Translate…')),
          findsNothing);
    });
  });
}
