import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

/// The wire for docs/PLAN-NAPREDAK-VEZBI.md: every drill writes the attempt
/// log through this, and the hub reads it back through this.
///
/// One class rather than a method per drill, because the server has one log
/// and one idea of a source; a drill that spelled its source differently would
/// be invisible on the card. Tactics keeps `TacticsApiService.submitAttempt`
/// for its own row (it needs the rating back); it sends the same fields.
///
/// The sources are the server's (`services/puzzleProgress.js`). Frozen here
/// too, because a string typed at a call site is a string that drifts.
abstract final class PuzzleSource {
  static const String lichess = 'lichess';
  static const String matePuzzle = 'mate_puzzle';
  static const String winningPosition = 'winning_position';
  static const String endgame = 'endgame';
  static const String blunderGame = 'blunder_game';
  static const String basicMate = 'basic_mate';

  /// One's own exercise, solved alone (`docs/PLAN-MATERIJAL.md`, phase 1). The
  /// server judges it and writes the row itself; [PuzzleAttemptApi] never
  /// reports one, and the server refuses it if it does.
  static const String own = 'own';

  static const List<String> all = [
    lichess,
    matePuzzle,
    winningPosition,
    endgame,
    blunderGame,
    basicMate,
    own,
  ];

  /// The sources whose puzzles can be served again by id — the ones a
  /// „Retry failed" button can act on. Basic mates are presets and a blunder
  /// game is a game, not a puzzle: neither has a by-id route.
  static const List<String> retryable = [
    lichess,
    matePuzzle,
    winningPosition,
    endgame,
    own,
  ];

  /// The first four FEN fields — the key `opening_nodes` and the repertoire
  /// already use, so a basic-mate preset is one puzzle however it was reached.
  static String basicMateId(String preset, String fen) {
    final fields = fen.trim().split(RegExp(r'\s+'));
    return 'basic:$preset:${fields.take(4).join(' ')}';
  }

  /// A game's id is opaque here — the archive names it, and it is a string
  /// on the wire — so nothing is parsed: an id that is not a number is still
  /// this game's id, and a stop in it is still recorded.
  static String blunderGameId(String gameId, int ply) => '$gameId:$ply';
}

/// What a player has done with one source's puzzles, as the server folds it.
class SourceProgress {
  const SourceProgress({
    required this.seen,
    required this.solved,
    required this.firstTry,
    required this.failed,
    required this.skipped,
    required this.toRetry,
    this.buckets = const {},
  });

  final int seen;
  final int solved;
  final int firstTry;
  final int failed;
  final int skipped;
  final int toRetry;

  /// A finer group inside the source — a mate's depth, an endgame's mode.
  final Map<String, SourceProgress> buckets;

  factory SourceProgress.fromJson(Map<String, dynamic> json) => SourceProgress(
        seen: _int(json['seen']),
        solved: _int(json['solved']),
        firstTry: _int(json['firstTry']),
        failed: _int(json['failed']),
        skipped: _int(json['skipped']),
        toRetry: _int(json['toRetry']),
        buckets: {
          for (final e
              in (json['buckets'] as Map<String, dynamic>? ?? {}).entries)
            e.key: SourceProgress.fromJson(e.value as Map<String, dynamic>),
        },
      );

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
}

/// Attempt writes still in flight, and the one thing that makes a read of the
/// log correct straight after one.
///
/// **The log is written on one screen and read on another.** A drill fires its
/// last attempt and does not wait for it — recording must never hold up the
/// board — and the reader leaves at once, which resolves the hub's
/// `context.push` and sends `progress()` immediately. The read can therefore
/// overtake the write and be answered with the log as it was one attempt ago.
///
/// Reported live on 18.9.2026 (TODO-provera 176.2): solve, miss, skip, come
/// back, and the mates card is one behind. Waiting does not mend it — nothing
/// re-reads on a wait — but pushing any other screen and popping straight back
/// does, because that is a second read. `hub_refresh_after_drill_test` proves
/// the client re-reads; this is the ordering it was missing.
///
/// Three paths write the log — [PuzzleAttemptApi.record], the puzzle screen's
/// own post to `/submit`, and `TacticsApiService.submitAttempt` — so the
/// barrier is here, beside the sources, rather than in any one of them.
abstract final class PuzzleAttemptWrites {
  static final Set<Future<void>> _inFlight = <Future<void>>{};

  /// Registers [write] and hands it straight back, so a caller can keep firing
  /// and forgetting. Failures are swallowed here and nowhere else: this
  /// barrier is about *when* a write is over, never about whether it worked.
  static Future<T> track<T>(Future<T> write) {
    late final Future<void> done;
    done = write.then((_) {}, onError: (_) {}).whenComplete(() {
      _inFlight.remove(done);
    });
    _inFlight.add(done);
    return write;
  }

  /// Completes once every write started before this call has finished.
  ///
  /// Bounded, and deliberately quiet when the bound is reached: a write that
  /// will not finish must not stop the reader from reading. The worst case is
  /// then the stale number this exists to prevent, which is where we already
  /// were — never a screen that does not load.
  static Future<void> settled({
    Duration limit = const Duration(seconds: 5),
  }) async {
    if (_inFlight.isEmpty) return;
    try {
      await Future.wait(_inFlight.toList()).timeout(limit);
    } catch (e) {
      AppLogger.log('[Puzzles] read did not wait for every write: $e');
    }
  }

  /// For tests: forget anything still tracked.
  @visibleForTesting
  static void reset() => _inFlight.clear();
}

class PuzzleAttemptApi {
  PuzzleAttemptApi({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String authToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  /// Writes one row of the log. Never throws: a message about the work must
  /// not be able to stop the work, and this is a message. Returns whether the
  /// server took it.
  ///
  /// Mates and winning positions go to `/submit`, which also moves their
  /// rating; every other source goes to `/attempt`, which for a source with
  /// no Elo writes the row and nothing else. Tactics (`lichess`) has its own
  /// path in `TacticsApiService` and does not come through here.
  Future<bool> record({
    required String source,
    required String puzzleId,
    required bool solved,
    bool skipped = false,
    bool hinted = false,
    int? msTaken,
  }) async {
    if (!PuzzleSource.all.contains(source)) {
      throw ArgumentError.value(source, 'source', 'not a puzzle source');
    }
    final toSubmit = source == PuzzleSource.matePuzzle ||
        source == PuzzleSource.winningPosition;
    final uri =
        Uri.parse('$backendUrl/api/puzzles/${toSubmit ? 'submit' : 'attempt'}');
    final body = <String, dynamic>{
      'puzzleId': puzzleId,
      'solved': solved,
      'skipped': skipped,
      'hinted': hinted,
      if (!toSubmit) 'source': source,
      if (!toSubmit && msTaken != null) 'msTaken': msTaken,
    };
    try {
      final res = await PuzzleAttemptWrites.track(_client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12)));
      if (res.statusCode != 200) {
        AppLogger.log('[Puzzles] attempt not recorded: ${res.statusCode}');
      }
      return res.statusCode == 200;
    } catch (e) {
      AppLogger.log('[Puzzles] attempt not recorded: $e');
      return false;
    }
  }

  /// The fold per source. Null when the server could not be reached — the
  /// hub draws nothing then, which is not the same as drawing zeros.
  Future<Map<String, SourceProgress>?> progress() async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/api/puzzles/progress'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        for (final e in json.entries)
          if (e.value is Map<String, dynamic>)
            e.key: SourceProgress.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (e) {
      AppLogger.log('[Puzzles] progress not read: $e');
      return null;
    }
  }

  /// The ids of one source's unsolved puzzles, oldest failure first. Null
  /// when the server could not be reached; an empty list means nothing to
  /// retry.
  Future<List<String>?> retryIds(String source) async {
    if (!PuzzleSource.retryable.contains(source)) {
      throw ArgumentError.value(source, 'source', 'has no retry queue');
    }
    try {
      final uri = Uri.parse('$backendUrl/api/puzzles/retry')
          .replace(queryParameters: {'source': source});
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['ids'] as List? ?? []).map((e) => e.toString()).toList();
    } catch (e) {
      AppLogger.log('[Puzzles] retry list not read: $e');
      return null;
    }
  }
}
