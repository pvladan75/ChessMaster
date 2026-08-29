import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';

/// The side tokens contrast tests.
///
/// A side token represents a side of the board (White, Draw, or Black)
/// as painted by the explorer or the evaluation bar.
void main() {
  const colors = AppColorTokens.dark;

  // WCAG 2.1 relative luminance and contrast, written out rather than
  // imported: a test that shares an implementation with the thing it checks
  // proves the two agree, not that either is right.
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  double luminance(int argb) {
    final r = channel(((argb >> 16) & 0xFF) / 255);
    final g = channel(((argb >> 8) & 0xFF) / 255);
    final b = channel((argb & 0xFF) / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  double ratio(int fg, int bg) {
    final a = luminance(fg), b = luminance(bg);
    final hi = math.max(a, b), lo = math.min(a, b);
    return (hi + 0.05) / (lo + 0.05);
  }

  void expectAtLeast(double got, double bar, String what) {
    expect(got, greaterThanOrEqualTo(bar),
        reason: '$what measures ${got.toStringAsFixed(2)}:1, under $bar:1');
  }

  group('side tokens separate from each other', () {
    test('sideWhite vs sideDraw', () {
      final r = ratio(colors.sideWhite.toARGB32(), colors.sideDraw.toARGB32());
      expectAtLeast(r, 3.0, 'sideWhite vs sideDraw');
    });
    test('sideDraw vs sideBlack', () {
      final r = ratio(colors.sideDraw.toARGB32(), colors.sideBlack.toARGB32());
      expectAtLeast(r, 3.0, 'sideDraw vs sideBlack');
    });
    test('sideWhite vs sideBlack', () {
      final r = ratio(colors.sideWhite.toARGB32(), colors.sideBlack.toARGB32());
      expectAtLeast(r, 4.5, 'sideWhite vs sideBlack');
    });
  });

  group('sideWhite against surfaces', () {
    test('sideWhite on canvas', () {
      final r = ratio(colors.sideWhite.toARGB32(), colors.canvas.toARGB32());
      expectAtLeast(r, 3.0, 'sideWhite on canvas');
    });
    test('sideWhite on surface', () {
      final r = ratio(colors.sideWhite.toARGB32(), colors.surface.toARGB32());
      expectAtLeast(r, 3.0, 'sideWhite on surface');
    });
    test('sideWhite on surfaceRaised', () {
      final r =
          ratio(colors.sideWhite.toARGB32(), colors.surfaceRaised.toARGB32());
      expectAtLeast(r, 3.0, 'sideWhite on surfaceRaised');
    });
  });

  group('sideBlack against surfaces is below 3.0', () {
    test('sideBlack on canvas', () {
      final r = ratio(colors.sideBlack.toARGB32(), colors.canvas.toARGB32());
      expect(r, lessThan(3.0),
          reason: 'A painted sideBlack on canvas needs borderStrong. '
              'It measures ${r.toStringAsFixed(2)}:1');
    });
    test('sideBlack on surface', () {
      final r = ratio(colors.sideBlack.toARGB32(), colors.surface.toARGB32());
      expect(r, lessThan(3.0),
          reason: 'A painted sideBlack on surface needs borderStrong. '
              'It measures ${r.toStringAsFixed(2)}:1');
    });
    test('sideBlack on surfaceRaised', () {
      final r =
          ratio(colors.sideBlack.toARGB32(), colors.surfaceRaised.toARGB32());
      expect(r, lessThan(3.0),
          reason: 'A painted sideBlack on surfaceRaised needs borderStrong. '
              'It measures ${r.toStringAsFixed(2)}:1');
    });
  });

  // The comments beside these tokens in app_colors.dart quote a ratio each.
  // Prose goes stale silently; a retuned shade would leave the numbers behind
  // and nothing would say so. These recompute what the comments claim.
  group('the documented ratios are the measured ones', () {
    void expectRatio(double got, double want, String what) {
      expect(got, closeTo(want, 0.005),
          reason: '$what is documented as $want:1 and measures '
              '${got.toStringAsFixed(2)}:1 -- fix whichever is wrong');
    }

    test('sideWhite on the three surfaces', () {
      expectRatio(ratio(colors.sideWhite.toARGB32(), colors.canvas.toARGB32()),
          16.30, 'sideWhite on canvas');
      expectRatio(ratio(colors.sideWhite.toARGB32(), colors.surface.toARGB32()),
          13.35, 'sideWhite on surface');
      expectRatio(
          ratio(colors.sideWhite.toARGB32(), colors.surfaceRaised.toARGB32()),
          9.45,
          'sideWhite on surfaceRaised');
    });

    test('sideDraw on the three surfaces', () {
      expectRatio(ratio(colors.sideDraw.toARGB32(), colors.canvas.toARGB32()),
          3.75, 'sideDraw on canvas');
      expectRatio(ratio(colors.sideDraw.toARGB32(), colors.surface.toARGB32()),
          3.07, 'sideDraw on surface');
      expectRatio(
          ratio(colors.sideDraw.toARGB32(), colors.surfaceRaised.toARGB32()),
          2.18,
          'sideDraw on surfaceRaised');
    });

    test('sideBlack on the three surfaces', () {
      expectRatio(ratio(colors.sideBlack.toARGB32(), colors.canvas.toARGB32()),
          1.13, 'sideBlack on canvas');
      expectRatio(ratio(colors.sideBlack.toARGB32(), colors.surface.toARGB32()),
          1.38, 'sideBlack on surface');
      expectRatio(
          ratio(colors.sideBlack.toARGB32(), colors.surfaceRaised.toARGB32()),
          1.95,
          'sideBlack on surfaceRaised');
    });

    test('the three bars against each other', () {
      expectRatio(
          ratio(colors.sideWhite.toARGB32(), colors.sideDraw.toARGB32()),
          4.34,
          'sideWhite vs sideDraw');
      expectRatio(
          ratio(colors.sideDraw.toARGB32(), colors.sideBlack.toARGB32()),
          4.24,
          'sideDraw vs sideBlack');
      expectRatio(
          ratio(colors.sideWhite.toARGB32(), colors.sideBlack.toARGB32()),
          18.41,
          'sideWhite vs sideBlack');
    });
  });
}
