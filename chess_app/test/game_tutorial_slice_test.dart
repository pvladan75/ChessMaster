// The two questions a trainer is asked around the engine - points 1 and 6 of
// the owner's live pass, 14.9.2026 - as phase 1b of
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md left them.
//
// Rewritten on 25.9.2026, openly. Until then both dialogs carried a pawn
// slider ("Teach a move that cost X pawns or more"), and this file held the
// count to it. The owner took the pawn rule out that day: a tutorial's moments
// are the moves the review's own judge calls mistakes, and the only moves a
// player found, and there is no threshold left to slide. What stayed is the
// point of point 6 - the trainer is told how many there are, how many become
// parts, and that a game with too few cannot be written - before anything is
// paid for. The first dialog asks the depth alone, and starts at 20, the depth
// the rule's floor was measured at.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/widgets/game_tutorial_flow.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/app_slider.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A row whose move the judge called a mistake (the facts' best, d4, is not
/// the move played).
Map<String, dynamic> _mistake({double lost = 20, bool unsettled = false}) => {
      'fen': _fen,
      'played': {
        'move': 'e4',
        'judged': {
          'lost': lost,
          'mistake': !unsettled,
          'reason': unsettled ? null : 'lostChances',
          'unsettled': unsettled,
          'only': false,
        },
      },
      'candidates': [
        {'move': 'd4'}
      ],
    };

/// A row where the move played was the only one that held.
Map<String, dynamic> _only() => {
      'fen': _fen,
      'played': {
        'move': 'e4',
        'judged': {
          'lost': 0.0,
          'mistake': false,
          'reason': null,
          'unsettled': false,
          'only': true,
          'gap': 30.0,
        },
      },
      'candidates': [
        {'move': 'e4'}
      ],
    };

/// A row the judge found nothing wrong with.
Map<String, dynamic> _fine() => {
      'fen': _fen,
      'played': {
        'move': 'e4',
        'judged': {
          'lost': 2.0,
          'mistake': false,
          'reason': null,
          'unsettled': false,
          'only': false,
        },
      },
      'candidates': [
        {'move': 'd4'}
      ],
    };

Map<String, dynamic> _facts(List<Map<String, dynamic>> rows) => {'rows': rows};

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

const _write = Key('game-tutorial-slice-write');

String _found(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('game-tutorial-found'))).data!;

void main() {
  testWidgets(
      'the count is the judge\'s mistakes and the only moves found — an '
      'unsettled mistake and a fine move are neither', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        facts: _facts([
          _mistake(),
          _fine(),
          _mistake(lost: 12),
          _mistake(unsettled: true),
          _only(),
        ]),
        parameters: const SkeletonParameters(),
      ),
      answers: answers,
    );

    expect(_found(tester), '2 mistakes and 1 move where only one move held.');
    expect(
        find.text('All of them become parts of the tutorial.'), findsOneWidget);
    expect(find.byType(AppSlider), findsNothing,
        reason: 'there is no threshold left to slide');
  });

  testWidgets('the cap is said as well as the count', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        // Ten mistakes against a cap of eight: both numbers have to be said, or
        // "10 found" over a tutorial of eight parts reads as a fault in the
        // tutorial rather than as the cap doing its job.
        facts: _facts([for (var i = 0; i < 10; i++) _mistake()]),
        parameters: const SkeletonParameters(),
      ),
      answers: answers,
    );

    expect(_found(tester), '10 mistakes and 0 moves where only one move held.');
    expect(find.text('The 8 that matter most become parts of the tutorial.'),
        findsOneWidget);
  });

  testWidgets('fewer than two cannot be written, and says why', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        facts: _facts([_mistake(), _fine()]),
        parameters: const SkeletonParameters(),
      ),
      answers: answers,
    );

    expect(find.byKey(const Key('game-tutorial-too-few')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_write)).onPressed, isNull,
        reason: 'a tutorial of one is not offered');
  });

  testWidgets('a clean game says so at its depth, and what kept it unsure',
      (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        facts: _facts([_fine(), _mistake(unsettled: true)]),
        parameters: const SkeletonParameters(),
        depth: 20,
        unsettled: 1,
        unjudged: 2,
      ),
      answers: answers,
    );

    expect(find.text('Nothing to teach from at depth 20.'), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('game-tutorial-unsure'))).data,
        'The looks still disagreed on 1 move(s). '
        'The engine did not answer on 2 move(s).');
  });

  testWidgets('Write answers with the parameters it was given', (tester) async {
    final answers = <SkeletonParameters?>[];
    const parameters = SkeletonParameters(maxMoments: 5);
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        facts: _facts([_mistake(), _only()]),
        parameters: parameters,
      ),
      answers: answers,
    );
    await tester.tap(find.byKey(_write));
    await tester.pumpAndSettle();
    expect(answers.single, same(parameters));
  });

  testWidgets('Cancel answers nothing at all', (tester) async {
    final answers = <SkeletonParameters?>[];
    await _pumpSlice(
      tester,
      slice: GameTutorialSlice(
        facts: _facts([_mistake(), _only()]),
        parameters: const SkeletonParameters(),
      ),
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

    testWidgets('asks the depth alone, starting at 20', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('game-tutorial-depth')), findsOneWidget);
      expect(find.byType(AppSlider), findsOneWidget,
          reason: 'the pawn threshold is gone');
      expect(find.text('Depth 20'), findsOneWidget);
    });

    testWidgets('a depth remembered under the old key is not the start',
        (tester) async {
      // The old key held 18, the old default, for almost everyone.
      SharedPreferences.setMockInitialValues({'app_game_tutorial_depth': 18});
      await open(tester);
      expect(find.text('Depth 20'), findsOneWidget);
    });

    testWidgets('the depth chosen is remembered for next time', (tester) async {
      await open(tester);
      tester
          .widget<AppSlider>(find.byKey(const Key('game-tutorial-depth')))
          .onChanged!(22);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-tutorial-start')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kGameTutorialDepthPreference), 22);

      // Read back on the next opening, which is the point of keeping it: a
      // test that only read the preference would pass with nothing reading it.
      await open(tester);
      expect(find.text('Depth 22'), findsOneWidget);
    });
  });
}
