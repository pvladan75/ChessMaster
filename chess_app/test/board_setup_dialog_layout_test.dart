// The board-setup dialog, on a phone and on a desktop.
//
// There were two of them until 8.9.2026 — this file was named after that — and
// the one that survived is the one that can be opened on the position in front
// of you. The assertions below are unchanged; the fixtures moved onto it.
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
import 'package:chess_app/theme/app_typography.dart';

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

  for (final size in const [Size(800, 360), Size(932, 430)]) {
    testWidgets(
        'every tab lays out on a phone held sideways at '
        '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      await pumpOnPhone(
        tester,
        // With a PGN caller, so all five tabs are drawn, not two.
        AnalysisBoardSetupDialog(
          initialFen: _startFen,
          onPositionSet: (_) {},
          onPgnLoaded: (_) {},
        ),
        size: size,
      );
      expect(tester.takeException(), isNull);
      final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs.length;
      expect(tabs, 5);
      for (var i = 0; i < tabs; i++) {
        await selectTab(tester, i);
        expect(tester.takeException(), isNull, reason: 'tab $i overflows');
      }
    });
  }

  testWidgets('every castling chip is on the screen, not past its edge',
      (tester) async {
    await pumpOnPhone(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: _startFen,
        onPositionSet: (_) {},
      ),
    );
    await selectTab(tester, 1); // Ručno slaganje — the second of two here
    expect(tester.takeException(), isNull);

    // The four rights, in the order they sit in the grid. `q` was the one 168
    // pixels past the edge, but asserting only the last would pass the day
    // somebody reorders them. They stopped being `K`, `Q`, `k`, `q` on
    // 8.9.2026 — the case of a letter was the only thing separating White's
    // rights from Black's — and shortened to an initial on 19.9.2026, which is
    // a letter that is not a case. The full name is in the tooltip.
    for (final label in ['W O-O', 'W O-O-O', 'B O-O', 'B O-O-O']) {
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
    await selectTab(tester, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a desktop the editor puts nothing below the fold',
      (tester) async {
    // The Windows complaint: palette, board and controls stacked into a column
    // taller than the screen, so the button that finishes the job sat below
    // the fold. Asking whether the button is *findable* would not have caught
    // it — an offstage widget in a scroll view is found — so this asks where
    // it actually is.
    await pumpOnPhone(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AnalysisBoardSetupDialog(
              initialFen: _startFen,
              onPositionSet: (_) {},
            ),
          ),
          child: const Text('otvori'),
        ),
      ),
      size: const Size(1280, 800),
    );
    await tester.tap(find.text('otvori'));
    await tester.pumpAndSettle();
    await selectTab(tester, 1);
    expect(tester.takeException(), isNull);

    final confirm = find.text('Generate and Set Position');
    expect(confirm, findsOneWidget);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(800.0),
        reason: 'the button that finishes the job is off the bottom of a '
            '1280x800 screen');
  });

  /// Every piece in the palette, and the eraser: the thirteen things a trainer
  /// has to be able to arm.
  const paletteKeys = [
    'P',
    'N',
    'B',
    'R',
    'Q',
    'K',
    'p',
    'n',
    'b',
    'r',
    'q',
    'k',
    'CLEAR',
  ];

  for (final size in const [
    Size(1280, 800),
    Size(1920, 1080),
    Size(360, 640),
    Size(320, 640),
    Size(800, 360),
    Size(932, 430),
    Size(600, 400),
  ]) {
    testWidgets(
        'every palette piece is inside the dialog at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      // Reported live on 19.9.2026 from Windows: „ovaj dijalog prozor ne moze
      // da dohvati do crne dame i crnog kralja". The palette was one row 848dp
      // wide inside a horizontal scroll view, and the dialog gives it 728 — so
      // the last three sat past the right edge, where a mouse wheel scrolls
      // the wrong axis and there is no scrollbar to drag.
      //
      // A scroll view never overflows, so no exception was ever thrown and no
      // test asking for one could have caught this. This asks where the cells
      // actually are.
      await pumpOnPhone(
        tester,
        AnalysisBoardSetupDialog(initialFen: _startFen, onPositionSet: (_) {}),
        size: size,
      );
      await selectTab(tester, 1);
      expect(tester.takeException(), isNull);

      // Against the tab's own viewport, not the screen: the dialog is 760
      // wide inside whatever the screen is, and a cell past 760 is clipped
      // whether or not the monitor behind it has the room. Asking about the
      // screen let a 1920x1080 desktop pass with three cells unreachable.
      final dialog = tester.getRect(find.byType(TabBarView));
      for (final key in paletteKeys) {
        final cell = find.byKey(ValueKey('palette-$key'));
        expect(cell, findsOneWidget, reason: 'palette cell $key is missing');
        final rect = tester.getRect(cell);
        expect(rect.right, lessThanOrEqualTo(dialog.right),
            reason: 'palette cell $key ends at ${rect.right}, past the '
                '${dialog.right} the dialog has - it cannot be clicked');
        expect(rect.left, greaterThanOrEqualTo(dialog.left),
            reason: 'palette cell $key starts at ${rect.left}, before the '
                '${dialog.left} the dialog starts at');
      }
    });

    testWidgets(
        'and the board fits inside the dialog at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      // The Android landscape half of the same report: „tabla je prevelika, ne
      // staje na ekran". The short branch sized the board from `maxWidth`
      // alone, which on a 932x430 phone is the *large* dimension - a 724x724
      // board inside a 398-tall dialog. Sized from one dimension, a board can
      // only be right on screens shaped like the one it was tried on.
      await pumpOnPhone(
        tester,
        AnalysisBoardSetupDialog(initialFen: _startFen, onPositionSet: (_) {}),
        size: size,
      );
      await selectTab(tester, 1);
      expect(tester.takeException(), isNull);

      final dialog = tester.getRect(find.byType(TabBarView));
      final board = tester.getRect(find.byType(GridView));
      expect(board.width, lessThanOrEqualTo(dialog.width),
          reason: 'the board is ${board.width} wide inside a '
              '${dialog.width} dialog');
      expect(board.height, lessThanOrEqualTo(dialog.height),
          reason: 'the board is ${board.height} tall inside a '
              '${dialog.height} dialog');
      // And square, which is the half a size check cannot see. A SizedBox is
      // clamped by what its parent offers, so a board asked for at 437 inside
      // a 260-tall row does not come out too big - it comes out 437x260, a
      // squashed board that passes every question about whether it fits.
      expect(board.width, closeTo(board.height, 1.0),
          reason: 'the board is ${board.width}x${board.height}, not square');
    });
  }

  for (final size in const [
    Size(1280, 800),
    Size(360, 640),
    Size(932, 430),
  ]) {
    testWidgets(
        'the button that finishes the job is on the screen at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      // It was the last child of a column taller than the tab on every size
      // measured: 918 on a 360dp phone, 1142 on a phone held sideways. A
      // scroll view finds an offstage widget, so `findsOneWidget` proved
      // nothing; this asks where it is.
      await pumpOnPhone(
        tester,
        AnalysisBoardSetupDialog(initialFen: _startFen, onPositionSet: (_) {}),
        size: size,
      );
      await selectTab(tester, 1);
      final confirm = find.text('Generate and Set Position');
      expect(confirm, findsOneWidget);
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(size.height),
          reason: 'the confirm button ends at '
              '${tester.getRect(confirm).bottom} on a ${size.height} screen');
    });
  }

  for (final size in const [
    Size(1280, 800),
    Size(1920, 1080),
    Size(800, 360),
    Size(932, 430),
  ]) {
    testWidgets(
        'all five tab labels are on one row at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      // Measured on the labels this replaced: 846dp of text, a 974dp strip,
      // in a bar that is 728 — 314 past the right edge on every size, desktop
      // included. The strip scrolled sideways and the first label read „N
      // String" on a phone held sideways. A tab a reader has to scroll to find
      // is the palette fault one row higher up.
      //
      // This asks where each label is, not whether it exists: a scrollable bar
      // lays its tabs out past its own viewport and `findsOneWidget` finds
      // every one of them.
      await pumpOnPhone(
        tester,
        AnalysisBoardSetupDialog(
          initialFen: _startFen,
          onPositionSet: (_) {},
          onPgnLoaded: (_) {},
        ),
        size: size,
      );
      final bar = tester.getRect(find.byType(TabBar));
      for (final label in ['FEN', 'PGN', 'Pieces', 'Openings', 'Online']) {
        final tab = find.text(label);
        expect(tab, findsOneWidget, reason: 'tab $label is missing');
        final rect = tester.getRect(tab);
        expect(rect.right, lessThanOrEqualTo(bar.right),
            reason: 'tab $label ends at ${rect.right}, past the ${bar.right} '
                'the strip has - it is scrolled out of sight');
        expect(rect.left, greaterThanOrEqualTo(bar.left),
            reason: 'tab $label starts at ${rect.left}, before the strip');
      }
      // And on one row: every label shares a vertical centre.
      final tops = [
        for (final label in ['FEN', 'PGN', 'Pieces', 'Openings', 'Online'])
          tester.getRect(find.text(label)).center.dy
      ];
      for (final dy in tops) {
        expect(dy, closeTo(tops.first, 1.0),
            reason: 'the labels are not on one row: $tops');
      }
    });
  }

  /// The width [label] wants at [style], laid out with nothing in its way.
  ///
  /// A `Text` inside a box narrower than its line is given the box's width and
  /// paints an ellipsis, so its rendered size says nothing about whether it was
  /// cut. This is what it would have been.
  double intrinsicWidth(String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  // Screen size, and how many rows the four rights take there: two where the
  // control block is narrow, one where it is wide enough for all four.
  for (final (size, rows) in const [
    (Size(1280, 800), 2),
    (Size(360, 640), 2),
    (Size(320, 640), 2),
    (Size(667, 300), 1),
    (Size(932, 430), 1),
  ]) {
    testWidgets(
        'the four castling rights make $rows row(s) at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      // They were one flat Wrap shared with „To move", and a Wrap fills each
      // line before starting the next: „White O-O" sat beside the dropdown,
      // the next two shared a line and the fourth was alone. Reported live on
      // 19.9.2026 with the picture.
      await pumpOnPhone(
        tester,
        AnalysisBoardSetupDialog(initialFen: _startFen, onPositionSet: (_) {}),
        size: size,
      );
      await selectTab(tester, 1);
      expect(tester.takeException(), isNull);

      const labels = ['W O-O', 'W O-O-O', 'B O-O', 'B O-O-O'];
      final rects = [
        for (final label in labels)
          tester.getRect(find.widgetWithText(FilterChip, label))
      ];

      // How many distinct lines they sit on.
      final lines = <double>[];
      for (final r in rects) {
        if (!lines.any((y) => (y - r.center.dy).abs() < 1)) {
          lines.add(r.center.dy);
        }
      }
      expect(lines, hasLength(rows),
          reason: 'the rights sit on ${lines.length} lines, not $rows');

      // Equal shares of the width, not four different sizes.
      for (final r in rects) {
        expect(r.width, closeTo(rects.first.width, 1.0),
            reason: 'the chips are not the same width: '
                '${rects.map((e) => e.width).toList()}');
      }

      // And none of them is too narrow for its own word. A chip that fits the
      // row by ellipsising „W O-O-O" into „W O-…" is not a chip that fits.
      for (final label in labels) {
        final rendered = tester.getSize(find.text(label)).width;
        expect(rendered,
            greaterThanOrEqualTo(intrinsicWidth(label, AppText.micro) - 0.5),
            reason: 'the label „$label" is cut: it is drawn $rendered wide and '
                'wants ${intrinsicWidth(label, AppText.micro)}');
      }

      // Nothing past the edge, which is where this family of faults began.
      final bar = tester.getRect(find.byType(TabBarView));
      for (final r in rects) {
        expect(r.right, lessThanOrEqualTo(bar.right + 0.5));
        expect(r.left, greaterThanOrEqualTo(bar.left - 0.5));
      }
    });
  }

  testWidgets('and the editor is the second tab when no PGN can be handed over',
      (tester) async {
    // Three of the five tabs give their result to `onPgnLoaded`. A caller that
    // passes none — the tutorial studio, deliberately — used to get them
    // anyway: picking „Najdorf" closed the dialog and dropped the opening.
    await pumpOnPhone(
      tester,
      AnalysisBoardSetupDialog(initialFen: _startFen, onPositionSet: (_) {}),
      size: const Size(1280, 800),
    );

    expect(find.text('FEN'), findsOneWidget);
    expect(find.text('Pieces'), findsOneWidget);
    expect(find.text('PGN'), findsNothing);
    expect(find.text('Openings'), findsNothing);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('and all five are there for a caller that can take a PGN',
      (tester) async {
    await pumpOnPhone(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: _startFen,
        onPositionSet: (_) {},
        onPgnLoaded: (_) {},
      ),
      size: const Size(1280, 800),
    );

    expect(find.text('PGN'), findsOneWidget);
    expect(find.text('Openings'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });
}
