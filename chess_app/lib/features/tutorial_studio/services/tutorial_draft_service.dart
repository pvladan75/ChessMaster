import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/services/app_logger.dart';

/// A restored tutorial draft: the examples already written, plus the tree the
/// trainer was standing in when they left.
class TutorialDraftRestore {
  TutorialDraftRestore({
    required this.draft,
    required this.workingTree,
    required this.workingPath,
    required this.blackOrientation,
  });

  final TutorialDraft draft;

  /// The example being written, as a tree rather than as a PGN string.
  ///
  /// Stored as the tree because that is what comes back without a parser: a
  /// [TutorialExample] holds `pgn`, and reading a PGN back into an
  /// [AnalysisNode] is a second importer this feature does not need to own.
  final AnalysisNode workingTree;

  /// Child indices from [workingTree] down to the node that was selected.
  /// Indices rather than ids, because [AnalysisNode.fromJson] mints fresh ones.
  final List<int> workingPath;

  final bool blackOrientation;

  AnalysisNode resolveWorkingNode() {
    var node = workingTree;
    for (final index in workingPath) {
      if (index < 0 || index >= node.children.length) break;
      node = node.children[index];
    }
    return node;
  }
}

/// Keeps a local, always-current copy of the tutorial being written, so closing
/// the screen — deliberately or not — never costs the trainer their work.
///
/// The same shape as [AnalysisDraftService], deliberately: decision 3 says the
/// tutorial is held in memory and saved once at the end, and "held in memory"
/// is only honest if leaving the screen does not empty it. One slot, on the
/// device, never on the server.
class TutorialDraftService {
  TutorialDraftService._();
  static final TutorialDraftService instance = TutorialDraftService._();

  static const String _key = 'tutorial_studio_draft';

  Timer? _debounce;

  /// Writes after a short idle delay, so a burst of moves is one write.
  void scheduleSave({
    required TutorialDraft draft,
    required AnalysisNode workingTree,
    required AnalysisNode workingNode,
    required bool blackOrientation,
  }) {
    _debounce?.cancel();
    // Snapshot synchronously: the tree keeps mutating while the timer waits.
    final payload = _encode(
      draft: draft,
      workingTree: workingTree,
      workingNode: workingNode,
      blackOrientation: blackOrientation,
    );
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, payload);
      } catch (e) {
        AppLogger.log('[TutorialDraft] ❌ Čuvanje nije uspelo: $e');
      }
    });
  }

  /// Writes now. Called before the screen goes away.
  ///
  /// The debounce is 600 ms, and a trainer who closes the window inside that
  /// half-second closes the process with it — the pending timer never runs, and
  /// the last thing they wrote is the thing they lose. Nothing in a widget test
  /// can see that on its own: there the timer outlives the screen and writes the
  /// same payload a moment later, which is how the gate for this passed with
  /// the flush deleted until it was measured.
  Future<void> flush({
    required TutorialDraft draft,
    required AnalysisNode workingTree,
    required AnalysisNode workingNode,
    required bool blackOrientation,
  }) async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        _encode(
          draft: draft,
          workingTree: workingTree,
          workingNode: workingNode,
          blackOrientation: blackOrientation,
        ),
      );
    } catch (e) {
      AppLogger.log('[TutorialDraft] ❌ Čuvanje nije uspelo: $e');
    }
  }

  Future<TutorialDraftRestore?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final treeJson = map['workingTree'];
      if (treeJson is! Map) return null;

      final tree = AnalysisNode.fromJson(Map<String, dynamic>.from(treeJson));
      final draft = TutorialDraft.fromJson(
          Map<String, dynamic>.from((map['draft'] as Map?) ?? const {}));

      // A bare position with no moves and no examples is not a tutorial anybody
      // started; restoring it would put a stale board in front of a trainer who
      // asked for a blank one. **Unlike the analysis draft, the examples alone
      // are enough**: a trainer who wrote two examples and is standing on a
      // fresh position for the third has done the most work of anyone here.
      if (tree.children.isEmpty && draft.examples.isEmpty) return null;

      return TutorialDraftRestore(
        draft: draft,
        workingTree: tree,
        workingPath: ((map['workingPath'] as List?) ?? const [])
            .whereType<int>()
            .toList(),
        blackOrientation: map['blackOrientation'] == true,
      );
    } catch (e) {
      AppLogger.log('[TutorialDraft] ❌ Učitavanje nije uspelo: $e');
      return null;
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      AppLogger.log('[TutorialDraft] ❌ Brisanje nije uspelo: $e');
    }
  }

  String _encode({
    required TutorialDraft draft,
    required AnalysisNode workingTree,
    required AnalysisNode workingNode,
    required bool blackOrientation,
  }) =>
      jsonEncode({
        'draft': draft.toJson(),
        'workingTree': workingTree.toJson(),
        'workingPath': _pathTo(workingTree, workingNode),
        'blackOrientation': blackOrientation,
        'savedAt': DateTime.now().toIso8601String(),
      });

  List<int> _pathTo(AnalysisNode root, AnalysisNode target) {
    final path = <int>[];
    var node = target;
    while (node.parent != null) {
      final parent = node.parent!;
      final index = parent.children.indexWhere((c) => c.id == node.id);
      if (index < 0) return const [];
      path.insert(0, index);
      node = parent;
    }
    // Guard against a target that belongs to a different tree.
    return node.id == root.id ? path : const [];
  }
}
