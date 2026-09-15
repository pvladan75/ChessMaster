import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

/// The picture says what its marks mean, and nothing about settings that no
/// longer exist.
AnalysisNode _root() => AnalysisNode(
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final root = _root();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: RepertoireTreePanel(
          root: root,
          active: root,
          onSelect: (_) {},
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('the legend names the marks the cards carry', (tester) async {
    await _pump(tester);

    expect(find.text(RepertoireTreePanel.legend), findsOneWidget);
    // The two marks `markOfRepertoireMove` writes, and no third.
    expect(RepertoireTreePanel.legend, contains('★'));
    expect(RepertoireTreePanel.legend, contains('?'));
    expect(RepertoireTreePanel.legend, isNot(contains('✂')));
    expect(RepertoireTreePanel.legend, isNot(contains('…')));
  });

  testWidgets('nothing about a breadth or a cut is drawn', (tester) async {
    await _pump(tester);

    expect(find.textContaining('Breadth'), findsNothing);
    expect(find.textContaining('not preparing'), findsNothing);
  });

  group('finding the node a position stands on', () {
    // The tree's FENs come from the server; the one the board is standing on is
    // computed locally by the chess engine after a move. Those two agree about
    // the position and can disagree about the halfmove clock and the move
    // number, which are arithmetic and not position.
    AnalysisNode treeFromServer() {
      final root = AnalysisNode(
        fen: 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3',
      );
      final c5 = AnalysisNode(
        fen: 'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4',
        moveSan: 'c5',
        moveUci: 'c7c5',
      )..parent = root;
      root.children.add(c5);
      return root;
    }

    test('the same position with different move counters is the same node', () {
      final root = treeFromServer();

      final found = findNodeByFen(root,
          'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 7 12');

      expect(found?.moveSan, 'c5', reason: 'move counters are not position');
    });

    test('a genuinely different position is still not found', () {
      // The en-passant square is inside the key on purpose: two positions that
      // differ only in it are different positions, and one allows a capture.
      final root = treeFromServer();

      expect(
          findNodeByFen(root,
              'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4'),
          isNull,
          reason: 'en passant is part of the position');
      expect(
          findNodeByFen(
              root, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
          isNull);
    });
  });
}
