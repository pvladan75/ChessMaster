import 'dart:convert';
import 'dart:io';
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

/// What a save says about the tutorial's language — `docs/PLAN-JEZIK-GLASA.md`.
///
/// **Three answers, and a nullable string can only give two.** The server
/// leaves `saved_lessons.language` alone when a request does not mention it,
/// clears it on an explicit null, and stores a code. A draft written on this
/// device before the field existed does not know the language, and if it sent
/// `null` it would wipe one set elsewhere — so „I do not know" has to be a
/// value of its own rather than the absence of one.
class LanguageWrite {
  const LanguageWrite._(this.mentioned, this.code);

  /// Say nothing; the server keeps what it has. The default, so every caller
  /// written before this sends exactly what it sent before.
  static const silent = LanguageWrite._(false, null);

  /// The tutorial has not said what language it is in.
  static const unsaid = LanguageWrite._(true, null);

  /// One of the seven codes in `TutorialLanguage`.
  const LanguageWrite.code(String this.code) : mentioned = true;

  final bool mentioned;
  final String? code;

  /// [code] said, or [unsaid] for none.
  factory LanguageWrite.of(String? code) =>
      code == null ? unsaid : LanguageWrite.code(code);
}

/// Which of the three answers `GET /lessons/:id/video` gave.
enum LessonVideoStatus { ready, expired, none, failed }

/// A link to a tutorial's current video, minted when it was asked for.
class LessonVideoLink {
  const LessonVideoLink({
    required this.status,
    this.downloadUrl,
    this.renderedAt,
    this.resolution,
    this.narrated = false,
    this.error,
  });

  final LessonVideoStatus status;
  final String? downloadUrl;
  final DateTime? renderedAt;
  final String? resolution;
  final bool narrated;

  /// The server's own sentence, for everything that is not `ready`.
  final String? error;

  bool get ok => status == LessonVideoStatus.ready && downloadUrl != null;
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

/// What `POST /lessons/:id/export-video` answered.
///
/// **Not the film.** Since item 5 of part two of `docs/PLAN-SNIMANJE.md` the
/// server answers as soon as it has accepted the render, with the id of the
/// job, and draws the film behind that answer. What the film came to is read
/// from [LessonApiService.renderStatus].
class LessonExportVideoResult {
  const LessonExportVideoResult({
    this.jobId,
    this.alreadyRendering = false,
    this.error,
  });

  /// The render to watch: the one just started or, with [alreadyRendering],
  /// the one of this tutorial that was already running.
  final String? jobId;

  /// The server refused a second render of this tutorial because one is
  /// running, and named it. One film per tutorial: a second render would
  /// replace the first the moment it finished.
  final bool alreadyRendering;

  /// The server's own sentence when it refused, or null.
  final String? error;

  bool get ok => error == null && jobId != null;
}

/// Where a render is. `unknown` is a job the server does not have — never
/// started, somebody else's, or its tutorial deleted since.
enum RenderJobState { running, done, failed, cancelled, unknown }

/// One answer of `GET /lessons/export-video/:jobId/progress`.
class RenderJobStatus {
  const RenderJobStatus({
    required this.state,
    this.percent = 0,
    this.etaSeconds,
    this.queuedAhead = 0,
    this.message,
    this.downloadUrl,
    this.error,
  });

  final RenderJobState state;
  final int percent;

  /// Null until the server has two readings to take a rate from, and again on
  /// the last frame. Null is „no estimate", never zero.
  final int? etaSeconds;

  /// Films in front of this one; zero once it is being drawn.
  final int queuedAhead;

  /// For a finished film: the sentence to show, and a link minted when this
  /// answer was — absent if the file has aged out since.
  final String? message;
  final String? downloadUrl;

  /// For a render that failed or that the server does not have, its sentence.
  final String? error;

  bool get finished => state != RenderJobState.running;
}

/// What the server said to a trainer's recorded narration.
class NarrationUploadResult {
  const NarrationUploadResult({
    required this.ok,
    this.error,
    this.ms,
    this.beats,
  });

  final bool ok;

  /// The server's own sentence when it refused — it names the fault (a silent
  /// take, one cut short on the wire, one past the cap) and what to do.
  final String? error;

  /// How long the server measured the audio to be, from the file itself.
  final int? ms;
  final int? beats;
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
    LanguageWrite language = LanguageWrite.silent,
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
              if (language.mentioned) 'language': language.code,
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
    LanguageWrite language = LanguageWrite.silent,
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
              if (language.mentioned) 'language': language.code,
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

  /// Where render [jobId] is, and how long it looks like having left.
  ///
  /// Polled while the progress dialog is open. Since item 5 of part two of
  /// `docs/PLAN-SNIMANJE.md` the film is drawn after the export request has
  /// been answered, so this is also how the app learns what it came to: the
  /// last answer is `done` with a download link, `failed` with the server's
  /// sentence, or `cancelled`.
  ///
  /// Null when the server could not be asked — a failed poll is not a failed
  /// render, and the dialog keeps what it had. A job the server does not have
  /// is [RenderJobState.unknown], which is an answer rather than a failure to
  /// get one.
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
  Future<RenderJobStatus?> renderStatus(String jobId) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/lessons/export-video/$jobId/progress'),
              headers: _headers)
          .timeout(const Duration(seconds: 5));
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      if (res.statusCode == 404) {
        return RenderJobStatus(
          state: RenderJobState.unknown,
          error: body['error']?.toString(),
        );
      }
      if (res.statusCode != 200) return null;
      final percent = body['percent'];
      final eta = body['etaSeconds'];
      final ahead = body['queuedAhead'];
      return RenderJobStatus(
        state: switch (body['status']) {
          'done' => RenderJobState.done,
          'failed' => RenderJobState.failed,
          'cancelled' => RenderJobState.cancelled,
          _ => RenderJobState.running,
        },
        percent: percent is num ? percent.round() : 0,
        etaSeconds: eta is num ? eta.round() : null,
        queuedAhead: ahead is num ? ahead.round() : 0,
        message: body['message']?.toString(),
        downloadUrl: body['downloadUrl']?.toString(),
        error: body['error']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Asks the server to stop render [jobId]. True when it agreed to.
  ///
  /// **The render says it has stopped, not this.** The dialog keeps polling
  /// [renderStatus], because a film that finished in the same moment is still a
  /// film, and „cancelled" over a video the trainer now has would be a lie.
  Future<bool> cancelRender(String jobId) async {
    try {
      final res = await _client
          .delete(Uri.parse('$backendUrl/lessons/export-video/$jobId'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 202;
    } catch (e) {
      AppLogger.log('[Lessons] Could not cancel render $jobId: $e');
      return false;
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

  /// One spoken sentence in [voice], so a trainer can hear it before spending
  /// a render on it.
  ///
  /// **The alternative was exporting a film per voice** — minutes each, a queue
  /// slot each, and a cloud account offers hundreds of them. Null when the
  /// server has no such voice or could not speak; the caller says so and
  /// nothing plays.
  Future<Uint8List?> fetchVoiceSample(String voice) async {
    try {
      final res = await _client
          .get(
            Uri.parse('$backendUrl/lessons/tts/sample'
                '?voice=${Uri.encodeQueryComponent(voice)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
      // Braced because `dart format` wrapped this onto two lines the moment the
      // file was formatted, and an unbraced `if` over two lines is the one info
      // this project counts. The line was 82 characters before.
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
      AppLogger.log('[Lessons] Voice sample refused: ${res.statusCode}');
      return null;
    } catch (e) {
      AppLogger.log('[Lessons] Failed to fetch a voice sample: $e');
      return null;
    }
  }

  /// Asks the server to render a tutorial as an MP4 video.
  ///
  /// **Answered when the render is accepted, not when it is drawn** — item 5
  /// of part two of `docs/PLAN-SNIMANJE.md`. Every refusal still comes back
  /// here as the server's sentence (the recording does not match, the film is
  /// too long, the queue is full); an accepted film comes back as the id of
  /// its job, to watch with [renderStatus]. So thirty seconds rather than the
  /// five minutes this call used to wait for a whole render.
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
    bool? narrate,
    String? voice,

    /// The trainer's own recording instead of a synthesised voice, and the id
    /// of the take this device holds — the server refuses a film against any
    /// other.
    bool? useRecording,
    String? takeId,

    /// The beat list the film is drawn from, signed (`filmSignatureOf`) — phase
    /// 5. The server compares it with the one the recording was made against
    /// and refuses a film whose beats have moved since.
    String? signature,

    /// Whether the sentences are written beside the board. Null and true are
    /// the same request, and the same one every client sent before this field
    /// existed.
    bool? captions,
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
              if (narrate != null) 'narrate': narrate,
              if (voice != null) 'voice': voice,
              if (captions == false) 'captions': false,
              if (useRecording == true) 'useRecording': true,
              if (takeId != null) 'takeId': takeId,
              if (signature != null) 'signature': signature,
            }),
          )
          .timeout(const Duration(seconds: 30));
      // 202 is the render accepted; 409 with a job id is one of this tutorial
      // already running, which is the render to show. A 409 without one is a
      // refusal like any other — a recording that does not match — and falls
      // through to its sentence.
      if (res.statusCode == 202 || res.statusCode == 409) {
        final body = jsonDecode(res.body);
        final jobId = body is Map ? body['jobId']?.toString() : null;
        if (jobId != null &&
            (res.statusCode == 202 || body['alreadyRendering'] == true)) {
          return LessonExportVideoResult(
            jobId: jobId,
            alreadyRendering: res.statusCode == 409,
          );
        }
      }
      return LessonExportVideoResult(
        error: _errorFrom(res.body, 'Video export failed (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Video export failed: $e');
      return const LessonExportVideoResult(
        error: 'Cannot connect to server.',
      );
    }
  }

  /// Sends the trainer's own recorded narration of [lessonId] — phase 3 of
  /// `docs/PLAN-SNIMANJE.md`.
  ///
  /// The server judges the file itself (`services/narrationUpload.js`): its
  /// length from the wav's own header, compared with [durationMs]; the level
  /// from the samples; and [markersMs] against both. So a refusal comes back as
  /// the server's sentence, and nothing here tries to second-guess it.
  ///
  /// Five minutes, like the export: fifteen minutes of 16 kHz mono is under
  /// 30 MB, and a slow uplink is the one thing that makes this take long.
  Future<NarrationUploadResult> uploadNarration({
    required int lessonId,
    required String audioPath,
    required List<int> markersMs,
    required int durationMs,
    required int beats,

    /// The take's own id (`take-<id>.wav` on this device). The server keeps it
    /// beside the recording, which is how [serverTakeId] can answer.
    String? takeId,

    /// The beat list this was recorded against, signed. Kept beside the
    /// recording so the export can refuse a film whose beats have moved.
    String? signature,
  }) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$backendUrl/lessons/$lessonId/narration'));
      if (authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.fields['markersMs'] = jsonEncode(markersMs);
      request.fields['durationMs'] = '$durationMs';
      request.fields['beats'] = '$beats';
      if (takeId != null) request.fields['takeId'] = takeId;
      if (signature != null) request.fields['signature'] = signature;
      // Read whole and at once: fifteen minutes is under 30 MB, and a file
      // streamed from disk is asynchronous I/O that a widget test's clock never
      // lets finish — the upload would work everywhere but under test.
      request.files.add(http.MultipartFile.fromBytes(
          'audio', File(audioPath).readAsBytesSync(),
          filename: 'take.wav'));

      final streamed =
          await _client.send(request).timeout(const Duration(minutes: 5));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final narration = body is Map ? body['narration'] : null;
        return NarrationUploadResult(
          ok: true,
          ms: narration is Map ? (narration['ms'] as num?)?.toInt() : null,
          beats:
              narration is Map ? (narration['beats'] as num?)?.toInt() : null,
        );
      }
      return NarrationUploadResult(
        ok: false,
        error: _errorFrom(res.body,
            'The recording could not be uploaded (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Narration upload failed: $e');
      return const NarrationUploadResult(
        ok: false,
        error: 'Cannot connect to server.',
      );
    }
  }

  /// The id of the take the server holds for [lessonId], or null when it holds
  /// none — or could not be asked.
  ///
  /// Those two are deliberately one answer here. Its only caller uploads when
  /// the answer is not the take it has, and uploading when unsure costs
  /// bandwidth, where assuming the server has the take costs a film with no
  /// voice.
  Future<String?> serverTakeId(int lessonId) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/lessons/$lessonId/narration'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map && body['status'] == 'ready') {
        return body['takeId']?.toString();
      }
      return null;
    } catch (e) {
      AppLogger.log('[Lessons] Could not ask for the narration: $e');
      return null;
    }
  }

  /// The longest recording the server accepts over [lessonId], in milliseconds,
  /// or null when it could not be asked — or is a server that does not say.
  ///
  /// Asked rather than written here: since item 5 of part two of
  /// `docs/PLAN-SNIMANJE.md` the server derives it from its render budget, so
  /// it follows the drawing rate that server was configured with, and a copy in
  /// the app would be a second number that drifts from the first.
  Future<int?> narrationMaxMs(int lessonId) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/lessons/$lessonId/narration'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      final max = body is Map ? body['maxMs'] : null;
      return max is num && max > 0 ? max.toInt() : null;
    } catch (e) {
      AppLogger.log('[Lessons] Could not ask for the narration limit: $e');
      return null;
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

    /// Whether the preview is drawn with the sentences beside the board. The
    /// preview exists to show the film's own drawing, so it has to be told.
    bool? captions,
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
              if (captions == false) 'captions': false,
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

  /// The tutorial's current video, if it still has one.
  ///
  /// **The link is minted by this call.** A download token expires in thirty
  /// minutes, so the one handed out when the film was rendered is no use
  /// tomorrow; the server stores the filename and signs a fresh link when
  /// somebody asks. Three answers, and they lead to different buttons: no film
  /// has been rendered, one was and its file has since been deleted, or here it
  /// is.
  Future<LessonVideoLink> fetchTutorialVideo(int lessonId) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/lessons/$lessonId/video'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body);
      final map = body is Map ? body : const {};
      if (res.statusCode == 200) {
        return LessonVideoLink(
          status: LessonVideoStatus.ready,
          downloadUrl: map['downloadUrl']?.toString(),
          renderedAt: DateTime.tryParse(map['renderedAt']?.toString() ?? ''),
          resolution: map['resolution']?.toString(),
          narrated: map['narrated'] == true,
        );
      }
      if (res.statusCode == 410) {
        return LessonVideoLink(
          status: LessonVideoStatus.expired,
          error: map['error']?.toString(),
        );
      }
      if (res.statusCode == 404 && map['status'] == 'none') {
        return LessonVideoLink(
          status: LessonVideoStatus.none,
          error: map['error']?.toString(),
        );
      }
      return LessonVideoLink(
        status: LessonVideoStatus.failed,
        error: _errorFrom(
            res.body, 'Could not find the video (${res.statusCode}).'),
      );
    } catch (e) {
      AppLogger.log('[Lessons] Video link failed: $e');
      return const LessonVideoLink(
        status: LessonVideoStatus.failed,
        error: 'Cannot connect to server.',
      );
    }
  }
}
