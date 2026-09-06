import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/move_tree.dart';

/// Phase 2 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: one PGN dialect, written and
/// read by one pair of functions.
///
/// Two parsers used to split this job. `PgnParser.parse` deleted `{comments}`
/// and then `(variations)` and handed back a flat list of positions; the lesson
/// viewer took its line from that and its comments from `MoveTree.parsePgn`,
/// then threw the whole result away whenever the two disagreed about how many
/// moves there were. A note under the wrong move is worse than no note — it is
/// the trainer appearing to say something they did not — so dropping them all
/// was the right call for a design that should not have existed.
///
/// Everything a lesson step is made of therefore has to survive one round trip
/// through the one reader: the moves, the words, the branches, the arrows, and
/// the squares the trainer coloured in.
const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A rook ending, so a step can start somewhere other than move one.
const _endgameFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

/// The position after 1. e4, for the studio-side tests.
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1';

MoveTree _treeWith(void Function(MoveTree tree) build, {String? from}) {
  final tree = MoveTree(startingFen: from ?? _startFen);
  build(tree);
  return tree;
}

/// The comments of the main line, top to bottom.
List<String> _mainLineComments(MoveTree tree) {
  final out = <String>[];
  var node = tree.root;
  while (node.children.isNotEmpty) {
    node = node.children.first;
    out.add(node.comment);
  }
  return out;
}

void main() {
  group('the round trip keeps everything a step is made of', () {
    test('the words a trainer wrote come back', () {
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['e2e4', 'e7e5', 'g1f3']);
        line.head!.comment = 'Zauzima centar.';
        line.end.comment = 'Napada pešaka na e5.';
      });

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;

      expect(_mainLineComments(reread),
          ['Zauzima centar.', '', 'Napada pešaka na e5.']);
    });

    test('a nested variation comes back as a branch, not as the game', () {
      // `PgnParser` read `1. e4 (1. d4 d5) e5` as e4, d5, e5 — a line nobody
      // played, shown to a child as their homework. It fixed that by deleting
      // variations outright, which is no use to a lesson that is *about* the
      // sideline.
      final tree = _treeWith((t) {
        MoveTree.appendLine(t.root, ['e2e4', 'e7e5']);
        MoveTree.appendLine(t.root, ['d2d4', 'd7d5']);
      });

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;

      expect(reread.root.children.length, 2,
          reason: 'both first moves survive');
      expect(reread.root.children[0].san, 'e4');
      expect(reread.root.children[1].san, 'd4');
      expect(reread.root.children[1].children.single.san, 'd5');

      // And the main line is still the main line.
      expect(reread.root.children[0].children.single.san, 'e5');
    });

    test('arrows come back', () {
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['e2e4']);
        line.end.arrows = [
          ChessArrow(from: 'd1', to: 'h5', colorCode: 'G'),
          ChessArrow(from: 'f1', to: 'c4', colorCode: 'R'),
        ];
      });

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;
      final arrows = reread.root.children.single.arrows;

      expect(arrows.length, 2);
      expect(arrows[0].from, 'd1');
      expect(arrows[0].to, 'h5');
      expect(arrows[0].colorCode, 'G');
      expect(arrows[1].colorCode, 'R');
    });

    test('marked squares come back', () {
      // `[%csl]` is how every other chess tool records a coloured square, and
      // nothing here parsed it. A weak square is the thing half these lessons
      // are *about*, so it cannot be the one annotation we drop.
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['e2e4']);
        line.end.squares = [
          SquareMark(square: 'd5', colorCode: 'R'),
          SquareMark(square: 'f5', colorCode: 'Y'),
        ];
      });

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;
      final squares = reread.root.children.single.squares;

      expect(squares.length, 2);
      expect(squares[0].square, 'd5');
      expect(squares[0].colorCode, 'R');
      expect(squares[1].square, 'f5');
      expect(squares[1].colorCode, 'Y');
    });

    test('words, arrows and squares in one comment do not swallow each other',
        () {
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['e2e4']);
        line.end.comment = 'Polje d5 je slabo.';
        line.end.arrows = [ChessArrow(from: 'd1', to: 'h5', colorCode: 'G')];
        line.end.squares = [SquareMark(square: 'd5', colorCode: 'R')];
      });

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;
      final node = reread.root.children.single;

      expect(node.comment, 'Polje d5 je slabo.');
      expect(node.arrows.single.to, 'h5');
      expect(node.squares.single.square, 'd5');
    });

    test('a line that starts somewhere other than move one round trips', () {
      // The reason the viewer needed a `_sameFen` guard at all: the old parser
      // always replayed from the standard position, so a step scanned out of an
      // endgame book came back as a different game entirely.
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['a1a8']);
        line.end.comment = 'Mat.';
      }, from: _endgameFen);

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _endgameFen)!;

      expect(reread.root.children.single.san, 'Ra8#');
      expect(reread.root.children.single.comment, 'Mat.');
    });

    test('what is written about the starting position round trips', () {
      // The note ahead of move one, which both writers used to parse and
      // neither used to write. It is the only place a sentence about a *still*
      // position can live, and a still position is most of what a lesson step
      // is — so it was the one thing an export could not carry.
      final tree = _treeWith((t) {
        t.root.comment = 'Pogledaj polje d5.';
        t.root.squares = [SquareMark(square: 'd5', colorCode: 'R')];
        MoveTree.appendLine(t.root, ['e2e4']);
      });

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;

      expect(reread.root.comment, 'Pogledaj polje d5.');
      expect(reread.root.squares.single.square, 'd5');
      expect(reread.root.children.single.san, 'e4',
          reason: 'the note must not swallow the first move');
    });

    test('the studio writes the same note in the same place', () {
      final root = AnalysisNode(fen: _startFen);
      root.comment = 'Pogledaj polje d5.';
      root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4');

      final reread = MoveTree.parsePgn(
        PgnExporterService.exportToPgn(root),
        startingFen: _startFen,
      )!;

      expect(reread.root.comment, 'Pogledaj polje d5.');
      expect(reread.root.children.single.san, 'e4');
    });
  });

  group('annotations are never shown to the reader as words', () {
    test('an arrow tag is not part of the comment', () {
      final node = MoveTree.parsePgn(
        '1. e4 { Napad. [%cal Gd1h5] }',
        startingFen: _startFen,
      )!
          .root
          .children
          .single;

      expect(node.comment, 'Napad.');
      expect(node.arrows.single.from, 'd1');
    });

    test('a square tag is not part of the comment', () {
      // This one leaked. `cleanPgnComment` stripped `[%cal ...]` and nothing
      // else, so a PGN written anywhere but here put „[%csl Rd5]" on screen in
      // the middle of the trainer's sentence.
      final node = MoveTree.parsePgn(
        '1. e4 { Slabo polje. [%csl Rd5] }',
        startingFen: _startFen,
      )!
          .root
          .children
          .single;

      expect(node.comment, 'Slabo polje.');
      expect(node.squares.single.square, 'd5');
    });

    test('a comment that is nothing but tags leaves no stray text', () {
      final node = MoveTree.parsePgn(
        '1. e4 { [%cal Gd1h5][%csl Rd5] }',
        startingFen: _startFen,
      )!
          .root
          .children
          .single;

      expect(node.comment, '');
      expect(node.arrows.length, 1);
      expect(node.squares.length, 1);
    });
  });

  group('the main line is read once, so it cannot disagree with itself', () {
    test('every move has exactly one note beside it', () {
      // The guarantee that replaces the old length check. Moves and notes come
      // out of one walk of one tree, so "the two readings disagree" has stopped
      // being a state this code can be in.
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['e2e4', 'e7e5', 'g1f3']);
        line.head!.comment = 'Zauzima centar.';
        MoveTree.appendLine(t.root, ['d2d4', 'd7d5']);
      });

      final line =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!
              .mainLine();

      expect(line.movesSan, ['e4', 'e5', 'Nf3']);
      expect(line.comments.length, line.movesSan.length);
      expect(line.arrows.length, line.movesSan.length);
      expect(line.squares.length, line.movesSan.length);
      expect(line.comments.first, 'Zauzima centar.');

      // fens[0] is the position before the first move, so there is always one
      // more of them than there are moves.
      expect(line.fens.length, line.movesSan.length + 1);
      expect(line.fens.first, _startFen);
    });

    test('a sideline does not shift the main line', () {
      final tree = _treeWith((t) {
        final line = MoveTree.appendLine(t.root, ['e2e4', 'e7e5', 'g1f3']);
        line.end.comment = 'Napada pešaka na e5.';
        MoveTree.appendLine(t.root, ['d2d4', 'd7d5']);
      });

      final line =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!
              .mainLine();

      expect(line.movesSan, ['e4', 'e5', 'Nf3']);
      expect(line.comments.last, 'Napada pešaka na e5.');
    });

    test('a tree with no moves is an empty line, not a crash', () {
      final line = MoveTree(startingFen: _endgameFen).mainLine();

      expect(line.movesSan, isEmpty);
      expect(line.comments, isEmpty);
      expect(line.fens, [_endgameFen]);
    });
  });

  group("the studio tree and the room tree write one dialect", () {
    test("an arrow drawn in the studio is read back by MoveTree", () {
      // Two models of one tree used to disagree about what a node may carry:
      // `MoveTree` held arrows and wrote `[%cal]`, `AnalysisNode` held none
      // and wrote none. A trainer arrow therefore survived the room and
      // vanished through the studio — a loss nobody reports, because it looks
      // like they forgot to draw it.
      final root = AnalysisNode(fen: _startFen);
      final e4 = root.addChild(childFen: _afterE4, san: "e4", uci: "e2e4");
      e4.comment = "Polje d5 je slabo.";
      e4.arrows = [ChessArrow(from: "d1", to: "h5", colorCode: "G")];
      e4.squares = [SquareMark(square: "d5", colorCode: "R")];

      final node = MoveTree.parsePgn(
        PgnExporterService.exportToPgn(root),
        startingFen: _startFen,
      )!
          .root
          .children
          .single;

      expect(node.comment, "Polje d5 je slabo.");
      expect(node.arrows.single.to, "h5");
      expect(node.squares.single.square, "d5");
    });

    test("a saved studio tree keeps what was drawn on it", () {
      final root = AnalysisNode(fen: _startFen);
      final e4 = root.addChild(childFen: _afterE4, san: "e4", uci: "e2e4");
      e4.arrows = [ChessArrow(from: "d1", to: "h5", colorCode: "G")];
      e4.squares = [SquareMark(square: "d5", colorCode: "R")];

      final child = AnalysisNode.fromJson(root.toJson()).children.single;

      expect(child.arrows.single.from, "d1");
      expect(child.arrows.single.colorCode, "G");
      expect(child.squares.single.square, "d5");
    });

    test("a tree saved before these fields existed reads back empty", () {
      final reread = AnalysisNode.fromJson({
        "fen": _startFen,
        "comment": "",
        "children": const [],
      });

      expect(reread.arrows, isEmpty);
      expect(reread.squares, isEmpty);
    });
  });
}
