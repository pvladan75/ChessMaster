// `docs/PLAN-LISTE.md`, phase 7 — „Choose a game" becomes a real table.
//
// Asked for by the owner on 20.9.2026, after phases 1 and 1b had already given
// the dialog its search and cleaned the clocks out of its move preview: *the
// raw text and the cards still bother me, I would like it turned into a real
// dense table.* §2.3 of the Gemini document is the shape — row height 36–40,
// search and filters above, columns **White · Black · Date · Result · First
// moves** — and §3.3 is the same list on a phone, two dense lines per game.
//
// Two things in that mockup are deliberately **not** built, and the reasons
// are here so the next reader does not think they were missed:
//
//  * **The „Izaberi" action column.** The row is already the target. A button
//    that does what the row does costs a column of width and gives one action
//    two doors.
//  * **Pagination (`1 / 206`).** That is a workaround for lists that cannot
//    virtualise. `ListView.builder` builds only what is on screen, so 4126
//    games scroll without paging, and the search is what actually narrows
//    them. Paging would put the reader back to hunting a page number.
//
// What the cases below are careful about: a table is not a list with a
// heading. The claim that matters is that a row's cells **line up under their
// headers**, which is measured from where they are painted, not from the fact
// that the words are on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';

/// A game with the headers a real export carries, and `%clk` on every move —
/// the owner's 4126 come from online play, and phase 1b was paid for by a
/// fixture that had clean movetext (rule 6).
PgnGameInfo _game({
  required String white,
  required String black,
  required String date,
  required String result,
  String moves = '1. e4 { [%clk 0:03:00] } 1... c5 { [%clk 0:03:00] } 2. Nf3',
}) =>
    PgnGameInfo(
      headers: {
        'White': white,
        'Black': black,
        'Date': date,
        'Result': result,
        'Event': 'Rated blitz game',
      },
      pgnBody: moves,
    );

List<PgnGameInfo> _shelf() => [
      _game(
          white: 'kotjok77',
          black: 'pvladan',
          date: '2026.07.04',
          result: '1-0',
          moves: '1. d4 { [%clk 0:03:00] } 1... d5 2. c4 e6 3. Nc3'),
      _game(
          white: 'ChessBruh2025',
          black: 'pvladan',
          date: '2026.07.03',
          result: '0-1',
          moves: '1. e4 e6 2. Nf3 d5'),
      _game(
          white: 'pvladan',
          black: 'Kingston32gb',
          date: '2026.07.02',
          result: '1/2-1/2',
          moves: '1. c4 Nf6 2. g3'),
    ];

/// Enough rows that „more of them fit now" is a claim about the layout and
/// not about the fixture.
List<PgnGameInfo> _many() => [
      for (var i = 0; i < 60; i++)
        _game(
            white: 'white$i',
            black: 'black$i',
            date: '2026.07.${(i % 28) + 1}',
            result: i.isEven ? '1-0' : '0-1'),
    ];

Future<void> _open(
  WidgetTester tester,
  List<PgnGameInfo> games, {
  Size size = const Size(1400, 900),
  void Function(PgnGameInfo)? onSelected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => GameSelectorDialog(
              games: games,
              onGameSelected: onSelected ?? (_) {},
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The left edge of the first `Text` whose string is exactly [s].
///
/// Asserted before it is measured, so a missing cell is a sentence about the
/// screen rather than a `StateError` out of `.first` (rule 3: a red is a catch
/// only if it is the right red).
double _leftOf(WidgetTester tester, String s) {
  expect(find.text(s), findsWidgets, reason: '„$s" is nowhere on the screen');
  return tester.getTopLeft(find.text(s).first).dx;
}

/// The left edge of a cell **inside a given row**.
///
/// Scoped rather than global, because „1-0" is on the screen twice — once as
/// the filter chip and once as that game's result — and an unscoped finder
/// would have measured the chip against the Result column and called it
/// aligned.
double _cellLeft(WidgetTester tester, String rowKey, String s) {
  final cell =
      find.descendant(of: find.byKey(ValueKey(rowKey)), matching: find.text(s));
  expect(cell, findsOneWidget, reason: '„$s" is not a cell of $rowKey');
  return tester.getTopLeft(cell).dx;
}

/// How many game rows are built right now.
int _rowsBuilt() => find
    .byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith('game-row-');
    })
    .evaluate()
    .length;

void main() {
  testWidgets('a wide dialog has the five columns the mockup names',
      (tester) async {
    await _open(tester, _shelf());

    for (final header in ['White', 'Black', 'Date', 'Result', 'First moves']) {
      expect(find.text(header), findsOneWidget, reason: '$header is missing');
    }
  });

  testWidgets('a row\'s cells line up under their headers', (tester) async {
    // The case that tells a table from a list with a heading over it. Read
    // from where the cells are painted; a layout that merely prints the words
    // in the right order passes the case above and fails this one.
    await _open(tester, _shelf());

    expect(
        _cellLeft(tester, 'game-row-0', 'kotjok77'), _leftOf(tester, 'White'));
    expect(
        _cellLeft(tester, 'game-row-0', 'pvladan'), _leftOf(tester, 'Black'));
    expect(
        _cellLeft(tester, 'game-row-0', '2026.07.04'), _leftOf(tester, 'Date'));
    expect(_cellLeft(tester, 'game-row-0', '1-0'), _leftOf(tester, 'Result'));
  });

  testWidgets('the rows are dense', (tester) async {
    // §2.3 says 36–40. The number that matters is the ceiling: a `ListTile`
    // with a subtitle, which is what this dialog drew until now, is 72.
    await _open(tester, _shelf());

    expect(find.byKey(const ValueKey('game-row-0')), findsOneWidget,
        reason: 'the rows are not addressable, so nothing here can measure '
            'one');
    final row = tester.getSize(find.byKey(const ValueKey('game-row-0')));
    expect(row.height, lessThanOrEqualTo(44),
        reason: 'a row is ${row.height} tall, so this is still a list of '
            'cards with column headings over it');
  });

  testWidgets('a tall window shows many more games than a card list did',
      (tester) async {
    // Phase 1 measured the same premise as the list's height; here it is the
    // thing the reader actually counts. Eight rows of 72 fit where this must
    // show at least fourteen.
    await _open(tester, _many());

    expect(_rowsBuilt(), greaterThanOrEqualTo(14),
        reason: 'only ${_rowsBuilt()} rows are built in a 900 px window — '
            'how many fit is the whole point of the phase');
  });

  testWidgets('on a phone it is two dense lines, not a table', (tester) async {
    // §3.3. Five columns in 296 px would be five unreadable columns, so the
    // narrow layout is the same information stacked — and the table's headers
    // must not be drawn there at all (rule 5: an absence is a claim about the
    // whole screen, so it is asked of the header words themselves).
    await _open(tester, _shelf(), size: const Size(360, 720));

    expect(find.text('First moves'), findsNothing);
    expect(find.textContaining('kotjok77'), findsWidgets);
    expect(find.textContaining('1. d4 d5 2. c4'), findsWidgets,
        reason: 'the moves are still shown, and still without the clocks');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the result filter narrows the list', (tester) async {
    await _open(tester, _shelf());

    expect(find.byKey(const ValueKey('game-filter-1-0')), findsOneWidget,
        reason: 'there is no result filter to press');
    await tester.tap(find.byKey(const ValueKey('game-filter-1-0')));
    await tester.pumpAndSettle();

    expect(find.text('kotjok77'), findsOneWidget);
    expect(find.text('ChessBruh2025'), findsNothing);
    expect(find.text('Kingston32gb'), findsNothing);
  });

  testWidgets('the filter and the search narrow together', (tester) async {
    // Two filters that each work and do not compose is the bug this catches:
    // the result chip must narrow what the search left, not replace it.
    await _open(tester, _shelf());

    // The search must leave something the chip then **disagrees** with, or
    // the case cannot tell composing from replacing. Searching „pvladan"
    // first — all three games have them on one side — let a mutation that
    // filtered the whole collection pass, because the whole collection was
    // what the search had left.
    await tester.enterText(find.byType(TextField), 'Kingston');
    await tester.pumpAndSettle();
    expect(find.text('Kingston32gb'), findsOneWidget);
    expect(find.text('kotjok77'), findsNothing);

    expect(find.byKey(const ValueKey('game-filter-1-0')), findsOneWidget,
        reason: 'there is no result filter to press');
    await tester.tap(find.byKey(const ValueKey('game-filter-1-0')));
    await tester.pumpAndSettle();

    // The one game the search left is a draw, so asking for 1-0 on top of it
    // leaves nothing at all.
    expect(find.text('kotjok77'), findsNothing,
        reason: 'the chip searched the whole collection again instead of '
            'narrowing what the search had left');
    expect(find.text('Kingston32gb'), findsNothing);
    expect(find.textContaining('No game matches'), findsOneWidget);
  });

  testWidgets('choosing a row closes the dialog and then reports it',
      (tester) async {
    // Phase 1's rule, and its order, carried over the rewrite. A row is the
    // target — there is no „Izaberi" button, deliberately.
    PgnGameInfo? chosen;
    await _open(tester, _shelf(), onSelected: (g) => chosen = g);

    expect(find.text('kotjok77'), findsOneWidget,
        reason: 'the white player is not a cell of its own');
    await tester.tap(find.text('kotjok77'));
    await tester.pumpAndSettle();

    expect(find.byType(GameSelectorDialog), findsNothing);
    expect(chosen?.headers['White'], 'kotjok77');
  });

  // 568 x 320 is a small phone on its side — the shortest screen this app is
  // built for. It is here because a mutation survived without it: putting the
  // old `clamp(240, …)` floor back changes nothing at 360 tall, where the
  // chrome now leaves 248, so the rule only bites on a screen shorter than
  // that. A floor that is harmless at every size the gate pumps is a floor
  // nobody can see come back.
  for (final size in [
    const Size(760, 360),
    const Size(932, 430),
    const Size(568, 320),
  ]) {
    testWidgets(
        'a phone on its side still shows a list — ${size.width.toInt()}'
        ' x ${size.height.toInt()}', (tester) async {
      // Reported live by the owner, 21.9.2026: „ne vidi se lista partija, nije
      // skrolabilno". Measured before the fix: at 760 x 360 the list was
      // **0.0 px tall with no rows at all** and a `RenderFlex` overflowed by
      // 36; at 932 x 430 it was 34 px and one row.
      //
      // The cause is a height asked for rather than taken. The dialog sized
      // its content `(screenHeight - 240).clamp(240, 720)`, and that **lower
      // clamp** demands 240 px on a screen that has about 200 to give once
      // the title, the actions and the insets are out. Everything above the
      // list — search, filter chips, column header — then ate what was left.
      //
      // So the case asserts what a reader needs, not a formula: some rows,
      // and no clipping.
      await _open(tester, _many(), size: size);

      final list = find.descendant(
        of: find.byType(GameSelectorDialog),
        matching: find.byType(ListView),
      );
      expect(list, findsOneWidget);
      final height = tester.getSize(list.first).height;

      expect(height, greaterThanOrEqualTo(100),
          reason: 'the list is $height tall at $size — there is nothing to '
              'read and nothing to scroll');
      // Measured, not wished for. A 320 px screen holds a title, a search
      // row, the filter chips and a Cancel button, and what is left is two
      // stacked rows — the dialog there is 294 px tall in all. Asking for
      // three would be asking the screen for height it does not have, and a
      // check that cannot pass is worth no more than one that cannot fail.
      final wantRows = size.height >= 360 ? 3 : 2;
      expect(_rowsBuilt(), greaterThanOrEqualTo(wantRows),
          reason: 'only ${_rowsBuilt()} rows are built at $size');
      expect(tester.takeException(), isNull);

      // And the dialog fits the screen it is on. Added because a mutation
      // that under-counted the chrome — making the content box taller than
      // the screen — left every assertion above green: a dialog too tall for
      // its window is **clipped by the overlay**, and clipping raises no
      // exception, in a test build or a release one. The same lesson the two
      // boards taught on 20.9.2026, in a third shape.
      //
      // „Cancel" is the bottom of the dialog and the thing a reader reaches
      // for when they give up, so it is the honest thing to measure.
      final cancelBottom = tester.getBottomLeft(find.text('Cancel')).dy;
      expect(cancelBottom, lessThanOrEqualTo(size.height),
          reason: 'the dialog runs $cancelBottom px down a ${size.height} px '
              'screen, so its bottom — Cancel included — is off it');
    });
  }

  // **Two mutations survive these cases, and the reason is worth keeping.**
  // Putting the old `clamp(240, …)` floor back, and under-counting the
  // dialog's chrome so the content box asks for far more than the screen has,
  // both leave every case above green. `AlertDialog` **caps its content to
  // the height that is actually available**, so the number this dialog
  // computes is only an upper bound — it cannot push the dialog off the
  // screen, and once the chrome above the list is small the floor never
  // binds either.
  //
  // What actually fixed the owner's report is the compact header: sideways,
  // the filter chips sit **beside** the search instead of under it, which is
  // 52 px, and 52 px is the difference between a list of zero rows and a list
  // of four. That change is guarded — forcing `short` to false turns both
  // landscape cases red. The two survivors are inert numbers rather than
  // holes, and they are recorded here instead of being chased with a case
  // that would have to assert a formula rather than what a reader sees.

  testWidgets('nothing overflows at either size', (tester) async {
    await _open(tester, _many(), size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    await _open(tester, _many(), size: const Size(1400, 900));
    expect(tester.takeException(), isNull);
  });
}
