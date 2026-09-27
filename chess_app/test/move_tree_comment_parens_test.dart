// A comment's own parentheses are its words, not a variation.
//
// Found 27.9.2026 by phase 8 of docs/PLAN-PRIPREMA.md: a sentence read back
// through the one reader came back changed, because `parsePgn` set every `(`
// and `)` apart — the comments' too — and joined the comment's tokens with a
// space. A trainer's „(see move 12)" came back from every save as
// „( see move 12 )".
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';

void main() {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('parentheses inside a comment come back as they were written', () {
    final tree = MoveTree.parsePgn(
        '{ The plan (f4) works. } 1. e4 { Then (see move 12) f4. } *',
        startingFen: start)!;
    expect(tree.root.comment, 'The plan (f4) works.');
    expect(tree.root.children.single.comment, 'Then (see move 12) f4.');
  });

  test('a variation beside such a comment is still a variation', () {
    final tree = MoveTree.parsePgn(
        '1. e4 { (a note) } (1. d4 { the other (way) }) 1... e5 *',
        startingFen: start)!;
    final root = tree.root;
    expect(root.children.map((c) => c.san).toList(), ['e4', 'd4']);
    expect(root.children[0].comment, '(a note)');
    expect(root.children[1].comment, 'the other (way)');
    expect(root.children[0].children.single.san, 'e5');
  });
}
