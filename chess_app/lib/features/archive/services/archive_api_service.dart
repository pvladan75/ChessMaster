import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/models/json_int.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/models/archive_homework_response.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

/// The colour as the API wants it: `w` or `b`, never `white`.
///
/// The screens hold `'white'`/`'black'` because those are what a segmented
/// button shows, and the backend's `requireColor` accepts only the single
/// letters — it answers 400 for anything else. Sent unconverted, the repertoire
/// diff failed on every single load, and no widget test could see it because a
/// faked API never validates what it was handed. Converted here, at the one
/// place that knows what goes on the wire.
String? _wireColor(String? color) {
  if (color == null) return null;
  final asked = color.trim().toLowerCase();
  if (asked.isEmpty) return null;
  if (asked == 'w' || asked == 'white') return 'w';
  if (asked == 'b' || asked == 'black') return 'b';
  return null;
}

class ArchiveApiService {
  ArchiveApiService._({http.Client? client}) : _client = client;

  static ArchiveApiService instance = ArchiveApiService._();

  /// A real service over a fake transport, for tests that need to see the
  /// request rather than replace it. The widget tests fake this class whole,
  /// which is right for them and blind to anything the server would refuse.
  @visibleForTesting
  static ArchiveApiService withClient(http.Client client) =>
      ArchiveApiService._(client: client);

  @visibleForTesting
  static void setMock(ArchiveApiService mock) {
    instance = mock;
  }

  final http.Client? _client;

  String get _token => SessionService.instance.current.token;
  String get _lichessToken =>
      AppSettingsService.instance.lichessApiToken.trim();

  Future<http.Response> _get(Uri uri, Map<String, String> headers) =>
      _client?.get(uri, headers: headers) ?? http.get(uri, headers: headers);

  Future<http.Response> _post(
          Uri uri, Map<String, String> headers, Object? body) =>
      _client?.post(uri, headers: headers, body: body) ??
      http.post(uri, headers: headers, body: body);

  Future<http.StreamedResponse> _send(http.BaseRequest request) =>
      _client?.send(request) ?? request.send();

  Future<int> importFile(String filePath, String username) async {
    final uri = Uri.parse('$backendUrl/games/import/file');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_token'
      ..fields['username'] = username
      ..files.add(await http.MultipartFile.fromPath('archive', filePath));

    final streamedResponse = await _send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 202) {
      final json = jsonDecode(response.body);
      return jsonInt(json['importId']);
    }
    throw Exception('Failed to import file: ${response.body}');
  }

  Future<int> importPgn(String pgn, String username) async {
    final uri = Uri.parse('$backendUrl/games/import/pgn');
    final response = await _post(
      uri,
      {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      jsonEncode({'pgn': pgn, 'username': username}),
    );
    if (response.statusCode == 202) {
      final json = jsonDecode(response.body);
      return jsonInt(json['importId']);
    }
    throw Exception('Failed to import PGN: ${response.body}');
  }

  Future<ArchiveRun> getImport(int id) async {
    final uri = Uri.parse('$backendUrl/games/imports/$id');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      return ArchiveRun.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to get import: ${response.body}');
  }

  Future<List<ArchiveSubject>> getSubjects() async {
    final uri = Uri.parse('$backendUrl/games/subjects');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ((json['subjects'] as List?) ?? [])
          .map((e) => ArchiveSubject.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Failed to get subjects: ${response.body}');
  }

  Future<List<ArchiveRun>> listImports() async {
    final uri = Uri.parse('$backendUrl/games/imports');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ((json['runs'] as List?) ?? [])
          .map((e) => ArchiveRun.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Failed to list imports: ${response.body}');
  }

  Future<LeakReport> getLeaks({
    required String subject,
    String? color,
    int? fromPly,
    int? toPly,
    int? minGames,
    double? maxScore,
    String? speed,
    int? limit,
    bool? judge,
    int? judgeLimit,
    int? minRating,
  }) async {
    final wire = _wireColor(color);
    final params = <String, String>{
      'subject': subject,
      if (wire != null) 'color': wire,
      if (fromPly != null) 'fromPly': fromPly.toString(),
      if (toPly != null) 'toPly': toPly.toString(),
      if (minGames != null) 'minGames': minGames.toString(),
      if (maxScore != null) 'maxScore': maxScore.toString(),
      if (speed != null) 'speed': speed,
      if (limit != null) 'limit': limit.toString(),
      if (judge != null) 'judge': judge.toString(),
      if (judgeLimit != null) 'judgeLimit': judgeLimit.toString(),
      if (minRating != null) 'minRating': minRating.toString(),
    };
    final uri = Uri.parse('$backendUrl/games/openings/leaks')
        .replace(queryParameters: params);

    final headers = {
      'Authorization': 'Bearer $_token',
    };
    if (_lichessToken.isNotEmpty) {
      headers['X-Lichess-Token'] = _lichessToken;
    }

    final response = await _get(uri, headers);
    if (response.statusCode == 200) {
      return LeakReport.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 400) {
      final error = jsonDecode(response.body)['error'] ?? 'Bad Request';
      throw Exception(error);
    }
    throw Exception('Failed to fetch leaks: ${response.body}');
  }

  Future<Map<String, int>> backfill() async {
    final uri = Uri.parse('$backendUrl/games/openings/backfill');
    final response =
        await _post(uri, {'Authorization': 'Bearer $_token'}, null);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return {
        'games': jsonInt(json['games']),
        'nodes': jsonInt(json['nodes']),
      };
    }
    throw Exception('Failed to backfill: ${response.body}');
  }

  Future<List<MistakeItem>> fetchMistakesDue({int limit = 20}) async {
    final uri = Uri.parse('$backendUrl/games/mistakes/due?limit=$limit');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ((json['items'] as List?) ?? [])
          .map((e) => MistakeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Failed to fetch due mistakes: ${response.body}');
  }

  Future<GradeResponse> gradeMistake(String id, String grade) async {
    final uri = Uri.parse('$backendUrl/games/mistakes/$id/grade');
    final response = await _post(
      uri,
      {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      jsonEncode({'grade': grade}),
    );
    return GradeResponse.fromJson(jsonDecode(response.body));
  }

  Future<Map<String, int>> fetchMistakeStats() async {
    final uri = Uri.parse('$backendUrl/games/mistakes/stats');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, jsonInt(v)));
    }
    throw Exception('Failed to fetch mistake stats: ${response.body}');
  }

  Future<MistakeRecurrence> fetchMistakeRecurrence() async {
    final uri = Uri.parse('$backendUrl/games/mistakes/recurrence');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      return MistakeRecurrence.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch mistake recurrence: ${response.body}');
  }

  Future<RepertoireDiff> getRepertoireDiff({
    required String username,
    String? color,
    int? limit,
  }) async {
    final wire = _wireColor(color);
    final params = <String, String>{
      'username': username,
      if (wire != null) 'color': wire,
      if (limit != null) 'limit': limit.toString(),
    };
    final uri = Uri.parse('$backendUrl/games/repertoire/diff')
        .replace(queryParameters: params);
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      return RepertoireDiff.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch repertoire diff: ${response.body}');
  }

  Future<PlayerProfile> getPlayerProfile(String username) async {
    final uri = Uri.parse('$backendUrl/games/profile?username=$username');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      return PlayerProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch player profile: ${response.body}');
  }

  Future<TrainerStudentArchive> getTrainerStudentArchive(
      String studentId) async {
    final uri = Uri.parse('$backendUrl/assignments/student/$studentId/archive');
    final response = await _get(uri, {'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      return TrainerStudentArchive.fromJson(jsonDecode(response.body));
    }
    throw Exception(
        'Failed to fetch trainer student archive: ${response.body}');
  }

  Future<ArchiveHomeworkResponse> createHomeworkFromArchive({
    required String studentId,
    int? count,
    String? kind,
    String? title,
    String? instructions,
    String? dueAt,
    bool? dryRun,
  }) async {
    final uri = Uri.parse('$backendUrl/assignments/from-archive');
    final response = await _post(
      uri,
      {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      jsonEncode({
        'studentId': studentId,
        if (count != null) 'count': count,
        if (kind != null) 'kind': kind,
        if (title != null) 'title': title,
        if (instructions != null) 'instructions': instructions,
        if (dueAt != null) 'dueAt': dueAt,
        if (dryRun != null) 'dryRun': dryRun,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ArchiveHomeworkResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 400 || response.statusCode == 403) {
      final decoded = jsonDecode(response.body);
      final msg = decoded['error'] ?? decoded['message'] ?? 'Greška';
      throw Exception(msg);
    }
    throw Exception('Failed to create homework: ${response.body}');
  }
}
