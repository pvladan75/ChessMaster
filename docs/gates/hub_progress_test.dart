// The Practise cards say what the player solved and offer the failed ones
// back — docs/PLAN-NAPREDAK-VEZBI.md §4, phase 2.
//
// The gate of the phase's hub half. Copied into chess_app/test/ by the
// implementer and left there green. Written 17.9.2026 against the seam
// (`progress` and `onRetry` on CategorySelectionHubWidget, not yet drawn), so
// every test but the first is red on master for the right reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';

SourceProgress _p({int seen = 0, int solved = 0, int toRetry = 0}) =>
    SourceProgress(
        seen: seen,
        solved: solved,
        firstTry: solved,
        failed: seen - solved,
        skipped: 0,
        toRetry: toRetry);

void main() {
  final retried = <String>[];
  setUp(retried.clear);

  Future<void> pump(WidgetTester tester,
      {Map<String, SourceProgress>? progress}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CategorySelectionHubWidget(
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
            progress: progress,
            onRetry: retried.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing read, no card says a number', (tester) async {
    await pump(tester);
    expect(find.textContaining('Solved'), findsNothing);
    expect(find.textContaining('to retry'), findsNothing);
    expect(find.textContaining('Retry failed'), findsNothing);
  });

  testWidgets('a card whose source has nothing seen says nothing',
      (tester) async {
    await pump(tester, progress: {
      PuzzleSource.endgame: _p(seen: 3, solved: 1, toRetry: 2),
    });
    // Endgames has a line; mates, tactics and the rest do not.
    expect(find.textContaining('Solved 1'), findsOneWidget);
    expect(find.textContaining('Solved 0'), findsNothing);
  });

  testWidgets('the line is „Solved N · M to retry", and the button carries M',
      (tester) async {
    await pump(tester, progress: {
      PuzzleSource.matePuzzle: _p(seen: 61, solved: 48, toRetry: 9),
      PuzzleSource.lichess: _p(seen: 210, solved: 154, toRetry: 39),
    });
    expect(find.text('Solved 48 · 9 to retry'), findsOneWidget);
    expect(find.text('Solved 154 · 39 to retry'), findsOneWidget);
    expect(find.text('Retry failed (9)'), findsOneWidget);
    expect(find.text('Retry failed (39)'), findsOneWidget);
  });

  testWidgets('nothing to retry: the line, and no button', (tester) async {
    await pump(tester, progress: {
      PuzzleSource.matePuzzle: _p(seen: 5, solved: 5, toRetry: 0),
    });
    expect(find.text('Solved 5'), findsOneWidget);
    expect(find.textContaining('to retry'), findsNothing);
    expect(find.textContaining('Retry failed'), findsNothing);
  });

  testWidgets('a source with no by-id gets the line and never the button',
      (tester) async {
    await pump(tester, progress: {
      PuzzleSource.basicMate: _p(seen: 4, solved: 2, toRetry: 2),
      PuzzleSource.blunderGame: _p(seen: 6, solved: 3, toRetry: 3),
    });
    expect(find.text('Solved 2 · 2 to retry'), findsOneWidget);
    expect(find.text('Solved 3 · 3 to retry'), findsOneWidget);
    expect(find.textContaining('Retry failed'), findsNothing);
  });

  testWidgets('endgames tally win and draw on one card', (tester) async {
    await pump(tester, progress: {
      PuzzleSource.endgame: SourceProgress(
        seen: 17,
        solved: 11,
        firstTry: 9,
        failed: 6,
        skipped: 0,
        toRetry: 4,
        buckets: {
          'win': _p(seen: 10, solved: 7, toRetry: 2),
          'draw': _p(seen: 7, solved: 4, toRetry: 2),
        },
      ),
    });
    expect(find.text('Solved 11 · 4 to retry'), findsOneWidget);
    expect(find.text('Retry failed (4)'), findsOneWidget);
  });

  testWidgets('pressing the button names the source', (tester) async {
    await pump(tester, progress: {
      PuzzleSource.endgame: _p(seen: 3, solved: 1, toRetry: 2),
      PuzzleSource.lichess: _p(seen: 9, solved: 4, toRetry: 5),
    });
    await tester.ensureVisible(find.text('Retry failed (2)'));
    await tester.tap(find.text('Retry failed (2)'));
    await tester.pumpAndSettle();
    expect(retried, [PuzzleSource.endgame]);
    await tester.ensureVisible(find.text('Retry failed (5)'));
    await tester.tap(find.text('Retry failed (5)'));
    await tester.pumpAndSettle();
    expect(retried, [PuzzleSource.endgame, PuzzleSource.lichess]);
  });

  testWidgets('the cards fit a 360 dp phone with the lines drawn',
      (tester) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CategorySelectionHubWidget(
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
            progress: {
              for (final s in PuzzleSource.all)
                s: _p(seen: 120, solved: 99, toRetry: 21),
            },
            onRetry: retried.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Retry failed (21)'), findsNWidgets(4));
  });
}
