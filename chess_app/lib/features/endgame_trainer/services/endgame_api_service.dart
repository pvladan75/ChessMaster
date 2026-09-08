import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/services/app_logger.dart';
import '../models/blunder_game.dart';
import '../models/endgame_catalog.dart';
import '../models/drill_step.dart';
import '../models/endgame_puzzle.dart';
import '../models/tablebase_readout.dart';

export '../models/blunder_game.dart';
export '../models/endgame_catalog.dart';
export '../models/drill_step.dart';
export '../models/tablebase_readout.dart';

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

class GameFetchResult {
  const GameFetchResult(this.outcome, [this.game]);

  final EndgameFetchOutcome outcome;
  final BlunderGame? game;
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
    String? material,
    String? band,
    bool oppositeOnly = false,
    bool includeOnline = false,
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
        // Absent means "any", so a full selection sends nothing rather than a
        // list of every key there is.
        if (material != null && material.isNotEmpty) 'material': material,
        if (band != null && band.isNotEmpty) 'band': band,
        if (oppositeOnly) 'oppositeBishops': 'true',
        // Sent only when asked for. Absent means over-the-board and the master
        // bases, which is what the trainer serves unless somebody says
        // otherwise.
        if (includeOnline) 'includeOnline': 'true',
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
            '[Endgames] Server rejected request (${res.statusCode}).');
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
        AppLogger.log('[Endgames] Position ${puzzle.id} has no moves.');
        return const EndgameFetchResult(EndgameFetchOutcome.unavailable);
      }
      return EndgameFetchResult(EndgameFetchOutcome.ok, puzzle);
    } catch (e) {
      AppLogger.log('[Endgames] Error fetching: $e');
      return const EndgameFetchResult(EndgameFetchOutcome.unavailable);
    }
  }

  /// What there is to practise, counted.
  ///
  /// One request per visit to the picker: the counts come split by rating band,
  /// so every combination of endings and levels is added up on the device
  /// rather than asked for.
  Future<EndgameCatalog?> fetchCatalog({EndgameMode? mode}) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/catalog').replace(
      queryParameters: {if (mode != null) 'mode': mode.name},
    );

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        AppLogger.log('[Endgames] Catalog did not arrive (${res.statusCode}).');
        return null;
      }
      return EndgameCatalog.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Endgames] Error fetching catalog: $e');
      return null;
    }
  }

  /// Fetches one game to walk through.
  ///
  /// The same outcome split as [fetchNext], and for the same reason: a filter
  /// that matches nothing is a fact about the filter, while an unreachable
  /// server might pass. Saying both as one error taught the user to retry
  /// something that could never work.
  Future<GameFetchResult> fetchNextGame({
    int? minBlunders,
    int? maxBlunders,
    int? minElo,
    int? maxElo,
    String? material,
    String? excludeId,
    bool includeOnline = false,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/game/next').replace(
      queryParameters: {
        if (minBlunders != null) 'minBlunders': '$minBlunders',
        if (maxBlunders != null) 'maxBlunders': '$maxBlunders',
        if (minElo != null) 'minElo': '$minElo',
        if (maxElo != null) 'maxElo': '$maxElo',
        if (material != null && material.isNotEmpty) 'material': material,
        if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
        if (includeOnline) 'includeOnline': 'true',
      },
    );

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 404) {
        return const GameFetchResult(EndgameFetchOutcome.noneMatch);
      }
      if (res.statusCode != 200) {
        AppLogger.log('[Endgames] Server rejected game (${res.statusCode}).');
        return const GameFetchResult(EndgameFetchOutcome.unavailable);
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['game'];
      if (data is! Map<String, dynamic>) {
        return const GameFetchResult(EndgameFetchOutcome.unavailable);
      }

      final game = BlunderGame.fromJson(data);
      if (!game.isPlayable) {
        // A game with no mistakes in it has nothing to stop at, and one with no
        // moves has nothing to walk. Either means something upstream changed.
        AppLogger.log('[Endgames] Game ${game.id} has nothing to walk.');
        return const GameFetchResult(EndgameFetchOutcome.unavailable);
      }
      return GameFetchResult(EndgameFetchOutcome.ok, game);
    } catch (e) {
      AppLogger.log('[Endgames] Error fetching game: $e');
      return const GameFetchResult(EndgameFetchOutcome.unavailable);
    }
  }

  /// The tag every position kept for later carries.
  ///
  /// One tag rather than a choice of several: the point is that the click is
  /// quick, and a menu at that moment is a question nobody asked. It is what
  /// makes the list findable afterwards - "Moje pozicije" filtered to this is
  /// everything that was left unexplained, rather than mixed in with the rest.
  static const unclearTag = 'Unclear';

  /// Keeps a position in the trainer's own library, to be looked at later.
  ///
  /// It goes to the shelf that already exists rather than to a table of its
  /// own: a kept position is an ordinary saved position, so "Moje pozicije"
  /// lists it, Analysis Studio opens it, and a lesson or a homework can take it
  /// without any of that being built for this.
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async {
    // Through `LessonApiService`, not `http`. Every write to `saved_lessons`
    // goes through one place since phase 7a — the rule a `positionList` is read
    // under is not something a second caller should have to know about.
    final error = await LessonApiService(authToken: authToken).save(
      title: title,
      description: description,
      fen: fen,
      tags: const [unclearTag],
    );
    if (error == null) return true;
    AppLogger.log('[Endgames] Position was not saved: $error');
    return false;
  }

  /// Best play for both sides from a position, as a line of moves.
  ///
  /// What makes a bad move bad is that there is a way to punish it, and this is
  /// that way. Asked for after the answer is known, so it gives nothing away.
  Future<List<String>?> fetchBestLine({
    required String fen,
    int plies = 10,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/line').replace(
      queryParameters: {'fen': fen, 'plies': '$plies'},
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        AppLogger.log('[Endgames] Line did not arrive (${res.statusCode}).');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ((body['moves'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
    } catch (e) {
      AppLogger.log('[Endgames] Error calculating line: $e');
      return null;
    }
  }

  /// What the tables say about the position in front of the reader.
  ///
  /// Asked for by hand, in a drill that will not come out. Deliberately the
  /// whole finding and not one recommended move: which moves hold, which lose,
  /// how far each is from the next capture or pawn move. A reader who is stuck
  /// learns more from seeing that three moves hold and only one makes progress
  /// than from being handed the one.
  Future<TablebaseReadout?> fetchReadout({
    required String fen,
    required EndgameMode goal,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/probe').replace(
      queryParameters: {'fen': fen, 'goal': goal.name},
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        AppLogger.log('[Endgames] Readout did not arrive (${res.statusCode}).');
        return null;
      }
      return TablebaseReadout.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Endgames] Error reading tablebases: $e');
      return null;
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
      AppLogger.log('[Endgames] Move was not judged (${res.statusCode}).');
      return DrillJudgeResult(outcome, message: message);
    } catch (e) {
      AppLogger.log('[Endgames] Error judging move: $e');
      return const DrillJudgeResult(DrillJudgeOutcome.unavailable);
    }
  }
}
