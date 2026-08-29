import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/ai_studio/solution_tree_models.dart';

void showGroupedMovesDialog({
  required BuildContext context,
  required SolutionGraphNode node,
  required Function(SolutionGraphNode node, int selectedIndex) onMoveSelected,
}) {
  int selectedIndex = node.selectedGroupedIndex;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final colors = context.colors;

        return AlertDialog(
          backgroundColor: colors.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.roundedLg,
            side: BorderSide(color: colors.brand, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.filter_list, color: colors.brand, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Odbrambene Varijante',
                style: AppText.title.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Izaberite odbrambeni potez protivnika za prikaz na tabli:',
                    style:
                        AppText.bodyLarge.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(node.groupedOpponentMoves.length,
                        (index) {
                      final isSelected = (index == selectedIndex);
                      final san = node.groupedOpponentMoves[index];
                      return ChoiceChip(
                        selected: isSelected,
                        selectedColor: colors.accent.withValues(alpha: 0.22),
                        backgroundColor: colors.surface,
                        side: BorderSide(
                            color: isSelected ? colors.accent : colors.border),
                        avatar: isSelected
                            ? Icon(Icons.check,
                                size: 16, color: colors.textPrimary)
                            : null,
                        label: Text(
                          san,
                          style: AppText.bodyLargeBold.copyWith(
                            color: isSelected
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                        onSelected: (_) {
                          setDialogState(() {
                            selectedIndex = index;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Zatvori',
                style: AppText.bodyLarge.copyWith(color: colors.textMuted),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.gamepad, size: 16),
              label: const Text('Prikaži Poziciju na Tabli'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.info,
                foregroundColor: colors.canvas,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onMoveSelected(node, selectedIndex);
              },
            ),
          ],
        );
      },
    ),
  );
}
