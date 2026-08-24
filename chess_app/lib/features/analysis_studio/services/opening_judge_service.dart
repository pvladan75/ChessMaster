import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

/// What the books and the engine, together, make of one move.
///
/// Four values and not three: `unknown` is what the judge says when Lichess has
/// never evaluated the position, and it is deliberately not folded into
/// `mistake`. A move nobody has judged, shown as a mistake, is the failure this
/// codebase keeps meeting - an answer that looks computed and is a guess.
enum OpeningVerdict { theory, playable, mistake, unknown }

class OpeningJudgement {
  const OpeningJudgement({
    required this.verdict,
    required this.fen,
    required this.san,
    required this.uci,
    required this.moverIsWhite,
    required this.mastersGames,
    required this.mastersTotal,
    required this.bandGames,
    required this.bandTotal,
    this.minRating,
    this.beforeCp,
    this.afterCp,
    this.lossCp,
    this.mateAfter,
    this.better,
    this.punishment = const [],
  });

  final OpeningVerdict verdict;

  /// The position the move was played *from*, so a verdict can never be shown
  /// under a board it does not belong to.
  final String fen;

  final String san;
  final String uci;
  final bool moverIsWhite;

  final int mastersGames;
  final int mastersTotal;
  final int bandGames;
  final int bandTotal;
  final int? minRating;

  /// Centipawns, always from the point of view of whoever played the move —
  /// the server converts, so nothing here has to remember that Lichess counts
  /// from White's side.
  final int? beforeCp;
  final int? afterCp;
  final int? lossCp;
  final int? mateAfter;

  /// What the engine would have played instead. Only under a move that gave
  /// something away; under a good one it would be noise.
  final String? better;

  /// How the move gets punished, in the notation a child reads. The same rule
  /// the endgame trainer had to learn: a number is not a lesson.
  final List<String> punishment;

  static OpeningVerdict _verdictOf(String? raw) {
    switch (raw) {
      case 'theory':
        return OpeningVerdict.theory;
      case 'playable':
        return OpeningVerdict.playable;
      case 'mistake':
        return OpeningVerdict.mistake;
      default:
        return OpeningVerdict.unknown;
    }
  }

  factory OpeningJudgement.fromJson(Map<String, dynamic> json) {
    final masters = json['masters'] is Map
        ? Map<String, dynamic>.from(json['masters'] as Map)
        : const <String, dynamic>{};
    final band = json['band'] is Map
        ? Map<String, dynamic>.from(json['band'] as Map)
        : const <String, dynamic>{};
    final eval = json['eval'] is Map
        ? Map<String, dynamic>.from(json['eval'] as Map)
        : const <String, dynamic>{};

    return OpeningJudgement(
      verdict: _verdictOf(json['verdict'] as String?),
      fen: json['fen'] as String? ?? '',
      san: json['san'] as String? ?? '',
      uci: json['uci'] as String? ?? '',
      moverIsWhite: json['moverIsWhite'] as bool? ?? true,
      mastersGames: (masters['games'] as num?)?.toInt() ?? 0,
      mastersTotal: (masters['total'] as num?)?.toInt() ?? 0,
      bandGames: (band['games'] as num?)?.toInt() ?? 0,
      bandTotal: (band['total'] as num?)?.toInt() ?? 0,
      minRating: (json['minRating'] as num?)?.toInt(),
      beforeCp: (eval['beforeCp'] as num?)?.toInt(),
      afterCp: (eval['afterCp'] as num?)?.toInt(),
      lossCp: (eval['lossCp'] as num?)?.toInt(),
      mateAfter: (eval['mateAfter'] as num?)?.toInt(),
      better: eval['better'] as String?,
      punishment: ((eval['punishment'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// One move played from a position, with how often and how well it went.
///
/// Used for both halves of building: the opponent's answers that have to be
/// prepared for, and — after the student has committed to a move of their own —
/// the candidates they can compare theirs against.
class OpponentReply {
  const OpponentReply({
    required this.uci,
    required this.san,
    required this.games,
    required this.share,
    this.white = 0,
    this.draws = 0,
    this.black = 0,
    this.covered = false,
  });

  final String uci;
  final String san;
  final int games;

  /// 0..1 of the games played from this position.
  final double share;

  /// How those games ended, from White's side — the Explorer counts results,
  /// not chances, so this is history and never an evaluation.
  final int white;
  final int draws;
  final int black;

  /// True for the moves the coverage rule prepared for.
  final bool covered;

  double get whitePercent => games == 0 ? 0 : white * 100 / games;
  double get drawPercent => games == 0 ? 0 : draws * 100 / games;
  double get blackPercent => games == 0 ? 0 : black * 100 / games;

  /// How the games went for whoever is to move here — the number the student
  /// is actually asking for when they compare two candidates.
  double scoreFor({required bool white_}) {
    if (games == 0) return 0;
    final wins = white_ ? white : black;
    return (wins + draws / 2) * 100 / games;
  }

  factory OpponentReply.fromJson(Map<String, dynamic> json) => OpponentReply(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        games: (json['games'] as num?)?.toInt() ?? 0,
        share: (json['share'] as num?)?.toDouble() ?? 0,
        white: (json['white'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
        black: (json['black'] as num?)?.toInt() ?? 0,
        covered: json['covered'] as bool? ?? false,
      );
}

/// The answers worth preparing for in one position — and, as plainly, the ones
/// that were left out.
///
/// The tail is not a rounding error to be hidden. It is exactly the set of
/// moves the drill will one day play and the student will have no answer to,
/// and saying "84% covered, 6 moves outside it" is the only honest way to tell
/// somebody their repertoire is finished.
class OpponentReplies {
  const OpponentReplies({
    required this.total,
    required this.replies,
    required this.coveredShare,
    required this.tailMoves,
    required this.tailShare,
    this.all = const [],
    this.minRating,
  });

  final int total;

  /// The ones the coverage rule prepares for.
  final List<OpponentReply> replies;

  /// Everything the book returned, up to a dozen. This is the list a student
  /// reads when they are choosing: four prepared answers do not tell them
  /// whether something better was available.
  final List<OpponentReply> all;
  final double coveredShare;
  final int tailMoves;
  final double tailShare;
  final int? minRating;

  bool get isEmpty => total == 0;

  factory OpponentReplies.fromJson(Map<String, dynamic> json) {
    final tail = json['tail'] is Map
        ? Map<String, dynamic>.from(json['tail'] as Map)
        : const <String, dynamic>{};
    return OpponentReplies(
      total: (json['total'] as num?)?.toInt() ?? 0,
      replies: ((json['replies'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OpponentReply.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      all: ((json['all'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OpponentReply.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      coveredShare: (json['coveredShare'] as num?)?.toDouble() ?? 0,
      tailMoves: (tail['moves'] as num?)?.toInt() ?? 0,
      tailShare: (tail['share'] as num?)?.toDouble() ?? 0,
      minRating: (json['minRating'] as num?)?.toInt(),
    );
  }
}

/// A reply lookup that either answered or said why not, in the same shape a
/// verdict uses.
class OpponentRepliesLookup {
  const OpponentRepliesLookup.ok(this.replies)
      : status = OpeningJudgeStatus.ok,
        reason = null;

  const OpponentRepliesLookup.unavailable(this.reason)
      : status = OpeningJudgeStatus.unavailable,
        replies = null;

  final OpeningJudgeStatus status;
  final OpponentReplies? replies;
  final String? reason;

  bool get isAvailable => status == OpeningJudgeStatus.ok;
}

enum OpeningJudgeStatus { ok, unavailable }

class OpeningJudgeLookup {
  const OpeningJudgeLookup.ok(this.judgement)
      : status = OpeningJudgeStatus.ok,
        reason = null;

  const OpeningJudgeLookup.unavailable(this.reason)
      : status = OpeningJudgeStatus.unavailable,
        judgement = null;

  final OpeningJudgeStatus status;
  final OpeningJudgement? judgement;

  /// Why there is no verdict, in the server's own words: `no-token`,
  /// `unauthorized`, `rate-limited`, `network`, `bad-request` — or `guest`,
  /// which never leaves the app. The panel says a different sentence for each,
  /// because "we could not ask" and "the move is fine" must never look alike.
  final String? reason;

  bool get isAvailable => status == OpeningJudgeStatus.ok;
}

/// Asks the server what one move is worth: theory, playable, or a mistake.
///
/// **This spends the user's own Lichess token, and only theirs.** Judging one
/// move costs up to four questions upstream, and the token the server keeps for
/// the opening book is a single allowance shared by everyone in the app —
/// spending it here would take the book away from all of them the first time
/// somebody walked a long variation. So the gate is here as well as on the
/// route: with no personal token, nothing is sent at all and the panel says why
/// and where to fix it.
///
/// The verdict itself is computed on the server and never here. An engine on a
/// phone answers from whatever depth it happened to reach, so the same move
/// could be playable today and a mistake tomorrow on a slower device.
class OpeningJudgeService {
  OpeningJudgeService._({http.Client? client}) : _client = client;

  static final OpeningJudgeService instance = OpeningJudgeService._();

  /// A judge with a stubbed transport, for tests.
  @visibleForTesting
  factory OpeningJudgeService.withClient(http.Client client) =>
      OpeningJudgeService._(client: client);

  final http.Client? _client;

  final Map<String, OpeningJudgeLookup> _cache = {};
  final Map<String, OpponentRepliesLookup> _repliesCache = {};

  static String get _personalToken =>
      AppSettingsService.instance.lichessApiToken.trim();

  /// Whether the user has a token of their own, which is the whole condition
  /// for this feature being offered at all.
  bool get hasPersonalToken => _personalToken.isNotEmpty;

  Future<OpeningJudgeLookup> judge(
    String fen,
    String move, {
    int? minRating,
  }) async {
    if (!hasPersonalToken) {
      // Not sent, not logged as a failure: this is a setting, not a fault.
      return const OpeningJudgeLookup.unavailable('no-token');
    }

    final cacheKey = '$fen|$move|${minRating ?? 'all'}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final session = SessionService.instance.current;
    if (session.token.isEmpty) {
      return const OpeningJudgeLookup.unavailable('guest');
    }

    final uri =
        Uri.parse('$backendUrl/opening-judge').replace(queryParameters: {
      'fen': fen,
      'move': move,
      if (minRating != null) 'minRating': '$minRating',
    });

    try {
      // The Lichess token goes in a header and never in the query string: a URL
      // is the one part of a request that gets written down by everything it
      // passes through.
      final res = await _get(uri, {
        'Authorization': 'Bearer ${session.token}',
        'X-Lichess-Token': _personalToken,
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        final reason = _reasonOf(res.body) ?? 'http-${res.statusCode}';
        AppLogger.log('[Sudija] ⚠️ ${res.statusCode} ($reason) | $move');
        return OpeningJudgeLookup.unavailable(reason);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final judgement = OpeningJudgement.fromJson(data);
      AppLogger.log('[Sudija] ✅ ${judgement.san}: ${judgement.verdict.name}');
      final lookup = OpeningJudgeLookup.ok(judgement);
      // Only an answer is remembered. Caching a bad minute would go on
      // refusing for the rest of the session.
      _cache[cacheKey] = lookup;
      return lookup;
    } catch (e) {
      AppLogger.log('[Sudija] ❌ Backend nedostupan: $e');
      return const OpeningJudgeLookup.unavailable('network');
    }
  }

  /// Which of the opponent's answers are worth preparing for here.
  ///
  /// The other half of building a repertoire, and the same gate as judging: it
  /// reads the opening book, so it spends the reader's own allowance. The
  /// server decides how many replies that is — the rule is one number in one
  /// place, not a slider each screen sets differently.
  Future<OpponentRepliesLookup> replies(String fen, {int? minRating}) async {
    if (!hasPersonalToken) {
      return const OpponentRepliesLookup.unavailable('no-token');
    }

    final cacheKey = 'replies|$fen|${minRating ?? 'all'}';
    final cached = _repliesCache[cacheKey];
    if (cached != null) return cached;

    final session = SessionService.instance.current;
    if (session.token.isEmpty) {
      return const OpponentRepliesLookup.unavailable('guest');
    }

    final uri = Uri.parse('$backendUrl/opening-judge/replies')
        .replace(queryParameters: {
      'fen': fen,
      if (minRating != null) 'minRating': '$minRating',
    });

    try {
      final res = await _get(uri, {
        'Authorization': 'Bearer ${session.token}',
        'X-Lichess-Token': _personalToken,
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        final reason = _reasonOf(res.body) ?? 'http-${res.statusCode}';
        AppLogger.log('[Sudija] ⚠️ odgovori ${res.statusCode} ($reason)');
        return OpponentRepliesLookup.unavailable(reason);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final replies = OpponentReplies.fromJson(data);
      AppLogger.log('[Sudija] ✅ ${replies.replies.length} odgovora, '
          'pokriveno ${(replies.coveredShare * 100).round()}%');
      final lookup = OpponentRepliesLookup.ok(replies);
      _repliesCache[cacheKey] = lookup;
      return lookup;
    } catch (e) {
      AppLogger.log('[Sudija] ❌ odgovori nedostupni: $e');
      return const OpponentRepliesLookup.unavailable('network');
    }
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) =>
      _client?.get(uri, headers: headers) ?? http.get(uri, headers: headers);

  String? _reasonOf(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['reason'] is String) {
        return decoded['reason'] as String;
      }
    } catch (_) {
      // A body that is not JSON says nothing about why, and pretending
      // otherwise would put a made-up reason in the log.
    }
    return null;
  }

  @visibleForTesting
  void clearCache() {
    _cache.clear();
    _repliesCache.clear();
  }
}
