import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

/// One move the student decided to play in a position.
class RepertoireMove {
  const RepertoireMove({
    required this.uci,
    required this.san,
    required this.role,
    this.verdict,
  });

  final String uci;
  final String san;

  /// `primary` or `alternate`. One primary per position, held by the database:
  /// three equal answers cannot be drilled, because everything is correct and
  /// nothing is ever learned past having to stop and think.
  final String role;

  /// What the judge said when the move was kept, if it was judged.
  final String? verdict;

  bool get isPrimary => role == 'primary';

  factory RepertoireMove.fromJson(Map<String, dynamic> json) => RepertoireMove(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        role: json['role'] as String? ?? 'alternate',
        verdict: json['verdict'] as String?,
      );
}

/// A repertoire, which is a *name for a starting position* rather than a box.
///
/// The moves belong to (user, colour), so two repertoires for Black share every
/// position they both reach — which is the whole point: work done deep in the
/// Smith-Morra is already part of a later, broader repertoire against 1.e4 the
/// moment it reaches the same board.
class RepertoireSummary {
  const RepertoireSummary({
    required this.id,
    required this.name,
    required this.color,
    required this.rootFen,
    required this.moves,
  });

  final int id;
  final String name;

  /// 'w' or 'b' — the side this repertoire is built for.
  final String color;
  final String rootFen;

  /// How many moves the whole graph for this colour holds. Honest rather than
  /// flattering: two doors into one graph show the same number.
  final int moves;

  bool get forWhite => color == 'w';

  factory RepertoireSummary.fromJson(Map<String, dynamic> json) =>
      RepertoireSummary(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'w',
        rootFen:
            json['rootFen'] as String? ?? json['root_fen'] as String? ?? '',
        moves: (json['moves'] as num?)?.toInt() ?? 0,
      );
}

/// One question the drill is about to ask.
class DrillItem {
  const DrillItem({
    required this.fen,
    required this.fresh,
    required this.repetitions,
    required this.moves,
  });

  /// The full position, six fields — the repertoire keeps four, and the server
  /// fills the counters back in so any board can load it.
  final String fen;

  /// True the first time a position is drilled at all.
  final bool fresh;
  final int repetitions;

  /// How many moves the student kept here. The moves themselves deliberately do
  /// not travel with the question.
  final int moves;

  factory DrillItem.fromJson(Map<String, dynamic> json) => DrillItem(
        fen: json['fen'] as String? ?? '',
        fresh: json['fresh'] as bool? ?? true,
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        moves: (json['moves'] as num?)?.toInt() ?? 0,
      );
}

/// How much is waiting, and whether there is anything at all.
class DrillStats {
  const DrillStats({
    required this.positions,
    required this.due,
    required this.known,
    required this.fresh,
  });

  final int positions;
  final int due;
  final int known;

  /// Never drilled. "Nothing is due" and "nothing was ever built" are different
  /// empty states, and only one of them is good news.
  final int fresh;

  factory DrillStats.fromJson(Map<String, dynamic> json) => DrillStats(
        positions: (json['positions'] as num?)?.toInt() ?? 0,
        due: (json['due'] as num?)?.toInt() ?? 0,
        known: (json['known'] as num?)?.toInt() ?? 0,
        fresh: (json['fresh'] as num?)?.toInt() ?? 0,
      );
}

/// What the drill made of one answer.
class DrillAnswer {
  const DrillAnswer({
    required this.outcome,
    this.primary,
    this.alternates = const [],
    this.intervalDays,
    this.reply,
    this.replyCovered = true,
  });

  /// `primary`, `alternate`, `unknown` — or `unprepared`, which is not a mark
  /// at all: it means the position was never built, so there was nothing to be
  /// right or wrong about.
  final String outcome;

  final RepertoireMove? primary;
  final List<RepertoireMove> alternates;

  /// When the position comes back, in days. Zero means "in a few minutes".
  final int? intervalDays;

  /// What the opponent plays next, drawn by how often it is really played —
  /// out of the book stored while the position was built, so a drill costs no
  /// Lichess request.
  final String? reply;

  /// False when the opponent has just played something the student never
  /// prepared for. Not a fault: it is the drill doing the one thing a book
  /// cannot, which is showing them the edge of what they covered.
  final bool replyCovered;

  bool get isPrepared => outcome != 'unprepared';

  static RepertoireMove? _move(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return RepertoireMove(
      uci: map['uci'] as String? ?? '',
      san: map['san'] as String? ?? '',
      role: 'primary',
    );
  }

  factory DrillAnswer.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'] is Map
        ? Map<String, dynamic>.from(json['reply'] as Map)
        : null;
    return DrillAnswer(
      outcome: json['outcome'] as String? ?? 'unknown',
      primary: _move(json['primary']),
      alternates: ((json['alternates'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RepertoireMove(
                uci: (e['uci'] as String?) ?? '',
                san: (e['san'] as String?) ?? '',
                role: 'alternate',
              ))
          .toList(),
      intervalDays: (json['intervalDays'] as num?)?.toInt(),
      reply: reply?['uci'] as String?,
      replyCovered: reply?['covered'] as bool? ?? true,
    );
  }
}

/// The student's own decisions, on our own server.
///
/// Nothing here talks to Lichess, and that is worth keeping straight: the judge
/// spends the reader's allowance to say what a move is worth, while this only
/// records what they decided about it. A repertoire built last week can be
/// read, edited and drilled with no allowance spent at all.
class RepertoireApiService {
  RepertoireApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SessionService.instance.current.token}',
        'Content-Type': 'application/json',
      };

  Future<List<RepertoireSummary>> list() async {
    final res =
        (await _send(() => _get(Uri.parse('$backendUrl/repertoire')))).res;
    if (res == null) return const [];
    final data = jsonDecode(res.body);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => RepertoireSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Makes a repertoire, or says why it could not.
  Future<({RepertoireSummary? made, String? error})> create({
    required String name,
    required String color,
    required String rootFen,
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire', {
          'name': name,
          'color': color,
          'rootFen': rootFen,
        }));
    final res = sent.res;
    if (res == null) return (made: null, error: sent.error);
    return (
      made: RepertoireSummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(res.body) as Map)),
      error: null,
    );
  }

  /// What the student already plays in this position, primary first.
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/node')
        .replace(queryParameters: {'color': color, 'fen': fen});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['moves'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RepertoireMove.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<bool> keepMove({
    required String color,
    required String fen,
    required String uci,
    required String san,
    String? verdict,
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire/node/move', {
          'color': color,
          'fen': fen,
          'uci': uci,
          'san': san,
          'verdict': verdict,
        }));
    return sent.res != null;
  }

  Future<bool> makePrimary({
    required String color,
    required String fen,
    required String uci,
  }) async {
    final sent =
        await _send(() => _post('$backendUrl/repertoire/node/primary', {
              'color': color,
              'fen': fen,
              'uci': uci,
            }));
    return sent.res != null;
  }

  Future<bool> removeMove({
    required String color,
    required String fen,
    required String uci,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/node/move')
        .replace(queryParameters: {'color': color, 'fen': fen, 'uci': uci});
    return (await _send(() => _delete(uri))).res != null;
  }

  /// Writes down what the student reached for, kept or not.
  ///
  /// Deliberately fire-and-forget from the caller's point of view: this is a
  /// note for later, and a screen must not stop working because a note failed
  /// to save. It is still logged, so a systematic failure is visible.
  Future<void> recordAttempt({
    required String color,
    required String fen,
    required String uci,
    String? san,
    String? verdict,
    bool kept = false,
    bool lookedUp = false,
  }) async {
    await _send(() => _post('$backendUrl/repertoire/attempt', {
          'color': color,
          'fen': fen,
          'uci': uci,
          'san': san,
          'verdict': verdict,
          'kept': kept,
          'lookedUp': lookedUp,
        }));
  }

  /// The next position to be asked about, and how much is waiting.
  Future<({DrillItem? item, DrillStats stats})> nextDrill(
      {required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/drill/next')
        .replace(queryParameters: {'color': color});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) {
      return (
        item: null,
        stats: const DrillStats(positions: 0, due: 0, known: 0, fresh: 0)
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = data['item'];
    return (
      item: raw is Map
          ? DrillItem.fromJson(Map<String, dynamic>.from(raw))
          : null,
      stats: DrillStats.fromJson(
          Map<String, dynamic>.from((data['stats'] as Map?) ?? const {})),
    );
  }

  /// Asks to be shown the answer. Its own call, so looking is a decision the
  /// schedule gets to know about.
  Future<RepertoireMove?> revealDrill({
    required String color,
    required String fen,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/drill/reveal')
        .replace(queryParameters: {'color': color, 'fen': fen});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final primary = data['primary'];
    if (primary is! Map) return null;
    return RepertoireMove(
      uci: primary['uci'] as String? ?? '',
      san: primary['san'] as String? ?? '',
      role: 'primary',
    );
  }

  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    int? minRating,
  }) async {
    final res =
        (await _send(() => _post('$backendUrl/repertoire/drill/answer', {
                  'color': color,
                  'fen': fen,
                  'uci': uci,
                  'revealed': revealed,
                  if (minRating != null) 'minRating': minRating,
                })))
            .res;
    if (res == null) return null;
    return DrillAnswer.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  Future<http.Response> _get(Uri uri) =>
      _client?.get(uri, headers: _headers) ?? http.get(uri, headers: _headers);

  Future<http.Response> _delete(Uri uri) =>
      _client?.delete(uri, headers: _headers) ??
      http.delete(uri, headers: _headers);

  Future<http.Response> _post(String url, Map<String, dynamic> body) {
    final uri = Uri.parse(url);
    final encoded = jsonEncode(body);
    return _client?.post(uri, headers: _headers, body: encoded) ??
        http.post(uri, headers: _headers, body: encoded);
  }

  /// One place where a failed call becomes a reason, not merely a null.
  ///
  /// The reason is the point. "The name is taken", "the server is not running"
  /// and "that position is not valid" are three different things to whoever is
  /// looking at the screen: one they fix in the field in front of them, one
  /// they fix in a terminal, and one is not their fault at all. One sentence
  /// for all three is the same silent failure this project keeps meeting, one
  /// layer up — and it was on screen the first time somebody used this.
  Future<({http.Response? res, String? error})> _send(
      Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (res: res, error: null);
      }
      AppLogger.log('[Repertoar] ⚠️ ${res.statusCode}: ${res.body}');
      return (res: null, error: _errorOf(res));
    } catch (e) {
      AppLogger.log('[Repertoar] ❌ $e');
      return (
        res: null,
        error: 'Server nije dostupan — proverite da li backend radi.',
      );
    }
  }

  /// What the server said, in its own words where it had any.
  String _errorOf(http.Response res) {
    if (res.statusCode == 409) return 'Već imate repertoar sa tim imenom.';
    if (res.statusCode == 401 || res.statusCode == 403) {
      return 'Niste prijavljeni ili je prijava istekla.';
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // A body that is not JSON says nothing about why, and inventing a reason
      // here would be worse than admitting the status code.
    }
    if (res.statusCode >= 500) {
      return 'Greška na serveru (${res.statusCode}). Ako je baza tek dobila '
          'nove tabele, backend treba restartovati.';
    }
    return 'Server je odgovorio ${res.statusCode}.';
  }

  @visibleForTesting
  static RepertoireApiService withClient(http.Client client) =>
      RepertoireApiService(client: client);
}
