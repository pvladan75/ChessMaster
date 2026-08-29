import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/app_radii.dart';

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

Offset getSquareCenter(
    String square, double boardSize, PlayerColor orientation) {
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

String getSquareFromOffset(
    Offset localOffset, double boardSize, PlayerColor orientation) {
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
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final ui.Color lastMoveColor;
  final ui.Color drawingModeColor;
  final ui.Color badgeTextColor;
  final ui.Color badgeBorderColor;

  ChessBoardPainter({
    required this.arrows,
    this.engineArrows,
    required this.boardSize,
    required this.orientation,
    required this.lastMoveColor,
    required this.drawingModeColor,
    required this.badgeTextColor,
    required this.badgeBorderColor,
    this.highlightedSquare,
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveBoardSize = (size.width > 0 && size.width != double.infinity)
        ? size.width
        : boardSize;
    final squareSize = effectiveBoardSize / 8;

    // Draw last move square highlights (origin & destination in glowing amber)
    if (lastMoveFrom != null && lastMoveTo != null) {
      final fromCenter =
          getSquareCenter(lastMoveFrom!, effectiveBoardSize, orientation);
      final toCenter =
          getSquareCenter(lastMoveTo!, effectiveBoardSize, orientation);

      final fillPaint = Paint()
        ..color = lastMoveColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = lastMoveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      if (fromCenter != Offset.zero) {
        final rectFrom = Rect.fromCenter(
            center: fromCenter, width: squareSize, height: squareSize);
        canvas.drawRect(rectFrom, fillPaint);
        canvas.drawRect(rectFrom, borderPaint);
      }
      if (toCenter != Offset.zero) {
        final rectTo = Rect.fromCenter(
            center: toCenter, width: squareSize, height: squareSize);
        canvas.drawRect(rectTo, fillPaint);
        canvas.drawRect(rectTo, borderPaint);
      }
    }

    // Draw highlighted starting square for drawing mode
    if (highlightedSquare != null) {
      final center =
          getSquareCenter(highlightedSquare!, effectiveBoardSize, orientation);
      final paint = Paint()
        ..color = drawingModeColor.withValues(alpha: 0.4)
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
        effectiveBoardSize: effectiveBoardSize,
      );
    }

    // Draw Stockfish Engine Arrows with Evaluation badges
    if (engineArrows != null) {
      for (final eArrow in engineArrows!) {
        final ui.Color color = _getEngineColor(eArrow.rank);
        final start =
            getSquareCenter(eArrow.from, effectiveBoardSize, orientation);
        final end = getSquareCenter(eArrow.to, effectiveBoardSize, orientation);

        if (start == Offset.zero || end == Offset.zero) continue;

        _drawSingleArrow(
          canvas: canvas,
          from: eArrow.from,
          to: eArrow.to,
          color: color.withValues(alpha: 0.85),
          strokeWidth: 7.0 - (eArrow.rank - 1) * 1.5,
          effectiveBoardSize: effectiveBoardSize,
        );

        // Draw Evaluation Badge near the target square center
        if (eArrow.evalText.isNotEmpty) {
          final textSpan = TextSpan(
            text: ' ${eArrow.evalText} ',
            style: AppText.micro.copyWith(
              color: badgeTextColor,
              fontWeight: FontWeight.bold,
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
            Rect.fromCenter(
                center: badgeCenter, width: badgeWidth, height: badgeHeight),
            const Radius.circular(AppRadii.xs),
          );

          final bgPaint = Paint()
            ..color = color.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;

          final borderPaint = Paint()
            ..color = badgeBorderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          canvas.drawRRect(badgeRect, bgPaint);
          canvas.drawRRect(badgeRect, borderPaint);
          textPainter.paint(
            canvas,
            Offset(badgeCenter.dx - textPainter.width / 2,
                badgeCenter.dy - textPainter.height / 2),
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
    required double effectiveBoardSize,
  }) {
    final startRaw = getSquareCenter(from, effectiveBoardSize, orientation);
    final endRaw = getSquareCenter(to, effectiveBoardSize, orientation);

    if (startRaw == Offset.zero || endRaw == Offset.zero) return;

    final dir = endRaw - startRaw;
    final length = dir.distance;
    if (length < 5) return;

    final u = dir / length;
    final start = startRaw + u * 10.0;
    final end = endRaw - u * 6.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw line
    canvas.drawLine(start, end, paint);

    // Draw arrowhead
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
        return const ui.Color(0xFFFF5252);
      case 'G':
        return const ui.Color(0xFF00E676);
      case 'B':
        return const ui.Color(0xFF00B0FF);
      case 'O':
        return const ui.Color(0xFFFF9100);
      case 'P':
        return const ui.Color(0xFFE040FB);
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
      case 4:
        return const ui.Color(0xFFE040FB); // Vibrant Purple
      case 5:
        return const ui.Color(0xFFFF5252); // Vibrant Red
      default:
        return Colors.tealAccent;
    }
  }

  @override
  bool shouldRepaint(covariant ChessBoardPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.engineArrows != engineArrows ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.orientation != orientation ||
        oldDelegate.highlightedSquare != highlightedSquare ||
        oldDelegate.lastMoveFrom != lastMoveFrom ||
        oldDelegate.lastMoveTo != lastMoveTo ||
        oldDelegate.lastMoveColor != lastMoveColor ||
        oldDelegate.drawingModeColor != drawingModeColor ||
        oldDelegate.badgeTextColor != badgeTextColor ||
        oldDelegate.badgeBorderColor != badgeBorderColor;
  }
}

/// A move whose visual result (piece already moved on the underlying board
/// state) needs a one-shot fly-over animation from [from] to [to] before it
/// settles. [piece] is the piece that moved, captured *before* board state
/// changed since the destination square already holds it by the time this
/// is used.
class PendingMoveAnimation {
  final String from;
  final String to;
  final chess.Piece piece;

  const PendingMoveAnimation(
      {required this.from, required this.to, required this.piece});
}

Widget pieceImageForAnimation(chess.Piece piece) {
  final isWhite = piece.color == chess.Color.WHITE;
  switch (piece.type.name) {
    case 'p':
      return isWhite ? WhitePawn() : BlackPawn();
    case 'n':
      return isWhite ? WhiteKnight() : BlackKnight();
    case 'b':
      return isWhite ? WhiteBishop() : BlackBishop();
    case 'r':
      return isWhite ? WhiteRook() : BlackRook();
    case 'q':
      return isWhite ? WhiteQueen() : BlackQueen();
    case 'k':
      return isWhite ? WhiteKing() : BlackKing();
    default:
      return isWhite ? WhitePawn() : BlackPawn();
  }
}

String _boardAssetPath(BoardColor color) {
  switch (color) {
    case BoardColor.brown:
      return 'images/brown_board.png';
    case BoardColor.darkBrown:
      return 'images/dark_brown_board.png';
    case BoardColor.green:
      return 'images/green_board.png';
    case BoardColor.orange:
      return 'images/orange_board.png';
  }
}

/// Slides a piece sprite from [pending].from to [pending].to over [duration],
/// then calls [onCompleted]. The underlying board state has already moved
/// the piece to [pending].to by the time this plays (see [PendingMoveAnimation]),
/// so left alone the real piece would sit there, fully visible, from frame
/// one — the sprite would then look like it's sliding into (and merging
/// with) a piece that's already arrived, instead of visibly delivering it.
/// A crop of the board's own square texture is layered over the destination
/// square for the duration of the slide to hide that, removed the instant
/// the sprite (and this whole widget) completes.
class AnimatedMovePiece extends StatefulWidget {
  final PendingMoveAnimation pending;
  final double boardSize;
  final PlayerColor orientation;
  final Duration duration;
  final VoidCallback onCompleted;
  final BoardColor boardColor;

  const AnimatedMovePiece({
    super.key,
    required this.pending,
    required this.boardSize,
    required this.orientation,
    required this.duration,
    required this.onCompleted,
    this.boardColor = BoardColor.brown,
  });

  @override
  State<AnimatedMovePiece> createState() => _AnimatedMovePieceState();
}

class _AnimatedMovePieceState extends State<AnimatedMovePiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final start = getSquareCenter(
        widget.pending.from, widget.boardSize, widget.orientation);
    final end = getSquareCenter(
        widget.pending.to, widget.boardSize, widget.orientation);
    _offset = Tween<Offset>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward().whenComplete(() {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final squareSize = widget.boardSize / 8;
    final destTopLeft = getSquareCenter(
            widget.pending.to, widget.boardSize, widget.orientation) -
        Offset(squareSize / 2, squareSize / 2);

    // Sized explicitly, because every child below is Positioned and a Stack
    // with no non-positioned child falls back to filling whatever its parent
    // offers. The room screen puts the board in a scrolling Column, where the
    // offered height is infinite — the Stack then failed its size.isFinite
    // assertion mid-layout, and an exception escaping layout leaves Flutter's
    // mouse tracker permanently wedged, so every later frame threw too. The
    // overlay is board-sized by definition, so it should never have been
    // asking the parent in the first place.
    return SizedBox(
      width: widget.boardSize,
      height: widget.boardSize,
      child: Stack(
        children: [
          Positioned(
            left: destTopLeft.dx,
            top: destTopLeft.dy,
            width: squareSize,
            height: squareSize,
            // The outer Positioned gives this inner Stack tight squareSize x
            // squareSize constraints, so its default hardEdge clip crops the
            // oversized, negatively-offset board image down to just this
            // square's slice — the same trick as a sprite-sheet crop.
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    left: -destTopLeft.dx,
                    top: -destTopLeft.dy,
                    width: widget.boardSize,
                    height: widget.boardSize,
                    child: Image.asset(
                      _boardAssetPath(widget.boardColor),
                      package: 'flutter_chess_board',
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _offset,
            builder: (context, child) => Positioned(
              left: _offset.value.dx - squareSize / 2,
              top: _offset.value.dy - squareSize / 2,
              width: squareSize,
              height: squareSize,
              child: IgnorePointer(child: child!),
            ),
            child: pieceImageForAnimation(widget.pending.piece),
          ),
        ],
      ),
    );
  }
}
