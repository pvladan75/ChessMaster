import 'package:chess_app/services/local_puzzle_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';

class PuzzleApiService {
  static final PuzzleApiService instance = PuzzleApiService._internal();

  PuzzleApiService._internal();

  Map<String, String> _headers([String? token]) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> checkServerHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchNextPuzzle({
    required String type,
    required String mateDepth,
    String? excludeId,
    required String userToken,
  }) async {
    final puzzleType = (type == 'winning' || type == 'winning_position')
        ? 'winning_position'
        : 'mate_puzzle';
    final queryParams = {
      'type': puzzleType,
      if (puzzleType == 'mate_puzzle' && mateDepth.isNotEmpty)
        'mate_depth': mateDepth,
      if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
    };

    final uri = Uri.parse('$backendUrl/api/puzzles/next')
        .replace(queryParameters: queryParams);

    try {
      final res = await http
          .get(uri, headers: _headers(userToken))
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print(
          '[PUZZLE_API_SERVICE] Server unreachable. Falling back to local offline puzzle DB: $e');
    }

    // Offline fallback for mate and winning position puzzles
    if (puzzleType == 'winning_position') {
      return await LocalPuzzleService.instance.getWinningPositionPuzzle(
        excludeId: excludeId,
      );
    } else {
      final int depth = int.tryParse(mateDepth) ?? 2;
      return await LocalPuzzleService.instance.getRandomPuzzle(
        mateIn: depth,
        excludeId: excludeId,
      );
    }
  }

  /// Serves one named puzzle, in the same shape as [fetchNextPuzzle] — how a
  /// retry queue is walked (docs/PLAN-NAPREDAK-VEZBI.md §4): `source` says
  /// which table the id belongs to.
  Future<Map<String, dynamic>?> fetchPuzzleById({
    required String id,
    required String source,
    required String userToken,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/by-id/$id')
        .replace(queryParameters: {'source': source});
    try {
      final res = await http
          .get(uri, headers: _headers(userToken))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Error fetching puzzle by id: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchNextEndgamePuzzle({
    required String difficulty,
    String? excludeId,
    required String userToken,
  }) async {
    final queryParams = {
      'difficulty': difficulty,
      if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
    };

    final uri = Uri.parse('$backendUrl/api/puzzles/endgame/next')
        .replace(queryParameters: queryParams);

    try {
      final res = await http
          .get(uri, headers: _headers(userToken))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Error fetching endgame puzzle: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> submitPuzzleResult({
    required String puzzleId,
    required bool solved,
    String? theme,
    required String userToken,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/api/puzzles/submit'),
            headers: _headers(userToken),
            body: jsonEncode({
              'puzzleId': puzzleId,
              'solved': solved,
              if (theme != null) 'theme': theme,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Error submitting puzzle result: $e');
    }
    return null;
  }
}
