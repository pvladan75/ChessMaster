import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/json_int.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

class ArchiveApiService {
  ArchiveApiService._({http.Client? client}) : _client = client;

  static ArchiveApiService instance = ArchiveApiService._();

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
    final params = <String, String>{
      'subject': subject,
      if (color != null) 'color': color,
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
}
