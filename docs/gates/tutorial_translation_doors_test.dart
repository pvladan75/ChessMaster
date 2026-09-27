// The doors of phase 9 of docs/PLAN-PRIPREMA.md — „Translate…" on a
// tutorial. The server's half is built and graded
// (POST /lessons/:id/translate, chess_backend/routes/lessonTranslation.js,
// chess_backend/test/lesson_translation.test.js): it answers 201 with the new
// tutorial's row, or an error sentence with 400/404/422/429/503. This gate
// holds what a trainer reaches.
//
// The contract this gate holds, and nothing else of the implementation:
//
//   lib/features/tutorial_studio/services/tutorial_translation_flow.dart
//     Future<int?> translateTutorialCopy(BuildContext context, {
//       required UserSession session,
//       required int lessonId,
//       required String? language,        // the tutorial's own, or null
//       required LessonApiService api,
//     })
//     1. a dialog: „Translate into…", one choice per TutorialLanguage the
//        tutorial is not already in (all seven when it says none), keys
//        `translate-language-<code>`, then `translate-start` /
//        `translate-cancel`; its text says the words are sent to DeepSeek;
//     2. POST /lessons/<id>/translate { language } through [api];
//     3. 201: the copy opens in the Tutorial Studio, and a message names the
//        language by its TutorialLanguage label; returns the copy's id;
//     4. anything else: the server's sentence, nothing opens, returns null.
//     A second call for a tutorial whose first is still running sends nothing.
//
//   The doors:
//     Library — a tutorial card has an IconButton with the tooltip
//       „Translate…"; after a copy is made the shelf is loaded again.
//     Studio — `tutorial-translate`, a button reading „Translate…" in the
//       Details sheet (`tutorial-details`), for both layouts. With changes not
//       saved it sends nothing and says „Save the tutorial first" — the
//       translation is made of what is saved.
//
//   Usage this month (usage_screen.dart, countedRows): `ai_translations` is
//   „Tutorials translated", `ai_translation_tokens` is „AI translation
//   writing", in tokens.

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
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_translation_flow.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/usage_screen.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/services/usage_service.dart';
import 'package:chess_app/theme/app_colors.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final _session =
    UserSession(token: 'tok', id: 1, email: 'e', name: 'N', role: 'trener');

Map<String, dynamic> _lesson({int id = 12, String? language = 'en'}) => {
      'id': id,
      'title': id == 12 ? 'The Italian Game' : 'Italienische Partie',
      'language': language,
      'position_list': [
        {
          'id': 'step-$id',
          'title': 'The first moves',
          'fen': _start,
          'pgn': '{ ${id == 12 ? 'White starts.' : 'Weiß beginnt.'} } 1. e4 *',
          'blackOrientation': false,
        },
      ],
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

class _Server {
  _Server({this.translateStatus = 201, this.language = 'en'});

  final int translateStatus;
  final String? language;
  final requests = <http.Request>[];

  late final http.Client client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path;
    if (req.method == 'POST' && path == '/lessons/12/translate') {
      if (translateStatus != 201) {
        return _json({
          'error': 'The translation could not be used, so no copy was made. '
              'It can be asked for again.',
          'reason': 'bad-translation',
        }, translateStatus);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return _json(
          {..._lesson(id: 99, language: body['language'] as String)}, 201);
    }
    if (req.method == 'GET' && path == '/lessons/99') {
      return _json(_lesson(id: 99, language: 'de'));
    }
    if (req.method == 'GET' && path == '/lessons/12') {
      return _json(_lesson(language: language));
    }
    if (path.endsWith('/library/positions')) {
      return _json({
        'items': [
          {
            'kind': 'tutorial',
            'id': '12',
            'title': 'The Italian Game',
            'fen': _start,
            'partsCount': 1,
          },
        ],
      });
    }
    if (req.method == 'GET' && path == '/lessons') {
      return _json([_lesson(language: language)]);
    }
    if (path.endsWith('/lessons/labels')) return _json(<Object>[]);
    return _json(<Object>[], 200);
  });

  List<String> get translations => [
        for (final r in requests)
          if (r.method == 'POST' && r.url.path.endsWith('/translate'))
            r.body,
      ];

  int get shelfLoads =>
      requests.where((r) => r.url.path.endsWith('/library/positions')).length;
}

Future<void> _wide(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await TutorialDraftService.instance.clear();
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpFlow(WidgetTester tester, _Server server,
    {String? language = 'en', int times = 1}) async {
  await _wide(tester);
  final api = LessonApiService(authToken: 'tok', client: server.client);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () {
            for (var i = 0; i < times; i++) {
              translateTutorialCopy(context,
                  session: _session,
                  lessonId: 12,
                  language: language,
                  api: api);
            }
          },
          child: const Text('translate'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('translate'));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _choice(String code) => find.byKey(Key('translate-language-$code'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the flow', () {
    testWidgets(
        'the languages offered are the ones the tutorial is not in, and the '
        'dialog says where the words go', (tester) async {
      final server = _Server();
      await _pumpFlow(tester, server);
      for (final code in ['sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr']) {
        expect(_choice(code), findsOneWidget, reason: code);
      }
      expect(_choice('en'), findsNothing,
          reason: 'a tutorial is not translated into its own language');
      expect(find.textContaining('DeepSeek'), findsOneWidget);
      await tester.tap(find.byKey(const Key('translate-cancel')));
      await tester.pumpAndSettle();
      expect(server.translations, isEmpty);
      await _close(tester);
    });

    testWidgets('a tutorial that says no language is offered all seven',
        (tester) async {
      final server = _Server(language: null);
      await _pumpFlow(tester, server, language: null);
      for (final code in ['en', 'sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr']) {
        expect(_choice(code), findsOneWidget, reason: code);
      }
      await _close(tester);
    });

    testWidgets(
        'a language chosen is sent, and the copy opens in the studio with the '
        'language named', (tester) async {
      final server = _Server();
      await _pumpFlow(tester, server);
      await tester.tap(_choice('de'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();

      expect(server.translations, [jsonEncode({'language': 'de'})]);
      expect(find.byType(TutorialStudioScreen), findsOneWidget);
      expect(find.textContaining('German'), findsWidgets);
      await _close(tester);
    });

    testWidgets('a refused translation says the server\'s sentence and opens '
        'nothing', (tester) async {
      final server = _Server(translateStatus: 422);
      await _pumpFlow(tester, server);
      await tester.tap(_choice('fr'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();
      expect(server.translations.length, 1);
      expect(find.byType(TutorialStudioScreen), findsNothing);
      expect(find.textContaining('no copy was made'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('two starts on one tutorial ask one question', (tester) async {
      final server = _Server();
      await _pumpFlow(tester, server, times: 2);
      // One dialog, not two stacked.
      expect(find.byKey(const Key('translate-start')), findsOneWidget);
      await tester.tap(_choice('it'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();
      expect(server.translations.length, 1);
      await _close(tester);
    });
  });

  group('the Library\'s door', () {
    testWidgets('a tutorial card translates, and the shelf is loaded again',
        (tester) async {
      await _wide(tester);
      final server = _Server();
      final client = server.client;
      AnalysisPersistenceService.setInstance(
          AnalysisPersistenceService.withClient(client));
      addTearDown(AnalysisPersistenceService.resetInstance);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
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
      final loadsBefore = server.shelfLoads;

      final door = find.descendant(
          of: find.byKey(const ValueKey('library-row-tutorial-12')),
          matching: find.byTooltip('Translate…'));
      expect(door, findsOneWidget);
      await tester.tap(door);
      await tester.pumpAndSettle();
      await tester.tap(_choice('es'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();

      expect(server.translations, [jsonEncode({'language': 'es'})]);
      expect(server.shelfLoads, greaterThan(loadsBefore),
          reason: 'the copy is on the shelf when the trainer comes back');
      await _close(tester);
    });
  });

  group('the studio\'s door', () {
    Future<_Server> openStudio(WidgetTester tester) async {
      await _wide(tester);
      final server = _Server();
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
        home: TutorialStudioScreen(
          session: _session,
          entry: TutorialEntry.saved(_lesson()),
          lessonApi: LessonApiService(authToken: 'tok', client: server.client),
        ),
      ));
      await tester.pumpAndSettle();
      return server;
    }

    testWidgets('„Translate…" is in the Details sheet and translates what is '
        'saved', (tester) async {
      final server = await openStudio(tester);
      await tester.tap(find.byKey(const Key('tutorial-details')));
      await tester.pumpAndSettle();
      final door = find.byKey(const Key('tutorial-translate'));
      expect(door, findsOneWidget);
      expect(find.descendant(of: door, matching: find.text('Translate…')),
          findsOneWidget);
      await tester.tap(door);
      await tester.pumpAndSettle();
      await tester.tap(_choice('de'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translate-start')));
      await tester.pumpAndSettle();
      expect(server.translations, [jsonEncode({'language': 'de'})]);
      await _close(tester);
    });

    testWidgets('with changes not saved it sends nothing and says why',
        (tester) async {
      final server = await openStudio(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'The Italian Game'), 'Italian, new');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tutorial-details')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tutorial-translate')));
      await tester.pumpAndSettle();
      expect(_choice('de'), findsNothing, reason: 'nothing is offered');
      expect(server.translations, isEmpty);
      expect(find.textContaining('Save the tutorial first'), findsOneWidget);
      await _close(tester);
    });
  });

  test('Usage this month names both counters', () {
    final rows = countedRows(MonthlyUsage(
      tier: 'premium',
      periodStart: DateTime.utc(2026, 9, 1),
      quotas: const {},
      metrics: const {'ai_translations': 3, 'ai_translation_tokens': 12345},
      voiceMinutes: 0,
    ));
    final said = {for (final r in rows) r.label: r.value};
    expect(said['Tutorials translated'], '3');
    expect(said['AI translation writing'], '12,345 tokens');
  });
}
