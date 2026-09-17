// Phase 3 of `docs/PLAN-PGN-TUTORIJAL.md`: the door a game comes in through.
//
// What is *in* a file is decided by `tutorialsFromPgn` and the questions by
// `sectionsWithQuestions`, both tested where they live. What is left here is
// the wiring: that a picked `.pgn` is read as games rather than as a tutorial,
// that the question about the mistakes is asked only when there is something to
// ask, and that saying no leaves the games as they were.
//
// The file chooser is a platform channel, so the card's `pickFiles` seam stands
// in for it — the same shape every other seam on this widget has.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';

/// A reviewed game: one blunder, with the engine's move beside it.
const String reviewedGame = '''
[Event "Analysis Studio Session"]
[Site "Chess trainer"]
[Date "2026.09.12"]
[White "Player"]
[Black "Analysis Engine"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? (3... Bc5! { Better move } 4. O-O) 4. Nxe5 Qg5 *
''';

/// Two games in one file, neither carrying a mark.
const String twoPlainGames = '''
[Event "Rated blitz game"]
[White "pvladan"]
[Black "Someone"]
[Result "1-0"]

1. e4 e5 2. Nf3 1-0

[Event "Rated blitz game"]
[White "Someone"]
[Black "pvladan"]
[Result "0-1"]

1. d4 d5 2. c4 0-1
''';

String tutorialJson() => jsonEncode({
      'title': 'Written outside the app',
      'positionList': [
        {
          'title': 'Part 1',
          'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'kind': 'show',
          'pgn': '1. e4 { A sentence about the centre. }\n*',
        },
      ],
    });

/// Records every `POST /lessons/save`.
class _SavingApi extends LessonApiService {
  _SavingApi._(this.posted, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> posted;

  factory _SavingApi() {
    final posted = <Map<String, dynamic>>[];
    return _SavingApi._(
      posted,
      MockClient((req) async {
        if (req.method == 'POST') {
          posted.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'id': 31}), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response(jsonEncode(const []), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }
}

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
  });

  Future<void> openCard(
    WidgetTester tester, {
    required List<PickedTutorialFile> files,
    LessonApiService? api,
  }) async {
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
    await tester.tap(find.byKey(const Key('import-tutorial')));
    await tester.pumpAndSettle();
  }

  testWidgets('a .pgn with two games is read as two tutorials', (tester) async {
    await openCard(tester, files: [
      (name: 'my-games.pgn', text: twoPlainGames),
    ]);

    // The report names what was read; two games are two rows, because one
    // tutorial per game is what „import my games" means.
    expect(find.textContaining('pvladan - Someone'), findsOneWidget);
    expect(find.textContaining('Someone - pvladan'), findsOneWidget);
  });

  testWidgets('a game with no marks is never asked about', (tester) async {
    await openCard(tester, files: [
      (name: 'my-games.pgn', text: twoPlainGames),
    ]);

    expect(find.text('Make questions from the mistakes?'), findsNothing,
        reason: 'an ordinary import must not meet a question about questions');
  });

  testWidgets('a JSON tutorial still goes the way it always did',
      (tester) async {
    await openCard(tester, files: [
      (name: 'written.json', text: tutorialJson()),
    ]);

    expect(find.text('Make questions from the mistakes?'), findsNothing);
    expect(find.textContaining('Written outside the app'), findsOneWidget);
  });

  testWidgets('a reviewed game is offered questions, and no is honoured',
      (tester) async {
    final api = _SavingApi();
    await openCard(tester, api: api, files: [
      (name: 'reviewed.pgn', text: reviewedGame),
      (name: 'plain.pgn', text: twoPlainGames),
    ]);

    expect(find.text('Make questions from the mistakes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-no-questions')));
    await tester.pumpAndSettle();

    // Three tutorials, every one of them a single demonstration.
    await tester.tap(find.textContaining('to the library'));
    await tester.pumpAndSettle();

    expect(api.posted, hasLength(3));
    for (final body in api.posted) {
      final parts = body['positionList'] as List;
      expect(parts, hasLength(1));
      expect((parts.single as Map)['kind'], 'show');
    }
  });

  testWidgets('saying yes cuts the question in', (tester) async {
    final api = _SavingApi();
    await openCard(tester, api: api, files: [
      (name: 'reviewed.pgn', text: reviewedGame),
      (name: 'plain.pgn', text: twoPlainGames),
    ]);

    await tester.tap(find.byKey(const Key('import-make-questions')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('to the library'));
    await tester.pumpAndSettle();

    expect(api.posted, hasLength(3));
    final kinds = [
      for (final body in api.posted)
        for (final part in body['positionList'] as List)
          (part as Map)['kind'] as String,
    ];
    expect(kinds.where((k) => k == 'ask_move'), hasLength(1));

    // And the answer is the engine's move, not the one that was played.
    final question = api.posted
        .expand((b) => b['positionList'] as List)
        .cast<Map>()
        .firstWhere((p) => p['kind'] == 'ask_move');
    expect(question['solutionSan'], 'Bc5');

    // The games with nothing marked in them are untouched by the choice.
    final plain = api.posted.where((b) =>
        (b['positionList'] as List).every((p) => (p as Map)['kind'] == 'show'));
    expect(plain, hasLength(2));
  });

  testWidgets('a tutorial that already asks something is not offered questions',
      (tester) async {
    // Found by the existing import tests, not by these: counting every
    // `ask_move` in the split's result counted the questions a file already
    // had, so a hand-written tutorial with a question in it was offered
    // „make questions from the mistakes" over a file with no mistakes marked
    // anywhere — and the report behind that dialog never opened.
    final withQuestion = jsonEncode({
      'title': 'Already asks',
      'positionList': [
        {
          'title': 'Part 1',
          'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'kind': 'show',
          'pgn': '1. e4 { A sentence about the centre. }\n*',
        },
        {
          'title': 'Part 2',
          'fen': '6k1/5pp1/7p/8/8/8/5PPP/R5K1 w - - 0 1',
          'kind': 'ask_move',
          'instruction': 'Find the move that wins.',
          'solutionSan': 'Ra8+',
        },
      ],
    });

    await openCard(tester, files: [(name: 'asks.json', text: withQuestion)]);

    expect(find.text('Make questions from the mistakes?'), findsNothing);
    expect(find.textContaining('Already asks'), findsOneWidget);
  });

  testWidgets('a broken .json is judged as JSON, not as a game',
      (tester) async {
    // The extension is taken at its word here: a trainer who picked a `.json`
    // and gets „there are no moves in this game" has been told about the wrong
    // reader.
    await openCard(tester,
        files: [(name: 'broken.json', text: 'this is not a tutorial')]);

    expect(find.textContaining('not valid JSON'), findsOneWidget);
  });

  testWidgets('the question dialog fits a 360 dp phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openCard(tester, files: [
      (name: 'reviewed.pgn', text: reviewedGame),
    ]);

    // Reachable rather than merely present: a release build paints no overflow
    // stripes, it clips, and a button past the edge cannot be pressed.
    await tester.tap(find.byKey(const Key('import-make-questions')));
    await tester.pumpAndSettle();
    expect(find.text('Make questions from the mistakes?'), findsNothing);
  });
}
