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
}
