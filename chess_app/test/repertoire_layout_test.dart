// The rule the repertoire build screen is laid out by on a desktop window —
// the owner's choice of 30.9.2026 („B, then A", `docs/skice/repertoar.html`).
//
// **Every expected number here is a literal**, as in
// `preparation_layout_test.dart`: a test that computed its expectation from
// `RepertoireLayout.padding` would follow the constant wherever it moved.
//
// Body = the window less the bar, 56 on a desktop window.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/services/repertoire_layout.dart';

void main() {
  test('the owner\'s window: three columns and a board of 668, not 368', () {
    // 1536 × 792, his 1920 × 1080 at 125%.
    final layout = RepertoireLayout.desktop(const Size(1536, 736));
    expect(layout.shape, RepertoireShape.threeColumns);
    expect(layout.board, 668);
    expect(layout.paneWidth, 840);
    expect(layout.treeWidth, 448);
    expect(layout.underTree, 0);
  });

  test('the board, the strip and the padding fill the height', () {
    // 8 + 668 + 4 + 48 + 8.
    final layout = RepertoireLayout.desktop(const Size(1536, 736));
    expect(8 + layout.board + 4 + 48 + 8, 736);
  });

  test('the board, the panels, the tree and the gaps fill the width', () {
    final three = RepertoireLayout.desktop(const Size(1536, 736));
    expect(8 + three.board + 12 + 380 + 12 + three.treeWidth + 8, 1536);
    for (final body in const [Size(1200, 744), Size(900, 644)]) {
      final layout = RepertoireLayout.desktop(body);
      expect(8 + layout.board + 12 + layout.paneWidth + 8, body.width);
    }
  });

  group('the three columns give way where they would cost the board', () {
    // At a body 736 tall the board is 668 by the height, and three columns
    // need 8 + 668 + 12 + 380 + 12 + 420 + 8 = 1508.
    test('1508 is three columns with a tree of 420', () {
      final layout = RepertoireLayout.desktop(const Size(1508, 736));
      expect(layout.shape, RepertoireShape.threeColumns);
      expect(layout.board, 668);
      expect(layout.treeWidth, 420);
    });

    test('1507 is the tree over the panels, and the board has not moved', () {
      final layout = RepertoireLayout.desktop(const Size(1507, 736));
      expect(layout.shape, RepertoireShape.treeOverBeside);
      expect(layout.board, 668, reason: 'the board jumped at the switch');
      expect(layout.paneWidth, 811);
      expect(layout.treeWidth, 811);
      expect(layout.underTree, 300);
    });

    test('a tall window keeps its board and puts the panels under the tree',
        () {
      // 1920 × 1000 is three columns; the same width twice as tall is not,
      // because a board of 1876 would leave nothing beside it.
      final wide = RepertoireLayout.desktop(const Size(1920, 944));
      expect(wide.shape, RepertoireShape.threeColumns);
      expect(wide.board, 876);
      expect(wide.treeWidth, 624);
      final tall = RepertoireLayout.desktop(const Size(1920, 1944));
      expect(tall.shape, isNot(RepertoireShape.threeColumns));
      expect(tall.board, 1472, reason: '1920 − 16 − 12 − 420');
      expect(tall.paneWidth, 420);
    });
  });

  group('under the tree, side by side from a pane of 640', () {
    // A body 600 tall: the board is 600 − 16 − 52 = 532 by the height.
    test('a pane of 640 has the book and the engine side by side', () {
      final at = RepertoireLayout.desktop(const Size(532 + 28 + 640, 600));
      expect(at.board, 532);
      expect(at.paneWidth, 640);
      expect(at.shape, RepertoireShape.treeOverBeside);
      expect(at.underTree, 300);
    });

    test('a pane of 639 has them one over the other', () {
      final under = RepertoireLayout.desktop(const Size(532 + 28 + 639, 600));
      expect(under.paneWidth, 639);
      expect(under.shape, RepertoireShape.treeOverStacked);
      expect(under.underTree, 300);
    });
  });

  test('1200 × 800 and 900 × 700, the narrow desktop windows', () {
    // Today's rule gave 372 and 322 here.
    final mid = RepertoireLayout.desktop(const Size(1200, 744));
    expect(mid.board, 676);
    expect(mid.paneWidth, 496);
    expect(mid.shape, RepertoireShape.treeOverStacked);
    expect(mid.underTree, 300);

    // Below 1000 wide the pane may be 400, as in Preparation.
    final narrow = RepertoireLayout.desktop(const Size(900, 644));
    expect(narrow.board, 472);
    expect(narrow.paneWidth, 400);
    expect(narrow.shape, RepertoireShape.treeOverStacked);
    expect(narrow.underTree, 300);
    expect(RepertoireLayout.desktop(const Size(1000, 2000)).paneWidth, 420);
    expect(RepertoireLayout.desktop(const Size(999, 2000)).paneWidth, 400);
  });

  test('the board-size setting only shrinks, and the tree takes the rest', () {
    final full = RepertoireLayout.desktop(const Size(1536, 736));
    final small = RepertoireLayout.desktop(const Size(1536, 736), scale: .6);
    expect(small.board, closeTo(668 * .6, 1e-9));
    expect(small.shape, RepertoireShape.threeColumns);
    expect(small.treeWidth - full.treeWidth,
        closeTo(full.board - small.board, 1e-9));
    final over = RepertoireLayout.desktop(const Size(1536, 736), scale: 1.4);
    expect(over.board, 668, reason: 'a setting over 1 must not overflow');
  });

  test('a window too small for a board gives none, not a negative one', () {
    final layout = RepertoireLayout.desktop(const Size(300, 100));
    expect(layout.board, 0);
    expect(layout.paneWidth, greaterThanOrEqualTo(0));
    expect(layout.treeWidth, greaterThanOrEqualTo(0));
  });
}
