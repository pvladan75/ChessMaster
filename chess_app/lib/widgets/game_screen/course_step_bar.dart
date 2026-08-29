import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Trainer-only bar for stepping through an active course's lesson list.
class CourseStepBar extends StatelessWidget {
  final List<dynamic> items;
  final int activeIndex;
  final String? courseTitle;
  final ValueChanged<int> onGoToStep;
  final VoidCallback onClose;

  const CourseStepBar({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.courseTitle,
    required this.onGoToStep,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.groupedContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.collections_bookmark,
              color: context.colors.onGroupedContainer, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: PopupMenuButton<int>(
              tooltip: 'Skoči na korak',
              initialValue: activeIndex,
              onSelected: onGoToStep,
              itemBuilder: (ctx) => List.generate(items.length, (i) {
                final stepTitle =
                    items[i]['title']?.toString() ?? 'Korak ${i + 1}';
                return PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      if (i == activeIndex)
                        Icon(Icons.check, size: 16, color: context.colors.brand)
                      else
                        const SizedBox(width: AppSpacing.lg),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text('${i + 1}. $stepTitle',
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${courseTitle ?? 'Kurs'} — korak ${activeIndex + 1}/${items.length}',
                      style: AppText.bodyBold
                          .copyWith(color: context.colors.onGroupedContainer),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down,
                      color: context.colors.onGroupedContainer
                          .withValues(alpha: 0.7),
                      size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: context.colors.onGroupedContainer),
            tooltip: 'Prethodni korak',
            onPressed:
                activeIndex > 0 ? () => onGoToStep(activeIndex - 1) : null,
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: context.colors.onGroupedContainer),
            tooltip: 'Sledeći korak',
            onPressed: activeIndex < items.length - 1
                ? () => onGoToStep(activeIndex + 1)
                : null,
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: context.colors.onGroupedContainer.withValues(alpha: 0.7),
                size: 18),
            tooltip: 'Zatvori kurs',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
