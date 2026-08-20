import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lesson step can carry a task — "Beli matira u jednom potezu" — ever since
/// scanned positions could be put into lessons. The board was locked, so the
/// step asked for a move the screen would not accept.
///
/// Found live, by the student, in these words: "ovde ne mogu da pomeram figure,
/// samo mogu da gledam pozicije".
void main() {
  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  AssignmentDetail lessonDetail() => AssignmentDetail(
        assignment: const Assignment(
          id: 5,
          title: 'Lekcija broj 5',
          kind: AssignmentKind.lesson,
          totalItems: 1,
        ),
        items: const [AssignmentItem(puzzleId: null, position: 0)],
        steps: const [
          LessonStep(
            title: '23.pdf #151',
            fen: '4k3/8/4K3/8/3Q4/8/8/8 w - - 0 1',
            instruction: 'Beli matira u jednom potezu.',
          ),
        ],
      );

  testWidgets('a lesson board accepts moves, so a task can be tried',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(session: session, detail: lessonDetail()),
    ));
    await tester.pump();

    final board = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

    expect(board.isAllowedToMove, isTrue,
        reason: 'a step that asks for a move must let one be played');
  });

  testWidgets('the task is still shown above the board', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(session: session, detail: lessonDetail()),
    ));
    await tester.pump();

    expect(find.text('Beli matira u jednom potezu.'), findsOneWidget);
  });

  testWidgets('nothing offers to restore an untouched board', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(session: session, detail: lessonDetail()),
    ));
    await tester.pump();

    // The button appears only once pieces have actually moved; standing there
    // from the start would suggest something is wrong with the position.
    expect(find.text('Vrati poziciju'), findsNothing);
  });
}
