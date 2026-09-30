/// A position of the opening report as a tree for Analysis.
///
/// The owner, 30.9.2026: from a position on the Opening leaks screen, go to
/// Analysis with the moves from the start of the game to that position,
/// analyse there, and come back to where he was.
///
/// The tree is the line the server sent ([OpeningLine]: the moves of the
/// latest game that reached the position), and it stands on the position.
/// There, it holds a branch for each move the report knows about: the moves
/// the player chose, most played first, so the main line is the habit; and
/// the engine's better move when it is not one of them. A move the engine
/// judged carries the line it answered with, cut as a puzzle's reveal is cut
/// ([revealLine], the one home of how much of an engine line is shown).
/// Nothing but moves goes into the tree — no comment and no evaluation, since
/// a tree opened here may become a tutorial, and a tutorial speaks its
/// comments.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/answer_line.dart' show revealLine;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;

typedef OpeningPositionTree = ({AnalysisNode root, AnalysisNode position});

/// The tree of [line], standing on the position [fenKey] names, with each of
/// [branches] (SAN moves from that position, the main line first) added
/// there.
///
/// **Null when [line] does not reach the position [fenKey] names** — the
/// screen says so rather than open Analysis on a board that is not the one
/// the card shows. One check covers a line that stops early as well: a move
/// that does not play leaves the board short of it, and a board short of a
/// move is never the same board.
OpeningPositionTree? openingPositionTree({
  required OpeningLine line,
  required String fenKey,
  List<List<String>> branches = const [],
}) {
  if (chess.Chess.validate_fen(line.startFen)['valid'] != true) return null;
  final tree = analysisTreeFromMoves(line.startFen, line.uciMoves);
  final position = nodeAtPly(tree.root, line.uciMoves.length);
  if (!_sameBoard(position.fen, fenKey)) return null;
  for (final branch in branches) {
    _addBranch(position, branch);
  }
  return (root: tree.root, position: position);
}

/// The branches of a flagged position: every move the player chose there,
/// most played first, each with the engine's line after it when it was
/// judged; then the engine's better move, when the player never chose it.
List<List<String>> branchesOfNode(LeakReportNode node) {
  final best = _deepest(node.moves.map((m) => m.judgement));
  final chosen = <String>{};
  final branches = <List<String>>[];
  for (final move in node.moves) {
    if (move.uci != null) chosen.add(move.uci!);
    final judged = move.judgement?.moveLine ?? const <String>[];
    if (judged.isNotEmpty) {
      branches.add(judged);
    } else if (best != null && move.uci != null && move.uci == best.bestUci) {
      // The engine's own choice, never judged as a habit: its line is the
      // best line.
      branches.add(best.bestLine);
    } else {
      branches.add([move.san]);
    }
  }
  if (best != null &&
      best.bestLine.isNotEmpty &&
      !chosen.contains(best.bestUci)) {
    branches.add(best.bestLine);
  }
  return branches;
}

/// The branches of a losing habit: the habit with the engine's line after it,
/// then the better move with its own.
List<List<String>> branchesOfHabit(LosingHabit habit) {
  final judgement = habit.judgement;
  return [
    if (judgement != null && judgement.moveLine.isNotEmpty)
      judgement.moveLine
    else
      [habit.san],
    if (judgement != null && judgement.bestLine.isNotEmpty) judgement.bestLine,
  ];
}

/// The judgement whose best line to show: the deepest, the first of equals.
HabitJudgement? _deepest(Iterable<HabitJudgement?> judgements) {
  HabitJudgement? best;
  for (final j in judgements) {
    if (j == null || j.bestLine.isEmpty) continue;
    if (best == null || j.depth > best.depth) best = j;
  }
  return best;
}

/// Placement, side to move and castling. **Not the en passant field**: the
/// server's chess.js writes it only when a capture is possible there, and the
/// app's `chess` package after every double push, so the same board carries
/// two spellings of it (measured 30.9.2026: after 1.e4 c5 the server keys
/// the board with `-` and the app writes `c6`).
bool _sameBoard(String fen, String fenKey) {
  List<String> head(String s) =>
      s.trim().split(RegExp(r'\s+')).take(3).toList();
  final a = head(fen);
  final b = head(fenKey);
  return a.length == 3 &&
      b.length == 3 &&
      a[0] == b[0] &&
      a[1] == b[1] &&
      a[2] == b[2];
}

/// [sans] as far as they play from [fen], in this app's own spelling — so
/// the reveal's cut, which plays them again by exact SAN, cannot refuse one.
/// A move that does not play ends the list: an engine line is an extra, and
/// the moves before it are still real.
List<String> _playable(String fen, List<String> sans) {
  final board = chess.Chess.fromFEN(fen);
  final out = <String>[];
  for (final san in sans) {
    final chess.Move move;
    try {
      move = findMove(board, san.trim());
    } on StateError {
      break;
    }
    out.add(board.move_to_san(move));
    board.make_move(move);
  }
  return out;
}

/// Walks [sans] down from [from] — the moves that play, cut as a reveal is
/// cut — reusing a child that already plays the same move and making the
/// rest.
void _addBranch(AnalysisNode from, List<String> sans) {
  final playable = _playable(from.fen, sans);
  if (playable.isEmpty) return;
  // At least the first move, and at most the reveal's `kRevealPlies`.
  final shown = revealLine(from.fen, playable);
  final board = chess.Chess.fromFEN(from.fen);
  var parent = from;
  for (final san in shown) {
    final move = findMove(board, san);
    final promotion = move.promotion;
    final uci = '${move.fromAlgebraic}${move.toAlgebraic}'
        '${promotion == null ? '' : promotion.toLowerCase()}';
    final written = board.move_to_san(move);
    board.make_move(move);
    AnalysisNode? next;
    for (final child in parent.children) {
      if (child.moveUci == uci) {
        next = child;
        break;
      }
    }
    if (next == null) {
      next = AnalysisNode(
        fen: board.fen,
        moveSan: written,
        moveUci: uci,
        parent: parent,
      );
      parent.children.add(next);
    }
    parent = next;
  }
}
