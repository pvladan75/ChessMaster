// exercise_checker.dart — asks the tablebase and the engine what they know
// of an exercise **when it is made** (`docs/PLAN-EXERCISE.md`, decision 5),
// and turns their answers into `ExerciseFinding`s through the pure functions
// in `exercise_check.dart`.
//
// The two askers are injected (`TablebaseAsk`, `EngineAsk`) so a test can
// fake the client, not the method — the default wraps the two real services
// this app already has, built from top-level tear-offs so the default value
// itself is a compile-time constant: constructing it does no I/O at all, and
// nothing runs until [ExerciseChecker.check] is actually called.
import 'dart:async';

import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/models/analysis_models.dart';

import '../models/exercise.dart';
import '../models/exercise_check.dart';
import '../models/exercise_task_words.dart'
    show exercisePieceCount, tablebasePieces;

typedef TablebaseAsk = Future<SyzygyResult?> Function(String fen);
typedef EngineAsk = Future<List<AnalysisLine>> Function(String fen);

Future<SyzygyResult?> _realTablebaseAsk(String fen) =>
    SyzygyTablebaseService.instance.lookup(fen);

Future<List<AnalysisLine>> _realEngineAsk(String fen) =>
    StockfishService().analyzePositionSync(fen, depth: 18, multiPV: 3);

/// The default the sheet reaches for: a compile-time constant, so having one
/// costs nothing until [ExerciseChecker.check] is called.
const ExerciseChecker defaultExerciseChecker = ExerciseChecker(
  tablebase: _realTablebaseAsk,
  engine: _realEngineAsk,
);

/// The runner. Never throws, never outlasts [timeout] by more than a moment,
/// and returns `[]` when nobody answered — the check advises, it never blocks
/// a save.
class ExerciseChecker {
  const ExerciseChecker({
    required this.tablebase,
    required this.engine,
    this.timeout = const Duration(seconds: 8),
  });

  final TablebaseAsk tablebase;
  final EngineAsk engine;
  final Duration timeout;

  /// Seven pieces or fewer: the tablebase, for every student position of a
  /// find exercise or the one position of a game. More: the engine, for a
  /// find exercise's first move only. A game with more than seven pieces has
  /// nobody to ask.
  Future<List<ExerciseFinding>> check({
    required String fen,
    required Map<String, dynamic> task,
    List<ExerciseStep>? steps,
  }) async {
    try {
      return await _run(fen: fen, task: task, steps: steps)
          .timeout(timeout, onTimeout: () => const <ExerciseFinding>[]);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ExerciseFinding>> _run({
    required String fen,
    required Map<String, dynamic> task,
    List<ExerciseStep>? steps,
  }) async {
    final fewPieces = exercisePieceCount(fen) <= tablebasePieces;

    if (task['type'] == 'game') {
      if (!fewPieces) return const [];
      final result = await tablebase(fen);
      final finding = gameFinding(task: task, result: result);
      return finding == null ? const [] : [finding];
    }

    if (steps == null || steps.isEmpty) return const [];

    if (fewPieces) {
      final fens = studentFens(fen, steps);
      final results = await Future.wait(fens.map(tablebase));
      return tablebaseFindings(steps: steps, results: results);
    }

    final lines = await engine(fen);
    final finding = engineFinding(fen: fen, first: steps.first, lines: lines);
    return finding == null ? const [] : [finding];
  }
}
