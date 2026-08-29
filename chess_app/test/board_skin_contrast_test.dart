import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

import 'support/color_vision.dart';

/// Every colour pairing on a board, measured — and measured three times over:
/// as ordinary vision sees it, and as a protanope and a deuteranope do.
///
/// The catalogues are multiplied out in loops rather than listed as cases,
/// because a hand-written list stops covering the catalogue the moment somebody
/// adds to it. That was already true when this file only measured normal
/// vision; adding two more eyes to every pairing is the same argument again.
///
/// The bars below are not aspirations. Every one of them was measured first and
/// set to a number the catalogue already clears, so a failure here means
/// something was **added** that does not clear it — not that the bar was
/// hopeful. Where the real margin is much larger than the bar, the bar is still
/// the accessibility floor rather than the observed value, so that retuning a
/// skin has room to move without rewriting the test.
void main() {
  /// Runs [body] for normal vision and both modelled deficiencies, so nothing
  /// can be checked for one set of eyes and quietly skipped for the others.
  void forEachVision(void Function(ColorVision vision) body) {
    for (final vision in ColorVision.values) {
      body(vision);
    }
  }

  void expectAtLeast(double got, double bar, String what, ColorVision vision) {
    expect(got, greaterThanOrEqualTo(bar),
        reason: '$what: ${got.toStringAsFixed(2)}:1 for ${vision.label}, '
            'under the $bar:1 floor');
  }

  group('the simulation itself', () {
    // A measurement instrument gets checked before its readings are believed.
    // Same rule as everywhere else in this repo: prove the guard, then trust it.
    test('grey is untouched, because grey has no hue to lose', () {
      for (final grey in const [
        Color(0xFF000000),
        Color(0xFF737373),
        Color(0xFFFFFFFF),
      ]) {
        forEachVision((vision) {
          // Compared as the 32-bit colour that is actually drawn, not as the
          // four doubles behind it. The simulation goes sRGB -> linear ->
          // matrix -> sRGB, and that round trip lands a few parts in ten
          // thousand away from where it started; identical at every bit depth a
          // screen has, not identical as floating point. Asserting the latter
          // would be asserting a property the code does not have and does not
          // need.
          expect(simulate(grey, vision).toARGB32(), grey.toARGB32(),
              reason: '$grey for ${vision.label}');
        });
      }
    });

    test('red and green stop being told apart', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);

      // Normal vision separates them by hue completely; the ratio below is a
      // luminance ratio and is not the point — the point is the hue distance,
      // which collapses.
      forEachVision((vision) {
        final r = simulate(red, vision);
        final g = simulate(green, vision);
        if (vision == ColorVision.normal) {
          expect(r.g, lessThan(0.1), reason: 'red keeps no green');
          expect(g.r, lessThan(0.1), reason: 'green keeps no red');
        } else {
          // Both land on the same yellow axis: red and green channels equal
          // within rounding, which is what "cannot tell them apart by hue"
          // looks like as a number.
          expect((r.r - r.g).abs(), lessThan(0.01),
              reason: 'red is on the yellow axis for ${vision.label}');
          expect((g.r - g.g).abs(), lessThan(0.01),
              reason: 'green is on the yellow axis for ${vision.label}');
        }
      });
    });

    test('a 45% fill is measured composited, not as the token', () {
      // over() is the difference between measuring what is on the screen and
      // measuring what was passed to the paint call.
      const amber = Color(0x73FFC107);
      const square = Color(0xFFF0DAB5);
      final flattened = over(amber, square);
      expect(flattened.a, 1.0);
      expect(contrast(flattened, square),
          lessThan(contrast(const Color(0xFFFFC107), square)));
    });
  });

  group('pieces', () {
    test('fill separates from stroke and decoration for every kind of eye', () {
      // A piece whose fill and stroke are close is a silhouette: the knight
      // loses its eye and mane, the king its cross.
      for (final piece in PieceSkin.all) {
        forEachVision((vision) {
          expectAtLeast(contrastAs(piece.whiteFill, piece.whiteStroke, vision),
              3.0, '${piece.id} white fill vs stroke', vision);
          expectAtLeast(
              contrastAs(piece.blackFill, piece.blackDecoration, vision),
              3.0,
              '${piece.id} black fill vs decoration',
              vision);
        });
      }
    });

    test(
        'the stroke clears 3.0:1 on both squares of every board, for every '
        'kind of eye', () {
      // The bar belongs to the stroke, not the fill: white fill on a pale
      // square is about 1.3:1 and always has been, because the black outline is
      // what draws a white piece.
      for (final piece in PieceSkin.all) {
        for (final board in BoardSkin.all) {
          forEachVision((vision) {
            for (final (name, stroke, square) in [
              (
                'white stroke, light square',
                piece.whiteStroke,
                board.lightSquare
              ),
              (
                'white stroke, dark square',
                piece.whiteStroke,
                board.darkSquare
              ),
              (
                'black stroke, light square',
                piece.blackStroke,
                board.lightSquare
              ),
              (
                'black stroke, dark square',
                piece.blackStroke,
                board.darkSquare
              ),
            ]) {
              expectAtLeast(contrastAs(stroke, square, vision), 3.0,
                  '${piece.id} on ${board.id} — $name', vision);
            }
          });
        }
      }
    });
  });

  group('boards', () {
    test('the two squares stay apart for every kind of eye', () {
      for (final board in BoardSkin.all) {
        forEachVision((vision) {
          expectAtLeast(contrastAs(board.lightSquare, board.darkSquare, vision),
              1.5, '${board.id} light vs dark square', vision);
        });
      }
    });
  });

  group('the last-move marker', () {
    // The finding that started this, on 29.8.2026: the marker is `warning` at
    // 45% plus a 2.5 px border of the same colour, and against the square
    // underneath it that is almost pure hue. These two tests are the pair that
    // matters — the first records why the brackets exist, the second asserts
    // that they do the job.

    test('the amber alone is a hue signal and almost nothing else', () {
      // Deliberately an upper bound, not a floor. Asserting "the amber is bad"
      // as a minimum would punish anyone who improves the palette later; what
      // this pins down is that on *some* skin it is this weak, which is the
      // fact the bracket design rests on. If a palette change ever makes even
      // the worst case strong, this test says so by failing, and the brackets
      // become a choice rather than a fix.
      var worst = double.infinity;
      String where = '';

      for (final (name, tokens) in [
        ('dark', AppColorTokens.dark),
        ('light', AppColorTokens.light),
      ]) {
        for (final board in BoardSkin.all) {
          for (final (side, square) in [
            ('light', board.lightSquare),
            ('dark', board.darkSquare),
          ]) {
            final marked = over(tokens.warning.withValues(alpha: 0.45), square);
            forEachVision((vision) {
              final value = contrastAs(marked, square, vision);
              if (value < worst) {
                worst = value;
                where = '$name palette, ${board.id}, $side square, '
                    '${vision.label}';
              }
            });
          }
        }
      }

      expect(worst, lessThan(1.2),
          reason: 'the worst amber-on-square case measures '
              '${worst.toStringAsFixed(2)}:1 ($where). If this now passes 1.2, '
              'the palette improved and this test should be revisited rather '
              'than relaxed.');
    });

    test('the brackets always keep an edge, on every square of every skin', () {
      // The invariant the two-tone bracket exists for: black and white are both
      // drawn, so whichever square the marker lands on, one of them has a
      // luminance edge on it. 3.0:1 is the WCAG floor for a non-text UI
      // element, which is what this is.
      for (final board in BoardSkin.all) {
        for (final (side, square) in [
          ('light', board.lightSquare),
          ('dark', board.darkSquare),
        ]) {
          forEachVision((vision) {
            final shade = contrastAs(
                ChessBoardPainter.lastMoveMarkerShade, square, vision);
            final light = contrastAs(
                ChessBoardPainter.lastMoveMarkerLight, square, vision);
            final best = shade > light ? shade : light;

            expectAtLeast(
                best, 3.0, 'brackets on ${board.id} $side square', vision);
          });
        }
      }
    });

    test('the bracket colours do not move, and the amber does', () {
      // The difference between the two channels, stated as the one thing that
      // is actually true of it. An earlier version of this test asserted that
      // the bracket's *contrast* against a square is the same for every kind of
      // eye, and that is false — the square moves even when the bracket does
      // not, so the pairing moves with it. What holds is narrower and is the
      // whole design: the bracket carries no hue to lose, so it looks the same
      // to everybody, while the amber does not and does not.
      for (final marker in [
        ChessBoardPainter.lastMoveMarkerShade,
        ChessBoardPainter.lastMoveMarkerLight,
      ]) {
        forEachVision((vision) {
          expect(simulate(marker, vision).toARGB32(), marker.toARGB32(),
              reason: 'the bracket must look the same for ${vision.label}');
        });
      }

      // And the colour channel, for contrast with the above: `warning` is a
      // different colour to a protanope than it is to a trichromat. That is not
      // a defect in the token — it is the reason a second channel exists.
      for (final tokens in [AppColorTokens.dark, AppColorTokens.light]) {
        for (final vision in [
          ColorVision.protanopia,
          ColorVision.deuteranopia,
        ]) {
          expect(simulate(tokens.warning, vision).toARGB32(),
              isNot(tokens.warning.toARGB32()),
              reason: 'warning is expected to shift for ${vision.label}');
        }
      }
    });
  });
}
