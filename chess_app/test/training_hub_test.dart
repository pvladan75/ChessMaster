import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';

/// What the crossroads promises, card by card.
///
/// Written before the screen it lives in is taken apart. That screen is 2662
/// lines and does two jobs - the choosing and one of the things chosen - and
/// the split is about to move every one of these buttons. What must not change
/// while they move is where each one leads, and nothing else in the app says
/// so: three of these go by route today and three by a field on the state.
void main() {
  /// Pumps the hub and records which promise was called, with what.
  Future<List<String>> tapCard(WidgetTester tester, String label) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CategorySelectionHubWidget(
            onSelectMatePuzzle: (depth) => calls.add('mat:$depth'),
            onSelectBasicMate: (level) => calls.add('osnovno:$level'),
            onSelectWinningPosition: () => calls.add('dobijena'),
            onSelectTactics: () => calls.add('taktika'),
            onSelectEndgameWin: () => calls.add('zavrsnice:dobitak'),
            onSelectEndgameDraw: () => calls.add('zavrsnice:remi'),
            onSelectBlunderGames: () => calls.add('greske'),
            onSelectRepertoire: () => calls.add('repertoar'),
            onSelectMyGames: () => calls.add('moje partije'),
            onSelectMistakesDrill: () => calls.add('greske drill'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final button = find.text(label);
    expect(button, findsWidgets, reason: 'nema dugmeta „$label" na raskrsnici');
    await tester.ensureVisible(button.first);
    await tester.pumpAndSettle();
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('every card leads where its label says', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The whole map in one place, so the split has something to be checked
    // against rather than a memory of what used to happen.
    const promises = <String, String>{
      'Otvori repertoar': 'repertoar',
      'Započni trening': 'taktika',
      'Dobij': 'zavrsnice:dobitak',
      'Održi remi': 'zavrsnice:remi',
      'Greške iz partija': 'greske',
      'Mat u 1': 'mat:1',
      'Mat u 2': 'mat:2',
      'Mat u 3': 'mat:3',
      'Lako': 'osnovno:easy',
      'Srednje': 'osnovno:medium',
      'Teško': 'osnovno:hard',
      'Započni vežbanje dobitnih pozicija': 'dobijena',
      'Uvezi partije': 'moje partije',
    };

    for (final entry in promises.entries) {
      expect(await tapCard(tester, entry.key), [entry.value],
          reason: 'kartica „${entry.key}" vodi na pogrešno mesto');
    }
  });

  testWidgets('the two endgame modes are two different places', (tester) async {
    // Converting a win and holding a draw are separate exercises, not two views
    // of one, and the hub is where that distinction is first made.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expect(await tapCard(tester, 'Održi remi'), ['zavrsnice:remi']);
  });

  testWidgets('nothing fires on its own', (tester) async {
    // A crossroads that navigates without being asked is the worst kind, and
    // this is the cheapest possible guard against it surviving the split.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CategorySelectionHubWidget(
            onSelectMatePuzzle: (depth) => calls.add('mat:$depth'),
            onSelectBasicMate: (level) => calls.add('osnovno:$level'),
            onSelectWinningPosition: () => calls.add('dobijena'),
            onSelectTactics: () => calls.add('taktika'),
            onSelectEndgameWin: () => calls.add('zavrsnice:dobitak'),
            onSelectEndgameDraw: () => calls.add('zavrsnice:remi'),
            onSelectBlunderGames: () => calls.add('greske'),
            onSelectRepertoire: () => calls.add('repertoar'),
            onSelectMyGames: () => calls.add('moje partije'),
            onSelectMistakesDrill: () => calls.add('greske drill'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('the repertoire is its own section, not an endgame button',
      (tester) async {
    // It sat as a fourth button on the endgame card, where it read as one more
    // ending to solve. It is neither an ending nor an exercise set, so what
    // this guards is the grouping itself: if it is ever folded back under
    // another card, this fails.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategorySelectionHubWidget(
          onSelectMatePuzzle: (_) {},
          onSelectBasicMate: (_) {},
          onSelectWinningPosition: () {},
          onSelectTactics: () {},
          onSelectEndgameWin: () {},
          onSelectEndgameDraw: () {},
          onSelectBlunderGames: () {},
          onSelectRepertoire: () {},
          onSelectMyGames: () {},
          onSelectMistakesDrill: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final endgameCard = find
        .ancestor(
          of: find.text('Završnice iz majstorskih partija'),
          matching: find.byType(Card),
        )
        .first;
    expect(
      find.descendant(of: endgameCard, matching: find.text('Otvori repertoar')),
      findsNothing,
      reason: 'repertoar je opet završio u kartici završnica',
    );

    // And the three groups the cards are ordered by are actually labelled.
    for (final label in const [
      'OTVARANJE',
      'TAKTIKA',
      'ZAVRŠNICA I TEHNIKA',
    ]) {
      expect(find.text(label), findsOneWidget,
          reason: 'nema naslova sekcije „$label”');
    }
  });

  testWidgets('the hub fits a 360 dp phone', (tester) async {
    // A release build paints no overflow warning - it just clips, and a button
    // past the edge cannot be pressed. In a test build the overflow throws,
    // which is the only cheap place to catch it.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategorySelectionHubWidget(
          onSelectMatePuzzle: (_) {},
          onSelectBasicMate: (_) {},
          onSelectWinningPosition: () {},
          onSelectTactics: () {},
          onSelectEndgameWin: () {},
          onSelectEndgameDraw: () {},
          onSelectBlunderGames: () {},
          onSelectRepertoire: () {},
          onSelectMyGames: () {},
          onSelectMistakesDrill: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
