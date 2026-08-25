import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStep;

/// How well the student recalled a position, on SM-2's 0–5 scale.
///
/// Four buttons rather than six: asking a child to distinguish six shades of
/// remembering produces noise, not data. Anything below 3 counts as a failure.
enum ReviewGrade {
  again(1, 'Ponovo'),
  hard(3, 'Teško'),
  good(4, 'Dobro'),
  easy(5, 'Lako');

  const ReviewGrade(this.quality, this.label);

  final int quality;
  final String label;
}

/// One position waiting to be reviewed.
class ReviewItem {
  final int id;
  final int lessonId;
  final int position;
  final String lessonTitle;
  final int repetitions;
  final LessonStep step;

  const ReviewItem({
    required this.id,
    required this.lessonId,
    required this.position,
    required this.lessonTitle,
    required this.repetitions,
    required this.step,
  });

  /// True the first time a position comes round; the UI says so, because
  /// grading something you have never been asked before feels like a trick.
  bool get isNew => repetitions == 0;

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        lessonId: (json['lessonId'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num?)?.toInt() ?? 0,
        lessonTitle: json['lessonTitle']?.toString() ?? '',
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        step: LessonStep.fromJson(
            Map<String, dynamic>.from(json['step'] ?? const {})),
      );
}

class ReviewStats {
  final int total;
  final int due;
  final int mature;

  const ReviewStats({this.total = 0, this.due = 0, this.mature = 0});

  factory ReviewStats.fromJson(Map<String, dynamic> json) => ReviewStats(
        total: (json['total'] as num?)?.toInt() ?? 0,
        due: (json['due'] as num?)?.toInt() ?? 0,
        mature: (json['mature'] as num?)?.toInt() ?? 0,
      );
}

class ReviewApiService {
  ReviewApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Future<({List<ReviewItem> items, ReviewStats stats})> fetchDue(
      {int limit = 30}) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/reviews/due?limit=$limit'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200)
        return (items: <ReviewItem>[], stats: const ReviewStats());

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        items: ((data['items'] as List?) ?? const [])
            .map((e) => ReviewItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        stats: ReviewStats.fromJson(
            Map<String, dynamic>.from(data['stats'] ?? const {})),
      );
    } catch (e) {
      AppLogger.log('[Reviews] Ne mogu da učitam ponavljanja: $e');
      return (items: <ReviewItem>[], stats: const ReviewStats());
    }
  }

  Future<ReviewStats> fetchStats() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/reviews/stats'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const ReviewStats();
      return ReviewStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      return const ReviewStats();
    }
  }

  /// Records a grade and returns the server's description of when it comes back
  /// ("sutra", "za 2 nedelje"), or null if it could not be saved.
  Future<String?> grade({
    required int lessonId,
    required int position,
    required ReviewGrade grade,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/reviews/grade'),
            headers: _headers,
            body: jsonEncode({
              'lessonId': lessonId,
              'position': position,
              'quality': grade.quality,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['description']
          ?.toString();
    } catch (e) {
      AppLogger.log('[Reviews] Ocena nije zabeležena: $e');
      return null;
    }
  }
}
