import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

/// The last-move marker's second channel, asserted where it is **painted**.
///
/// `board_skin_contrast_test.dart` proves the two bracket colours keep a
/// luminance edge on every square of every skin. That is a statement about two
/// constants and would go on passing if nothing ever drew them — which is the
/// shape of bug this codebase keeps finding. This file is the other half: the
/// brackets reach the canvas, they reach both squares of the move, and they
/// stop being drawn when there is no move to mark.
void main() {
  const amber = Color(0xFFFFC107);

  // Keyed, and found by that key rather than by type. `Material` builds
  // CustomPaints of its own for ink and for its shape border, so
  // `find.byKey(overlayKey)` lands on one of those and records a canvas
  // that starts with somebody else's transparent rectangle.
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

  ChessBoardPainter painter({String? from, String? to}) => ChessBoardPainter(
        arrows: const [],
        boardSize: 400,
        orientation: PlayerColor.white,
        lastMoveColor: amber,
        drawingModeColor: const Color(0xFF00BCD4),
        badgeTextColor: const Color(0xFFFFFFFF),
        badgeBorderColor: const Color(0xFF000000),
        lastMoveFrom: from,
        lastMoveTo: to,
      );

  testWidgets('a marked move paints both bracket colours', (tester) async {
    await tester.pumpWidget(wrap(painter(from: 'e2', to: 'e4')));

    expect(
      find.byKey(overlayKey),
      paints
        // The amber wash and border are untouched by this work and come first.
        ..rect(color: amber.withValues(alpha: 0.45))
        ..rect(color: amber)
        // Then the two-tone bracket: the dark halo, then the light core over it.
        ..path(color: ChessBoardPainter.lastMoveMarkerShade)
        ..path(color: ChessBoardPainter.lastMoveMarkerLight),
    );
  });

  testWidgets('both squares of the move get their own brackets',
      (tester) async {
    await tester.pumpWidget(wrap(painter(from: 'e2', to: 'e4')));

    // Two squares, two strokes each, so four bracket paths in all. Asserted as
    // a count as well as a sequence, because "the origin was marked and the
    // destination was not" is exactly the half-done case that looks right in a
    // screenshot of the correct half.
    expect(
      find.byKey(overlayKey),
      paints
        ..path(color: ChessBoardPainter.lastMoveMarkerShade)
        ..path(color: ChessBoardPainter.lastMoveMarkerLight)
        ..path(color: ChessBoardPainter.lastMoveMarkerShade)
        ..path(color: ChessBoardPainter.lastMoveMarkerLight),
    );
    expect(
      find.byKey(overlayKey),
      paintsExactlyCountTimes(#drawPath, 4),
    );
  });

  testWidgets('no move, no brackets', (tester) async {
    // The mutation-proof for the two tests above: if the matcher above passed
    // for a reason other than the brackets being drawn, it would pass here too.
    await tester.pumpWidget(wrap(painter()));

    expect(
      find.byKey(overlayKey),
      paintsExactlyCountTimes(#drawPath, 0),
    );
  });

  testWidgets('the brackets stay inside their own square', (tester) async {
    // The halo is the widest stroke on the board and it is drawn on the square
    // boundary, so the inset is the only thing keeping it off the neighbouring
    // square. A corner square is the case that shows it: a1 has two edges
    // against the board's own edge.
    await tester.pumpWidget(wrap(painter(from: 'a1', to: 'h8')));

    const squareSize = 400 / 8;
    const arm = squareSize * 0.28;
    const halo = squareSize * 0.07 * 2.2;

    // a1 is the bottom-left square of a white-oriented board.
    final expected =
        const Rect.fromLTWH(0, 350, squareSize, squareSize).deflate(halo / 2);

    expect(
      find.byKey(overlayKey),
      paints
        ..path(
          color: ChessBoardPainter.lastMoveMarkerShade,
          includes: [
            Offset(expected.left, expected.top + arm),
            Offset(expected.left + arm, expected.top),
          ],
        ),
    );
  });

  testWidgets('the amber is still there — this was added, not swapped in',
      (tester) async {
    // The reader approved how the board looks. The brackets are a second
    // channel on top of that, and a change that quietly removed the amber
    // would be a redesign nobody asked for.
    await tester.pumpWidget(wrap(painter(from: 'e2', to: 'e4')));

    expect(
      find.byKey(overlayKey),
      paints
        ..rect(color: amber.withValues(alpha: 0.45))
        ..rect(color: amber),
    );
  });

  test('the bracket colours are achromatic, which is the whole point', () {
    for (final marker in [
      ChessBoardPainter.lastMoveMarkerShade,
      ChessBoardPainter.lastMoveMarkerLight,
    ]) {
      expect(marker.r, marker.g, reason: '$marker must have no hue');
      expect(marker.g, marker.b, reason: '$marker must have no hue');
    }

    // And they are not tokens. If someone ever wires these to the palette the
    // guarantee is gone, because a token changes with the theme and the board
    // does not.
    for (final tokens in [AppColorTokens.dark, AppColorTokens.light]) {
      expect(ChessBoardPainter.lastMoveMarkerShade, isNot(tokens.warning));
      expect(ChessBoardPainter.lastMoveMarkerLight, isNot(tokens.warning));
    }
  });
}
