import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';

/// Phase 2 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`: the four states, drawn apart.
///
/// The owner's complaint is that a built repertoire is a picture nobody can
/// hold in their head — „čvorovi su međusobno previše slični". So the test is
/// not that a colour changed; it is that the three channels a colourblind
/// reader actually gets are different: **fill, silhouette and weight.**
const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
const afterE5 = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
const afterC5 = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2';

RepertoireTree treeWithAHole() => const RepertoireTree(
      rootFen: start,
      rootPath: [],
      children: [
        RepertoireTreeMove(
          uci: 'e2e4',
          san: 'e4',
          fen: afterE4,
          mine: true,
          role: 'primary',
          children: [
            RepertoireTreeMove(
              uci: 'e7e5',
              san: 'e5',
              fen: afterE5,
              mine: false,
              share: 0.55,
              state: 'decided',
            ),
            RepertoireTreeMove(
              uci: 'c7c5',
              san: 'c5',
              fen: afterC5,
              mine: false,
              share: 0.31,
              state: 'open',
            ),
          ],
        ),
      ],
    );

/// The decoration of the card whose label contains [san].
BoxDecoration cardFor(WidgetTester tester, String san) {
  final container = tester.widget<AnimatedContainer>(find.ancestor(
    of: find.textContaining(san),
    matching: find.byType(AnimatedContainer),
  ));
  return container.decoration! as BoxDecoration;
}

Future<void> pumpTree(
  WidgetTester tester,
  AnalysisNode root, {
  MoveTreeNodeLook? Function(AnalysisNode)? nodeLook,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: VisualMoveTreeWidget(
        rootNode: root,
        activeNode: root,
        onSelectNode: (_) {},
        nodeLook: nodeLook,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('which of the four a card is', () {
    test('the state the server sent decides it', () {
      const mine = RepertoireTreeMove(
          uci: 'e2e4', san: 'e4', fen: afterE4, mine: true, role: 'primary');
      const covered = RepertoireTreeMove(
          uci: 'e7e5', san: 'e5', fen: afterE5, mine: false, state: 'decided');
      const hole = RepertoireTreeMove(
          uci: 'c7c5', san: 'c5', fen: afterC5, mine: false, state: 'open');
      const cut = RepertoireTreeMove(
          uci: 'c7c5', san: 'c5', fen: afterC5, mine: false, state: 'cut');

      expect(lookOfRepertoireMove(mine), MoveTreeNodeLook.authored);
      expect(lookOfRepertoireMove(covered), MoveTreeNodeLook.covered);
      expect(lookOfRepertoireMove(hole), MoveTreeNodeLook.gap);
      expect(lookOfRepertoireMove(cut), MoveTreeNodeLook.refused);
    });

    test('a cut branch is refused even on the student\'s own move', () {
      // `mine` and `cut` can both be true — the student decided a move and
      // later said they are not preparing what follows. The refusal wins,
      // because it is the fact that changes what the card means.
      const mineButCut = RepertoireTreeMove(
          uci: 'e2e4',
          san: 'e4',
          fen: afterE4,
          mine: true,
          role: 'primary',
          state: 'cut');

      expect(lookOfRepertoireMove(mineButCut), MoveTreeNodeLook.refused);
    });
  });

  group('the drawing says which is which', () {
    testWidgets('my move is filled, theirs is a pill, a hole is heavier',
        (tester) async {
      final looks = <String, MoveTreeNodeLook>{};
      final root = repertoireTreeToNodes(treeWithAHole(), looks: looks);
      await pumpTree(tester, root, nodeLook: (node) => looks[node.id]);

      final mine = cardFor(tester, 'e4');
      final covered = cardFor(tester, 'e5');
      final hole = cardFor(tester, 'c5');

      // Fill: mine carries one, theirs does not. The first channel, and the
      // one that reads at a distance.
      expect(mine.color, isNot(Colors.transparent));
      expect(covered.color, Colors.transparent);
      expect(hole.color, Colors.transparent);

      // Silhouette: a rectangle is mine, a pill is theirs. This is the channel
      // that survives being glanced at rather than read.
      final mineRadius = mine.borderRadius! as BorderRadius;
      final coveredRadius = covered.borderRadius! as BorderRadius;
      expect(mineRadius.topLeft.x, lessThan(20));
      expect(coveredRadius.topLeft.x, greaterThan(100));

      // Weight: a hole is drawn heavier than an answered reply, because it is
      // the card the reader is hunting for.
      expect(hole.border!.top.width, greaterThan(covered.border!.top.width));
    });

    testWidgets('a board that passes no look is drawn exactly as before',
        (tester) async {
      // The analysis studio shares this widget and knows nothing about
      // repertoires. Every one of the rules above must be off by default, or
      // phase 2 quietly restyles a screen it was never about.
      final root = repertoireTreeToNodes(treeWithAHole());
      await pumpTree(tester, root);

      final mine = cardFor(tester, 'e4');
      final hole = cardFor(tester, 'c5');

      expect(mine.color, isNot(Colors.transparent));
      expect(hole.color, isNot(Colors.transparent));
      expect((hole.borderRadius! as BorderRadius).topLeft.x, lessThan(20));
      expect(hole.border!.top.width, mine.border!.top.width);
    });
  });
}
