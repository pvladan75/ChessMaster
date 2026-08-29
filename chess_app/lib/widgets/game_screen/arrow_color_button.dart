import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';

/// One swatch in the arrow-drawing color picker.
class ArrowColorButton extends StatelessWidget {
  final ui.Color color;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const ArrowColorButton({
    super.key,
    required this.color,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 1.0 : 0.4),
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: context.colors.textPrimary, width: 2.0)
                : Border.all(color: Colors.transparent),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: isSelected
              ? Icon(Icons.check, size: 16, color: context.colors.textPrimary)
              : null,
        ),
      ),
    );
  }
}
