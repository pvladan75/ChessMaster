/// The assessment on a move survives being read back.
///
/// `AnalysisNode.nag` has existed since the Analysis Studio was built and
/// `PgnExporterService` has always written it — but until 12.9.2026 nothing
/// read one back: `MoveTree.parsePgn` stripped `!` and `?` to get at the move
/// and threw them away, `MoveNode` had nowhere to put them, and `readStepTree`
/// could not carry across what it was never given.
///
/// What that cost: „Review entire game" writes `c5??` and the „Better move"
/// line beside it, the file keeps both, and the first time a trainer reopened
/// that part in the studio and touched anything at all, the re-export wrote
/// `c5`. The blunder marks of a whole game, gone, silently — and they are
/// exactly the marks a question generator has to read to know *where* the
/// lesson is.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// `parsePgn` answers null for a text it cannot start from at all; every
  /// fixture here starts from the opening position, so a null is the test's own
  /// mistake and should say so rather than blow up three lines later.
  MoveTree parsed(String pgn) {
    final tree = MoveTree.parsePgn(pgn, startingFen: startFen);
    expect(tree, isNotNull, reason: 'the fixture did not parse at all: $pgn');
    return tree!;
  }

  List<AnalysisNode> mainLineOf(AnalysisNode root) {
    final out = <AnalysisNode>[];
    var node = root;
    while (node.children.isNotEmpty) {
      node = node.children.first;
      out.add(node);
    }
    return out;
  }

  group('the parser keeps the glyph', () {
    test('a blunder mark stays on its move', () {
      final tree = parsed('1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4??');

      final line = <MoveNode>[];
      var node = tree.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        line.add(node);
      }

      expect(line.map((n) => n.san).toList(),
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nd4']);
      expect(line.last.nag, '??');
      // The move itself is still the move: the glyph is read off it, not left
      // on it, or `chess.dart` cannot play it.
      expect(line.map((n) => n.nag).take(5), everyElement(isNull));
    });

    test('every glyph this app can draw', () {
      for (final glyph in ['!', '!!', '?', '??', '!?', '?!']) {
        final tree = parsed('1. e4$glyph');
        expect(tree.root.children.single.nag, glyph,
            reason: 'e4$glyph should come back carrying $glyph');
        expect(tree.root.children.single.san, 'e4');
        expect(tree.rejectedMoves, 0);
      }
    });

    test('a numeric NAG lands on the move in front of it', () {
      // What a game annotated anywhere but here looks like: the standard's
      // codes rather than this app's glyphs.
      final tree = parsed('1. e4 e5 2. Nf3 \$2 Nc6 \$1');
      final line = <MoveNode>[];
      var node = tree.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        line.add(node);
      }

      expect(line.map((n) => n.san).toList(), ['e4', 'e5', 'Nf3', 'Nc6']);
      expect(line[2].nag, '?', reason: '\$2 is a question mark');
      expect(line[3].nag, '!', reason: '\$1 is an exclamation mark');
      expect(tree.rejectedMoves, 0, reason: 'a NAG is not a move that failed');
    });

    test('a code with no glyph here is dropped rather than invented', () {
      // `$14` is „White is slightly better". There is no mark for it in this
      // app, and putting one on the move would say something the app cannot
      // draw and the trainer never wrote.
      final tree = parsed('1. e4 \$14');
      expect(tree.root.children.single.nag, isNull);
      expect(tree.rejectedMoves, 0);
    });

    test('a glyph written on the move beats a code written after it', () {
      final tree = parsed('1. e4! \$2');
      expect(tree.root.children.single.nag, '!');
    });

    test('a glyph does not break the result marker glued to a move', () {
      // The rule from 7.9.2026: `Nxb4*` at the end of a line is a move and a
      // result, not an unplayable token. With a glyph in between it is still
      // both.
      final tree = parsed('1. e4 e5 2. Nf3!*');
      expect(tree.rejectedMoves, 0);
      final last =
          mainLineOf(readStepTree(fen: startFen, pgn: '1. e4 e5 2. Nf3!*').root)
              .last;
      expect(last.moveSan, 'Nf3');
      expect(last.nag, '!');
    });
  });

  group('the studio gets it, and gives it back', () {
    test('readStepTree carries the glyph onto the AnalysisNode', () {
      final read = readStepTree(
          fen: startFen, pgn: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? *');
      final line = mainLineOf(read.root);

      expect(read.rejectedMoves, 0);
      expect(line.last.moveSan, 'Nd4');
      expect(line.last.nag, '??');
      expect(read.root.nag, isNull, reason: 'a position is not a move');
    });

    test('a reviewed line survives the round trip it used to lose', () {
      // The shape „Review entire game" writes: a blunder, and the engine's own
      // line beside it marked `!` with a sentence on it.
      const reviewed = '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? '
          '(3... Bc5! { Better move } 4. O-O) 4. Nxe5 *';

      final first = readStepTree(fen: startFen, pgn: reviewed).root;
      final written = PgnExporterService.exportToPgn(first);

      expect(written, contains('Nd4??'));
      expect(written, contains('Bc5!'));
      expect(written, contains('Better move'));

      // And again, because the studio writes what it read: a part that is
      // reopened, edited and saved goes through this twice.
      final second = readStepTree(fen: startFen, pgn: written).root;
      expect(PgnExporterService.exportToPgn(second), written,
          reason: 'the second pass must not lose what the first one kept');
    });

    test('the tree signature notices a glyph that went missing', () {
      // `treeSignature` is what tells a section „you are unedited, write your
      // stored text back". It has always included the nag — which was dead
      // weight while nothing could read one, and is what keeps a re-export
      // honest now.
      final withGlyph =
          readStepTree(fen: startFen, pgn: '1. e4 e5 2. Nf3??').root;
      final without = readStepTree(fen: startFen, pgn: '1. e4 e5 2. Nf3').root;

      expect(treeSignature(withGlyph), isNot(treeSignature(without)));
    });
  });
}
