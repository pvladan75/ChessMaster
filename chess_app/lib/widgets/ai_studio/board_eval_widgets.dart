import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class SelectedSquarePainter extends CustomPainter {
  final String selectedSquare;
  final double boardSize;
  final PlayerColor orientation;

  SelectedSquarePainter({
    required this.selectedSquare,
    required this.boardSize,
    required this.orientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedSquare.isEmpty) return;
    final squareSize = boardSize / 8.0;

    final file = selectedSquare[0];
    final rank = int.parse(selectedSquare[1]);

    int col, row;
    if (orientation == PlayerColor.white) {
      col = file.codeUnitAt(0) - 'a'.codeUnitAt(0);
      row = 8 - rank;
    } else {
      col = 'h'.codeUnitAt(0) - file.codeUnitAt(0);
      row = rank - 1;
    }

    final rect = Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize);
    final borderPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SelectedSquarePainter oldDelegate) {
    return oldDelegate.selectedSquare != selectedSquare ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.orientation != orientation;
  }
}

class HorizontalEvalBarWidget extends StatelessWidget {
  final double eval;
  final String evalString;
  final int depth;
  final PlayerColor orientation;

  const HorizontalEvalBarWidget({
    super.key,
    required this.eval,
    required this.evalString,
    required this.depth,
    required this.orientation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWhiteOrientation = orientation == PlayerColor.white;
    final double clampedEval = eval.clamp(-10.0, 10.0);
    double winPct = 0.5 + (clampedEval / 20.0);
    winPct = winPct.clamp(0.05, 0.95);

    if (!isWhiteOrientation) {
      winPct = 1.0 - winPct;
    }

    String displayEvalText = evalString;
    if (!evalString.contains('M') && !evalString.contains('+') && !evalString.contains('-')) {
      final double val = double.tryParse(evalString) ?? 0.0;
      if (val > 0) displayEvalText = '+$evalString';
    }

    return Container(
      height: 18,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade700, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  flex: (winPct * 1000).round(),
                  child: Container(color: Colors.grey.shade100),
                ),
                Expanded(
                  flex: ((1.0 - winPct) * 1000).round(),
                  child: Container(color: Colors.grey.shade900),
                ),
              ],
            ),
            Center(
              child: Stack(
                children: [
                  Text(
                    displayEvalText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2.5
                        ..color = Colors.black,
                    ),
                  ),
                  Text(
                    displayEvalText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
