// `MoveTree.sanTokens` — reading just the moves out of a PGN body.
//
// Added with phase 1b of `docs/PLAN-LISTE.md`. The game picker needed it
// because the owner's 4126 games come from online play and carry
// `{ [%clk H:MM:SS] }` after every move, which broke both the preview and the
// move search. It is on `MoveTree` rather than in the dialog because that is
// where this project keeps what it knows about PGN, and a second half-answer
// somewhere else is how the first one came about (rule 12).
//
// Pure, so it is tested here directly rather than only through a widget. A
// mutation that stopped it dropping variations survived the dialog's own gate
// — the dialog's fixtures have none — which is what this file is for.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';

void main() {
  test('plain movetext comes back as its moves', () {
    expect(MoveTree.sanTokens('1. e4 e5 2. Nf3 Nc6 3. Bb5 a6'),
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']);
  });

  test('clock annotations after every move are not moves', () {
    // The exact shape the owner's collection is in, and the reason this
    // function exists: `1. e4 { … } 1... c5` does not contain "e4 c5".
    const body = '1. e4 { [%clk 0:03:00] } 1... c5 { [%clk 0:03:00] } '
        '2. Nf3 { [%clk 0:02:58] } 1-0';
    expect(MoveTree.sanTokens(body), ['e4', 'c5', 'Nf3']);
    expect(MoveTree.sanTokens(body).join(' '), contains('e4 c5'));
  });

  test('NAGs are not moves', () {
    expect(MoveTree.sanTokens(r'1. d4 $1 Nf6 $6 2. c4'), ['d4', 'Nf6', 'c4']);
  });

  test('a variation is not the game', () {
    // The mainline only. A picker row that showed a side line as if it were
    // played would be worse than one that showed nothing.
    expect(MoveTree.sanTokens('1. e4 e5 (1... c5 2. Nf3) 2. Bc4 *'),
        ['e4', 'e5', 'Bc4']);
  });

  test('a variation inside a variation goes too', () {
    expect(
        MoveTree.sanTokens('1. e4 e5 (1... c5 (1... e6 2. d4) 2. Nf3) 2. Bc4'),
        ['e4', 'e5', 'Bc4']);
  });

  test('a comment holding a brace or a bracket does not swallow the game', () {
    expect(MoveTree.sanTokens('1. e4 { [%cal Ge2e4] } e5 2. Nf3'),
        ['e4', 'e5', 'Nf3']);
  });

  test('a result is not a move, in any of its forms', () {
    for (final result in ['1-0', '0-1', '1/2-1/2', '*']) {
      expect(MoveTree.sanTokens('1. e4 e5 $result'), ['e4', 'e5'],
          reason: '"$result" was read as a move');
    }
  });

  test('move numbers go, glued or standing alone', () {
    expect(MoveTree.sanTokens('1.e4 e5 2.Nf3'), ['e4', 'e5', 'Nf3']);
    expect(MoveTree.sanTokens('1... e5 2. Nf3'), ['e5', 'Nf3']);
  });

  test('check, mate and annotation glyphs stay on the move', () {
    // Not cleaned here on purpose: this reader shows and matches, it does not
    // play. `Qh4#` is what the file says and what a reader searching for it
    // will type.
    expect(
        MoveTree.sanTokens('1. f4 e6 2. g4 Qh4#'), ['f4', 'e6', 'g4', 'Qh4#']);
  });

  test('nothing in, nothing out', () {
    expect(MoveTree.sanTokens(''), isEmpty);
    expect(MoveTree.sanTokens('   '), isEmpty);
    expect(MoveTree.sanTokens('{ [%clk 0:03:00] }'), isEmpty);
    expect(MoveTree.sanTokens('1-0'), isEmpty);
  });
}
