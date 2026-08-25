import 'dart:async';

import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_logger.dart';

/// Remembers engine evaluations so the same position is not searched twice.
///
/// Whole-game review, automatic tree generation and puzzle extraction all walk
/// the same board, and each of them asked the engine from scratch. Reviewing a
/// game and then running automatic analysis over it meant paying for every
/// position a second time — the slowest part of both operations, repeated for
/// nothing.
///
/// It attaches as a decorator around a [PositionAnalyzer], which is a plain
/// function type, so none of the three services needed changing to benefit.
class EvalCache {
  EvalCache({this.maxEntries = 2000});

  /// Shared by whole-game review, automatic tree generation and puzzle
  /// extraction, because the win is precisely that they see each other's work:
  /// reviewing a game and then expanding it should not search the same
  /// positions twice.
  ///
  /// Cleared whenever the engine is (re)initialised — the engine's identity is
  /// not part of the key, so results from a previous binary or a different
  /// setting must not survive the switch.
  static final EvalCache instance = EvalCache();

  /// Bounded so a long session cannot grow without limit. Dart's Map keeps
  /// insertion order, which is what makes the cheap eviction below correct.
  final int maxEntries;

  final Map<String, List<AnalysisLine>> _entries = {};

  /// Searches already running, so two callers asking for the same position at
  /// the same moment share one engine run instead of racing to compute it twice.
  final Map<String, Future<List<AnalysisLine>>> _inFlight = {};

  int _hits = 0;
  int _misses = 0;

  int get size => _entries.length;
  int get hits => _hits;
  int get misses => _misses;

  /// The whole FEN takes part in the key, move counters included.
  ///
  /// Tempting to strip them so transpositions collide, but the halfmove clock
  /// genuinely changes what the engine reports near the fifty-move rule, and a
  /// draw score served for a position that is not actually drawn would be a very
  /// hard bug to find. The wins this cache is for — the same game analysed twice
  /// — produce identical FENs anyway.
  static String keyFor(String fen, int depth, int multiPV) =>
      '$fen|d$depth|pv$multiPV';

  List<AnalysisLine>? peek(String fen, int depth, int multiPV) =>
      _entries[keyFor(fen, depth, multiPV)];

  void store(String fen, int depth, int multiPV, List<AnalysisLine> lines) {
    if (lines.isEmpty) return; // an empty result is a failure, not an answer

    final key = keyFor(fen, depth, multiPV);
    // Re-inserting moves the entry to the end, so anything touched recently
    // survives eviction.
    _entries.remove(key);
    _entries[key] = List.unmodifiable(lines);

    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Wraps [inner] so repeated positions are answered from memory.
  ///
  /// A deeper search is not served from a shallower cached one: the caller asked
  /// for a depth, and quietly giving them less is exactly the kind of silent
  /// downgrade that makes an analysis wrong without looking wrong.
  PositionAnalyzer wrap(PositionAnalyzer inner) {
    return (
      String fen, {
      required int depth,
      required int multiPV,
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final key = keyFor(fen, depth, multiPV);

      final cached = _entries[key];
      if (cached != null) {
        _hits++;
        return cached;
      }

      final running = _inFlight[key];
      if (running != null) {
        _hits++;
        return running;
      }

      _misses++;
      final future =
          inner(fen, depth: depth, multiPV: multiPV, timeout: timeout);
      _inFlight[key] = future;

      try {
        final lines = await future;
        store(fen, depth, multiPV, lines);
        return lines;
      } finally {
        // Cleared whether the search succeeded or threw, so one failure does not
        // leave a permanently poisoned entry that every later caller awaits.
        _inFlight.remove(key);
      }
    };
  }

  void logStats(String context) {
    final total = _hits + _misses;
    if (total == 0) return;
    final percent = ((_hits / total) * 100).round();
    AppLogger.log(
        '[EvalCache] $context — $_hits/$total iz keša ($percent%), $size pozicija.');
  }
}
