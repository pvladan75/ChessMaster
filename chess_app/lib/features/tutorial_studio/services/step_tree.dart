/// Reading a saved lesson step back into the tree the studio writes on.
///
/// This is phase P1 of `docs/PLAN-STUDIO-REDIZAJN.md`, and it is the piece the
/// whole redesign was waiting for. Until now a finished example was flattened
/// to `fen` + `pgn` and its tree was dropped, so a section could never be
/// reopened — which is the entire reason a second, weaker editing screen had to
/// exist beside the studio.
///
/// **There is exactly one reader, and it is the child's.**
/// [LessonStepLine.read] parses a step's `pgn` against that step's own `fen`
/// and returns a [MoveTree] carrying the comments, the `[%cal]` arrows, the
/// `[%csl]` squares and the sidelines — plus [LessonStepLine.rejectedMoves],
/// which is how a line that belongs to a different position is told from a step
/// that was always a still diagram.
///
/// `AnalysisStudioScreen._importPgn` must never be used for this and must never
/// be copied here. It goes through `chess.load_pgn` and `getHistory()`, which
/// keeps the main line and throws away every comment, every arrow, every
/// coloured square and every variation. A trainer reopening a tutorial through
/// it would be shown a board that looked right and would silently lose
/// everything they had written on it — the recurring fault of this repository,
/// in the most expensive form it could take.
///
/// What is added here is only the crossing from [MoveNode] to [AnalysisNode].
/// The two are already near-isomorphic; nothing is parsed twice.
library;

import 'package:chess_app/core/services/legal_moves.dart' show promotionOf;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/move_tree.dart';

/// One step's line, as a tree the studio can be written on.
///
/// [rejectedMoves] is carried out rather than swallowed: above zero means the
/// `pgn` and the `fen` describe different games, and the caller has to be able
/// to say so instead of showing a trainer a board with moves missing from it.
typedef StepTree = ({AnalysisNode root, int rejectedMoves});

/// Reads [pgn] against [fen] and returns the tree it comes to.
///
/// A step with no line answers with a bare root on its own position, which is
/// what most of a tutorial is: „pogledaj polje d5" is a step with no moves in
/// it.
StepTree readStepTree({required String fen, String? pgn}) {
  final read = LessonStepLine.read(fen: fen, pgn: pgn);
  final tree = read.tree;
  if (tree == null) {
    return (root: AnalysisNode(fen: fen), rejectedMoves: read.rejectedMoves);
  }
  return (
    root: _convert(tree.root, fen: fen),
    rejectedMoves: read.rejectedMoves,
  );
}

/// The crossing. [MoveNode] carries `san`, `fen`, `comment`, `arrows`,
/// `squares` and `children`; [AnalysisNode] carries the same five and a `uci`.
///
/// [fen] is passed in for the root because the tree's own root fen is the one
/// the parser was told to start from — the same string — and taking it from the
/// caller keeps this function honest when a future parser normalises it.
AnalysisNode _convert(MoveNode source, {String? fen}) {
  final node = AnalysisNode(
    fen: fen ?? source.fen,
    moveSan: source.san.isEmpty ? null : source.san,
    moveUci: source.san.isEmpty ? null : _uciOf(source),
    comment: source.comment,
    // Copied rather than shared: the parsed tree is thrown away as soon as this
    // returns, but a list handed on by reference is the kind of sharing that
    // turns into two screens editing one object a year later.
    arrows: List<ChessArrow>.from(source.arrows),
    squares: List<SquareMark>.from(source.squares),
  );

  for (final child in source.children) {
    final converted = _convert(child);
    converted.parent = node;
    node.children.add(converted);
  }
  return node;
}

/// `e2e4`, and `e7e8q` when a pawn became something.
///
/// [MoveNode] holds `from` and `to` as plain squares and has nowhere to put the
/// promotion, so it is read out of the SAN — through [promotionOf], which is
/// the one place in this app that knows `chess.dart` does not fill that field
/// in. A uci with the letter missing is a move the board refuses, which is how
/// every promotion this app ever lost was lost.
String _uciOf(MoveNode node) =>
    '${node.from}${node.to}${promotionOf({'san': node.san})}';

/// A deep copy with fresh ids, for cloning a section.
///
/// `fromJson` mints a new id for every node as it goes, which is exactly what
/// is wanted: two sections sharing node identity is the same class of fault as
/// two tutorials sharing a step id.
AnalysisNode copyTree(AnalysisNode root) =>
    AnalysisNode.fromJson(root.toJson());

/// A comparable rendering of everything a trainer can put on a tree.
///
/// It exists so a section can tell whether its tree still says what the stored
/// `pgn` said, without keeping a second copy of the tree around to compare
/// against. See [TutorialSection.toJson]: an untouched section is written back
/// as the exact text it was read from, because `PgnExporterService` stamps a
/// fresh `[Date]` on every call and would otherwise rewrite lines nobody
/// edited.
///
/// The `fen` is deliberately not in it — it is derived from the moves — and
/// neither is the node id, which changes on every copy and means nothing to a
/// reader.
String treeSignature(AnalysisNode root) {
  final out = StringBuffer();
  void walk(AnalysisNode node) {
    out
      ..write(node.moveSan ?? '')
      ..write('|')
      ..write(node.nag ?? '')
      ..write('|')
      ..write(node.comment)
      ..write('|')
      ..write(node.arrows.map((a) => a.toString()).join(','))
      ..write('|')
      ..write(node.squares.map((s) => s.toString()).join(','))
      ..write('|')
      ..write(node.children.length)
      ..write(';');
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(root);
  return out.toString();
}

/// The end of the main line — where the next section starts when the trainer
/// asks it to continue from here.
///
/// That position is what makes „show, then ask" one board with no reset on the
/// child's screen: `LessonViewerScreen` crosses the join without reloading when
/// the next step stands on the position the line ran out at.
AnalysisNode endOfMainLine(AnalysisNode root) {
  var node = root;
  while (node.children.isNotEmpty) {
    node = node.children.first;
  }
  return node;
}
