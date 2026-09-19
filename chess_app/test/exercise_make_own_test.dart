// exercise_make_own_test.dart — what `docs/gates/exercise_make_test.dart`
// cannot reach: the door in Preparation, the sheet's layout and refusals, and
// the solver playing a line through the real screen.
//
// `docs/briefs/BRIEF-EXERCISE-FAZA2B-APP.md`, „Your own tests".
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart' show loadRoboto;

/// After 1.e4 e5 — the same position `docs/gates/exercise_line_cases.json`
/// calls "scholar", so the solution below is the one both ends already agree
/// on.
const _scholar = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';

class _Recorder {
  final requests = <http.Request>[];
  Map<String, dynamic> bodyOf(int i) =>
      jsonDecode(requests[i].body) as Map<String, dynamic>;
}

MoveTree _twoMoveLineWithAlternative() {
  final tree = MoveTree.parsePgn(
    '2. Qh5 (2. Qf3) 2... g6 3. Qxe5+',
    startingFen: _scholar,
  );
  if (tree == null) throw StateError('the test\'s own PGN did not parse');
  return tree;
}

Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(body: Builder(builder: (context) => dialog)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  group('the door in Preparation', () {
    // The full studio room (`chess_game_screen.dart`) opens a live
    // Socket.IO connection on `initState`, which a widget test cannot give
    // it — so this pumps `MakeExerciseButton`, the small widget the room
    // embeds beside "Save position", rather than the whole screen (CLAUDE.md
    // rule 10: every layer can be right and a feature still unreachable).
    testWidgets('tapping "Make exercise" opens the sheet', (tester) async {
      await pumpDialog(
        tester,
        MakeExerciseButton(
          api: ExerciseApiService(
            authToken: 't',
            client: MockClient((r) async => http.Response('{}', 500)),
          ),
          moveTree: _twoMoveLineWithAlternative(),
          availableUserLabels: const [],
        ),
      );

      expect(find.byType(MakeExerciseSheet), findsNothing);
      await tester.tap(find.text('Make exercise'));
      await tester.pumpAndSettle();

      expect(find.byType(MakeExerciseSheet), findsOneWidget,
          reason: 'the door must actually open the sheet');
    });
  });

  group('the sheet', () {
    Widget sheet({http.Client? client, MoveTree? tree}) => MakeExerciseSheet(
          api: ExerciseApiService(
            authToken: 't',
            client: client ?? MockClient((r) async => http.Response('{}', 500)),
          ),
          moveTree: tree ?? _twoMoveLineWithAlternative(),
          availableUserLabels: const [],
        );

    Future<void> pumpAtSize(
        WidgetTester tester, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(body: Builder(builder: (context) => child)),
      ));
      await tester.pumpAndSettle();
    }

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'lays out with no overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpAtSize(tester, size, sheet());
        expect(tester.takeException(), isNull);

        expect(find.textContaining('Qh5'), findsOneWidget,
            reason: 'the solution text must be on screen');
        expect(find.textContaining('or Qf3'), findsOneWidget,
            reason: 'the accepted alternative is shown in brackets');

        // Save is disabled until a name is typed.
        final saveBefore = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save'));
        expect(saveBefore.onPressed, isNull);

        await tester.enterText(find.byType(TextField).first, 'Queen out early');
        await tester.pump();

        final saveAfter = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save'));
        expect(saveAfter.onPressed, isNotNull);
      });
    }

    testWidgets('an empty tree offers the way to the move, and no Save',
        (tester) async {
      await pumpDialog(
        tester,
        sheet(tree: MoveTree(startingFen: _scholar)),
      );

      // Until phase 14 this was a red refusal and a sentence about playing
      // the solution first. It leads now, and still does not save.
      expect(find.byKey(const Key('exercise-play-the-move')), findsOneWidget);
      expect(find.textContaining('at least one move'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Anything');
      await tester.pump();
      final save = tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));
      expect(save.onPressed, isNull,
          reason: 'a name typed over an empty line still must not save');
    });

    testWidgets(
        'a refusal from the server is shown, in its own words, '
        'and the sheet stays open', (tester) async {
      final rec = _Recorder();
      const serverError = 'move 1: "Qh6" cannot be played here.';
      await pumpDialog(
        tester,
        sheet(
          client: MockClient((r) async {
            rec.requests.add(r);
            return http.Response(jsonEncode({'error': serverError}), 422);
          }),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Queen out early');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(rec.requests, hasLength(1));
      expect(rec.requests.single.method, 'POST');
      expect(rec.requests.single.url.path, '/exercises');
      final body = jsonDecode(rec.requests.single.body) as Map<String, dynamic>;
      expect(body['name'], 'Queen out early');
      expect(body['fen'], _scholar);

      expect(find.text(serverError), findsOneWidget);
      expect(find.byType(MakeExerciseSheet), findsOneWidget,
          reason: 'a refusal must not close the sheet');
    });
  });

  group('the solver plays a line through the real screen', () {
    UserSession session() => UserSession(
          token: 't',
          id: 1,
          email: 's@example.com',
          name: 'Student',
          role: 'korisnik',
        );

    AssignmentDetail detail() => const AssignmentDetail(
          assignment: Assignment(id: 42, title: 'Openings'),
          items: [],
        );

    /// The queen's own square through the line: d1 → h5 (move 1), then h5 for
    /// both the wrong try and the move that finishes it — the wrong move is
    /// never actually applied to the board.
    Offset squareOn(WidgetTester tester, String square) {
      final rect = tester.getRect(find.byType(ChessBoardWithOverlay));
      return rect.topLeft +
          getSquareCenter(square, rect.width, PlayerColor.white);
    }

    Future<void> drag(WidgetTester tester, String from, String to) async {
      await tester.dragFrom(squareOn(tester, from),
          squareOn(tester, to) - squareOn(tester, from));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a right move, a wrong move, then the right move — one request per '
        'move, the wrong one changes nothing, and onAnswered fires once',
        (tester) async {
      final rec = _Recorder();
      final answered = <(String, bool)>[];

      final client = MockClient((r) async {
        rec.requests.add(r);
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final moves = (body['moves'] as List).cast<String>();
        if (moves.length == 1) {
          // 1. Qh5 — the author's move, the line goes on.
          return http.Response(
              jsonEncode({
                'correct': true,
                'reason': "the author's move",
                'playedSan': 'Qh5',
                'done': false,
                'step': 0,
                'reply': 'g6',
                'continuesOn': null,
                'retry': false,
              }),
              200);
        }
        if (moves.last == 'Qxh7') {
          // The wrong second move — a line, so it may be tried again.
          return http.Response(
              jsonEncode({
                'correct': false,
                'reason': 'That is not the move the exercise asks for.',
                'playedSan': 'Qxh7',
                'done': false,
                'step': 1,
                'retry': true,
              }),
              200);
        }
        // 2. Qxe5+ finishes the line.
        return http.Response(
            jsonEncode({
              'correct': true,
              'reason': "the author's move",
              'playedSan': 'Qxe5+',
              'done': true,
              'step': 1,
            }),
            200);
      });

      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: CustomPuzzleSolverScreen(
          session: session(),
          detail: detail(),
          positions: const [
            CustomPosition(puzzleId: 'ex_1', fen: _scholar, sideToMove: 'w'),
          ],
          startIndex: 0,
          api: AssignmentApiService(authToken: 't', client: client),
          onAnswered: (id, correct) => answered.add((id, correct)),
        ),
      ));
      await tester.pumpAndSettle();

      await drag(tester, 'd1', 'h5');
      await tester.pumpAndSettle();

      final controllerFinder = find.byType(ChessBoardWithOverlay);
      String fenNow() =>
          (tester.widget<ChessBoardWithOverlay>(controllerFinder))
              .controller
              .getFen();

      final fenBeforeWrong = fenNow();
      await drag(tester, 'h5', 'h7');
      await tester.pumpAndSettle();
      expect(fenNow(), fenBeforeWrong,
          reason: 'a wrong move must leave the board exactly as it was');

      await drag(tester, 'h5', 'e5');
      await tester.pumpAndSettle();

      expect(rec.requests, hasLength(3));
      expect((jsonDecode(rec.requests[0].body) as Map)['moves'], ['Qh5']);
      expect(
          (jsonDecode(rec.requests[1].body) as Map)['moves'], ['Qh5', 'Qxh7']);
      expect(
          (jsonDecode(rec.requests[2].body) as Map)['moves'], ['Qh5', 'Qxe5+']);

      expect(answered, [('ex_1', false)],
          reason: 'the report keeps the first verdict: the wrong move, '
              'once — not overwritten by the finish that followed it');
    });
  });
}
