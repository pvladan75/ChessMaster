// `docs/PLAN-LISTE.md`, phase 2 — the grid that turns width into visible
// cards.
//
// The whole point of this widget is a number it must never be told: how many
// columns to draw. So every case here reads the count from **where the
// children are actually painted**, not from the delegate. Reading the delegate
// back would only test that Flutter's own arithmetic is what it is, which is
// true whatever this widget does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/adaptive_card_grid.dart';

/// Pumps the grid inside a box of exactly [width] and returns how many cards
/// share the topmost row.
///
/// The box matters: the widget must decide from the constraint it is handed,
/// never from the window. A screen that reads `MediaQuery` instead would pass
/// a test that sized the window and fail this one — `teach_tab` already makes
/// that mistake with its 700 cap, and phase 3 puts this widget inside the
/// room's narrow column, where the window is wide and the column is not.
Future<int> _columnsIn(WidgetTester tester, double width) async {
  tester.view.physicalSize = const Size(2400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 1400,
          child: AdaptiveCardGrid(
            itemCount: 24,
            itemBuilder: (context, i) => Card(
              key: ValueKey('tile-$i'),
              child: Center(child: Text('card $i')),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final tops = <double>[];
  for (var i = 0; i < 24; i++) {
    final finder = find.byKey(ValueKey('tile-$i'));
    if (finder.evaluate().isEmpty) continue;
    tops.add(tester.getTopLeft(finder).dy);
  }
  expect(tops, isNotEmpty, reason: 'no card was built at width $width');
  final firstRow = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((t) => (t - firstRow).abs() < 0.5).length;
}

void main() {
  // The four sizes the plan names. 360 is the phone the overflow reports keep
  // coming from; 840 is `Breakpoints.wide`, where this project already says
  // two columns fit; 1200 is `Breakpoints.ultraWide`; 1920 is the owner's
  // desktop.
  //
  // These are the *outer* widths. The grid's own padding comes off before the
  // delegate sees anything, which is part of what is being checked: the
  // expected counts have to hold for the real inner extent, not for a tidy
  // number.
  //
  // Measured 20.9.2026: setting the spacing to 0 changes none of the four
  // counts. That mutation surviving is the right answer rather than a hole —
  // none of these widths sits on a band boundary, so the numbers below are not
  // knife-edge and a later change to the spacing token cannot quietly flip
  // one. (The bands do move with spacing in general: at an inner extent of
  // 850, 420 gives three columns and 432 gives two.)
  testWidgets('one column on a phone', (tester) async {
    expect(await _columnsIn(tester, 360), 1);
  });

  testWidgets('two columns where the project already says two fit',
      (tester) async {
    expect(await _columnsIn(tester, 840), 2);
  });

  testWidgets('three columns on a wide window', (tester) async {
    expect(await _columnsIn(tester, 1200), 3);
  });

  testWidgets('five columns on a desktop', (tester) async {
    expect(await _columnsIn(tester, 1920), 5);
  });

  testWidgets('the count comes from the constraint, not from the window',
      (tester) async {
    // The same window, two different boxes. A widget that read `MediaQuery`
    // would answer the same number twice; this is the case that would catch
    // the mistake `teach_tab` makes, and it is why phase 3 can put this grid
    // in the room's column without a special case.
    final narrow = await _columnsIn(tester, 360);
    final wide = await _columnsIn(tester, 1920);
    expect(narrow, lessThan(wide),
        reason: 'the window was 2400 wide for both — the grid is reading the '
            'window rather than the box it was given');
  });

  testWidgets('420 is the only place the tile width is written',
      (tester) async {
    // One home for the number (rule 12). A screen that wants a different
    // density passes `tileHeight`; nothing may re-declare the width.
    expect(AdaptiveCardGrid.maxTileWidth, 420.0);
  });

  testWidgets('a strip just past a band boundary keeps one column',
      (tester) async {
    // The fault this rule was added for, found on 20.9.2026 while building
    // phase 5 and **present on master**: `ceil` alone splits 460 into two
    // columns of 224, and a `LibraryList` card at 224 overflows its own
    // height by 48 px. A release build clips that instead of warning, so a
    // Library window between roughly 440 and 530 px quietly cut the buttons
    // off its cards. Nothing to do with the pane — the pane only walked into
    // it.
    expect(await _columnsIn(tester, 460), 1);
    expect(await _columnsIn(tester, 500), 1);
    // And the band is still entered as soon as two cards genuinely fit.
    expect(await _columnsIn(tester, 620), 2);
  });

  testWidgets('no column is ever narrower than a card can be drawn',
      (tester) async {
    // The rule itself rather than three of its answers, swept across two
    // whole bands one pixel at a time would be slow — every 7 px is enough to
    // land inside each one, including on the boundaries themselves.
    for (var width = 200.0; width <= 1400; width += 7) {
      final columns = AdaptiveCardGrid.columnsFor(width);
      final each = (width - AdaptiveCardGrid.spacing * (columns - 1)) / columns;
      expect(
        columns == 1 || each >= AdaptiveCardGrid.minTileWidth,
        isTrue,
        reason: 'at $width the grid asks for $columns columns of '
            '${each.toStringAsFixed(1)}, under the ${AdaptiveCardGrid.minTileWidth} '
            'a card needs',
      );
    }
  });

  testWidgets('columnsFor answers what the grid actually draws',
      (tester) async {
    // Phase 4 needed the same arithmetic without a sliver delegate — „What to
    // drill" has cards of different heights, so `AdaptiveCardColumns` deals
    // them into plain `Column`s and asks `columnsFor` how many. That is a
    // second place the count is worked out, and two places that must agree
    // are one fixture's job (rule 12): this case reads the delegate's answer
    // off the rendering and holds the helper to it.
    //
    // The widths straddle the bands rather than sitting in their middles —
    // 432 and 864 are boundaries — so a helper that rounded instead of
    // ceiling, or that forgot the spacing, is red here and not merely lucky.
    for (final width in [200.0, 431.0, 432.0, 433.0, 863.0, 864.0, 1376.0]) {
      tester.view.physicalSize = const Size(2400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 2400,
              child: AdaptiveCardGrid(
                padding: EdgeInsets.zero,
                itemCount: 24,
                itemBuilder: (context, i) =>
                    Card(key: ValueKey('tile-$i'), child: Text('$i')),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final tops = <double>[];
      for (var i = 0; i < 24; i++) {
        final f = find.byKey(ValueKey('tile-$i'));
        if (f.evaluate().isEmpty) continue;
        tops.add(tester.getTopLeft(f).dy);
      }
      final firstRow = tops.reduce((a, b) => a < b ? a : b);
      final drawn = tops.where((t) => (t - firstRow).abs() < 0.5).length;

      expect(AdaptiveCardGrid.columnsFor(width), drawn,
          reason: 'at $width the grid draws $drawn columns and the helper '
              'says ${AdaptiveCardGrid.columnsFor(width)}');
    }
  });

  testWidgets('a card keeps its height whatever the column count is',
      (tester) async {
    // Height by `mainAxisExtent`, not by an aspect ratio. With an aspect
    // ratio the same card would be short and wide in one column and tall and
    // narrow in five, so a two-line subtitle would fit on the desktop and
    // overflow on the phone.
    Future<double> heightAt(double width) async {
      await _columnsIn(tester, width);
      return tester.getSize(find.byKey(const ValueKey('tile-0'))).height;
    }

    final onPhone = await heightAt(360);
    final onDesktop = await heightAt(1920);
    expect(onPhone, onDesktop);
    expect(onPhone, AdaptiveCardGrid.defaultTileHeight);
  });
}
