// GATE — phase 2 of docs/PLAN-TUTORIJAL.md, batch B.
//
// Red until the batch it judges is done, which is why it lives in docs/ rather
// than in chess_app/test/. To run it against a worker's tree:
//
//   cp docs/gates/tutorial_branching_test.dart <worktree>/chess_app/test/
//   cd <worktree>/chess_app && flutter test test/tutorial_branching_test.dart
//
// It drives the screen through its own controls — the strip, the sheet, the
// text on the board — and never names a private field. A gate written against
// internals passes a rewrite that broke the feature, and fails a refactor that
// did not.
//
// The contract it enforces is C2 in docs/PLAN-TUTORIJAL.md.

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/speech_text.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/speech_service.dart';

void main() {
  // The opposition position the whole plan is written around: white Ke2 and a
  // pawn on d2, black Kd5. Black has two replies to 1.Kd3, and the trainer
  // wrote about both.
  const startFen = '8/8/8/3k4/8/8/3PK3/8 w - - 0 1';

  const mainNote = 'Pretpostavimo da crni kralj odigra na e5.';
  const sideNote = 'Ako crni ide na c5, beli odgovara isto — samo na drugu '
      'stranu.';

  // 1. Kd3 Ke5 (main) with 1...Kc5 as a sideline, each with its own comment and
  // its own coloured square.
  const branchingPgn = '1. Kd3 {Beli zauzima opoziciju. [%csl Gd5]} '
      'Ke5 {$mainNote [%csl Ge4]} '
      '(1... Kc5 {$sideNote [%csl Gc4]}) '
      '2. Kc4';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  AssignmentDetail lesson(List<LessonStep> steps) => AssignmentDetail(
        assignment: Assignment(
          id: 1,
          title: 'Opozicija',
          kind: AssignmentKind.lesson,
          totalItems: steps.length,
        ),
        items: [
          for (var i = 0; i < steps.length; i++)
            AssignmentItem(puzzleId: null, position: i),
        ],
        steps: steps,
      );

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  Future<void> open(WidgetTester tester, AssignmentDetail detail) async {
    await tester.pumpWidget(
        MaterialApp(home: LessonViewerScreen(session: session, detail: detail)));
    await tester.pump();
  }

  Future<void> forward(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Sledeći potez'));
    await tester.pumpAndSettle();
  }

  group('a student can reach the line the trainer prepared', () {
    testWidgets('the fork is offered, not decided', (tester) async {
      await open(
          tester,
          lesson(const [
            LessonStep(title: 'Opozicija', fen: startFen, pgn: branchingPgn),
          ]));

      await forward(tester); // 1. Kd3 — only one move, no question
      expect(find.text('Odavde ide više linija — kojom?'), findsNothing);

      await forward(tester); // the fork after 1.Kd3
      expect(find.text('Odavde ide više linija — kojom?'), findsOneWidget,
          reason: 'two replies means "forward" has two meanings');
      expect(find.text('Ke5'), findsOneWidget);
      expect(find.text('Kc5'), findsOneWidget);
    });

    testWidgets('the sideline carries its own words and its own marks',
        (tester) async {
      await open(
          tester,
          lesson(const [
            LessonStep(title: 'Opozicija', fen: startFen, pgn: branchingPgn),
          ]));

      await forward(tester);
      await forward(tester);
      await tester.tap(find.text('Kc5'));
      await tester.pumpAndSettle();

      expect(find.text(sideNote), findsOneWidget,
          reason: 'the note belongs to the move that was chosen');
      expect(find.text(mainNote), findsNothing);
      expect(board(tester).squares.map((s) => s.toString()).toList(), ['Gc4']);
    });

    testWidgets('closing the sheet leaves the board where it was',
        (tester) async {
      // Being asked and saying nothing is not the same as choosing the main
      // line. The sheet's own doc comment says so; this is the screen keeping
      // it.
      await open(
          tester,
          lesson(const [
            LessonStep(title: 'Opozicija', fen: startFen, pgn: branchingPgn),
          ]));

      await forward(tester);
      await forward(tester);
      await tester.tapAt(const Offset(20, 20)); // outside the sheet
      await tester.pumpAndSettle();

      expect(find.text(mainNote), findsNothing);
      expect(find.text(sideNote), findsNothing);
    });

    testWidgets('going back from a sideline returns to the fork',
        (tester) async {
      await open(
          tester,
          lesson(const [
            LessonStep(title: 'Opozicija', fen: startFen, pgn: branchingPgn),
          ]));

      await forward(tester);
      await forward(tester);
      await tester.tap(find.text('Kc5'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Prethodni potez'));
      await tester.pumpAndSettle();

      expect(find.text(sideNote), findsNothing);
      expect(board(tester).squares.map((s) => s.toString()).toList(), ['Gd5'],
          reason: 'back is the position after 1.Kd3, with its own mark');
    });
  });

  group('the flow that already exists is not traded away for branching', () {
    testWidgets('a step with no branches never shows the sheet',
        (tester) async {
      await open(
          tester,
          lesson(const [
            LessonStep(
              title: 'Opozicija',
              fen: startFen,
              pgn: '1. Kd3 {Jedan potez.} Ke5 2. Kc4',
            ),
          ]));

      await forward(tester);
      await forward(tester);
      await forward(tester);

      expect(find.text('Odavde ide više linija — kojom?'), findsNothing);
    });

    testWidgets('the narrated walk stops at a fork instead of choosing',
        (tester) async {
      // The rule from C2. A walk that took the main line silently would make
      // the sideline unreachable for exactly the child who is listening rather
      // than pressing — which is the child this feature is for.
      final tts = _InstantTts();
      final speech = SpeechService.forTesting(tts);
      await speech.init(enabled: true, rate: 0.5, engine: tts);
      expect(speech.state, SpeechState.ready);

      await tester.pumpWidget(MaterialApp(
        home: LessonViewerScreen(
          session: session,
          detail: lesson(const [
            LessonStep(title: 'Opozicija', fen: startFen, pgn: branchingPgn),
          ]),
          speech: speech,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byTooltip('Pročitaj mi liniju'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // It walked into 1.Kd3, said its sentence, met the fork and stopped.
      //
      // Asserted on what was **spoken**, not on what is on screen at the end: a
      // walk that ran past the fork and finished on a move with no note leaves
      // an empty comment panel, which looks exactly like a walk that stopped.
      // What it cannot hide is having read the note out on the way.
      expect(tts.spoken, isNotEmpty, reason: 'the walk did not start');
      expect(tts.spoken, isNot(contains(speakable(mainNote))),
          reason: 'the walk chose the main line instead of asking');
      expect(tts.spoken, isNot(contains(speakable(sideNote))));
      expect(find.byTooltip('Pročitaj mi liniju'), findsOneWidget,
          reason: 'the walk stopped, so the button offers to start it again');
    });
  });
}

/// A synthesiser that finishes every sentence at once. The waiting is pinned in
/// test/lesson_narration_test.dart; here the only question is where the walk
/// stops.
class _InstantTts implements TtsEngine {
  final List<String> spoken = [];

  @override
  Future<List<String>> languages() async => ['sr-RS'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
