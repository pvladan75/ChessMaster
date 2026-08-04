import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:chess_app/move_tree.dart';

class MoveHistoryView extends StatelessWidget {
  final MoveTree moveTree;
  final MoveNode currentNode;
  final Function(MoveNode node) onSelectNode;

  const MoveHistoryView({
    super.key,
    required this.moveTree,
    required this.currentNode,
    required this.onSelectNode,
  });

  List<InlineSpan> _buildSpans(MoveNode node, BuildContext context) {
    final List<InlineSpan> spans = [];
    _collectSpans(node, spans, context, true);
    return spans;
  }

  void _collectSpans(MoveNode node, List<InlineSpan> spans, BuildContext context, bool showMoveNumber) {
    if (node.children.isEmpty) return;

    final mainChild = node.children[0];
    final parts = node.fen.split(' ');
    final isWhite = parts.length > 1 ? parts[1] == 'w' : true;
    final moveNum = parts.length > 5 ? (int.tryParse(parts[5]) ?? 1) : 1;

    if (isWhite) {
      spans.add(TextSpan(
        text: '$moveNum. ',
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
      ));
    } else if (showMoveNumber) {
      spans.add(TextSpan(
        text: '$moveNum... ',
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
      ));
    }

    final isMainActive = currentNode == mainChild;

    spans.add(TextSpan(
      text: '${mainChild.san} ',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: isMainActive ? Colors.greenAccent : Colors.white,
        backgroundColor: isMainActive ? Colors.green.withOpacity(0.3) : Colors.transparent,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => onSelectNode(mainChild),
    ));

    if (mainChild.comment.isNotEmpty) {
      spans.add(TextSpan(
        text: '{${mainChild.comment}} ',
        style: const TextStyle(color: Colors.yellowAccent, fontStyle: FontStyle.italic, fontSize: 12),
      ));
    }

    // Variations
    for (int i = 1; i < node.children.length; i++) {
      final varChild = node.children[i];
      spans.add(const TextSpan(
        text: '( ',
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ));

      if (isWhite) {
        spans.add(TextSpan(
          text: '$moveNum. ',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ));
      } else {
        spans.add(TextSpan(
          text: '$moveNum... ',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ));
      }

      final isVarActive = currentNode == varChild;

      spans.add(TextSpan(
        text: '${varChild.san} ',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: isVarActive ? Colors.greenAccent : Colors.grey[400],
          backgroundColor: isVarActive ? Colors.green.withOpacity(0.3) : Colors.transparent,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onSelectNode(varChild),
      ));

      if (varChild.comment.isNotEmpty) {
        spans.add(TextSpan(
          text: '{${varChild.comment}} ',
          style: const TextStyle(color: Colors.yellowAccent, fontStyle: FontStyle.italic, fontSize: 10),
        ));
      }

      _collectSpans(varChild, spans, context, false);

      spans.add(const TextSpan(
        text: ') ',
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ));
    }

    final nextShowMoveNumber = node.children.length > 1;
    _collectSpans(mainChild, spans, context, nextShowMoveNumber);
  }

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = _buildSpans(moveTree.root, context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: spans.isEmpty
          ? const Center(
              child: Text(
                'Nema odigranih poteza.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: RichText(
                text: TextSpan(
                  children: spans,
                ),
              ),
            ),
    );
  }
}
