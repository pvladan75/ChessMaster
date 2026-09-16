import 'package:chess_app/move_tree.dart';

/// The move tree a room member builds from a PGN another member broadcast.
///
/// Found by the architecture audit on 16.9.2026 (`docs/audit/app.md`, 5): the
/// receiver parsed every broadcast PGN against its **own** root. When the trainer
/// loaded a saved position, a tutorial step or a pasted game, the broadcast began
/// somewhere else — its `[FEN]` header said where — and the receiver replayed its
/// moves from the old root, rejected every one without a word, and was left with
/// an empty tree under a position nobody's board showed any more.
///
/// The broadcast says where it starts: `MoveTree.exportToPgn` writes a `[FEN]`
/// header whenever the root is not the standard opening, and `parsePgn` reads it
/// when it is not overridden. So nothing is overridden here.
///
/// The cursor stays on the receiver's path when that path still exists in the
/// new tree, and goes to the root when it does not — a path from the old root
/// means nothing under a new one. `null` when the text is not a game at all.
MoveTree? treeFromBroadcast(String pgn, {required List<String> cursorPath}) {
  final tree = MoveTree.parsePgn(pgn);
  if (tree == null) return null;
  tree.current = nodeAtPath(tree.root, cursorPath) ?? tree.root;
  return tree;
}

/// The node reached by following [path], a list of SAN moves, from [root].
MoveNode? nodeAtPath(MoveNode root, List<String> path) {
  var current = root;
  for (final san in path) {
    MoveNode? next;
    for (final child in current.children) {
      if (child.san == san) {
        next = child;
        break;
      }
    }
    if (next == null) return null;
    current = next;
  }
  return current;
}
