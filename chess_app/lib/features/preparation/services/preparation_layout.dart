/// Where everything on the Preparation screen goes, as numbers — D11 of
/// `docs/PLAN-PRIPREMA.md`.
///
/// **The board takes what the window has left**, and that is the whole rule:
/// the height under the bar, less the two rows that stand under the board, and
/// never more than the width the pane beside it leaves. The room's screen,
/// which Preparation used to be a mode of, capped the board at 62% of the
/// window's height whatever stood under it, so on the owner's window
/// (1536 × 792) the board was 491 where 600 fit.
///
/// **Nothing the trainer switches on may resize the board.** The evaluation
/// bar has its place beside the board whether it is drawn or not, and the two
/// rows under the board are one row each at every width — which is why the
/// marking bar has three densities and the screen asks here which one.
///
/// Pure, so the rule has a test of its own
/// (`test/preparation_layout_test.dart`) and the screen's gate can hold the
/// rendered board to it.
library;

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart'
    show MarkingDensity;

export 'package:chess_app/widgets/game_screen/board_annotation_bar.dart'
    show MarkingDensity;

class PreparationLayout {
  const PreparationLayout({
    required this.board,
    required this.paneWidth,
    required this.commentBesideEngine,
    required this.marks,
  });

  /// The board's side.
  final double board;

  /// The column beside the board on a desktop window; the page's own width on
  /// a phone held upright.
  final double paneWidth;

  /// Whether the comment and the engine's lines stand side by side under the
  /// tree, or one over the other.
  final bool commentBesideEngine;

  final MarkingDensity marks;

  /// Around everything under the bar.
  static const double padding = 8;

  /// Between the board's column and the pane.
  static const double gap = 12;

  /// Between the board and the row under it, and between the two rows.
  static const double rowGap = 4;

  /// The marking bar: 48 of button and the bar's own 4 above and below.
  static const double markingRow = 56;

  /// The move strip, dense: 40 of button and 4 of margin above and below.
  static const double stripRow = 48;

  /// `VerticalEvalBarWidget`'s own width, and the room between it and the
  /// board.
  static const double evalBar = 22;
  static const double evalGap = 8;

  /// The narrowest the pane may be, and what it may be in a window under
  /// [narrowWindow] — 900 is the narrowest window Windows gives this app.
  static const double minPane = 420;
  static const double minPaneNarrow = 400;
  static const double narrowWindow = 1000;

  /// What stands under the tree: the comment and the engine's lines side by
  /// side, or the comment over them. The tree takes the rest of the pane.
  static const double underTreeBeside = 270;
  static const double commentAlone = 112;
  static const double underTreeStacked = 300;

  /// From this pane width the comment and the engine's lines fit side by side.
  static const double commentBesideEngineFrom = 480;

  /// The widths the marking bar's three densities need. [regular] is the
  /// studio's labelled bar with „Undo" beside „Clear marks"; [compact] is five
  /// 40 dp buttons, the five 28 dp colours and their spacing.
  static const double regularMarksFrom = 760;
  static const double compactMarksFrom = 420;

  /// Everything that stands under the board, gaps included.
  static const double underBoard = markingRow + stripRow + 2 * rowGap;

  /// The evaluation bar's place beside the board, kept whether it is drawn or
  /// not.
  static const double evalSlot = evalBar + evalGap;

  static MarkingDensity marksFor(double width) {
    if (width >= regularMarksFrom) return MarkingDensity.regular;
    if (width >= compactMarksFrom) return MarkingDensity.compact;
    return MarkingDensity.tight;
  }

  /// A desktop window, from the [body] the screen is given under its bar.
  ///
  /// [scale] is the reader's board-size setting, 0.6–1.0: it only ever shrinks
  /// the board, and what the board gives up goes to the pane.
  static PreparationLayout desktop(Size body, {double scale = 1.0}) {
    final minPaneWidth = body.width < narrowWindow ? minPaneNarrow : minPane;
    final byHeight = body.height - 2 * padding - underBoard;
    final byWidth = body.width - 2 * padding - gap - minPaneWidth - evalSlot;
    final fits = math.max(0.0, math.min(byHeight, byWidth));
    final board = fits * scale.clamp(0.0, 1.0);
    final paneWidth = math.max(
      0.0,
      body.width - 2 * padding - gap - evalSlot - board,
    );
    return PreparationLayout(
      board: board,
      paneWidth: paneWidth,
      commentBesideEngine: paneWidth >= commentBesideEngineFrom,
      marks: marksFor(board),
    );
  }

  /// A phone held upright: the board as wide as the screen lets it be, and
  /// everything else under it. The evaluation bar lies over the board here —
  /// a place beside the board would cost the board thirty of its 344.
  static PreparationLayout phone(Size body, {double scale = 1.0}) {
    final fits = math.max(0.0, body.width - 2 * padding);
    final board = fits * scale.clamp(0.0, 1.0);
    return PreparationLayout(
      board: board,
      paneWidth: fits,
      commentBesideEngine: false,
      marks: marksFor(board),
    );
  }
}
