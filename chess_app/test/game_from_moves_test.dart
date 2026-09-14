// A game from the archive, rebuilt as an Analysis tree — D4 of
// `docs/PLAN-SKELET.md`.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

List<String> _sans(GameTree tree) {
  final out = <String>[];
  for (var node = tree.root;
      node.children.isNotEmpty;
      node = node.children.first) {
    out.add(node.children.first.moveSan!);
  }
  return out;
}

void main() {
  test('the moves become one line of nodes, with SAN, UCI and positions', () {
    final tree = analysisTreeFromMoves(_start, ['e2e4', 'e7e5', 'g1f3']);
    expect(tree.playable, 3);
    expect(_sans(tree), ['e4', 'e5', 'Nf3']);
    final third = tree.root.children.first.children.first.children.first;
    expect(third.moveUci, 'g1f3');
    expect(third.fen, startsWith('rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/'));
    expect(third.parent!.moveSan, 'e5');
  });

  test('castling written as the king taking its rook is read as castling', () {
    const fen =
        'r3k2r/pppqbppp/2np1n2/4p3/4P3/2NP1N2/PPPQBPPP/R3K2R w KQkq - 4 8';
    expect(
        _sans(analysisTreeFromMoves(fen, ['e1h1', 'e8a8'])), ['O-O', 'O-O-O']);
    expect(
        _sans(analysisTreeFromMoves(fen, ['e1g1', 'e8c8'])), ['O-O', 'O-O-O']);
  });

  test('a rook moving from e1 to h1 is a rook move, not castling', () {
    // Only the king taking its rook is castling written the Lichess way.
    const fen = '4k3/8/8/8/8/8/8/K3R3 w - - 0 1';
    expect(_sans(analysisTreeFromMoves(fen, ['e1h1'])), ['Rh1']);
  });

  test('the cursor stands on the ply asked for, or on the last move', () {
    final tree = analysisTreeFromMoves(_start, ['e2e4', 'e7e5', 'g1f3']);
    expect(nodeAtPly(tree.root, 0), same(tree.root));
    expect(nodeAtPly(tree.root, 2).moveSan, 'e5');
    expect(nodeAtPly(tree.root, 3).moveSan, 'Nf3');
    expect(nodeAtPly(tree.root, 40).moveSan, 'Nf3',
        reason: 'a ply past the end stands on the last move');
  });

  test('a promotion is played as the piece it names', () {
    const fen = '4k3/1P6/8/8/8/8/8/4K3 w - - 0 1';
    expect(_sans(analysisTreeFromMoves(fen, ['b7b8n'])), ['b8=N']);
  });

  test('a move that cannot be played ends the line, and says how far it got',
      () {
    // e7e5 would play if the refused move were skipped rather than ending it.
    final tree = analysisTreeFromMoves(_start, ['e2e4', 'e2e4', 'e7e5']);
    expect(tree.playable, 1);
    expect(_sans(tree), ['e4']);
  });

  test('no moves is the starting position alone', () {
    final tree = analysisTreeFromMoves(_start, const []);
    expect(tree.playable, 0);
    expect(tree.root.children, isEmpty);
  });
}
