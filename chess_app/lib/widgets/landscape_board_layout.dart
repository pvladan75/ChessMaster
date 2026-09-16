import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_spacing.dart';
import 'package:chess_app/theme/breakpoints.dart';

/// A board screen held sideways: the board on the left, everything else in a
/// column on the right.
///
/// **The board never moves.** It is not inside anything that scrolls, and its
/// side is taken from the height this layout is actually given rather than from
/// the screen minus a guess. The layouts this replaces put the board, the move
/// strip and the panels in one scrolling column, so on a phone held sideways
/// (about 800×360 dp) the board came out near 240 dp and slid away under the
/// reader's thumb.
///
/// **What sits "under the board" in portrait goes to the bottom of the right
/// column**, pinned — the move strip first of all. Under the board it would
/// take its height out of the board, and on a phone it could not even stay one
/// row: the Analysis Studio's nine buttons need 432 dp, and a board bounded by a
/// 360 dp screen is about 290 dp wide, so the strip wraps and the board loses
/// another row. In the right column it is one row, in one place, and only the
/// [panels] above it scroll.
///
/// **An eval bar stands beside the board** ([boardAside]), as tall as the board,
/// for the same reason: height is what a landscape phone does not have.
class LandscapeBoardLayout extends StatelessWidget {
  const LandscapeBoardLayout({
    super.key,
    required this.board,
    required this.panels,
    this.footer = const [],
    this.header,
    this.boardAside,
    this.boardScale = 1.0,
  });

  /// Whether a screen should use this layout: a phone held sideways, or any
  /// window as short as one.
  ///
  /// By height, not width. A large phone on its side is 915 dp wide — past
  /// [Breakpoints.wide] — and the two-column layouts drawn for that width
  /// assume a desktop's height under the board. Material 3 calls anything
  /// under 480 dp tall a compact height, and every phone on its side is one.
  static bool applies(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.height < Breakpoints.compactHeight;
  }

  /// The app bar height for a screen that uses this layout: 44 rather than 56,
  /// because on a 360 dp tall screen the difference is the board's.
  ///
  /// Null elsewhere, so an `AppBar(toolbarHeight: …)` keeps its default.
  static double? toolbarHeight(BuildContext context) =>
      applies(context) ? compactToolbarHeight : null;

  static const double compactToolbarHeight = 44.0;

  /// Draws the board at the side length it is given.
  final Widget Function(double side) board;

  /// Something as tall as the board, drawn to its left — the eval bar.
  final Widget Function(double height)? boardAside;

  /// Pinned at the top of the right column.
  final Widget? header;

  /// The part of the right column that scrolls.
  final Widget panels;

  /// Pinned at the bottom of the right column, in order — the move strip, and
  /// whatever the portrait layout has under the board.
  final List<Widget> footer;

  /// The user's board size setting, 0.6–1.0. It only ever shrinks the board.
  final double boardScale;

  /// The right column is never narrower than one row of the widest move strip.
  ///
  /// The Analysis Studio's: nine dense 40 dp buttons, its 8 dp spacer and the
  /// strip's own 8 dp padding a side make 384; the rest is room for a centre
  /// label such as the repertoire's "Move 12 of 30". It was 300 until a phone
  /// at about 760 dp with the eval bar on wrapped the strip into two rows and
  /// left the panels a sliver (TODO-provera 172, item 1). The board pays for
  /// it only where the width binds: a 640 dp phone, or a tall one near 760.
  static const double minPanelWidth = 390.0;

  static const double asideWidth = 22.0;

  static const double _padding = AppSpacing.sm;
  static const double _gap = AppSpacing.md;
  static const double _asideGap = AppSpacing.xs;

  /// The board's side in a layout given [area]: bound by the height, or by the
  /// width left once the panel column has its minimum, whichever is smaller.
  static double boardSideFor(
    Size area, {
    bool withAside = false,
    double scale = 1.0,
  }) {
    final byHeight = area.height - 2 * _padding;
    final byWidth = area.width -
        2 * _padding -
        _gap -
        minPanelWidth -
        (withAside ? asideWidth + _asideGap : 0.0);
    final fits = math.max(0.0, math.min(byHeight, byWidth));
    return fits * scale.clamp(0.0, 1.0);
  }

  /// Below this the layout stops shrinking and scrolls as a whole instead.
  ///
  /// A soft keyboard takes two thirds of a phone on its side, and a board
  /// computed from what is left would be a stamp — or nothing, with the footer
  /// overflowing a column shorter than itself. Scrolling while the keyboard is
  /// up is the lesser cost, and it lasts only as long as the keyboard does.
  static const double minHeight = 240.0;

  /// The largest share of the right column the footer may take before it
  /// scrolls inside itself, so the panels always keep some of the column.
  static const double footerShare = 0.6;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, child: _scrolling());
  }

  Widget _scrolling() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Always inside the scroll view, never only when it is needed. The
        // keyboard is what makes it needed, and a tree that changed shape as
        // the keyboard came up would rebuild the text field being typed into —
        // which drops its focus and closes the keyboard again.
        final height = constraints.maxHeight.isFinite
            ? math.max(constraints.maxHeight, minHeight)
            : minHeight;
        return SingleChildScrollView(
          child: SizedBox(
            height: height,
            child: _layout(Size(constraints.maxWidth, height)),
          ),
        );
      },
    );
    // Here and not on each screen: on a phone on its side the system buttons
    // and the camera cut-out are on the left or the right, and the tutorial
    // step editor, which had no SafeArea of its own, drew its fields under
    // them (TODO-provera 172, item 7). The app bar owns the top. A SafeArea
    // above this one has already taken the padding, so nothing is counted
    // twice.
  }

  Widget _layout(Size area) {
    final side = boardSideFor(
      area,
      withAside: boardAside != null,
      scale: boardScale,
    );
    final column = area.height - 2 * _padding;

    return Padding(
      padding: const EdgeInsets.all(_padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (boardAside != null) ...[
            SizedBox(
              width: asideWidth,
              height: side,
              child: boardAside!(side),
            ),
            const SizedBox(width: _asideGap),
          ],
          SizedBox(width: side, height: side, child: board(side)),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(
              children: [
                if (header != null) header!,
                Expanded(child: SingleChildScrollView(child: panels)),
                if (footer.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: column * footerShare,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // Full width, so a strip that wraps its buttons draws
                        // its card across the column rather than a stub.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: footer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
