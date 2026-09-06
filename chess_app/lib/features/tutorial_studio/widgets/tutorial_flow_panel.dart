import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The timeline of a tutorial part in the order the child meets it.
///
/// Stateless, and it decides nothing: it projects [root] and [current] through
/// [beatsOf], draws one card per beat, and reports every choice through
/// [onSelect]. The screen owns the cursor and moves the board.
class TutorialFlowPanel extends StatelessWidget {
  const TutorialFlowPanel({
    super.key,
    required this.root,
    required this.current,
    required this.onSelect,
  });

  final AnalysisNode root;
  final AnalysisNode current;
  final void Function(AnalysisNode) onSelect;

  @override
  Widget build(BuildContext context) {
    final beats = beatsOf(root, current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < beats.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _BeatCard(
            beat: beats[i],
            onSelect: onSelect,
          ),
        ],
      ],
    );
  }
}

class _BeatCard extends StatelessWidget {
  const _BeatCard({
    required this.beat,
    required this.onSelect,
  });

  final TutorialBeat beat;
  final void Function(AnalysisNode) onSelect;

  @override
  Widget build(BuildContext context) {
    final headerText =
        beat.index == 0 ? 'Polazna pozicija' : 'posle ${beat.arrivedLabel}';

    return Material(
      key: Key('beat-${beat.index}'),
      color: beat.isCurrent
          ? context.colors.surfaceRaised
          : context.colors.surface,
      borderRadius: AppRadii.roundedMd,
      child: InkWell(
        borderRadius: AppRadii.roundedMd,
        onTap: () => onSelect(beat.node),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.roundedMd,
            border: Border.all(
              color: beat.isCurrent
                  ? context.colors.borderStrong
                  : context.colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (beat.isCurrent) ...[
                    Icon(
                      Icons.radio_button_checked,
                      key: const Key('beat-current'),
                      size: 16,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      headerText,
                      style: (beat.isCurrent ? AppText.bodyBold : AppText.body)
                          .copyWith(
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (beat.node.comment.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  beat.node.comment,
                  style: AppText.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
              if (beat.branches.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final branch in beat.branches)
                      ActionChip(
                        backgroundColor: branch.taken
                            ? context.colors.surfaceRaised
                            : context.colors.surface,
                        side: BorderSide(
                          color: branch.taken
                              ? context.colors.accent
                              : context.colors.border,
                        ),
                        label: Text(
                          branch.label,
                          style:
                              (branch.taken ? AppText.bodyBold : AppText.body)
                                  .copyWith(
                            color: branch.taken
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                          ),
                        ),
                        onPressed: () => onSelect(branch.node),
                      ),
                  ],
                ),
              ] else if (!beat.isLast && beat.playsLabel != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'pa se igra: ${beat.playsLabel}',
                  style: AppText.caption.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
