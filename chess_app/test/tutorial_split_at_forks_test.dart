// Every fork made into parts — phase 2 of `docs/PLAN-MAPA-DELOVA.md`, D2.
//
// The film walks first children, so a side line left inside a part is saved
// and never shown. `splitAtForks` is the one function every door but the board
// passes a part through; this file holds it to D2's order, to „Insert a line
// here" where there is one fork, and — the proof that matters — to the film:
// every move of the tree is filmed, exactly once.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

import 'support/tutorial_part_fixtures.dart';

/// A part's line, as its moves.
List<String> _line(TutorialSection part) => [
      for (AnalysisNode n = part.root;
          n.children.isNotEmpty;
          n = n.children.first)
        n.children.first.moveSan!,
    ];

/// Every move in a tree, once per node — the multiset the film must show.
List<String> _everyMove(AnalysisNode root) => [
      for (final child in root.children) ...[
        child.moveSan!,
        ..._everyMove(child),
      ],
    ];

/// What the film shows of [parts], as the moves it arrives by.
List<String> _filmed(List<TutorialSection> parts) => [
      for (final stop in filmBeatsOf(TutorialDraft(sections: parts)))
        if (stop.beat.arrivedBy != null) stop.beat.arrivedBy!,
    ];

AnalysisNode _find(AnalysisNode root, String san) {
  if (root.moveSan == san) return root;
  for (final child in root.children) {
    final hit = _findOrNull(child, san);
    if (hit != null) return hit;
  }
  throw StateError('$san is not in the tree');
}

AnalysisNode? _findOrNull(AnalysisNode node, String san) {
  if (node.moveSan == san) return node;
  for (final child in node.children) {
    final hit = _findOrNull(child, san);
    if (hit != null) return hit;
  }
  return null;
}

void main() {
  test('a part with no fork comes back as itself', () {
    final part = partOf(forkPosition, '17. Bg5 Nxe5 18. Rfe1 cxd4 *');
    final parts = splitAtForks(part);
    expect(parts, hasLength(1));
    expect(identical(parts.single, part), isTrue);
  });

  test('one fork: what „Insert a line here" makes at that fork', () {
    // The owner's example of 11.9.2026, checked live on 12.9 — rule 12: one
    // rule, two callers.
    final part = ownerExamplePart()..stepId = 'step-1';
    final kc6 = _find(part.root, 'Kc6');
    final other = ownerExamplePart()..stepId = 'step-1';
    final expected = splitForLine(other, _find(other.root, 'Kc6')).parts;

    final parts = splitAtForks(part);

    expect(parts.map((p) => treeSignature(p.root)),
        expected.map((p) => treeSignature(p.root)));
    expect(parts.map((p) => p.root.fen), expected.map((p) => p.root.fen));
    expect(parts.map((p) => p.stepId), expected.map((p) => p.stepId));
    expect(parts.map(_line), [
      ['Ra1', 'Kc6'],
      ['Ra8', 'Bb2'],
      ['Ra6', 'Bb2', 'c3', 'Kb5'],
    ]);
    expect(parts[1].root.fen, kc6.fen);
  });

  group('many forks', () {
    late TutorialSection part;
    late String signature;
    late List<TutorialSection> parts;

    setUp(() {
      part = manyForksPart()..stepId = 'step-9';
      signature = treeSignature(part.root);
      parts = splitAtForks(part);
    });

    test('come in D2\'s order: side lines as they stand, then the line', () {
      final afterRfe1 = fenAfter(forkPosition, '17. Bg5 Nxe5 18. Rfe1');
      final afterH6 = fenAfter(forkPosition, '17. Bg5 Nxe5 18. Rfe1 h6');
      expect(parts.map(_line), [
        ['Be3', 'Nxe3', 'fxe3'],
        ['Bc1', 'Nxe5'],
        ['Bg5', 'Nxe5', 'Rfe1'],
        ['h6'],
        ['Bxf6', 'Qxf6'],
        ['Rxe5'],
        ['cxd4', 'cxd4'],
      ]);
      expect(parts.map((p) => p.root.fen), [
        forkPosition,
        forkPosition,
        forkPosition,
        afterRfe1,
        afterH6,
        afterH6,
        afterRfe1,
      ]);
    });

    test('no part forks', () {
      for (final p in parts) {
        expect(partForks(p), isFalse, reason: _line(p).join(' '));
      }
    });

    test('the film shows every move of the tree, once', () {
      final tree = _everyMove(part.root)..sort();
      final filmed = _filmed(parts)..sort();
      expect(filmed, tree);
      expect(_filmed([part]), isNot(containsAll(['Be3', 'h6', 'Bxf6'])),
          reason: 'the fixture must lose moves unsplit, or this proves '
              'nothing');
    });

    test('what is written on a move travels with it', () {
      AnalysisNode first(int i) => parts[i].root.children.first;
      expect(first(0).comment, 'The quiet retreat.');
      expect(first(3).comment, 'Asking the bishop.');
      expect(first(4).comment, 'Taking first.');
      expect(first(2).comment, 'The bishop pins the knight.');
      final rfe1 = parts[2].root.children.first.children.first.children.first;
      expect(rfe1.arrows.map((a) => a.toString()), ['Ge1e5']);
      // A part that goes back to 18. Rfe1 draws its arrow again.
      expect(parts[3].root.arrows.map((a) => a.toString()), ['Ge1e5']);
      expect(parts[6].root.arrows.map((a) => a.toString()), ['Ge1e5']);
    });

    test('one part keeps the step id — the one that starts where it did', () {
      expect(parts.where((p) => p.stepId != null).map((p) => p.stepId),
          ['step-9']);
    });

    test('the part handed in is not changed', () {
      expect(treeSignature(part.root), signature);
    });
  });

  test('a fork inside a part keeps the part\'s title on its first piece', () {
    final part = partOf(forkPosition,
        '17. Bg5 Nxe5 18. Rfe1 cxd4 (18... h6 19. Rxe5) 19. cxd4 *')
      ..title = 'The best line';
    final parts = splitAtForks(part);
    expect(parts.map((p) => p.title), ['The best line', '', '']);
  });

  test('side lines at one position: the sentence once, the marks on each', () {
    // Read out once, where the film first shows the position; drawn again at
    // every return, because the board reloads there.
    final part = partOf(forkPosition,
        '{Look at e5. [%cal Ge1e5]} 17. Bg5 (17. Be3) (17. Bc1) *');
    final parts = splitAtForks(part);

    expect(parts.map(_line), [
      ['Be3'],
      ['Bc1'],
      ['Bg5'],
    ]);
    expect(parts.map((p) => p.root.comment), ['Look at e5.', '', '']);
    for (final p in parts) {
      expect(p.root.arrows.map((a) => a.toString()), ['Ge1e5'],
          reason: _line(p).join(' '));
    }
  });
}
