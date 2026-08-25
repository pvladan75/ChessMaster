import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class SolutionGraphNode {
  final String id;
  final String moveUci;
  final String moveSan;
  final String fen;
  final String? parentFen;
  final bool isWhite;
  final bool isCheckmate;
  final bool isGrouped;
  int selectedGroupedIndex;
  final List<String> groupedOpponentMoves;
  final List<String> groupedOpponentMovesUci;
  final List<SolutionGraphNode> children;

  SolutionGraphNode({
    required this.id,
    required this.moveUci,
    required this.moveSan,
    required this.fen,
    this.parentFen,
    required this.isWhite,
    this.isCheckmate = false,
    this.isGrouped = false,
    this.selectedGroupedIndex = 0,
    this.groupedOpponentMoves = const [],
    this.groupedOpponentMovesUci = const [],
    this.children = const [],
  });
}

class PositionedNode {
  final SolutionGraphNode node;
  final double x;
  final double y;
  final double width;
  final double height;
  final PositionedNode? parent;
  final List<PositionedNode> children = [];

  PositionedNode({
    required this.node,
    required this.x,
    required this.y,
    this.width = 110.0,
    this.height = 44.0,
    this.parent,
  });
}

class TreeEdgesPainter extends CustomPainter {
  final List<PositionedNode> positionedNodes;
  final String? activeFen;

  TreeEdgesPainter({
    required this.positionedNodes,
    required this.activeFen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const ui.Color(0xFF334155)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint activePaint = Paint()
      ..color = const ui.Color(0xFF38BDF8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final String? activeFenShort = activeFen?.split(' ')[0];

    for (var pn in positionedNodes) {
      if (pn.parent != null) {
        final parentX = pn.parent!.x + pn.parent!.width / 2;
        final parentY = pn.parent!.y + pn.parent!.height;
        final childX = pn.x + pn.width / 2;
        final childY = pn.y;

        final bool isChildActive = (activeFenShort != null &&
            activeFenShort == pn.node.fen.split(' ')[0]);

        final Path path = Path();
        path.moveTo(parentX, parentY);
        final double midY = (parentY + childY) / 2;
        path.cubicTo(parentX, midY, childX, midY, childX, childY);

        canvas.drawPath(path, isChildActive ? activePaint : linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreeEdgesPainter oldDelegate) {
    return oldDelegate.activeFen != activeFen ||
        oldDelegate.positionedNodes != positionedNodes;
  }
}
