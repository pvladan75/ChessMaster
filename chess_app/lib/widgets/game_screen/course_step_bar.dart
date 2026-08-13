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
      color: Colors.deepPurple.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.collections_bookmark, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: PopupMenuButton<int>(
              tooltip: 'Skoči na korak',
              initialValue: activeIndex,
              onSelected: onGoToStep,
              itemBuilder: (ctx) => List.generate(items.length, (i) {
                final stepTitle = items[i]['title']?.toString() ?? 'Korak ${i + 1}';
                return PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      if (i == activeIndex) const Icon(Icons.check, size: 16, color: Colors.deepPurple) else const SizedBox(width: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${i + 1}. $stepTitle', overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${courseTitle ?? 'Kurs'} — korak ${activeIndex + 1}/${items.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            tooltip: 'Prethodni korak',
            onPressed: activeIndex > 0 ? () => onGoToStep(activeIndex - 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            tooltip: 'Sledeći korak',
            onPressed: activeIndex < items.length - 1 ? () => onGoToStep(activeIndex + 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            tooltip: 'Zatvori kurs',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
