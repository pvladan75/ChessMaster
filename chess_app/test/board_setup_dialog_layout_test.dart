// The two board-setup dialogs, on a phone.
//
// Found by looking at a debug build on 29.8.2026: the analysis studio's setup
// dialog striped twice — 19 pixels on the title row and **168 on the row that
// carries the castling rights**. The second one is not cosmetic. `Q`, `k` and
// `q` sat past the right edge, and a widget that is past the edge cannot be
// tapped, so black's castling rights could not be set at all on a phone.
//
// In a release build neither stripe is drawn: the row is simply clipped and
// the chips are missing with no sign that anything went wrong. In a *test*
// build an overflow throws, which is the only reason a test can stand in for
// the phone here.
//
// The sizes were the cause in both files: 550x620 in one and a tight 360 in
// the other, promised to a 360dp screen that has neither.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_setup_dialog.dart';

const _phone = Size(360, 640);
const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  Future<void> pumpOnPhone(WidgetTester tester, Widget dialog,
      {Size size = _phone}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(body: Builder(builder: (context) => dialog)),
    ));
    await tester.pumpAndSettle();
  }

  /// Selects a tab by index without tapping it: the TabBar is scrollable, so
  /// the tab under test may itself be off-screen, and a test that cannot find
  /// its own entry point proves nothing about the tab.
  Future<void> selectTab(WidgetTester tester, int index) async {
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    bar.controller!.animateTo(index);
    await tester.pumpAndSettle();
  }

  testWidgets('analysis setup dialog lays out on a 360dp phone',
      (tester) async {
    await pumpOnPhone(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: _startFen,
        onPositionSet: (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every castling chip is on the screen, not past its edge',
      (tester) async {
    await pumpOnPhone(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: _startFen,
        onPositionSet: (_) {},
      ),
    );
    await selectTab(tester, 2); // Ručno slaganje
    expect(tester.takeException(), isNull);

    // The four rights, in the order they sit in the row. `q` was the one 168
    // pixels past the edge, but asserting only the last would pass the day
    // somebody reorders them.
    for (final label in ['K', 'Q', 'k', 'q']) {
      final chip = find.widgetWithText(FilterChip, label);
      expect(chip, findsOneWidget, reason: 'castling chip $label is missing');
      final rect = tester.getRect(chip);
      expect(rect.right, lessThanOrEqualTo(_phone.width),
          reason: 'chip $label ends at ${rect.right}, past the ${_phone.width}'
              ' the screen has — it cannot be tapped');
      expect(rect.left, greaterThanOrEqualTo(0.0),
          reason: 'chip $label starts at ${rect.left}');
    }
  });

  testWidgets('the manual tab survives a narrower phone still', (tester) async {
    // 320dp is the narrowest Android phone still in use. The point is not that
    // it looks good there, but that nothing lands where it cannot be reached.
    await pumpOnPhone(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: _startFen,
        onPositionSet: (_) {},
      ),
      size: const Size(320, 640),
    );
    await selectTab(tester, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a desktop the simple dialog needs no scrolling',
      (tester) async {
    // The Windows complaint: palette, board and controls stacked into a column
    // taller than the screen, so "Učitaj na tablu" sat below the fold. Asking
    // whether the button is *findable* would not have caught it — an offstage
    // widget in a scroll view is found. What has to be true is that there is
    // nothing to scroll.
    await pumpOnPhone(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => BoardSetupDialog(onFenGenerated: (_) {}),
          ),
          child: const Text('otvori'),
        ),
      ),
      size: const Size(1280, 800),
    );
    await tester.tap(find.text('otvori'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final scroller = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scroller.first).position;
    expect(position.maxScrollExtent, 0.0,
        reason: 'the dialog still scrolls by ${position.maxScrollExtent} on a '
            '1280x800 screen, so something is below the fold');
  });

  testWidgets('the simple setup dialog lays out on a 360dp phone',
      (tester) async {
    await pumpOnPhone(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => BoardSetupDialog(onFenGenerated: (_) {}),
          ),
          child: const Text('otvori'),
        ),
      ),
    );
    await tester.tap(find.text('otvori'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Postavi poziciju (Board Setup)'), findsOneWidget);
  });
}
