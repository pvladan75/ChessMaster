// Importing a tutorial written outside the app — the screen half.
//
// `readTutorialJson` decides everything about what is *in* a file
// (`tutorial_import_test.dart`), so what is left here is the two doors and the
// rule that separates them: one file is **opened, not saved** — the trainer
// presses "Save tutorial" in the studio, with every refusal that screen makes —
// and several files are written straight to the library, because opening twelve
// in an authoring screen one at a time is a chore that gets skipped.
//
// The file chooser is a platform channel and cannot run in a widget test, so
// the card takes a `pickFiles` seam, defaulted to the real one — the same shape
// `api`, `assignmentApi` and `groupApi` already have on this widget.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import_save.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';

const String _start =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const String _rook = '6k1/5pp1/7p/8/8/8/5PPP/R5K1 w - - 0 1';

/// A tutorial file with nothing wrong with it.
String cleanFile({String title = 'The opposition', String? tags}) =>
    jsonEncode({
      'title': title,
      'description': 'Generated',
      if (tags != null) 'tags': [tags],
      'positionList': [
        {
          'title': 'Deo 1',
          'fen': _start,
          'kind': 'show',
          'pgn': '{ Watch the centre. }\n1. e4 { A sentence. }\n*',
        },
        {
          'title': 'Deo 2',
          'fen': _rook,
          'kind': 'ask_move',
          'instruction': 'Find the best move.',
          'solutionSan': 'Ra8+',
        },
      ],
    });

/// One the server would refuse: the solution cannot be played.
String refusedFile() => jsonEncode({
      'title': 'Broken question',
      'positionList': [
        {'fen': _rook, 'kind': 'ask_move', 'solutionSan': 'Qe5+'},
      ],
    });

/// One that would be stored and would be wrong: two moves that do not replay.
String damagedFile() => jsonEncode({
      'title': 'Wrong line',
      'positionList': [
        {'fen': _rook, 'kind': 'show', 'pgn': '1. Nf3 { A sentence. } Nf6\n*'},
      ],
    });

/// The library, plus every tutorial it was asked to save.
class _SavingApi extends LessonApiService {
  _SavingApi._(this.posted, http.Client client)
      : super(authToken: 'tok', client: client);

  /// The decoded body of every `POST /lessons/save`.
  final List<Map<String, dynamic>> posted;

  factory _SavingApi({String? refuseTitled}) {
    final posted = <Map<String, dynamic>>[];
    return _SavingApi._(
      posted,
      MockClient((req) async {
        if (req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          posted.add(body);
          if (refuseTitled != null && body['title'] == refuseTitled) {
            return http.Response(
              jsonEncode({'error': 'The server said no.'}),
              422,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'id': 31, 'position_list': body['positionList']}),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(jsonEncode(const []), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }
}

/// The library list, for the filtering group.
class _ListApi extends LessonApiService {
  _ListApi(List<Map<String, dynamic>> rows)
      : super(
          authToken: 'tok',
          client: MockClient((req) async => http.Response(
                jsonEncode(rows),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )),
        );
}

Map<String, dynamic> row(int id, String title, List<String> tags) => {
      'id': id,
      'title': title,
      'tags': tags,
      'position_list': [
        {'id': 's$id', 'fen': _start, 'title': 'Deo 1', 'kind': 'show'},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
    debugTutorialStudioAvailable = true;
  });

  tearDown(() => debugTutorialStudioAvailable = null);

  Future<void> pump(
    WidgetTester tester, {
    required List<PickedTutorialFile> files,
    LessonApiService? api,
  }) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorialLibraryCard(
            session: session,
            api: api,
            pickFiles: () async => files,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openImport(
    WidgetTester tester, {
    required List<PickedTutorialFile> files,
    LessonApiService? api,
  }) async {
    await pump(tester, files: files, api: api);
    await tester.tap(find.byKey(const Key('import-tutorial')));
    await tester.pumpAndSettle();
  }

  TutorialEntry? openedWith(WidgetTester tester) {
    final found = find.byType(TutorialStudioScreen);
    if (found.evaluate().isEmpty) return null;
    return tester.widget<TutorialStudioScreen>(found).entry;
  }

  group('the door', () {
    testWidgets('is on the card, beside the other two', (tester) async {
      await pump(tester, files: const []);
      expect(find.text('Import from a file'), findsOneWidget);
    });

    testWidgets('is not drawn where the studio is not', (tester) async {
      // The import ends in the studio. A door to a screen that does not exist
      // on this platform is the fault this card was written to stop.
      debugTutorialStudioAvailable = false;
      await pump(tester, files: const []);
      expect(find.text('Import from a file'), findsNothing);
    });

    testWidgets('picking nothing opens nothing', (tester) async {
      await openImport(tester, files: const []);
      expect(find.text('Import tutorial'), findsNothing);
      expect(openedWith(tester), isNull);
    });
  });

  group('one file', () {
    testWidgets('is reported before anything happens to it', (tester) async {
      await openImport(tester, files: [
        (name: 'opposition.json', text: cleanFile()),
      ]);

      expect(find.text('Import tutorial'), findsOneWidget);
      expect(find.textContaining('2 parts'), findsWidgets);
      expect(find.textContaining('nothing wrong with it'), findsOneWidget);
      // Nothing has been saved, and nothing has been opened.
      expect(openedWith(tester), isNull);
    });

    testWidgets('opens in the studio, and is not saved on the way',
        (tester) async {
      final api = _SavingApi();
      await openImport(
        tester,
        files: [(name: 'opposition.json', text: cleanFile())],
        api: api,
      );
      await tester.tap(find.byKey(const Key('import-open')));
      await tester.pumpAndSettle();

      final entry = openedWith(tester);
      expect(entry, isA<TutorialEntryImported>(),
          reason: 'an imported file is not a saved tutorial and not a blank '
              'one: a `saved` entry would adopt the stored draft, and a blank '
              'one would throw the file away');

      final lesson = (entry! as TutorialEntryImported).lesson;
      expect(lesson['title'], 'The opposition');
      expect(lesson.containsKey('id'), isFalse,
          reason: 'an id would make the first save a PUT to somebody else\'s '
              'tutorial');
      expect((lesson['position_list'] as List).length, 2);

      expect(api.posted, isEmpty,
          reason: 'the file is saved by the studio, when the trainer presses '
              'its own save — importing writes nothing');
    });

    testWidgets('labels typed here travel with it', (tester) async {
      await openImport(
        tester,
        files: [(name: 'opposition.json', text: cleanFile())],
      );
      await tester.enterText(
          find.byKey(const Key('import-labels')), 'endgame, rook');
      await tester.tap(find.byKey(const Key('import-open')));
      await tester.pumpAndSettle();

      final lesson = (openedWith(tester)! as TutorialEntryImported).lesson;
      expect(lesson['tags'], ['endgame', 'rook']);
    });

    testWidgets('a broken part is named, and the file can still be opened',
        (tester) async {
      // The studio is where it gets fixed, so refusing to open it would leave
      // the trainer with a file and nothing to do about it.
      await openImport(tester, files: [
        (name: 'damaged.json', text: damagedFile()),
      ]);

      expect(find.textContaining('Part 1:'), findsOneWidget);
      expect(find.textContaining('cannot be played'), findsOneWidget);
      expect(find.byKey(const Key('import-open')), findsOneWidget);
    });

    testWidgets('a file that is not a tutorial offers no way in',
        (tester) async {
      await openImport(tester, files: [
        (name: 'photo.json', text: 'this is not json'),
      ]);

      expect(find.textContaining('not valid JSON'), findsOneWidget);
      expect(find.byKey(const Key('import-open')), findsNothing);
    });
  });

  group('several files', () {
    testWidgets('are saved in one press, with the labels', (tester) async {
      final api = _SavingApi();
      await openImport(
        tester,
        files: [
          (name: 'a.json', text: cleanFile(title: 'First')),
          (name: 'b.json', text: cleanFile(title: 'Second')),
        ],
        api: api,
      );

      expect(find.text('Save 2 to the library'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('import-labels')), 'endgame');
      await tester.tap(find.byKey(const Key('import-save')));
      await tester.pumpAndSettle();

      expect(api.posted.length, 2);
      expect(api.posted.map((b) => b['title']), ['First', 'Second']);
      for (final body in api.posted) {
        expect(body['tags'], ['endgame']);
        expect((body['positionList'] as List).length, 2);
      }
      expect(find.textContaining('2 tutorials imported'), findsOneWidget);
    });

    testWidgets('a file the server would refuse is not sent', (tester) async {
      // It would come back 422 naming a step number the trainer cannot see, and
      // the request would have been spent to learn what the report already
      // knew.
      final api = _SavingApi();
      await openImport(
        tester,
        files: [
          (name: 'good.json', text: cleanFile(title: 'Good')),
          (name: 'broken.json', text: refusedFile()),
        ],
        api: api,
      );

      expect(find.text('Save 1 to the library'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-save')));
      await tester.pumpAndSettle();

      expect(api.posted.length, 1);
      expect(api.posted.single['title'], 'Good');
    });

    testWidgets('the ones the server refuses are named, not counted',
        (tester) async {
      final api = _SavingApi(refuseTitled: 'Second');
      await openImport(
        tester,
        files: [
          (name: 'a.json', text: cleanFile(title: 'First')),
          (name: 'b.json', text: cleanFile(title: 'Second')),
        ],
        api: api,
      );
      await tester.tap(find.byKey(const Key('import-save')));
      await tester.pumpAndSettle();

      expect(find.text('Import finished'), findsOneWidget);
      expect(find.textContaining('b.json'), findsOneWidget);
      expect(find.textContaining('The server said no.'), findsOneWidget);
    });

    testWidgets('a step id in the file never reaches the server',
        (tester) async {
      // A step id resolves a schedule row and a recorded answer. The same file
      // imported twice would name the same ids twice, and a child's progress
      // would appear in the wrong copy — silently, since nothing joins on it.
      final api = _SavingApi();
      final withIds = jsonEncode({
        'title': 'Carries ids',
        'positionList': [
          {'id': 'a3f9c1d2', 'fen': _start, 'kind': 'show'},
        ],
      });
      await openImport(
        tester,
        files: [
          (name: 'a.json', text: withIds),
          (name: 'b.json', text: cleanFile(title: 'Second')),
        ],
        api: api,
      );
      await tester.tap(find.byKey(const Key('import-save')));
      await tester.pumpAndSettle();

      final steps = api.posted.first['positionList'] as List;
      expect((steps.first as Map).containsKey('id'), isFalse);
    });
  });

  group('the batch writer itself', () {
    // `saveImportedTutorials` is the rule, and the dialog only decides which
    // button to draw. A test that goes through the screen cannot see this: the
    // screen hands over the storable ones, so the guard below is never reached
    // from there — and a guard nothing reaches is a guard that stops being
    // true the day a second caller appears.
    test('a file the server would refuse is never sent', () async {
      final api = _SavingApi();
      final refused = readTutorialJson(refusedFile(), fileName: 'broken.json');
      final good =
          readTutorialJson(cleanFile(title: 'Good'), fileName: 'a.json');

      final outcomes = await saveImportedTutorials([refused, good], api);

      expect(api.posted.length, 1);
      expect(api.posted.single['title'], 'Good');
      expect(outcomes.first.saved, isFalse);
      expect(outcomes.first.error, contains('cannot be played'));
      expect(outcomes.last.saved, isTrue);
      expect(outcomes.last.lessonId, 31);
    });

    test('a file that would be stored damaged is still sent', () async {
      // The trainer was shown the fault and pressed save anyway. Refusing here
      // would be the screen and the writer disagreeing about what the button
      // said.
      final api = _SavingApi();
      final damaged = readTutorialJson(damagedFile(), fileName: 'wrong.json');
      expect(damaged.clean, isFalse);

      final outcomes = await saveImportedTutorials([damaged], api);

      expect(api.posted.length, 1);
      expect(outcomes.single.saved, isTrue);
    });
  });

  group('finding one tutorial among many', () {
    Future<void> openList(WidgetTester tester, LessonApiService api) async {
      await pump(tester, files: const [], api: api);
      await tester.tap(find.text('Saved tutorials'));
      await tester.pumpAndSettle();
    }

    testWidgets('a label filters the list, and the rows say which they carry',
        (tester) async {
      final api = _ListApi([
        row(1, 'Opposition', ['endgame']),
        row(2, 'Greek gift', ['attack']),
        row(3, 'Vancura', ['endgame', 'rook']),
      ]);
      await openList(tester, api);

      expect(find.text('endgame'), findsWidgets);
      await tester.tap(find.widgetWithText(FilterChip, 'attack'));
      await tester.pumpAndSettle();

      expect(find.text('Greek gift'), findsOneWidget);
      expect(find.text('Opposition'), findsNothing);
      expect(find.text('Vancura'), findsNothing);
    });

    testWidgets('two labels are a union rather than an intersection',
        (tester) async {
      // Most tutorials carry one label, so an intersection is empty almost
      // every time — a filter that answers "nothing" to an obvious question is
      // a filter nobody presses twice.
      final api = _ListApi([
        row(1, 'Opposition', ['endgame']),
        row(2, 'Greek gift', ['attack']),
      ]);
      await openList(tester, api);

      await tester.tap(find.widgetWithText(FilterChip, 'attack'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'endgame'));
      await tester.pumpAndSettle();

      expect(find.text('Opposition'), findsOneWidget);
      expect(find.text('Greek gift'), findsOneWidget);
    });

    testWidgets('the search box appears once there is a list to search',
        (tester) async {
      final few = _ListApi([row(1, 'Opposition', const [])]);
      await openList(tester, few);
      expect(find.byKey(const Key('tutorial-search')), findsNothing,
          reason:
              'a search box above four rows is taller than what it filters');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final many = _ListApi([
        for (var i = 1; i <= 8; i++) row(i, 'Tutorial $i', const []),
      ]);
      await openList(tester, many);
      expect(find.byKey(const Key('tutorial-search')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('tutorial-search')), 'al 7');
      await tester.pumpAndSettle();
      expect(find.text('Tutorial 7'), findsOneWidget);
      expect(find.text('Tutorial 3'), findsNothing);
    });

    testWidgets('a search that matches nothing says so', (tester) async {
      final api = _ListApi([
        for (var i = 1; i <= 8; i++) row(i, 'Tutorial $i', const []),
      ]);
      await openList(tester, api);
      await tester.enterText(
          find.byKey(const Key('tutorial-search')), 'nothing like this');
      await tester.pumpAndSettle();

      expect(find.text('No tutorial matches that.'), findsOneWidget);
    });
  });
}
