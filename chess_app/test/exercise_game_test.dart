// exercise_game_test.dart — the gate of phase 3b, docs/PLAN-EXERCISE.md.
//
// Copy into chess_app/test/ and leave it there green, unchanged. Written
// 18.9.2026 by the lead, **red on master**: `EngineGameVerdict` has no
// `needsTablebase`, `EngineGameTask.fromJson` drops a number of moves on a win
// or a hold, and none of the three new things below exists.
//
// It reads the `forMoves` half of `docs/gates/engine_game_cases.json` — the
// same cases the server's `engine_game_for_moves.test.js` reads. The app
// decides on its own board when an assigned game stops; the server decides
// again from the moves and, at a move target, asks a tablebase the app cannot
// ask. So the app must stop where the server stops, and **must not announce a
// verdict it cannot know**.
//
// What the implementer must provide, exactly:
//
//   // lib/core/models/engine_game_task.dart — changed in place
//   EngineGameTask.fromJson: `surviveMoves` is kept on `win` and `hold` as
//     well as `survive` (1.._maxSurviveMoves, else null = refused); and a
//     `win` with `surviveMoves` and more than seven pieces on the board is
//     refused (null), as the server refuses it. Use `exercisePieceCount` and
//     `tablebasePieces` from
//     `lib/features/exercises/models/exercise_task_words.dart` — one home.
//   EngineGameVerdict gains `final bool needsTablebase;` — true exactly when
//     the game ended at `GameEnding.moveTarget` with seven pieces or fewer on
//     the board.
//   engineGameVerdict: the move target applies to every goal that carries
//     `surviveMoves`, not only to `survive`.
//
//   // lib/core/models/engine_game_said.dart — new
//   class EngineGameServerVerdict {        // what POST …/game-result answers
//     final bool? goalMet;                 // null while pending
//     final String? judgedBy;              // 'rules' | 'tablebase' | 'device' | null
//     final bool pending;
//     static EngineGameServerVerdict? fromJson(Object? json);  // null if unreadable
//   }
//   enum EngineGameSaid { met, notMet, notJudged }
//   /// What the ending dialog may say. [server] is null when the result could
//   /// not be sent or read.
//   EngineGameSaid engineGameSaid(EngineGameVerdict local, EngineGameServerVerdict? server);
//   String engineGameSaidWords(EngineGameSaid said);   // three different sentences
//
//   // lib/features/exercises/models/exercise.dart — added
//   /// The `task` map of a game exercise, as POST /exercises takes it.
//   Map<String, dynamic> exerciseGameTask({
//     required String side,          // 'w' | 'b' — the side the STUDENT plays
//     required ExerciseAsk ask,      // win | hold   (find throws ArgumentError)
//     int? forMoves,                 // null = to the end of the game
//     String? level,                 // 'lako' | 'srednje' | 'tesko' | null
//     int? thinkSeconds,
//   });
//
//   // lib/features/homework/models/homework_child.dart — added
//   final int pendingItems;          // from 'pending_items', 0 when absent

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:chess_app/core/models/engine_game_said.dart';
import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/features/homework/models/homework_child.dart';

Map<String, dynamic> _forMoves() {
  final file = File('../docs/gates/engine_game_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  final all = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return all['forMoves'] as Map<String, dynamic>;
}

String _outcomeName(DrillOutcome outcome) => switch (outcome) {
      DrillOutcome.readerWon => 'won',
      DrillOutcome.readerLost => 'lost',
      DrillOutcome.drawn => 'drawn',
      DrillOutcome.undecided => 'undecided',
    };

/// Plays the case on a real board and asks the app's own verdict.
EngineGameVerdict _verdictOf(Map<String, dynamic> c) {
  final task =
      EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map));
  if (task == null) throw StateError('unreadable task in: ${c['name']}');
  final game = chess.Chess.fromFEN(task.fen);
  var ownMoves = 0;
  for (final san in (c['moves'] as List).cast<String>()) {
    if (game.turn == task.side) ownMoves++;
    if (!game.move(san)) throw StateError('illegal in fixture: $san');
  }
  return engineGameVerdict(task: task, game: game, ownMoves: ownMoves);
}

void main() {
  final fixture = _forMoves();
  final judged = (fixture['judged'] as List).cast<Map<String, dynamic>>();
  final rejected = (fixture['rejected'] as List).cast<Map<String, dynamic>>();

  test('the shared fixture has what the loops below need', () {
    expect(judged.length, greaterThanOrEqualTo(5));
    expect(rejected.length, greaterThanOrEqualTo(2));
    expect(judged.any((c) => (c['expect'] as Map)['needsTablebase'] == true),
        isTrue);
    expect(
        judged.any((c) =>
            (c['expect'] as Map)['ending'] == 'moveTarget' &&
            (c['expect'] as Map)['needsTablebase'] == false),
        isTrue);
  });

  group('the app stops where the server stops', () {
    for (final c in judged) {
      test('${c['name']}', () {
        final verdict = _verdictOf(c);
        final want = c['expect'] as Map<String, dynamic>;
        expect(verdict.ending?.name, want['ending'], reason: 'ending');
        expect(_outcomeName(verdict.outcome), want['outcome'],
            reason: 'outcome');
        expect(verdict.ownMoves, want['ownMoves'], reason: 'own moves');
        expect(verdict.needsTablebase, want['needsTablebase'],
            reason: 'needs the tablebase');
        // `goalMet` is compared only where the app can know it. At a move
        // target a tablebase will judge, the app's own `goalMet` is a guess
        // and is asserted on below — through what it is allowed to SAY.
        if (want['needsTablebase'] != true) {
          expect(verdict.goalMet, want['goalMet'], reason: 'goal met');
        }
      });
    }

    for (final c in rejected) {
      test('refused: ${c['name']}', () {
        expect(
          EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map)),
          isNull,
        );
      });
    }

    test('a number of moves is kept on a win and a hold', () {
      const krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
      EngineGameTask? read(String goal, Object? n) => EngineGameTask.fromJson({
            'fen': krk,
            'side': 'w',
            'goal': goal,
            if (n != null) 'surviveMoves': n,
          });
      expect(read('win', 3)!.surviveMoves, 3);
      expect(read('hold', 4)!.surviveMoves, 4);
      expect(read('win', null)!.surviveMoves, isNull);
      expect(read('hold', 0), isNull, reason: 'for no moves is not a task');
      expect(read('survive', null), isNull);
    });
  });

  group('the screen says only what it can know', () {
    final needsTb = judged
        .firstWhere((c) => (c['expect'] as Map)['needsTablebase'] == true);
    final local = _verdictOf(needsTb);
    final byRules = _verdictOf(judged
        .firstWhere((c) => (c['expect'] as Map)['ending'] == 'checkmate'));

    test('the server\'s answer is read, and an unreadable one is not guessed',
        () {
      final met = EngineGameServerVerdict.fromJson({
        'ok': true,
        'goalMet': true,
        'judgedBy': 'tablebase',
        'pending': false
      });
      expect(met!.goalMet, isTrue);
      expect(met.judgedBy, 'tablebase');
      expect(met.pending, isFalse);

      final waiting = EngineGameServerVerdict.fromJson(
          {'ok': true, 'goalMet': null, 'judgedBy': null, 'pending': true});
      expect(waiting!.goalMet, isNull);
      expect(waiting.pending, isTrue);

      // A server from before phase 3a: no `pending`, no `judgedBy`.
      final old =
          EngineGameServerVerdict.fromJson({'ok': true, 'goalMet': false});
      expect(old!.goalMet, isFalse);
      expect(old.pending, isFalse);

      expect(EngineGameServerVerdict.fromJson('nonsense'), isNull);
      expect(EngineGameServerVerdict.fromJson(null), isNull);
    });

    test(
        'at a move target the tablebase judges, the server\'s word is the word',
        () {
      EngineGameServerVerdict server(bool? met, {bool pending = false}) =>
          EngineGameServerVerdict.fromJson({
            'goalMet': met,
            'judgedBy': pending ? null : 'tablebase',
            'pending': pending,
          })!;
      expect(engineGameSaid(local, server(true)), EngineGameSaid.met);
      expect(engineGameSaid(local, server(false)), EngineGameSaid.notMet);
      expect(engineGameSaid(local, server(null, pending: true)),
          EngineGameSaid.notJudged);
      // Nothing came back: the app does not fall back on its own guess.
      expect(engineGameSaid(local, null), EngineGameSaid.notJudged);
    });

    test('a game the rules ended is announced at once, whatever came back', () {
      expect(byRules.needsTablebase, isFalse);
      expect(byRules.goalMet, isTrue);
      expect(engineGameSaid(byRules, null), EngineGameSaid.met);
    });

    test(
        'three states, three different sentences, and „not judged" is not a '
        'failure', () {
      final words = EngineGameSaid.values.map(engineGameSaidWords).toList();
      expect(words.toSet().length, 3);
      final waiting =
          engineGameSaidWords(EngineGameSaid.notJudged).toLowerCase();
      expect(waiting, isNot(contains('not met')));
      expect(waiting, isNot(contains('fail')));
      expect(waiting, isNot(contains('wrong')));
    });
  });

  group('the task the sheet sends', () {
    test('two questions make one task', () {
      expect(
        exerciseGameTask(side: 'w', ask: ExerciseAsk.win),
        {'type': 'game', 'side': 'w', 'goal': 'win'},
      );
      expect(
        exerciseGameTask(
            side: 'b', ask: ExerciseAsk.hold, forMoves: 4, level: 'tesko'),
        {
          'type': 'game',
          'side': 'b',
          'goal': 'hold',
          'surviveMoves': 4,
          'level': 'tesko',
        },
      );
      // Absence is a third answer: what was not chosen is not sent.
      final plain = exerciseGameTask(side: 'w', ask: ExerciseAsk.hold);
      expect(plain.containsKey('surviveMoves'), isFalse);
      expect(plain.containsKey('level'), isFalse);
      expect(plain.containsKey('thinkSeconds'), isFalse);
      expect(plain.containsKey('fen'), isFalse,
          reason: 'the exercise has the position; the task does not repeat it');
    });

    test('„find" is not a game', () {
      expect(() => exerciseGameTask(side: 'w', ask: ExerciseAsk.find),
          throwsArgumentError);
    });

    test('what it sends reads back as the words the trainer chose', () {
      final task =
          exerciseGameTask(side: 'b', ask: ExerciseAsk.hold, forMoves: 4);
      expect(exerciseTaskWords(task), 'Draw or better as Black, for 4 moves');
      expect(exerciseAskOf(task), ExerciseAsk.hold);
      expect(exerciseForMoves(task), 4);
    });
  });

  group('the homework row', () {
    Map<String, dynamic> child(Map<String, dynamic> over) => {
          'id': 9,
          'title': 'Hold it',
          'kind': 'engine_game',
          'position': 0,
          'item_key': 'k0',
          'total_items': 1,
          'attempted_items': 1,
          'solved_items': 0,
          'passed': true,
          'locked': false,
          ...over,
        };

    test('a game played and not judged is counted as that', () {
      final waiting = HomeworkChild.fromJson(child({'pending_items': 1}));
      expect(waiting!.pendingItems, 1);
      final plain = HomeworkChild.fromJson(child({}));
      expect(plain!.pendingItems, 0, reason: 'absent reads as none');
    });
  });
}
