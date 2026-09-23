// `docs/PLAN-POCETNI-TABOVI.md`, phase 1 — `AdaptiveCardRows`, the third half
// of pattern A: peer cards laid out row by row, every card in a row as tall as
// the tallest one in it.
//
// Every claim is read from where the cards are painted, never from the
// widget's own arithmetic, and the cards are of deliberately different heights
// — a fixture of equal cards could not tell „rows of equal height" from „no
// rule at all" (rule 6).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/adaptive_card_grid.dart';

/// Heights that differ inside every row at every column count the cases use.
const _heights = [40.0, 90.0, 60.0, 30.0, 75.0, 50.0, 20.0, 85.0, 45.0];

Widget _card(int i) => ColoredBox(
      key: ValueKey('card-$i'),
      color: Colors.grey,
      child: SizedBox(height: _heights[i % _heights.length]),
    );

/// Pumps [count] cards inside a box exactly [width] wide, in a window that is
/// always 2400 — so a widget reading the window instead of its box answers
/// the same at every width.
Future<void> _pump(WidgetTester tester, double width,
    {int count = 9, Widget Function(int)? card}) async {
  tester.view.physicalSize = const Size(2400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: AdaptiveCardRows(
              key: UniqueKey(),
              children: [for (var i = 0; i < count; i++) (card ?? _card)(i)],
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, int i) =>
    tester.getRect(find.byKey(ValueKey('card-$i')));

/// How many cards share the first card's top edge.
int _firstRow(WidgetTester tester, int count) {
  final top = _rect(tester, 0).top;
  return [for (var i = 0; i < count; i++) _rect(tester, i).top]
      .where((t) => (t - top).abs() < 0.5)
      .length;
}

void main() {
  testWidgets('one card per line on a phone, each its own height',
      (tester) async {
    await _pump(tester, 360);
    expect(_firstRow(tester, 9), 1);
    for (var i = 0; i < 9; i++) {
      final r = _rect(tester, i);
      expect(r.width, 360, reason: 'card $i is not full width on a phone');
      expect(r.height, _heights[i],
          reason: 'on a phone card $i was stretched to a height it does not '
              'need — a row of one is as tall as its one card');
    }
  });

  testWidgets('the column count grows with the box: 1, 2, 3, 5',
      (tester) async {
    for (final (width, expected) in [
      (360.0, 1),
      (840.0, 2),
      (1200.0, 3),
      (1920.0, 5),
    ]) {
      await _pump(tester, width, count: 12);
      expect(_firstRow(tester, 12), expected, reason: 'at $width');
    }
  });

  testWidgets('the count is the shared rule\'s, at the band boundaries',
      (tester) async {
    // The widths where one more pixel changes the answer — the only ones that
    // catch a copy of the arithmetic that forgot the spacing (PLAN-LISTE,
    // phase 4).
    for (final width in [431.0, 432.0, 433.0, 863.0, 864.0, 865.0]) {
      await _pump(tester, width, count: 12);
      expect(_firstRow(tester, 12), AdaptiveCardGrid.columnsFor(width),
          reason: 'at $width');
    }
  });

  testWidgets('every card in a row is as tall as the tallest in it',
      (tester) async {
    await _pump(tester, 1200); // three columns, three rows of three
    expect(_firstRow(tester, 9), 3);
    for (var row = 0; row < 3; row++) {
      final ids = [row * 3, row * 3 + 1, row * 3 + 2];
      final tallest =
          ids.map((i) => _heights[i]).reduce((a, b) => a > b ? a : b);
      for (final i in ids) {
        expect(_rect(tester, i).height, tallest,
            reason: 'card $i in row $row does not reach the row\'s bottom');
        expect(_rect(tester, i).top, _rect(tester, ids.first).top,
            reason: 'card $i is not on its row\'s top edge');
      }
    }
    // And a row is not given the height of the whole set: the first row's
    // tallest is 90, the last row's 85 — neither is stretched to the other.
    expect(_rect(tester, 0).height, 90);
    expect(_rect(tester, 6).height, 85);
  });

  testWidgets('cards read left to right, then down', (tester) async {
    await _pump(tester, 1200);
    final a = _rect(tester, 0), b = _rect(tester, 1), d = _rect(tester, 3);
    expect(b.top, a.top, reason: 'the second card is not beside the first');
    expect(b.left, greaterThan(a.right));
    expect(d.left, a.left, reason: 'the fourth card does not start row two');
    expect(d.top,
        moreOrLessEquals(a.bottom + AdaptiveCardGrid.spacing, epsilon: 0.01),
        reason: 'rows are not one spacing apart');
  });

  testWidgets('a short last row keeps the width of the rows above it',
      (tester) async {
    await _pump(tester, 1200, count: 7); // 3 + 3 + 1
    expect(_rect(tester, 6).width, _rect(tester, 0).width,
        reason: 'the lone card in the last row was widened to fill the line');
    expect(_rect(tester, 6).left, _rect(tester, 0).left);
  });

  testWidgets('decided from the box, not from the window', (tester) async {
    await _pump(tester, 360, count: 6);
    final narrow = _firstRow(tester, 6);
    await _pump(tester, 1920, count: 6);
    final wide = _firstRow(tester, 6);
    expect(narrow, lessThan(wide),
        reason: 'the window was 2400 both times — the widget reads the '
            'window rather than the box it was given');
  });

  testWidgets('rows nest inside a card of rows without throwing',
      (tester) async {
    // The reason this is a render object and not `IntrinsicHeight` around a
    // `Row`: intrinsics throw on a `LayoutBuilder`, and the Teach tab's
    // people card is a card in a flow that holds a flow of its own.
    await _pump(tester, 1200, count: 3, card: (i) {
      if (i != 1) return _card(i);
      return Card(
        key: const ValueKey('card-1'),
        child: AdaptiveCardRows(children: [
          for (var j = 0; j < 4; j++)
            SizedBox(key: ValueKey('inner-$j'), height: 30),
        ]),
      );
    });
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('inner-3')), findsOneWidget);
    expect(_rect(tester, 0).height, _rect(tester, 1).height);
  });

  testWidgets('asked for its intrinsic height, it fails loudly — never 0',
      (tester) async {
    // The render object does not implement intrinsics; the `LayoutBuilder`
    // in front of it is what answers, and it refuses in a debug or test
    // build. That refusal is the guard: without it, an `IntrinsicHeight`
    // around these rows would size them to 0 and clip every card in
    // silence. If someone drops the `LayoutBuilder`, this case goes red —
    // and the render object then needs real intrinsics before it ships.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IntrinsicHeight(
          child: AdaptiveCardRows(children: [_card(0), _card(1)]),
        ),
      ),
    ));
    expect(tester.takeException(), isNotNull,
        reason: 'an intrinsic query was answered quietly — check that it is '
            'not 0 before trusting it');
  });

  testWidgets('a button in any card can be tapped', (tester) async {
    final tapped = <int>[];
    await _pump(tester, 1200, count: 5, card: (i) {
      return SizedBox(
        key: ValueKey('card-$i'),
        height: _heights[i],
        child: TextButton(
          onPressed: () => tapped.add(i),
          child: Text('go $i'),
        ),
      );
    });
    await tester.tap(find.text('go 4'));
    await tester.tap(find.text('go 1'));
    expect(tapped, [4, 1]);
  });

  // docs/PLAN-MATERIJAL.md, phase 2: a card that grows after its row was laid
  // out — an engine proposal appearing under a scanned board — must take the
  // row with it. Each card's last layout is tight, which makes it a relayout
  // boundary, so until then it re-laid itself inside its old height,
  // overflowed, and the row stayed as it was.
  testWidgets('a card grown by a rebuild takes its row with it',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var grown = false;
    late StateSetter grow;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              child: StatefulBuilder(builder: (context, setState) {
                grow = setState;
                return AdaptiveCardRows(children: [
                  _card(0),
                  ColoredBox(
                    key: const ValueKey('card-1'),
                    color: Colors.grey,
                    child: Column(children: [
                      const SizedBox(height: 60),
                      if (grown) const SizedBox(height: 100),
                    ]),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_rect(tester, 1).height, 60);

    grow(() => grown = true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_rect(tester, 1).height, 160,
        reason: 'the card kept its old height');
    expect(_rect(tester, 0).height, 160,
        reason: 'its neighbour is no longer as tall as the row');
  });
}
