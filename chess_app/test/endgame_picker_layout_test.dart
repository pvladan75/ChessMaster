// `docs/PLAN-LISTE.md`, phase 4 — „What to drill" spends the width it is
// given instead of running the seven families down one column.
//
// Two things make this screen different from the lists phases 3a and 3b put
// on the grid, and both are what this file is really about:
//
//  * **A family grows when it is opened.** Rook endings alone come in
//    thirteen shapes, so a card that is 72 px tall shut is some 800 tall
//    open. A grid cell has one height for every cell in the sheet, so
//    pattern A's `mainAxisExtent` cannot hold this list: either the open
//    family overflows its cell, or every shut family is given the open one's
//    height and the window fills with air — which is exactly the complaint
//    phase 3a was amended for.
//  * **Opening one family must not move the others.** That is the whole gain
//    over a `ListView`: today a tap on Rook endings pushes Pawn endings some
//    700 px down the page, so the reader loses their place to look at one
//    thing.
//
// Every layout claim below is read from **where the cards are painted**. None
// is a width threshold: phase 1 paid for that lesson — a width assertion
// passed on master while the fault stood, because the box was laid out under
// an `IntrinsicWidth` and given more than it asked for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart'
    show EndgameMode;
import 'package:chess_app/features/endgame_trainer/screens/endgame_picker_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

class _FakeApi extends EndgameApiService {
  _FakeApi(this.catalog) : super(authToken: '');

  final EndgameCatalog catalog;

  @override
  Future<EndgameCatalog?> fetchCatalog({
    EndgameMode? mode,
    bool includeOnline = false,
  }) async =>
      catalog;
}

/// Six families, the first of them thirteen shapes deep.
///
/// The real catalogue has seven families and rook endings really does carry
/// thirteen, so the fixture stands where the screen stands (rule 6). A
/// fixture with two families and two shapes each cannot fail the two cases
/// that matter here: it never fills a second row, and opening it never grows
/// a card by more than a line.
EndgameCatalog bigCatalog() {
  Map<String, dynamic> ending(int i) => {
        'material': 'KRP${i}vKR',
        'label': 'shape $i',
        'count': 10,
        'bands': {'b2000': 10},
      };
  Map<String, dynamic> family(String id, String name, int shapes) => {
        'id': id,
        'name': name,
        'count': 10 * shapes,
        'endings': [for (var i = 0; i < shapes; i++) ending(i)],
      };
  return EndgameCatalog.fromJson({
    'families': [
      family('rooks', 'Rook endings', 13),
      family('pawns', 'Pawn endings', 2),
      family('queens', 'Queen endings', 2),
      family('bishops', 'Bishop endings', 2),
      family('knights', 'Knight endings', 2),
      family('mixed', 'Mixed endings', 2),
    ],
    'bands': [
      {'id': 'b2000', 'name': '2000 - 2200'},
    ],
    'oppositeBishops': 0,
  });
}

Future<void> pumpPicker(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: EndgamePickerScreen(
      session: UserSession(
          token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
      mode: EndgameMode.draw,
      api: _FakeApi(bigCatalog()),
      onStart: (_) {},
    ),
  ));
  await tester.pumpAndSettle();

  // The screen opens its biggest family by itself, so that an all-shut list
  // does not look like it holds nothing. Every case below states its own
  // starting point instead of inheriting that one, and a shut catalogue is
  // the state in which all six families are actually built — a `ListView`
  // builds nothing below the fold, and rook endings open is taller than the
  // window.
  await setFamilyOpen(tester, 'Rook endings', false);
}

/// The card a family's name is drawn inside.
///
/// Found through the name rather than through a key or a type, so the finder
/// keeps working whatever the family is wrapped in — and so that a red here
/// is an assertion about the layout and not a rename.
Finder familyCard(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Card)).first;

Offset cardAt(WidgetTester tester, String name) =>
    tester.getTopLeft(familyCard(name));

/// Puts the family whose card carries [name] into the [open] state, and
/// asserts it got there.
///
/// Tapping the chevron blind would be a toggle, and a toggle reads whichever
/// way the screen happened to start — which is how a case ends up asserting
/// about a shut family it believed it had opened.
Future<void> setFamilyOpen(WidgetTester tester, String name, bool open) async {
  final chevron = find.descendant(
      of: familyCard(name),
      matching: find.byIcon(open ? Icons.expand_more : Icons.expand_less));
  if (chevron.evaluate().isNotEmpty) {
    await tester.tap(chevron);
    await tester.pumpAndSettle();
  }
  expect(
    find.descendant(
        of: familyCard(name),
        matching: find.byIcon(open ? Icons.expand_less : Icons.expand_more)),
    findsOneWidget,
    reason: '$name is not ${open ? 'open' : 'shut'}',
  );
}

/// How many columns `AdaptiveCardGrid` — the one home for this arithmetic —
/// would draw when handed exactly [width].
///
/// The picker must not answer this question for itself. A screen that wrote
/// its own count down would agree with the grid at one width and drift at the
/// next; this reads the answer out of the grid's own rendering, so the two
/// cannot separate without a red.
Future<int> gridColumnsAt(WidgetTester tester, double width) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 2000,
          child: AdaptiveCardGrid(
            padding: EdgeInsets.zero,
            itemCount: 24,
            itemBuilder: (context, i) =>
                Card(key: ValueKey('probe-$i'), child: Text('$i')),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final tops = <double>[];
  for (var i = 0; i < 24; i++) {
    final f = find.byKey(ValueKey('probe-$i'));
    if (f.evaluate().isEmpty) continue;
    tops.add(tester.getTopLeft(f).dy);
  }
  final first = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((t) => (t - first).abs() < 0.5).length;
}

void main() {
  testWidgets('on a wide window the families stand side by side',
      (tester) async {
    await pumpPicker(tester, const Size(1400, 900));

    final rooks = cardAt(tester, 'Rook endings');
    final pawns = cardAt(tester, 'Pawn endings');

    expect(pawns.dy, rooks.dy,
        reason: 'the second family is still under the first — the width is '
            'being spent on the gap inside a row rather than on a second row');
    expect(pawns.dx, greaterThan(rooks.dx));
  });

  testWidgets('the column count is the one the shared grid would give',
      (tester) async {
    // Rule 12: the 420 and the count formula live in `AdaptiveCardGrid` and
    // nowhere else. The header switch spans the whole content width, so it is
    // what the screen actually had to divide up.
    await pumpPicker(tester, const Size(1400, 900));

    final innerWidth = tester.getSize(find.byType(SwitchListTile).first).width;

    const names = [
      'Rook endings',
      'Pawn endings',
      'Queen endings',
      'Bishop endings',
      'Knight endings',
      'Mixed endings',
    ];
    final firstRowTop = cardAt(tester, names.first).dy;
    final inFirstRow = names
        .where((n) => (cardAt(tester, n).dy - firstRowTop).abs() < 0.5)
        .length;

    expect(inFirstRow, await gridColumnsAt(tester, innerWidth));
  });

  testWidgets('on a phone it is one family per line', (tester) async {
    await pumpPicker(tester, const Size(360, 900));

    final rooks = cardAt(tester, 'Rook endings');
    final pawns = cardAt(tester, 'Pawn endings');

    expect(pawns.dx, rooks.dx);
    expect(pawns.dy, greaterThan(rooks.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a family leaves its neighbours where they were',
      (tester) async {
    // The gain over a `ListView`, stated as a rule: thirteen shapes unfold
    // inside one column and the rest of the catalogue does not move.
    await pumpPicker(tester, const Size(1400, 900));

    final before = cardAt(tester, 'Pawn endings');
    await setFamilyOpen(tester, 'Rook endings', true);

    expect(find.text('shape 0'), findsOneWidget,
        reason: 'the family did not actually unfold its shapes');
    // Asked without `.first`, so that a neighbour pushed off the page is an
    // assertion here and not a `Bad state` out of the finder — which is the
    // difference between a catch and a crash (rule 3).
    expect(
      find.ancestor(of: find.text('Pawn endings'), matching: find.byType(Card)),
      findsOneWidget,
      reason: 'thirteen shapes pushed the next family off the page',
    );
    expect(cardAt(tester, 'Pawn endings'), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tall family in a short window overflows nothing',
      (tester) async {
    // 1400 x 600: thirteen shapes are taller than the window they open in.
    await pumpPicker(tester, const Size(1400, 600));
    await setFamilyOpen(tester, 'Rook endings', true);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an open family overflows nothing on a phone either',
      (tester) async {
    await pumpPicker(tester, const Size(360, 640));
    await setFamilyOpen(tester, 'Rook endings', true);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the level chips and the switch stay a full-width header',
      (tester) async {
    // Owner's decision, written into the phase: the families get columns, the
    // controls above them do not become one of those columns.
    await pumpPicker(tester, const Size(1400, 900));

    final header = tester.getSize(find.byType(SwitchListTile).first).width;
    final card = tester.getSize(familyCard('Rook endings')).width;

    expect(header, greaterThan(card * 1.5));
    expect(find.text('All levels'), findsOneWidget);
  });
}
