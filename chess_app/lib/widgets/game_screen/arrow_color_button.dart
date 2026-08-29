import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

/// One swatch in the arrow-drawing colour picker.
///
/// Takes an [ArrowColor] rather than a colour and a tooltip string, because
/// those two were typed out at each call site and a swatch whose label and
/// colour disagree is worse than either being wrong alone.
///
/// **The letter is not decoration.** Five circles that differ only in colour are
/// five identical circles to a reader who cannot separate the hues, and the
/// tooltip only speaks on hover or a long press. The initial of the Serbian name
/// — C, N, Z, P, Lj — says which one this is without asking anybody to see a
/// colour, and the five initials are distinct, which is luck worth using.
///
/// **The swatch is never muted, and that is a fix rather than an oversight.**
/// Until 29.8.2026 an unselected swatch was drawn at 40% over the panel, which
/// is what the original design did with `withValues(alpha: 0.4)`. Measured
/// against the dark theme's surface, that turned `Crvena` into `#782934` and
/// `Narandžasta` into `#785434` — both warm hues below the lightness floor that
/// separates orange from brown, which is the exact failure a whole round of
/// palette work had just been spent rejecting. It also collapsed the worst pair
/// from the catalogue's guaranteed 1.50:1 to 1.10:1, so the two colours a
/// dichromat has most trouble with became harder to tell apart **in the control
/// whose job is to tell them apart**. A picker that dims the thing it is
/// previewing is not previewing it. Selection is carried by the ring and the
/// glow, which is what a ring and a glow are for.
class ArrowColorButton extends StatelessWidget {
  final ArrowColor arrow;
  final bool isSelected;
  final VoidCallback onTap;

  const ArrowColorButton({
    super.key,
    required this.arrow,
    required this.isSelected,
    required this.onTap,
  });

  /// The initial a Serbian reader would use. `Ljubičasta` needs two letters,
  /// because `Lj` is a letter of its own here and is what the name starts with.
  static String initialOf(ArrowColor arrow) {
    final name = arrow.name;
    if (name.toLowerCase().startsWith('lj')) return 'Lj';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Filled in whichever of black and white reads better on this colour, and
    // outlined in the other. Red is why: `#FF2929` is mid-toned, so black
    // reaches 3.49:1 on it and white less, and neither clears 4.5:1. The same
    // answer as the engine's eval badge and as the arrows themselves — when one
    // colour cannot carry it, use two and let their own edge do the work.
    final fill = ChessBoardPainter.readableOn(arrow.color);
    final outline = fill == const Color(0xFF000000)
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    const base = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      height: 1.0,
    );

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: arrow.name,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: arrow.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? context.colors.textPrimary
                  : context.colors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: arrow.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                initialOf(arrow),
                style: base.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.0
                    ..strokeJoin = StrokeJoin.round
                    ..color = outline,
                ),
              ),
              Text(initialOf(arrow), style: base.copyWith(color: fill)),
            ],
          ),
        ),
      ),
    );
  }
}
