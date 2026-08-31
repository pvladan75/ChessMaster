import 'package:flutter/foundation.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'analysis_node.dart';

/// A [MoveCursor] over the Analysis Studio's own tree, jumping through
/// [onSelect].
///
/// [first] is deliberately not "the root of the game". In a studio full of
/// variations, the useful jump back is to the point the current line branched
/// off — walking all the way out to move one throws away where you were. That
/// is the behaviour the studio's `<<` button always had; it lives here now so
/// the shared strip does not have to know about it.
class AnalysisNodeCursor implements MoveCursor {
  final AnalysisNode currentNode;
  final ValueChanged<AnalysisNode> onSelect;

  const AnalysisNodeCursor({required this.currentNode, required this.onSelect});

  @override
  bool get canGoBack => !currentNode.isRoot;

  @override
  bool get canGoForward => currentNode.children.isNotEmpty;

  @override
  String? get currentFen => currentNode.fen;

  @override
  void first() => onSelect(_nearestLineStart(currentNode));

  @override
  void previous() {
    final parent = currentNode.parent;
    if (parent != null) onSelect(parent);
  }

  @override
  void next() {
    if (currentNode.children.isNotEmpty) onSelect(currentNode.children.first);
  }

  @override
  void last() {
    var curr = currentNode;
    while (curr.children.isNotEmpty) {
      curr = curr.children.first;
    }
    onSelect(curr);
  }

  /// Every move out of this node, in the order the tree holds them — the main
  /// line first. The label is the one the tree's own cards carry, marks
  /// included, so the choice reads the same wherever it is made.
  @override
  List<MoveBranch> get forwardBranches => [
        for (var i = 0; i < currentNode.children.length; i++)
          MoveBranch(
            label: '${currentNode.children[i].moveSan ?? ""}'
                '${currentNode.children[i].nag ?? ""}',
            isMain: i == 0,
          ),
      ];

  @override
  void takeBranch(int index) {
    if (index < 0 || index >= currentNode.children.length) return next();
    onSelect(currentNode.children[index]);
  }

  /// Walks up from [node] to the nearest ancestor that is itself a branch
  /// point (has more than one child) — i.e. the node the current line
  /// diverged from. If the path back to the root never branches, that's
  /// effectively the same as "the line's start", so this falls back to it.
  static AnalysisNode _nearestLineStart(AnalysisNode node) {
    var cur = node;
    while (!cur.isRoot) {
      final parent = cur.parent!;
      if (parent.children.length > 1) return parent;
      cur = parent;
    }
    return cur;
  }
}
