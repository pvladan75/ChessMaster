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
/// **The column count is never written down here.** [columnsFor] derives it
/// from the constraint this widget actually receives — as many cards as fit at
/// [maxTileWidth], never so many that one falls below [minTileWidth] — which
/// buys two things that a hard-coded count does not:
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

  /// The narrowest a card may be drawn before the grid prefers **fewer**
  /// columns.
  ///
  /// [maxTileWidth] alone is half a rule, and the missing half was a real
  /// fault: `ceil` means a strip just past a band boundary is split evenly,
  /// so 460 px became two columns of 224 — and a `LibraryList` card at 224
  /// overflowed its own height by 48 px, measured 20.9.2026 with no pane and
  /// no screen involved, on master. A release build clips that instead of
  /// warning, so a Library window between roughly 440 and 530 px silently cut
  /// the buttons off its cards.
  ///
  /// 280 is taken from the widest thing a card of this family has to fit on
  /// one line — a 56 px indent and four 48 px action buttons is 248 — with
  /// room left for the card's own insets. Measured either side of it: 274 is
  /// clean, 244 overflows.
  static const double minTileWidth = 280.0;

  /// How many columns this pattern gives a strip exactly [width] wide.
  ///
  /// Two constraints, not one: as many columns as fit at [maxTileWidth], and
  /// never so many that a card falls below [minTileWidth]. **The count is
  /// still not written down** — it is derived here and nowhere else, which is
  /// what lets [AdaptiveCardColumns], whose cards are of different heights and
  /// so cannot use a sliver delegate, answer the question exactly as the grid
  /// does (rule 12).
  ///
  /// [width] is the extent the cards are actually laid out in, with any
  /// padding and spacing already accounted for.
  static int columnsFor(double width) {
    if (!width.isFinite || width <= 0) return 1;
    var count = (width / (maxTileWidth + spacing)).ceil();
    if (count < 1) count = 1;
    // Drop a column while the ones left would be too narrow to draw.
    while (
        count > 1 && (width - spacing * (count - 1)) / count < minTileWidth) {
      count--;
    }
    return count;
  }

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
    final pad = padding ?? const EdgeInsets.all(AppSpacing.md);
    // The count comes from [columnsFor] rather than from a sliver delegate's
    // own arithmetic, because the delegate knows only a maximum and the rule
    // has two halves. It is still read off the constraint this widget was
    // handed and never off the window, which is what lets the room's narrow
    // column and a desktop screen share one widget.
    return LayoutBuilder(builder: (context, constraints) {
      final inset = pad.resolve(Directionality.of(context)).horizontal;
      return GridView.builder(
        padding: pad,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnsFor(constraints.maxWidth - inset),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          mainAxisExtent: tileHeight,
        ),
        itemBuilder: itemBuilder,
      );
    });
  }
}

/// The same pattern for cards that are **not** all the same height — phase 4
/// of `docs/PLAN-LISTE.md`.
///
/// [AdaptiveCardGrid] sizes every cell to one [AdaptiveCardGrid.tileHeight],
/// which is what a sliver grid is: a sheet of equal cells. „What to drill"
/// cannot live in one. A family of endings is a line tall while it is shut and
/// some 800 px tall once it is opened — rook endings alone come in thirteen
/// shapes — so a single cell height has only two outcomes, and both are
/// faults this plan already paid for: the open family overflows its cell, or
/// every shut family is given the open one's height and the window fills with
/// air, which is phase 3a's complaint word for word.
///
/// So the cards are dealt into columns and each column is an ordinary
/// [Column] that takes the height its contents need. Opening one card grows
/// its own column and moves nothing in the others, which is the real gain
/// here over the `ListView` this replaced.
///
/// The column **count** is still not written down: it comes from
/// [AdaptiveCardGrid.columnsFor], the one home for that arithmetic, applied to
/// the constraint this widget is handed. One column on a phone, by
/// construction.
///
/// Cards are dealt round-robin, so they read left to right across the row
/// exactly as they would in the grid.
class AdaptiveCardColumns extends StatelessWidget {
  const AdaptiveCardColumns({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AdaptiveCardGrid.columnsFor(constraints.maxWidth);
        if (columns <= 1 || children.length <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        final buckets = List.generate(columns, (_) => <Widget>[]);
        for (var i = 0; i < children.length; i++) {
          buckets[i % columns].add(children[i]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: AdaptiveCardGrid.spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buckets[c],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
