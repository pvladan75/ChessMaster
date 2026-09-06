import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

/// Everything the app does to `saved_lessons`, in one place.
///
/// Phase 7a of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`, and the reason it exists
/// before the editor rather than with it: until now these calls were seven raw
/// `http` invocations spread over `chess_game_screen.dart` (4,346 lines), the
/// course dialog and the library service. A batch cannot be briefed against
/// that and a widget test cannot fake it — a test would have had to intercept
/// `http` itself, which is how you end up asserting that a URL was formatted.
///
/// Two rules it keeps, both of them paid for elsewhere in this codebase:
///
/// * **A refusal is passed on in the server's own words.** `buildLessonStep`
///   refuses a bad step with a reason a trainer can act on — „ask_move nema
///   rešenje", „potez nije legalan u toj poziciji" — and a client that replaces
///   those with „Čuvanje nije uspelo" throws away the only part that helps.
///   Every method here answers `null` for success and the server's sentence for
///   failure, which is the shape [appendStep] already had.
/// * **It never judges and never validates a step.** The server is the one
///   authority on what a step may be, exactly as it is the one authority on
///   whether an answer is right. A second copy of those rules in Dart is two
///   copies to keep in step, and the one that drifts is the one nobody is
///   testing.
class LessonApiService {
  LessonApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  /// The server's own sentence, or [fallback] when it did not send one.
  String _errorFrom(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString() ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Saved lessons and positions, filtered the way the library screen asks.
  ///
  /// Returns an empty list on any failure rather than throwing: this feeds a
  /// list that is drawn either way, and the screen says so itself.
  Future<List<dynamic>> fetchAll({
    String? searchQuery,
    List<String> includeTags = const [],
    List<String> excludeTags = const [],
    String matchMode = 'any',
  }) async {
    try {
      final params = <String, String>{
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
        if (includeTags.isNotEmpty) 'includeTags': includeTags.join(','),
        if (excludeTags.isNotEmpty) 'excludeTags': excludeTags.join(','),
        'matchMode': matchMode,
      };
      final res = await http
          .get(
            Uri.parse('$backendUrl/lessons').replace(queryParameters: params),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      return decoded is List ? decoded : const [];
    } catch (e) {
      AppLogger.log('[Lessons] Ne mogu da učitam listu: $e');
      return const [];
    }
  }

  /// The labels this user has used, for the filter panel.
  Future<List<String>> fetchLabels() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/lessons/labels'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      return decoded is List ? List<String>.from(decoded) : const [];
    } catch (e) {
      AppLogger.log('[Lessons] Ne mogu da učitam oznake: $e');
      return const [];
    }
  }

  /// Saves a position or a whole course. Returns the server's error, or null.
  Future<String?> save({
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/lessons/save'),
            headers: _headers,
            body: jsonEncode({
              'title': title,
              if (description != null) 'description': description,
              if (tags != null) 'tags': tags,
              if (fen != null) 'fen': fen,
              if (pgn != null) 'pgn': pgn,
              if (positionList != null) 'positionList': positionList,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 201) return null;
      return _errorFrom(res.body, 'Čuvanje nije uspelo (${res.statusCode}).');
    } catch (e) {
      AppLogger.log('[Lessons] Čuvanje nije uspelo: $e');
      return 'Nije moguće doći do servera.';
    }
  }

  /// Updates a lesson. Returns the server's error, or null.
  ///
  /// **[positionList] is omitted from the body when it is null, and that is not
  /// a tidiness.** The server tells "leave the steps alone" from "there are no
  /// steps now" by whether the field is present at all; sending an explicit
  /// null or an empty list clears them. A rename that carried `'positionList':
  /// null` would delete every step of a course, and nothing would say so —
  /// `chess_backend/test/lesson_rename_keeps_steps.test.js` is that bug's
  /// gravestone.
  Future<String?> update({
    required int id,
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$backendUrl/lessons/$id'),
            headers: _headers,
            body: jsonEncode({
              'title': title,
              if (description != null) 'description': description,
              if (tags != null) 'tags': tags,
              if (fen != null) 'fen': fen,
              if (pgn != null) 'pgn': pgn,
              if (positionList != null) 'positionList': positionList,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Izmena nije uspela (${res.statusCode}).');
    } catch (e) {
      AppLogger.log('[Lessons] Izmena nije uspela: $e');
      return 'Nije moguće doći do servera.';
    }
  }

  /// Deletes a lesson. Returns the server's error, or null.
  Future<String?> delete(int id) async {
    try {
      final res = await http
          .delete(Uri.parse('$backendUrl/lessons/$id'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Brisanje nije uspelo (${res.statusCode}).');
    } catch (e) {
      AppLogger.log('[Lessons] Brisanje nije uspelo: $e');
      return 'Nije moguće doći do servera.';
    }
  }

  /// Appends one step to an existing lesson, server-side.
  ///
  /// Moved here from `PositionLibraryService` in phase 7a, whose own doc
  /// comment already called it the odd one out — everything else there is a
  /// read. Appending in one statement rather than read-push-PUT is deliberate:
  /// two trainers editing one lesson that way lose an edit, and the loser is
  /// never told.
  ///
  /// [step] goes to the server as written, including `kind`, `solutionSan`,
  /// `acceptedSans` and `choices`. Nothing here inspects it — see the class
  /// comment.
  Future<String?> appendStep({
    required int lessonId,
    required Map<String, dynamic> step,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/lessons/$lessonId/steps'),
            headers: _headers,
            body: jsonEncode({'step': step}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 201) return null;
      return _errorFrom(res.body, 'Dodavanje nije uspelo (${res.statusCode}).');
    } catch (e) {
      AppLogger.log('[Lessons] Dodavanje koraka nije uspelo: $e');
      return 'Nije moguće doći do servera.';
    }
  }

  /// Saves a tutorial as a new version, and returns the copy's id.
  ///
  /// Phase 3a of `docs/PLAN-TUTORIJAL.md`. The trainer keeps one tutorial and
  /// makes an easier or harder version of it for another group; the original
  /// comes out untouched, which is why this is one call to the server rather
  /// than a read, an edit and a PUT — two of those racing lose an edit, and the
  /// loser is never told.
  ///
  /// The server mints a fresh id for every copied step. Null [title] means the
  /// server names it, `naslov (kopija)`.
  ///
  /// Returns the new id, or null with the reason in [cloneError] — the odd
  /// signature in this class, because the caller has to open what it just made.
  Future<int?> clone({required int id, String? title}) async {
    cloneError = null;
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/lessons/$id/clone'),
            headers: _headers,
            body: jsonEncode({if (title != null) 'title': title}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final newId = body is Map ? body['id'] : null;
        if (newId is int) return newId;
        cloneError = 'Kopija je napravljena, ali je server nije imenovao.';
        return null;
      }
      cloneError =
          _errorFrom(res.body, 'Kopiranje nije uspelo (${res.statusCode}).');
      return null;
    } catch (e) {
      AppLogger.log('[Lessons] Kopiranje nije uspelo: $e');
      cloneError = 'Nije moguće doći do servera.';
      return null;
    }
  }

  /// Why the last [clone] returned null. Null when it succeeded.
  String? cloneError;
}
