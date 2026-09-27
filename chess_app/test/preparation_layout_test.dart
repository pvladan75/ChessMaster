// The rule the Preparation screen is laid out by — D11 of
// `docs/PLAN-PRIPREMA.md`, phase 1.
//
// **Every expected number here is a literal.** A test that read
// `PreparationLayout.padding` to compute what it expects would follow the
// constant wherever it moved; these are the sizes the owner chose from the
// sketches, less what the real rows under the board turned out to need, and a
// change to any constant has to answer to them.
//
// Body = the window less the bar: 56 on a desktop window and on a phone held
// upright.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/preparation/services/preparation_layout.dart';

void main() {
  group('a desktop window', () {
    // window, board today (the room's 62% rule), board sketched, board now.
    const windows = [
      (Size(1536, 792), 491, 600, 608.0),
      (Size(1200, 800), 496, 608, 616.0),
      (Size(900, 700), 269, 440, 442.0),
    ];

    for (final (window, today, sketched, now) in windows) {
      final name = '${window.width.toInt()} × ${window.height.toInt()}';
      test('$name gives a board of $now', () {
        final layout = PreparationLayout.desktop(
          Size(window.width, window.height - 56),
        );
        expect(layout.board, now);
        expect(layout.board, greaterThanOrEqualTo(today),
            reason: 'never under what the room gives today');
        expect((layout.board - sketched).abs(), lessThanOrEqualTo(16),
            reason: 'within 16 px of the sketch the owner chose (D11)');
      });
    }

    test('the board, the rows under it and the padding fill the height', () {
      // 736 of body: 8 + 608 + 4 + 56 + 4 + 48 + 8.
      final layout = PreparationLayout.desktop(const Size(1536, 736));
      expect(8 + layout.board + 4 + 56 + 4 + 48 + 8, 736);
    });

    test('the board, its bar\'s place, the gap and the pane fill the width',
        () {
      for (final body in const [Size(1536, 736), Size(900, 644)]) {
        final layout = PreparationLayout.desktop(body);
        expect(
            8 + 22 + 8 + layout.board + 12 + layout.paneWidth + 8, body.width);
      }
    });

    test('the pane is never under 420, and never under 400 below 1000 wide',
        () {
      expect(PreparationLayout.desktop(const Size(1000, 2000)).paneWidth, 420);
      expect(PreparationLayout.desktop(const Size(999, 2000)).paneWidth, 400);
      expect(PreparationLayout.desktop(const Size(900, 2000)).paneWidth, 400);
    });

    test('comment and engine stand side by side from a pane of 480', () {
      // 1200 × 800: board 616, pane 1200 − 16 − 30 − 12 − 616 = 526.
      final wide = PreparationLayout.desktop(const Size(1200, 744));
      expect(wide.paneWidth, 526);
      expect(wide.commentBesideEngine, isTrue);
      // 900 × 700: the pane is its minimum, 400.
      final narrow = PreparationLayout.desktop(const Size(900, 644));
      expect(narrow.paneWidth, 400);
      expect(narrow.commentBesideEngine, isFalse);
      // The boundary itself: a body 2000 tall and wide enough for a pane of
      // exactly 480 beside a board bound by the width.
      //   board = W − 16 − 12 − 420 − 30, pane = W − 58 − board = 420 …
      // so where the width binds the pane is its minimum; 480 is reached only
      // where the height binds. Height 600: board 600 − 16 − 112 = 472.
      final at = PreparationLayout.desktop(const Size(472 + 58 + 480, 600));
      expect(at.board, 472);
      expect(at.paneWidth, 480);
      expect(at.commentBesideEngine, isTrue);
      final under = PreparationLayout.desktop(const Size(472 + 58 + 479, 600));
      expect(under.paneWidth, 479);
      expect(under.commentBesideEngine, isFalse);
    });

    test('the board-size setting only shrinks, and the pane takes the rest',
        () {
      final full = PreparationLayout.desktop(const Size(1536, 736));
      final small = PreparationLayout.desktop(const Size(1536, 736), scale: .6);
      expect(small.board, closeTo(608 * .6, 1e-9));
      expect(small.paneWidth - full.paneWidth,
          closeTo(full.board - small.board, 1e-9));
      final over = PreparationLayout.desktop(const Size(1536, 736), scale: 1.4);
      expect(over.board, 608, reason: 'a setting over 1 must not overflow');
    });

    test('a window too small for a board gives none, not a negative one', () {
      final layout = PreparationLayout.desktop(const Size(300, 100));
      expect(layout.board, 0);
      expect(layout.paneWidth, greaterThanOrEqualTo(0));
    });
  });

  group('a phone held upright', () {
    test('360 wide gives a board of 344, over the 324 the room gives today',
        () {
      final layout = PreparationLayout.phone(const Size(360, 584));
      expect(layout.board, 344);
      expect(layout.marks, MarkingDensity.tight);
    });
  });

  group('the marking bar', () {
    test('is labelled from 760, icons from 420, and one colour button under',
        () {
      expect(PreparationLayout.marksFor(760), MarkingDensity.regular);
      expect(PreparationLayout.marksFor(759.9), MarkingDensity.compact);
      expect(PreparationLayout.marksFor(420), MarkingDensity.compact);
      expect(PreparationLayout.marksFor(419.9), MarkingDensity.tight);
    });

    test('is icons at all three desktop windows of the sketches', () {
      for (final body in const [
        Size(1536, 736),
        Size(1200, 744),
        Size(900, 644)
      ]) {
        expect(PreparationLayout.desktop(body).marks, MarkingDensity.compact);
      }
    });
  });
}
