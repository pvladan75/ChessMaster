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
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/models/analysis_models.dart';

import '../models/exercise.dart';
import '../models/exercise_check.dart';
import '../models/exercise_task_words.dart'
    show exercisePieceCount, tablebasePieces;

typedef TablebaseAsk = Future<SyzygyResult?> Function(String fen);
typedef EngineAsk = Future<List<AnalysisLine>> Function(String fen);

/// Whether this is a `flutter test` run. The default askers say nothing there.
///
/// Every sheet test that does not pass its own checker gets the default, and
/// the default used to reach for the real engine and the real network from a
/// widget test. On the workstation that built it both happen to fail fast, so
/// the tests were green — and a test that is green because of what one machine
/// does is a test of that machine (CLAUDE.md rule 8): on another, an engine
/// that waits out its own ten-second timer leaves a pending `Timer` and fails
/// tests that have nothing to do with it. The check is advice; in a test run
/// that was not given a checker, there is nobody to advise.
bool get _underTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

Future<SyzygyResult?> _realTablebaseAsk(String fen) async =>
    _underTest ? null : SyzygyTablebaseService.instance.lookup(fen);

Future<List<AnalysisLine>> _realEngineAsk(String fen) async {
  if (_underTest) return const <AnalysisLine>[];
  return StockfishService().analyzePositionSync(fen, depth: 18, multiPV: 3);
}

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
      return tablebaseFindings(
        answer: steps.first,
        result: await tablebase(fen),
      );
    }

    final lines = await engine(fen);
    final finding = engineFinding(fen: fen, first: steps.first, lines: lines);
    return finding == null ? const [] : [finding];
  }
}
