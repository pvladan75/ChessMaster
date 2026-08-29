import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';

void main() {
  const colors = AppColorTokens.light;

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

  final lightSurfaces = {
    'canvas': colors.canvas,
    'surface': colors.surface,
    'surfaceRaised': colors.surfaceRaised,
  };

  group('Semantic accents on light surfaces', () {
    final criticalSemantics = {
      'accent': colors.accent,
      'info': colors.info,
      'warning': colors.warning,
      'danger': colors.danger,
      'success': colors.success,
    };

    final supportingSemantics = {
      'accentAlt': colors.accentAlt,
      'brand': colors.brand,
    };

    for (final surfaceEntry in lightSurfaces.entries) {
      final surfaceName = surfaceEntry.key;
      final surfaceColor = surfaceEntry.value;

      test('Critical semantics >= 4.5 on $surfaceName', () {
        for (final entry in criticalSemantics.entries) {
          expectAtLeast(ratio(entry.value.toARGB32(), surfaceColor.toARGB32()),
              4.5, '${entry.key} on $surfaceName');
        }
      });

      test('Supporting semantics >= 3.0 on $surfaceName', () {
        for (final entry in supportingSemantics.entries) {
          expectAtLeast(ratio(entry.value.toARGB32(), surfaceColor.toARGB32()),
              3.0, '${entry.key} on $surfaceName');
        }
      });
    }
  });

  group('Containers in light mode', () {
    test('successContainer', () {
      expectAtLeast(
          ratio(colors.onSuccessContainer.toARGB32(),
              colors.successContainer.toARGB32()),
          4.5,
          'onSuccessContainer on successContainer');
      expectAtLeast(
          ratio(colors.successContainerBorder.toARGB32(),
              colors.successContainer.toARGB32()),
          3.0,
          'successContainerBorder on successContainer');
    });
    test('groupedContainer', () {
      expectAtLeast(
          ratio(colors.onGroupedContainer.toARGB32(),
              colors.groupedContainer.toARGB32()),
          4.5,
          'onGroupedContainer on groupedContainer');
      expectAtLeast(
          ratio(colors.groupedContainerBorder.toARGB32(),
              colors.groupedContainer.toARGB32()),
          3.0,
          'groupedContainerBorder on groupedContainer');
    });
    test('infoContainer', () {
      expectAtLeast(
          ratio(colors.onInfoContainer.toARGB32(),
              colors.infoContainer.toARGB32()),
          4.5,
          'onInfoContainer on infoContainer');
      expectAtLeast(
          ratio(colors.info.toARGB32(), colors.infoContainer.toARGB32()),
          3.0,
          'info as a border on infoContainer');
    });
    test('dangerContainer', () {
      expectAtLeast(
          ratio(colors.onDangerContainer.toARGB32(),
              colors.dangerContainer.toARGB32()),
          4.5,
          'onDangerContainer on dangerContainer');
      expectAtLeast(
          ratio(colors.dangerContainerBorder.toARGB32(),
              colors.dangerContainer.toARGB32()),
          3.0,
          'dangerContainerBorder on dangerContainer');
    });
  });

  group('Side tokens', () {
    test('Separate from each other past 3.0', () {
      // sideWhite and sideBlack are the extremes. sideDraw is in the middle.
      expectAtLeast(
          ratio(colors.sideWhite.toARGB32(), colors.sideDraw.toARGB32()),
          3.0,
          'sideWhite vs sideDraw');
      expectAtLeast(
          ratio(colors.sideDraw.toARGB32(), colors.sideBlack.toARGB32()),
          3.0,
          'sideDraw vs sideBlack');
    });
  });

  group('The default button style', () {
    // The brief asked for this pair by name, and the reason is on the record:
    // the dark pass shipped white on `brand` at 2.72:1 documented as 4.5 — as
    // the *default* filled-button style, so for the whole application rather
    // than one screen. A palette is not finished until the thing every screen
    // presses has been measured.
    test("a filled button's label reads on its own background", () {
      expectAtLeast(ratio(0xFFFFFFFF, colors.brand.toARGB32()), 4.5,
          'FilledButton foreground on brand');
    });

    test('every on-colour in the light ColorScheme reads on its own', () {
      expectAtLeast(ratio(0xFFFFFFFF, colors.accent.toARGB32()), 4.5,
          'onSecondary on accent');
      expectAtLeast(ratio(0xFFFFFFFF, colors.accentAlt.toARGB32()), 4.5,
          'onTertiary on accentAlt');
      expectAtLeast(ratio(0xFFFFFFFF, colors.danger.toARGB32()), 4.5,
          'onError on danger');
    });
  });

  group('Text tokens', () {
    for (final surfaceEntry in lightSurfaces.entries) {
      final surfaceName = surfaceEntry.key;
      final surfaceColor = surfaceEntry.value;

      test('Text tokens on $surfaceName', () {
        expectAtLeast(
            ratio(colors.textPrimary.toARGB32(), surfaceColor.toARGB32()),
            4.5,
            'textPrimary on $surfaceName');
        expectAtLeast(
            ratio(colors.textSecondary.toARGB32(), surfaceColor.toARGB32()),
            4.5,
            'textSecondary on $surfaceName');
        // textMuted only needs 3.0 on surfaceRaised, but 4.5 on canvas/surface
        if (surfaceName == 'surfaceRaised') {
          expectAtLeast(
              ratio(colors.textMuted.toARGB32(), surfaceColor.toARGB32()),
              3.0,
              'textMuted on $surfaceName');
        } else {
          expectAtLeast(
              ratio(colors.textMuted.toARGB32(), surfaceColor.toARGB32()),
              4.5,
              'textMuted on $surfaceName');
        }
      });
    }
  });
}
