// lesson_viewer_layout_test.dart — where the words go, and what they may move.
//
// The owner's report, 9.9.2026: „pri reprodukciji tutorijala tekst komentara se
// nalazi negde između table i navigacije, što stalno pomera navigaciju." Every
// step with a longer sentence put the strip somewhere else, and a child who had
// just learned where „next" lives had to find it again.
//
// Two layouts answer it, and this file is the gate for both. Wide enough, the
// words go **beside** the board, which is also what the exported video does
// since the same day. Otherwise the strip goes directly under the board and the
// words below *it* — so the thing that grows is the last thing on the screen
// and it pushes nothing.
//
// Positions are measured rather than described: „the strip is above the
// comment" is a claim about pixels, and a test that only asks whether both are
// present passes either arrangement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

void main() {
  const startFen = '8/8/8/3k4/8/8/3PK3/8 w - - 0 1';

  // Long on purpose: a short note fits anywhere, and the report was about what
  // happens when it does not.
  const note = 'Beli zauzima opoziciju i time uzima crnom kralju sva polja '
      'ispred pešaka, pa crni mora da se skloni u stranu i pusti belog da '
      'napreduje sa svojim pešakom prema polju promocije.';
  const pgn = '1. Kd3 {$note [%csl Gd5]} Ke5 2. Kc4';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  AssignmentDetail lesson() => AssignmentDetail(
        assignment: Assignment(
          id: 1,
          title: 'Opozicija',
          kind: AssignmentKind.lesson,
          totalItems: 1,
        ),
        items: const [AssignmentItem(puzzleId: null, position: 0)],
        steps: const [
          LessonStep(title: 'Opozicija', fen: startFen, pgn: pgn),
        ],
      );

  Future<void> openAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LessonViewerScreen(session: session, detail: lesson())));
    await tester.pump();
  }

  /// Forward once, so there is a move behind us and a comment to draw.
  Future<void> forward(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
  }

  Rect boardRect(WidgetTester tester) =>
      tester.getRect(find.byType(ChessBoardWithOverlay).first);

  Rect stripRect(WidgetTester tester) =>
      tester.getRect(find.byTooltip('Next move'));

  Rect commentRect(WidgetTester tester) => tester.getRect(find.text(note));

  testWidgets('on a wide window the words are beside the board',
      (tester) async {
    await openAt(tester, const Size(1400, 900));
    await forward(tester);

    final board = boardRect(tester);
    final comment = commentRect(tester);

    expect(comment.left, greaterThan(board.right),
        reason: 'the sentence starts to the right of the board');
    expect(comment.top, lessThan(board.bottom),
        reason: 'and beside it rather than under it');
  });

  testWidgets('on a phone the strip sits under the board, above the words',
      (tester) async {
    // The report's own case. The strip is directly under the board, so the
    // sentence below it can be any length without moving anything a child has
    // learned the position of.
    await openAt(tester, const Size(400, 900));
    await forward(tester);

    final board = boardRect(tester);
    final strip = stripRect(tester);
    final comment = commentRect(tester);

    expect(strip.top, greaterThan(board.bottom - 1),
        reason: 'the strip is below the board');
    expect(strip.bottom, lessThan(comment.top),
        reason: 'and above the sentence, which is what stops it moving');
    expect(strip.top - board.bottom, lessThan(80),
        reason: 'directly under it, not somewhere further down the page');
  });

  testWidgets('a longer sentence does not move the strip', (tester) async {
    // The measurement the report is really about. Two steps, one with a short
    // note and one with a long one: the strip must be in the same place on both.
    const short = 'Kratko.';
    final detail = AssignmentDetail(
      assignment: Assignment(
        id: 1,
        title: 'Opozicija',
        kind: AssignmentKind.lesson,
        totalItems: 2,
      ),
      items: const [
        AssignmentItem(puzzleId: null, position: 0),
        AssignmentItem(puzzleId: null, position: 1),
      ],
      steps: const [
        LessonStep(
            title: 'Kratak', fen: startFen, pgn: '1. Kd3 {$short} Ke5 2. Kc4'),
        LessonStep(title: 'Dug', fen: startFen, pgn: pgn),
      ],
    );

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LessonViewerScreen(session: session, detail: detail)));
    await tester.pump();

    await forward(tester);
    final onShort = stripRect(tester);
    expect(find.text(short), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next part'));
    await tester.pumpAndSettle();
    await forward(tester);
    final onLong = stripRect(tester);
    expect(find.text(note), findsOneWidget, reason: 'the long step is showing');

    expect(onLong.top, closeTo(onShort.top, 1),
        reason: 'the strip is in the same place whatever the step says');
  });
}
