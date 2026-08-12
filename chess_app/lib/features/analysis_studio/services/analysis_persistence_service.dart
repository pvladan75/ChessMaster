import 'dart:convert';
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
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Saves and loads Analysis Studio variation trees to/from the backend, so a
/// user's analysis is available across every device they log into.
class AnalysisPersistenceService {
  static final AnalysisPersistenceService instance = AnalysisPersistenceService._internal();

  AnalysisPersistenceService._internal();

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
      final res = await http
          .post(
            Uri.parse('$backendUrl/analysis'),
            headers: _headers(userToken),
            body: jsonEncode({
              'title': title,
              'startingFen': rootNode.fen,
              'tree': rootNode.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 201) {
        return SavedAnalysisSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      print('[AnalysisPersistenceService] Error saving analysis: $e');
    }
    return null;
  }

  /// Lists the current user's saved analyses (without the full tree), newest first.
  Future<List<SavedAnalysisSummary>> listSavedAnalyses({required String userToken}) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/analysis'), headers: _headers(userToken))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        return data
            .whereType<Map>()
            .map((e) => SavedAnalysisSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      print('[AnalysisPersistenceService] Error listing analyses: $e');
    }
    return [];
  }

  /// Loads a saved analysis's full tree by [id]. Returns null on failure.
  Future<AnalysisNode?> loadAnalysis({required int id, required String userToken}) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/analysis/$id'), headers: _headers(userToken))
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
  Future<bool> deleteAnalysis({required int id, required String userToken}) async {
    try {
      final res = await http
          .delete(Uri.parse('$backendUrl/analysis/$id'), headers: _headers(userToken))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      print('[AnalysisPersistenceService] Error deleting analysis: $e');
      return false;
    }
  }
}
