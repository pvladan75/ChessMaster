import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

class VisualMoveTreeWidget extends StatelessWidget {
  final AnalysisNode rootNode;
  final AnalysisNode activeNode;
  final Function(AnalysisNode node) onSelectNode;
  final Function(AnalysisNode node)? onPromoteNode;
  final Function(AnalysisNode node)? onDeleteNode;

  const VisualMoveTreeWidget({
    super.key,
    required this.rootNode,
    required this.activeNode,
    required this.onSelectNode,
    this.onPromoteNode,
    this.onDeleteNode,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: _buildTreeBranch(context, rootNode, isMainLine: true, depth: 0),
        ),
      ),
    );
  }

  Widget _buildTreeBranch(BuildContext context, AnalysisNode node, {required bool isMainLine, required int depth}) {
    if (node.children.isEmpty && node.isRoot) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text('🏁 Startna pozicija', style: TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }

    final List<Widget> columnChildren = [];

    // Render node card
    if (!node.isRoot) {
      columnChildren.add(_buildNodeCard(context, node, isMainLine: isMainLine));
    } else {
      columnChildren.add(
        InkWell(
          onTap: () => onSelectNode(node),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: node.id == activeNode.id ? Colors.teal.shade900 : Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: node.id == activeNode.id ? Colors.tealAccent : Colors.white24,
                width: node.id == activeNode.id ? 1.5 : 1.0,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag, size: 14, color: Colors.tealAccent),
                SizedBox(width: 4),
                Text('Start', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    // Children branches
    if (node.children.isNotEmpty) {
      final List<Widget> childrenWidgets = [];

      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final isChildMain = isMainLine && i == 0;

        childrenWidgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Connector line
              CustomPaint(
                size: const Size(16, 34),
                painter: BranchLinePainter(
                  isFirst: i == 0,
                  isLast: i == node.children.length - 1,
                  isMainLine: isChildMain,
                ),
              ),
              const SizedBox(width: 4),
              _buildTreeBranch(context, child, isMainLine: isChildMain, depth: depth + 1),
            ],
          ),
        );
      }

      columnChildren.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: childrenWidgets,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: columnChildren,
    );
  }

  Widget _buildNodeCard(BuildContext context, AnalysisNode node, {required bool isMainLine}) {
    final isSelected = node.id == activeNode.id;
    final parentFen = node.parent?.fen ?? '';
    final isWhiteMove = parentFen.contains(' w ');

    // Color theme
    final cardBg = isSelected
        ? Colors.teal.shade800
        : (isMainLine ? Colors.grey.shade900 : Colors.purple.shade900.withValues(alpha: 0.8));
    final borderColor = isSelected
        ? Colors.tealAccent
        : (isMainLine ? Colors.teal.shade600 : Colors.purpleAccent.shade100);

    // Eval formatting
    String evalText = '';
    Color evalBg = Colors.grey.shade700;
    Color evalTextColor = Colors.white;

    if (node.eval != null) {
      final val = node.eval!;
      if (val.abs() > 500) {
        final mateIn = (1000 - val.abs()).round();
        evalText = val > 0 ? 'M$mateIn' : '-M$mateIn';
        evalBg = val > 0 ? Colors.amber.shade800 : Colors.red.shade900;
      } else {
        evalText = val > 0 ? '+${val.toStringAsFixed(2)}' : val.toStringAsFixed(2);
        if (val > 0.3) {
          evalBg = Colors.green.shade800;
        } else if (val < -0.3) {
          evalBg = Colors.red.shade800;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: InkWell(
        onTap: () => onSelectNode(node),
        onLongPress: () => _showNodeContextMenu(context, node),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isWhiteMove ? "" : "..."}${node.moveSan ?? ""}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (node.nag != null) ...[
                const SizedBox(width: 3),
                Text(
                  node.nag!,
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
              if (evalText.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: evalBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    evalText,
                    style: TextStyle(color: evalTextColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
                    onPromoteNode?.call(node);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Obriši Ovu Varijantu', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDeleteNode?.call(node);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class BranchLinePainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final bool isMainLine;

  BranchLinePainter({
    required this.isFirst,
    required this.isLast,
    required this.isMainLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isMainLine ? Colors.tealAccent.withValues(alpha: 0.7) : Colors.purpleAccent.withValues(alpha: 0.5)
      ..strokeWidth = isMainLine ? 2.0 : 1.2
      ..style = PaintingStyle.stroke;

    final startX = 0.0;
    final endX = size.width;
    final midY = size.height / 2;

    final path = Path();
    path.moveTo(startX, 0);
    path.lineTo(startX, midY);
    path.lineTo(endX, midY);

    if (!isLast) {
      path.moveTo(startX, midY);
      path.lineTo(startX, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BranchLinePainter oldDelegate) {
    return oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.isMainLine != isMainLine;
  }
}
