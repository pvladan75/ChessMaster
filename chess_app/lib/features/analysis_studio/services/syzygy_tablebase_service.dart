import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

/// WDL category as reported by the Lichess Syzygy tablebase API, always
/// expressed from the perspective of the side to move in the position it
/// describes.
enum SyzygyCategory {
  win,
  maybeWin,
  cursedWin,
  draw,
  blessedLoss,
  maybeLoss,
  loss,
  unknown,
}

SyzygyCategory syzygyCategoryFromString(String? raw) {
  switch (raw) {
    case 'win':
      return SyzygyCategory.win;
    case 'maybe-win':
      return SyzygyCategory.maybeWin;
    case 'cursed-win':
      return SyzygyCategory.cursedWin;
    case 'draw':
      return SyzygyCategory.draw;
    case 'blessed-loss':
      return SyzygyCategory.blessedLoss;
    case 'maybe-loss':
      return SyzygyCategory.maybeLoss;
    case 'loss':
      return SyzygyCategory.loss;
    default:
      return SyzygyCategory.unknown;
  }
}

/// Lower rank sorts first. Ranked from the perspective of the side about to
/// play the move (i.e. inverted from [SyzygyCategory], since the API reports
/// each move's category for the opponent who is to move afterwards).
int _moveRankForMover(SyzygyCategory category) {
  switch (category) {
    case SyzygyCategory.loss:
      return 0; // opponent loses => best for the mover
    case SyzygyCategory.maybeLoss:
      return 1;
    case SyzygyCategory.blessedLoss:
      return 2;
    case SyzygyCategory.draw:
    case SyzygyCategory.unknown:
      return 3;
    case SyzygyCategory.cursedWin:
      return 4;
    case SyzygyCategory.maybeWin:
      return 5;
    case SyzygyCategory.win:
      return 6; // opponent wins => worst for the mover
  }
}

class SyzygyMove {
  final String uci;
  final String san;
  final SyzygyCategory category;
  final int? dtz;
  final int? dtm;
  final bool zeroing;
  final bool checkmate;
  final bool stalemate;

  SyzygyMove({
    required this.uci,
    required this.san,
    required this.category,
    this.dtz,
    this.dtm,
    required this.zeroing,
    required this.checkmate,
    required this.stalemate,
  });

  factory SyzygyMove.fromJson(Map<String, dynamic> json) {
    return SyzygyMove(
      uci: json['uci'] as String? ?? '',
      san: json['san'] as String? ?? '',
      category: syzygyCategoryFromString(json['category'] as String?),
      dtz: json['dtz'] as int?,
      dtm: json['dtm'] as int?,
      zeroing: json['zeroing'] as bool? ?? false,
      checkmate: json['checkmate'] as bool? ?? false,
      stalemate: json['stalemate'] as bool? ?? false,
    );
  }
}

class SyzygyResult {
  final String fen;
  final SyzygyCategory category;
  final int? dtz;
  final int? dtm;
  final bool checkmate;
  final bool stalemate;
  final bool insufficientMaterial;
  final List<SyzygyMove> moves;

  SyzygyResult({
    required this.fen,
    required this.category,
    this.dtz,
    this.dtm,
    required this.checkmate,
    required this.stalemate,
    required this.insufficientMaterial,
    required this.moves,
  });

  factory SyzygyResult.fromJson(String fen, Map<String, dynamic> json) {
    final movesJson = (json['moves'] as List?) ?? const [];
    final moves = movesJson
        .whereType<Map<String, dynamic>>()
        .map(SyzygyMove.fromJson)
        .toList()
      ..sort((a, b) {
        final rankDiff = _moveRankForMover(a.category)
            .compareTo(_moveRankForMover(b.category));
        if (rankDiff != 0) return rankDiff;
        return (a.dtz ?? 0).abs().compareTo((b.dtz ?? 0).abs());
      });

    return SyzygyResult(
      fen: fen,
      category: syzygyCategoryFromString(json['category'] as String?),
      dtz: json['dtz'] as int?,
      dtm: json['dtm'] as int?,
      checkmate: json['checkmate'] as bool? ?? false,
      stalemate: json['stalemate'] as bool? ?? false,
      insufficientMaterial: json['insufficient_material'] as bool? ?? false,
      moves: moves,
    );
  }
}

/// Looks up exact endgame results (win/draw/loss + distance-to-zero). Only
/// meaningful for positions with 7 or fewer pieces on the board.
///
/// **The server is asked first** (`GET /api/tablebase`,
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1t): it answers five men or
/// fewer from the owner's own tables and the rest from Lichess, paced and
/// cached for everybody, in the explorer's own shape. Lichess is asked
/// directly only when the server cannot be reached — no sign-in, no network,
/// or a server without the route (401, 404). A server that was reached and
/// could not answer (a 503: the tablebase is unavailable) is an answer too:
/// null, and Lichess is not asked behind its back.
///
/// **Paced and rate-limited** (measured 30.8.2026): a run of requests without
/// a gap draws a 429 from `tablebase.lichess.ovh` after 84–98 of them at
/// ~4.8/s, and a request sent while blocked only extends the block — which a
/// game review with a long, tablebase-eligible ending can produce on its own,
/// asking about every position with seven men or fewer (`kTablebaseMen`). So
/// every real request waits at least [_minGap] behind the last one (a cached
/// answer never waits), and a 429 blocks the service for [_blockDuration]
/// during which [lookup] answers null without sending anything — never
/// retried, exactly as the server's own pacing does it
/// (`chess_backend/services/tablebaseService.js`, `TABLEBASE_GAP_MS`).
class SyzygyTablebaseService {
  SyzygyTablebaseService._()
      : _client = null,
        _now = DateTime.now,
        _sleep = _defaultSleep,
        _serverUrl = backendUrl,
        _token = (() => SessionService.instance.current.token);

  static final SyzygyTablebaseService instance = SyzygyTablebaseService._();

  /// For tests: an injectable client and clock/sleep seam, paced exactly as
  /// [instance] is. Callers of [instance] see no change.
  @visibleForTesting
  SyzygyTablebaseService.forTesting({
    required http.Client client,
    DateTime Function() now = DateTime.now,
    Future<void> Function(Duration duration)? sleep,
    String serverUrl = 'http://server.test',
    String token = '',
  })  : _client = client,
        _now = now,
        _sleep = sleep ?? _defaultSleep,
        _serverUrl = serverUrl,
        _token = (() => token);

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  static const _baseUrl = 'https://tablebase.lichess.ovh/standard';

  /// Requests at least this far apart — the server's own `TABLEBASE_GAP_MS`.
  static const _minGap = Duration(seconds: 1);

  /// How long a 429 blocks further requests.
  static const _blockDuration = Duration(seconds: 60);

  /// Null: each request on its own, as the service always asked.
  final http.Client? _client;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _sleep;

  final Map<String, SyzygyResult?> _cache = {};

  final String _serverUrl;
  final String Function() _token;

  /// The earliest moment the next request may go out.
  ///
  /// Slots, not a queue of futures: each request takes the next free second
  /// at once and sleeps until it comes, so callers that ask together are still
  /// spaced, and there is nothing one unfinished request can hold up. The
  /// first version chained every lookup behind the last, and a lookup whose
  /// answer never came — its timeout timer on a widget test's fake clock that
  /// had been thrown away — held every later lookup in the file forever.
  DateTime? _nextSlot;
  DateTime? _blockedUntil;

  bool _blocked() {
    final until = _blockedUntil;
    return until != null && _now().isBefore(until);
  }

  Future<SyzygyResult?> lookup(String fen) async {
    if (_cache.containsKey(fen)) return _cache[fen];

    final fromServer = await _askServer(fen);
    if (fromServer != null) {
      final (:reached, :result) = fromServer;
      if (result != null) _cache[fen] = result;
      if (reached) return result;
    }
    return _askLichess(fen);
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    final client = _client;
    return client == null
        ? http.get(uri, headers: headers)
        : client.get(uri, headers: headers);
  }

  /// The server's answer: null when it was never asked (no sign-in), else
  /// whether it was reached and what it said.
  Future<({bool reached, SyzygyResult? result})?> _askServer(String fen) async {
    final token = _token();
    if (token.isEmpty) return null;
    try {
      final uri = Uri.parse(
          '$_serverUrl/api/tablebase?fen=${Uri.encodeQueryComponent(fen)}');
      final res = await _get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (reached: true, result: SyzygyResult.fromJson(fen, data));
      }
      if (res.statusCode == 401 || res.statusCode == 404) {
        AppLogger.log(
            '[Syzygy] ⚠️ server ${res.statusCode} — asking Lichess directly');
        return (reached: false, result: null);
      }
      AppLogger.log('[Syzygy] ⚠️ server tablebase ${res.statusCode}: $fen');
      return (reached: true, result: null);
    } catch (e) {
      AppLogger.log('[Syzygy] ⚠️ server not reached ($e) — asking Lichess');
      return (reached: false, result: null);
    }
  }

  Future<SyzygyResult?> _askLichess(String fen) async {
    if (_blocked()) return null;

    final now = _now();
    final next = _nextSlot;
    final slot = next == null || next.isBefore(now) ? now : next;
    _nextSlot = slot.add(_minGap);
    if (slot.isAfter(now)) await _sleep(slot.difference(now));

    // Answered, or blocked, while this one waited for its slot.
    if (_cache.containsKey(fen)) return _cache[fen];
    if (_blocked()) return null;

    try {
      final url = '$_baseUrl?fen=${Uri.encodeComponent(fen)}';
      final res =
          await _get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (res.statusCode == 429) {
        _blockedUntil = _now().add(_blockDuration);
        AppLogger.log(
            '[Syzygy] ⚠️ 429 — blocked for ${_blockDuration.inSeconds}s');
        return null;
      }
      if (res.statusCode != 200) {
        AppLogger.log(
            '[Syzygy] ⚠️ Tablebase HTTP ${res.statusCode} for FEN: $fen');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = SyzygyResult.fromJson(fen, data);
      _cache[fen] = result;
      return result;
    } catch (e) {
      AppLogger.log('[Syzygy] ❌ Tablebase lookup failed: $e');
      return null;
    }
  }
}
