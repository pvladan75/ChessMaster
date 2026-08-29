import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/chess_piece_image.dart';
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

  /// The two colours the last-move brackets are drawn in.
  ///
  /// Black and white, and **not** tokens, deliberately. The one job these two
  /// have is to be the part of the marker that does not depend on the palette,
  /// on the board skin, or on the reader's colour vision — and a value that
  /// must not vary must not come from a variable. Both are achromatic, so a
  /// protanopia or deuteranopia simulation leaves them exactly where they are;
  /// there is no hue in them to lose.
  ///
  /// `board_skin_contrast_test.dart` measures them against every square of
  /// every skin and asserts the invariant this pair exists for: whichever
  /// square the marker lands on, at least one of the two still has a luminance
  /// edge on it.
  static const ui.Color lastMoveMarkerShade = ui.Color(0xFF000000);
  static const ui.Color lastMoveMarkerLight = ui.Color(0xFFFFFFFF);
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

  /// Corner brackets on a last-move square: a black halo with a white core
  /// drawn over it.
  ///
  /// This is the marker's second channel, and it was added on 29.8.2026 because
  /// the first one had been measured and did not hold. Two numbers decided the
  /// shape, neither of them a matter of taste:
  ///
  /// - The amber fill against the square beneath it measures **1.03:1** at its
  ///   worst — blue board, dark palette, light square, deuteranopia — and never
  ///   better than 1.94:1 anywhere on any skin. As a luminance signal it is not
  ///   weak, it is absent: the marker was legible only as a shift in hue, which
  ///   is the one channel a red-green deficiency takes away. Roughly one boy in
  ///   twelve has one, and the users here are children.
  /// - Black clears 4.4:1 against every square of every skin, white clears
  ///   3.0:1 against every dark one, so drawing **both** means at least one of
  ///   them has an edge whatever it lands on. That is why there are two strokes
  ///   and not one in a cleverly chosen grey.
  ///
  /// Corners rather than a thicker border, because a border competes with the
  /// square's own edge and because the shape is then a third channel on top of
  /// the second: four right angles pointing inwards look like nothing else on
  /// this board. The amber is untouched — this is added to it, not instead.
  void _paintLastMoveBrackets(Canvas canvas, Rect square) {
    final side = square.width;
    final arm = side * 0.28;
    final coreWidth = side * 0.07;
    final haloWidth = coreWidth * 2.2;
    // Inset by half the halo, so the widest stroke stays inside its own square
    // instead of bleeding onto the neighbouring one.
    final r = square.deflate(haloWidth / 2);

    final path = Path()
      ..moveTo(r.left, r.top + arm)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + arm, r.top)
      ..moveTo(r.right - arm, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + arm)
      ..moveTo(r.right, r.bottom - arm)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - arm, r.bottom)
      ..moveTo(r.left + arm, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - arm);

    canvas.drawPath(
      path,
      Paint()
        ..color = lastMoveMarkerShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloWidth
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lastMoveMarkerLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = coreWidth
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveBoardSize = (size.width > 0 && size.width != double.infinity)
        ? size.width
        : boardSize;
    final squareSize = effectiveBoardSize / 8;

    // Draw last move square highlights: an amber wash and border, plus the
    // black-and-white corner brackets that carry the same fact without using
    // colour to do it.
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
        _paintLastMoveBrackets(canvas, rectFrom);
      }
      if (toCenter != Offset.zero) {
        final rectTo = Rect.fromCenter(
            center: toCenter, width: squareSize, height: squareSize);
        canvas.drawRect(rectTo, fillPaint);
        canvas.drawRect(rectTo, borderPaint);
        _paintLastMoveBrackets(canvas, rectTo);
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

  /// The annotation palette: what an arrow code means on this board.
  ///
  /// Rule 14 -- these are chess colours, not UI tokens. A token named `accent`
  /// has no business deciding what a red arrow looks like, and none of these
  /// will ever move into `AppColorTokens`.
  ///
  /// They live here because they were typed twice. The painter drew these five
  /// while the swatch buttons in `chess_game_screen.dart` passed Material's
  /// primary family -- `Colors.green` #4CAF50 against this #00E676, `Colors.blue`
  /// #2196F3 against this #00B0FF -- so the colour you picked was not the colour
  /// you got. One definition, read by both.
  ///
  /// `P` has no button on the game screen; only G, R, B and O are offered.
  ///
  /// The key order matches the switch this replaced, deliberately: the strings
  /// gate compares literal *sequence*, not just content, so that a swapped pair
  /// of labels cannot slip through as an equal multiset. Reordering these to suit
  /// `_getEngineColor` would have tripped it for no reader-visible reason.
  static const Map<String, ui.Color> arrowPalette = {
    'R': ui.Color(0xFFFF5252),
    'G': ui.Color(0xFF00E676),
    'B': ui.Color(0xFF00B0FF),
    'O': ui.Color(0xFFFF9100),
    'P': ui.Color(0xFFE040FB),
  };

  ui.Color _getColor(String code) => arrowPalette[code] ?? Colors.tealAccent;

  /// Engine lines colour by rank, and the ranks are not in palette order --
  /// best line green, then blue, orange, purple, red. Sharing one definition
  /// with `arrowPalette` would mean naming all five codes a second time, and
  /// the swatch bug this unification fixes was on the *user's* palette, not
  /// here. Left duplicated on purpose; see the handoff.
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

/// The sprite that flies from one square to the other.
///
/// Kept as a named function rather than inlined because the animation is the
/// one place a piece is drawn without a square under it; the drawing itself is
/// the app's single piece factory, so an animated knight is the same knight
/// that lands.
Widget pieceImageForAnimation(chess.Piece piece, {PieceSkin? skin}) =>
    chessPieceWidgetFor(piece, skin: skin);

/// Slides a piece sprite from [pending].from to [pending].to over [duration],
/// then calls [onCompleted]. The underlying board state has already moved
/// the piece to [pending].to by the time this plays (see [PendingMoveAnimation]),
/// so left alone the real piece would sit there, fully visible, from frame
/// one — the sprite would then look like it's sliding into (and merging
/// with) a piece that's already arrived, instead of visibly delivering it.
/// The destination square is repainted in its own colour for the duration of
/// the slide to hide that, removed the instant the sprite (and this whole
/// widget) completes.
///
/// Until 29.8.2026 that cover was a *crop of the board image*: the whole PNG
/// positioned at negative offset inside a clipped square, sprite-sheet style.
/// It had to change when the squares stopped being an image, and a filled
/// rectangle is what a flat two-colour board wanted in the first place.
class AnimatedMovePiece extends StatefulWidget {
  final PendingMoveAnimation pending;
  final double boardSize;
  final PlayerColor orientation;
  final Duration duration;
  final VoidCallback onCompleted;

  /// Null takes the reader's chosen board, which is what every caller wants;
  /// it is a parameter at all so a test can pin a skin without a preference.
  final BoardSkin? boardSkin;

  const AnimatedMovePiece({
    super.key,
    required this.pending,
    required this.boardSize,
    required this.orientation,
    required this.duration,
    required this.onCompleted,
    this.boardSkin,
  });

  /// a1 is dark, and that is the whole rule: with a zero-based file and a
  /// one-based rank, a square is light when the two add up to an even number.
  /// Orientation does not enter into it — flipping the board moves the squares
  /// around the screen, not the colours off them.
  static bool isLightSquare(String square) {
    if (square.length < 2) return true;
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square[1]) ?? 1;
    return (file + rank) % 2 == 0;
  }

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
    final skin = widget.boardSkin ?? AppSettingsService.instance.boardSkin;
    final coverColour = AnimatedMovePiece.isLightSquare(widget.pending.to)
        ? skin.lightSquare
        : skin.darkSquare;
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
            // Opaque, and exactly one square: the piece has already arrived
            // underneath it on the real board, and this is what hides it until
            // the sprite gets there.
            child: IgnorePointer(
              child: ColoredBox(color: coverColour),
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
