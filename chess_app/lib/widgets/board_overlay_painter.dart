import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/move_tree.dart';

class EngineArrow {
  final String from;
  final String to;
  final String evalText;
  final int rank; // 1 = Best, 2 = 2nd best, 3 = 3rd best

  EngineArrow({
    required this.from,
    required this.to,
    required this.evalText,
    required this.rank,
  });
}

Offset getSquareCenter(String square, double boardSize, PlayerColor orientation) {
  if (square.length < 2) return Offset.zero;
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0 to 7
  final rank = int.parse(square[1]) - 1; // 0 to 7

  double col = file.toDouble();
  double row = 7.0 - rank.toDouble();

  if (orientation == PlayerColor.black) {
    col = 7.0 - file.toDouble();
    row = rank.toDouble();
  }

  final squareSize = boardSize / 8;
  final x = col * squareSize + squareSize / 2;
  final y = row * squareSize + squareSize / 2;

  return Offset(x, y);
}

String getSquareFromOffset(Offset localOffset, double boardSize, PlayerColor orientation) {
  final squareSize = boardSize / 8;
  int col = (localOffset.dx / squareSize).floor();
  int row = (localOffset.dy / squareSize).floor();

  if (col < 0) col = 0;
  if (col > 7) col = 7;
  if (row < 0) row = 0;
  if (row > 7) row = 7;

  int fileIndex = col;
  int rankIndex = 7 - row;

  if (orientation == PlayerColor.black) {
    fileIndex = 7 - col;
    rankIndex = row;
  }

  final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
  final rank = rankIndex + 1;

  return '$file$rank';
}

class ChessBoardPainter extends CustomPainter {
  final List<ChessArrow> arrows;
  final List<EngineArrow>? engineArrows;
  final double boardSize;
  final PlayerColor orientation;
  final String? highlightedSquare;

  ChessBoardPainter({
    required this.arrows,
    this.engineArrows,
    required this.boardSize,
    required this.orientation,
    this.highlightedSquare,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = boardSize / 8;

    // Draw highlighted starting square for drawing mode
    if (highlightedSquare != null) {
      final center = getSquareCenter(highlightedSquare!, boardSize, orientation);
      final paint = Paint()
        ..color = Colors.tealAccent.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, squareSize * 0.4, paint);
    }

    // Draw user drawn arrows
    for (final arrow in arrows) {
      _drawSingleArrow(
        canvas: canvas,
        from: arrow.from,
        to: arrow.to,
        color: _getColor(arrow.colorCode).withValues(alpha: 0.75),
        strokeWidth: 6.0,
      );
    }

    // Draw Stockfish Engine Arrows with Evaluation badges
    if (engineArrows != null) {
      for (final eArrow in engineArrows!) {
        final ui.Color color = _getEngineColor(eArrow.rank);
        final start = getSquareCenter(eArrow.from, boardSize, orientation);
        final end = getSquareCenter(eArrow.to, boardSize, orientation);

        if (start == Offset.zero || end == Offset.zero) continue;

        _drawSingleArrow(
          canvas: canvas,
          from: eArrow.from,
          to: eArrow.to,
          color: color.withValues(alpha: 0.85),
          strokeWidth: 7.0 - (eArrow.rank - 1) * 1.5,
        );

        // Draw Evaluation Badge near the target square center
        if (eArrow.evalText.isNotEmpty) {
          final textSpan = TextSpan(
            text: ' ${eArrow.evalText} ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          final badgeWidth = textPainter.width + 4;
          final badgeHeight = textPainter.height + 2;
          final badgeCenter = Offset(end.dx, end.dy - 12.0);

          final badgeRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: badgeCenter, width: badgeWidth, height: badgeHeight),
            const Radius.circular(4),
          );

          final bgPaint = Paint()
            ..color = color.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;

          final borderPaint = Paint()
            ..color = Colors.black87
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          canvas.drawRRect(badgeRect, bgPaint);
          canvas.drawRRect(badgeRect, borderPaint);
          textPainter.paint(
            canvas,
            Offset(badgeCenter.dx - textPainter.width / 2, badgeCenter.dy - textPainter.height / 2),
          );
        }
      }
    }
  }

  void _drawSingleArrow({
    required Canvas canvas,
    required String from,
    required String to,
    required ui.Color color,
    required double strokeWidth,
  }) {
    final start = getSquareCenter(from, boardSize, orientation);
    final end = getSquareCenter(to, boardSize, orientation);

    if (start == Offset.zero || end == Offset.zero) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw line
    canvas.drawLine(start, end, paint);

    // Draw arrowhead
    final dir = end - start;
    final length = dir.distance;
    if (length < 5) return;

    final u = dir / length;
    const headLength = 16.0;
    const headWidth = 10.0;

    final backPoint = end - u * headLength;
    final ortho = Offset(-u.dy, u.dx);
    final p1 = backPoint + ortho * headWidth;
    final p2 = backPoint - ortho * headWidth;

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, headPaint);
  }

  ui.Color _getColor(String code) {
    switch (code) {
      case 'R':
        return Colors.red;
      case 'G':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'O':
        return Colors.orange;
      default:
        return Colors.tealAccent;
    }
  }

  ui.Color _getEngineColor(int rank) {
    switch (rank) {
      case 1:
        return const ui.Color(0xFF00E676); // Vibrant Green
      case 2:
        return const ui.Color(0xFF00B0FF); // Vibrant Blue
      case 3:
        return const ui.Color(0xFFFF9100); // Vibrant Amber/Orange
      default:
        return Colors.purpleAccent;
    }
  }

  @override
  bool shouldRepaint(covariant ChessBoardPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.engineArrows != engineArrows ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.orientation != orientation ||
        oldDelegate.highlightedSquare != highlightedSquare;
  }
}
