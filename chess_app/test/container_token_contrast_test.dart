import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';

/// The container tokens carry their contrast guarantees here, not in a comment.
///
/// A container is a dark hued surface a widget sits *on*. That makes it the
/// opposite of every other semantic token in the palette, which are 400-level
/// foregrounds chosen to be legible on canvas — and it makes rule 23 wrong on
/// them: `canvas` on `successContainer` is 2.32:1, on `groupedContainer`
/// 1.56:1. Each container therefore ships with its own light on-container
/// foreground and its own border, and the numbers below are why those exact
/// values were chosen rather than the ones the proposal first suggested.
///
/// The ratios are recomputed from the tokens on every run. If somebody
/// retunes a container by a shade, this says so.
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

  group('on-container text clears AA body (4.5:1)', () {
    test('successContainer', () {
      expectAtLeast(
          ratio(colors.onSuccessContainer.toARGB32(),
              colors.successContainer.toARGB32()),
          4.5,
          'onSuccessContainer on successContainer');
    });
    test('groupedContainer', () {
      expectAtLeast(
          ratio(colors.onGroupedContainer.toARGB32(),
              colors.groupedContainer.toARGB32()),
          4.5,
          'onGroupedContainer on groupedContainer');
    });
    test('infoContainer', () {
      expectAtLeast(
          ratio(colors.onInfoContainer.toARGB32(),
              colors.infoContainer.toARGB32()),
          4.5,
          'onInfoContainer on infoContainer');
    });
  });

  group('container borders clear the 3:1 a UI boundary needs', () {
    test('successContainer', () {
      expectAtLeast(
          ratio(colors.successContainerBorder.toARGB32(),
              colors.successContainer.toARGB32()),
          3.0,
          'successContainerBorder on successContainer');
    });
    test('groupedContainer', () {
      expectAtLeast(
          ratio(colors.groupedContainerBorder.toARGB32(),
              colors.groupedContainer.toARGB32()),
          3.0,
          'groupedContainerBorder on groupedContainer');
    });
    test('infoContainer, bordered by info itself', () {
      // This is the one the proposal got wrong. Sky 600 gives 1.91:1 and the
      // recommended Sky 700 only 2.77:1; Sky 800 is why this passes.
      expectAtLeast(
          ratio(colors.info.toARGB32(), colors.infoContainer.toARGB32()),
          3.0,
          'info as a border on infoContainer');
    });
  });

  test('canvas is the wrong foreground on every container', () {
    // Rule 23 sends a light token used as a background to canvas. A container
    // is not a light token, and this is the measurement that says so. If one
    // of these ever climbs above 4.5, the container has stopped being dark and
    // the rule-23 exemption for it needs revisiting.
    for (final container in [
      colors.successContainer,
      colors.groupedContainer,
      colors.infoContainer,
    ]) {
      expect(
          ratio(colors.canvas.toARGB32(), container.toARGB32()), lessThan(4.5));
    }
  });

  test('canvasRecessed really is below canvas', () {
    expect(luminance(colors.canvasRecessed.toARGB32()),
        lessThan(luminance(colors.canvas.toARGB32())));
    expectAtLeast(
        ratio(colors.textPrimary.toARGB32(), colors.canvasRecessed.toARGB32()),
        4.5,
        'textPrimary on canvasRecessed');
  });
}
