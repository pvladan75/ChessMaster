import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';

/// First/prev/next/last toolbar for walking the game's move tree.
class MoveNavigationControls extends StatelessWidget {
  final MoveTree moveTree;
  final MoveNode currentNode;
  final bool canNavigate;
  final ValueChanged<MoveNode> onSelectNode;
  final VoidCallback onFlipBoard;

  const MoveNavigationControls({
    super.key,
    required this.moveTree,
    required this.currentNode,
    required this.canNavigate,
    required this.onSelectNode,
    required this.onFlipBoard,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentNode != moveTree.root;
    final canGoForward = currentNode.children.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: canNavigate && canGoBack
                ? () => onSelectNode(moveTree.root)
                : null,
            tooltip: 'Idi na početak',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: canNavigate && canGoBack
                ? () => onSelectNode(currentNode.parent!)
                : null,
            tooltip: 'Prethodni potez',
          ),
          const Text(
            'Navigacija',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: canNavigate && canGoForward
                ? () => onSelectNode(currentNode.children[0])
                : null,
            tooltip: 'Sledeći potez',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: canNavigate && canGoForward
                ? () {
                    MoveNode curr = currentNode;
                    while (curr.children.isNotEmpty) {
                      curr = curr.children[0];
                    }
                    onSelectNode(curr);
                  }
                : null,
            tooltip: 'Idi na kraj',
          ),
          IconButton(
            icon: const Icon(Icons.flip),
            onPressed: onFlipBoard,
            tooltip: 'Okreni tablu',
          ),
        ],
      ),
    );
  }
}
