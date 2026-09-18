// exercise_check_own_test.dart — what `docs/gates/exercise_check_test.dart`
// cannot reach: the sheet's own layout and wiring for phase 5's check —
// findings shown under the solution, *Accept* moving them into it, and the
// save never held up for an answer that never comes.
//
// `docs/briefs/BRIEF-EXERCISE-FAZA5-APP.md`, „Your own tests". Every finding
// here comes from a fake `TablebaseAsk`/`EngineAsk` running under the real
// `ExerciseChecker` — fake the client, not the method — so the runner's own
// piece-count branching and the pure functions in `exercise_check.dart` are
// exercised for real, only their network/engine edge faked.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/services/exercise_checker.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart' show loadRoboto;

// White to move and winning: Kc6, Kd6 and Ke6 all keep the win, Kc4 lets it
// go — the same position `docs/gates/exercise_check_test.dart` reads it as.
const _kpk = '8/8/8/3K4/3P4/8/8/3k4 w - - 0 1';

SyzygyResult _tb(String fen, String category, Map<String, String> moves) =>
    SyzygyResult.fromJson(fen, {
      'category': category,
      'moves': [
        for (final m in moves.entries)
          {'uci': 'a1a1', 'san': m.key, 'category': m.value},
      ],
    });

final _winning = _tb(_kpk, 'win', {
  'Kc6': 'loss',
  'Kd6': 'loss',
  'Ke6': 'loss',
  'Kc4': 'draw',
  'Ke4': 'draw',
});

Future<List<AnalysisLine>> _noEngine(String fen) async => fail(
    'this scenario has seven pieces or fewer: the engine must not be asked');

/// A one-move "find" line from [_kpk]: the trainer's move [main], nothing
/// after it — a line ending on the student's own move needs no reply.
MoveTree _oneMoveLine(String main) {
  final tree = MoveTree.parsePgn('1. $main', startingFen: _kpk);
  if (tree == null) throw StateError('the test\'s own PGN did not parse');
  return tree;
}

Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(body: Builder(builder: (context) => dialog)),
    ),
  );
  await tester.pumpAndSettle();
}

http.Client _saveOk(List<http.Request> recorded) => MockClient((r) async {
      recorded.add(r);
      return http.Response(
          jsonEncode({
            'exercise': {
              'id': 'ex_1',
              'fen': _kpk,
              'sideToMove': 'w',
              'name': 'Name',
              'origin': 'trainer',
              'task': {'type': 'find'},
              'assignable': true,
            },
          }),
          201);
    });

MakeExerciseSheet _sheet({
  required ExerciseChecker checker,
  MoveTree? tree,
  http.Client? client,
}) =>
    MakeExerciseSheet(
      api: ExerciseApiService(
        authToken: 't',
        client: client ?? MockClient((r) async => http.Response('{}', 500)),
      ),
      moveTree: tree ?? _oneMoveLine('Kc6'),
      availableUserLabels: const [],
      checker: checker,
    );

void main() {
  setUpAll(loadRoboto);

  group('a finding under the solution', () {
    ExerciseChecker alsoKeepsChecker() => ExerciseChecker(
          tablebase: (fen) async => fen == _kpk ? _winning : null,
          engine: _noEngine,
        );

    Future<void> pumpAtSize(
        WidgetTester tester, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(body: Builder(builder: (context) => child)),
      ));
      await tester.pumpAndSettle();
    }

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'lays out with no overflow at ${size.width.toInt()}x${size.height.toInt()}, '
          'words and Accept present', (tester) async {
        await pumpAtSize(tester, size, _sheet(checker: alsoKeepsChecker()));
        expect(tester.takeException(), isNull);

        expect(find.textContaining('Kd6'), findsOneWidget,
            reason: 'the other move that keeps the win is named');
        expect(find.widgetWithText(TextButton, 'Accept'), findsOneWidget);
      });
    }
  });

  group('accepting, then saving', () {
    ExerciseChecker alsoKeepsChecker() => ExerciseChecker(
          tablebase: (fen) async => fen == _kpk ? _winning : null,
          engine: _noEngine,
        );

    testWidgets('without pressing Accept, the extra moves are not saved',
        (tester) async {
      final rec = <http.Request>[];
      await pumpDialog(
        tester,
        _sheet(checker: alsoKeepsChecker(), client: _saveOk(rec)),
      );

      await tester.enterText(find.byType(TextField).first, 'Endgame');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(rec, hasLength(1));
      final body = jsonDecode(rec.single.body) as Map<String, dynamic>;
      final solution = body['solution'] as List;
      final accept = (solution.single as Map)['accept'] as List;
      expect(accept, ['Kc6']);
    });

    testWidgets('pressing Accept adds the offered moves, after the main one',
        (tester) async {
      final rec = <http.Request>[];
      await pumpDialog(
        tester,
        _sheet(checker: alsoKeepsChecker(), client: _saveOk(rec)),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Accept'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Endgame');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(rec, hasLength(1));
      final body = jsonDecode(rec.single.body) as Map<String, dynamic>;
      final solution = body['solution'] as List;
      final accept = (solution.single as Map)['accept'] as List<dynamic>;
      expect(accept.first, 'Kc6', reason: 'the main move stays first');
      expect(accept.toSet(), {'Kc6', 'Kd6', 'Ke6'});
    });
  });

  group('the check never holds up Save', () {
    testWidgets(
        'askers that never answer: Save is enabled at once, the save goes '
        'through, and „Checking…" does not outlive the timeout',
        (tester) async {
      final rec = <http.Request>[];
      final checker = ExerciseChecker(
        tablebase: (fen) => Completer<SyzygyResult?>().future,
        engine: (fen) => Completer<List<AnalysisLine>>().future,
        timeout: const Duration(milliseconds: 60),
      );
      // A single, undelayed pump: enough to lay the sheet out, not enough for
      // pumpAndSettle's own 100ms step to already outrun the 60ms timeout.
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
            body: Builder(
                builder: (context) =>
                    _sheet(checker: checker, client: _saveOk(rec)))),
      ));
      await tester.pump();

      expect(find.text('Checking…'), findsOneWidget,
          reason: 'the check is still in flight right after the sheet opens');

      await tester.enterText(find.byType(TextField).first, 'Endgame');
      await tester.pump();
      final saveButton = tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));
      expect(saveButton.onPressed, isNotNull,
          reason: 'Save must not wait for an answer that never comes');

      // Past the checker's own timeout: the line saying so goes, on time,
      // whether or not anybody answered.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Checking…'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(rec, hasLength(1), reason: 'the save itself still goes through');
    });
  });

  group('a warning offers nothing to accept', () {
    testWidgets(
        'a game task best play cannot meet: the words show, no Accept, '
        'and Save still works', (tester) async {
      final rec = <http.Request>[];
      final checker = ExerciseChecker(
        tablebase: (fen) async => _tb(_kpk, 'draw', {}),
        engine: _noEngine,
      );
      await pumpDialog(
        tester,
        _sheet(
          checker: checker,
          tree: MoveTree(startingFen: _kpk),
          client: _saveOk(rec),
        ),
      );

      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-side-w')));
      await tester.pumpAndSettle();

      expect(find.textContaining('draw'), findsOneWidget,
          reason: 'best play only draws, so "Win" cannot be met');
      expect(find.widgetWithText(TextButton, 'Accept'), findsNothing,
          reason: 'a warning is not an offer');

      await tester.enterText(find.byType(TextField).first, 'Hold the draw');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(rec, hasLength(1), reason: 'the check never blocks a save');
    });
  });

  group('the check is for the current choice', () {
    testWidgets('switching from Win to Draw or better drops the Win finding',
        (tester) async {
      final checker = ExerciseChecker(
        tablebase: (fen) async => _tb(_kpk, 'draw', {}),
        engine: _noEngine,
      );
      await pumpDialog(
        tester,
        _sheet(checker: checker, tree: MoveTree(startingFen: _kpk)),
      );

      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-side-w')));
      await tester.pumpAndSettle();
      expect(find.textContaining('draw'), findsOneWidget,
          reason: 'a win asked of a drawn position cannot be met');

      await tester.tap(find.byKey(const Key('exercise-ask-hold')));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be met'), findsNothing,
          reason: 'holding a draw is fine, so the Win finding is gone');
    });
  });
}
