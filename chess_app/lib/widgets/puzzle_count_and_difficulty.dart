import 'package:flutter/material.dart';

import 'package:chess_app/widgets/app_slider.dart';
import 'package:chess_app/widgets/rating_range_stepper.dart';

/// „Number of puzzles" and „Difficulty" for a puzzle set — the one home of the
/// two controls that the homework editor's „A puzzle set" and the trainer's
/// „Create assignment" dialogs used to write out, line for line, each on its
/// own (merged 22.9.2026).
///
/// The count runs 5–50 in steps of 5; the difficulty is a rating range of
/// 400–2800 in steps of 100 ([RatingRangeStepper]). The caller owns both
/// values and sends them on.
class PuzzleCountAndDifficulty extends StatelessWidget {
  const PuzzleCountAndDifficulty({
    super.key,
    required this.count,
    required this.onCount,
    required this.rating,
    required this.onRating,
  });

  final int count;
  final ValueChanged<int> onCount;
  final RangeValues rating;
  final ValueChanged<RangeValues> onRating;

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.labelLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Number of puzzles: $count', style: heading),
        AppSlider(
          key: const Key('puzzle-count'),
          value: count.toDouble(),
          min: 5,
          max: 50,
          divisions: 9,
          label: '$count',
          onChanged: (value) => onCount(value.round()),
        ),
        Text(
          'Difficulty: ${rating.start.round()}–${rating.end.round()}',
          style: heading,
        ),
        RatingRangeStepper(values: rating, onChanged: onRating),
      ],
    );
  }
}
