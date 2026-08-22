import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import '../models/endgame_puzzle.dart';

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
}
