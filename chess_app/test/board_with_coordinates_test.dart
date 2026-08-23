import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/board_with_coordinates.dart';

Widget wrap(PlayerColor orientation, {double size = 320}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: BoardWithCoordinates(
            size: size,
            orientation: orientation,
            builder: (inner) => SizedBox(
              width: inner,
              height: inner,
              child: const ColoredBox(color: Colors.brown),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('white at the bottom puts rank 1 below rank 8, and a left of h',
      (tester) async {
    await tester.pumpWidget(wrap(PlayerColor.white));

    // Positions, not just presence: which way round they run is the whole
    // reason the labels are there, and a reversed list would still contain
    // every letter.
    expect(tester.getCenter(find.text('8')).dy,
        lessThan(tester.getCenter(find.text('1')).dy));
    expect(tester.getCenter(find.text('a')).dx,
        lessThan(tester.getCenter(find.text('h')).dx));
  });

  testWidgets('a flipped board flips the labels with it', (tester) async {
    await tester.pumpWidget(wrap(PlayerColor.black));

    expect(tester.getCenter(find.text('1')).dy,
        lessThan(tester.getCenter(find.text('8')).dy));
    expect(tester.getCenter(find.text('h')).dx,
        lessThan(tester.getCenter(find.text('a')).dx));
  });

  testWidgets('the whole thing fits the size it was given', (tester) async {
    // The caller has already worked out how much room it has, so the labels
    // come out of that rather than being added to it - otherwise a board sized
    // to a 360 dp phone overflows by the width of the gutter, and in a release
    // build that is silent.
    await tester.pumpWidget(wrap(PlayerColor.white, size: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final box = tester.getSize(find.byType(BoardWithCoordinates));
    expect(box.width, 200);
    expect(box.height, 200);
  });

  testWidgets('every file and rank is labelled once', (tester) async {
    await tester.pumpWidget(wrap(PlayerColor.white));

    for (final file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
      expect(find.text(file), findsOneWidget, reason: 'linija $file');
    }
    for (var rank = 1; rank <= 8; rank++) {
      expect(find.text('$rank'), findsOneWidget, reason: 'red $rank');
    }
  });
}
