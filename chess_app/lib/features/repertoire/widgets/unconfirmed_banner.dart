import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class UnconfirmedBanner extends StatelessWidget {
  const UnconfirmedBanner({
    super.key,
    required this.total,
    required this.onOpenWizard,
  });

  final int total;
  final VoidCallback onOpenWizard;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.1),
        border:
            Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
        borderRadius: AppRadii.roundedMd,
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: context.colors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$total nepotvrđenih u grafu',
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Outlined rather than filled. A filled warning button needs
          // `canvas` for its label, and `canvas` measures 1.51:1 against the
          // tint behind it, so the two sit one on top of the other with no
          // reading of the pair that is safe in both themes. The outline puts
          // the label on the tint instead -- 11.33:1 dark, 15.61:1 light --
          // and carries the affordance as a *shape*, which is the half a
          // colourblind reader actually gets.
          OutlinedButton(
            onPressed: onOpenWizard,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.warning),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text('Pregledaj nacrt'),
          ),
        ],
      ),
    );
  }
}
