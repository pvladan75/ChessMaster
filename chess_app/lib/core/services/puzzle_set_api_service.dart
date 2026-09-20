// puzzle_set_api_service.dart — the wire for the account's puzzle sets.
//
// Added 21.9.2026, on the owner's report that the Library showed his sets on
// Windows and nothing on the phone under the same account. They had only ever
// lived in `SharedPreferences` on the device that ran „Review entire game".
//
// Mounted at `/puzzle-sets` (`chess_backend/routes/puzzleSets.js`). The
// `client` seam is here for the same reason `EndgameApiService` carries one:
// a test that overrides the methods proves the screen and nothing about the
// path, the query or the body.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/services/app_logger.dart';

class PuzzleSetApiService {
  PuzzleSetApiService({required this.authToken, http.Client? client})
      : _client = client;

  final String authToken;
  final http.Client? _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Uri _uri(String path) => Uri.parse('$backendUrl/puzzle-sets$path');

  Future<http.Response> _get(Uri uri) =>
      _client?.get(uri, headers: _headers) ?? http.get(uri, headers: _headers);

  /// Every set this account keeps, newest first.
  ///
  /// **Null is not an empty list.** A server that cannot be reached must not
  /// read as „you have no sets", because the caller uses that answer to
  /// decide whether to fall back to the device's own — and an empty list
  /// would quietly hide them.
  Future<List<SavedPuzzleSet>?> list() async {
    try {
      final res = await _get(_uri('')).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        AppLogger.log('[PuzzleSets] List refused (${res.statusCode}).');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ((body['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SavedPuzzleSet.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      AppLogger.log('[PuzzleSets] List failed: $e');
      return null;
    }
  }

  /// Creates or replaces one set. Idempotent, which is what lets a device
  /// upload everything it holds on every start without multiplying anything.
  Future<bool> save(SavedPuzzleSet set) async {
    try {
      final uri = _uri('/${Uri.encodeComponent(set.id)}');
      final body = jsonEncode({
        'title': set.title,
        'createdAt': set.createdAt.toIso8601String(),
        'puzzles': set.puzzles.map((p) => p.toJson()).toList(),
      });
      final res = await (_client?.put(uri, headers: _headers, body: body) ??
              http.put(uri, headers: _headers, body: body))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return true;
      AppLogger.log('[PuzzleSets] Save refused (${res.statusCode}).');
      return false;
    } catch (e) {
      AppLogger.log('[PuzzleSets] Save failed: $e');
      return false;
    }
  }

  Future<bool> delete(String setId) async {
    try {
      final uri = _uri('/${Uri.encodeComponent(setId)}');
      final res = await (_client?.delete(uri, headers: _headers) ??
              http.delete(uri, headers: _headers))
          .timeout(const Duration(seconds: 12));
      // 404 is a set this account does not have, which is the state the
      // caller wanted anyway.
      if (res.statusCode == 200 || res.statusCode == 404) return true;
      AppLogger.log('[PuzzleSets] Delete refused (${res.statusCode}).');
      return false;
    } catch (e) {
      AppLogger.log('[PuzzleSets] Delete failed: $e');
      return false;
    }
  }
}
