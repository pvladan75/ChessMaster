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
