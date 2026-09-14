// The two questions a trainer is asked around the engine - points 1 and 6 of
// the owner's live pass, 14.9.2026.
//
// Point 1 asked for a dialog like "Review game": depth *and* a blunder
// threshold, rather than depth alone. Point 6 asked to be told how many
// mistakes were found with those settings, so a trainer can try another slice
// when it is too few or too many.
//
// The second turned out cheaper than asked for. A game's answers are cached by
// game, depth and engine (`factsKey`) and the threshold is no part of that key,
// so re-slicing costs no engine time at all - the count answers while the
// slider moves, and nothing is spent until the trainer presses the button.
// "Run the analysis again" was never needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/widgets/game_tutorial_flow.dart';
import 'package:chess_app/theme/app_theme.dart';

/// Facts whose moves cost exactly [costs] pawns.
///
/// Written by hand rather than taken from a fixture, so the number a test
/// asserts is visible in the test that asserts it.
Map<String, dynamic> _facts({List<double> costs = const [2.2, 2.0, 1.2, 0.4]}) {
  const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  return {
    'rows': [
      for (final cost in costs)
        {
          'fen': fen,
          'played': {'move': 'e4', 'cost_pawns': cost},
          'candidates': [
            {'move': 'd4'}
          ],
        },
    ],
  };
}

Future<void> _pumpSlice(
  WidgetTester tester, {
  required GameTutorialSlice slice,
  required List<SkeletonParameters?> answers,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              answers.add(await chooseGameTutorialSlice(context, slice)),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

const _sliceSlider = Key('game-tutorial-slice-threshold');
const _write = Key('game-tutorial-slice-write');

/// Moves a slider to an exact value.
///
/// A pixel drag cannot: the range is 0.2 to 5.0 across whatever width the
/// dialog happens to have, so 200 px saturates it in a narrow one and lands
/// somewhere arbitrary in a wide one. One test below drags for real, to say the
/// control is reachable at all; the rest ask about a number, so they set one.
Future<void> _setSlider(WidgetTester tester, Key key, double value) async {
  tester.widget<Slider>(find.byKey(key)).onChanged!(value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the count is what the threshold finds, and follows the slider',
      (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
          facts: _facts(), parameters: const SkeletonParameters()),
      answers: answers,
    );

    // Three of the four cost a pawn or more.
    expect(find.text('3 moves cost 1.0 pawns or more.'), findsOneWidget);
    expect(
        find.text('All of them become parts of the tutorial.'), findsOneWidget);

    // At two pawns only two of them qualify.
    await _setSlider(tester, _sliceSlider, 2.0);
    expect(find.text('2 moves cost 2.0 pawns or more.'), findsOneWidget);

    // And the slider is a control a trainer can actually reach and move.
    await tester.drag(find.byKey(_sliceSlider), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 moves cost 2.0 pawns or more.'), findsNothing);
  });

  testWidgets('the cap is said as well as the count', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        // Ten mistakes against a cap of eight: both numbers have to be said, or
        // "10 found" over a tutorial of eight parts reads as a fault in the
        // tutorial rather than as the cap doing its job.
        facts: _facts(costs: List<double>.filled(10, 2.0)),
        parameters: const SkeletonParameters(),
      ),
      answers: answers,
    );

    expect(find.text('10 moves cost 1.0 pawns or more.'), findsOneWidget);
    expect(
        find.text('The 8 worst become parts of the tutorial.'), findsOneWidget);
  });

  testWidgets('fewer than two cannot be written, and says why', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
          facts: _facts(costs: const [2.0, 0.3]),
          parameters: const SkeletonParameters()),
      answers: answers,
    );

    expect(find.byKey(const Key('game-tutorial-too-few')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_write)).onPressed, isNull,
        reason: 'a tutorial of one is not offered');

    // And the way out is in the trainer's hands rather than in a refusal.
    await _setSlider(tester, _sliceSlider, 0.2);
    expect(find.byKey(const Key('game-tutorial-too-few')), findsNothing);
    expect(
        tester.widget<FilledButton>(find.byKey(_write)).onPressed, isNotNull);
  });

  testWidgets('the threshold it answers with is the one on the slider',
      (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
          facts: _facts(), parameters: const SkeletonParameters()),
      answers: answers,
    );
    await _setSlider(tester, _sliceSlider, 1.5);
    await tester.tap(find.byKey(_write));
    await tester.pumpAndSettle();

    expect(answers.single, isNotNull);
    expect(answers.single!.minCost, 1.5);
    // Everything else is the skeleton's own and no business of the trainer's.
    expect(answers.single!.maxMoments, const SkeletonParameters().maxMoments);
    expect(answers.single!.near, const SkeletonParameters().near);
  });

  testWidgets('Cancel answers nothing at all', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
          facts: _facts(), parameters: const SkeletonParameters()),
      answers: answers,
    );
    await tester.tap(find.byKey(const Key('game-tutorial-slice-cancel')));
    await tester.pumpAndSettle();
    expect(answers, [null]);
  });

  group('the first dialog', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => chooseGameTutorialDepth(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks the threshold beside the depth', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('game-tutorial-threshold')), findsOneWidget);
      expect(find.byKey(const Key('game-tutorial-depth-20')), findsOneWidget);
    });

    testWidgets('both are remembered for next time', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('game-tutorial-depth-20')));
      await tester.pumpAndSettle();
      await _setSlider(tester, const Key('game-tutorial-threshold'), 2.5);
      await tester.tap(find.byKey(const Key('game-tutorial-start')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kGameTutorialDepthPreference), 20);
      expect(prefs.getDouble(kGameTutorialThresholdPreference), 2.5);

      // Read back on the next opening, which is the point of keeping it: a
      // test that only read the preference would pass with nothing reading it.
      await open(tester);
      expect(find.textContaining('cost 2.5 pawns'), findsWidgets);
    });

    testWidgets('a remembered threshold off the slider is ignored',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {kGameTutorialThresholdPreference: 99.0});
      await open(tester);
      expect(
          find.textContaining(
              'cost ${kGameTutorialDefaultThreshold.toStringAsFixed(1)} pawns'),
          findsWidgets);
    });
  });
}
