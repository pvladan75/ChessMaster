import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/arrow_colors.dart';

import 'support/color_vision.dart';

/// The five arrow colours, measured three times over: as ordinary vision sees
/// them, and as a protanope and a deuteranope do.
///
/// Structure and the first two tests are batch 47's, which measured correctly
/// and reported honestly. What is added here is the half its brief only asked
/// for in prose: **that a colour is still recognisable as its own name.** Round
/// one satisfied every number it was given and produced an orange of `#88370E`,
/// which is brown — not carelessness, but the predictable result of one
/// requirement being a bar and the other being a sentence. It is a bar now.
void main() {
  /// Where each name lives on the colour wheel. These are the anchors the
  /// Serbian names promise, and the reason a drift bound exists at all.
  const anchors = {
    'R': 0.0,
    'O': 30.0,
    'G': 120.0,
    'B': 230.0,
    'P': 285.0,
  };

  /// Distance between two hues on a circle, so 350° and 10° are 20° apart
  /// rather than 340°.
  double hueGap(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  group('the five are told apart', () {
    test('every pair clears 1.5:1 under every kind of vision', () {
      // 1.5 is not a preference. With the five held within 20 degrees of their
      // own names, a search of the space puts the ceiling at exactly 1.50 —
      // under both deficiencies these collapse onto two hue axes, so all five
      // must separate by luminance alone, and a lightness band that keeps them
      // off black and white caps how far that can go. Reaching 1.77 is possible
      // and costs the names; the missing separation is carried by the arrow's
      // halo instead, which is a channel and not a colour.
      for (var i = 0; i < ArrowColor.all.length; i++) {
        for (var j = i + 1; j < ArrowColor.all.length; j++) {
          final a = ArrowColor.all[i];
          final b = ArrowColor.all[j];
          for (final vision in ColorVision.values) {
            final c = contrastAs(a.color, b.color, vision);
            expect(c, greaterThanOrEqualTo(1.5),
                reason: '${a.id} vs ${b.id} for ${vision.label}: '
                    '${c.toStringAsFixed(3)}:1');
          }
        }
      }
    });

    test('no colour vanishes into its own halo', () {
      // The arrow is drawn over a two-tone achromatic halo, so a colour that
      // sits on top of black *and* on top of white loses the outline that makes
      // it visible on any square. Both directions, worst vision, because the
      // colour moves under simulation even though black and white do not.
      for (final arrow in ArrowColor.all) {
        for (final vision in ColorVision.values) {
          expect(contrastAs(arrow.color, const Color(0xFF000000), vision),
              greaterThanOrEqualTo(1.1),
              reason: '${arrow.id} is too close to black for ${vision.label}');
          expect(contrastAs(arrow.color, const Color(0xFFFFFFFF), vision),
              greaterThanOrEqualTo(1.1),
              reason: '${arrow.id} is too close to white for ${vision.label}');
        }
      }
    });
  });

  group('the five are still their own names', () {
    test('each stays within 20 degrees of the hue its name promises', () {
      for (final arrow in ArrowColor.all) {
        final hsl = HSLColor.fromColor(arrow.color);
        final anchor = anchors[arrow.id];
        expect(anchor, isNotNull, reason: 'no anchor for ${arrow.id}');
        expect(hueGap(hsl.hue, anchor!), lessThanOrEqualTo(20.0),
            reason: '${arrow.id} "${arrow.name}" is at hue '
                '${hsl.hue.toStringAsFixed(0)}, and ${arrow.name} lives at '
                '$anchor');
      }
    });

    test('none is washed out, and no warm one has gone brown', () {
      // Two ways a colour stops being its name without its hue moving at all: a
      // red at lightness 0.85 is pink, and one at 0.15 is maroon.
      //
      // The floor is **not** the same for every hue, and the first version of
      // this test was wrong for assuming it was. A single band of 0.28-0.80 let
      // `#88370E` through — hue 20, inside orange's drift allowance, lightness
      // 0.29, inside the band — and that colour is brown. It was round one's
      // orange and it is the exact thing this group exists to catch; it was
      // caught by the *pair* test instead, which is luck rather than coverage.
      //
      // Warm hues lose their name when darkened and cool ones do not: dark
      // orange is brown, dark red is maroon, dark yellow is olive, while navy
      // is still recognisably blue and a dark violet is still purple. So the
      // floor is 0.45 for anything in the red-to-yellow arc and 0.28 elsewhere.
      for (final arrow in ArrowColor.all) {
        final hsl = HSLColor.fromColor(arrow.color);
        final warm = hsl.hue <= 60 || hsl.hue >= 340;
        final floor = warm ? 0.45 : 0.28;

        expect(hsl.lightness, greaterThanOrEqualTo(floor),
            reason: '${arrow.id} "${arrow.name}" is at lightness '
                '${hsl.lightness.toStringAsFixed(2)}, under the '
                '${warm ? "warm" : "cool"} floor of $floor — a warm hue this '
                'dark is brown, whatever its hue says');
        expect(hsl.lightness, lessThanOrEqualTo(0.80),
            reason: '${arrow.id} lightness '
                '${hsl.lightness.toStringAsFixed(2)} is washed out');
        expect(hsl.saturation, greaterThanOrEqualTo(0.55),
            reason: '${arrow.id} saturation '
                '${hsl.saturation.toStringAsFixed(2)}');
      }
    });

    test('red stays below orange in hue, and clearly', () {
      // Red and orange are only 30 degrees apart natively, so a 20 degree drift
      // allowance lets them cross. A picker listing "crvena" above
      // "narandžasta" where the first is the oranger of the two is worse than
      // either being slightly off its anchor.
      final red = HSLColor.fromColor(ArrowColor.r.color).hue;
      final orange = HSLColor.fromColor(ArrowColor.o.color).hue;
      expect(orange - red, greaterThanOrEqualTo(15.0),
          reason: 'crvena is at $red, narandžasta at $orange');
    });
  });

  group('the catalogue holds its shape', () {
    test('the ids are the five that are stored in saved arrows', () {
      expect(
          ArrowColor.all.map((a) => a.id).toList(), ['R', 'O', 'G', 'B', 'P']);
    });

    test('an unknown id draws something that means nothing', () {
      // Not one of the five: green *means* the engine's best line, so falling
      // back to it would draw a specific claim about an arrow nobody can read.
      expect(ArrowColor.byId('nonsense'), ArrowColor.fallback);
      expect(ArrowColor.byId(null), ArrowColor.fallback);
      expect(ArrowColor.all, isNot(contains(ArrowColor.fallback)));
      for (final arrow in ArrowColor.all) {
        expect(arrow.color, isNot(ArrowColor.fallback.color));
      }
    });

    test('every id resolves to itself', () {
      for (final arrow in ArrowColor.all) {
        expect(ArrowColor.byId(arrow.id), arrow);
      }
    });
  });
}
