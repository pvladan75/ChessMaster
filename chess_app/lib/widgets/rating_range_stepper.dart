import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// A puzzle-difficulty range as two numbers with a step each way — „From
/// [−] 1200 [+]   To [−] 1800 [+]".
///
/// It replaced a `RangeSlider` on 22.9.2026. Flutter's range slider keeps an
/// `OverlayPortal` open for its value bubbles, and in a dialog that overlay's
/// semantics node reaches Windows before the node it belongs under, which
/// breaks the accessibility tree and a few updates later crashes the app (the
/// same fault as `AppSlider` answers; see `lib/widgets/app_slider.dart`).
/// The owner chose numbers over a home-made two-thumb slider.
///
/// The ends never cross: a step that would put „from" above „to" is not
/// offered. No tooltips on the buttons — each carries its sentence as
/// semantics instead, because a tooltip is an overlay too.
class RatingRangeStepper extends StatelessWidget {
  const RatingRangeStepper({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 400,
    this.max = 2800,
    this.step = 100,
  });

  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final double min;
  final double max;
  final double step;

  @override
  Widget build(BuildContext context) {
    final from = values.start;
    final to = values.end;
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _End(
          name: 'From',
          value: from,
          step: step,
          keyPrefix: 'rating-from',
          lower: from - step >= min
              ? () => onChanged(RangeValues(from - step, to))
              : null,
          raise: from + step <= to
              ? () => onChanged(RangeValues(from + step, to))
              : null,
        ),
        _End(
          name: 'To',
          value: to,
          step: step,
          keyPrefix: 'rating-to',
          lower: to - step >= from
              ? () => onChanged(RangeValues(from, to - step))
              : null,
          raise: to + step <= max
              ? () => onChanged(RangeValues(from, to + step))
              : null,
        ),
      ],
    );
  }
}

class _End extends StatelessWidget {
  const _End({
    required this.name,
    required this.value,
    required this.step,
    required this.keyPrefix,
    required this.lower,
    required this.raise,
  });

  final String name;
  final double value;
  final double step;
  final String keyPrefix;
  final VoidCallback? lower;
  final VoidCallback? raise;

  @override
  Widget build(BuildContext context) {
    final shown = value.round();
    final by = step.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            style: AppText.body.copyWith(color: context.colors.textSecondary)),
        const SizedBox(width: AppSpacing.xs),
        Semantics(
          button: true,
          enabled: lower != null,
          onTap: lower,
          label: '$name: lower to ${shown - by}',
          excludeSemantics: true,
          child: IconButton(
            key: Key('$keyPrefix-minus'),
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
            onPressed: lower,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$shown',
            key: Key('$keyPrefix-value'),
            textAlign: TextAlign.center,
            style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
          ),
        ),
        Semantics(
          button: true,
          enabled: raise != null,
          onTap: raise,
          label: '$name: raise to ${shown + by}',
          excludeSemantics: true,
          child: IconButton(
            key: Key('$keyPrefix-plus'),
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
            onPressed: raise,
          ),
        ),
      ],
    );
  }
}
