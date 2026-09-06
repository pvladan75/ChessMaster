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

  testWidgets('the note about the starting position is shown before move one',
      (tester) async {
    // PGN keeps this note ahead of move one rather than on a move, and the
    // viewer read it out of the parse and then showed nothing — so „pogledaj
    // polje d5", which is most of what a still step says, made it the whole way
    // here and was dropped on the last step. The arrows drawn on that same
    // position were shown all along, which is what made the gap hard to see.
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(
        session: session,
        detail: AssignmentDetail(
          assignment: const Assignment(
            id: 7,
            title: 'Mat topom',
            kind: AssignmentKind.lesson,
            totalItems: 1,
          ),
          items: const [AssignmentItem(puzzleId: null, position: 0)],
          steps: const [
            LessonStep(
              title: 'Zadnji red',
              fen: endgameFen,
              pgn:
                  '{ Crni kralj nema vazduha. } 1. Ra8# { Mat na osmom redu. }',
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Crni kralj nema vazduha.'), findsOneWidget);

    // And it belongs to the position it was written about: stepping onto the
    // move replaces it with that move's note rather than showing both.
    await tester.tap(find.byTooltip('Sledeći potez'));
    await tester.pump();

    expect(find.text('Crni kralj nema vazduha.'), findsNothing);
    expect(find.text('Mat na osmom redu.'), findsOneWidget);

    // Back to the diagram, and the note about it comes back.
    await tester.tap(find.byTooltip('Prethodni potez'));
    await tester.pump();

    expect(find.text('Crni kralj nema vazduha.'), findsOneWidget);
  });

  testWidgets('a step with no note about its position says nothing there',
      (tester) async {
    // An empty root comment must not draw an empty card.
    await open(tester);

    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });

  testWidgets('a step whose line does not replay still shows its position',
      (tester) async {
    // Steps saved before the studio checked the pair: the `pgn` was written
    // from the root of the tree and the `fen` names a position several plies
    // in, so not one move can be played. Nothing new is saved this way, but
    // what is already in the database must still open — as the still board it
    // has effectively always been.
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(
        session: session,
        detail: AssignmentDetail(
          assignment: const Assignment(
            id: 8,
            title: 'Stari korak',
            kind: AssignmentKind.lesson,
            totalItems: 1,
          ),
          items: const [AssignmentItem(puzzleId: null, position: 0)],
          steps: const [
            LessonStep(
              title: 'Zadnji red',
              fen: endgameFen,
              pgn: '1. e4 e5 2. Nf3',
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.byTooltip('Sledeći potez'), findsNothing,
        reason: 'there is no line to walk');
    expect(find.text('Zadnji red'), findsOneWidget);
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
