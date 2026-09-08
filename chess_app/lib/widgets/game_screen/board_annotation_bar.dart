import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/game_screen/arrow_color_button.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';

/// The annotation bar under the board in the tutorial studio.
///
/// Holds the drawing controls: arrow toggle, square toggle, the swatches in
/// [ArrowColor.all], and the clear button.
///
/// Stateless: reports every action through callbacks and owns nothing. The
/// screen owns the [BoardAnnotationController].
class BoardAnnotationBar extends StatelessWidget {
  const BoardAnnotationBar({
    super.key,
    required this.mode,
    required this.selectedColorCode,
    required this.onArrowPressed,
    required this.onSquarePressed,
    required this.onColorSelected,
    required this.onClearPressed,
  });

  final AnnotationMode mode;
  final String selectedColorCode;
  final VoidCallback onArrowPressed;
  final VoidCallback onSquarePressed;
  final ValueChanged<String> onColorSelected;
  final VoidCallback onClearPressed;

  /// The style of a mode button, written as two whole styles rather than as
  /// one style made of ternaries.
  ///
  /// The pairing is the point: on the accent ground the foreground is
  /// `canvas`, and off it the foreground is `textPrimary` on the surface. Both
  /// are right, and the ternary version said so too — but it said it in four
  /// separate conditions, and anything reading this file (the contrast gate
  /// included) has to pair `background ? a : null` with `foreground ? b : c`
  /// by understanding that the two conditions are the same one. Written out,
  /// each branch carries its own pair and there is nothing to infer.
  ButtonStyle _modeStyle(BuildContext context, {required bool active}) {
    if (active) {
      return OutlinedButton.styleFrom(
        backgroundColor: context.colors.accent,
        foregroundColor: context.colors.canvas,
        side: BorderSide(color: context.colors.accent),
        minimumSize: const Size(48, 48),
      );
    }
    return OutlinedButton.styleFrom(
      foregroundColor: context.colors.textPrimary,
      side: BorderSide(color: context.colors.border),
      minimumSize: const Size(48, 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArrow = mode == AnnotationMode.arrow;
    final isSquare = mode == AnnotationMode.square;

    return Container(
      key: const Key('annotation-bar'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Tooltip(
            message: 'Arrow',
            child: OutlinedButton.icon(
              key: const Key('annotate-arrow'),
              onPressed: onArrowPressed,
              icon: const Icon(Icons.arrow_right_alt, size: 18),
              label: const Text('Arrow', style: AppText.body),
              style: _modeStyle(context, active: isArrow),
            ),
          ),
          Tooltip(
            message: 'Square',
            child: OutlinedButton.icon(
              key: const Key('annotate-square'),
              onPressed: onSquarePressed,
              icon: const Icon(Icons.crop_square, size: 18),
              label: const Text('Square', style: AppText.body),
              style: _modeStyle(context, active: isSquare),
            ),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final arrow in ArrowColor.all)
                ArrowColorButton(
                  key: Key('annotate-color-${arrow.id}'),
                  arrow: arrow,
                  isSelected: selectedColorCode == arrow.id,
                  onTap: () => onColorSelected(arrow.id),
                ),
            ],
          ),
          Tooltip(
            message: 'Clear marks',
            child: OutlinedButton.icon(
              key: const Key('annotate-clear'),
              onPressed: onClearPressed,
              icon: const Icon(Icons.layers_clear, size: 18),
              label: const Text('Clear marks', style: AppText.body),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textSecondary,
                side: BorderSide(color: context.colors.border),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
