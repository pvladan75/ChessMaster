/// A game's positions walked through the server's masters database — phase 2
/// of `docs/PLAN-SKELET.md`, decision D5.
///
/// The server answers from a local SQLite file built from over-the-board games
/// in which both players are rated 2200+ (`POST /opening-explorer/masters-walk`),
/// in the explorer's shape the builder's `applyMastersBook` reads. This file
/// adds the one thing that database does not hold, **the opening's name**, from
/// the ECO data the app already ships: on the thirteen harness games it gave
/// back all 52 of the Lichess masters explorer's names, word for word, and named
/// no position Lichess does not.
///
/// **A refusal is a reason, never an exception.** A tutorial made without the
/// masters statistics is still a whole tutorial; one that fails because the
/// server has no database file is not one at all. The reason is kept so the
/// caller can say which it was.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

/// The database holds the first 50 plies of every game, so the position after
/// the fiftieth is the last one it can know anything about. It was 30 until
/// the book was rebuilt on 15.9.2026 (`docs/PLAN-OTVARANJA-LOKALNO.md`); the
/// server refuses a walk longer than 64 positions, so 51 still fits.
const int kMastersBookPlies = 50;

/// What the walk found — by position, in the explorer's shape — and, when it
/// found nothing because it could not ask, why.
typedef MastersWalk = ({
  Map<String, Map<String, dynamic>> known,
  String? unavailable,
});

Future<MastersWalk> walkMastersBook(
  List<String> fens, {
  http.Client? client,
  String? baseUrl,
  String? sessionToken,
  String? Function(String fen)? openingNameOf,
}) async {
  final token = sessionToken ?? SessionService.instance.current.token;
  if (token.isEmpty) {
    return (
      known: const <String, Map<String, dynamic>>{},
      unavailable: 'guest'
    );
  }
  final asked = fens.take(kMastersBookPlies + 1).toList();
  if (asked.isEmpty) {
    return (known: const <String, Map<String, dynamic>>{}, unavailable: null);
  }

  final http.Client c = client ?? http.Client();
  try {
    final res = await c
        .post(
          Uri.parse('${baseUrl ?? backendUrl}/opening-explorer/masters-walk'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'fens': asked}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      final reason = _reasonOf(res.body) ?? 'http-${res.statusCode}';
      AppLogger.log('[MastersWalk] ⚠️ ${res.statusCode} ($reason)');
      return (
        known: const <String, Map<String, dynamic>>{},
        unavailable: reason
      );
    }

    final data = jsonDecode(res.body);
    if (data is! Map || data['positions'] is! List) {
      throw const FormatException('no positions in the answer');
    }
    final known = <String, Map<String, dynamic>>{};
    for (final raw in data['positions'] as List) {
      final position = Map<String, dynamic>.from(raw as Map);
      final fen = position.remove('fen') as String;
      final name = openingNameOf?.call(fen);
      if (name != null && name.isNotEmpty) position['opening'] = {'name': name};
      known[fen] = position;
    }
    return (known: known, unavailable: null);
  } on FormatException catch (e) {
    AppLogger.log('[MastersWalk] ❌ Neispravan odgovor: $e');
    return (
      known: const <String, Map<String, dynamic>>{},
      unavailable: 'bad-answer'
    );
  } catch (e) {
    AppLogger.log('[MastersWalk] ❌ Server nedostupan: $e');
    return (
      known: const <String, Map<String, dynamic>>{},
      unavailable: 'network'
    );
  } finally {
    if (client == null) c.close();
  }
}

String? _reasonOf(String body) {
  try {
    final data = jsonDecode(body);
    return data is Map ? data['reason'] as String? : null;
  } catch (_) {
    return null;
  }
}

/// Opening names from the app's own ECO data, for [walkMastersBook].
Future<String? Function(String fen)> ecoOpeningNames() async {
  await OpeningBookService.instance.ensureLoaded();
  return (fen) => OpeningBookService.instance.lookupByFen(fen)?.name;
}
