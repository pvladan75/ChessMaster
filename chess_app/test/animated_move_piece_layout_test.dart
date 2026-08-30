import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';

/// The room screen lays the board out inside a Column in a SingleChildScrollView,
/// which offers infinite height. [AnimatedMovePiece] builds a Stack whose every
/// child is Positioned, and such a Stack sizes itself to whatever the parent
/// offers — so in that spot it used to fail `size.isFinite` during layout.
///
/// That is far worse than one bad frame: an exception escaping layout leaves
/// Flutter's MouseTracker with `_debugDuringDeviceUpdate` stuck true (there is
/// no try/finally around it), after which every pointer event and every frame
/// throws as well. The app looks frozen and the console fills with thousands of
/// assertions. Starting a lesson recording was enough to hit it.
AnimatedMovePiece _overlay({double boardSize = 400}) => AnimatedMovePiece(
      pending: PendingMoveAnimation(
        from: 'e2',
        to: 'e4',
        piece: chess.Piece(chess.PieceType.PAWN, chess.Color.WHITE),
      ),
      boardSize: boardSize,
      orientation: PlayerColor.white,
      duration: const Duration(milliseconds: 150),
      onCompleted: () {},
    );

void main() {
  testWidgets('lays out where the parent offers unbounded height',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [_overlay()],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
        tester.getSize(find.byType(AnimatedMovePiece)), const Size(400, 400));
  });

  testWidgets('takes exactly the board size, not the space on offer',
      (tester) async {
    // A parent far larger than the board must not stretch the overlay: the
    // squares it positions pieces over are computed from boardSize, so any
    // other size would put the sprite on the wrong square.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Center offers the whole screen loosely, so anything that sized
          // itself from the parent would come out screen-sized instead.
          body: Center(child: _overlay(boardSize: 320)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
        tester.getSize(find.byType(AnimatedMovePiece)), const Size(320, 320));
  });
}
