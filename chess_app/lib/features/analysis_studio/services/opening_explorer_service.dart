import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chess_app/services/app_logger.dart';

class OpeningInfo {
  final String eco;
  final String name;

  OpeningInfo({required this.eco, required this.name});

  factory OpeningInfo.fromJson(Map<String, dynamic> json) {
    return OpeningInfo(
      eco: json['eco'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class OpeningExplorerMove {
  final String uci;
  final String san;
  final int white;
  final int draws;
  final int black;
  final int? averageOpponentRating;

  OpeningExplorerMove({
    required this.uci,
    required this.san,
    required this.white,
    required this.draws,
    required this.black,
    this.averageOpponentRating,
  });

  int get total => white + draws + black;

  // Historical outcome shares (0-100), always from White's perspective —
  // the Explorer counts past games and is not relative to who is to move.
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
      averageOpponentRating: (json['averageOpponentRating'] as num?)?.toInt(),
    );
  }
}

class OpeningExplorerResult {
  final String fen;
  final int white;
  final int draws;
  final int black;
  final OpeningInfo? opening;
  final List<OpeningExplorerMove> moves;

  OpeningExplorerResult({
    required this.fen,
    required this.white,
    required this.draws,
    required this.black,
    required this.opening,
    required this.moves,
  });

  int get total => white + draws + black;

  factory OpeningExplorerResult.fromJson(String fen, Map<String, dynamic> json) {
    final movesJson = (json['moves'] as List?) ?? const [];
    final moves = movesJson
        .whereType<Map<String, dynamic>>()
        .map(OpeningExplorerMove.fromJson)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final openingJson = json['opening'] as Map<String, dynamic>?;

    return OpeningExplorerResult(
      fen: fen,
      white: (json['white'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      black: (json['black'] as num?)?.toInt() ?? 0,
      opening: openingJson != null ? OpeningInfo.fromJson(openingJson) : null,
      moves: moves,
    );
  }
}

/// Looks up real game statistics (move popularity, opening name, win rates)
/// from the Lichess Opening Explorer. As of the 2026 anti-abuse changes this
/// endpoint requires a personal Lichess OAuth token (see
/// lichess.org/account/oauth/token) sent as a Bearer header; without one the
/// lookup is skipped entirely rather than surfacing a 401 to the user.
class OpeningExplorerService {
  OpeningExplorerService._();
  static final OpeningExplorerService instance = OpeningExplorerService._();

  static const _baseUrl = 'https://explorer.lichess.ovh/lichess';

  final Map<String, OpeningExplorerResult?> _cache = {};

  /// [minRating] sends the Lichess Explorer `ratings` bucket filter (e.g. 2500
  /// selects games whose average rating falls in the 2500+ bucket). Buckets
  /// are fixed steps (1000, 1200, ... 2200, 2500); pass null for all ratings.
  Future<OpeningExplorerResult?> lookup(
    String fen,
    String apiToken, {
    int movesLimit = 12,
    int? minRating,
  }) async {
    if (apiToken.isEmpty) return null;

    final cacheKey = '$fen|$movesLimit|${minRating ?? 'all'}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'fen': fen,
        'moves': '$movesLimit',
        if (minRating != null) 'ratings': '$minRating',
      });
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $apiToken'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) {
        AppLogger.log('[OpeningExplorer] ⚠️ HTTP ${res.statusCode} for FEN: $fen');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = OpeningExplorerResult.fromJson(fen, data);
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      AppLogger.log('[OpeningExplorer] ❌ Lookup failed: $e');
      return null;
    }
  }
}
