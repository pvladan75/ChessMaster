import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/app_logger.dart';

/// A restored draft: the tree plus enough state to put the user back exactly
/// where they were.
class AnalysisDraft {
  final AnalysisNode rootNode;

  /// Child indices from the root down to the node that was selected. Indices
  /// are used rather than node ids because [AnalysisNode.fromJson] mints fresh
  /// ids on every load.
  final List<int> currentPath;
  final bool blackOrientation;
  final DateTime savedAt;

  AnalysisDraft({
    required this.rootNode,
    required this.currentPath,
    required this.blackOrientation,
    required this.savedAt,
  });

  /// Walks [currentPath] back down the restored tree, stopping early (rather
  /// than throwing) if the stored path no longer fits.
  AnalysisNode resolveCurrentNode() {
    var node = rootNode;
    for (final idx in currentPath) {
      if (idx < 0 || idx >= node.children.length) break;
      node = node.children[idx];
    }
    return node;
  }
}

/// Keeps a local, always-current copy of the Analysis Studio tree so closing
/// the screen — deliberately or not — never costs the user their work.
///
/// This is separate from [AnalysisPersistenceService], which handles named
/// analyses the user explicitly saves to the server. This one is an implicit,
/// single-slot scratch draft on the device.
class AnalysisDraftService {
  AnalysisDraftService._();
  static final AnalysisDraftService instance = AnalysisDraftService._();

  static const String _key = 'analysis_studio_draft';

  Timer? _debounce;

  /// Writes the draft after a short idle delay, so a burst of moves results in
  /// a single write instead of one per move.
  void scheduleSave({
    required AnalysisNode rootNode,
    required AnalysisNode currentNode,
    required bool blackOrientation,
  }) {
    _debounce?.cancel();
    // Snapshot synchronously: the tree may keep mutating before the timer runs.
    final payload = jsonEncode({
      'tree': rootNode.toJson(),
      'path': _pathTo(rootNode, currentNode),
      'blackOrientation': blackOrientation,
      'savedAt': DateTime.now().toIso8601String(),
    });
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, payload);
      } catch (e) {
        AppLogger.log('[AnalysisDraft] ❌ Save failed: $e');
      }
    });
  }

  Future<AnalysisDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final treeJson = map['tree'];
      if (treeJson is! Map) return null;

      final root = AnalysisNode.fromJson(Map<String, dynamic>.from(treeJson));
      // A bare starting position with no moves is not worth restoring.
      if (root.children.isEmpty) return null;

      return AnalysisDraft(
        rootNode: root,
        currentPath: ((map['path'] as List?) ?? const []).whereType<int>().toList(),
        blackOrientation: map['blackOrientation'] == true,
        savedAt: DateTime.tryParse(map['savedAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      AppLogger.log('[AnalysisDraft] ❌ Load failed: $e');
      return null;
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      AppLogger.log('[AnalysisDraft] ❌ Clear failed: $e');
    }
  }

  /// Flushes any pending debounced write immediately — call before the screen
  /// goes away, since a pending Timer dies with it.
  Future<void> flush({
    required AnalysisNode rootNode,
    required AnalysisNode currentNode,
    required bool blackOrientation,
  }) async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'tree': rootNode.toJson(),
          'path': _pathTo(rootNode, currentNode),
          'blackOrientation': blackOrientation,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      AppLogger.log('[AnalysisDraft] ❌ Flush failed: $e');
    }
  }

  List<int> _pathTo(AnalysisNode root, AnalysisNode target) {
    final path = <int>[];
    var node = target;
    while (node.parent != null) {
      final parent = node.parent!;
      final idx = parent.children.indexWhere((c) => c.id == node.id);
      if (idx < 0) return const [];
      path.insert(0, idx);
      node = parent;
    }
    // Guard against a target that belongs to a different tree.
    return node.id == root.id ? path : const [];
  }
}
