// „Play it out": who is on the move, and who decides it.
//
// Reported live on 18.9.2026 (TODO-provera 183.1): „ne mogu da ubacim pozicije,
// fen nije dobar", with
//
//   rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR
//
// pasted into the FEN field - a board and nothing else, one field of six, and
// the dialog answered every possible fault with the same sentence.
//
// The rule for the side took three goes. The owner settled it: a FEN that names
// its side is not overruled by a switch, so there is no switch; a board that
// does not say is a question the trainer must answer deliberately, with nothing
// offered in advance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/homework/widgets/homework_item_pickers.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  const board = 'rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR';

  Future<Map<String, dynamic>?> open(
    WidgetTester tester,
    Future<void> Function(WidgetTester) act,
  ) async {
    Map<String, dynamic>? result;
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
    return result;
  }

  Future<void> type(WidgetTester t, String fen) async {
    await t.enterText(find.byKey(const Key('homework-engine-fen')), fen);
    await t.pumpAndSettle();
  }

  group('the FEN says who is to move', () {
    testWidgets('and then there is no switch to overrule it', (tester) async {
      final task = await open(tester, (t) async {
        await type(t, '$board b KQkq - 0 1');
        expect(find.byKey(const Key('homework-engine-side')), findsNothing,
            reason: 'the position answered; there is nothing to ask');
        expect(
            find.byKey(const Key('homework-engine-side-read')), findsOneWidget);
        expect(find.textContaining('Black to move'), findsOneWidget);
        await t.tap(find.text('Add'));
      });

      expect(task!['fen'], '$board b KQkq - 0 1',
          reason: 'the position is taken as it was given');
      expect(task['side'], 'b');
    });

    testWidgets('White reads as White', (tester) async {
      final task = await open(tester, (t) async {
        await type(t, '$board w KQkq - 0 1');
        expect(find.textContaining('White to move'), findsOneWidget);
        await t.tap(find.text('Add'));
      });
      expect(task!['side'], 'w');
    });
  });

  group('the FEN does not say', () {
    testWidgets('the switch appears, with nothing chosen', (tester) async {
      await open(tester, (t) async {
        await type(t, board);
        final toggle = t.widget<SegmentedButton<String>>(
            find.byKey(const Key('homework-engine-side')));
        expect(toggle.selected, isEmpty,
            reason: 'an answer offered in advance is an answer half-given');
        expect(
            find.byKey(const Key('homework-engine-side-read')), findsNothing);
      });
    });

    testWidgets('and Add is refused until it is answered', (tester) async {
      final task = await open(tester, (t) async {
        await type(t, board);
        await t.tap(find.text('Add'));
      });

      expect(task, isNull, reason: 'nobody said who moves');
      expect(
          find.textContaining('does not say who is to move'), findsOneWidget);
    });

    testWidgets('a deliberate choice completes the board and is taken',
        (tester) async {
      final task = await open(tester, (t) async {
        await type(t, board);
        await t.tap(find.text('Black'));
        await t.pumpAndSettle();
        await t.tap(find.text('Add'));
      });

      expect(task!['fen'], '$board b KQkq - 0 1',
          reason: 'castling is read off the board, the side from the choice');
      expect(task['side'], 'b');
    });

    testWidgets('a new position asks again from the start', (tester) async {
      const other = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR';
      await open(tester, (t) async {
        await type(t, board);
        await t.tap(find.text('White'));
        await t.pumpAndSettle();
        expect(
          t
              .widget<SegmentedButton<String>>(
                  find.byKey(const Key('homework-engine-side')))
              .selected,
          {'w'},
          reason: 'the tap must take, or the paste below clears nothing',
        );

        await type(t, other);
        expect(
          t
              .widget<SegmentedButton<String>>(
                  find.byKey(const Key('homework-engine-side')))
              .selected,
          isEmpty,
          reason: 'a different position is a different question',
        );
      });
    });
  });

  testWidgets('a position that is not chess says why, in its own words',
      (tester) async {
    const noKing = 'rnbq1bnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR';
    final task = await open(tester, (t) async {
      await type(t, '$noKing w KQ - 0 1');
      await t.tap(find.text('Add'));
    });

    expect(task, isNull);
    expect(find.text('The black king is missing.'), findsOneWidget);
    expect(find.textContaining('Not a valid position'), findsNothing);
  });
}
