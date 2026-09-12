import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
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

  group('the last-move wash', () {
    // The marker this replaced was amber at 45% over the pieces, and the two
    // tests that stood here recorded why it needed corner brackets: it measured
    // 1.03:1 at worst against the square beneath it, which is a hue signal and
    // not a luminance one. The wash that replaced it on 12.9.2026 is asked the
    // same two questions, and answers them without a second channel.

    test('a washed square reads as darker than the same square unwashed', () {
      // The comparison a reader actually makes: this square against another
      // square of the same colour elsewhere on the board. 1.4:1 is just under
      // the measured worst case, and is the same order as the 1.5:1 that
      // `ArrowColor` holds between its own pairs — a floor for "these two are
      // not the same shade", not the 3.0:1 of an element against a background.
      var worst = double.infinity;
      var where = '';

      for (final board in BoardSkin.all) {
        for (final (side, square) in [
          ('light', board.lightSquare),
          ('dark', board.darkSquare),
        ]) {
          final washed = over(LastMovePainter.wash, square);
          forEachVision((vision) {
            final value = contrastAs(washed, square, vision);
            if (value < worst) {
              worst = value;
              where = '${board.id}, $side square, ${vision.label}';
            }
            expectAtLeast(
                value, 1.4, 'the wash on ${board.id} $side square', vision);
          });
        }
      }

      // Printed rather than pinned: the alpha is a live judgement — the owner
      // decides whether it is loud enough on a real screen — and a test that
      // fixed the number would fail the moment that judgement is acted on.
      // ignore: avoid_print
      print('worst washed-vs-plain contrast: '
          '${worst.toStringAsFixed(2)}:1 at $where');
    });

    test(
        'the wash looks the same to everybody, which is why it needs no '
        'second channel', () {
      // The whole argument for black rather than a colour. The amber it
      // replaced is a different colour to a protanope than to a trichromat —
      // asserted below, because that difference is the reason brackets existed
      // — and a wash with no hue in it has nothing to lose.
      forEachVision((vision) {
        expect(simulate(LastMovePainter.wash, vision).toARGB32(),
            LastMovePainter.wash.toARGB32(),
            reason: 'the wash must look the same for ${vision.label}');
      });

      // And a square with the wash on it moves only as much as the square
      // itself does: the compositing adds no hue of its own.
      for (final board in BoardSkin.all) {
        for (final square in [board.lightSquare, board.darkSquare]) {
          final washed = over(LastMovePainter.wash, square);
          for (final vision in [
            ColorVision.protanopia,
            ColorVision.deuteranopia,
          ]) {
            expect(simulate(washed, vision).toARGB32(),
                over(LastMovePainter.wash, simulate(square, vision)).toARGB32(),
                reason:
                    'washing ${board.id} and then simulating ${vision.label} '
                    'must give the same colour as simulating and then washing');
          }
        }
      }

      for (final tokens in [AppColorTokens.dark, AppColorTokens.light]) {
        for (final vision in [
          ColorVision.protanopia,
          ColorVision.deuteranopia,
        ]) {
          expect(simulate(tokens.warning, vision).toARGB32(),
              isNot(tokens.warning.toARGB32()),
              reason: 'warning is expected to shift for ${vision.label} — that '
                  'shift is what the wash was chosen to avoid');
        }
      }
    });
  });

  group('the [%csl] ring', () {
    test('the csl ring keeps an edge on every square of every skin', () {
      // The same invariant as the brackets above, for the ring `[%csl]` is
      // drawn as, and it matters more here. An arrow is a shape with a
      // direction and survives with no colour at all; a coloured *square* is
      // only its colour unless something else carries it — so the two
      // achromatic passes are not a refinement of the ring, they are the ring.
      for (final board in BoardSkin.all) {
        for (final (side, square) in [
          ('light', board.lightSquare),
          ('dark', board.darkSquare),
        ]) {
          forEachVision((vision) {
            final shade = contrastAs(
                ChessBoardPainter.squareMarkHaloShade, square, vision);
            final light = contrastAs(
                ChessBoardPainter.squareMarkHaloLight, square, vision);
            final best = shade > light ? shade : light;

            expectAtLeast(
                best, 3.0, 'csl ring on ${board.id} $side square', vision);
          });
        }
      }
    });

    test('the ring outline carries no hue, for any eye', () {
      for (final halo in [
        ChessBoardPainter.squareMarkHaloShade,
        ChessBoardPainter.squareMarkHaloLight,
      ]) {
        forEachVision((vision) {
          expect(simulate(halo, vision).toARGB32(), halo.toARGB32(),
              reason:
                  'the ring outline must look the same for ${vision.label}');
        });
      }
    });

    test('the three passes nest, widest first', () {
      // This used to reproduce the ring's radius arithmetic, and when the ring
      // became a frame on 12.9.2026 it went on passing while asserting a
      // formula that no longer existed anywhere. What is left here is the part
      // that is about the design rather than about the maths: widest first,
      // colour last and narrowest, or the halo covers the thing it is there to
      // make legible. Where the strokes land is asked of the rendering, in
      // `square_marks_test.dart`.
      const core = ChessBoardPainter.squareMarkCoreFraction;
      const shade = ChessBoardPainter.squareMarkShadeFraction;
      const light = ChessBoardPainter.squareMarkLightFraction;

      expect(shade, greaterThan(light));
      expect(light, greaterThan(core));

      // And the widest cannot meet itself across the square, which would be a
      // filled square rather than a frame — the one thing this shape may not
      // become, because the piece underneath has to stay readable.
      expect(shade, lessThan(0.5));
    });
  });
}
