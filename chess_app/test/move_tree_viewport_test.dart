import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';

AnalysisNode createDeepTree() {
  final root = AnalysisNode(
    id: 'root',
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  );

  AnalysisNode current = root;
  for (int i = 1; i <= 30; i++) {
    current = current.addChild(
      childFen:
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 ${i + 1}',
      san: 'move$i',
      uci: 'm$i',
    );
  }
  return root;
}

Future<void> pumpTree(
  WidgetTester tester,
  AnalysisNode root,
  AnalysisNode active, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: VisualMoveTreeWidget(
        rootNode: root,
        activeNode: active,
        onSelectNode: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Rect getCardRect(WidgetTester tester, String text) {
  final cardFinder = find
      .ancestor(
        of: find.textContaining(text),
        matching: find.byType(Positioned),
      )
      .first;
  return tester.getRect(cardFinder);
}

void main() {
  testWidgets('The scale survives a move', (tester) async {
    final root = createDeepTree();
    await pumpTree(tester, root, root);

    // Zoom in twice via + button
    await tester.tap(find.byTooltip('Uvećaj'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Uvećaj'));
    await tester.pumpAndSettle();

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final scale1 = iv.transformationController!.value.getMaxScaleOnAxis();

    // Move to move10
    final node10 = root
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first
        .children
        .first; // 10th move
    await pumpTree(tester, root, node10);

    final iv2 =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final scale2 = iv2.transformationController!.value.getMaxScaleOnAxis();

    expect(scale2, equals(scale1));
  });

  testWidgets('A node already inside the viewport moves nothing',
      (tester) async {
    final root = createDeepTree();
    await pumpTree(tester, root, root);

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final m1 = iv.transformationController!.value.clone();

    // move1 is definitely on screen for a 1400x900 viewport.
    final node1 = root.children.first;
    await pumpTree(tester, root, node1);

    final iv2 =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final m2 = iv2.transformationController!.value;

    expect(m2, equals(m1));
  });

  testWidgets('A node past the edge is brought just inside', (tester) async {
    final root = createDeepTree();
    await pumpTree(tester, root, root);

    AnalysisNode node25 = root;
    for (int i = 0; i < 25; i++) {
      node25 = node25.children.first;
    }

    await pumpTree(tester, root, node25);

    final viewportRect = tester.getRect(find.byType(VisualMoveTreeWidget));
    final deflatedViewport = viewportRect.deflate(48.0);

    final cardRect = getCardRect(tester, 'move25');

    expect(cardRect.left, greaterThanOrEqualTo(deflatedViewport.left));
    expect(cardRect.top, greaterThanOrEqualTo(deflatedViewport.top));
    expect(cardRect.right, lessThanOrEqualTo(deflatedViewport.right));
    expect(cardRect.bottom, lessThanOrEqualTo(deflatedViewport.bottom));
  });

  testWidgets('And it is not centred', (tester) async {
    final root = createDeepTree();
    await pumpTree(tester, root, root);

    AnalysisNode node25 = root;
    for (int i = 0; i < 25; i++) {
      node25 = node25.children.first;
    }

    await pumpTree(tester, root, node25);

    final viewportRect = tester.getRect(find.byType(VisualMoveTreeWidget));
    final cardRect = getCardRect(tester, 'move25');

    final viewportCenter = viewportRect.center;
    final cardCenter = cardRect.center;

    expect(cardCenter.dx, isNot(closeTo(viewportCenter.dx, 1.0)));
    expect(cardCenter.dy, isNot(closeTo(viewportCenter.dy, 1.0)));
  });

  testWidgets('The toolbar button still centres', (tester) async {
    final root = createDeepTree();
    await pumpTree(tester, root, root);

    AnalysisNode node25 = root;
    for (int i = 0; i < 25; i++) {
      node25 = node25.children.first;
    }

    await pumpTree(tester, root, node25);

    await tester.tap(find.byTooltip('Centriraj na aktivni potez'));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(find.byType(VisualMoveTreeWidget));
    final cardRect = getCardRect(tester, 'move25');

    final viewportCenter = viewportRect.center;
    final cardCenter = cardRect.center;

    expect(cardCenter.dx, closeTo(viewportCenter.dx, 1.0));
    expect(cardCenter.dy, closeTo(viewportCenter.dy, 1.0));
  });
}
