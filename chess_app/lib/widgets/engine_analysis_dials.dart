import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// How deep, and how many lines, **this board** is analysed to.
///
/// One control, on every board that shows an evaluation. Until 27.8.2026 both
/// numbers came from Settings, where they doubled as the engine's playing
/// strength: turning the opponent down to make a lesson easier also made every
/// evaluation in the app shallower, and there was no way to ask for five lines
/// on one position without changing how the engine played everywhere. The two
/// questions are now asked separately — the level in Settings is about the
/// opponent, and these dials are about what you are looking at.
///
/// The depth goes to 50 because on a position worth studying it is worth
/// waiting for; the old ceiling of 28 was a leftover from when this number also
/// decided how long the opponent thought before moving.
class EngineAnalysisDials extends StatelessWidget {
  const EngineAnalysisDials({
    super.key,
    required this.depth,
    required this.lines,
    required this.onDepthChanged,
    required this.onLinesChanged,
    this.onRestart,
    this.enabled = true,
    this.compact = false,
  });

  final int depth;
  final int lines;
  final ValueChanged<int> onDepthChanged;
  final ValueChanged<int> onLinesChanged;

  /// "Ask again", where a screen analyses on demand rather than continuously.
  final VoidCallback? onRestart;

  /// False while a search is running and the dials would only queue confusion.
  final bool enabled;

  /// Drops the word before each dial, for a panel with no room for it.
  final bool compact;

  /// Every second ply from 6 up. Odd depths are not interesting enough to
  /// double the length of the menu.
  static const List<int> depths = [
    6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 34, 38, 42, 46, 50 //
  ];

  static const List<int> lineCounts = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _dial(
          context,
          label: 'dubina',
          value: depth,
          values: depths,
          onChanged: onDepthChanged,
        ),
        _dial(
          context,
          label: compact ? 'linije' : 'linija',
          value: lines,
          values: lineCounts,
          onChanged: onLinesChanged,
        ),
        if (onRestart != null)
          TextButton.icon(
            onPressed: enabled ? onRestart : null,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Ponovo'),
          ),
      ],
    );
  }

  Widget _dial(
    BuildContext context, {
    required String label,
    required int value,
    required List<int> values,
    required ValueChanged<int> onChanged,
  }) {
    // A value from an older build (or a hand-edited preference) must still be
    // selectable, or the dropdown throws on a value it has no item for.
    // The parentheses are load-bearing: `a ? b : [...]..sort()` binds the
    // cascade to the whole conditional, so it sorted `values` — a const list —
    // and threw UnsupportedError while building.
    final options =
        values.contains(value) ? values : ([...values, value]..sort());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          Text('$label ',
              style: AppText.micro.copyWith(color: context.colors.textMuted)),
        DropdownButton<int>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: AppText.caption.copyWith(color: context.colors.textPrimary),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(compact ? '$label $option' : '$option'),
              ),
          ],
          onChanged: enabled
              ? (picked) {
                  if (picked != null) onChanged(picked);
                }
              : null,
        ),
      ],
    );
  }
}
