import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import '../models/drill_step.dart';
import '../models/endgame_puzzle.dart';

export '../models/drill_step.dart';

/// Why the request came back empty.
///
/// A screen asking for a drawn rook ending with at most five pieces can
/// legitimately find nothing, and that is not the same as the server being
/// unreachable. The old endpoint blurred the two by quietly handing back any
/// position at all when the filters matched none; this keeps them apart so the
/// screen can say which happened.
enum EndgameFetchOutcome { ok, noneMatch, unavailable }

class EndgameFetchResult {
  final EndgameFetchOutcome outcome;
  final EndgamePuzzle? puzzle;

  const EndgameFetchResult(this.outcome, [this.puzzle]);

  bool get hasPuzzle => puzzle != null && puzzle!.isPlayable;
}

/// Why a judged move came back without a verdict.
///
/// `unavailable` is the tablebase being unreachable, and it is deliberately not
/// smoothed over: the drill's whole promise is that "that move let the win go"
/// is a fact, so when the fact cannot be had the drill says so instead of
/// falling back on an estimate. `refused` is the position or the move being
/// something the server will not judge at all, which retrying will not fix.
enum DrillJudgeOutcome { ok, unavailable, refused }

class DrillJudgeResult {
  const DrillJudgeResult(this.outcome, {this.step, this.message});

  final DrillJudgeOutcome outcome;
  final DrillStep? step;

  /// What the server said, when it refused or could not answer. Shown as is:
  /// the server knows why better than a generic sentence here would.
  final String? message;
}

/// Talks to the endgame endpoint.
class EndgameApiService {
  EndgameApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  /// Fetches one position.
  ///
  /// [maxPieces] and [minPawns] look alike and are not interchangeable. A
  /// play-it-out drill sets [maxPieces] to 5 because that is how far the
  /// tablebases reach, so every move can be judged exactly; a pawn-ending
  /// lesson sets [minPawns] because there the structure is the subject and
  /// few pieces would be the wrong thing to ask for.
  Future<EndgameFetchResult> fetchNext({
    String? type,
    EndgameMode? mode,
    String? difficulty,
    int? maxPieces,
    int? minPawns,
    String? excludeId,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/next').replace(
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (mode != null) 'mode': mode.name,
        if (difficulty != null && difficulty.isNotEmpty)
          'difficulty': difficulty,
        if (maxPieces != null) 'maxPieces': '$maxPieces',
        if (minPawns != null) 'minPawns': '$minPawns',
        if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
      },
    );

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 404) {
        return const EndgameFetchResult(EndgameFetchOutcome.noneMatch);
      }
      if (res.statusCode != 200) {
        AppLogger.log(
            '[Zavrsnice] Server je odbio zahtev (${res.statusCode}).');
        return const EndgameFetchResult(EndgameFetchOutcome.unavailable);
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['endgame'];
      if (data is! Map<String, dynamic>) {
        return const EndgameFetchResult(EndgameFetchOutcome.unavailable);
      }

      final puzzle = EndgamePuzzle.fromJson(data);
      if (!puzzle.isPlayable) {
        // A position with no accepted move is unsolvable by construction. The
        // route filters these out, so reaching here means something upstream
        // changed; say so rather than putting a board with no answer in front
        // of a child.
        AppLogger.log('[Zavrsnice] Pozicija ${puzzle.id} nema nijedan potez.');
        return const EndgameFetchResult(EndgameFetchOutcome.unavailable);
      }
      return EndgameFetchResult(EndgameFetchOutcome.ok, puzzle);
    } catch (e) {
      AppLogger.log('[Zavrsnice] Greška pri dobavljanju: $e');
      return const EndgameFetchResult(EndgameFetchOutcome.unavailable);
    }
  }

  /// Has the server judge one move of a play-it-out drill.
  ///
  /// The verdict is not worked out here even though the answer is a public
  /// lookup away. A result that arrives from a client is one the server cannot
  /// tell apart from any other POST, and the ordinary case is not a child
  /// cheating but an old build still installed. It also costs nothing to do it
  /// there, since the tables have to be asked to answer the child at all.
  Future<DrillJudgeResult> judgeDrillMove({
    required String fen,
    required String move,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/play');

    try {
      final res = await http
          .post(uri,
              headers: _headers, body: jsonEncode({'fen': fen, 'move': move}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return DrillJudgeResult(
          DrillJudgeOutcome.ok,
          step:
              DrillStep.fromJson(jsonDecode(res.body) as Map<String, dynamic>),
        );
      }

      String? message;
      try {
        message =
            (jsonDecode(res.body) as Map<String, dynamic>)['error']?.toString();
      } catch (_) {
        message = null;
      }

      // 503 is the tablebase, not the server: worth telling apart, because one
      // is worth retrying in a minute and the other is not.
      final outcome = res.statusCode == 503
          ? DrillJudgeOutcome.unavailable
          : DrillJudgeOutcome.refused;
      AppLogger.log('[Zavrsnice] Potez nije presuđen (${res.statusCode}).');
      return DrillJudgeResult(outcome, message: message);
    } catch (e) {
      AppLogger.log('[Zavrsnice] Greška pri suđenju poteza: $e');
      return const DrillJudgeResult(DrillJudgeOutcome.unavailable);
    }
  }
}
