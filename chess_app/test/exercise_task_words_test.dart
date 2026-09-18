// What an exercise asks, in words — `lib/features/exercises/models/
// exercise_task_words.dart`, the one home three screens read
// (docs/PLAN-EXERCISE.md, decision 1).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/exercises/models/exercise_task_words.dart';

const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  test('a task is one of three things to ask, and no task means „find"', () {
    expect(exerciseAskOf(null), ExerciseAsk.find);
    expect(exerciseAskOf({'type': 'find'}), ExerciseAsk.find);
    expect(exerciseAskOf({'type': 'game', 'goal': 'win'}), ExerciseAsk.win);
    expect(exerciseAskOf({'type': 'game', 'goal': 'hold'}), ExerciseAsk.hold);
    // The older spelling of „draw or better, for N moves".
    expect(
        exerciseAskOf({'type': 'game', 'goal': 'survive'}), ExerciseAsk.hold);
  });

  test('the words name the side and how long, and nothing that is not asked',
      () {
    expect(exerciseTaskWords(null), 'Find the move');
    expect(
        exerciseTaskWords({'type': 'find'}, solutionMoves: 1), 'Find the move');
    expect(exerciseTaskWords({'type': 'find'}, solutionMoves: 3),
        'Find the moves');
    expect(exerciseTaskWords({'type': 'game', 'goal': 'win', 'side': 'w'}),
        'Win as White');
    expect(
        exerciseTaskWords(
            {'type': 'game', 'goal': 'hold', 'side': 'b', 'surviveMoves': 4}),
        'Draw or better as Black, for 4 moves');
    expect(
        exerciseTaskWords({
          'type': 'game',
          'goal': 'survive',
          'side': 'b',
          'surviveMoves': 1
        }),
        'Draw or better as Black, for 1 move');
    // A number that is not one is not „for N moves".
    expect(
        exerciseTaskWords(
            {'type': 'game', 'goal': 'win', 'side': 'w', 'surviveMoves': 0}),
        'Win as White');
    expect(exerciseForMoves({'type': 'find', 'surviveMoves': 3}), isNull);
    expect(exerciseForMoves({'type': 'game', 'surviveMoves': '5'}), 5);
  });

  test('who is to move is said in words', () {
    expect(sideToMoveWords(_krk), 'White to move');
    expect(sideToMoveWords('8/8/8/8/8/4k3/8/R3K3 b - - 0 1'), 'Black to move');
    // A board and nothing more: White, as every reader of a diagram assumes.
    expect(sideToMoveWords('8/8/8/8/8/4k3/8/R3K3'), 'White to move');
  });

  test('pieces are counted off the board field only', () {
    expect(exercisePieceCount(_krk), 3);
    expect(exercisePieceCount(_start), 32);
    expect(exercisePieceCount('8/8/8/4k3/8/4K3/4P3/8 b KQkq - 0 1'), 3);
  });

  test('who will judge a game is known when it is written', () {
    ExerciseJudge j(String fen, ExerciseAsk ask, int? n) =>
        exerciseJudgeFor(fen: fen, ask: ask, forMoves: n);
    expect(j(_krk, ExerciseAsk.win, null), ExerciseJudge.rules);
    expect(j(_start, ExerciseAsk.hold, null), ExerciseJudge.rules);
    expect(j(_krk, ExerciseAsk.win, 3), ExerciseJudge.tablebase);
    expect(j(_krk, ExerciseAsk.hold, 3), ExerciseJudge.tablebase);
    expect(j(_start, ExerciseAsk.hold, 3), ExerciseJudge.notMatedOnly);
    expect(j(_start, ExerciseAsk.win, 3), ExerciseJudge.refused);
    expect(j(_start, ExerciseAsk.find, 3), ExerciseJudge.rules);
    // Four sentences, four different ones.
    expect(ExerciseJudge.values.map(exerciseJudgeWords).toSet().length, 4);
  });

  test('„refused" here is what the server refuses, on the shared fixture', () {
    // docs/gates/engine_game_cases.json → forMoves.rejected: the server's
    // `parseEngineGameTask` refuses these, so the sheet must not offer them.
    final fixture = jsonDecode(
            File('../docs/gates/engine_game_cases.json').readAsStringSync())
        as Map<String, dynamic>;
    final forMoves = fixture['forMoves'] as Map<String, dynamic>;
    final tooBig = (forMoves['rejected'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => (c['why'] as String).contains('7 pieces'));
    final task = tooBig['task'] as Map<String, dynamic>;
    expect(
      exerciseJudgeFor(
        fen: task['fen'] as String,
        ask: exerciseAskOf({'type': 'game', ...task}),
        forMoves: exerciseForMoves({'type': 'game', ...task}),
      ),
      ExerciseJudge.refused,
    );
    // And every case the server judges by tablebase is one this says it will.
    for (final c in (forMoves['judged'] as List).cast<Map<String, dynamic>>()) {
      final t = c['task'] as Map<String, dynamic>;
      final expectTb = (c['expect'] as Map)['needsTablebase'] == true;
      if (!expectTb) continue;
      expect(
        exerciseJudgeFor(
          fen: t['fen'] as String,
          ask: exerciseAskOf({'type': 'game', ...t}),
          forMoves: exerciseForMoves({'type': 'game', ...t}),
        ),
        ExerciseJudge.tablebase,
        reason: c['name'] as String,
      );
    }
  });
}
