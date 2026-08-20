import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';

/// One position on the walked line, as the navigation strip offers it.
///
/// The strip never learns what a move *is* — only its label and what to call
/// when it is tapped — which is what lets three unrelated move models share
/// one row of buttons.
class MoveStop {
  final String label;
  final bool isCurrent;
  final VoidCallback onSelect;

  /// Small leading icon, used for the "Početak" stop so it reads as a marker
  /// rather than as a move.
  final IconData? icon;

  const MoveStop({
    required this.label,
    required this.isCurrent,
    required this.onSelect,
    this.icon,
  });
}

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

  /// The line walked so far, oldest first, for the optional chip strip.
  /// Empty means this screen offers no chips.
  List<MoveStop> get line => const [];
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
  List<MoveStop> get line {
    final path = <MoveNode>[];
    MoveNode? curr = currentNode;
    while (curr != null && curr.parent != null) {
      path.insert(0, curr);
      curr = curr.parent;
    }

    return [
      MoveStop(
        label: 'Početak',
        isCurrent: currentNode == moveTree.root,
        onSelect: first,
        icon: Icons.flag,
      ),
      for (final node in path)
        MoveStop(
          label: formatMoveWithNumber(node, moveTree.root),
          isCurrent: node == currentNode,
          onSelect: () => onSelect(node),
        ),
    ];
  }
}

/// A cursor over a line replayed into a list of positions: [fens] holds the
/// starting position followed by one entry per move, so index 0 is "before the
/// first move" and [fens].length - 1 is the end.
///
/// The end is taken from [fens] rather than from [movesSan] on purpose. The two
/// come from the same parse and normally agree, but if they ever did not, a
/// bound read off the labels would walk past the last position it can show.
class LinearMoveCursor implements MoveCursor {
  final List<String> fens;

  /// One label per move, in order. May be empty — then the strip still walks,
  /// it just cannot offer chips.
  final List<String> movesSan;

  /// Where the cursor stands: 0 is the starting position.
  final int index;

  /// Called with the position index to move to. The screen clamps and applies.
  final ValueChanged<int> onSeek;

  const LinearMoveCursor({
    required this.fens,
    required this.index,
    required this.onSeek,
    this.movesSan = const [],
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

  @override
  List<MoveStop> get line {
    if (fens.isEmpty || movesSan.isEmpty) return const [];
    final rootFen = fens.first;

    return [
      MoveStop(
        label: 'Početak',
        isCurrent: index == 0,
        onSelect: first,
        icon: Icons.flag,
      ),
      for (var ply = 0; ply < movesSan.length; ply++)
        MoveStop(
          label: formatSanAtPly(rootFen: rootFen, ply: ply, san: movesSan[ply]),
          isCurrent: index == ply + 1,
          onSelect: () => onSeek(ply + 1),
        ),
    ];
  }
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
