/// What a trainer has prepared in a room, read back through the app's one
/// reader before it leaves the screen.
///
/// The room writes on a [MoveTree]; everything that *keeps* a tree — a saved
/// analysis (`saved_analyses.tree_json`), the Analysis board, a tutorial part —
/// holds an [AnalysisNode]. The crossing already exists and is used by every
/// other importer in the app: `MoveTree.exportToPgn` writes, `readStepTree` →
/// `LessonStepLine` → `MoveTree.parsePgn` reads, and `_convert` in
/// `step_tree.dart` carries the result over. Nothing here parses a move.
///
/// **Why the round trip rather than a direct copy of the nodes.** CLAUDE.md's
/// rule from 6.9.2026: *the writer reads its own work back through the reader's
/// parser before saving it*. A line that cannot be replayed from the position it
/// is saved with is the fault this repository has already paid for twice — the
/// studio's „Napravi korak od ove pozicije" and the room's „Save position" —
/// and both times it was silent, because the screen said „saved" and the loss
/// only appeared when somebody else opened the board. [rejectedMoves] is that
/// number, carried out rather than swallowed, so the caller can refuse instead
/// of storing a shorter line than the trainer built.
///
/// It should always be zero: the room's writer and the app's reader are meant
/// to agree. That is exactly why it is worth checking — a disagreement between
/// them is a bug somewhere else, and this is the cheapest place it can surface.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

/// The room's tree, as the rest of the app holds a tree.
///
/// [pgn] is what the room itself wrote — kept so a caller that cannot use
/// [root] (because the read-back lost moves) can still hand the trainer their
/// own moves rather than nothing.
typedef PreparedLine = ({
  AnalysisNode root,
  String pgn,
  int rejectedMoves,
  int moveCount,
});

/// Reads [tree] back and reports what came of it.
PreparedLine readPreparedLine(MoveTree tree) {
  final pgn = tree.exportToPgn();
  final read = readStepTree(fen: tree.root.fen, pgn: pgn);
  return (
    root: read.root,
    pgn: pgn,
    rejectedMoves: read.rejectedMoves,
    moveCount: _moveCount(read.root),
  );
}

/// Nothing here worth keeping: no move read back, and none lost either.
///
/// One predicate rather than the same condition written at each door, because
/// „empty" and „the reader lost everything" look identical from the outside and
/// must not be answered with the same sentence — a board with one unreadable
/// move is not an empty board, and telling the trainer it is would hide the
/// only symptom the fault has.
bool preparedLineIsEmpty(PreparedLine line) =>
    line.moveCount == 0 && line.rejectedMoves == 0;

/// Why this line must not be stored, or null when it may be.
///
/// A separate function, and public, because it is the half worth testing on
/// its own: a refusal branch reached only when the app's own writer and reader
/// disagree is a branch no fixture built out of legal moves can ever enter.
/// Given a record, this can be made to fail.
String? preparedLineRefusal(PreparedLine line) {
  if (line.rejectedMoves > 0) {
    final moves = line.rejectedMoves == 1 ? 'move' : 'moves';
    return '${line.rejectedMoves} $moves on this board could not be read back, '
        'so saving it would store a shorter line than you built. '
        'Nothing was saved. Tell the developer which position this is.';
  }
  if (preparedLineIsEmpty(line)) {
    return 'There are no moves on this board yet. '
        'Play the line you want to keep, then save it.';
  }
  return null;
}

/// Moves in the whole tree, sidelines included. The root is a position, not a
/// move, so it does not count itself.
int _moveCount(AnalysisNode root) {
  var total = 0;
  void walk(AnalysisNode node) {
    for (final child in node.children) {
      total++;
      walk(child);
    }
  }

  walk(root);
  return total;
}
