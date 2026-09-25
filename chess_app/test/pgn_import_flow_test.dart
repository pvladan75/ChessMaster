// Phase 3 of `docs/PLAN-PGN-TUTORIJAL.md`: the door a game comes in through.
//
// What is *in* a file is decided by `tutorialsFromPgn`, tested where it lives.
// What is left here is the wiring: that a picked `.pgn` is read as games rather
// than as a tutorial. The offer to make questions from a reviewed game's
// mistakes went with the questions (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4).
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

  testWidgets('a reviewed game is not offered questions, and comes in whole',
      (tester) async {
    final api = _SavingApi();
    await openCard(tester, api: api, files: [
      (name: 'reviewed.pgn', text: reviewedGame),
      (name: 'plain.pgn', text: twoPlainGames),
    ]);

    expect(find.text('Make questions from the mistakes?'), findsNothing);

    // Three tutorials, every one of them a single demonstration.
    await tester.tap(find.textContaining('to the library'));
    await tester.pumpAndSettle();

    expect(api.posted, hasLength(3));
    for (final body in api.posted) {
      final parts = body['positionList'] as List;
      expect(parts, hasLength(1));
      final part = parts.single as Map;
      expect(part['kind'] ?? 'show', 'show');
      for (final field in ['instruction', 'solutionSan']) {
        expect(part.containsKey(field), isFalse, reason: field);
      }
    }
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
}
