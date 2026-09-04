import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/models/walkthrough_cursor.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';

RepertoireTree buildTestTree() {
  return RepertoireTree(
    rootFen: 'start',
    children: [
      RepertoireTreeMove(
        uci: 'e2e4',
        san: 'e4',
        fen: 'fen-e4',
        mine: true,
        role: 'primary',
        share: 1.0,
        state: 'decided',
        children: [
          RepertoireTreeMove(
            uci: 'e7e5',
            san: 'e5',
            fen: 'fen-e4-e5',
            mine: false,
            role: null,
            share: 0.55,
            state: 'decided',
            children: [
              RepertoireTreeMove(
                uci: 'g1f3',
                san: 'Nf3',
                fen: 'fen-e4-e5-Nf3',
                mine: true,
                role: 'primary',
                share: 1.0,
                state: 'decided',
                children: [],
              ),
            ],
          ),
          RepertoireTreeMove(
            uci: 'e7e6',
            san: 'e6',
            fen: 'fen-e4-e6',
            mine: false,
            role: null,
            share: 0.14,
            state: 'decided',
            children: [
              RepertoireTreeMove(
                uci: 'd2d4',
                san: 'd4',
                fen: 'fen-e4-e6-d4',
                mine: true,
                role: 'primary',
                share: 1.0,
                state: 'decided',
                children: [
                  RepertoireTreeMove(
                    uci: 'd7d5',
                    san: 'd5',
                    fen: 'fen-e4-e6-d4-d5',
                    mine: false,
                    role: null,
                    share: 0.60,
                    state: 'open',
                    children: [],
                  ),
                ],
              ),
            ],
          ),
          RepertoireTreeMove(
            uci: 'c7c5',
            san: 'c5',
            fen: 'fen-e4-c5',
            mine: false,
            role: null,
            share: 0.31,
            state: 'open',
            children: [],
          ),
        ],
      ),
    ],
  );
}

void main() {
  test(
      'mutated 1: next walks the tour order, including the climb back to a fork',
      () {
    final tree = buildTestTree();
    final stops = walkthroughOrder(tree);

    int currentIndex = -1;
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    // root -> e4 -> e5 -> Nf3
    cursor.next(); // 0: e4
    expect(currentIndex, 0);

    final cursorAt0 = WalkthroughCursor(
        tree: tree, stops: stops, index: 0, onSelect: (i) => currentIndex = i);
    cursorAt0.next(); // 1: e4 e5
    expect(currentIndex, 1);

    final cursorAt1 = WalkthroughCursor(
        tree: tree, stops: stops, index: 1, onSelect: (i) => currentIndex = i);
    cursorAt1.next(); // 2: e4 e5 Nf3
    expect(currentIndex, 2);

    final cursorAt2 = WalkthroughCursor(
        tree: tree, stops: stops, index: 2, onSelect: (i) => currentIndex = i);
    cursorAt2.next(); // 3: e4 e6 (climb back to e4 and take e6)
    expect(currentIndex, 3);
    expect(stops[currentIndex].path, ['e4', 'e6']);
  });

  test('mutated 2: previous undoes exactly that step', () {
    final tree = buildTestTree();
    final stops = walkthroughOrder(tree);

    int currentIndex = 2; // e4 e5 Nf3
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    cursor.next();
    expect(currentIndex, 3); // e4 e6

    final cursorAt3 = WalkthroughCursor(
        tree: tree, stops: stops, index: 3, onSelect: (i) => currentIndex = i);
    cursorAt3.previous();
    expect(currentIndex, 2); // e4 e5 Nf3 again
  });

  test('first reaches the root', () {
    final tree = buildTestTree();
    final stops = walkthroughOrder(tree);

    int currentIndex = 5;
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    cursor.first();
    expect(currentIndex, -1);

    final rootCursor = WalkthroughCursor(
        tree: tree, stops: stops, index: -1, onSelect: (i) => currentIndex = i);
    expect(rootCursor.currentFen, 'start');
  });

  test(
      'last stops at the end of the line and does not cross into a sibling branch',
      () {
    final tree = buildTestTree();
    final stops = walkthroughOrder(tree);

    int currentIndex = 1; // e4 e5
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    cursor.last();
    // End of line from e4 e5 is e4 e5 Nf3 which is index 2.
    // It should not cross into e4 e6 (index 3).
    expect(currentIndex, 2);
    expect(stops[currentIndex].path, ['e4', 'e5', 'Nf3']);
  });

  test('mutated 5: forwardBranches at a fork lists the children in tour order',
      () {
    final tree = buildTestTree();
    final stops = walkthroughOrder(tree);

    int currentIndex = 0; // e4
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    final branches = cursor.forwardBranches;
    expect(branches.length, 3);

    expect(branches[0].label, 'e5 55%');
    expect(branches[0].isMain, isTrue);
    expect(branches[0].detail, isNull);

    expect(branches[1].label, 'e6 14%');
    expect(branches[1].isMain, isFalse);
    expect(branches[1].detail, isNull);

    expect(branches[2].label, 'c5 31% ?');
    expect(branches[2].isMain, isFalse);
    expect(branches[2].detail, 'nemate odgovor');
  });

  test('takeBranch(1) moves to that branchs own stop index', () {
    final tree = buildTestTree();
    final stops = walkthroughOrder(tree);

    int currentIndex = 0; // e4
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    cursor.takeBranch(1);
    // Branch 1 is e6, which is index 3 in tour order
    expect(currentIndex, 3);
  });

  test('a move of mine in front of an open position is not called a hole', () {
    // `state` describes the position a move leads to, so it reads differently
    // on the two kinds of card: one of *my* moves can stand in front of a
    // position nothing has been decided in yet. Read raw, that says „nemate
    // odgovor" about the reader's own move — which is the sentence the tour
    // exists to say about the opponent's.
    const tree = RepertoireTree(
      rootFen: 'start',
      children: [
        RepertoireTreeMove(
          uci: 'e2e4',
          san: 'e4',
          fen: 'fen-e4',
          mine: true,
          role: 'primary',
          state: 'open',
        ),
        RepertoireTreeMove(
          uci: 'd2d4',
          san: 'd4',
          fen: 'fen-d4',
          mine: true,
          role: 'alternate',
          state: 'open',
        ),
      ],
    );
    final stops = walkthroughOrder(tree);
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: -1,
      onSelect: (_) {},
    );

    expect(cursor.forwardBranches.map((b) => b.detail), everyElement(isNull));
  });

  test('An empty tree: canGoBack and canGoForward are both false', () {
    final tree = RepertoireTree(rootFen: 'start', children: []);
    final stops = walkthroughOrder(tree);

    int currentIndex = -1;
    final cursor = WalkthroughCursor(
      tree: tree,
      stops: stops,
      index: currentIndex,
      onSelect: (i) => currentIndex = i,
    );

    expect(cursor.canGoBack, isFalse);
    expect(cursor.canGoForward, isFalse);

    cursor.next();
    cursor.previous();
    expect(currentIndex, -1);
  });
}
