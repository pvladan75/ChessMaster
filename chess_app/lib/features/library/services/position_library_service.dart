import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

import '../models/library_entry.dart';

/// Reads the trainer's positions as one shelf, and puts one onto a lesson.
///
/// Everything here is a read except [appendStep], which appends a single
/// step server-side rather than reading a lesson, pushing onto it and writing
/// the whole thing back — two people editing the same lesson that way lose one
/// of the edits, silently.
class PositionLibraryService {
  PositionLibraryService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  /// Everything the trainer can put into a lesson.
  ///
  /// Returns null when the server could not be reached. An empty list means
  /// "nothing saved", and the two must never look the same on screen — a
  /// trainer told "nemate pozicija" when the server is simply down will go
  /// looking for positions they already have.
  Future<List<LibraryEntry>?> list({LibraryKind? kind, String? search}) async {
    final query = <String, String>{
      if (kind != null) 'kind': libraryKindWire(kind),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final uri = Uri.parse('$backendUrl/library/positions')
        .replace(queryParameters: query.isEmpty ? null : query);

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['items'] as List? ?? [])
          .map((e) => LibraryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.log('Library list failed: $e', name: 'PositionLibrary');
      return null;
    }
  }

  /// Lessons that have steps — the ones a position can be appended to.
  ///
  /// A single saved board is not a course and cannot take a step; the server
  /// refuses that too, and says so rather than quietly turning one into the
  /// other.
  Future<List<CourseSummary>?> listCourses() async {
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/lessons'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;

      final rows = jsonDecode(response.body) as List;
      final courses = <CourseSummary>[];
      for (final row in rows.whereType<Map>()) {
        final steps = row['position_list'];
        if (steps is! List) continue;
        courses.add(CourseSummary(
          id: (row['id'] as num).toInt(),
          title: row['title']?.toString() ?? 'Bez naziva',
          stepCount: steps.length,
        ));
      }
      return courses;
    } catch (e) {
      AppLogger.log('Course list failed: $e', name: 'PositionLibrary');
      return null;
    }
  }

  /// Appends one position to an existing course.
  ///
  /// Returns null on success, or the server's own explanation. The refusals
  /// worth reading are its own words: a lesson that is really a single board,
  /// or a position no board could load.
  ///
  /// [instruction] and [solutionSan] are passed on rather than dropped. The
  /// task is what the student reads — a step without it is a board with no
  /// question — and the solution travels so the same step can later become
  /// homework without the move having been lost on the way in.
  Future<String?> appendStep({
    required int lessonId,
    required String title,
    required String fen,
    String? pgn,
    String? instruction,
    String? solutionSan,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/lessons/$lessonId/steps'),
            headers: _headers,
            body: jsonEncode({
              'step': {
                'title': title,
                'fen': fen,
                if (pgn != null) 'pgn': pgn,
                if (instruction != null) 'instruction': instruction,
                if (solutionSan != null) 'solutionSan': solutionSan,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) return null;
      try {
        return (jsonDecode(response.body) as Map<String, dynamic>)['error']
                ?.toString() ??
            'Dodavanje nije uspelo (${response.statusCode}).';
      } catch (_) {
        return 'Dodavanje nije uspelo (${response.statusCode}).';
      }
    } catch (e) {
      AppLogger.log('Append step failed: $e', name: 'PositionLibrary');
      return 'Nije moguće doći do servera.';
    }
  }
}
