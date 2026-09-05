import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A note written on a move in the studio has to survive being exported to PGN,
/// saved as a lesson, sent as homework and read back by the viewer.
///
/// **What these tests assert changed in phase 2 of
/// `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`.** They used to check that two parsers
/// agreed about how many moves a line had, because the viewer read the line
/// with `PgnParser.parse` and the notes with `MoveTree.parsePgn` and threw
/// every note away when the counts differed. That check was the right response
/// to a wrong design: a note under the wrong move is the trainer appearing to
/// say something they did not.
///
/// There is one reader now. `MoveTree.mainLine()` builds the moves and the notes
/// in a single walk, so they are the same length by construction and there is
/// nothing left to compare. What these tests guard instead is that the note
/// stays attached to **its own move** through an export, a re-read, and a
/// sideline added afterwards.
void main() {
  group('a trainer comment travels from the studio to the homework', () {
    late String pgn;

    setUp(() {
      final tree = MoveTree(startingFen: _startFen);
      final line = MoveTree.appendLine(tree.root, ['e2e4', 'e7e5', 'g1f3']);
      line.head!.comment = 'Zauzima centar.';
      line.end.comment = 'Napada pešaka na e5.';
      pgn = tree.exportToPgn();
    });

    test('the export carries the notes', () {
      expect(pgn, contains('Zauzima centar.'));
      expect(pgn, contains('Napada pešaka na e5.'));
    });

    test('every move comes back with its own note', () {
      final line = MoveTree.parsePgn(pgn, startingFen: _startFen)!.mainLine();

      expect(line.movesSan, ['e4', 'e5', 'Nf3']);
      expect(line.comments, ['Zauzima centar.', '', 'Napada pešaka na e5.']);
    });

    test('the moves and the notes cannot come back different lengths', () {
      // The old failure, now unreachable rather than checked for. Both lists
      // are appended to inside one loop over one tree.
      final line = MoveTree.parsePgn(pgn, startingFen: _startFen)!.mainLine();

      expect(line.comments.length, line.movesSan.length);
      expect(line.arrows.length, line.movesSan.length);
      expect(line.squares.length, line.movesSan.length);
      expect(line.fens.length, line.movesSan.length + 1);
    });

    test('a sideline added later does not shift the main line’s notes', () {
      final tree = MoveTree.parsePgn(pgn, startingFen: _startFen)!;
      // The trainer adds an alternative first move after writing the notes.
      MoveTree.appendLine(tree.root, ['d2d4', 'd7d5']);

      final line =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!
              .mainLine();

      expect(line.movesSan, ['e4', 'e5', 'Nf3']);
      expect(line.comments, ['Zauzima centar.', '', 'Napada pešaka na e5.']);
    });

    test('the sideline is kept, not deleted, and keeps its own notes', () {
      // `PgnParser.stripVariations` used to remove branches outright — the only
      // safe thing to do with a reader that would otherwise splice a sideline
      // into the game. A lesson about the sideline needs it kept.
      final tree = MoveTree.parsePgn(pgn, startingFen: _startFen)!;
      final side = MoveTree.appendLine(tree.root, ['d2d4', 'd7d5']);
      side.head!.comment = 'Druga mogućnost.';

      final reread =
          MoveTree.parsePgn(tree.exportToPgn(), startingFen: _startFen)!;

      expect(reread.root.children.length, 2);
      expect(reread.root.children[1].san, 'd4');
      expect(reread.root.children[1].comment, 'Druga mogućnost.');
      expect(reread.root.children[1].children.single.san, 'd5');

      // And the main line is untouched by any of it.
      expect(reread.mainLine().movesSan, ['e4', 'e5', 'Nf3']);
    });
  });

  group('what the author wrote before the first move', () {
    // The only place an arrow or a coloured square about a *still* position can
    // live, and a still position is most of what an interactive lesson is:
    // „look at d5" is a step with no moves in it. `parsePgn` has always
    // attached a leading comment to the root; `mainLine()` dropped it on the
    // way out, which was invisible while nothing read arrows or squares at all.
    const pgn = '{ Slabo polje d5. [%csl Rd5] [%cal Gf3d5] } 1. e4 e5';

    test('its words, its squares and its arrows all survive the flattening',
        () {
      final line = MoveTree.parsePgn(pgn, startingFen: _startFen)!.mainLine();

      expect(line.rootComment, 'Slabo polje d5.');
      expect(line.rootSquares.single.square, 'd5');
      expect(line.rootSquares.single.colorCode, 'R');
      expect(line.rootArrows.single.toString(), 'Gf3d5');
    });

    test('and it is not confused with the first move’s own note', () {
      final line = MoveTree.parsePgn(pgn, startingFen: _startFen)!.mainLine();

      // The root's note belongs to `fens[0]`, not to `e4`. Folding the two
      // together would make the trainer appear to have written about a move
      // they wrote about a position.
      expect(line.comments, ['', '']);
      expect(line.squares, [[], []]);
      expect(line.arrows, [[], []]);
    });

    test('a line with no leading comment says so with empties', () {
      final line =
          MoveTree.parsePgn('1. e4 e5', startingFen: _startFen)!.mainLine();

      expect(line.rootComment, '');
      expect(line.rootSquares, isEmpty);
      expect(line.rootArrows, isEmpty);
    });
  });
}
