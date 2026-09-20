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
    expect(exerciseTaskWords({'type': 'find'}), 'Find the move');
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
    // On a win the number is a mate to give, and it is said first: a row
    // that reads „Win as White" twice is how two different exercises looked
    // the same to the student on 19.9.2026.
    expect(
        exerciseTaskWords(
            {'type': 'game', 'goal': 'win', 'side': 'w', 'surviveMoves': 5}),
        'Checkmate in 5 moves as White');
    expect(
        exerciseTaskWords(
            {'type': 'game', 'goal': 'win', 'side': 'b', 'surviveMoves': 1}),
        'Checkmate in 1 move as Black');
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
    expect(j(_krk, ExerciseAsk.win, 3), ExerciseJudge.mateInMoves);
    expect(j(_krk, ExerciseAsk.hold, 3), ExerciseJudge.tablebase);
    expect(j(_start, ExerciseAsk.hold, 3), ExerciseJudge.notMatedOnly);
    // Checkmate in N is the rules' alone: thirty-two pieces are no obstacle.
    expect(j(_start, ExerciseAsk.win, 3), ExerciseJudge.mateInMoves);
    expect(j(_start, ExerciseAsk.find, 3), ExerciseJudge.rules);
    // „Play N moves" (phase 15) is the trainer's, whatever the board holds.
    expect(j(_krk, ExerciseAsk.play, 3), ExerciseJudge.trainer);
    expect(j(_start, ExerciseAsk.play, 12), ExerciseJudge.trainer);
    // As many sentences as judges, every one different. Counted, not typed:
    // the number that stood here was one judge behind the day one was added.
    expect(ExerciseJudge.values.map(exerciseJudgeWords).toSet().length,
        ExerciseJudge.values.length);
  });

  test('who judges here is who judges on the server, on the shared fixture',
      () {
    // docs/gates/engine_game_cases.json → forMoves.judged. Read in **both**
    // directions at every game that stopped at its move target: the sheet
    // says „tablebase" exactly where the server asks one. One direction alone
    // could not see the sheet promise a tablebase for a checkmate in N.
    final fixture = jsonDecode(
            File('../docs/gates/engine_game_cases.json').readAsStringSync())
        as Map<String, dynamic>;
    final forMoves = fixture['forMoves'] as Map<String, dynamic>;
    var asked = 0, notAsked = 0;
    for (final c in (forMoves['judged'] as List).cast<Map<String, dynamic>>()) {
      final t = c['task'] as Map<String, dynamic>;
      final expected = c['expect'] as Map;
      if (expected['ending'] != 'moveTarget') continue;
      final expectTb = expected['needsTablebase'] == true;
      expectTb ? asked++ : notAsked++;
      final judge = exerciseJudgeFor(
        fen: t['fen'] as String,
        ask: exerciseAskOf({'type': 'game', ...t}),
        forMoves: exerciseForMoves({'type': 'game', ...t}),
      );
      expect(judge == ExerciseJudge.tablebase, expectTb,
          reason: c['name'] as String);
      if (t['goal'] == 'win') {
        expect(judge, ExerciseJudge.mateInMoves, reason: c['name'] as String);
      }
    }
    expect(asked, greaterThan(0));
    expect(notAsked, greaterThan(0));
  });
}
