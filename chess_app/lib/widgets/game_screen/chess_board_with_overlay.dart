import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow;

/// The live game board plus its arrow/blindfold/drawing overlays.
///
/// A tap while [isDrawingMode] is on can mean "start an arrow" or "finish
/// one" depending on [drawingStartSquare] — that two-step decision (and the
/// network broadcast it triggers) stays on the screen's State via
/// [onSquareTapForDrawing], since drawn arrows live on the shared move tree,
/// not in this widget.
class ChessBoardWithOverlay extends StatelessWidget {
  final ChessBoardController controller;
  final PlayerColor boardOrientation;
  final double boardSize;
  final bool isAllowedToMove;
  final bool isDrawingMode;
  final bool isBlindfoldMode;
  final String? drawingStartSquare;
  final List<ChessArrow> arrows;
  final List<EngineArrow> engineArrows;
  final void Function(String from, String to) onMove;
  final ValueChanged<String> onSquareTapForDrawing;

  const ChessBoardWithOverlay({
    super.key,
    required this.controller,
    required this.boardOrientation,
    required this.boardSize,
    required this.isAllowedToMove,
    required this.isDrawingMode,
    required this.isBlindfoldMode,
    required this.drawingStartSquare,
    required this.arrows,
    required this.engineArrows,
    required this.onMove,
    required this.onSquareTapForDrawing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !isAllowedToMove || isDrawingMode,
          child: Opacity(
            opacity: isBlindfoldMode ? 0.05 : 1.0,
            child: ChessBoard(
              controller: controller,
              boardColor: BoardColor.brown,
              boardOrientation: boardOrientation,
              size: boardSize,
              onMove: () {
                final lastMove = controller.getPossibleMoves().isEmpty
                    ? null
                    : controller.game.history.last;
                if (lastMove != null) {
                  final from = lastMove.move.fromAlgebraic;
                  final to = lastMove.move.toAlgebraic;
                  onMove(from, to);
                }
              },
            ),
          ),
        ),
        if (isBlindfoldMode)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.visibility_off, size: 56, color: Colors.amberAccent),
                      SizedBox(height: 6),
                      Text('🙈 Šah Na Slepo', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Figure su skrivene radi vežbanja vizuelizacije', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Interactive paint overlay for trainer drawing arrows
        IgnorePointer(
          ignoring: !isDrawingMode,
          child: GestureDetector(
            onTapDown: (details) {
              if (!isDrawingMode) return;
              final localPos = details.localPosition;
              final square = getSquareFromOffset(localPos, boardSize, boardOrientation);
              onSquareTapForDrawing(square);
            },
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: ChessBoardPainter(
                arrows: arrows,
                engineArrows: engineArrows,
                boardSize: boardSize,
                orientation: boardOrientation,
                highlightedSquare: drawingStartSquare,
              ),
            ),
          ),
        ),
        // Non-interactive overlay to draw arrows for both when not in drawing mode
        if (!isDrawingMode)
          IgnorePointer(
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: ChessBoardPainter(
                arrows: arrows,
                engineArrows: engineArrows,
                boardSize: boardSize,
                orientation: boardOrientation,
              ),
            ),
          ),
      ],
    );
  }
}
