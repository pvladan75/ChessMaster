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
    this.bare = false,
  });

  final int total;
  final VoidCallback onOpenWizard;

  /// Without the tinted card around it, for a place that already separates it.
  ///
  /// Since 5.9.2026 this banner rides in the screen's app bar on a wide window
  /// — the owner asked whether the empty space beside the title could be used,
  /// and it is the one place where moving it costs no column any height at all.
  /// There it needs no frame of its own: the bar is the frame, and a tinted
  /// card inside a coloured bar reads as a mistake.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    if (bare) return _row(context, oneRow: true);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
      child: LayoutBuilder(
          builder: (context, space) =>
              _row(context, oneRow: space.maxWidth >= _oneRowNeeds)),
    );
  }

  /// The banner's contents, in one row or two.
  ///
  /// One function rather than two, so the sentence and the label cannot drift
  /// between the card and the bar — they are the same banner in two frames.
  Widget _row(BuildContext context, {required bool oneRow}) {
    return Builder(builder: (context) {
      // One sentence, not two copies of it: `SpeakableInfo` draws the text
      // itself when it is handed a style, so what is spoken cannot drift
      // from what is shown by somebody editing one of them.
      // One string, two frames. `SpeakableInfo` draws it in the card; the bar
      // draws it plainly, and neither may spell it differently from the other
      // or from what is spoken.
      final said = '$total nepotvrđenih u grafu';
      final sentence = Theme(
        data: Theme.of(context).copyWith(
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        child: SpeakableInfo(
          text: said,
          style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
        ),
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
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(64, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Pregledaj nepotvrđene'),
      );
      final icon =
          Icon(Icons.edit_note, color: context.colors.warning, size: 20);

      if (!oneRow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              icon,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: sentence),
            ]),
            const SizedBox(height: AppSpacing.xs),
            button,
          ],
        );
      }
      // `Expanded` in both frames. `SpeakableInfo` is itself a `Row` with an
      // `Expanded` inside — the note at the top says so — so a row that sizes
      // itself to its children hands that inner one no width to shrink into and
      // overflows by however much the sentence wants. Caught at 1000 dp:
      // eleven pixels, which in a release build would have been eleven pixels
      // of silence.
      return Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.sm),
          // In the bar the sentence is a plain `Text` that may shrink to
          // nothing, and it carries no speaker of its own.
          //
          // Both for the same reason: `SpeakableInfo` is a `Row` of an
          // `Expanded` and an `IconButton`, and that icon cannot shrink — so
          // when the button's label leaves the sentence a few pixels, the icon
          // overflows the bar. Measured at 1000 dp: the banner is handed 381
          // px, the button wants 326 of them, and eleven pixels came out of
          // the right-hand side. A release build would have clipped them
          // without a word.
          //
          // The bar has its own speech control beside the title, so nothing
          // sayable is lost — but it is a different control, and it is worth a
          // look on the live pass.
          if (bare)
            Flexible(
              child: Text(said,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary)),
            )
          else
            Expanded(child: sentence),
          const SizedBox(width: AppSpacing.sm),
          button,
        ],
      );
    });
  }
}
