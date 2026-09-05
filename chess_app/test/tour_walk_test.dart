import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/tour_walk.dart';
import 'package:chess_app/move_tree.dart';

/// Phase 3 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: the tour arithmetic, with
/// the repertoire taken out of it.
///
/// All of this was written for „Upoznaj repertoar" and watched running there
/// (provera 97–101). None of it is about repertoires: every rule below is about
/// **paths** — where a stop sits relative to the one before it — and a lesson
/// step's line is a list of paths like any other.
///
/// The one thing the extraction must not do is change any of it, so these tests
/// state the existing behaviour rather than a nicer version of it. The
/// repertoire's own four test files are the real judges and stay untouched.
void main() {
  // A tour of e4, its three replies, and what hangs off two of them:
  //
  //   0  e4
  //   1  e4 e5
  //   2  e4 e5 Nf3
  //   3  e4 e6
  //   4  e4 e6 d4
  //   5  e4 c5
  final branching = <List<String>>[
    ['e4'],
    ['e4', 'e5'],
    ['e4', 'e5', 'Nf3'],
    ['e4', 'e6'],
    ['e4', 'e6', 'd4'],
    ['e4', 'c5'],
  ];

  group('pathStartsWith', () {
    test('a path starts with its own prefix, and with nothing longer', () {
      expect(pathStartsWith(['e4', 'e5'], ['e4']), isTrue);
      expect(pathStartsWith(['e4', 'e5'], ['e4', 'e5']), isTrue);
      expect(pathStartsWith(['e4'], ['e4', 'e5']), isFalse);
    });

    test('every path starts with the empty prefix — that is the root', () {
      expect(pathStartsWith(['e4', 'e5'], const []), isTrue);
      expect(pathStartsWith(const [], const []), isTrue);
    });

    test('a sibling is not a prefix', () {
      expect(pathStartsWith(['e4', 'e6'], ['e4', 'e5']), isFalse);
    });
  });

  group('tourBeats — the return to the fork', () {
    test('a line that never forks is walked without a single return', () {
      final beats = tourBeats([
        ['e4'],
        ['e4', 'e5'],
        ['e4', 'e5', 'Nf3'],
      ]);

      expect(beats.length, 3);
      expect(beats.every((b) => !b.returning), isTrue);
      expect(beats.map((b) => b.stopIndex), [0, 1, 2]);
    });

    test('the tour comes back to the fork before it takes another line', () {
      final beats = tourBeats(branching);
      final returns = [
        for (final b in beats)
          if (b.returning) b,
      ];

      expect(returns.length, 2);

      // Back to e4 after finishing e5, about to start e6.
      expect(returns[0].stopIndex, 0);
      expect(returns[0].doneIndex, 1);
      expect(returns[0].nextIndex, 3);

      // And back to e4 again after e6, about to start c5. `done` is the
      // *branch* just finished, not the last stop walked — the tour came out
      // of e6 by way of d4.
      expect(returns[1].stopIndex, 0);
      expect(returns[1].doneIndex, 3);
      expect(returns[1].nextIndex, 5);
    });

    test('a fork at the root has no stop to stand on, and says so with -1', () {
      final beats = tourBeats([
        ['e4'],
        ['e4', 'e5'],
        ['d4'],
      ]);
      final back = beats.firstWhere((b) => b.returning);

      expect(back.stopIndex, -1, reason: 'the root is a fork like any other');
      expect(back.doneIndex, 0);
      expect(back.nextIndex, 2);
    });

    test('every stop is still visited exactly once, in order', () {
      // The returning beats are added *between* stops and may never reorder or
      // drop one. This is the contract `walkthroughOrder` owns and this
      // function must not touch.
      final beats = tourBeats(branching);
      final visited = [
        for (final b in beats)
          if (!b.returning) b.stopIndex,
      ];

      expect(visited, [0, 1, 2, 3, 4, 5]);
    });

    test('an empty tour has no beats', () {
      expect(tourBeats(const []), isEmpty);
    });
  });

  group('tourForwardIndices — the moves out of here', () {
    test('the root offers the first move of every line', () {
      expect(tourForwardIndices(branching, -1), [0]);
    });

    test('a fork offers each of its replies once', () {
      // e4's children are e5, e6 and c5 — not Nf3 or d4, which sit deeper.
      expect(tourForwardIndices(branching, 0), [1, 3, 5]);
    });

    test('a stop with one continuation offers exactly it', () {
      expect(tourForwardIndices(branching, 1), [2]);
    });

    test('the end of a line offers nothing', () {
      expect(tourForwardIndices(branching, 2), isEmpty);
      expect(tourForwardIndices(branching, 5), isEmpty);
    });

    test('the scan stops at the edge of the subtree', () {
      // From e6 (index 3) the walk must not run on into c5, which is a sibling
      // rather than a child. Reading past that edge is how a tour offers a
      // reply that belongs to somebody else's position.
      expect(tourForwardIndices(branching, 3), [4]);
    });
  });

  group('tourLastIndex — the end of this line, never a sibling', () {
    test('it runs to the end of the line it is standing on', () {
      final beats = tourBeats(branching);
      // Standing on e4 e5 (beat 1) the line ends at Nf3.
      final end = tourLastIndex(branching, beats, 1);

      expect(beats[end].returning, isFalse);
      expect(beats[end].stopIndex, 2);
    });

    test('it stops rather than stepping into a sibling variation', () {
      final beats = tourBeats(branching);
      // From the last stop of the e5 line there is nowhere further down; the
      // next beat is a return to the fork, which is an ancestor.
      final atNf3 = beats.indexWhere((b) => !b.returning && b.stopIndex == 2);

      expect(tourLastIndex(branching, beats, atNf3), atNf3);
    });

    test('from the root it runs down the first line only', () {
      final beats = tourBeats(branching);
      final end = tourLastIndex(branching, beats, -1);

      expect(beats[end].stopIndex, 2, reason: 'e4 e5 Nf3, not e6 and not c5');
    });
  });

  group('tourBeatOfStop', () {
    test('it finds the beat that plays a stop, not one that returns to it', () {
      final beats = tourBeats(branching);
      final at = tourBeatOfStop(beats, 0);

      expect(at, isNot(-1));
      expect(beats[at].returning, isFalse);
      expect(beats[at].stopIndex, 0);
    });

    test('a stop nobody plays is not found', () {
      expect(tourBeatOfStop(tourBeats(branching), 99), -1);
    });
  });

  group('the seam this extraction exists for: a lesson line', () {
    // The repertoire is the only caller today, and an extraction with one
    // caller is not yet proven fit for the second. A lesson step's line is a
    // `MoveTree` rather than a repertoire, so this walks one through the same
    // arithmetic — the case phases 6 and 7 will actually build on.
    //
    // The path derivation lives here rather than in `lib/` on purpose: nothing
    // in the app needs it yet, and unused production code is worse than a test
    // that proves the seam holds.
    List<List<String>> pathsOf(MoveNode node,
        [List<String> prefix = const []]) {
      final out = <List<String>>[];
      for (final child in node.children) {
        final path = [...prefix, child.san];
        out.add(path);
        out.addAll(pathsOf(child, path));
      }
      return out;
    }

    test('a step with a sideline gets its return to the fork', () {
      // 1. e4 e5 2. Nf3 with 1... c5 as a sideline — the shape a trainer draws
      // when a lesson says „and if Black plays this instead".
      final tree = MoveTree(
          startingFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      MoveTree.appendLine(tree.root, ['e2e4', 'e7e5', 'g1f3']);
      MoveTree.appendLine(tree.root, ['e2e4', 'c7c5']);

      final paths = pathsOf(tree.root);
      expect(paths, [
        ['e4'],
        ['e4', 'e5'],
        ['e4', 'e5', 'Nf3'],
        ['e4', 'c5'],
      ]);

      final beats = tourBeats(paths);
      final returns = [
        for (final b in beats)
          if (b.returning) b,
      ];

      expect(returns.length, 1, reason: 'one climb, out of e5 and into c5');
      expect(paths[returns.single.stopIndex], ['e4'],
          reason:
              'the reader is put back on the position the two lines part at');
      expect(paths[returns.single.doneIndex], ['e4', 'e5']);
      expect(paths[returns.single.nextIndex], ['e4', 'c5']);
    });

    test('the fork offers both continuations, and the trunk runs to its end',
        () {
      final tree = MoveTree(
          startingFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      MoveTree.appendLine(tree.root, ['e2e4', 'e7e5', 'g1f3']);
      MoveTree.appendLine(tree.root, ['e2e4', 'c7c5']);

      final paths = pathsOf(tree.root);
      final beats = tourBeats(paths);

      // Standing on e4, both replies are on offer — that is the fork the
      // student is asked about instead of being walked silently into e5.
      expect(tourForwardIndices(paths, 0), [1, 3]);

      // And „go to the end" follows e5 to Nf3 without falling into c5.
      final atE5 = tourBeatOfStop(beats, 1);
      expect(beats[tourLastIndex(paths, beats, atE5)].stopIndex, 2);
    });
  });
}
