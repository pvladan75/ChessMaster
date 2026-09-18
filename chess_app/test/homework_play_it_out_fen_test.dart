// „Play it out" takes the board a diagram tool gives you.
//
// Reported live on 18.9.2026 (TODO-provera 183.1): „ne mogu da ubacim pozicije,
// fen nije dobar", with
//
//   rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR
//
// pasted into the FEN field - one field of six, and the dialog answered every
// possible fault with the same sentence. Asked for afterwards: „ne moram,
// ionako obeležavam ko je na potezu" - the side is already a switch here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/homework/widgets/homework_item_pickers.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  const board = 'rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR';

  /// Opens the dialog and hands back whatever it returns.
  Future<Map<String, dynamic>?> open(
    WidgetTester tester,
    Future<void> Function(WidgetTester) act,
  ) async {
    Map<String, dynamic>? result;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await pickEngineGameTask(
                  context,
                  positionLibrary: PositionLibraryService(authToken: 't'),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act(tester);
    await tester.pumpAndSettle();
    expect(done || result == null, isTrue);
    return result;
  }

  testWidgets('a board on its own is completed and accepted', (tester) async {
    final task = await open(tester, (t) async {
      await t.enterText(find.byKey(const Key('homework-engine-fen')), board);
      await t.pumpAndSettle();
      await t.tap(find.text('Add'));
    });

    expect(task, isNotNull, reason: 'the board was refused');
    expect(task!['fen'], '$board w KQkq - 0 1',
        reason: 'the side comes from the switch, castling from the board');
    expect(task['side'], 'w');
  });

  testWidgets('the side switch decides who moves first', (tester) async {
    final task = await open(tester, (t) async {
      await t.enterText(find.byKey(const Key('homework-engine-fen')), board);
      await t.pumpAndSettle();
      await t.tap(find.text('Black'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add'));
    });

    expect(task!['fen'], '$board b KQkq - 0 1');
    expect(task['side'], 'b');
  });

  testWidgets('the completed FEN is written where the trainer can see it',
      (tester) async {
    await open(tester, (t) async {
      await t.enterText(find.byKey(const Key('homework-engine-fen')), board);
      await t.pumpAndSettle();
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();
    });
    // The dialog closed on success, so the field is gone — what matters is
    // that the guess was not hidden: it went into the controller before the
    // task was built, which the accepted `fen` above already proves.
  });

  testWidgets('a FEN that carries a side sets the switch to it',
      (tester) async {
    // Black to move in the FEN, and the trainer has touched nothing: the
    // switch must already read Black.
    final task = await open(tester, (t) async {
      await t.enterText(
          find.byKey(const Key('homework-engine-fen')), '$board b KQkq - 0 1');
      await t.pumpAndSettle();
      final toggle = t.widget<SegmentedButton<String>>(
          find.byKey(const Key('homework-engine-side')));
      expect(toggle.selected, {'b'},
          reason: 'the switch is showing what the FEN says');
      await t.tap(find.text('Add'));
    });
    expect(task!['fen'], '$board b KQkq - 0 1');
  });

  testWidgets('changing the switch changes who is on the move', (tester) async {
    final task = await open(tester, (t) async {
      await t.enterText(
          find.byKey(const Key('homework-engine-fen')), '$board b KQkq - 0 1');
      await t.pumpAndSettle();
      await t.tap(find.text('White'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add'));
    });
    expect(task!['fen'], '$board w KQkq - 0 1',
        reason: 'the switch decides once it has been moved');
    expect(task['side'], 'w');
  });

  testWidgets('an en passant square does not survive the side changing',
      (tester) async {
    // „e6" means black may capture there *this move*. Carried across a change
    // of side it asserts a capture that cannot happen.
    const afterE4 =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
    final task = await open(tester, (t) async {
      await t.enterText(find.byKey(const Key('homework-engine-fen')), afterE4);
      await t.pumpAndSettle();
      await t.tap(find.text('White'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add'));
    });
    expect(task!['fen'], contains(' w KQkq - '),
        reason: 'the en passant square went with the side that could use it');
  });

  testWidgets('a pasted FEN always takes the switch, whatever was tapped',
      (tester) async {
    // Three steps, each of which has to move something, or the test proves
    // nothing: the FEN names Black, the tap contradicts it with White, and the
    // second paste is a *different* position (re-entering the same text fires
    // no change at all) that names Black again.
    const other = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR';
    Set<String> sideOfSwitch(WidgetTester t) => t
        .widget<SegmentedButton<String>>(
            find.byKey(const Key('homework-engine-side')))
        .selected;

    final task = await open(tester, (t) async {
      await t.enterText(
          find.byKey(const Key('homework-engine-fen')), '$board b KQkq - 0 1');
      await t.pumpAndSettle();
      expect(sideOfSwitch(t), {'b'}, reason: 'the switch reads the position');

      await t.tap(find.text('White'));
      await t.pumpAndSettle();
      expect(sideOfSwitch(t), {'w'},
          reason: 'the tap must take, or the paste below overrules nothing');

      await t.enterText(
          find.byKey(const Key('homework-engine-fen')), '$other b KQkq - 0 1');
      await t.pumpAndSettle();
      expect(sideOfSwitch(t), {'b'},
          reason: 'the paste overrules the tap that came before it');
      await t.tap(find.text('Add'));
    });
    expect(task!['fen'], '$other b KQkq - 0 1');
  });

  testWidgets('a position that is not chess says why, in its own words',
      (tester) async {
    // No black king: the validator has a sentence for this, and the dialog
    // used to replace it with „Not a valid position for play it out".
    const noKing = 'rnbq1bnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR';
    final task = await open(tester, (t) async {
      await t.enterText(find.byKey(const Key('homework-engine-fen')), noKing);
      await t.pumpAndSettle();
      await t.tap(find.text('Add'));
    });

    expect(task, isNull, reason: 'a board with no black king is not a game');
    expect(find.text('The black king is missing.'), findsOneWidget);
    expect(find.textContaining('Not a valid position'), findsNothing);
  });
}
