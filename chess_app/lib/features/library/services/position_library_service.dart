import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

import '../models/library_entry.dart';

/// Reads the trainer's positions as one shelf.
///
/// Every method here is a read. It used to carry one write — `appendStep`,
/// which its own comment already called the odd one out — and phase 7a moved
/// that onto `LessonApiService`, where the rest of what this app does to
/// `saved_lessons` now lives. A service that reads one table and writes another
/// is a service two features will reach for and one of them will be surprised.
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
          title: row['title']?.toString() ?? 'Untitled',
          stepCount: steps.length,
        ));
      }
      return courses;
    } catch (e) {
      AppLogger.log('Course list failed: $e', name: 'PositionLibrary');
      return null;
    }
  }
}
