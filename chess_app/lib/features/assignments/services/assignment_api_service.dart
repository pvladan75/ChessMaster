import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart'
    show LessonVideoLink, LessonVideoStatus;
import 'package:chess_app/services/app_logger.dart';
import '../models/assignment.dart';
import '../models/assignment_review.dart';

/// Result of asking the server to create homework.
class CreateAssignmentResult {
  final bool success;
  final String? error;

  /// True when the free tier's monthly allowance is spent, so the caller can
  /// offer the upgrade rather than showing a bare error.
  final bool quotaExceeded;

  const CreateAssignmentResult({
    required this.success,
    this.error,
    this.quotaExceeded = false,
  });
}

class AssignmentApiService {
  AssignmentApiService({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String authToken;

  /// The seam: every request in this file goes through this client, so a
  /// test can answer it. Without this, the file called the top-level
  /// `http.get`/`http.post` directly, which no test could fake.
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  String _errorFrom(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString() ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<CreateAssignmentResult> create({
    required int studentId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    List<String> themes = const [],
    int? minRating,
    int? maxRating,
    int count = 10,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments'),
            headers: _headers,
            body: jsonEncode({
              'studentId': studentId,
              'title': title,
              if (instructions != null && instructions.isNotEmpty)
                'instructions': instructions,
              if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
              if (themes.isNotEmpty) 'themes': themes,
              if (minRating != null) 'minRating': minRating,
              if (maxRating != null) 'maxRating': maxRating,
              'count': count,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) {
        return const CreateAssignmentResult(success: true);
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return CreateAssignmentResult(
        success: false,
        error: body['error']?.toString() ?? 'Assignment not created.',
        quotaExceeded: body['quotaExceeded'] == true,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Creation failed: $e');
      return const CreateAssignmentResult(
        success: false,
        error: 'Cannot connect to server.',
      );
    }
  }

  /// Sends one of the trainer's own tutorials — its film — to a student.
  /// A tutorial with no film is refused, with the server's sentence.
  Future<CreateAssignmentResult> createLessonAssignment({
    required int studentId,
    required int lessonId,
    String? title,
    String? instructions,
    DateTime? dueAt,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments/lesson'),
            headers: _headers,
            body: jsonEncode({
              'studentId': studentId,
              'lessonId': lessonId,
              if (title != null && title.isNotEmpty) 'title': title,
              if (instructions != null && instructions.isNotEmpty)
                'instructions': instructions,
              if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) {
        return const CreateAssignmentResult(success: true);
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return CreateAssignmentResult(
        success: false,
        error: body['error']?.toString() ?? 'Tutorial not assigned.',
        quotaExceeded: body['quotaExceeded'] == true,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Assigning tutorial failed: $e');
      return const CreateAssignmentResult(
          success: false, error: 'Cannot connect to server.');
    }
  }

  /// Sends the student's move for one of the trainer's own positions.
  ///
  /// The verdict comes from the server because the solution never left it;
  /// the first answer is the answer, and the server's report keeps it.
  Future<CustomAttemptResult?> submitCustomAttempt({
    required int assignmentId,
    required String puzzleId,
    required String moveSan,
    int? msTaken,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments/$assignmentId/custom-attempt'),
            headers: _headers,
            body: jsonEncode({
              'puzzleId': puzzleId,
              'moveSan': moveSan,
              if (msTaken != null) 'msTaken': msTaken,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return CustomAttemptResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Assignments] Answer not sent: $e');
      return null;
    }
  }

  /// A fresh link to the tutorial film sent to the student in
  /// [assignmentId] — `docs/PLAN-TUTORIJAL-VIDEO.md`, phase 2.
  ///
  /// **Minted by this call**: the link's token dies in thirty minutes and names
  /// this student, this assignment and this file, so the download it opens is
  /// what the server records as done. `ready` with a link, `none` when the
  /// tutorial or its film is gone, `failed` otherwise — each with the server's
  /// own sentence.
  Future<LessonVideoLink> fetchVideoLink(int assignmentId) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/assignments/$assignmentId/video'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> map = const {};
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic>) map = body;
      } catch (_) {}
      if (res.statusCode == 200 && map['downloadUrl'] != null) {
        return LessonVideoLink(
          status: LessonVideoStatus.ready,
          downloadUrl: map['downloadUrl'].toString(),
          renderedAt: DateTime.tryParse(map['renderedAt']?.toString() ?? ''),
          resolution: map['resolution']?.toString(),
          narrated: map['narrated'] == true,
        );
      }
      return LessonVideoLink(
        status: map['status'] == 'none'
            ? LessonVideoStatus.none
            : LessonVideoStatus.failed,
        error: map['error']?.toString() ??
            'Could not fetch the video (${res.statusCode}).',
      );
    } catch (e) {
      AppLogger.log('[Assignments] Video link failed: $e');
      return const LessonVideoLink(
          status: LessonVideoStatus.failed, error: 'Cannot connect to server.');
    }
  }

  Future<List<Assignment>> fetchMine() =>
      _fetchList('$backendUrl/assignments/mine');

  Future<List<Assignment>> fetchGiven({int? studentId}) => _fetchList(
        '$backendUrl/assignments/given${studentId == null ? '' : '?studentId=$studentId'}',
      );

  Future<List<Assignment>> _fetchList(String url) async {
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['assignments'] as List?) ?? const [])
          .map((e) => Assignment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.log('[Assignments] Could not load list: $e');
      return const [];
    }
  }

  /// What asking for one assignment's detail can answer, as three answers
  /// rather than two: the detail itself,
  /// „not yet — here is what blocks it" when the server refuses a locked
  /// item (`{locked: true, blockedBy}`, whatever status it rides on), or
  /// neither when the request could not be answered at all — and „the
  /// server did not answer“ must not read as „you are locked out“, which is
  /// why [locked] is its own flag rather than „no detail and no blocker“.
  /// `AssignmentDetail
  /// .fromJson` would read a locked body as an assignment with no title and
  /// no items, so this is read here rather than left for every caller to
  /// notice on its own.
  Future<({AssignmentDetail? detail, bool locked, int? lockedBy})> fetchDetail(
      int id) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/assignments/$id'), headers: _headers)
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = null;
      }

      // Read from the body, not from the status: the server answers a
      // locked item with 423 (`routes/assignments.js`), and a check written
      // against one status would break the moment the other arrived.
      if (body != null && body['locked'] == true) {
        return (
          detail: null,
          locked: true,
          lockedBy: (body['blockedBy'] as num?)?.toInt(),
        );
      }
      if (res.statusCode != 200 || body == null) {
        return (detail: null, locked: false, lockedBy: null);
      }
      return (
        detail: AssignmentDetail.fromJson(body),
        locked: false,
        lockedBy: null,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Could not load assignment: $e');
      return (detail: null, locked: false, lockedBy: null);
    }
  }

  /// The trainer's escape hatch: unlocks one child of a homework for the
  /// student it was sent to. Null when it worked, the server's own sentence
  /// when it did not — 404 covers „not yours", „not an item" and „already
  /// open" alike, so there is only ever one message to show.
  Future<String?> openGate(int assignmentId) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments/$assignmentId/open-gate'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Could not unlock this item.');
    } catch (e) {
      AppLogger.log('[Assignments] Unlock failed: $e');
      return 'Cannot connect to server.';
    }
  }

  /// The trainer's own verdict on a played game (`docs/PLAN-EXERCISE.md`,
  /// phase 15): „Play N moves", which has no other judge, and a game no
  /// tablebase answered. Null when it was written; otherwise the server's own
  /// sentence — 404 for a game that is not this trainer's or was not played,
  /// 409 for one the rules or a tablebase already judged.
  Future<String?> submitGameVerdict(int assignmentId,
      {required bool met}) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments/$assignmentId/game-verdict'),
            headers: _headers,
            body: jsonEncode({'met': met}),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Could not save the verdict.');
    } catch (e) {
      AppLogger.log('[Assignments] Verdict failed: $e');
      return 'Cannot connect to server.';
    }
  }

  /// What happened on one assignment, position by position, with the notes.
  ///
  /// One request rather than three: it is one screen, and the server decides
  /// what this reader may see — including whether the solution has been earned
  /// yet.
  Future<AssignmentReview?> fetchReview(int id) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/assignments/$id/review'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return AssignmentReview.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Assignments] Could not load review: $e');
      return null;
    }
  }

  /// Leaves a note on the assignment, or on one position in it.
  ///
  /// Returns the stored note, or an error message. Who wrote it is read from
  /// the account on the server and never sent from here.
  Future<({AssignmentNote? note, String? error})> addNote({
    required int assignmentId,
    required String body,
    int? itemId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments/$assignmentId/notes'),
            headers: _headers,
            body: jsonEncode(
                {'body': body, if (itemId != null) 'itemId': itemId}),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (
          note: AssignmentNote.fromJson(
              Map<String, dynamic>.from(data['note'] as Map)),
          error: null,
        );
      }
      return (note: null, error: _errorFrom(res.body, 'Note not sent.'));
    } catch (e) {
      AppLogger.log('[Assignments] Note not sent: $e');
      return (note: null, error: 'Cannot connect to server.');
    }
  }

  /// Takes back a note the caller wrote. Only the author may.
  Future<String?> deleteNote(
      {required int assignmentId, required int noteId}) async {
    try {
      final res = await _client
          .delete(
            Uri.parse('$backendUrl/assignments/$assignmentId/notes/$noteId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Delete failed.');
    } catch (e) {
      return 'Cannot connect to server.';
    }
  }

  Future<String?> delete(int id) async {
    try {
      final res = await _client
          .delete(Uri.parse('$backendUrl/assignments/$id'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Delete failed.');
    } catch (e) {
      return 'Cannot connect to server.';
    }
  }

  /// Freezes a report for the parent and returns the link to share.
  ///
  /// Returns the URL on success, or an error message. The link carries a signed
  /// token and expires, so it is shareable but not permanent.
  Future<({String? url, String? error, bool hasData})> generateParentReport({
    required int studentId,
    int days = 30,
    String? note,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$backendUrl/assignments/report/$studentId'),
            headers: _headers,
            body: jsonEncode({
              'days': days,
              if (note != null && note.isNotEmpty) 'note': note,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201) {
        return (
          url: body['url']?.toString(),
          error: null,
          hasData: body['hasData'] == true,
        );
      }
      return (
        url: null,
        error: body['error']?.toString() ?? 'Report not generated.',
        hasData: false,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Report generation failed: $e');
      return (url: null, error: 'Cannot connect to server.', hasData: false);
    }
  }

  /// [studentId] null asks for the caller's own report.
  Future<StudentProgress?> fetchProgress(
      {int? studentId, int days = 30}) async {
    final path = studentId == null ? 'me' : '$studentId';
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/assignments/progress/$path?days=$days'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return StudentProgress.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Assignments] Could not load report: $e');
      return null;
    }
  }
}
