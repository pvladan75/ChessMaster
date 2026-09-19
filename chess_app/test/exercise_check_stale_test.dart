// A check that answers late must not speak for a task the trainer has already
// left. Added by the lead while grading phase 5 of docs/PLAN-EXERCISE.md: the
// mutation that dropped the sheet's staleness guard survived the gate and the
// worker's own tests — their „switching the task" test uses a checker that
// answers at once, so the old answer never arrives after the new question.

import 'dart:async';

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

const _kpk = '8/8/8/3K4/3P4/8/8/3k4 w - - 0 1';

SyzygyResult _drawn() =>
    SyzygyResult.fromJson(_kpk, {'category': 'draw', 'moves': []});

void main() {
  testWidgets(
      'a slow answer about „Win" does not appear under „Draw or better"',
      (tester) async {
    final slow = Completer<SyzygyResult?>();
    var asked = 0;
    final checker = ExerciseChecker(
      // The first question is answered late; every later one at once.
      tablebase: (fen) {
        asked++;
        return asked == 1 ? slow.future : Future.value(_drawn());
      },
      engine: (fen) async => const <AnalysisLine>[],
      timeout: const Duration(seconds: 30),
    );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(
        body: MakeExerciseSheet(
          api: ExerciseApiService(
            authToken: 't',
            client: MockClient((r) async => http.Response('{}', 500)),
          ),
          moveTree: MoveTree(startingFen: _kpk),
          availableUserLabels: const [],
          checker: checker,
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('exercise-ask-win')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('exercise-side-w')));
    await tester.pump();
    expect(asked, 1, reason: 'the Win question is out, and unanswered');

    await tester.tap(find.byKey(const Key('exercise-ask-hold')));
    await tester.pump();
    await tester.pump();
    expect(asked, greaterThanOrEqualTo(2),
        reason: 'the new task is asked about');

    // Now the old answer arrives: a draw, which „Win" cannot meet — and which
    // is no finding at all for „Draw or better".
    slow.complete(_drawn());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('cannot be met'), findsNothing);
  });
}
