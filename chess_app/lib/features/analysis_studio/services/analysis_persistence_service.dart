import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

class SavedAnalysisSummary {
  final int id;
  final String title;
  final String startingFen;
  final DateTime createdAt;

  SavedAnalysisSummary({
    required this.id,
    required this.title,
    required this.startingFen,
    required this.createdAt,
  });

  factory SavedAnalysisSummary.fromJson(Map<String, dynamic> json) {
    return SavedAnalysisSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      startingFen: json['starting_fen'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Saves and loads Analysis Studio variation trees to/from the backend, so a
/// user's analysis is available across every device they log into.
class AnalysisPersistenceService {
  AnalysisPersistenceService._internal({http.Client? client})
      : _client = client;

  static AnalysisPersistenceService instance =
      AnalysisPersistenceService._internal();

  /// The real service over a fake transport, for a test that needs to see the
  /// request rather than replace the class. Faking the class whole cannot see
  /// a body the server would refuse — CLAUDE.md rule 7, fake the client and
  /// assert on the request.
  @visibleForTesting
  static AnalysisPersistenceService withClient(http.Client client) =>
      AnalysisPersistenceService._internal(client: client);

  @visibleForTesting
  static void setInstance(AnalysisPersistenceService replacement) {
    instance = replacement;
  }

  @visibleForTesting
  static void resetInstance() {
    instance = AnalysisPersistenceService._internal();
  }

  final http.Client? _client;

  Future<http.Response> _post(
          Uri uri, Map<String, String> headers, String body) =>
      _client?.post(uri, headers: headers, body: body) ??
      http.post(uri, headers: headers, body: body);

  Future<http.Response> _put(
          Uri uri, Map<String, String> headers, String body) =>
      _client?.put(uri, headers: headers, body: body) ??
      http.put(uri, headers: headers, body: body);

  Future<http.Response> _get(Uri uri, Map<String, String> headers) =>
      _client?.get(uri, headers: headers) ?? http.get(uri, headers: headers);

  Future<http.Response> _delete(Uri uri, Map<String, String> headers) =>
      _client?.delete(uri, headers: headers) ??
      http.delete(uri, headers: headers);

  Map<String, String> _headers(String userToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $userToken',
      };

  /// Saves the tree rooted at [rootNode] under [title]. Returns null on failure.
  Future<SavedAnalysisSummary?> saveAnalysis({
    required String title,
    required AnalysisNode rootNode,
    required String userToken,
  }) async {
    try {
      final res = await _post(
        Uri.parse('$backendUrl/analysis'),
        _headers(userToken),
        jsonEncode({
          'title': title,
          'startingFen': rootNode.fen,
          'tree': rootNode.toJson(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 201) {
        return SavedAnalysisSummary.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      print('[AnalysisPersistenceService] Error saving analysis: $e');
    }
    return null;
  }

  /// Writes the tree rooted at [rootNode] over the saved analysis [id], under
  /// [title]. Returns null on failure — a refused or unreachable server, or an
  /// [id] this account does not have (the server scopes it by account).
  ///
  /// „Replace" in the question [promptSaveAnalysisDialog] asks when a name is
  /// already taken (TODO-provera 201.9).
  Future<SavedAnalysisSummary?> replaceAnalysis({
    required int id,
    required String title,
    required AnalysisNode rootNode,
    required String userToken,
  }) async {
    try {
      final res = await _put(
        Uri.parse('$backendUrl/analysis/$id'),
        _headers(userToken),
        jsonEncode({
          'title': title,
          'startingFen': rootNode.fen,
          'tree': rootNode.toJson(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return SavedAnalysisSummary.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      print('[AnalysisPersistenceService] Error replacing analysis: $e');
    }
    return null;
  }

  /// Lists the current user's saved analyses (without the full tree), newest first.
  Future<List<SavedAnalysisSummary>> listSavedAnalyses(
      {required String userToken}) async {
    try {
      final res =
          await _get(Uri.parse('$backendUrl/analysis'), _headers(userToken))
              .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        return data
            .whereType<Map>()
            .map((e) =>
                SavedAnalysisSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      print('[AnalysisPersistenceService] Error listing analyses: $e');
    }
    return [];
  }

  /// Loads a saved analysis's full tree by [id]. Returns null on failure.
  Future<AnalysisNode?> loadAnalysis(
      {required int id, required String userToken}) async {
    try {
      final res =
          await _get(Uri.parse('$backendUrl/analysis/$id'), _headers(userToken))
              .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AnalysisNode.fromJson(data['tree_json'] as Map<String, dynamic>);
      }
    } catch (e) {
      print('[AnalysisPersistenceService] Error loading analysis: $e');
    }
    return null;
  }

  /// Deletes a saved analysis by [id]. Returns true on success.
  Future<bool> deleteAnalysis(
      {required int id, required String userToken}) async {
    try {
      final res = await _delete(
              Uri.parse('$backendUrl/analysis/$id'), _headers(userToken))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      print('[AnalysisPersistenceService] Error deleting analysis: $e');
      return false;
    }
  }
}
