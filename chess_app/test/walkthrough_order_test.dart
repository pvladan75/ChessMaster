import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';

/// Phase 3 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`: the order a repertoire is read
/// in. The examples below are the ones written out in
/// `docs/brief-upoznaj-f3-2026-09.md` §6, kept in step with it on purpose — the
/// brief is the contract phase 4 is written against.
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A move, with only the fields an ordering can see. The FEN is never read by
/// `walkthroughOrder`, so one placeholder for every node keeps the fixtures
/// about the thing under test.
RepertoireTreeMove mine(String san,
        {bool primary = true,
        String state = '',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: '$san-uci',
      san: san,
      fen: _start,
      mine: true,
      role: primary ? 'primary' : 'alternate',
      state: state,
      children: children,
    );

RepertoireTreeMove theirs(String san, double share,
        {String state = '', List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: '$san-uci',
      san: san,
      fen: _start,
      mine: false,
      share: share,
      state: state,
      children: children,
    );

RepertoireTree treeOf(List<RepertoireTreeMove> children) =>
    RepertoireTree(rootFen: _start, children: children);

List<String> linesOf(List<WalkthroughStop> stops) =>
    [for (final stop in stops) stop.path.join(' ')];

void main() {
  test('the main line is walked to its end before the tour comes back', () {
    // §6.1. Depth-first is the whole difference between a story and a table of
    // contents: read breadth-first, the two replies to 1.e4 are read together
    // and the reader never finds out how either one continues.
    final tree = treeOf([
      mine('e4', children: [
        theirs('e5', 0.55, children: [mine('Nf3')]),
        theirs('c5', 0.31, state: 'open'),
      ]),
    ]);

    expect(
        linesOf(walkthroughOrder(tree)), ['e4', 'e4 e5', 'e4 e5 Nf3', 'e4 c5']);
  });

  test('a reply the reader has built under comes before a more played one', () {
    // §6.2, and the rule the owner decided: „it is a walkthrough of my
    // repertoire, so the user's actual work must never be buried beneath
    // untouched book lines." Nf6 is played nearly three times as often as d5
    // and is still second, because nothing of theirs lives under it.
    final tree = treeOf([
      mine('d4', children: [
        theirs('Nf6', 0.60),
        theirs('d5', 0.22, children: [mine('c4')]),
      ]),
    ]);

    expect(
        linesOf(walkthroughOrder(tree)), ['d4', 'd4 d5', 'd4 d5 c4', 'd4 Nf6']);
  });

  test('share still decides between two replies that are equally empty', () {
    // The other half of the same rule. Without this the first rule could be
    // written as „ignore share" and every test above would still pass.
    final tree = treeOf([
      mine('e4', children: [
        theirs('c6', 0.20),
        theirs('e5', 0.55),
        theirs('c5', 0.31),
      ]),
    ]);

    expect(linesOf(walkthroughOrder(tree)), ['e4', 'e4 e5', 'e4 c5', 'e4 c6']);
  });

  test('a cut branch is not visited, and neither is anything under it', () {
    // §6.3, and the list the brief asks a worker to print. Six stops: c6 is
    // played more often than c5 and appears nowhere, because a refused branch
    // is neither what I play nor what awaits me.
    final tree = treeOf([
      mine('e4', children: [
        theirs('e5', 0.55, children: [
          mine('Nf3', children: [theirs('Nc6', 0.40, state: 'open')]),
        ]),
        theirs('c6', 0.30, state: 'cut', children: [mine('d4')]),
        theirs('c5', 0.28, children: [mine('Nf3', primary: false)]),
      ]),
    ]);

    expect(linesOf(walkthroughOrder(tree)), [
      'e4',
      'e4 e5',
      'e4 e5 Nf3',
      'e4 e5 Nf3 Nc6',
      'e4 c5',
      'e4 c5 Nf3',
    ]);
  });

  test('work behind a cut does not lift the reply that leads to it', () {
    // The brief said „whose subtree contains at least one move of the reader's
    // own" and did not say which side of a cut that falls on. This is the
    // reading: the tour cannot show what it does not walk, so a reply whose only
    // work is behind a cut is ranked as the empty branch it will look like.
    final tree = treeOf([
      mine('d4', children: [
        theirs('Nf6', 0.60),
        theirs('d5', 0.22, children: [
          mine('c4', state: 'cut', children: [theirs('e6', 0.5)]),
        ]),
      ]),
    ]);

    expect(linesOf(walkthroughOrder(tree)), ['d4', 'd4 Nf6', 'd4 d5']);
  });

  test('my own moves are ordered by role, and the main one leads', () {
    final tree = treeOf([
      mine('c4', primary: false),
      mine('e4'),
      mine('d4', primary: false),
    ]);

    expect(linesOf(walkthroughOrder(tree)), ['e4', 'c4', 'd4']);
  });

  test('a stop knows which of the four it is', () {
    final tree = treeOf([
      mine('e4', children: [
        theirs('e5', 0.55, children: [mine('Nf3')]),
        theirs('c5', 0.31, state: 'open'),
      ]),
    ]);
    final stops = walkthroughOrder(tree);

    expect(stops[0].kind, MoveTreeNodeLook.authored);
    expect(stops[1].kind, MoveTreeNodeLook.covered);
    expect(stops[3].kind, MoveTreeNodeLook.gap);
    // And the depth is the line's length, not the ply of the position.
    expect(stops[3].depth, 2);
  });

  test('the tree is not reordered by being read', () {
    // The same object is drawn afterwards, in the server's order, by a screen
    // that knows nothing about this function. A sort in place would silently
    // rewrite the picture.
    final children = [
      theirs('Nf6', 0.60),
      theirs('d5', 0.22, children: [mine('c4')]),
    ];
    final tree = treeOf([mine('d4', children: children)]);

    walkthroughOrder(tree);

    expect([for (final move in tree.children.first.children) move.san],
        ['Nf6', 'd5']);
    expect(identical(tree.children.first.children, children), isTrue);
  });

  group('trees that answer nothing', () {
    test('an empty tree is an empty tour', () {
      expect(walkthroughOrder(treeOf(const [])), isEmpty);
    });

    test('a tree that is entirely cut is an empty tour', () {
      final tree = treeOf([
        mine('e4', state: 'cut', children: [theirs('e5', 0.55)]),
      ]);

      expect(walkthroughOrder(tree), isEmpty);
    });

    test('a reply nobody plays sorts last, not first', () {
      final tree = treeOf([
        mine('e4', children: [theirs('a6', 0), theirs('e5', 0.55)]),
      ]);

      expect(linesOf(walkthroughOrder(tree)), ['e4', 'e4 e5', 'e4 a6']);
    });
  });

  group('a fan of gaps', () {
    test('a fan is collapsed', () {
      final tree = treeOf([
        mine('e4', children: [
          theirs('e5', 0.50, state: 'open'),
          theirs('c5', 0.30, state: 'open'),
          theirs('e6', 0.20, state: 'open'),
        ]),
      ]);
      expect(linesOf(walkthroughOrder(tree)), ['e4']);
    });

    test('a lone gap survives', () {
      final tree = treeOf([
        mine('e4', children: [
          theirs('e5', 0.50, state: 'open'),
        ]),
      ]);
      expect(linesOf(walkthroughOrder(tree)), ['e4', 'e4 e5']);
    });

    test('a mixed position', () {
      final tree = treeOf([
        mine('e4', children: [
          theirs('e5', 0.50, state: 'open'),
          theirs('c5', 0.30, children: [mine('Nf3')]),
        ]),
      ]);
      expect(linesOf(walkthroughOrder(tree)),
          ['e4', 'e4 c5', 'e4 c5 Nf3', 'e4 e5']);
    });

    test('nothing else moved', () {
      final tree = treeOf([
        mine('e4', children: [
          theirs('e5', 0.50, children: [mine('Nf3')]),
          theirs('c5', 0.30, children: [mine('Nf3')]),
        ]),
      ]);
      expect(linesOf(walkthroughOrder(tree)),
          ['e4', 'e4 e5', 'e4 e5 Nf3', 'e4 c5', 'e4 c5 Nf3']);
    });
  });
}
