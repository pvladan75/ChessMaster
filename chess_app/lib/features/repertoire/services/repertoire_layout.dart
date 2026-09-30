/// Where the repertoire build screen puts things on a desktop window, as
/// numbers — the owner's choice of 30.9.2026 from the sketches in
/// `docs/skice/repertoar.html` („B, then A").
///
/// **The board takes the height the window has left** under the bar and the
/// move strip, and never more than the width the rest leaves: Preparation's
/// rule (`PreparationLayout`), with the strip as the only row under the board.
/// Until then the board was held to half the window's height so the book and
/// the engine could stand under it — 368 on the owner's window (1536 × 792)
/// where 668 fit — and the engine was still a scroll away.
///
/// **Beside the board, one of two shapes**, and the book and the engine are on
/// the screen in both:
///
///  * [RepertoireShape.threeColumns] — the position's panels in a column of
///    their own and the tree in the rest, as tall as the window. Taken
///    wherever that column and a readable tree fit without costing the board
///    anything.
///  * Preparation's shape — the tree on top and the panels under it: the book
///    and the engine side by side where the pane is wide enough
///    ([RepertoireShape.treeOverBeside]), one column that scrolls where it is
///    not ([RepertoireShape.treeOverStacked]).
///
/// The three columns give way exactly where they would start to take from the
/// board, so at the board's full size it is the same on both sides of that
/// width and only what stands beside it moves. (A board the reader has shrunk
/// is a share of what fits, as in Preparation, and what fits is bound by the
/// width on one side of the switch and by the height on the other.)
///
/// Pure, so the rule has a test of its own (`test/repertoire_layout_test.dart`)
/// and the screen's gate can hold the rendered board to it.
library;

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:chess_app/features/preparation/services/preparation_layout.dart';

enum RepertoireShape { threeColumns, treeOverBeside, treeOverStacked }

class RepertoireLayout {
  const RepertoireLayout({
    required this.board,
    required this.shape,
    required this.paneWidth,
    required this.treeWidth,
    required this.underTree,
  });

  /// The board's side, its coordinates included.
  final double board;

  final RepertoireShape shape;

  /// Everything to the right of the board: in three columns the panels'
  /// column, a gap and the tree; otherwise the pane that holds the tree and
  /// the panels under it.
  final double paneWidth;

  /// The tree's width — its own column, or the whole pane.
  final double treeWidth;

  /// How tall the panels under the tree are. Nothing stands under the tree in
  /// three columns, so zero there.
  final double underTree;

  /// The same spacing as Preparation, so the two screens a trainer moves
  /// between are laid out alike.
  static const double padding = PreparationLayout.padding;
  static const double gap = PreparationLayout.gap;
  static const double rowGap = PreparationLayout.rowGap;

  /// The move strip under the board, dense: 40 of button and 4 of margin
  /// above and below.
  static const double stripRow = PreparationLayout.stripRow;

  /// The panels' own column in three columns: the book's three chips in one
  /// row, and an engine line with room for its continuation.
  static const double panelColumn = 380;

  /// The narrowest tree worth a column of its own — about three cards abreast.
  static const double minTree = 420;

  /// From this pane width the book and the engine stand side by side under
  /// the tree, each as wide as a three-column layout's panel column gives
  /// them, less a little.
  static const double besideFrom = 640;

  /// The panels under the tree, as tall as Preparation's: side by side, the
  /// book's chips and the moves kept, or the engine's three lines and its
  /// dials, with the buttons under both; one over the other, the book first
  /// and the rest a scroll away inside the box. A share of the height was
  /// tried first and left the tree a sliver at 900 × 700.
  static const double underTreeHeight = PreparationLayout.underTreeStacked;

  /// The narrowest the pane may be, as in Preparation.
  static const double minPane = PreparationLayout.minPane;
  static const double minPaneNarrow = PreparationLayout.minPaneNarrow;
  static const double narrowWindow = PreparationLayout.narrowWindow;

  /// Everything that stands under the board, gap included.
  static const double underBoard = rowGap + stripRow;

  /// A desktop window, from the [body] the screen is given under its bar.
  ///
  /// [scale] is the reader's board-size setting, 0.6–1.0: it only ever
  /// shrinks the board, and what the board gives up goes to what is beside
  /// it.
  static RepertoireLayout desktop(Size body, {double scale = 1.0}) {
    final s = scale.clamp(0.0, 1.0);
    final inner = math.max(0.0, body.height - 2 * padding);
    final byHeight = math.max(0.0, inner - underBoard);
    // What the board and everything beside it share.
    final shared = math.max(0.0, body.width - 2 * padding - gap);

    final threeColumnsBoard = byHeight * s;
    if (shared - threeColumnsBoard - panelColumn - gap >= minTree) {
      final pane = shared - threeColumnsBoard;
      return RepertoireLayout(
        board: threeColumnsBoard,
        shape: RepertoireShape.threeColumns,
        paneWidth: pane,
        treeWidth: pane - panelColumn - gap,
        underTree: 0,
      );
    }

    final minPaneWidth = body.width < narrowWindow ? minPaneNarrow : minPane;
    final fits = math.max(0.0, math.min(byHeight, shared - minPaneWidth));
    final board = fits * s;
    final pane = math.max(0.0, shared - board);
    final beside = pane >= besideFrom;
    return RepertoireLayout(
      board: board,
      shape: beside
          ? RepertoireShape.treeOverBeside
          : RepertoireShape.treeOverStacked,
      paneWidth: pane,
      treeWidth: pane,
      underTree: math.min(underTreeHeight, inner),
    );
  }
}
