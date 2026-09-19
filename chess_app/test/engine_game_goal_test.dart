// engine_game_goal_test.dart — the gate of phase 2's app half.
// docs/PLAN-DOMACI-ZADATAK.md §3, „play it out".
//
// Copy into chess_app/test/ and leave it there green. Written 17.9.2026 by the
// lead, **red on master**: `lib/core/models/engine_game_task.dart` does not
// exist, and `GameEnding` has no `moveTarget`.
//
// It reads `docs/gates/engine_game_cases.json` — the same file the backend's
// `engine_game_task.test.js` reads, and the reason it exists: the app decides
// on its own board when an assigned game is over, the server decides it again
// from the moves when the result is recorded, and the two must agree (CLAUDE.md
// rule 12). Every position and move in the fixture was replayed on a real board
// before it was written down.
//
// What the implementer must provide, exactly:
//
//   enum EngineGameGoal { win, hold, survive }
//
//   class EngineGameTask {
//     final String fen;                // the position, as the trainer set it
//     final chess.Color side;          // the side the student plays
//     final EngineGameGoal goal;
//     final int? surviveMoves;         // only for survive, else null
//     final String? level;             // 'lako' | 'srednje' | 'tesko' | null
//     final int? thinkSeconds;         // 1..60, or null
//     final int plyCap;                // defaults to 200
//     static EngineGameTask? fromJson(Map<String, dynamic> json);  // null when refused
//   }
//
//   class EngineGameVerdict {
//     final GameEnding? ending;        // null while the game is running
//     final DrillOutcome outcome;
//     final bool goalMet;
//     final int ownMoves;
//   }
//
//   EngineGameVerdict engineGameVerdict({
//     required EngineGameTask task,
//     required chess.Chess game,
//     required int ownMoves,
//     bool resigned = false,
//   });
//
// and `GameEnding.moveTarget` in `lib/core/models/drill_outcome.dart` — the
// number of own moves a „survive" goal asked for, which no board can know.
// `engineGameVerdict` must read the board through the existing `verdictFor`
// rather than asking `chess.Chess` again: one rule, one home.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:chess_app/core/models/engine_game_task.dart';

/// The fixture lives beside the plan, one directory above the app.
Map<String, dynamic> _fixture() {
  final file = File('../docs/gates/engine_game_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _outcomeName(DrillOutcome outcome) => switch (outcome) {
      DrillOutcome.readerWon => 'won',
      DrillOutcome.readerLost => 'lost',
      DrillOutcome.drawn => 'drawn',
      DrillOutcome.undecided => 'undecided',
    };

void main() {
  final fixture = _fixture();
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
  final rejected = (fixture['rejected'] as List).cast<Map<String, dynamic>>();

  test('the shared fixture has both halves', () {
    // A fixture that shrank would make every loop below vacuous.
    expect(cases.length, greaterThanOrEqualTo(16));
    expect(rejected.length, greaterThanOrEqualTo(5));
  });

  for (final c in cases) {
    test('${c['name']}', () {
      final task =
          EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map));
      expect(task, isNotNull, reason: 'the fixture task must be readable');

      final game = chess.Chess.fromFEN(task!.fen);
      var ownMoves = 0;
      for (final san in (c['moves'] as List).cast<String>()) {
        if (game.turn == task.side) ownMoves++;
        expect(game.move(san), isTrue, reason: 'illegal in fixture: $san');
      }

      final verdict = engineGameVerdict(
        task: task,
        game: game,
        ownMoves: ownMoves,
        resigned: c['resigned'] == true,
      );
      final want = c['expect'] as Map<String, dynamic>;

      expect(verdict.ending?.name, want['ending'], reason: 'ending');
      expect(_outcomeName(verdict.outcome), want['outcome'], reason: 'outcome');
      expect(verdict.goalMet, want['goalMet'], reason: 'goal met');
      expect(verdict.ownMoves, want['ownMoves'], reason: 'own moves');
    });
  }

  // Corrected 17.9.2026, after the implementer stopped on it rather than
  // working around it — the right call. The fixture's `rejected` array holds
  // two different kinds of refusal, and only one of them is the *task's*: the
  // „illegal move" entry carries a task **identical** to an accepted case
  // („nothing played yet is nothing decided"), because what is wrong with it is
  // the move list, which `fromJson` never sees. Asserting null for it asked the
  // app to refuse a task using information the task does not contain. The
  // backend's `judgeEngineGame` takes task and moves together and refuses it
  // there; here the board refuses the move, which is the app's equivalent.
  for (final c in rejected.where((c) => c['reason'] == 'bad task')) {
    test('refused: ${c['name']}', () {
      // A task the app cannot read is a homework item it must not open — not a
      // board with a guessed goal on it.
      final task =
          EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map));
      expect(task, isNull);
    });
  }

  test('the fixture separates a bad task from a bad move', () {
    // Both kinds must be present, or the loop above and the case below could
    // each pass by there being nothing to check.
    expect(rejected.where((c) => c['reason'] == 'bad task').length, 4);
    expect(rejected.where((c) => c['reason'] == 'illegal move').length, 1);
  });

  for (final c in rejected.where((c) => c['reason'] == 'illegal move')) {
    test('refused on the board: ${c['name']}', () {
      final task =
          EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map));
      expect(task, isNotNull, reason: 'the task itself is a good one');
      final game = chess.Chess.fromFEN(task!.fen);
      for (final san in (c['moves'] as List).cast<String>()) {
        expect(game.move(san), isFalse,
            reason: 'the position cannot play $san, and must say so');
      }
    });
  }

  test('a task carries the engine the trainer chose, and its own defaults', () {
    final task = EngineGameTask.fromJson({
      'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
      'side': 'w',
      'goal': 'hold',
      'level': 'tesko',
      'thinkSeconds': 5,
    })!;
    expect(task.side, chess.Color.WHITE);
    expect(task.goal, EngineGameGoal.hold);
    expect(task.level, 'tesko');
    expect(task.thinkSeconds, 5);
    expect(task.plyCap, 200, reason: 'the same default as the server');
    expect(task.surviveMoves, isNull);
  });

  test('a running game meets no goal', () {
    final task = EngineGameTask.fromJson({
      'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
      'side': 'w',
      'goal': 'hold',
      'plyCap': 40,
    })!;
    final game = chess.Chess.fromFEN(task.fen);
    expect(game.move('Rh2'), isTrue);
    final verdict = engineGameVerdict(task: task, game: game, ownMoves: 1);
    expect(verdict.ending, isNull);
    expect(verdict.goalMet, isFalse);
  });

  test('the ending is read through the one rule, not a second reading', () {
    // `moveTarget` is the app's own addition to `GameEnding`; the five board
    // endings must still be the ones `verdictFor` names.
    final task = EngineGameTask.fromJson({
      'fen': '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
      'side': 'w',
      'goal': 'win',
      'plyCap': 40,
    })!;
    final game = chess.Chess.fromFEN(task.fen);
    expect(game.move('Rd8#'), isTrue);
    final verdict = engineGameVerdict(task: task, game: game, ownMoves: 1);
    expect(verdict.ending, GameEnding.checkmate);
    expect(verdict.outcome, verdictFor(game, task.side).outcome);
  });

  group('the words on the board', () {
    EngineGameTask task(String goal, {int? n, String side = 'w'}) =>
        EngineGameTask.fromJson({
          'fen': '8/8/8/8/8/4k3/8/R3K3 w - - 0 1',
          'side': side,
          'goal': goal,
          if (n != null) 'surviveMoves': n,
        })!;

    test('the banner says the number whenever the trainer set one', () {
      expect(engineGameGoalSentence(task('win'), ownMoves: 0),
          'You are White — win the game');
      expect(engineGameGoalSentence(task('hold', side: 'b'), ownMoves: 3),
          'You are Black — hold a draw');
      expect(engineGameGoalSentence(task('win', n: 5), ownMoves: 0),
          'You are White — checkmate in 5 moves · 5 left');
      expect(engineGameGoalSentence(task('win', n: 5), ownMoves: 4),
          'You are White — checkmate in 5 moves · 1 left');
      expect(engineGameGoalSentence(task('win', n: 1), ownMoves: 0),
          'You are White — checkmate in 1 move · 1 left');
      expect(engineGameGoalSentence(task('hold', n: 4), ownMoves: 1),
          'You are White — do not lose for 4 moves · 3 left');
      expect(engineGameGoalSentence(task('survive', n: 4), ownMoves: 9),
          'You are White — do not lose for 4 moves · 0 left');
    });

    test('a move target is named by what the number was for', () {
      expect(engineGameEndingWords(task('win', n: 5), GameEnding.moveTarget),
          'no checkmate in 5 moves');
      expect(engineGameEndingWords(task('hold', n: 1), GameEnding.moveTarget),
          'you were not beaten in 1 move');
      // Every other ending keeps its one name.
      expect(engineGameEndingWords(task('win', n: 5), GameEnding.checkmate),
          endingLabel(GameEnding.checkmate));
      expect(engineGameEndingWords(null, GameEnding.moveTarget),
          endingLabel(GameEnding.moveTarget));
    });
  });
}
