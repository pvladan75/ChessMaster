import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/theme/app_theme.dart';

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
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
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

      // Fill: mine carries one, an answered reply does not. The first
      // channel, and the one that reads at a distance. A hole carries a wash —
      // see the luminance test below for why it stopped being bare.
      expect(mine.color, isNot(Colors.transparent));
      expect(covered.color, Colors.transparent);
      expect(hole.color, isNot(Colors.transparent));

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

    testWidgets("a hole's edge carries luminance, in both themes",
        (tester) async {
      // Measured, not asserted by eye. The first version of this test demanded
      // the hole keep the *same* colour as the covered reply beside it, on the
      // argument that the outline still had to say whose move it was. The
      // owner watched it on 4.9.2026 and the hole was still hard to find, so
      // the numbers were taken: in the dark theme that shared token is
      // `sideBlack` at luminance 0.002 — a near-black line on a near-black
      // ground, and the only difference from its neighbours was 3.0 px of it
      // instead of 1.2. The channel that was being protected is constant
      // inside a repertoire anyway: every card of the opponent's is the same
      // side, and fill and silhouette already say whose move it is.
      //
      // So what is asserted now is what a reader actually gets: the hole's
      // edge stands away from its neighbour's in luminance, in both themes.
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final looks = <String, MoveTreeNodeLook>{};
        final root = repertoireTreeToNodes(treeWithAHole(), looks: looks);
        await pumpTree(tester, root,
            nodeLook: (node) => looks[node.id], theme: theme);

        final covered = cardFor(tester, 'e5').border!.top;
        final hole = cardFor(tester, 'c5').border!.top;

        final holeFill = cardFor(tester, 'c5').color!;
        final coveredFill = cardFor(tester, 'e5').color!;

        expect(hole.width, 3.0);
        expect(hole.color.a, 1.0);

        // The channel that has to survive both themes. A bright edge alone
        // fixes the dark one and does nothing for the light one, where
        // `textPrimary` and the neighbours' side token are both dark.
        expect(holeFill.a, greaterThan(0.0),
            reason: 'a hole with no fill differs from an answered reply only '
                'by stroke width');
        expect(coveredFill.a, 0.0);

        // And the edge has to be visible against the ground it is drawn on,
        // which is the half the fill does not cover. This is the assertion the
        // old side token fails: in the dark theme it is luminance 0.002 on a
        // ground of about 0.02, so the line is there and cannot be seen.
        final ground = theme.scaffoldBackgroundColor.computeLuminance();
        expect((hole.color.computeLuminance() - ground).abs(), greaterThan(0.4),
            reason: 'the hole is outlined in almost exactly the shade behind '
                'it');
      }
    });

    testWidgets('and an answered reply is not drawn like a hole',
        (tester) async {
      // The other side of it: whatever the hole gets, a covered reply must not
      // have, or the drawing is back to one look for two states.
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final looks = <String, MoveTreeNodeLook>{};
        final root = repertoireTreeToNodes(treeWithAHole(), looks: looks);
        await pumpTree(tester, root,
            nodeLook: (node) => looks[node.id], theme: theme);

        final covered = cardFor(tester, 'e5');
        final hole = cardFor(tester, 'c5');

        expect(covered.border!.top.width, lessThan(hole.border!.top.width));
        expect(covered.color!.a, lessThan(hole.color!.a));
      }
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
