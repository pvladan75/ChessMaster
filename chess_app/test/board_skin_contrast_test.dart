import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/board_skins.dart';

double _luminance(Color color) {
  double calc(double c) {
    if (c <= 0.03928) return c / 12.92;
    return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * calc(color.r) +
      0.7152 * calc(color.g) +
      0.0722 * calc(color.b);
}

double _contrast(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('BoardSkin and PieceSkin Contrast', () {
    test('Every piece skin fill vs stroke/decoration is >= 3.0:1', () {
      for (final pieceSkin in PieceSkin.all) {
        final wFillStroke =
            _contrast(pieceSkin.whiteFill, pieceSkin.whiteStroke);
        final bFillDec =
            _contrast(pieceSkin.blackFill, pieceSkin.blackDecoration);

        expect(wFillStroke, greaterThanOrEqualTo(3.0),
            reason: '${pieceSkin.id} white fill vs stroke');
        expect(bFillDec, greaterThanOrEqualTo(3.0),
            reason: '${pieceSkin.id} black fill vs decoration');
      }
    });

    test('Piece stroke clears 3.0:1 against both squares of every board skin',
        () {
      for (final pieceSkin in PieceSkin.all) {
        for (final boardSkin in BoardSkin.all) {
          final wStrokeLight =
              _contrast(pieceSkin.whiteStroke, boardSkin.lightSquare);
          final wStrokeDark =
              _contrast(pieceSkin.whiteStroke, boardSkin.darkSquare);
          final bStrokeLight =
              _contrast(pieceSkin.blackStroke, boardSkin.lightSquare);
          final bStrokeDark =
              _contrast(pieceSkin.blackStroke, boardSkin.darkSquare);

          expect(wStrokeLight, greaterThanOrEqualTo(3.0),
              reason: '${pieceSkin.id} wStroke on ${boardSkin.id} light');
          expect(wStrokeDark, greaterThanOrEqualTo(3.0),
              reason: '${pieceSkin.id} wStroke on ${boardSkin.id} dark');
          expect(bStrokeLight, greaterThanOrEqualTo(3.0),
              reason: '${pieceSkin.id} bStroke on ${boardSkin.id} light');
          expect(bStrokeDark, greaterThanOrEqualTo(3.0),
              reason: '${pieceSkin.id} bStroke on ${boardSkin.id} dark');
        }
      }
    });

    test('Board squares contrast is at least 1.5:1', () {
      for (final boardSkin in BoardSkin.all) {
        final squareContrast =
            _contrast(boardSkin.lightSquare, boardSkin.darkSquare);
        expect(squareContrast, greaterThanOrEqualTo(1.5),
            reason: '${boardSkin.id} squares');
      }
    });
  });
}
