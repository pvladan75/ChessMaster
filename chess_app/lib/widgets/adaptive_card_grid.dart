import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_spacing.dart';

/// A list of peer cards that answers a wide window with **more cards**, not
/// with the same cards stretched — phase 2 of `docs/PLAN-LISTE.md`, pattern A.
///
/// The owner's correction is the whole reason this exists: *when I said there
/// is a lot of space on a wide screen, I did not mean it should be cut down by
/// capping the item width; I meant it should be used.* A `ListTile` in a
/// `ListView` cannot use it — its three slots keep their intrinsic size and
/// only the gap between them grows, which is where "a title, an ocean, and an
/// icon" comes from. So the answer is a grid, and the grid's job is to convert
/// width into visible items.
///
/// **The column count is never written down here.** It is worked out by
/// [SliverGridDelegateWithMaxCrossAxisExtent] from the constraint this widget
/// actually receives, which buys two things that a hard-coded count does not:
///
///  * `LibraryList` is drawn both on the Library screen and in the room's
///    narrow left column. The column gets one card across without being told,
///    because it is narrow — not because anything asked which screen it is.
///  * The phone is unchanged by construction. Below roughly 840 there is one
///    column, exactly as before this widget existed.
///
/// Sizing is by [mainAxisExtent] — a tile height in logical pixels — rather
/// than by an aspect ratio. A card's height is driven by the text inside it,
/// and an aspect ratio would make a card in a 1-column phone layout a
/// different height from the same card in a 4-column desktop one.
class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.tileHeight = defaultTileHeight,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  /// The widest a single card is allowed to be before the grid prefers to add
  /// a column instead.
  ///
  /// 420 is chosen so the grid agrees with the breakpoint this project already
  /// has: at `Breakpoints.wide` (840), where the codebase already says "there
  /// is room for two columns", this gives exactly two.
  ///
  /// The framework's count is `(extent / (maxExtent + spacing)).ceil()`, so
  /// with [spacing] the bands are one column to 432, two to 864, three to
  /// 1296, four to 1728 and five to 2160. **Those bands move if [spacing]
  /// changes**, which is why the test proves the count from where the children
  /// are actually painted rather than by quoting these numbers back.
  static const double maxTileWidth = 420.0;

  /// Between cards, both ways.
  static const double spacing = AppSpacing.md;

  /// Room for a title and two or three short facts.
  static const double defaultTileHeight = 112.0;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The height of one card. Screens whose cards carry a board thumbnail pass
  /// a larger one.
  final double tileHeight;

  final EdgeInsetsGeometry? padding;

  /// Take only the height the cards need, for a column that scrolls as a
  /// whole. The default fills what it is given.
  final bool shrinkWrap;

  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxTileWidth,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: itemBuilder,
    );
  }
}
