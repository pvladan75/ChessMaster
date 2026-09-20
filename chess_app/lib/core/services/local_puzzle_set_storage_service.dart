import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/services/app_logger.dart';

/// A named group of [LocalPuzzle]s extracted from one game, kept together so
/// the set can be reopened and stepped through later instead of vanishing
/// once the extraction dialog that produced it closes.
class SavedPuzzleSet {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<LocalPuzzle> puzzles;

  const SavedPuzzleSet({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.puzzles,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'puzzles': puzzles.map((p) => p.toJson()).toList(),
      };

  factory SavedPuzzleSet.fromJson(Map<String, dynamic> json) => SavedPuzzleSet(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        puzzles: ((json['puzzles'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => LocalPuzzle.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// On-device library of extracted puzzle sets (see [SavedPuzzleSet]). Local
/// only, like [AnalysisDraftService] in the same feature — no login or
/// backend round-trip needed just to keep a set of exercises around between
/// sessions.
class LocalPuzzleSetStorageService {
  LocalPuzzleSetStorageService._();
  static final LocalPuzzleSetStorageService instance =
      LocalPuzzleSetStorageService._();

  static const String _key = 'analysis_studio_puzzle_sets';

  /// Caps how many sets accumulate on the device so this doesn't grow
  /// unbounded across many extraction runs.
  static const int _maxSets = 30;

  Future<List<SavedPuzzleSet>> loadSets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];

      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => SavedPuzzleSet.fromJson(Map<String, dynamic>.from(m)))
          .toList()
        // Newest first.
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      AppLogger.log('[LocalPuzzleSetStorage] ❌ Load failed: $e');
      return const [];
    }
  }

  /// Saves [puzzles] as a new named set and returns it.
  Future<SavedPuzzleSet> saveSet({
    required String title,
    required List<LocalPuzzle> puzzles,
  }) async {
    final set = SavedPuzzleSet(
      id: 'puzzleset_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      createdAt: DateTime.now(),
      puzzles: puzzles,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await loadSets();
      final updated = [set, ...existing].take(_maxSets).toList();
      await prefs.setString(
          _key, jsonEncode(updated.map((s) => s.toJson()).toList()));
    } catch (e) {
      AppLogger.log('[LocalPuzzleSetStorage] ❌ Save failed: $e');
    }

    return set;
  }

  /// Replaces everything this device holds with [sets].
  ///
  /// The cache half of `PuzzleSetRepository`: after a reachable load, what
  /// the account has is what this device should hold, so a set deleted on
  /// another machine stops haunting this one. Capped the same way a save is,
  /// because the cap is about this device's storage and not about the
  /// account.
  Future<void> replaceAll(List<SavedPuzzleSet> sets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kept = sets.take(_maxSets).toList();
      await prefs.setString(
          _key, jsonEncode(kept.map((s) => s.toJson()).toList()));
    } catch (e) {
      AppLogger.log('[LocalPuzzleSetStorage] ❌ Replace failed: $e');
    }
  }

  Future<void> deleteSet(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await loadSets();
      existing.removeWhere((s) => s.id == id);
      await prefs.setString(
          _key, jsonEncode(existing.map((s) => s.toJson()).toList()));
    } catch (e) {
      AppLogger.log('[LocalPuzzleSetStorage] ❌ Delete failed: $e');
    }
  }
}
