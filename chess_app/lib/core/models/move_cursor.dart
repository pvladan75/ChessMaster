import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';

/// Walking a line of moves, independent of how those moves are stored.
///
/// Three models sit underneath the screens of this app — a [MoveTree] (lesson
/// room, AI Studio), a linear list of FENs with an index (lesson viewer, review
/// session), and the Analysis Studio's own `AnalysisNode` tree. Each screen
/// grew its own first/prev/next/last row against its own model, which is how
/// six copies of the same four buttons appeared, with different icons and
/// different tooltips for identical actions.
///
/// A cursor is built fresh in `build()` from whatever the screen currently
/// holds; its methods call back into the screen, which does its own `setState`.
/// So it carries no state of its own and nothing has to be kept in sync.
///
/// Implementations: [MoveTreeCursor] and [LinearMoveCursor] below, and
/// `AnalysisNodeCursor` in `lib/features/analysis_studio/models/`, which lives
/// beside its model rather than here so this file stays free of the feature.
abstract class MoveCursor {
  bool get canGoBack;
  bool get canGoForward;

  void first();
  void previous();
  void next();
  void last();

  /// The position the cursor is standing on, or null when there is no line to
  /// stand on at all.
  String? get currentFen;

  /// The moves that lead forward from here.
  ///
  /// One entry means "forward" has one meaning and nobody should be asked
  /// anything. **More than one is a fork**, and a strip that walks into the
  /// first of them every time is a strip on which the other lines cannot be
  /// reached at all — which is exactly what the owner found in the repertoire:
  /// a position with two replies and no way to navigate into the second.
  ///
  /// Empty is also an answer, and it means the same as one: nothing to choose.
  /// A model with no branches (a replayed game, a lesson) says so by leaving
  /// this empty and never sees a question.
  ///
  /// Given a body rather than left abstract so that a cursor written for one
  /// screen — or for a test — does not have to know about forks to compile. A
  /// model that branches overrides it; one that does not is right by default,
  /// which is the way round that cannot produce a wrong answer.
  List<MoveBranch> get forwardBranches => const [];

  /// Takes the branch at [index] of [forwardBranches]. Out of range is
  /// [next], because a stale index must move the board rather than break it.
  void takeBranch(int index) => next();
}

/// One of the moves leading forward from a position, as a chooser shows it.
///
/// The label is whatever the screen already writes on that move — SAN, and the
/// marks it carries there — so the choice is made with the same facts and in
/// the same words as everywhere else that move appears.
class MoveBranch {
  const MoveBranch({required this.label, this.detail, this.isMain = false});

  final String label;

  /// A second line, where the screen has something worth saying about the
  /// branch: how often it is played, what state it leads to. Optional, because
  /// most models have nothing to add.
  final String? detail;

  /// The move that would have been taken without asking. Marked rather than
  /// preselected: the point is that the others are reachable.
  final bool isMain;
}

/// A cursor over a [MoveTree], selecting nodes through [onSelect].
///
/// [first] goes to the tree's root, and [last] to the end of the line the
/// cursor is currently on — following first children, never jumping into a
/// sibling variation.
class MoveTreeCursor implements MoveCursor {
  final MoveTree moveTree;
  final MoveNode currentNode;
  final ValueChanged<MoveNode> onSelect;

  const MoveTreeCursor({
    required this.moveTree,
    required this.currentNode,
    required this.onSelect,
  });

  @override
  bool get canGoBack => currentNode != moveTree.root;

  @override
  bool get canGoForward => currentNode.children.isNotEmpty;

  @override
  String? get currentFen => currentNode.fen;

  @override
  void first() => onSelect(moveTree.root);

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

  @override
  List<MoveBranch> get forwardBranches => [
        for (var i = 0; i < currentNode.children.length; i++)
          MoveBranch(label: currentNode.children[i].san, isMain: i == 0),
      ];

  @override
  void takeBranch(int index) {
    if (index < 0 || index >= currentNode.children.length) return next();
    onSelect(currentNode.children[index]);
  }
}

/// A cursor over a line replayed into a list of positions: [fens] holds the
/// starting position followed by one entry per move, so index 0 is "before the
/// first move" and [fens].length - 1 is the end.
class LinearMoveCursor implements MoveCursor {
  final List<String> fens;

  /// Where the cursor stands: 0 is the starting position.
  final int index;

  /// Called with the position index to move to. The screen clamps and applies.
  final ValueChanged<int> onSeek;

  const LinearMoveCursor({
    required this.fens,
    required this.index,
    required this.onSeek,
  });

  int get _lastIndex => fens.isEmpty ? 0 : fens.length - 1;

  @override
  bool get canGoBack => fens.isNotEmpty && index > 0;

  @override
  bool get canGoForward => index < _lastIndex;

  @override
  String? get currentFen =>
      fens.isEmpty ? null : fens[index.clamp(0, _lastIndex)];

  @override
  void first() => onSeek(0);

  @override
  void previous() => onSeek(index - 1);

  @override
  void next() => onSeek(index + 1);

  @override
  void last() => onSeek(_lastIndex);

  /// A replayed line does not branch: there is one move forward and it is the
  /// next position in the list. Left empty so nobody is ever asked a question
  /// with one answer.
  @override
  List<MoveBranch> get forwardBranches => const [];

  @override
  void takeBranch(int index) => next();
}

/// Formats [node]'s SAN with its move number relative to [rootNode], the way
/// PGN notation does ("12. Nf3", "12... Nf3" only for Black's first move,
/// otherwise bare "Nf3").
String formatMoveWithNumber(MoveNode node, MoveNode rootNode) {
  if (node.parent == null) return 'Početak';

  final path = <MoveNode>[];
  MoveNode? curr = node;
  while (curr != null && curr.parent != null) {
    path.insert(0, curr);
    curr = curr.parent;
  }

  final moveIndex = path.indexOf(node);
  if (moveIndex < 0) return node.san;

  return formatSanAtPly(rootFen: rootNode.fen, ply: moveIndex, san: node.san);
}

/// The same numbering, for models that count plies instead of walking parents.
/// [ply] is 0 for the first move played from [rootFen].
String formatSanAtPly({
  required String rootFen,
  required int ply,
  required String san,
}) {
  final rootParts = rootFen.split(' ');
  final rootIsWhite = rootParts.length > 1 ? (rootParts[1] == 'w') : true;
  final rootMoveNum =
      rootParts.length > 5 ? (int.tryParse(rootParts[5]) ?? 1) : 1;

  final int currentMoveNum;
  final bool isWhiteMove;
  if (rootIsWhite) {
    currentMoveNum = rootMoveNum + (ply ~/ 2);
    isWhiteMove = ply % 2 == 0;
  } else {
    currentMoveNum = rootMoveNum + ((ply + 1) ~/ 2);
    isWhiteMove = ply % 2 == 1;
  }

  if (isWhiteMove) return '$currentMoveNum. $san';
  // Only the first Black move of a line needs the "12..." form; after a White
  // move has just been listed, a bare SAN reads correctly.
  if (ply == 0) return '$currentMoveNum... $san';
  return san;
}
