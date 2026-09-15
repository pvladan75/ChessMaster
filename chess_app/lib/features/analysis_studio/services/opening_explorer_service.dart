import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

class OpeningExplorerMove {
  final String uci;
  final String san;
  final int white;
  final int draws;
  final int black;

  OpeningExplorerMove({
    required this.uci,
    required this.san,
    required this.white,
    required this.draws,
    required this.black,
  });

  int get total => white + draws + black;

  // Historical outcome shares (0-100), always from White's perspective.
  double get whitePercent => total == 0 ? 0 : white * 100 / total;
  double get drawsPercent => total == 0 ? 0 : draws * 100 / total;
  double get blackPercent => total == 0 ? 0 : black * 100 / total;

  factory OpeningExplorerMove.fromJson(Map<String, dynamic> json) {
    return OpeningExplorerMove(
      uci: json['uci'] as String? ?? '',
      san: json['san'] as String? ?? '',
      white: (json['white'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      black: (json['black'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpeningExplorerResult {
  final String fen;
  final int white;
  final int draws;
  final int black;
  final List<OpeningExplorerMove> moves;
  final int unlisted;
  final bool beyondBook;

  OpeningExplorerResult({
    required this.fen,
    required this.white,
    required this.draws,
    required this.black,
    required this.moves,
    this.unlisted = 0,
    this.beyondBook = false,
  });

  int get total => white + draws + black;

  factory OpeningExplorerResult.fromJson(
    String fen,
    Map<String, dynamic> json,
  ) {
    final movesJson = (json['moves'] as List?) ?? const [];
    final moves = movesJson
        .whereType<Map>()
        .map((e) => OpeningExplorerMove.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return OpeningExplorerResult(
      fen: fen,
      white: (json['white'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      black: (json['black'] as num?)?.toInt() ?? 0,
      moves: moves,
      unlisted: (json['unlisted'] as num?)?.toInt() ?? 0,
      beyondBook: json['beyondBook'] as bool? ?? false,
    );
  }
}

/// How a lookup ended.
enum OpeningExplorerStatus { ok, unavailable }

class OpeningExplorerLookup {
  final OpeningExplorerStatus status;
  final OpeningExplorerResult? result;

  /// Why the book could not be reached, in the server's own words:
  /// `not-configured`, `unreadable`, `inconsistent`, `guest`, `network`, etc.
  final String? reason;

  const OpeningExplorerLookup.ok(this.result)
      : status = OpeningExplorerStatus.ok,
        reason = null;

  const OpeningExplorerLookup.unavailable(this.reason)
      : status = OpeningExplorerStatus.unavailable,
        result = null;

  bool get isAvailable => status == OpeningExplorerStatus.ok;
}

/// What master games played in the position on the board, read from the
/// opening book on our own server. The position's name is not asked here: the
/// screen already has it from the bundled ECO data.
class OpeningExplorerService {
  OpeningExplorerService._({http.Client? client}) : _client = client;

  static final OpeningExplorerService instance = OpeningExplorerService._();

  /// An explorer service with a stubbed transport, for tests.
  @visibleForTesting
  factory OpeningExplorerService.withClient(http.Client client) =>
      OpeningExplorerService._(client: client);

  final http.Client? _client;

  final Map<String, OpeningExplorerLookup> _cache = {};

  Future<OpeningExplorerLookup> lookup(
    String fen, {
    int movesLimit = 12,
  }) async {
    final cacheKey = '$fen|$movesLimit';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final session = SessionService.instance.current;
    if (session.token.isEmpty) {
      return const OpeningExplorerLookup.unavailable('guest');
    }

    final uri = Uri.parse('$backendUrl/opening-explorer').replace(
      queryParameters: {
        'fen': fen,
        'moves': '$movesLimit',
      },
    );

    try {
      final res = await _get(
        uri,
        headers: {'Authorization': 'Bearer ${session.token}'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        final reason = _reasonOf(res.body) ?? 'http-${res.statusCode}';
        AppLogger.log(
          '[OpeningExplorer] ⚠️ Backend ${res.statusCode} ($reason) | FEN: $fen',
        );
        return OpeningExplorerLookup.unavailable(reason);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = OpeningExplorerResult.fromJson(fen, data);
      AppLogger.log(
        '[OpeningExplorer] ✅ ${result.moves.length} moves, ${result.total} games',
      );
      final lookup = OpeningExplorerLookup.ok(result);
      _cache[cacheKey] = lookup;
      return lookup;
    } catch (e) {
      AppLogger.log('[OpeningExplorer] ❌ Backend unreachable: $e');
      return const OpeningExplorerLookup.unavailable('network');
    }
  }

  Future<http.Response> _get(Uri uri, {required Map<String, String> headers}) =>
      _client?.get(uri, headers: headers) ?? http.get(uri, headers: headers);

  static String? _reasonOf(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['reason'] is String) {
        return data['reason'] as String;
      }
    } catch (_) {
      // A body that is not JSON says nothing the status code has not said.
    }
    return null;
  }

  @visibleForTesting
  void clearCache() {
    _cache.clear();
  }
}
