import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/speakable_info.dart';

/// Below this, the sentence and the button do not fit side by side.
///
/// Measured rather than guessed: with the sentence squeezed to nothing the row
/// still needs the icon, two gaps and the button, and „Pregledaj nepotvrđene"
/// makes that wider than a 360 dp phone. A little headroom above the measured
/// width, because the sentence should not be squeezed to nothing to avoid
/// stacking — at that point two lines read better than one.
const double _oneRowNeeds = 420;

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
      // One row where it fits, two where it does not.
      //
      // „Pregledaj nepotvrđene" is four characters longer than the „Pregledaj
      // nacrt" this banner was built around, and on a 360 dp phone that is a
      // 22-pixel overflow — clipped silently in a release build, which is the
      // trap CLAUDE.md keeps a whole section for. Measured 4.9.2026 during the
      // vocabulary sweep, which is exactly when a label gets longer.
      //
      // A plain `Wrap` fixes the phone and costs the desktop: `SpeakableInfo`
      // is a `Row` with an `Expanded` inside it, so as a `Wrap` child it takes
      // the whole width and the button drops to a second line at *every* size.
      // So the breakpoint is asked for explicitly instead.
      child: LayoutBuilder(builder: (context, space) {
        // One sentence, not two copies of it: `SpeakableInfo` draws the text
        // itself when it is handed a style, so what is spoken cannot drift
        // from what is shown by somebody editing one of them.
        final sentence = SpeakableInfo(
          text: '$total nepotvrđenih u grafu',
          style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
        );
        // Outlined rather than filled. A filled warning button needs `canvas`
        // for its label, and `canvas` measures 1.51:1 against the tint behind
        // it, so the two sit one on top of the other with no reading of the
        // pair that is safe in both themes. The outline puts the label on the
        // tint instead -- 11.33:1 dark, 15.61:1 light -- and carries the
        // affordance as a *shape*, which is the half a colourblind reader
        // actually gets.
        final button = OutlinedButton(
          onPressed: onOpenWizard,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
            side: BorderSide(color: context.colors.warning),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: const Text('Pregledaj nepotvrđene'),
        );
        final icon =
            Icon(Icons.edit_note, color: context.colors.warning, size: 20);

        if (space.maxWidth < _oneRowNeeds) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                icon,
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: sentence),
              ]),
              const SizedBox(height: AppSpacing.sm),
              button,
            ],
          );
        }
        return Row(children: [
          icon,
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: sentence),
          const SizedBox(width: AppSpacing.sm),
          button,
        ]);
      }),
    );
  }
}
