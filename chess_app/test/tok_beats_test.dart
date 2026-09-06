// The lead's gate for `beatsOf` — P6 of `docs/PLAN-STUDIO-REDIZAJN.md`, D5.
//
// Written before the panel that renders it, and deliberately **headless**:
// that is what makes the widget replaceable and the contract cheap to hold.
// The panel owns no model; if a question about the timeline can be answered
// here, it must not be answered in a widget test.
//
// The order these assert is the **viewer's**, taken from the narration loop in
// `lesson_viewer_screen.dart`: standing on a node the child sees that node's
// marks, hears that node's comment, and only then is the move to the next node
// played. So `arrivedBy` names the move that reached a beat and `plays` the
// move that leaves it, and the sentence belongs between them. A panel that drew
// the move first would teach the author something false about their own
// tutorial, and this file is where that stays decided.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';

void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// A node hung under [parent], the way the studio builds one.
  AnalysisNode child(AnalysisNode parent, String san, {String comment = ''}) {
    final node = AnalysisNode(
      fen: '$startFen/$san',
      moveSan: san,
      comment: comment,
      parent: parent,
    );
    parent.children.add(node);
    return node;
  }

  AnalysisNode line(AnalysisNode root, List<String> sans) {
    var node = root;
    for (final san in sans) {
      node = child(node, san);
    }
    return node;
  }

  group('the line the author is standing on', () {
    test('the opening position is a beat, and nothing arrived at it', () {
      final root = AnalysisNode(fen: startFen, comment: 'Pogledaj polje d5.');
      final beats = beatsOf(root, root);

      expect(beats, hasLength(1));
      expect(beats.single.arrivedBy, isNull,
          reason: 'a move that reached the starting position would be a move '
              'the child never sees played');
      expect(beats.single.plays, isNull);
      expect(beats.single.isLast, isTrue);
      expect(beats.single.isCurrent, isTrue);
      expect(beats.single.node.comment, 'Pogledaj polje d5.',
          reason: 'the note about the starting position is a whole beat — it '
              'is the one place „pogledaj polje d5" can live');
    });

    test('one beat per node, in the order the child meets them', () {
      final root = AnalysisNode(fen: startFen);
      line(root, ['e4', 'e5', 'Nf3']);

      final beats = beatsOf(root, root);

      expect(beats.map((b) => b.arrivedBy), [null, 'e4', 'e5', 'Nf3']);
      expect(beats.map((b) => b.index), [0, 1, 2, 3]);
    });

    test('the move out of a beat is the move into the next one', () {
      // The two halves of the same edge, read from the two ends. A panel draws
      // `plays` under the sentence and `arrivedBy` in the header, so if these
      // ever disagree the same move is on screen twice saying two things.
      final root = AnalysisNode(fen: startFen);
      line(root, ['d4', 'd5', 'c4']);

      final beats = beatsOf(root, root);

      for (var i = 0; i + 1 < beats.length; i++) {
        expect(beats[i].plays, beats[i + 1].arrivedBy,
            reason: 'beat $i plays a different move than beat ${i + 1} says '
                'arrived');
      }
      expect(beats.last.plays, isNull,
          reason: 'the line has run out here — this is where the question is '
              'asked, and a move drawn under it would be a move the child '
              'never gets to see');
      expect(beats.last.isLast, isTrue);
      expect(beats.take(beats.length - 1).every((b) => b.isLast), isFalse);
    });

    test('the walk goes on past where the author stands', () {
      final root = AnalysisNode(fen: startFen);
      final first = child(root, 'e4');
      line(first, ['e5', 'Nf3', 'Nc6']);

      final beats = beatsOf(root, first);

      expect(beats.map((b) => b.arrivedBy), [null, 'e4', 'e5', 'Nf3', 'Nc6'],
          reason: 'the timeline is the whole line, not the part behind the '
              'author');
      expect(beats.where((b) => b.isCurrent).map((b) => b.arrivedBy), ['e4'],
          reason: 'exactly one beat is where the author is standing');
    });
  });

  group('a fork is named, not walked', () {
    test('the alternatives are on the beat they leave from', () {
      final root = AnalysisNode(fen: startFen);
      final e4 = child(root, 'e4');
      child(e4, 'e5');
      child(e4, 'c5');

      final beats = beatsOf(root, root);
      final fork = beats.firstWhere((b) => b.arrivedBy == 'e4');

      expect(fork.branches.map((b) => b.san), ['e5', 'c5'],
          reason: 'both replies belong to the position they are played from');
      expect(fork.branches.map((b) => b.taken), [true, false],
          reason: 'the first child is the line this projection follows, and '
              'the author has to be able to see which one that is');
      expect(fork.plays, 'e5');
    });

    test('a beat with one move out has nothing to choose', () {
      final root = AnalysisNode(fen: startFen);
      line(root, ['e4', 'e5']);

      expect(beatsOf(root, root).every((b) => b.branches.isEmpty), isTrue,
          reason: 'a fork drawn where there is no fork is a choice the author '
              'never made');
    });

    test('standing in a sideline projects that sideline', () {
      // The one that matters. The author clicks into the second reply and the
      // timeline must follow *them* — a projection that walks first children
      // from the root would draw the main line while the board shows the
      // sideline, which is the two-views-disagreeing fault this panel exists
      // to avoid.
      final root = AnalysisNode(fen: startFen);
      final e4 = child(root, 'e4');
      child(e4, 'e5');
      final c5 = child(e4, 'c5');
      line(c5, ['Nf3', 'd6']);

      final beats = beatsOf(root, c5);

      expect(beats.map((b) => b.arrivedBy), [null, 'e4', 'c5', 'Nf3', 'd6']);
      final fork = beats.firstWhere((b) => b.arrivedBy == 'e4');
      expect(fork.plays, 'c5',
          reason: 'the move out of the fork is the one the author took, not '
              'the first child');
      expect(fork.branches.map((b) => b.taken), [false, true],
          reason: 'the branch marked taken is the one the timeline below it '
              'actually follows');
    });

    test('a fork below the author still follows the first child', () {
      final root = AnalysisNode(fen: startFen);
      final e4 = child(root, 'e4');
      final e5 = child(e4, 'e5');
      child(e5, 'Nf3');
      child(e5, 'Bc4');

      final beats = beatsOf(root, e4);

      expect(beats.map((b) => b.arrivedBy), [null, 'e4', 'e5', 'Nf3']);
      expect(beats.firstWhere((b) => b.arrivedBy == 'e5').branches.length, 2);
    });
  });

  group('the move number a beat carries', () {
    // `moveNumberLabel` came out of `VisualMoveTreeWidget`, where it was
    // private, the moment the timeline needed the same sentence. It is gated
    // here because it is the pure half of what a beat's header says, and
    // because a tutorial part may open on any position — the ply from the root
    // is not the move number, and only the FEN knows where the counting
    // started.
    test('white and black are numbered the way a book writes them', () {
      final root = AnalysisNode(fen: startFen);
      final e4 = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          moveSan: 'e4',
          parent: root);
      final e5 = AnalysisNode(
          fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          moveSan: 'e5',
          parent: e4);

      expect(e4.moveNumberLabel, '1. ');
      expect(e5.moveNumberLabel, '1... ',
          reason: "black's move belongs to the number before the one its own "
              'position carries');
    });

    test('a part that opens mid-game counts from where it opens', () {
      final root = AnalysisNode(fen: startFen);
      final late = AnalysisNode(
          fen:
              'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 5 12',
          moveSan: 'Bc4',
          parent: root);

      expect(late.moveNumberLabel, '12. ',
          reason: 'the ply from the root would say „1." here, and a trainer '
              'writing about a middlegame would be told the wrong move number');
    });

    test('the opening position is a position, not a move', () {
      expect(AnalysisNode(fen: startFen).moveNumberLabel, '');
    });

    test('a beat writes both of its moves the way a book would', () {
      // The labels exist so that a card never composes a move number itself.
      // Real FENs here rather than the fixture's shorthand, because the number
      // is read out of the FEN and a fixture that cannot be parsed would let a
      // broken label pass as an empty one.
      final root = AnalysisNode(fen: startFen);
      final e4 = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          moveSan: 'e4',
          parent: root);
      root.children.add(e4);
      final e5 = AnalysisNode(
          fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          moveSan: 'e5',
          parent: e4);
      e4.children.add(e5);

      final beats = beatsOf(root, root);

      expect(beats[0].arrivedLabel, isNull,
          reason: 'nothing arrived at the opening position');
      expect(beats[0].playsLabel, '1. e4');
      expect(beats[1].arrivedLabel, '1. e4');
      expect(beats[1].playsLabel, '1... e5',
          reason: 'the move out of a beat is written from the node it goes to, '
              'not from the one it leaves');
      expect(beats.last.playsLabel, isNull);
      expect(beats.last.plays, isNull);
    });

    test('a fork chip is numbered like the beats around it', () {
      final root = AnalysisNode(fen: startFen);
      for (final san in ['e4', 'd4']) {
        final node = AnalysisNode(
            fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
            moveSan: san,
            parent: root);
        root.children.add(node);
      }

      expect(beatsOf(root, root).first.branches.map((b) => b.label),
          ['1. e4', '1. d4']);
    });
  });

  group('what it refuses to break on', () {
    test('a node that is not in this tree projects the root line', () {
      // A screen holds the author's node across edits, and a stale one used to
      // read as „no beats at all" — an empty panel over a tutorial that is
      // perfectly fine. Drawing the root's line is wrong about *where the
      // author is* and right about everything else, which is the better half
      // to be wrong about.
      final root = AnalysisNode(fen: startFen);
      line(root, ['e4', 'e5']);
      final orphan = AnalysisNode(fen: startFen, moveSan: 'h4');

      final beats = beatsOf(root, orphan);

      expect(beats.map((b) => b.arrivedBy), [null, 'e4', 'e5']);
      expect(beats.first.isCurrent, isTrue,
          reason: 'with the author nowhere in the tree, the opening position '
              'is where the panel should put them');
    });

    test('a root that is itself hung under something terminates', () {
      // Not hypothetical arithmetic: the studio hands `_rootNode` and
      // `_currentNode` to this function, and a section swapped underneath while
      // one of them is held is exactly how a screen ends up with a „root" that
      // has a parent. The first version of this function recursed here and
      // would have hung the app rather than drawn a wrong panel.
      final realRoot = AnalysisNode(fen: startFen);
      final notReallyRoot = child(realRoot, 'e4');
      line(notReallyRoot, ['e5']);

      final beats = beatsOf(notReallyRoot, realRoot);

      expect(beats, isNotEmpty);
      expect(beats.first.node, same(notReallyRoot));
      expect(beats.map((b) => b.arrivedBy), ['e4', 'e5']);
    });
  });
}
