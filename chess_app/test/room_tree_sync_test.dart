import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/room_tree_sync.dart';
import 'package:chess_app/move_tree.dart';

/// A room member rebuilds the tree from where the broadcast starts, not from
/// where their own tree started. See `lib/core/services/room_tree_sync.dart`.
void main() {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const endgame = '8/8/8/4k3/8/8/4K3/4R3 w - - 0 1';

  test('a broadcast from a loaded position keeps its moves, under its own root',
      () {
    // What the trainer's app broadcasts after loading a position and playing
    // one move from it.
    final pgn =
        MoveTree.parsePgn('1. Ra1', startingFen: endgame)!.exportToPgn();
    expect(pgn, contains('[FEN "$endgame"]'));

    final received = treeFromBroadcast(pgn, cursorPath: const [])!;
    expect(received.root.fen, endgame);
    expect(received.root.children.map((c) => c.san), ['Ra1']);
    expect(received.rejectedMoves, 0);
  });

  test(
      'a broadcast from the standard opening needs no header and plays from it',
      () {
    final received =
        treeFromBroadcast('1. e4 e5 2. Nf3', cursorPath: const ['e4', 'e5'])!;
    expect(received.root.fen, start);
    expect(received.current.san, 'e5');
  });

  test('the receiver\'s cursor stays where it was when that path still exists',
      () {
    final received = treeFromBroadcast('1. e4 e5 2. Nf3 Nc6',
        cursorPath: const ['e4', 'e5', 'Nf3'])!;
    expect(received.current.san, 'Nf3');
  });

  test('a cursor path that does not exist in the new tree goes to the root',
      () {
    final pgn =
        MoveTree.parsePgn('1. Ra1', startingFen: endgame)!.exportToPgn();
    final received = treeFromBroadcast(pgn, cursorPath: const ['e4', 'e5'])!;
    expect(identical(received.current, received.root), isTrue);
  });
}
