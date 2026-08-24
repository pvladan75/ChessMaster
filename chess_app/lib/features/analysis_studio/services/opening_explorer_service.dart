import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

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

  factory OpeningExplorerResult.fromJson(
      String fen, Map<String, dynamic> json) {
    final movesJson = (json['moves'] as List?) ?? const [];
    final moves = movesJson
        .whereType<Map>()
        .map((e) => OpeningExplorerMove.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final rawOpening = json['opening'];
    final openingJson =
        rawOpening is Map ? Map<String, dynamic>.from(rawOpening) : null;

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

/// How a lookup ended.
///
/// "No games were played from here" and "the book could not be reached" are two
/// different sentences on screen, and a bare `null` said both at once. The panel
/// shows an empty book for the first and falls back to ChessDB for the second.
enum OpeningExplorerStatus { ok, unavailable }

class OpeningExplorerLookup {
  final OpeningExplorerStatus status;
  final OpeningExplorerResult? result;

  /// Why the book could not be reached, in the server's own words:
  /// `not-configured`, `unauthorized`, `rate-limited`, `network` — or `guest`,
  /// which never leaves the app. Only the log reads it, and that is the point:
  /// without it a spent quota and an opening nobody has played look identical.
  final String? reason;

  const OpeningExplorerLookup.ok(this.result)
      : status = OpeningExplorerStatus.ok,
        reason = null;

  const OpeningExplorerLookup.unavailable(this.reason)
      : status = OpeningExplorerStatus.unavailable,
        result = null;

  bool get isAvailable => status == OpeningExplorerStatus.ok;
}

/// Real game statistics (move popularity, opening name, win rates) for the
/// position on the board.
///
/// The lookup goes through our backend, which holds the one Lichess token and
/// caches what it learns. That is why this stopped being something the user has
/// to set up: the Explorer demands a token, and sending every trainer and every
/// child off to make one meant that in practice almost nobody did, and the panel
/// quietly showed ChessDB instead.
///
/// A personal token in Settings still wins when there is one. It is nobody's
/// obligation any more — it is there for someone who would rather spend their
/// own allowance than the shared one, and as the way out if ours is ever
/// refused.
class OpeningExplorerService {
  OpeningExplorerService._();
  static final OpeningExplorerService instance = OpeningExplorerService._();

  static const _lichessUrl = 'https://explorer.lichess.ovh/lichess';

  /// The token form with the description filled in and — deliberately — not one
  /// scope ticked. The Explorer only wants to know who is asking; a token that
  /// can do more than that is a permission on a child's Lichess account sitting
  /// in `SharedPreferences` for no reason.
  static const createTokenUrl = 'https://lichess.org/account/oauth/token/create'
      '?description=Sahovski%20trener%20-%20baza%20otvaranja';

  static String get _personalToken =>
      AppSettingsService.instance.lichessApiToken;

  final Map<String, OpeningExplorerLookup> _cache = {};

  /// [minRating] is a floor. The backend expands it into every Lichess rating
  /// bucket at or above it, so "2000+" means 2000 and up rather than the games
  /// between 2000 and 2199. Pass null for all ratings.
  Future<OpeningExplorerLookup> lookup(
    String fen, {
    int movesLimit = 12,
    int? minRating,
  }) async {
    final cacheKey = '$fen|$movesLimit|${minRating ?? 'all'}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final token = _personalToken;
    final lookup = token.isEmpty
        ? await _viaBackend(fen, movesLimit, minRating)
        : await _direct(fen, movesLimit, minRating, token);

    // Only an answer is remembered. Caching a failure would go on showing an
    // empty book for the rest of the session because of one bad minute.
    if (lookup.isAvailable) _cache[cacheKey] = lookup;
    return lookup;
  }

  /// The ordinary path: our server asks Lichess, and answers out of its own
  /// cache when it already knows.
  Future<OpeningExplorerLookup> _viaBackend(
    String fen,
    int movesLimit,
    int? minRating,
  ) async {
    final session = SessionService.instance.current;
    if (session.token.isEmpty) {
      // A guest cannot prove who they are, and the route will not spend the
      // shared token on an anonymous caller. ChessDB needs no account and is
      // exactly what a guest saw before any of this existed.
      AppLogger.log('[OpeningExplorer] 👤 Gost — koristim ChessDB');
      return const OpeningExplorerLookup.unavailable('guest');
    }

    final uri =
        Uri.parse('$backendUrl/opening-explorer').replace(queryParameters: {
      'fen': fen,
      'moves': '$movesLimit',
      if (minRating != null) 'minRating': '$minRating',
    });

    try {
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${session.token}'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        final reason = _reasonOf(res.body) ?? 'http-${res.statusCode}';
        AppLogger.log(
            '[OpeningExplorer] ⚠️ Backend ${res.statusCode} ($reason) | FEN: $fen');
        return OpeningExplorerLookup.unavailable(reason);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = OpeningExplorerResult.fromJson(fen, data);
      AppLogger.log(
          '[OpeningExplorer] ✅ ${result.moves.length} poteza, ${result.total} partija');
      return OpeningExplorerLookup.ok(result);
    } catch (e) {
      AppLogger.log('[OpeningExplorer] ❌ Backend nedostupan: $e');
      return const OpeningExplorerLookup.unavailable('network');
    }
  }

  /// The way out: a personal token goes straight to Lichess, so a refused
  /// server token is not the end of the panel for whoever has one.
  Future<OpeningExplorerLookup> _direct(
    String fen,
    int movesLimit,
    int? minRating,
    String token,
  ) async {
    final uri = Uri.parse(_lichessUrl).replace(queryParameters: {
      'fen': fen,
      'moves': '$movesLimit',
      'topGames': '0',
      'recentGames': '0',
      if (minRating != null) 'ratings': _bucketsFrom(minRating).join(','),
    });

    try {
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        AppLogger.log(
            '[OpeningExplorer] ⚠️ Lichess ${res.statusCode} (lični token) | FEN: $fen');
        return OpeningExplorerLookup.unavailable(
            _reasonOfStatus(res.statusCode));
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return OpeningExplorerLookup.ok(
          OpeningExplorerResult.fromJson(fen, data));
    } catch (e) {
      AppLogger.log('[OpeningExplorer] ❌ Lichess nedostupan: $e');
      return const OpeningExplorerLookup.unavailable('network');
    }
  }

  /// Mirrors `ratingBucketsFrom` on the server. Lichess wants the list of
  /// buckets to count, not a floor, so a lone 1600 quietly answers with games
  /// between 1600 and 1799 while the panel says "1600+".
  static List<int> _bucketsFrom(int minRating) => const [
        0,
        1000,
        1200,
        1400,
        1600,
        1800,
        2000,
        2200,
        2500
      ].where((b) => b >= minRating).toList();

  static String _reasonOfStatus(int status) {
    if (status == 401 || status == 403) return 'unauthorized';
    if (status == 429) return 'rate-limited';
    return 'http-$status';
  }

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
}
