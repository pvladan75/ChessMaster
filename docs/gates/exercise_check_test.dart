// exercise_check_test.dart — the gate of phase 5, docs/PLAN-EXERCISE.md.
//
// Copy into chess_app/test/ and leave it there green, unchanged. Written
// 19.9.2026 by the lead, **red on master**: neither file below exists.
//
// Decision 5 of the plan: the tablebase and the engine check an exercise **when
// it is made**, not when it is solved. What they find is put to the trainer,
// and what the trainer accepts becomes stored accepted moves — so the judge
// stays a list comparison on the server, the same on every device.
//
// Two rules above all others, each with tests below:
//   1. **The check advises; it never blocks a save.** A tablebase that does not
//      answer, an engine that throws or never comes back — the result is „no
//      findings", on time.
//   2. **A finding is never applied by itself.** `acceptFinding` is the only
//      thing that changes a solution, and only the trainer calls it.
//
// What the implementer must provide, exactly:
//
//   // lib/features/exercises/models/exercise_check.dart — pure, no I/O
//   enum ExerciseFindingKind {
//     alsoKeeps,        // other moves keep the result: offered for accepting
//     mainMoveLetsGo,   // the trainer's own move does not keep the result
//     tooManyKeep,      // so many moves keep it that accepting all is impossible
//     taskImpossible,   // a game task best play cannot meet
//     enginePrefers,    // the engine's choice is clearly better than the main move
//   }
//   class ExerciseFinding {
//     final ExerciseFindingKind kind;
//     final int step;             // the student's move it is about, 0-based; 0 for a game
//     final List<String> sans;    // the moves offered for accepting; empty when none are
//     final String words;         // one sentence for the trainer
//   }
//   const int maxAcceptedMoves = 8;        // the server's MAX_ACCEPTED
//   const double enginePrefersByPawns = 1.5;
//
//   /// The position before each of the student's moves, walking the main line.
//   List<String> studentFens(String fen, List<ExerciseStep> steps);
//
//   /// One [results] entry per step, null where the tablebase had no answer.
//   /// „Keeps the result": the side to move wins → a move keeps it when the
//   /// opponent is then `loss`; it draws (draw, cursedWin, blessedLoss) → when
//   /// the opponent is then draw, cursedWin or blessedLoss. A side that is
//   /// lost, or a category that is no outcome (unknown, maybe*), yields nothing.
//   List<ExerciseFinding> tablebaseFindings({
//     required List<ExerciseStep> steps,
//     required List<SyzygyResult?> results,
//   });
//
//   /// [result] is the tablebase's word for the side TO MOVE at the exercise's
//   /// position; the student may be the other side.
//   ExerciseFinding? gameFinding({
//     required Map<String, dynamic> task,   // the game task, with 'side' and 'goal'
//     required SyzygyResult? result,
//   });
//
//   /// [lines] as `StockfishService.analyzePositionSync` returns them, best
//   /// first; their evaluation is from White's side (`parseEval` in
//   /// `position_scanner/services/side_proposal.dart` — reuse it).
//   ExerciseFinding? engineFinding({
//     required String fen,
//     required ExerciseStep first,
//     required List<AnalysisLine> lines,
//   });
//
//   /// [steps] with the finding's moves added to its step's `accept`, after the
//   /// moves already there, never past `maxAcceptedMoves`, never twice. A
//   /// finding that offers no moves returns [steps] unchanged.
//   List<ExerciseStep> acceptFinding(List<ExerciseStep> steps, ExerciseFinding finding);
//
//   // lib/features/exercises/services/exercise_checker.dart
//   typedef TablebaseAsk = Future<SyzygyResult?> Function(String fen);
//   typedef EngineAsk = Future<List<AnalysisLine>> Function(String fen);
//   class ExerciseChecker {
//     const ExerciseChecker({required this.tablebase, required this.engine,
//         this.timeout = const Duration(seconds: 8)});
//     /// Seven pieces or fewer: the tablebase, for every student position of a
//     /// find exercise or the one position of a game. More: the engine, for a
//     /// find exercise's first move only. **Never throws, never outlasts
//     /// [timeout] by more than a moment, and returns [] when nobody answered.**
//     Future<List<ExerciseFinding>> check({
//       required String fen,
//       required Map<String, dynamic> task,
//       List<ExerciseStep>? steps,
//     });
//   }

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_check.dart';
import 'package:chess_app/features/exercises/services/exercise_checker.dart';
import 'package:chess_app/models/analysis_models.dart';

// White to move and winning: Kc6, Kd6 and Ke6 all keep the win, Kc4 lets it go.
const _kpk = '8/8/8/3K4/3P4/8/8/3k4 w - - 0 1';
const _big = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

/// A tablebase answer in the wire's own shape, so the real `fromJson` reads it.
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

ExerciseStep _step(List<String> accept, [String? reply]) =>
    ExerciseStep(accept: accept, reply: reply);

AnalysisLine _line(int n, String eval, String lan, String fen) =>
    AnalysisLine.fromPv(multipv: n, eval: eval, pvString: lan, startingFen: fen);

void main() {
  group('what a tablebase says of a find exercise', () {
    test('other moves that keep the win are offered, not applied', () {
      final steps = [_step(['Kc6'])];
      final findings = tablebaseFindings(steps: steps, results: [_winning]);
      final also = findings.single;
      expect(also.kind, ExerciseFindingKind.alsoKeeps);
      expect(also.step, 0);
      expect(also.sans, unorderedEquals(['Kd6', 'Ke6']));
      expect(also.words, contains('Kd6'));
      expect(steps.single.accept, ['Kc6'], reason: 'nothing changed by itself');
    });

    test('moves already accepted are not offered again, however they are '
        'spelled', () {
      final findings = tablebaseFindings(
        steps: [_step(['Kc6', 'Kd6+', 'Ke6'])],
        results: [_winning],
      );
      expect(findings, isEmpty);
    });

    test('a main move that lets the win go is said, with a move that keeps it',
        () {
      final findings =
          tablebaseFindings(steps: [_step(['Kc4'])], results: [_winning]);
      final letsGo = findings
          .firstWhere((f) => f.kind == ExerciseFindingKind.mainMoveLetsGo);
      expect(letsGo.words, contains('Kc4'));
      expect(letsGo.sans, isEmpty, reason: 'a warning, not an offer');
      // The moves that do keep it are still offered, separately.
      final also =
          findings.firstWhere((f) => f.kind == ExerciseFindingKind.alsoKeeps);
      expect(also.sans, unorderedEquals(['Kc6', 'Kd6', 'Ke6']));
    });

    test('a draw is kept by a draw, and cursed and blessed count as draws', () {
      final drawn = _tb(_kpk, 'draw', {
        'Kc6': 'draw',
        'Kd6': 'cursed-win',
        'Ke6': 'blessed-loss',
        'Kc4': 'win',
      });
      final findings =
          tablebaseFindings(steps: [_step(['Kc6'])], results: [drawn]);
      expect(findings.single.sans, unorderedEquals(['Kd6', 'Ke6']));
    });

    test('more keeping moves than can be accepted is said, and none offered',
        () {
      // King and rook against king: nearly every rook move keeps the win.
      const krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
      final many = _tb(krk, 'win', {
        for (final san in [
          'Ra2', 'Ra3+', 'Ra4', 'Ra5', 'Ra6', 'Ra7', 'Ra8', 'Rb1', 'Rc1', 'Rd1'
        ])
          san: 'loss',
      });
      final findings =
          tablebaseFindings(steps: [_step(['Ra8'])], results: [many]);
      expect(findings.single.kind, ExerciseFindingKind.tooManyKeep);
      expect(findings.single.sans, isEmpty);
      expect(findings.single.words, contains('10'));
    });

    test('no answer, a lost side, or no outcome: nothing is found', () {
      final steps = [_step(['Kc6'])];
      expect(tablebaseFindings(steps: steps, results: [null]), isEmpty);
      expect(
          tablebaseFindings(
              steps: steps, results: [_tb(_kpk, 'loss', {'Kc6': 'win'})]),
          isEmpty);
      expect(
          tablebaseFindings(
              steps: steps, results: [_tb(_kpk, 'unknown', {'Kc6': 'loss'})]),
          isEmpty);
    });

    test('each of the student\'s moves is looked at on its own position', () {
      const line = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
      final steps = [
        _step(['Ra8'], 'Kd3'),
        _step(['Ra3+'])
      ];
      final fens = studentFens(line, steps);
      expect(fens, hasLength(2));
      expect(fens.first, line);
      expect(fens.last.split(' ').first, 'R7/8/8/8/8/3k4/8/4K3');

      final findings = tablebaseFindings(steps: steps, results: [
        null,
        _tb(fens.last, 'win', {'Ra3+': 'loss', 'Rd8+': 'loss'}),
      ]);
      expect(findings.single.step, 1);
      expect(findings.single.sans, ['Rd8+']);
    });
  });

  group('what a tablebase says of a game exercise', () {
    Map<String, dynamic> task(String side, String goal) =>
        {'type': 'game', 'side': side, 'goal': goal};

    test('a win asked of a drawn position cannot be met by best play', () {
      final drawn = _tb(_kpk, 'draw', {});
      final f = gameFinding(task: task('w', 'win'), result: drawn);
      expect(f!.kind, ExerciseFindingKind.taskImpossible);
      expect(f.words.toLowerCase(), contains('draw'));
      expect(f.sans, isEmpty);
    });

    test('the student may be the side that is not to move', () {
      // White to move and winning: Black, asked to hold, is lost.
      final f = gameFinding(task: task('b', 'hold'), result: _winning);
      expect(f!.kind, ExerciseFindingKind.taskImpossible);
      // …and White, asked to win, is fine.
      expect(gameFinding(task: task('w', 'win'), result: _winning), isNull);
      // A cursed win is a draw: holding it is fine, winning it is not.
      final cursed = _tb(_kpk, 'cursed-win', {});
      expect(gameFinding(task: task('w', 'hold'), result: cursed), isNull);
      expect(gameFinding(task: task('w', 'win'), result: cursed), isNotNull);
    });

    test('no answer and no outcome say nothing', () {
      expect(gameFinding(task: task('w', 'win'), result: null), isNull);
      expect(
          gameFinding(task: task('w', 'win'), result: _tb(_kpk, 'unknown', {})),
          isNull);
    });
  });

  group('the engine\'s second opinion', () {
    test('a clearly better move is offered', () {
      final f = engineFinding(
        fen: _big,
        first: _step(['Bc4']),
        lines: [
          _line(1, '+2.10', 'f1b5', _big),
          _line(2, '+0.30', 'f1c4', _big),
        ],
      );
      expect(f!.kind, ExerciseFindingKind.enginePrefers);
      expect(f.sans, ['Bb5']);
      expect(f.words, contains('Bb5'));
    });

    test('a slightly better move is not worth a word', () {
      expect(
        engineFinding(fen: _big, first: _step(['Bc4']), lines: [
          _line(1, '+0.60', 'f1b5', _big),
          _line(2, '+0.30', 'f1c4', _big),
        ]),
        isNull,
      );
    });

    test('the engine\'s choice is already accepted: nothing to say', () {
      expect(
        engineFinding(fen: _big, first: _step(['Bc4', 'Bb5']), lines: [
          _line(1, '+2.10', 'f1b5', _big),
          _line(2, '+0.30', 'f1c4', _big),
        ]),
        isNull,
      );
    });

    test('the evaluation is turned round for Black', () {
      const black =
          'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 2 3';
      // From White's side −2.10 is good for Black; +0.30 is not.
      final f = engineFinding(fen: black, first: _step(['a6']), lines: [
        _line(1, '-2.10', 'g8f6', black),
        _line(2, '+0.30', 'a7a6', black),
      ]);
      expect(f!.sans, ['Nf6']);
      // The same numbers the other way round: a6 is the better move for Black.
      expect(
        engineFinding(fen: black, first: _step(['a6']), lines: [
          _line(1, '-2.10', 'a7a6', black),
          _line(2, '+0.30', 'g8f6', black),
        ]),
        isNull,
      );
    });

    test('a main move the engine did not even list is said', () {
      final f = engineFinding(fen: _big, first: _step(['h3']), lines: [
        _line(1, '+0.40', 'f1b5', _big),
        _line(2, '+0.35', 'f1c4', _big),
      ]);
      expect(f!.kind, ExerciseFindingKind.enginePrefers);
      expect(f.sans, ['Bb5']);
    });

    test('no lines, or an unreadable evaluation, say nothing', () {
      expect(engineFinding(fen: _big, first: _step(['Bc4']), lines: const []),
          isNull);
      expect(
        engineFinding(fen: _big, first: _step(['Bc4']), lines: [
          _line(1, 'nonsense', 'f1b5', _big),
          _line(2, '+0.30', 'f1c4', _big),
        ]),
        isNull,
      );
    });
  });

  group('accepting is the trainer\'s act', () {
    final steps = [_step(['Kc6'], 'Kd2'), _step(['Kd6'])];

    test('the offered moves join their own step, after what was there', () {
      final also = tablebaseFindings(steps: [steps.first], results: [_winning])
          .single;
      final after = acceptFinding(steps, also);
      expect(after.first.accept.first, 'Kc6', reason: 'the main move stays');
      expect(after.first.accept, unorderedEquals(['Kc6', 'Kd6', 'Ke6']));
      expect(after.first.reply, 'Kd2');
      expect(after.last.accept, ['Kd6'], reason: 'the other step is untouched');
      expect(steps.first.accept, ['Kc6'], reason: 'the input is not mutated');
    });

    test('never twice, never past the limit', () {
      final full = [
        _step(['Kc6', 'a', 'b', 'c', 'd', 'e', 'f'])
      ];
      final also =
          tablebaseFindings(steps: [_step(['Kc6'])], results: [_winning]).single;
      final after = acceptFinding(full, also);
      expect(after.single.accept.length, maxAcceptedMoves);
      final twice = acceptFinding(acceptFinding(steps, also), also);
      expect(twice.first.accept.toSet().length, twice.first.accept.length);
    });

    test('a warning changes nothing', () {
      final letsGo =
          tablebaseFindings(steps: [_step(['Kc4'])], results: [_winning])
              .firstWhere((f) => f.kind == ExerciseFindingKind.mainMoveLetsGo);
      final after = acceptFinding(steps, letsGo);
      expect(after.first.accept, ['Kc6']);
    });
  });

  group('the check never stops a save', () {
    Future<List<AnalysisLine>> noEngine(String fen) async =>
        fail('the engine must not be asked about a tablebase position');
    Future<SyzygyResult?> noTablebase(String fen) async =>
        fail('the tablebase must not be asked about a position it cannot hold');

    test('seven pieces or fewer: the tablebase is asked, about each student '
        'position', () async {
      final asked = <String>[];
      final checker = ExerciseChecker(
        tablebase: (fen) async {
          asked.add(fen);
          return fen == _kpk ? _winning : null;
        },
        engine: noEngine,
      );
      final findings = await checker.check(
        fen: _kpk,
        task: const {'type': 'find'},
        steps: [_step(['Kc6'])],
      );
      expect(asked, [_kpk]);
      expect(findings.single.kind, ExerciseFindingKind.alsoKeeps);
    });

    test('a game exercise is asked about once, and needs no steps', () async {
      final asked = <String>[];
      final checker = ExerciseChecker(
        tablebase: (fen) async {
          asked.add(fen);
          return _tb(_kpk, 'draw', {});
        },
        engine: noEngine,
      );
      final findings = await checker.check(
          fen: _kpk, task: const {'type': 'game', 'side': 'w', 'goal': 'win'});
      expect(asked, [_kpk]);
      expect(findings.single.kind, ExerciseFindingKind.taskImpossible);
    });

    test('more pieces: the engine is asked about the first position only',
        () async {
      final asked = <String>[];
      final checker = ExerciseChecker(
        tablebase: noTablebase,
        engine: (fen) async {
          asked.add(fen);
          return [
            _line(1, '+2.10', 'f1b5', _big),
            _line(2, '+0.30', 'f1c4', _big),
          ];
        },
      );
      final findings = await checker.check(
        fen: _big,
        task: const {'type': 'find'},
        steps: [_step(['Bc4'], 'a6'), _step(['Ba4'])],
      );
      expect(asked, [_big]);
      expect(findings.single.kind, ExerciseFindingKind.enginePrefers);
      // A game with many pieces has nobody to ask.
      asked.clear();
      expect(
          await checker.check(
              fen: _big,
              task: const {'type': 'game', 'side': 'w', 'goal': 'win'}),
          isEmpty);
      expect(asked, isEmpty);
    });

    test('an asker that throws is „no findings", not an error', () async {
      final checker = ExerciseChecker(
        tablebase: (fen) async => throw StateError('network down'),
        engine: (fen) async => throw StateError('engine not started'),
      );
      expect(
          await checker.check(
              fen: _kpk, task: const {'type': 'find'}, steps: [_step(['Kc6'])]),
          isEmpty);
      expect(
          await checker.check(
              fen: _big, task: const {'type': 'find'}, steps: [_step(['Bc4'])]),
          isEmpty);
    });

    test('an asker that never answers is given up on, on time', () async {
      final never = Completer<SyzygyResult?>();
      final checker = ExerciseChecker(
        tablebase: (fen) => never.future,
        engine: noEngine,
        timeout: const Duration(milliseconds: 60),
      );
      final started = DateTime.now();
      final findings = await checker.check(
          fen: _kpk, task: const {'type': 'find'}, steps: [_step(['Kc6'])]);
      expect(findings, isEmpty);
      expect(DateTime.now().difference(started),
          lessThan(const Duration(seconds: 2)));
    });
  });
}
