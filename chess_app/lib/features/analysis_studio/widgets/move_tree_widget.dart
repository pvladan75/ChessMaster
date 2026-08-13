import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

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
      color: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_tree, color: context.colors.accent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Stablo Varijanti',
                      style: AppText.bodyLargeBold.copyWith(color: context.colors.textPrimary),
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
                          border: Border.all(color: _showVisualGraph ? context.colors.accent : context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bar_chart, size: 13, color: context.colors.accent),
                            const SizedBox(width: 3),
                            Text('Grafičko', style: AppText.caption.copyWith(color: context.colors.textPrimary)),
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
                          border: Border.all(color: !_showVisualGraph ? context.colors.accent : context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notes, size: 13, color: context.colors.accent),
                            const SizedBox(width: 3),
                            Text('PGN', style: AppText.caption.copyWith(color: context.colors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    if (_showVisualGraph) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _openFullscreen(context),
                        tooltip: 'Prikaži preko celog ekrana',
                        icon: Icon(Icons.open_in_full, size: 16, color: context.colors.accent),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Divider(height: 16, color: context.colors.border),
            Container(
              constraints: const BoxConstraints(maxHeight: 420),
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

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: dialogContext.colors.surface,
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(dialogContext).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_tree, color: dialogContext.colors.accent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Stablo Varijanti',
                            style: AppText.subtitle.copyWith(color: dialogContext.colors.textPrimary),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close, color: dialogContext.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: dialogContext.colors.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: VisualMoveTreeWidget(
                      rootNode: widget.rootNode,
                      activeNode: widget.activeNode,
                      onSelectNode: (node) {
                        widget.onSelectNode(node);
                        Navigator.pop(dialogContext);
                      },
                      onPromoteNode: widget.onPromoteNode,
                      onDeleteNode: widget.onDeleteNode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            border: isSelected ? Border.all(color: context.colors.accent, width: 1.5) : null,
          ),
          child: RichText(
            text: TextSpan(
              style: AppText.bodyLarge.copyWith(color: context.colors.textPrimary),
              children: [
                if (moveNumStr.isNotEmpty)
                  TextSpan(text: moveNumStr, style: AppText.caption.copyWith(color: context.colors.textMuted)),
                TextSpan(
                  text: mainChild.moveSan ?? '',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? context.colors.accent : context.colors.textPrimary,
                  ),
                ),
                if (mainChild.nag != null)
                  TextSpan(
                    text: ' ${mainChild.nag!}',
                    style: TextStyle(color: context.colors.warning, fontWeight: FontWeight.bold),
                  ),
                if (mainChild.comment.isNotEmpty)
                  TextSpan(
                    text: ' {${mainChild.comment}}',
                    style: AppText.caption.copyWith(color: context.colors.info, fontStyle: FontStyle.italic),
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
                  Text('(', style: AppText.caption.copyWith(color: context.colors.accentAlt)),
                  Text(
                    '${isWhiteMove ? "$moveNumber..." : ""}${varChild.moveSan ?? ""}${varChild.nag ?? ""}',
                    style: AppText.body.copyWith(
                      fontWeight: varChild.id == widget.activeNode.id ? FontWeight.bold : FontWeight.normal,
                      color: varChild.id == widget.activeNode.id ? context.colors.warning : Colors.purpleAccent.shade100,
                    ),
                  ),
                  Text(')', style: AppText.caption.copyWith(color: context.colors.accentAlt)),
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
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.star, color: ctx.colors.warning),
                title: Text('Unapredi u Glavnu Liniju (Main Line)', style: TextStyle(color: ctx.colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (node.parent != null) {
                    widget.onPromoteNode?.call(node);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: ctx.colors.danger),
                title: Text('Obriši Ovu Varijantu', style: TextStyle(color: ctx.colors.textPrimary)),
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
