import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

import '../models/homework.dart';

/// The client for `/homeworks` — `chess_backend/routes/homeworks.js`, phase
/// 3a. One call per verb, matching the routes exactly: list, one, save
/// (create or update) and remove.
class HomeworkApiService {
  HomeworkApiService({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String authToken;

  /// The client this service reads and writes through. Exposed so the editor
  /// screen can build the pickers it reuses (a tutorial's list, a position's
  /// shelf) against the *same* client — in a test, the same [MockClient] that
  /// answers `/homeworks`, so one recorder sees every request an "Add" flow
  /// makes rather than only the save (via `MockClient`). One client, one home.
  http.Client get client => _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  /// The server's own sentence — it names the item ("item 2: …") — or
  /// [fallback] when there is none to read.
  String _errorFrom(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString() ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// The server's sentence for the last [save], [load] or [remove] that
  /// failed. Null after a call that succeeded, or before any call at all.
  /// The header this class is built from returns a bare nullable value from
  /// each of those methods; this is where the *why* goes, the same shape as
  /// `LessonApiService.lastFetchFailed`.
  String? lastError;

  /// The trainer's own homeworks, as summaries — `item_count` and
  /// `sent_count` rather than the items themselves. Empty on any failure,
  /// the same rule `LessonApiService.fetchAll` uses for a list that is drawn
  /// either way.
  Future<List<Homework>> list() async {
    lastError = null;
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/homeworks'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        lastError = _errorFrom(res.body, 'Could not load homeworks.');
        return const [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['homeworks'] is! List) return const [];
      final result = <Homework>[];
      for (final raw in decoded['homeworks'] as List) {
        if (raw is! Map) continue;
        final homework = Homework.fromJson(Map<String, dynamic>.from(raw));
        if (homework != null) result.add(homework);
      }
      return result;
    } catch (e) {
      AppLogger.log('[Homework] Could not load list: $e');
      lastError = 'Cannot connect to server.';
      return const [];
    }
  }

  /// One homework, with its items in the trainer's order — or null when it
  /// could not be read: unreachable, refused, or a body this app cannot
  /// parse into a [Homework].
  Future<Homework?> load(int id) async {
    lastError = null;
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/homeworks/$id'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        lastError = _errorFrom(res.body, 'Could not load that homework.');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        lastError = 'Could not load that homework.';
        return null;
      }
      final homework = Homework.fromJson(Map<String, dynamic>.from(decoded));
      if (homework == null) lastError = 'Could not load that homework.';
      return homework;
    } catch (e) {
      AppLogger.log('[Homework] Could not load $id: $e');
      lastError = 'Cannot connect to server.';
      return null;
    }
  }

  /// Saves the homework as the editor holds it: `POST /homeworks` when it has
  /// never been saved, `PUT /homeworks/:id` otherwise. Returns the saved
  /// homework, or null with [lastError] set to the server's own sentence —
  /// which, on a refusal, names the item (`"item 2: …"`).
  Future<Homework?> save(Homework homework) async {
    lastError = null;
    final body = jsonEncode(homework.toJson());
    try {
      final res = homework.id == null
          ? await _client
              .post(Uri.parse('$backendUrl/homeworks'),
                  headers: _headers, body: body)
              .timeout(const Duration(seconds: 20))
          : await _client
              .put(Uri.parse('$backendUrl/homeworks/${homework.id}'),
                  headers: _headers, body: body)
              .timeout(const Duration(seconds: 20));

      final expectedStatus = homework.id == null ? 201 : 200;
      if (res.statusCode != expectedStatus) {
        lastError = _errorFrom(res.body, 'Could not save (${res.statusCode}).');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        lastError = 'Could not save.';
        return null;
      }
      final saved = Homework.fromJson(Map<String, dynamic>.from(decoded));
      if (saved == null) lastError = 'Could not save.';
      return saved;
    } catch (e) {
      AppLogger.log('[Homework] Save failed: $e');
      lastError = 'Cannot connect to server.';
      return null;
    }
  }

  /// Sends this homework to **one** student, which is what makes the quota
  /// rule true: the server charges one unit per request, so one student is
  /// one unit however many items the homework holds (the owner's answer to
  /// `docs/PLAN-DOMACI-ZADATAK.md` §9). A caller sending to three students
  /// makes three requests and spends three units.
  ///
  /// Null when it was sent; otherwise the server's own sentence, which names
  /// what refused — a position under review, a puzzle set that matches
  /// nothing, a quota that is spent. Nothing is written on a refusal, so the
  /// student gets the whole homework or none of it.
  Future<String?> send({
    required int homeworkId,
    required int studentId,
    DateTime? dueAt,
    String? note,
  }) async {
    lastError = null;
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/homeworks/$homeworkId/send'),
            headers: _headers,
            body: jsonEncode({
              'studentId': studentId,
              if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
              if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 201) return null;
      final error = _errorFrom(res.body, 'Could not send (${res.statusCode}).');
      lastError = error;
      return error;
    } catch (e) {
      AppLogger.log('[Homework] Send failed: $e');
      lastError = 'Cannot connect to server.';
      return lastError;
    }
  }

  /// Withdraws a homework. True on success; false with [lastError] set
  /// otherwise.
  Future<bool> remove(int id) async {
    lastError = null;
    try {
      final res = await _client
          .delete(Uri.parse('$backendUrl/homeworks/$id'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return true;
      lastError = _errorFrom(res.body, 'Could not delete (${res.statusCode}).');
      return false;
    } catch (e) {
      AppLogger.log('[Homework] Delete failed: $e');
      lastError = 'Cannot connect to server.';
      return false;
    }
  }
}
