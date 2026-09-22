/// The "Add" picker that has nothing in the Library to reuse — a puzzle
/// set's criteria (`CreateAssignmentDialog` is a full assignment dialog with
/// a student and a due date, awkward to fold a criteria-only question into).
/// The other two doors — a tutorial, exercises — are picked through
/// `CoursePickerDialog` and `PositionPickerDialog`, already built for this.
///
/// A third door lived here until `docs/PLAN-EXERCISE.md` phase 4: „Play it
/// out", which asked for a pasted FEN and built an `engine_game` task by
/// hand. **Superseded 18.9.2026** — a game exercise is now made in
/// Preparation (phase 3b's `MakeExerciseSheet`) and picked here the same way
/// a find-the-move one is, through `homeworkItemsFromExercises`. Its dialog
/// (`_EngineGameItemDialog`) and `pickEngineGameTask` are gone; the FEN
/// completion and legality it called (`services/fen_legality.dart`) stay —
/// they are read by other code and guarded by `test/fen_completion_test.dart`.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show themeLabel, themeLabels;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/puzzle_count_and_difficulty.dart';

/// Asks for a puzzle set's criteria and hands back the `puzzles` task —
/// `{themes, count, minRating, maxRating}` — or null on cancel. The same
/// theme catalogue `CreateAssignmentDialog` offers ([themeLabels]), read
/// rather than copied a second time.
Future<Map<String, dynamic>?> pickPuzzleCriteria(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _PuzzleCriteriaDialog(),
  );
}

class _PuzzleCriteriaDialog extends StatefulWidget {
  const _PuzzleCriteriaDialog();

  @override
  State<_PuzzleCriteriaDialog> createState() => _PuzzleCriteriaDialogState();
}

class _PuzzleCriteriaDialogState extends State<_PuzzleCriteriaDialog> {
  final Set<String> _themes = {};
  int _count = 10;
  RangeValues _ratingRange = const RangeValues(1000, 1800);

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.of(context).size.width - 128;
    return AlertDialog(
      title: const Text('Puzzle set'),
      content: SizedBox(
        width: available.clamp(180.0, 420.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Themes', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final theme in themeLabels.keys)
                    FilterChip(
                      label: Text(themeLabel(theme), style: AppText.body),
                      selected: _themes.contains(theme),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _themes.add(theme);
                        } else {
                          _themes.remove(theme);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PuzzleCountAndDifficulty(
                count: _count,
                onCount: (v) => setState(() => _count = v),
                rating: _ratingRange,
                onRating: (v) => setState(() => _ratingRange = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('homework-puzzle-submit'),
          onPressed: () => Navigator.pop(context, {
            'themes': _themes.toList(),
            'count': _count,
            'minRating': _ratingRange.start.round(),
            'maxRating': _ratingRange.end.round(),
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
