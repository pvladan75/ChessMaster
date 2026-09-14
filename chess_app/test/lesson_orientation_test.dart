import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which way round a child opens a tutorial's part.
///
/// Reported live on 7.9.2026: the board turned over between parts of one
/// tutorial, because the viewer worked the orientation out from whose turn it
/// was and the trainer's own choice never left the studio — `toJson` did not
/// carry it. Three states, and the third is the reason the field is nullable:
/// a step written before this existed says nothing, and for those the side to
/// move is still the best guess there is.
void main() {
  const whiteToMove = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const blackToMove = '6k1/5ppp/8/8/8/8/5PPP/R5K1 b - - 0 1';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  AssignmentDetail detailOf(LessonStep step) => AssignmentDetail(
        assignment: const Assignment(
          id: 5,
          title: 'Mat topom',
          kind: AssignmentKind.lesson,
          totalItems: 1,
        ),
        items: const [AssignmentItem(puzzleId: null, position: 0)],
        steps: [step],
      );

  Future<PlayerColor> orientationOf(
      WidgetTester tester, LessonStep step) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(session: session, detail: detailOf(step)),
    ));
    await tester.pump();
    return tester
        .widget<BoardWithCoordinates>(find.byType(BoardWithCoordinates).first)
        .orientation;
  }

  testWidgets('the trainer\'s choice decides, not whose turn it is',
      (tester) async {
    // A white-to-move position a trainer deliberately left the black way
    // round — the whole point of storing the field.
    expect(
      await orientationOf(
        tester,
        const LessonStep(
          title: 'Deo 1',
          fen: whiteToMove,
          blackOrientation: true,
        ),
      ),
      PlayerColor.black,
    );
  });

  testWidgets('and „false" is a decision too, not a missing field',
      (tester) async {
    // The case a computed orientation gets wrong in the other direction: a
    // black-to-move position shown from White's side on purpose.
    expect(
      await orientationOf(
        tester,
        const LessonStep(
          title: 'Deo 1',
          fen: blackToMove,
          blackOrientation: false,
        ),
      ),
      PlayerColor.white,
    );
  });

  testWidgets('a step written before the field existed still guesses',
      (tester) async {
    expect(
      await orientationOf(
        tester,
        const LessonStep(title: 'Deo 1', fen: blackToMove),
      ),
      PlayerColor.black,
      reason: 'nothing says, so the side to move is the best guess there is',
    );
  });

  group('across parts', () {
    // A knight move, so no en passant square: `samePosition` compares that
    // field, and a pawn's double step would make the join no join at all.
    const afterNf3 =
        'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1';

    AssignmentDetail twoParts(bool? second) => AssignmentDetail(
          assignment: const Assignment(
            id: 6,
            title: 'Dva dela',
            kind: AssignmentKind.lesson,
            totalItems: 2,
          ),
          items: const [
            AssignmentItem(puzzleId: null, position: 0),
            AssignmentItem(puzzleId: null, position: 1),
          ],
          steps: [
            const LessonStep(
              title: 'Deo 1',
              fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
              pgn: '1. Nf3',
              blackOrientation: false,
            ),
            LessonStep(title: 'Deo 2', fen: afterNf3, blackOrientation: second),
          ],
        );

    PlayerColor shown(WidgetTester tester) => tester
        .widget<BoardWithCoordinates>(find.byType(BoardWithCoordinates).first)
        .orientation;

    Future<void> step(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('a part that says which way it faces is obeyed at a join',
        (tester) async {
      // Part 2 stands on the position part 1 ends on. That join used to keep
      // the board as it was, whatever part 2 said — so a part the trainer set
      // to face Black in „Preview tutorial" would never have shown it.
      await tester.pumpWidget(MaterialApp(
        home: LessonViewerScreen(session: session, detail: twoParts(true)),
      ));
      await tester.pump();
      expect(shown(tester), PlayerColor.white);
      // To the end of part 1's line, which is where part 2 stands: a join.
      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();

      await step(tester, 'Next part');

      expect(shown(tester), PlayerColor.black);
    });

    testWidgets('a student turning the board is a look, not a setting',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LessonViewerScreen(session: session, detail: twoParts(false)),
      ));
      await tester.pump();

      expect(find.byKey(const Key('preview-flip-part')), findsNothing,
          reason: 'only the studio\'s preview sets a part');
      await tester.tap(find.byTooltip('Flip board'));
      await tester.pumpAndSettle();
      expect(shown(tester), PlayerColor.black);

      await step(tester, 'Next part');
      await step(tester, 'Previous part');

      expect(shown(tester), PlayerColor.white);
    });
  });

  test('the wire carries all three states', () {
    expect(
      LessonStep.fromJson({'fen': whiteToMove, 'blackOrientation': true})
          .blackOrientation,
      isTrue,
    );
    expect(
      LessonStep.fromJson({'fen': whiteToMove, 'blackOrientation': false})
          .blackOrientation,
      isFalse,
    );
    expect(
      LessonStep.fromJson({'fen': whiteToMove}).blackOrientation,
      isNull,
      reason: 'absent must not read as false — false is a trainer speaking',
    );
  });
}
