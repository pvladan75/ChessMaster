import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

/// One swatch in the arrow-drawing colour picker.
///
/// Takes an [ArrowColor] rather than a colour and a tooltip string, because
/// those two were typed out at each of the eight call sites and a swatch whose
/// label and colour disagree is worse than either being wrong alone.
///
/// **The letter is not decoration.** Five circles that differ only in colour are
/// five identical circles to a reader who cannot separate the hues, and the
/// tooltip only speaks on hover or a long press. The initial of the Serbian name
/// — C, N, Z, P, Lj — says which one this is without asking anybody to see a
/// colour, and the five initials are distinct, which is luck worth using.
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
  /// because `L` alone is not a letter of its own in this alphabet's reckoning
  /// and `Lj` is what the name starts with.
  static String initialOf(ArrowColor arrow) {
    final name = arrow.name;
    if (name.toLowerCase().startsWith('lj')) return 'Lj';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Unselected swatches are drawn at 40% over the panel, so the letter has to
    // read on what is actually there rather than on the full-strength colour.
    final shown = isSelected
        ? arrow.color
        : ui.Color.lerp(context.colors.surface, arrow.color, 0.4)!;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: arrow.name,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: shown,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: context.colors.textPrimary, width: 2.0)
                : Border.all(color: context.colors.border, width: 1.0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: arrow.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: Text(
            initialOf(arrow),
            style: TextStyle(
              // Off the swatch, not off the theme — the same rule as the eval
              // badge, and for the same reason: what this letter stands on is a
              // chess colour and has nothing to do with the app's surface.
              color: ChessBoardPainter.readableOn(shown),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
