import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/arrow_color_button.dart';

import 'support/color_vision.dart';

/// The wiring, asserted where it is painted.
///
/// `arrow_color_contrast_test.dart` proves the five values are far enough apart
/// and still deserve their names. That is a statement about a catalogue, and it
/// would go on passing if nothing ever drew from it — which is the shape of bug
/// this codebase keeps finding. This file is the other half: the arrows reach
/// the canvas in those colours, they reach it wearing an outline, and the two
/// pieces of text that stand on an arrow colour are legible on it.
void main() {
  const overlayKey = ValueKey('overlay');

  Widget wrap(ChessBoardPainter painter) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: CustomPaint(
              key: overlayKey,
              size: const Size(400, 400),
              painter: painter,
            ),
          ),
        ),
      );

  ChessBoardPainter painter({
    List<ChessArrow> arrows = const [],
    List<EngineArrow>? engineArrows,
  }) =>
      ChessBoardPainter(
        arrows: arrows,
        engineArrows: engineArrows,
        boardSize: 400,
        orientation: PlayerColor.white,
        lastMoveColor: const Color(0xFFFFC107),
        drawingModeColor: const Color(0xFF00BCD4),
        badgeBorderColor: const Color(0xFF000000),
      );

  group('an arrow is drawn in the catalogue colour, wearing an outline', () {
    testWidgets('the three passes reach the canvas, widest first',
        (tester) async {
      await tester.pumpWidget(wrap(painter(
        arrows: [ChessArrow(from: 'e2', to: 'e4', colorCode: 'R')],
      )));

      // Black, then white, then the arrow. Order matters: the colour has to be
      // painted last or the outline covers it.
      expect(
        find.byKey(overlayKey),
        paints
          ..line(color: ChessBoardPainter.arrowHaloShade)
          ..line(color: ChessBoardPainter.arrowHaloLight)
          ..line(color: ArrowColor.r.color.withValues(alpha: 0.75)),
      );
    });

    testWidgets('the outline is wider than the arrow, and the black one widest',
        (tester) async {
      await tester.pumpWidget(wrap(painter(
        arrows: [ChessArrow(from: 'a1', to: 'h8', colorCode: 'G')],
      )));

      final widths = <double>[];
      final colors = <Color>[];
      // ignore: invalid_use_of_protected_member
      final recording = tester.widget<CustomPaint>(find.byKey(overlayKey));
      expect(recording.painter, isNotNull);

      expect(
        find.byKey(overlayKey),
        paints
          ..something((symbol, args) {
            if (symbol != #drawLine) return false;
            final paint = args.last as Paint;
            widths.add(paint.strokeWidth);
            colors.add(paint.color);
            return true;
          }),
      );

      // Re-collect deterministically: three lines, strictly narrowing.
      widths.clear();
      colors.clear();
      expect(
        find.byKey(overlayKey),
        paints
          ..everything((symbol, args) {
            if (symbol == #drawLine) {
              final paint = args.last as Paint;
              widths.add(paint.strokeWidth);
              colors.add(paint.color);
            }
            return true;
          }),
      );

      expect(widths.length, 3, reason: 'one arrow is three passes');
      expect(widths[0], greaterThan(widths[1]));
      expect(widths[1], greaterThan(widths[2]));
      expect(colors[0], ChessBoardPainter.arrowHaloShade);
      expect(colors[1], ChessBoardPainter.arrowHaloLight);
    });

    testWidgets('no arrows, no outline', (tester) async {
      // The mutation-proof for the two above: if those matched for a reason
      // other than an arrow being drawn, they would match here too.
      await tester.pumpWidget(wrap(painter()));
      expect(find.byKey(overlayKey), paintsExactlyCountTimes(#drawLine, 0));
    });

    testWidgets('an engine arrow takes its rank colour and the same outline',
        (tester) async {
      await tester.pumpWidget(wrap(painter(engineArrows: [
        EngineArrow(from: 'd2', to: 'd4', evalText: '+0.3', rank: 1),
      ])));

      // Rank 1 is the best line and has always been green.
      expect(
        find.byKey(overlayKey),
        paints
          ..line(color: ChessBoardPainter.arrowHaloShade)
          ..line(color: ChessBoardPainter.arrowHaloLight)
          ..line(color: ArrowColor.g.color.withValues(alpha: 0.85)),
      );
    });

    testWidgets('an unknown arrow code draws the grey that means nothing',
        (tester) async {
      await tester.pumpWidget(wrap(painter(
        arrows: [ChessArrow(from: 'b1', to: 'c3', colorCode: 'nonsense')],
      )));

      expect(
        find.byKey(overlayKey),
        paints
          ..line(color: ChessBoardPainter.arrowHaloShade)
          ..line(color: ChessBoardPainter.arrowHaloLight)
          ..line(color: ArrowColor.fallback.color.withValues(alpha: 0.75)),
      );
    });
  });

  group('text standing on an arrow colour is legible on it', () {
    // The bug this closes: `badgeTextColor` was `context.colors.canvas`, which
    // is near-black in the dark theme and near-white in the light one. In the
    // light theme the best line's badge measured 1.55:1 and every one of the
    // ten rank/palette combinations sat under 4.5:1. Nobody saw it because the
    // light theme only became selectable on 29.8.2026.
    test(
        'the badge glyph carries both black and white, and the better of them '
        'clears 3.0:1 on every rank', () {
      for (final rank in [1, 2, 3, 4, 5]) {
        final fill = switch (rank) {
          1 => ArrowColor.g.color,
          2 => ArrowColor.b.color,
          3 => ArrowColor.o.color,
          4 => ArrowColor.p.color,
          _ => ArrowColor.r.color,
        };
        // Drawn at 0.9 over whatever is behind it; both palettes, because the
        // canvas behind the board differs between them.
        for (final tokens in [AppColorTokens.dark, AppColorTokens.light]) {
          final drawn = over(fill.withValues(alpha: 0.9), tokens.canvas);
          final text = ChessBoardPainter.readableOn(drawn);
          const black = Color(0xFF000000);
          const white = Color(0xFFFFFFFF);

          // The fill is the better of the two, so the outline is the other one
          // and both are always on the glyph. Their edge against each other is
          // 21:1 whatever the badge is filled with, which is the property that
          // makes this legible where a single colour could not be.
          expect(text == black || text == white, isTrue);
          expect(contrast(black, white), closeTo(21.0, 0.01));

          for (final vision in ColorVision.values) {
            // 3.0 rather than 4.5, and stated rather than assumed: red sits at
            // a luminance where black reaches 3.04 and white 3.74 and no
            // achromatic colour reaches 4.5. Four of the five clear 5.6 or
            // better; this is the floor red imposes, and the outline is what
            // covers the difference.
            expect(contrastAs(text, drawn, vision), greaterThanOrEqualTo(3.0),
                reason: 'rank $rank badge for ${vision.label}');
          }
        }
      }
    });

    test('readableOn picks the better of black and white, not a guess', () {
      for (final c in [
        ...ArrowColor.all.map((a) => a.color),
        ArrowColor.fallback.color,
        const Color(0xFF808080),
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
      ]) {
        final picked = ChessBoardPainter.readableOn(c);
        final other = picked == const Color(0xFF000000)
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF000000);
        expect(contrast(picked, c), greaterThanOrEqualTo(contrast(other, c)),
            reason: '$c');
      }
    });
  });

  group('the picker swatch says which colour it is without using colour', () {
    test('every colour in the catalogue is offered, with a distinct initial',
        () {
      // Until 29.8.2026 the picker listed four ids by hand while the catalogue
      // held five, so purple was drawn by the engine and could be picked by
      // nobody. The row is generated from `ArrowColor.all` now, and this is the
      // assertion that a sixth colour would have to be offered too.
      expect(ArrowColor.all.length, greaterThanOrEqualTo(5));

      final initials = ArrowColor.all.map(ArrowColorButton.initialOf).toList();
      expect(initials.toSet().length, initials.length,
          reason: 'two swatches sharing a letter is two identical swatches: '
              '$initials');
      expect(ArrowColorButton.initialOf(ArrowColor.p), 'Lj');
      expect(ArrowColorButton.initialOf(ArrowColor.b), 'P');
    });

    testWidgets('a swatch draws its letter', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Row(
            children: [
              for (final arrow in ArrowColor.all)
                ArrowColorButton(arrow: arrow, isSelected: false, onTap: () {}),
            ],
          ),
        ),
      ));

      for (final arrow in ArrowColor.all) {
        expect(find.text(ArrowColorButton.initialOf(arrow)), findsOneWidget,
            reason: arrow.id);
      }
    });
  });

  group('the arrows still land on a board they can be seen against', () {
    test('the outline keeps an edge on every square of every skin', () {
      // The reason the palette could stop at 1.5:1. Each outline colour is
      // achromatic, so this holds identically for every kind of vision.
      for (final board in BoardSkin.all) {
        for (final square in [board.lightSquare, board.darkSquare]) {
          final shade = worstContrast(ChessBoardPainter.arrowHaloShade, square);
          final light = worstContrast(ChessBoardPainter.arrowHaloLight, square);
          expect(shade > light ? shade : light, greaterThanOrEqualTo(3.0),
              reason: '${board.id} square $square');
        }
      }
    });
  });
}
