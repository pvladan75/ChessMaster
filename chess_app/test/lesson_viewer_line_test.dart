import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 2 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`, on the screen a child sees.
///
/// The dialect tests prove the parser keeps everything; this proves the viewer
/// asks it for everything. Two things could regress silently here and neither
/// would throw: a line that starts somewhere other than move one, which the old
/// reader replayed from the standard position and the screen then rejected on
/// sight, and the trainer's note, which used to be dropped whenever two parsers
/// counted the moves differently.
void main() {
  const endgameFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  /// A step whose line starts from its own position and carries a note.
  String linePgn() {
    final tree = MoveTree(startingFen: endgameFen);
    final line = MoveTree.appendLine(tree.root, ['a1a8']);
    line.end.comment = 'Top ide na osmi red i to je mat.';
    return tree.exportToPgn();
  }

  AssignmentDetail detail() => AssignmentDetail(
        assignment: const Assignment(
          id: 5,
          title: 'Mat topom',
          kind: AssignmentKind.lesson,
          totalItems: 1,
        ),
        items: const [AssignmentItem(puzzleId: null, position: 0)],
        steps: [
          LessonStep(
            title: 'Zadnji red',
            fen: endgameFen,
            pgn: linePgn(),
            instruction: 'Prati liniju.',
          ),
        ],
      );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(session: session, detail: detail()),
    ));
    await tester.pump();
  }

  testWidgets('a line that starts from the step\'s own position is replayed',
      (tester) async {
    await open(tester);

    // The move strip counts the line. Nothing to count means the PGN was
    // rejected — which is exactly what happened to every endgame step before
    // the reader was told where the line begins.
    expect(find.textContaining('/1'), findsWidgets,
        reason: 'the step\'s single move should be on the strip');
  });

  testWidgets('a line with no FEN header still starts from the step',
      (tester) async {
    // The case where `startingFen` is the only source of truth. An exported
    // PGN carries a `[FEN]` header the parser can fall back on, so it hides
    // this; a line pasted from a book, a chat message or a coaching site does
    // not, and the old reader replayed every one of them from move one — a
    // rook ending read as a queen's pawn opening, then rejected on sight.
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(
        session: session,
        detail: AssignmentDetail(
          assignment: const Assignment(
            id: 6,
            title: 'Mat topom',
            kind: AssignmentKind.lesson,
            totalItems: 1,
          ),
          items: const [AssignmentItem(puzzleId: null, position: 0)],
          steps: const [
            LessonStep(
              title: 'Zadnji red',
              fen: endgameFen,
              pgn: '1. Ra8# { Mat na osmom redu. }',
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byTooltip('Sledeći potez'));
    await tester.pump();

    expect(find.text('Mat na osmom redu.'), findsOneWidget);
  });

  testWidgets('the trainer\'s note reaches the student', (tester) async {
    await open(tester);

    // Nothing is written about the position *before* the first move, so the
    // note appears only once the student steps onto the move it belongs to.
    expect(find.text('Top ide na osmi red i to je mat.'), findsNothing);

    await tester.tap(find.byTooltip('Sledeći potez'));
    await tester.pump();

    expect(find.text('Top ide na osmi red i to je mat.'), findsOneWidget);
  });
}
