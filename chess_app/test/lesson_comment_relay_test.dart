import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/pgn_parser.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A note written on a move in the studio has to survive being exported to
/// PGN, saved as a lesson, sent as homework and read back by the viewer — which
/// reads the line with one parser and the notes with another. These check that
/// the two agree about how many moves there are, which is the only thing that
/// keeps a note under the move it was written for.
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

    test('both readings of the line count the same moves', () {
      final line = PgnParser.parse(pgn);
      final tree = MoveTree.parsePgn(pgn, startingFen: _startFen);

      expect(line, isNotNull);
      expect(tree, isNotNull);

      final comments = <String>[];
      var node = tree!.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        comments.add(node.comment);
      }

      expect(line!.movesSan, ['e4', 'e5', 'Nf3']);
      expect(comments.length, line.movesSan.length);
      expect(comments, ['Zauzima centar.', '', 'Napada pešaka na e5.']);
    });

    test('a sideline does not shift the main line’s notes', () {
      final tree = MoveTree.parsePgn(pgn, startingFen: _startFen)!;
      // The trainer adds an alternative first move after writing the notes.
      MoveTree.appendLine(tree.root, ['d2d4', 'd7d5']);
      final withSideline = tree.exportToPgn();

      final line = PgnParser.parse(withSideline);
      final reread = MoveTree.parsePgn(withSideline, startingFen: _startFen)!;

      final comments = <String>[];
      var node = reread.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        comments.add(node.comment);
      }

      expect(line!.movesSan, ['e4', 'e5', 'Nf3']);
      expect(comments, ['Zauzima centar.', '', 'Napada pešaka na e5.']);
    });
  });

  group('PgnParser.stripVariations', () {
    test('a nested variation goes in full', () {
      expect(
        PgnParser.stripVariations('1. e4 (1. d4 d5 (1... Nf6 2. c4)) e5 2. Nf3')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        '1. e4 e5 2. Nf3',
      );
    });

    test('an unbalanced bracket does not eat the rest of the game', () {
      expect(
        PgnParser.stripVariations('1. e4 ) e5').replaceAll(RegExp(r'\s+'), ' '),
        '1. e4 e5',
      );
    });

    test('a game with no variations comes back unchanged', () {
      expect(PgnParser.stripVariations('1. e4 e5 2. Nf3'), '1. e4 e5 2. Nf3');
    });
  });
}
