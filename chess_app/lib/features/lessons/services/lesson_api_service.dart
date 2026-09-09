import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

/// What a write to `saved_lessons` came to.
///
/// Both write routes answer with `RETURNING *`, so a successful write hands
/// back the whole row — including `position_list` **with the ids the server
/// minted**. Those ids are the identity of a step: `assignment_items.step_key`
/// and `review_items.step_key` name one by it and nothing joins on it. Until
/// P3a of `docs/PLAN-STUDIO-REDIZAJN.md` this class read the status code and
/// threw the body away, which is why a client could never learn them — and why
/// a second „Sačuvaj" would have made a second tutorial.
class LessonWriteResult {
  const LessonWriteResult({this.id, this.steps = const [], this.error});

  /// The row's id. Null when the write failed, or when the server answered
  /// without one.
  final int? id;

  /// `position_list` as it is now stored. Empty when the server said nothing
  /// about the steps — which the real one never does, but a client that treats
  /// „said nothing" as „there are none" is how `position_list = NULL` got
  /// written the first time.
  final List<Map<String, dynamic>> steps;

  /// The server's own sentence, or null on success.
  final String? error;

  bool get ok => error == null;
}

/// Stills of a film that has not been rendered.
class LessonPreviewFramesResult {
  const LessonPreviewFramesResult({this.frames = const [], this.error});

  /// One PNG per requested beat, in the order the server drew them.
  final List<Uint8List> frames;

  /// The server's own sentence, or null on success.
  final String? error;

  bool get ok => error == null && frames.isNotEmpty;
}

/// The outcome of an MP4 video export request for a tutorial.
class LessonExportVideoResult {
  const LessonExportVideoResult({
    required this.ok,
    this.downloadUrl,
    this.message,
    this.error,
  });

  final bool ok;
  final String? downloadUrl;
  final String? message;
  final String? error;
}

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
  LessonApiService({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

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

  /// Whether the last [fetchAll] failed.
  bool lastFetchFailed = false;

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
    lastFetchFailed = false;
    try {
      final params = <String, String>{
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
        if (includeTags.isNotEmpty) 'includeTags': includeTags.join(','),
        if (excludeTags.isNotEmpty) 'excludeTags': excludeTags.join(','),
        'matchMode': matchMode,
      };
      final res = await _client
          .get(
            Uri.parse('$backendUrl/lessons').replace(queryParameters: params),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        lastFetchFailed = true;
        return const [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        lastFetchFailed = true;
        return const [];
      }
      return decoded;
    } catch (e) {
      AppLogger.log('[Lessons] Could not load list: $e');
      lastFetchFailed = true;
      return const [];
    }
  }

  /// The labels this user has used, for the filter panel.
  Future<List<String>> fetchLabels() async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/lessons/labels'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      return decoded is List ? List<String>.from(decoded) : const [];
    } catch (e) {
      AppLogger.log('[Lessons] Could not load tags: $e');
      return const [];
    }
  }

  /// Saves a position or a whole course. Returns the server's error, or null.
  ///
  /// The thin shape, kept because three gate files fake this class by
  /// **overriding it** — `lesson_editor_test.dart`,
  /// `lesson_answer_stays_hidden_test.dart` and `lesson_step_order_test.dart`,
  /// all three of which `docs/PLAN-STUDIO-REDIZAJN.md` §8 requires to pass
  /// unedited. There is one implementation, in [saveTutorial]; this is an
  /// adapter, not a second route.
  Future<String?> save({
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async =>
      (await saveTutorial(
        title: title,
        description: description,
        tags: tags,
        fen: fen,
        pgn: pgn,
        positionList: positionList,
      ))
          .error;

  /// Saves, and answers with the row the server wrote.
  ///
  /// The caller needs the id and the step ids to be able to save a second time
  /// as an *edit* rather than as a new tutorial. See [LessonWriteResult].
  Future<LessonWriteResult> saveTutorial({
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async {
    try {
      final res = await _client
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
      if (res.statusCode == 201) return _rowFrom(res.body);
      return LessonWriteResult(
        error: _errorFrom(res.body, 'Save failed (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Save failed: $e');
      return const LessonWriteResult(error: 'Cannot connect to server.');
    }
  }

  /// The saved row, read out of a successful response.
  ///
  /// A body this cannot read is still a success — the write happened, and the
  /// status code said so. It comes back with no id and no steps rather than as
  /// a failure: telling a trainer their tutorial was not saved when it is in
  /// the database is the worse of the two wrong answers.
  LessonWriteResult _rowFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const LessonWriteResult();
      final rawSteps = decoded['position_list'];
      return LessonWriteResult(
        id: decoded['id'] is int ? decoded['id'] as int : null,
        steps: [
          for (final raw in rawSteps is List ? rawSteps : const [])
            if (raw is Map) Map<String, dynamic>.from(raw),
        ],
      );
    } catch (_) {
      return const LessonWriteResult();
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
  /// The thin shape. See [save] for why it survives; the work is in
  /// [updateTutorial].
  Future<String?> update({
    required int id,
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async =>
      (await updateTutorial(
        id: id,
        title: title,
        description: description,
        tags: tags,
        fen: fen,
        pgn: pgn,
        positionList: positionList,
      ))
          .error;

  /// Updates, and answers with the row the server wrote.
  ///
  /// [positionList] is omitted from the body when it is null for the reason
  /// spelled out on [update], and that has not changed: the server tells „leave
  /// the steps alone" from „there are no steps now" by whether the field is
  /// there at all.
  Future<LessonWriteResult> updateTutorial({
    required int id,
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async {
    try {
      final res = await _client
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
      if (res.statusCode == 200) return _rowFrom(res.body);
      return LessonWriteResult(
        error: _errorFrom(res.body, 'Update failed (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Update failed: $e');
      return const LessonWriteResult(error: 'Cannot connect to server.');
    }
  }

  /// Deletes a lesson. Returns the server's error, or null.
  Future<String?> delete(int id) async {
    try {
      final res = await _client
          .delete(Uri.parse('$backendUrl/lessons/$id'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Delete failed (${res.statusCode}).');
    } catch (e) {
      AppLogger.log('[Lessons] Delete failed: $e');
      return 'Cannot connect to server.';
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
      final res = await _client
          .post(
            Uri.parse('$backendUrl/lessons/$lessonId/steps'),
            headers: _headers,
            body: jsonEncode({'step': step}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 201) return null;
      return _errorFrom(res.body, 'Adding step failed (${res.statusCode}).');
    } catch (e) {
      AppLogger.log('[Lessons] Adding step failed: $e');
      return 'Cannot connect to server.';
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
      final res = await _client
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
        cloneError = 'Copy created, but server did not return an id.';
        return null;
      }
      cloneError = _errorFrom(res.body, 'Copy failed (${res.statusCode}).');
      return null;
    } catch (e) {
      AppLogger.log('[Lessons] Copy failed: $e');
      cloneError = 'Cannot connect to server.';
      return null;
    }
  }

  /// How far along a render is, and how long it looks like having left.
  ///
  /// Polled while the export request is still in flight — the render happens
  /// inside that request, and this is a plain read beside it. A failed poll is
  /// not a failed export: it answers null and the bar keeps whatever it had.
  ///
  /// `etaSeconds` is null until the server has two readings to take a rate
  /// from, and null again on the last frame, when what is left is ffmpeg
  /// closing the file rather than a number of frames. Null means „no estimate",
  /// which the screen says nothing about; it does not mean zero.
  ///
  /// `queuedAhead` is how many films are in front of this one. The server draws
  /// one at a time, so an export can spend its first stretch waiting — and a
  /// bar at „Starting…" looks identical to one that has begun. Zero means it is
  /// this film's turn.
  Future<({int percent, int? etaSeconds, int queuedAhead})?> renderProgress(
      String jobId) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/lessons/export-video/$jobId/progress'),
              headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map && body['percent'] is num) {
        final eta = body['etaSeconds'];
        final ahead = body['queuedAhead'];
        return (
          percent: (body['percent'] as num).round(),
          etaSeconds: eta is num ? eta.round() : null,
          queuedAhead: ahead is num ? ahead.round() : 0,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Why the last [clone] returned null. Null when it succeeded.
  String? cloneError;

  /// Fetches available TTS narration voices from the backend.
  Future<({bool available, List<Map<String, dynamic>> voices})>
      fetchTtsVoices() async {
    try {
      final res = await _client
          .get(
            Uri.parse('$backendUrl/lessons/tts/voices'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          final available = body['available'] == true;
          final rawVoices = body['voices'];
          final voices = <Map<String, dynamic>>[];
          if (rawVoices is List) {
            for (final v in rawVoices) {
              if (v is Map) {
                voices.add(Map<String, dynamic>.from(v));
              }
            }
          }
          return (available: available, voices: voices);
        }
      }
      return (available: false, voices: const <Map<String, dynamic>>[]);
    } catch (e) {
      AppLogger.log('[Lessons] Failed to fetch TTS voices: $e');
      return (available: false, voices: const <Map<String, dynamic>>[]);
    }
  }

  /// Exports a tutorial as an MP4 video rendered by the backend.
  Future<LessonExportVideoResult> exportVideo({
    required int lessonId,
    required List<Map<String, dynamic>> events,
    required int seconds,
    String? title,
    String resolution = '720p',
    String boardTheme = 'wood',

    /// The app's own colours, so the film matches the screen the tutorial was
    /// written on. Absent means the renderer's own defaults, which is what the
    /// recorded-lesson export sends.
    Map<String, String>? look,

    /// A name the client gives its own render so it can watch it. See
    /// [renderProgress].
    String? jobId,
    bool? narrate,
    String? voice,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/lessons/$lessonId/export-video'),
            headers: _headers,
            body: jsonEncode({
              'events': events,
              'seconds': seconds,
              if (title != null) 'title': title,
              'resolution': resolution,
              'boardTheme': boardTheme,
              if (look != null) 'look': look,
              if (jobId != null) 'jobId': jobId,
              if (narrate != null) 'narrate': narrate,
              if (voice != null) 'voice': voice,
            }),
          )
          .timeout(const Duration(minutes: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          return LessonExportVideoResult(
            ok: true,
            downloadUrl: body['downloadUrl']?.toString(),
            message: body['message']?.toString(),
          );
        }
        return const LessonExportVideoResult(
          ok: false,
          error: 'Invalid response from server.',
        );
      }
      return LessonExportVideoResult(
        ok: false,
        error: _errorFrom(res.body, 'Video export failed (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Video export failed: $e');
      return const LessonExportVideoResult(
        ok: false,
        error: 'Cannot connect to server.',
      );
    }
  }

  /// Stills of a film that has not been rendered, for the trainer to look at
  /// before spending a render on it.
  ///
  /// Costs no queue slot on the server and writes no file — see
  /// `POST /lessons/:id/preview-frames`. [beats] names which events to draw;
  /// absent, the server picks the opening, a middle beat and the end.
  ///
  /// The PNGs come back base64-encoded inside the JSON, so this returns the
  /// decoded bytes ready for `Image.memory`.
  Future<LessonPreviewFramesResult> previewFrames({
    required int lessonId,
    required List<Map<String, dynamic>> events,
    required int seconds,
    String? title,
    String resolution = '720p',
    String boardTheme = 'wood',
    Map<String, String>? look,
    List<int>? beats,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/lessons/$lessonId/preview-frames'),
            headers: _headers,
            body: jsonEncode({
              'events': events,
              'seconds': seconds,
              if (title != null) 'title': title,
              'resolution': resolution,
              'boardTheme': boardTheme,
              if (look != null) 'look': look,
              if (beats != null) 'beats': beats,
            }),
          )
          // Far shorter than an export's five minutes: a preview is one frame's
          // drawing, and a trainer waiting a minute for one has been told
          // something is wrong by the waiting itself.
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final raw = body is Map ? body['frames'] : null;
        if (raw is List) {
          final frames = <Uint8List>[];
          for (final entry in raw) {
            final png = entry is Map ? entry['png']?.toString() : null;
            if (png != null && png.isNotEmpty) frames.add(base64Decode(png));
          }
          if (frames.isEmpty) {
            return const LessonPreviewFramesResult(
              error: 'The server sent no preview.',
            );
          }
          return LessonPreviewFramesResult(frames: frames);
        }
        return const LessonPreviewFramesResult(
          error: 'Invalid response from server.',
        );
      }
      return LessonPreviewFramesResult(
        error: _errorFrom(res.body, 'Preview failed (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Preview failed: $e');
      return const LessonPreviewFramesResult(
          error: 'Cannot connect to server.');
    }
  }
}
