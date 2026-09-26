// A tutorial's branches, and their order — phase 2 of
// `docs/PLAN-REDOSLED-GRANA.md`.
//
// The parts that leave one move are that move's variations, and their order is
// the film's. „Move variation earlier / later" moves a whole branch — the part
// and everything that hangs from it — and the proof asked of every case is the
// film: every move still filmed once, every sentence where it was.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_branches.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

import 'support/tutorial_part_fixtures.dart';

/// The sketch's parts, by the number §3 gives them, in the order they now
/// stand.
List<int> _order(TutorialDraft draft, List<TutorialSection> original) => [
      for (final part in draft.sections) original.indexOf(part) + 1,
    ];

List<String> _filmed(TutorialDraft draft) => [
      for (final stop in filmBeatsOf(draft))
        if (stop.beat.arrivedBy != null) stop.beat.arrivedBy!,
    ]..sort();

void main() {
  group('the sketch', () {
    late TutorialDraft draft;
    late List<TutorialSection> original;
    late List<String> filmedBefore;
    late Map<TutorialSection, String> sentences;

    setUp(() {
      draft = sketchDraft();
      original = [...draft.sections];
      filmedBefore = _filmed(draft);
      sentences = {for (final p in original) p: p.root.comment};
    });

    void holdsTheFilm() {
      expect(_filmed(draft), filmedBefore,
          reason: 'a move was lost or filmed twice');
      for (final p in draft.sections) {
        expect(p.root.comment, sentences[p]);
      }
      expect(draft.sections.toSet(), original.toSet());
    }

    test('three branches leave 16... Nc4', () {
      final map = partMapOf(draft);
      expect(siblingsOf(map, 1), [1, 4, 5]);
      expect(branchOf(map, 1), [1, 2, 3], reason: 'parts 2, 3 and 4');
      expect(branchOf(map, 4), [4], reason: 'part 5');
      expect(branchOf(map, 5), [5, 6], reason: 'parts 6 and 7');
    });

    test('„later" on 17. Be3: 1, 2, 3, 4, 6, 7, 5, 8', () {
      expect(moveBranch(draft, 4, earlier: false), isTrue);
      expect(_order(draft, original), [1, 2, 3, 4, 6, 7, 5, 8]);
      holdsTheFilm();
    });

    test('„earlier" on 17. Be3: 1, 5, 2, 3, 4, 6, 7, 8', () {
      expect(moveBranch(draft, 4, earlier: true), isTrue);
      expect(_order(draft, original), [1, 5, 2, 3, 4, 6, 7, 8]);
      holdsTheFilm();
      final kinds = partMapOf(draft).entries.map((e) => e.rowText).toList();
      expect(kinds[1], '2 · continues',
          reason: 'part 5 now opens where part 1 ended');
      expect(kinds[2], '3 · back to after 16... Nc4',
          reason: 'and part 2 goes back there');
    });

    test('the open part stays open wherever it went', () {
      draft.selected = 4;
      moveBranch(draft, 4, earlier: true);
      expect(identical(draft.section, original[4]), isTrue);
      expect(draft.selected, 1);
    });

    test('the ends stay ends, and a lone branch does not move', () {
      expect(canMoveBranch(draft, 1, earlier: true), isFalse,
          reason: 'part 2 is the first to leave 16... Nc4');
      expect(canMoveBranch(draft, 5, earlier: false), isFalse,
          reason: 'part 6 is the last');
      expect(canMoveBranch(draft, 3, earlier: true), isFalse,
          reason: 'part 4 is the only one to leave 18. Rfe1');
      expect(canMoveBranch(draft, 3, earlier: false), isFalse);
      expect(canMoveBranch(draft, 0, earlier: false), isFalse,
          reason: 'a new board hangs from nothing');
      expect(moveBranch(draft, 1, earlier: true), isFalse);
      expect(_order(draft, original), [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('a part of neither branch keeps its place', () {
      // Part 8 is a new board after both; it must not be carried along.
      moveBranch(draft, 5, earlier: true);
      expect(_order(draft, original), [1, 2, 3, 4, 6, 7, 5, 8]);
      expect(identical(draft.sections.last, original.last), isTrue);
    });
  });

  test('a part between two branches stays where it is', () {
    // Two answers to 17. Bg5 with a new board between them: the sketch's
    // branches all stand side by side, so it could not show this.
    final afterBg5 = fenAfter(forkPosition, '17. Bg5');
    final draft = TutorialDraft(sections: [
      partOf(forkPosition, '17. Bg5 Nxe5 *'),
      partOf(afterBg5, '17... h6 *'),
      partOf(standardStart, '1. e4 *'),
      partOf(afterBg5, '17... Qd7 *'),
    ]);
    final original = [...draft.sections];
    expect(siblingsOf(partMapOf(draft), 1), [1, 3]);

    expect(moveBranch(draft, 3, earlier: true), isTrue);
    expect(_order(draft, original), [1, 4, 3, 2],
        reason: 'the two answers swap the places they held');
    expect(identical(draft.sections[2], original[2]), isTrue,
        reason: 'the new board between them did not move');
  });

  group('the family as one tree', () {
    late TutorialDraft draft;
    late TutorialTree tree;
    setUp(() {
      draft = sketchDraft()..selected = 2;
      tree = tutorialTreeOf(draft);
    });

    List<String> sans(AnalysisNode node) =>
        [for (final c in node.children) c.moveSan!];

    AnalysisNode child(AnalysisNode node, String san) =>
        node.children.singleWhere((c) => c.moveSan == san);

    test('the moves that leave 16... Nc4 are the parts that leave it', () {
      final nc4 = tree.root.children.single;
      expect(nc4.moveSan, 'Nc4');
      expect(sans(nc4), ['Bg5', 'Be3', 'Bc1'],
          reason: 'in film order: parts 3 (after 2), 5 and 6');
      final rfe1 = child(child(child(nc4, 'Bg5'), 'Nxe5'), 'Rfe1');
      expect(sans(rfe1), ['cxd4', 'h6'],
          reason: 'part 3 goes on first; part 4 leaves 18. Rfe1');
      expect(sans(child(child(nc4, 'Bc1'), 'Nxe5')), ['Qe2'],
          reason: 'part 7 continues part 6');
    });

    test('a part that starts where another stood is drawn at that move', () {
      final nc4 = tree.root.children.single;
      for (final p in [1, 4, 5]) {
        expect(identical(tree.shownAt(draft.sections[p].root), nc4), isTrue,
            reason: 'part ${p + 1}');
      }
      expect(tree.shownAt(draft.sections[7].root), isNull,
          reason: 'part 8 is a new board, not of this family');
    });

    test('each move leads back to its part, and a copy is not the original',
        () {
      final be3 = child(tree.root.children.single, 'Be3');
      expect(tree.originOf(be3)!.part, 4);
      expect(identical(tree.originOf(be3)!.node, be3), isFalse);
      expect(tree.originOf(be3)!.node.id, be3.id);
    });

    test('which branch a move starts', () {
      final nc4 = tree.root.children.single;
      expect(tree.branchAt(child(nc4, 'Be3'), draft), 4);
      expect(tree.branchAt(child(nc4, 'Bc1'), draft), 5);
      expect(tree.branchAt(child(nc4, 'Bg5'), draft), 1,
          reason: 'part 2 only adds a sentence; 17. Bg5 starts its branch');
      final rfe1 = child(child(child(nc4, 'Bg5'), 'Nxe5'), 'Rfe1');
      expect(tree.branchAt(child(rfe1, 'h6'), draft), 3);
      expect(tree.branchAt(child(rfe1, 'cxd4'), draft), isNull,
          reason: 'a move inside a part starts no branch');
      expect(tree.branchAt(nc4, draft), isNull,
          reason: 'the first part hangs from nothing');
    });

    test('a new board is a family of its own', () {
      draft.selected = 7;
      final own = tutorialTreeOf(draft);
      expect(own.root.fen, standardStart);
      expect(own.shownAt(draft.sections[2].root), isNull);
    });
  });
}
