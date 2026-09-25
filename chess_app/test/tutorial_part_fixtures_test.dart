// The fixtures of `docs/PLAN-MAPA-DELOVA.md` hold what they say — phase 0.
//
// Nothing here tests new behaviour. It exists so that the gates of phases 1–3
// stand on fixtures that replay in full and have exactly the shape their names
// promise: a fork fixture that had quietly lost its side line to a typo would
// make every „no part forks" assertion pass for the wrong reason.
//
// The last group also pins §3 of the plan to the code as it stands: the way
// each of the sketch's eight parts opens is already `partOpeningsOf`'s answer
// today, and the map of phase 3 draws that answer rather than a second one.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

import 'support/tutorial_part_fixtures.dart';

/// Every node below [root], in preorder.
List<AnalysisNode> movesOf(AnalysisNode root) => [
      for (final child in root.children) ...[child, ...movesOf(child)],
    ];

AnalysisNode childBy(AnalysisNode node, String san) =>
    node.children.singleWhere((c) => c.moveSan == san);

void main() {
  group('the owner\'s example of 12.9', () {
    test('replays in full and forks once, after 1... Kc6', () {
      final part = ownerExamplePart();
      expect(part.rejectedMoves, 0);

      final kc6 = childBy(childBy(part.root, 'Ra1'), 'Kc6');
      expect(kc6.children.map((c) => c.moveSan), ['Ra6', 'Ra8'],
          reason: 'the original continuation first, the new line second — '
              'the order the tree held when the owner cut it');
      expect(movesOf(part.root), hasLength(8));
      expect(childBy(kc6, 'Ra8').arrows.map((a) => a.toString()), ['Ga8a6']);
    });
  });

  group('the tree with many forks', () {
    test('replays in full, with every fork where its name says', () {
      final part = manyForksPart();
      expect(part.rejectedMoves, 0);

      final root = part.root;
      expect(root.children.map((c) => c.moveSan), ['Bg5', 'Be3', 'Bc1'],
          reason: 'two side lines at one fork');

      final rfe1 = childBy(childBy(childBy(root, 'Bg5'), 'Nxe5'), 'Rfe1');
      expect(rfe1.children.map((c) => c.moveSan), ['cxd4', 'h6'],
          reason: 'a second fork on the main line');
      expect(
          childBy(rfe1, 'h6').children.map((c) => c.moveSan), ['Rxe5', 'Bxf6'],
          reason: 'a fork inside a side line');

      expect(movesOf(root), hasLength(14));
    });

    test('carries words and a drawing in every kind of branch', () {
      final root = manyForksPart().root;
      final bg5 = childBy(root, 'Bg5');
      final rfe1 = childBy(childBy(bg5, 'Nxe5'), 'Rfe1');
      final h6 = childBy(rfe1, 'h6');

      expect(bg5.comment, contains('pins'), reason: 'on the main line');
      expect(childBy(root, 'Be3').comment, contains('retreat'),
          reason: 'on a side line at the root');
      expect(h6.comment, contains('Asking'),
          reason: 'on a side line further down');
      expect(childBy(h6, 'Bxf6').comment, contains('Taking'),
          reason: 'inside a side line\'s own fork');
      expect(rfe1.arrows.map((a) => a.toString()), ['Ge1e5']);
    });
  });

  group('the sketch\'s eight parts', () {
    test('every part replays in full, and none of them forks', () {
      final draft = sketchDraft();
      expect(draft.sections, hasLength(8));
      for (var i = 0; i < draft.sections.length; i++) {
        final part = draft.sections[i];
        expect(part.rejectedMoves, 0, reason: 'part ${i + 1}');
        expect(
          [part.root, ...movesOf(part.root)]
              .every((n) => n.children.length < 2),
          isTrue,
          reason: 'part ${i + 1} is one line',
        );
      }
      expect(draft.sections[1].root.arrows.map((a) => a.toString()), ['Bf4c1'],
          reason: 'part 2 draws the move the game played');
    });

    test('each part opens the way §3 of the plan says, by the film\'s rule',
        () {
      final stops = filmBeatsOf(sketchDraft());
      final openings =
          partOpeningsOf(stops).where((opening) => opening != null).toList();

      expect(openings.map((o) => o!.entry), [
        PartEntry.fresh,
        PartEntry.continues,
        PartEntry.continues,
        PartEntry.returns,
        PartEntry.returns,
        PartEntry.returns,
        PartEntry.continues,
        PartEntry.fresh,
      ]);
      expect(openings.map((o) => o!.afterMove), [
        null,
        null,
        null,
        '18. Rfe1',
        '16... Nc4',
        '16... Nc4',
        null,
        null,
      ]);
    });
  });
}
