import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class LocalPuzzleService {
  static final LocalPuzzleService instance = LocalPuzzleService._internal();

  LocalPuzzleService._internal();

  List<Map<String, dynamic>>? _cachedPuzzles;

  /// Loads and caches local mate puzzles from asset JSON.
  Future<List<Map<String, dynamic>>> loadLocalPuzzles() async {
    if (_cachedPuzzles != null) return _cachedPuzzles!;

    try {
      final jsonString =
          await rootBundle.loadString('assets/puzzles/mate_puzzles_db.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _cachedPuzzles =
          jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('[LOCAL_PUZZLE_SERVICE] Error loading local puzzles: $e');
      _cachedPuzzles = [];
    }

    return _cachedPuzzles!;
  }

  /// Gets a random puzzle for requested mate depth (1, 2, or 3).
  Future<Map<String, dynamic>?> getRandomPuzzle({
    required int mateIn,
    String? excludeId,
  }) async {
    final puzzles = await loadLocalPuzzles();
    if (puzzles.isEmpty) return null;

    List<String> solvedIds = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      solvedIds = prefs.getStringList('solved_local_puzzles') ?? [];
    } catch (_) {}

    final matchingPuzzles = puzzles.where((p) {
      final target = p['targetMoves'] ?? p['mate_depth'];
      final String id = p['id']?.toString() ?? '';
      final matchesDepth = target == mateIn;
      final isNotExcluded = id != excludeId;
      final isNotSolved = !solvedIds.contains(id);
      return matchesDepth && isNotExcluded && isNotSolved;
    }).toList();

    // Fallback if all matching puzzles have been solved
    final candidateList = matchingPuzzles.isNotEmpty
        ? matchingPuzzles
        : puzzles.where((p) {
            final target = p['targetMoves'] ?? p['mate_depth'];
            return target == mateIn;
          }).toList();

    if (candidateList.isEmpty) return null;

    final random = Random();
    final chosen = candidateList[random.nextInt(candidateList.length)];

    return {
      'id': chosen['id']?.toString(),
      'puzzle_id': chosen['id']?.toString(),
      'fen': chosen['fen'],
      'type': 'mate_puzzle',
      'mate_depth': mateIn,
      'solutions': chosen['solutions'] ?? {},
      'isLocal': true,
    };
  }

  /// Gets a random offline winning position puzzle.
  Future<Map<String, dynamic>?> getWinningPositionPuzzle({
    String? excludeId,
  }) async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/puzzles/hard_puzzles.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      if (jsonList.isNotEmpty) {
        jsonList.shuffle();
        final chosen = jsonList.first;
        return {
          'id': chosen['id']?.toString() ?? '1',
          'puzzle_id': chosen['id']?.toString() ?? '1',
          'fen': chosen['fen'],
          'type': 'winning_position',
          'solutions': {},
          'isLocal': true,
        };
      }
    } catch (e) {
      print('[LOCAL_PUZZLE_SERVICE] Error loading winning position puzzle: $e');
    }
    return null;
  }

  /// Saves solved puzzle ID into SharedPreferences so it won't repeat.
  Future<void> markPuzzleAsSolved(String puzzleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final solvedIds = prefs.getStringList('solved_local_puzzles') ?? [];
      if (!solvedIds.contains(puzzleId)) {
        solvedIds.add(puzzleId);
        await prefs.setStringList('solved_local_puzzles', solvedIds);
      }
    } catch (_) {}
  }
}
