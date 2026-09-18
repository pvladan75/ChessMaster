// exercise_api_service.dart — the client for `/exercises`
// (`chess_backend/routes/exercises.js`, `docs/PLAN-EXERCISE.md` §7a).
//
// Same seam as `HomeworkApiService`: every request goes through one injected
// `http.Client`, so a test can answer it and assert on what it sent. A
// refusal (422 for a line that does not replay, 409 for a changed position)
// comes back in the server's own words, with its status — never swallowed
// into `null`, because the caller shows it in the sheet rather than guessing
// what went wrong.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

import '../models/exercise.dart';

/// What saving an exercise came back with. [exercise] is null on any
/// refusal; [error] is then the server's own sentence and [status] the
/// response it rode on (0 when the request could not be sent at all).
class ExerciseSaveResult {
  const ExerciseSaveResult({this.exercise, this.error, required this.status});

  final Exercise? exercise;
  final String? error;
  final int status;
}

class ExerciseApiService {
  ExerciseApiService({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String authToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Future<ExerciseSaveResult> create(ExerciseDraft draft) => _save(
        method: 'POST',
        url: '$backendUrl/exercises',
        draft: draft,
        okStatus: 201,
      );

  /// An edit says nothing about the position: [draft] omits `fen` unless the
  /// trainer is making a new exercise, and the server keeps the old one
  /// regardless (409 if the two disagree).
  Future<ExerciseSaveResult> update(String id, ExerciseDraft draft) => _save(
        method: 'PUT',
        url: '$backendUrl/exercises/$id',
        draft: draft,
        okStatus: 200,
      );

  Future<ExerciseSaveResult> _save({
    required String method,
    required String url,
    required ExerciseDraft draft,
    required int okStatus,
  }) async {
    try {
      final body = jsonEncode(draft.toJson());
      final res = method == 'POST'
          ? await _client
              .post(Uri.parse(url), headers: _headers, body: body)
              .timeout(const Duration(seconds: 20))
          : await _client
              .put(Uri.parse(url), headers: _headers, body: body)
              .timeout(const Duration(seconds: 20));

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }

      if (res.statusCode == okStatus && decoded?['exercise'] is Map) {
        final exercise = Exercise.fromJson(
            Map<String, dynamic>.from(decoded!['exercise'] as Map));
        if (exercise != null) {
          return ExerciseSaveResult(exercise: exercise, status: res.statusCode);
        }
      }
      final error = decoded?['error']?.toString() ??
          'Could not save the exercise (${res.statusCode}).';
      return ExerciseSaveResult(error: error, status: res.statusCode);
    } catch (e) {
      AppLogger.log('[Exercises] Save failed: $e');
      return const ExerciseSaveResult(
          error: 'Cannot connect to server.', status: 0);
    }
  }

  /// One exercise, with its solution, for its owner's editor. Null when it
  /// could not be read: unreachable, refused, or a body this app cannot parse.
  Future<Exercise?> load(String id) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/exercises/$id'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['exercise'] is! Map) return null;
      return Exercise.fromJson(
          Map<String, dynamic>.from(decoded['exercise'] as Map));
    } catch (e) {
      AppLogger.log('[Exercises] Load failed: $e');
      return null;
    }
  }
}
