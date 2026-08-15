import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import '../models/tactics_puzzle.dart';

/// A user's standing on one tactical motif.
class ThemeRating {
  final String theme;
  final int? rating;
  final int attempts;

  /// False while the theme has too few attempts to mean anything — an unknown,
  /// not a weakness.
  final bool measured;

  const ThemeRating({
    required this.theme,
    required this.rating,
    required this.attempts,
    required this.measured,
  });

  factory ThemeRating.fromJson(Map<String, dynamic> json) => ThemeRating(
        theme: json['theme']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toInt(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        measured: json['measured'] == true,
      );
}

/// What the selector aimed at, so the UI can say why this puzzle appeared.
class PuzzleSelection {
  final String? targetTheme;
  final int targetRating;

  const PuzzleSelection({this.targetTheme, required this.targetRating});

  factory PuzzleSelection.fromJson(Map<String, dynamic> json) => PuzzleSelection(
        targetTheme: json['targetTheme']?.toString(),
        targetRating: (json['targetRating'] as num?)?.toInt() ?? 1500,
      );
}

class AdaptivePuzzleResponse {
  final TacticsPuzzle puzzle;
  final PuzzleSelection selection;

  const AdaptivePuzzleResponse({required this.puzzle, required this.selection});
}

class AttemptResult {
  final int newRating;
  final int ratingChange;
  final int puzzleRating;
  final int puzzlesSolved;

  const AttemptResult({
    required this.newRating,
    required this.ratingChange,
    required this.puzzleRating,
    required this.puzzlesSolved,
  });

  factory AttemptResult.fromJson(Map<String, dynamic> json) => AttemptResult(
        newRating: (json['newRating'] as num?)?.toInt() ?? 1500,
        ratingChange: (json['ratingChange'] as num?)?.toInt() ?? 0,
        puzzleRating: (json['puzzleRating'] as num?)?.toInt() ?? 1500,
        puzzlesSolved: (json['puzzlesSolved'] as num?)?.toInt() ?? 0,
      );
}

/// Talks to the adaptive puzzle endpoints.
///
/// Note what is *not* sent when reporting an attempt: the puzzle's difficulty.
/// The server reads that from its own table, so a client cannot inflate a rating
/// by claiming it solved something hard.
class TacticsApiService {
  TacticsApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Future<AdaptivePuzzleResponse?> fetchAdaptivePuzzle({
    String? theme,
    String? phase,
    String? excludeId,
  }) async {
    final uri = Uri.parse('$backendUrl/api/puzzles/adaptive').replace(
      queryParameters: {
        if (theme != null && theme.isNotEmpty) 'theme': theme,
        if (phase != null && phase.isNotEmpty) 'phase': phase,
        if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
      },
    );

    try {
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        AppLogger.log('[Tactics] Server je odbio zahtev (${res.statusCode}).');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AdaptivePuzzleResponse(
        puzzle: TacticsPuzzle.fromJson(Map<String, dynamic>.from(data['puzzle'])),
        selection: PuzzleSelection.fromJson(
          Map<String, dynamic>.from(data['selection'] ?? const {}),
        ),
      );
    } catch (e) {
      AppLogger.log('[Tactics] Ne mogu da preuzmem zagonetku: $e');
      return null;
    }
  }

  /// Fetches one named puzzle — how assigned homework is served, so the student
  /// gets exactly what the trainer set rather than what the selector would pick.
  Future<TacticsPuzzle?> fetchPuzzleById(String puzzleId) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/puzzles/by-id/$puzzleId'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return TacticsPuzzle.fromJson(Map<String, dynamic>.from(data['puzzle']));
    } catch (e) {
      AppLogger.log('[Tactics] Ne mogu da preuzmem zadatu zagonetku: $e');
      return null;
    }
  }

  Future<AttemptResult?> submitAttempt({
    required String puzzleId,
    required bool solved,
    int? msTaken,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/api/puzzles/attempt'),
            headers: _headers,
            body: jsonEncode({
              'puzzleId': puzzleId,
              'solved': solved,
              if (msTaken != null) 'msTaken': msTaken,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;
      return AttemptResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Tactics] Ne mogu da pošaljem rezultat: $e');
      return null;
    }
  }

  Future<List<ThemeRating>> fetchThemeRatings() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/puzzles/themes'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['themes'] as List?) ?? const [])
          .map((e) => ThemeRating.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.log('[Tactics] Ne mogu da učitam rejtinge po temama: $e');
      return const [];
    }
  }
}
