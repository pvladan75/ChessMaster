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
      'Započni trening': 'taktika',
      'Održi remi': 'zavrsnice:remi',
      'Greške iz partija': 'greske',
      'Mat u 1': 'mat:1',
      'Mat u 2': 'mat:2',
      'Mat u 3': 'mat:3',
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
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });
}
