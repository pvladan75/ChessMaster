// Gate — `docs/PLAN-LISTE.md`, phase 1: Choose a game gets a search box.
//
// Written by the lead before the phase was briefed, and proved red on master.
//
// Everything here goes through the one public widget `GameSelectorDialog`,
// with the constructor it already has. That is deliberate: a gate that names a
// symbol which does not exist yet can only fail to *compile*, and a compile
// error is not the right red (CLAUDE.md, checks-and-tests rule 3). Every
// failing case below fails as an assertion about what is on the screen, so the
// implementer is free about internals and the red says what is missing.
//
// Two fixtures, for two different questions (rule 6 — a fixture that is
// luckier than the real thing cannot fail):
//
//   * `_few` — six games, for anything that counts rows. A `ListView.builder`
//     only builds what is on screen, so row assertions over 4126 would be
//     assertions about the scroll position.
//   * `_many` — 4126, the number the owner actually has, for the count in the
//     title and for the size of the dialog, neither of which depends on a row
//     being built.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';

PgnGameInfo _game({
  required String white,
  required String black,
  String date = '2026.07.04',
  String result = '1-0',
  String event = 'Casual game',
  required String body,
}) =>
    PgnGameInfo(
      headers: {
        'White': white,
        'Black': black,
        'Date': date,
        'Result': result,
        'Event': event,
      },
      pgnBody: body,
    );

/// Six games, each distinguishable by something different: a white name, a
/// black name, an opening move, and — the trap — an Event tag that matches
/// nothing else.
final _few = <PgnGameInfo>[
  _game(
      white: 'nightrook42',
      black: 'pvladan',
      body: '1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 1-0'),
  _game(
      white: 'PawnStorm2025',
      black: 'pvladan',
      result: '0-1',
      body: '1. e4 e6 2. Nf3 d5 3. e5 c5 4. b4 cxb4 0-1'),
  _game(
      white: 'pvladan',
      black: 'EndgameEnjoyer',
      result: '0-1',
      body: '1. e4 d5 2. exd5 Qxd5 3. Nc3 Qa5 0-1'),
  _game(
      white: 'pvladan',
      black: 'lasker_fan',
      result: '0-1',
      body: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 0-1'),
  _game(
      white: 'bishopblunder',
      black: 'pvladan',
      result: '0-1',
      body: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 0-1'),
  // The trap for case 4: "zagreb" appears in this game and in no other, and
  // only in a header the search must not read. A search that scans the whole
  // header map instead of the two player names passes every other case here
  // and fails this one.
  _game(
      white: 'anderssen',
      black: 'kieseritzky',
      event: 'Zagreb Open',
      body: '1. e4 e5 2. f4 exf4 3. Bc4 Qh4+ 1-0'),
];

/// 4126 games — the owner's real collection size, and the number in the
/// screenshot the plan was written from. Exactly two of them are played by
/// `nightrook42`, so the count in the title is a fact and not a coincidence.
final _many = <PgnGameInfo>[
  for (var i = 0; i < 4126; i++)
    _game(
      white: i == 17 || i == 3999 ? 'nightrook42' : 'player$i',
      black: 'opponent$i',
      body: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0',
    ),
];

Future<void> _open(
  WidgetTester tester,
  List<PgnGameInfo> games, {
  Size size = const Size(1400, 900),
  void Function(PgnGameInfo game)? onSelected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
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
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String query) async {
  final field = find.byType(TextField);
  expect(field, findsOneWidget,
      reason: 'the dialog has exactly one search field — no field at all is '
          'the state this phase starts from, and two means a second one was '
          'added somewhere');
  await tester.enterText(field, query);
  await tester.pumpAndSettle();
}

/// Records pops in the order they happen, so a test can tell *when* the route
/// went away rather than only that it did.
class _PopSpy extends NavigatorObserver {
  _PopSpy(this.events);

  final List<String> events;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add('pop');
    super.didPop(route, previousRoute);
  }
}

void main() {
  // ---------------------------------------------------------------- already true
  // Two cases below pass on master. They are here not to catch the missing
  // feature but to hold still what the change could break, which is the only
  // reason a gate ever contains a green case.

  testWidgets('unfiltered, the title still says how many there are',
      (tester) async {
    await _open(tester, _many);
    expect(find.textContaining('4126'), findsOneWidget);
  });

  testWidgets('choosing a game closes the dialog and then reports it',
      (tester) async {
    // The order is load-bearing: `board_setup_dialog._loadPgnContent` awaits
    // this dialog and writes the chosen game into its text box, so a callback
    // that fires before the pop, or a pop that never happens, hangs that
    // caller. The current dialog pops first and calls back second; keep it.
    PgnGameInfo? chosen;
    await _open(tester, _few, onSelected: (g) => chosen = g);
    await tester.tap(find.textContaining('nightrook42'));
    await tester.pumpAndSettle();

    expect(chosen, isNotNull, reason: 'the caller was never told');
    expect(chosen!.headers['White'], 'nightrook42');
    expect(find.byType(GameSelectorDialog), findsNothing,
        reason: 'the dialog is still open after a game was chosen');
  });

  testWidgets('a 360 dp phone draws it without overflowing', (tester) async {
    await _open(tester, _many, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------------- the phase

  testWidgets('a query narrows the list by the player names', (tester) async {
    await _open(tester, _few);
    await _type(tester, 'nightrook');

    expect(find.textContaining('nightrook42'), findsOneWidget);
    expect(find.textContaining('PawnStorm2025'), findsNothing);
    expect(find.textContaining('bishopblunder'), findsNothing);
  });

  testWidgets('a query narrows the list by the moves as well', (tester) async {
    await _open(tester, _few);
    // Only the Kieseritzky game has 2. f4; four of the six open 1. e4, so a
    // search that matched the whole blob loosely would keep more than one.
    await _type(tester, 'f4 exf4');

    expect(find.textContaining('kieseritzky'), findsOneWidget);
    expect(find.textContaining('pvladan'), findsNothing);
  });

  testWidgets('the search reads the players and the moves, and nothing else',
      (tester) async {
    // "Zagreb" is in one Event tag and nowhere else. A search over the whole
    // header map would find it, and would also mean that typing a date or a
    // result silently reorders the list.
    await _open(tester, _few);
    await _type(tester, 'zagreb');

    expect(find.textContaining('kieseritzky'), findsNothing,
        reason: 'the Event tag was searched');
  });

  testWidgets('while filtering, the title says how many of how many',
      (tester) async {
    await _open(tester, _many);
    await _type(tester, 'nightrook42');
    expect(find.textContaining('2 of 4126'), findsOneWidget);
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await _open(tester, _few);
    await _type(tester, 'qqqzzz');

    expect(find.textContaining('No game matches'), findsOneWidget);
    for (final name in ['nightrook42', 'pvladan', 'kieseritzky']) {
      expect(find.textContaining(name), findsNothing,
          reason: '$name is still drawn under an empty result');
    }
  });

  testWidgets('on a tall window the list is taller than a phone\'s',
      (tester) async {
    // The state this phase starts from is `SizedBox(width: 400, height: 300)`,
    // so a 900 px tall window shows the same five rows out of 4126 that a
    // phone does. **The height is the fixed dimension and the one that
    // matters** — it is what "five visible out of 4126" measures.
    //
    // The width is deliberately not asserted here, and the reason is worth
    // keeping: measured against master on 20.9.2026, that `SizedBox` asks for
    // 400 and is given **912**. `AlertDialog` lays title, content and actions
    // out under an `IntrinsicWidth`, which takes the widest intrinsic — the
    // title string — and forces every child to it. So master's width is not
    // fixed at 400, it is whatever the title happens to measure in whatever
    // font, which no threshold can describe honestly. `BoardPreviewDialog`
    // already carries this warning in a comment; the brief says to take the
    // width from `MediaQuery` for the same reason.
    //
    // Measured on the list, not on `Dialog`: a `Dialog`'s own render box is
    // the whole overlay and reads the full window, so an assertion on it
    // passes while the visible card is still small.
    await _open(tester, _many, size: const Size(1400, 900));
    final list = find.descendant(
      of: find.byType(GameSelectorDialog),
      matching: find.byType(ListView),
    );
    expect(list, findsOneWidget);
    final height = tester.getSize(list.first).height;
    expect(height, greaterThan(480),
        reason: 'the list is $height tall in a 900 px window — master gives '
            'exactly 300 here, the same as on a phone, which is the whole '
            'premise of docs/PLAN-LISTE.md in one number');
  });

  testWidgets('the dialog is popped before the caller is told', (tester) async {
    // Added after the case above it survived a mutation. „Closes the dialog
    // and then reports it" asserted that both things happened and could not
    // see the order: swapping `Navigator.pop` and `onGameSelected` left all
    // nine cases green (measured 20.9.2026). A pop is only observable at the
    // moment it happens, so this watches the navigator rather than the tree.
    //
    // The order is the original code's choice and it is worth holding: the
    // board screen's callback can put a message on the screen, and a message
    // raised from under a dialog that is about to close is the shape this
    // project has been bitten by before.
    final events = <String>[];
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [_PopSpy(events)],
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => GameSelectorDialog(
                  games: _few,
                  onGameSelected: (_) => events.add('told'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('nightrook42'));
    await tester.pumpAndSettle();

    expect(events, ['pop', 'told'],
        reason: 'the caller was told before the dialog was popped');
  });
}
