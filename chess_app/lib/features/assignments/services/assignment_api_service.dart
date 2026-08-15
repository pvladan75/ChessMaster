import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import '../models/assignment.dart';

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
  AssignmentApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  String _errorFrom(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString() ?? fallback;
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
      final res = await http
          .post(
            Uri.parse('$backendUrl/assignments'),
            headers: _headers,
            body: jsonEncode({
              'studentId': studentId,
              'title': title,
              if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
              if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
              if (themes.isNotEmpty) 'themes': themes,
              if (minRating != null) 'minRating': minRating,
              if (maxRating != null) 'maxRating': maxRating,
              'count': count,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) return const CreateAssignmentResult(success: true);

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return CreateAssignmentResult(
        success: false,
        error: body['error']?.toString() ?? 'Zadatak nije kreiran.',
        quotaExceeded: body['quotaExceeded'] == true,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Kreiranje nije uspelo: $e');
      return const CreateAssignmentResult(
        success: false,
        error: 'Nema veze sa serverom.',
      );
    }
  }

  /// Assigns one of the trainer's own lessons.
  Future<CreateAssignmentResult> createLessonAssignment({
    required int studentId,
    required int lessonId,
    String? title,
    String? instructions,
    DateTime? dueAt,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/assignments/lesson'),
            headers: _headers,
            body: jsonEncode({
              'studentId': studentId,
              'lessonId': lessonId,
              if (title != null && title.isNotEmpty) 'title': title,
              if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
              if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) return const CreateAssignmentResult(success: true);

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return CreateAssignmentResult(
        success: false,
        error: body['error']?.toString() ?? 'Lekcija nije zadata.',
        quotaExceeded: body['quotaExceeded'] == true,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Zadavanje lekcije nije uspelo: $e');
      return const CreateAssignmentResult(success: false, error: 'Nema veze sa serverom.');
    }
  }

  /// Records that the student has been through one step of an assigned lesson.
  ///
  /// Fire-and-forget by design: a failure here must not interrupt the student's
  /// reading, and the step will be marked again on the next pass.
  Future<void> markLessonStep({required int assignmentId, required int position}) async {
    try {
      await http
          .post(
            Uri.parse('$backendUrl/assignments/$assignmentId/step/$position'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      AppLogger.log('[Assignments] Korak nije zabeležen: $e');
    }
  }

  Future<List<Assignment>> fetchMine() => _fetchList('$backendUrl/assignments/mine');

  Future<List<Assignment>> fetchGiven({int? studentId}) => _fetchList(
        '$backendUrl/assignments/given${studentId == null ? '' : '?studentId=$studentId'}',
      );

  Future<List<Assignment>> _fetchList(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['assignments'] as List?) ?? const [])
          .map((e) => Assignment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.log('[Assignments] Ne mogu da učitam listu: $e');
      return const [];
    }
  }

  Future<AssignmentDetail?> fetchDetail(int id) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/assignments/$id'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return AssignmentDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Assignments] Ne mogu da učitam zadatak: $e');
      return null;
    }
  }

  Future<String?> delete(int id) async {
    try {
      final res = await http
          .delete(Uri.parse('$backendUrl/assignments/$id'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return null;
      return _errorFrom(res.body, 'Brisanje nije uspelo.');
    } catch (e) {
      return 'Nema veze sa serverom.';
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
      final res = await http
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
        error: body['error']?.toString() ?? 'Izveštaj nije napravljen.',
        hasData: false,
      );
    } catch (e) {
      AppLogger.log('[Assignments] Izrada izveštaja nije uspela: $e');
      return (url: null, error: 'Nema veze sa serverom.', hasData: false);
    }
  }

  /// [studentId] null asks for the caller's own report.
  Future<StudentProgress?> fetchProgress({int? studentId, int days = 30}) async {
    final path = studentId == null ? 'me' : '$studentId';
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/assignments/progress/$path?days=$days'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return StudentProgress.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Assignments] Ne mogu da učitam izveštaj: $e');
      return null;
    }
  }
}
