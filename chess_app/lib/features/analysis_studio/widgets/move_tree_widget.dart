import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';

class AnalysisMoveTreeWidget extends StatefulWidget {
  final AnalysisNode rootNode;
  final AnalysisNode activeNode;
  final Function(AnalysisNode node) onSelectNode;
  final Function(AnalysisNode node)? onPromoteNode;
  final Function(AnalysisNode node)? onDeleteNode;

  const AnalysisMoveTreeWidget({
    super.key,
    required this.rootNode,
    required this.activeNode,
    required this.onSelectNode,
    this.onPromoteNode,
    this.onDeleteNode,
  });

  @override
  State<AnalysisMoveTreeWidget> createState() => _AnalysisMoveTreeWidgetState();
}

class _AnalysisMoveTreeWidgetState extends State<AnalysisMoveTreeWidget> {
  bool _showVisualGraph = true; // Default to interactive visual tree graph!

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_tree, color: Colors.tealAccent, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Stablo Varijanti',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Mode selector toggle buttons
                    InkWell(
                      onTap: () => setState(() => _showVisualGraph = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showVisualGraph ? Colors.teal.shade800 : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _showVisualGraph ? Colors.tealAccent : Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bar_chart, size: 13, color: Colors.tealAccent),
                            SizedBox(width: 3),
                            Text('Grafičko', style: TextStyle(fontSize: 11, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _showVisualGraph = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_showVisualGraph ? Colors.teal.shade800 : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: !_showVisualGraph ? Colors.tealAccent : Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notes, size: 13, color: Colors.tealAccent),
                            SizedBox(width: 3),
                            Text('PGN', style: TextStyle(fontSize: 11, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, color: Colors.white24),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              width: double.infinity,
              child: _showVisualGraph
                  ? VisualMoveTreeWidget(
                      rootNode: widget.rootNode,
                      activeNode: widget.activeNode,
                      onSelectNode: widget.onSelectNode,
                      onPromoteNode: widget.onPromoteNode,
                      onDeleteNode: widget.onDeleteNode,
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 4.0,
                        runSpacing: 6.0,
                        children: _buildTreeSpans(context, widget.rootNode, 1),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTreeSpans(BuildContext context, AnalysisNode current, int moveNumber) {
    final List<Widget> widgets = [];

    if (current.children.isEmpty) return widgets;

    // Main line child (0th child)
    final mainChild = current.children.first;
    final isWhiteMove = current.fen.contains(' w ');
    final isSelected = mainChild.id == widget.activeNode.id;

    final moveNumStr = isWhiteMove ? '$moveNumber. ' : '';

    widgets.add(
      InkWell(
        onTap: () => widget.onSelectNode(mainChild),
        onLongPress: () => _showNodeContextMenu(context, mainChild),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade800 : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
            border: isSelected ? Border.all(color: Colors.tealAccent, width: 1.5) : null,
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white),
              children: [
                if (moveNumStr.isNotEmpty)
                  TextSpan(text: moveNumStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                TextSpan(
                  text: mainChild.moveSan ?? '',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.tealAccent : Colors.white,
                  ),
                ),
                if (mainChild.nag != null)
                  TextSpan(
                    text: ' ${mainChild.nag!}',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                  ),
                if (mainChild.comment.isNotEmpty)
                  TextSpan(
                    text: ' {${mainChild.comment}}',
                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Render variations (children at index >= 1)
    if (current.children.length > 1) {
      for (int i = 1; i < current.children.length; i++) {
        final varChild = current.children[i];
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade900.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.purpleAccent.shade100, width: 0.8),
            ),
            child: InkWell(
              onTap: () => widget.onSelectNode(varChild),
              onLongPress: () => _showNodeContextMenu(context, varChild),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('(', style: TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                  Text(
                    '${isWhiteMove ? "$moveNumber..." : ""}${varChild.moveSan ?? ""}${varChild.nag ?? ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: varChild.id == widget.activeNode.id ? FontWeight.bold : FontWeight.normal,
                      color: varChild.id == widget.activeNode.id ? Colors.amberAccent : Colors.purpleAccent.shade100,
                    ),
                  ),
                  const Text(')', style: TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Continue down main line recursively
    final nextMoveNum = isWhiteMove ? moveNumber : moveNumber + 1;
    widgets.addAll(_buildTreeSpans(context, mainChild, nextMoveNum));

    return widgets;
  }

  void _showNodeContextMenu(BuildContext context, AnalysisNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amberAccent),
                title: const Text('Unapredi u Glavnu Liniju (Main Line)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (node.parent != null) {
                    widget.onPromoteNode?.call(node);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Obriši Ovu Varijantu', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteNode?.call(node);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
