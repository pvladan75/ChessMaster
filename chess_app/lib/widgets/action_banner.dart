import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// One look for "this expects something from you".
///
/// Written for `docs/PLAN-JEDNOSTAVNOST.md` phase 0, before the batches that
/// use it, so three of them cannot invent three versions of the same bar. The
/// reason it exists at all is the owner's, from the live pass: on a screen where
/// everything is a sentence in the same grey, the one sentence that wants an
/// answer looks exactly like the four that are merely true.
///
/// **The tone is carried by an icon and a border, never by hue alone.** The
/// reader this project is built for cannot be assumed to see the difference
/// between an amber tint and a grey one; they can see that one bar has a mark
/// and an outlined button on it and the other does not.
///
/// The label goes *on the tint* rather than inside a filled button: a filled
/// warning button needs `canvas` for its text, and `canvas` measures 1.51:1
/// against the tint behind it — unreadable in both themes. Outlined puts the
/// label at 11.33:1 dark and 15.61:1 light, and carries the affordance as a
/// shape, which is the half a colourblind reader actually gets.
enum ActionTone {
  /// Something is waiting to be answered. The common case.
  waiting,

  /// Something did not work and the reader has to decide what to do.
  problem,

  /// Nothing is wrong and nothing is being asked — a fact worth a bar.
  calm,
}

class ActionBanner extends StatelessWidget {
  const ActionBanner({
    super.key,
    required this.text,
    this.tone = ActionTone.waiting,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.trailing,
  });

  /// What is being asked, in one sentence. The banner does not compose it: the
  /// screen already has the words and a second source for them would drift.
  final String text;

  final ActionTone tone;

  /// The one thing to press. Both must be given or neither — a label with no
  /// callback is a button that does nothing, which this project has shipped
  /// once already.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides the tone's own mark. For the rare bar whose subject has an icon
  /// the reader already knows.
  final IconData? icon;

  /// Anything that belongs at the end and is not the action — the speaker
  /// control, most often.
  final Widget? trailing;

  Color _colorOf(BuildContext context) => switch (tone) {
        ActionTone.waiting => context.colors.warning,
        ActionTone.problem => context.colors.danger,
        ActionTone.calm => context.colors.accent,
      };

  IconData get _markOf => switch (tone) {
        ActionTone.waiting => Icons.pending_actions,
        ActionTone.problem => Icons.error_outline,
        ActionTone.calm => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final colour = _colorOf(context);
    final hasAction = actionLabel != null && onAction != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
        borderRadius: AppRadii.roundedMd,
      ),
      // `Wrap`, not `Row`: a sentence and a button do not fit on one line at
      // 360 dp, and a release build clips rather than warning about it.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Icon(icon ?? _markOf, color: colour, size: 20),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
            ),
            child: Text(
              text,
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textPrimary),
            ),
          ),
          if (trailing != null) trailing!,
          if (hasAction)
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: colour),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
