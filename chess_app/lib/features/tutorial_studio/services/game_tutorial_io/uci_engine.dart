/// The engines a game's facts are built with — phase 2 of `docs/PLAN-SKELET.md`.
///
/// **One single-threaded Stockfish process per worker, and nothing shared with
/// the rest of the app.** `StockfishService` is a singleton that also drives
/// the evaluation bar, and a build of eighty positions through it would fight
/// the bar for every answer. So the builder starts its own processes of the
/// downloaded binary and closes them when it is done.
///
/// **Every search starts from an empty hash** (`ucinewgame`), as the harness
/// does: phase 0 measured the facts built this way identical to the harness's
/// on all ten games at depth 18, because one thread at a fixed depth from an
/// empty table is deterministic and the binary is the same one.
///
/// **A search that runs out of time is stopped and returns what it had.** It is
/// not this file's business to decide that a shallow answer is not a fact —
/// `searchProblem` in `game_facts.dart` does, for every analyzer alike.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/models/analysis_models.dart';

/// Workers for a machine with [logicalProcessors].
///
/// Phase 0, on a laptop with 10 cores and 16 logical processors: 8 workers
/// built a game in 39–109 s, and 16 bought nothing reliable — one game got
/// slower. Dart reports logical processors only, so half of them is the guess,
/// capped at the 8 that were measured.
int defaultFactsWorkers([int? logicalProcessors]) => math.max(
    1, math.min(8, (logicalProcessors ?? Platform.numberOfProcessors) ~/ 2));

/// One `info` line's answer, or null when the line is not one.
typedef UciInfo = ({int rank, int depth, int? cp, int? mate, String pv});

/// Reads a line of UCI output. Only exact scores with a line count: a
/// `lowerbound` or `upperbound` score is a search still narrowing in, and the
/// final line for every rank arrives without one.
UciInfo? parseUciInfo(String line) {
  if (!line.startsWith('info ') || !line.contains(' pv ')) return null;
  if (line.contains(' lowerbound') || line.contains(' upperbound')) return null;
  final depth = _intAfter(line, 'depth');
  final cp = _intAfter(line, 'score cp');
  final mate = _intAfter(line, 'score mate');
  if (depth == null || (cp == null && mate == null)) return null;
  final pv = line.substring(line.indexOf(' pv ') + 4).trim();
  if (pv.isEmpty) return null;
  return (
    rank: _intAfter(line, 'multipv') ?? 1,
    depth: depth,
    cp: cp,
    mate: mate,
    pv: pv,
  );
}

int? _intAfter(String line, String key) {
  final at = line.indexOf(' $key ');
  if (at < 0) return null;
  final rest = line.substring(at + key.length + 2).trimLeft();
  return int.tryParse(rest.split(' ').first);
}

/// An answer in the app's own spelling: from White's side, `+0.35`, `-1.20`,
/// `0.00`, `M3`, `-M2` — exactly what `StockfishService` writes, so every
/// reader of an [AnalysisLine] reads this one the same way.
AnalysisLine analysisLineOf(String fen, UciInfo info) {
  final whiteToMove = fen.split(' ')[1] == 'w';
  final String eval;
  if (info.mate != null) {
    final white = whiteToMove ? info.mate! : -info.mate!;
    eval = white > 0 ? 'M$white' : '-M${white.abs()}';
  } else {
    final white = (whiteToMove ? info.cp! : -info.cp!) / 100.0;
    eval =
        white > 0 ? '+${white.toStringAsFixed(2)}' : white.toStringAsFixed(2);
  }
  return AnalysisLine.fromPv(
    multipv: info.rank,
    depth: info.depth,
    eval: eval,
    pvString: info.pv,
    startingFen: fen,
  );
}

/// One engine process.
class UciEngine {
  UciEngine._(this._lines, this._send, this._kill,
      {this.stopTimeout = const Duration(seconds: 10)});

  /// An engine behind any pair of streams — a process, or a test's script.
  UciEngine.fromStreams(Stream<String> lines, void Function(String) send,
      {void Function()? kill,
      Duration stopTimeout = const Duration(seconds: 10)})
      : this._(lines.isBroadcast ? lines : lines.asBroadcastStream(), send,
            kill ?? () {},
            stopTimeout: stopTimeout);

  final Stream<String> _lines;
  final void Function(String) _send;
  final void Function() _kill;

  /// How long a stopped search may take to say `bestmove` before the process
  /// is treated as hung.
  final Duration stopTimeout;

  bool _stopped = false;
  Completer<void>? _searching;

  static const _answerTimeout = Duration(seconds: 20);

  /// Starts [path] and makes it ready: one thread, [hashMb] of hash.
  static Future<UciEngine> start(String path, {int hashMb = 128}) async {
    final process = await Process.start(path, const []);
    unawaited(process.stderr.drain<void>());
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final engine = UciEngine._(
        lines, (c) => process.stdin.writeln(c), () => process.kill());
    try {
      await engine.handshake(hashMb: hashMb);
    } catch (_) {
      engine.close();
      rethrow;
    }
    return engine;
  }

  Future<void> handshake({int hashMb = 128}) async {
    await _ask('uci', 'uciok');
    _send('setoption name Threads value 1');
    _send('setoption name Hash value $hashMb');
    await _ask('isready', 'readyok');
  }

  /// Sends [command] and waits for a line that is exactly [token]. Listening
  /// starts before sending, so an answer that comes back at once is not missed.
  Future<void> _ask(String command, String token) async {
    final answer = _lines.firstWhere((l) => l.trim() == token).timeout(
        _answerTimeout,
        onTimeout: () => throw StateError('the engine never said $token'));
    _send(command);
    await answer;
  }

  /// The [PositionAnalyzer] shape: [multiPV] lines for [fen] at [depth].
  ///
  /// [searchMoves] narrows the search to those moves only (`go depth N
  /// searchmoves a b …`), for asking the engine's opinion of one move that is
  /// not among the top lines already searched — `docs/PLAN-MOJE-PARTIJE.md`
  /// §9.3. Left null, nothing narrows the search, exactly as before.
  Future<List<AnalysisLine>> analyze(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(minutes: 15),
  }) async {
    if (_stopped) throw StateError('the engine has been closed');
    await _ask('ucinewgame\nisready', 'readyok');

    final best = <int, UciInfo>{};
    final done = Completer<void>();
    _searching = done;
    final sub = _lines.listen((line) {
      if (line.startsWith('bestmove')) {
        if (!done.isCompleted) done.complete();
        return;
      }
      final info = parseUciInfo(line);
      if (info != null) best[info.rank] = info;
    });
    try {
      _send('setoption name MultiPV value $multiPV');
      _send('position fen $fen');
      _send(searchMoves == null || searchMoves.isEmpty
          ? 'go depth $depth'
          : 'go depth $depth searchmoves ${searchMoves.join(' ')}');
      try {
        await done.future.timeout(timeout);
      } on TimeoutException {
        _send('stop');
        // The engine must have finished before the next search is sent, or
        // this search's last lines are read as the next one's.
        await done.future.timeout(stopTimeout, onTimeout: () {
          close();
          throw StateError('the engine did not stop when asked');
        });
      }
    } finally {
      await sub.cancel();
      _searching = null;
    }
    final ranks = best.keys.toList()..sort();
    return [for (final r in ranks) analysisLineOf(fen, best[r]!)];
  }

  PositionAnalyzer get analyzer => analyze;

  /// Stops the process. A search in progress ends with an error rather than
  /// waiting for a timeout nobody will see.
  void close() {
    if (_stopped) return;
    _stopped = true;
    final pending = _searching;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('the engine has been closed'));
    }
    try {
      _send('quit');
    } catch (_) {
      // The pipe may already be gone; the kill below is what counts.
    }
    _kill();
  }
}

/// The engines of one build.
class UciEnginePool {
  UciEnginePool._(this.engines);

  final List<UciEngine> engines;

  static Future<UciEnginePool> start(String path,
      {required int workers}) async {
    final started = <UciEngine>[];
    try {
      for (var i = 0; i < workers; i++) {
        started.add(await UciEngine.start(path));
      }
    } catch (_) {
      for (final e in started) {
        e.close();
      }
      rethrow;
    }
    return UciEnginePool._(started);
  }

  List<PositionAnalyzer> get analyzers => [for (final e in engines) e.analyzer];

  void close() {
    for (final e in engines) {
      e.close();
    }
  }
}
