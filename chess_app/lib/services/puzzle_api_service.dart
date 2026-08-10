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
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Server unreachable. Falling back to local offline puzzle DB: $e');
    }

    // Offline fallback for mate puzzles
    final int depth = int.tryParse(mateDepth) ?? 2;
    return await LocalPuzzleService.instance.getRandomPuzzle(
      mateIn: depth,
      excludeId: excludeId,
    );
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
          .timeout(const Duration(seconds: 10));

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
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Error submitting puzzle result: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> verifyStockfishMove({
    required String fen,
    required String userMove,
    String? mode,
    int? remainingNeeded,
    String? orientation,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/api/puzzles/verify'),
            headers: _headers(),
            body: jsonEncode({
              'fen': fen,
              'userMove': userMove,
              'mode': mode,
              'remainingNeeded': remainingNeeded,
              'orientation': orientation,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Error verifying Stockfish move: $e');
    }
    return {
      'success': false,
      'status': 'REJECTED',
      'reason': 'Greška na mrežnoj konekciji pri verifikaciji.',
    };
  }

  Future<void> sendLogDetails(Map<String, dynamic> details) async {
    try {
      await http
          .post(
            Uri.parse('$backendUrl/api/puzzles/log'),
            headers: _headers(),
            body: jsonEncode({'details': details}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> explainPosition({
    required String fen,
    required Map<String, dynamic> evals,
    String userLanguage = 'sr',
    required String userToken,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/api/ai/explain-position'),
            headers: _headers(userToken),
            body: jsonEncode({
              'fen': fen,
              'evals': evals,
              'userLanguage': userLanguage,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PUZZLE_API_SERVICE] Error explaining position: $e');
    }
    return null;
  }
}
