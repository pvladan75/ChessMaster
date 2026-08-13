import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';

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

  final rootFen = rootNode.fen;
  final rootParts = rootFen.split(' ');
  final rootIsWhite = rootParts.length > 1 ? (rootParts[1] == 'w') : true;
  final rootMoveNum = rootParts.length > 5 ? (int.tryParse(rootParts[5]) ?? 1) : 1;

  final moveIndex = path.indexOf(node);
  if (moveIndex < 0) return node.san;

  int currentMoveNum;
  bool isWhiteMove;

  if (rootIsWhite) {
    currentMoveNum = rootMoveNum + (moveIndex ~/ 2);
    isWhiteMove = (moveIndex % 2 == 0);
  } else {
    currentMoveNum = rootMoveNum + ((moveIndex + 1) ~/ 2);
    isWhiteMove = (moveIndex % 2 == 1);
  }

  if (isWhiteMove) {
    return '$currentMoveNum. ${node.san}';
  } else {
    if (moveIndex == 0 && !rootIsWhite) {
      return '$currentMoveNum... ${node.san}';
    } else {
      return node.san;
    }
  }
}

/// Chip row + prev/next toolbar for walking the puzzle's played move tree.
class MoveHistoryNavigationWidget extends StatelessWidget {
  final MoveTree? moveTree;
  final ValueChanged<MoveNode> onNavigate;

  const MoveHistoryNavigationWidget({
    super.key,
    required this.moveTree,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final tree = moveTree;
    if (tree == null) return const SizedBox.shrink();

    final currentNode = tree.current;
    final mainLineNodes = <MoveNode>[];
    MoveNode? curr = currentNode;
    while (curr != null && curr.parent != null) {
      mainLineNodes.insert(0, curr);
      curr = curr.parent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.flag, size: 14, color: Colors.amberAccent),
                  label: const Text('Početak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: currentNode == tree.root ? Colors.amber.shade900 : Colors.blueGrey.shade800,
                  onPressed: () => onNavigate(tree.root),
                ),
                const SizedBox(width: 6),
                ...mainLineNodes.map((node) {
                  final isCurrent = (node == currentNode);
                  final labelText = formatMoveWithNumber(node, tree.root);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(labelText, style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? Colors.white : Colors.white70)),
                      selected: isCurrent,
                      selectedColor: Colors.teal.shade700,
                      backgroundColor: Colors.blueGrey.shade800,
                      onSelected: (_) => onNavigate(node),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'Početna pozicija',
                onPressed: () => onNavigate(tree.root),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Prethodni potez',
                onPressed: currentNode.parent != null ? () => onNavigate(currentNode.parent!) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Naredni potez',
                onPressed: currentNode.children.isNotEmpty ? () => onNavigate(currentNode.children.first) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Poslednji potez',
                onPressed: () {
                  MoveNode target = currentNode;
                  while (target.children.isNotEmpty) {
                    target = target.children.first;
                  }
                  onNavigate(target);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
