import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/board_flip_button.dart';

/// First/prev/next/last toolbar for walking a [MoveTree], with an optional
/// strip of tappable move chips above it and an optional flip button.
///
/// This is the one navigation strip for every screen whose moves live in a
/// [MoveTree]. It used to be two — this one for the lesson session and a
/// near-identical `MoveHistoryNavigationWidget` for the AI Studio — which had
/// drifted into different icons (`navigate_before` vs `chevron_left`) and
/// different chrome for the same four buttons. Screens on other move models
/// (the linear index in the lesson viewer and review session, the
/// `AnalysisNode` tree in the Analysis Studio) still have their own; they need
/// a cursor abstraction before they can share this.
class MoveNavigationControls extends StatelessWidget {
  final MoveTree moveTree;
  final MoveNode currentNode;
  final ValueChanged<MoveNode> onSelectNode;

  /// Disables every control. Used in a room where this seat may not drive the
  /// shared board, since navigating broadcasts the position to everyone.
  final bool canNavigate;

  /// Omitted where the screen has no board orientation to flip.
  final VoidCallback? onFlipBoard;

  /// Shows the played line as tappable chips above the buttons — worth the
  /// vertical space when jumping several moves back is the common action, as
  /// in puzzle solving.
  final bool showMoveChips;

  /// Label between the back and forward buttons. Hidden when chips are shown,
  /// since the chips already say where you are.
  final String? centerLabel;

  const MoveNavigationControls({
    super.key,
    required this.moveTree,
    required this.currentNode,
    required this.onSelectNode,
    this.canNavigate = true,
    this.onFlipBoard,
    this.showMoveChips = false,
    this.centerLabel = 'Navigacija',
  });

  MoveNode _lastOfLine(MoveNode from) {
    var curr = from;
    while (curr.children.isNotEmpty) {
      curr = curr.children.first;
    }
    return curr;
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentNode != moveTree.root;
    final canGoForward = currentNode.children.isNotEmpty;

    final buttons = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.first_page),
          onPressed: canNavigate && canGoBack ? () => onSelectNode(moveTree.root) : null,
          tooltip: 'Idi na početak',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: canNavigate && canGoBack ? () => onSelectNode(currentNode.parent!) : null,
          tooltip: 'Prethodni potez',
        ),
        if (!showMoveChips && centerLabel != null)
          Text(centerLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canNavigate && canGoForward ? () => onSelectNode(currentNode.children.first) : null,
          tooltip: 'Sledeći potez',
        ),
        IconButton(
          icon: const Icon(Icons.last_page),
          onPressed: canNavigate && canGoForward ? () => onSelectNode(_lastOfLine(currentNode)) : null,
          tooltip: 'Idi na kraj',
        ),
        if (onFlipBoard != null) BoardFlipButton(onPressed: onFlipBoard!),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMoveChips) ...[
            _MoveChipStrip(
              moveTree: moveTree,
              currentNode: currentNode,
              canNavigate: canNavigate,
              onSelectNode: onSelectNode,
            ),
            const SizedBox(height: 6),
          ],
          buttons,
        ],
      ),
    );
  }
}

/// The played line as chips, oldest first, with the current move selected.
class _MoveChipStrip extends StatelessWidget {
  final MoveTree moveTree;
  final MoveNode currentNode;
  final bool canNavigate;
  final ValueChanged<MoveNode> onSelectNode;

  const _MoveChipStrip({
    required this.moveTree,
    required this.currentNode,
    required this.canNavigate,
    required this.onSelectNode,
  });

  @override
  Widget build(BuildContext context) {
    final lineToHere = <MoveNode>[];
    MoveNode? curr = currentNode;
    while (curr != null && curr.parent != null) {
      lineToHere.insert(0, curr);
      curr = curr.parent;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.flag, size: 14),
            label: const Text('Početak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: canNavigate ? () => onSelectNode(moveTree.root) : null,
          ),
          const SizedBox(width: 6),
          ...lineToHere.map((node) {
            final isCurrent = node == currentNode;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: ChoiceChip(
                label: Text(
                  formatMoveWithNumber(node, moveTree.root),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isCurrent,
                onSelected: canNavigate ? (_) => onSelectNode(node) : null,
              ),
            );
          }),
        ],
      ),
    );
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

  final rootParts = rootNode.fen.split(' ');
  final rootIsWhite = rootParts.length > 1 ? (rootParts[1] == 'w') : true;
  final rootMoveNum = rootParts.length > 5 ? (int.tryParse(rootParts[5]) ?? 1) : 1;

  final moveIndex = path.indexOf(node);
  if (moveIndex < 0) return node.san;

  final int currentMoveNum;
  final bool isWhiteMove;
  if (rootIsWhite) {
    currentMoveNum = rootMoveNum + (moveIndex ~/ 2);
    isWhiteMove = moveIndex % 2 == 0;
  } else {
    currentMoveNum = rootMoveNum + ((moveIndex + 1) ~/ 2);
    isWhiteMove = moveIndex % 2 == 1;
  }

  if (isWhiteMove) return '$currentMoveNum. ${node.san}';
  // Only the first Black move of a line needs the "12..." form; after a White
  // move has just been listed, a bare SAN reads correctly.
  if (moveIndex == 0) return '$currentMoveNum... ${node.san}';
  return node.san;
}
