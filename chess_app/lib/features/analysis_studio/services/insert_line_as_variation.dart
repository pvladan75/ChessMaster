/// Playing an engine's line into an [AnalysisNode] tree as a variation.
///
/// Beside the model rather than in a screen, because Preparation needs it and
/// a screen is not where a tree rule belongs (rule 12: one rule, one home).
/// The room has the same idea over its own model (`MoveTree.appendLine`,
/// `_insertEngineLineAsVariation` in `chess_game_screen.dart`) — that one
/// stamps the engine's evaluation onto the first move's comment, which
/// Preparation deliberately does not do (a comment here may become what a
/// tutorial's voice reads out, §3 of `docs/PLAN-PRIPREMA.md`), so this is a
/// second small copy rather than a shared one; see the phase 1 report.
library;

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

/// What [insertLineAsVariation] did with the moves it was given.
class InsertedLine {
  const InsertedLine({required this.added, required this.rejected});

  /// How many nodes were actually created. Zero means every move was already
  /// in the tree, or the first one was not legal from [from] — [rejected]
  /// tells those two apart.
  final int added;

  /// The first move was not legal from [from]'s position — the line was
  /// searched from somewhere else.
  final bool rejected;
}

/// Plays the UCI moves of [continuationLan] (space-separated, e.g.
/// `"e2e4 e7e5 g1f3"`) one at a time from [from], walking into a move the
/// tree already has rather than adding it twice. The cursor is not moved —
/// that is the caller's decision, and [from] is left standing wherever it
/// was.
InsertedLine insertLineAsVariation(AnalysisNode from, String continuationLan) {
  final moves = continuationLan
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (moves.isEmpty) return const InsertedLine(added: 0, rejected: true);

  var node = from;
  var added = 0;
  for (final uci in moves) {
    if (uci.length < 4) {
      return InsertedLine(added: added, rejected: added == 0);
    }
    final existing =
        node.children.where((c) => c.moveUci == uci || _sameMove(c, uci));
    if (existing.isNotEmpty) {
      node = existing.first;
      continue;
    }

    final played = playedMove(
      fen: node.fen,
      from: uci.substring(0, 2),
      to: uci.substring(2, 4),
      promotion: uci.length > 4 ? uci.substring(4, 5) : '',
    );
    if (played == null) {
      return InsertedLine(added: added, rejected: added == 0);
    }
    node =
        node.addChild(childFen: played.fen, san: played.san, uci: played.uci);
    added++;
  }
  return InsertedLine(added: added, rejected: false);
}

/// [AnalysisNode.moveUci] on a promotion carries the piece
/// (`playedMove`/`addChild` write `e7e8q`), while the engine's own
/// continuation may leave it off on a pawn that only has one way to promote.
/// Matched by the from/to squares alone when the stored move is a
/// promotion of the same pair, so a line is not added twice over that.
bool _sameMove(AnalysisNode child, String uci) {
  final stored = child.moveUci;
  if (stored == null || stored.length < 4 || uci.length < 4) return false;
  return stored.substring(0, 4) == uci.substring(0, 4);
}
