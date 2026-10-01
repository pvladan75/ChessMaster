/// An endgame position as a tree for Analysis — `Open in Analysis` in the
/// trainer (docs/PLAN-TRENER-ZAVRSNICA.md, D1, D6, D14, D15).
///
/// The shape of `opening_position_tree.dart`, and its rule: **nothing but
/// moves goes into the tree** — no comment, no NAG, no arrow, no square —
/// since a tree opened in Analysis may become a tutorial, and a tutorial
/// speaks its comments (D6). The Syzygy panel says which move loses.
///
/// Under the puzzle's position, in this order:
///   1. the reader's moves, in the order found, each with the reply the
///      server gave it when one came;
///   2. every other move that holds, in the server's order;
///   3. the move played in the game, when the position comes from one;
///   4. the drill's line, continuing under whichever of those its first move
///      is, or as a last branch of its own — and a Punish line under the
///      game's move.
/// A child that plays the same move is reused, never doubled.
///
/// The drill is replayed move by move from where the previous move left it,
/// never found by FEN: the server's FENs are chess.js's and the tree's are the
/// app's, and across that boundary two strings are one board only by
/// placement, side and castling. A FEN is kept with each drill move only as a
/// check that the replay is where the drill was.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess/chess.dart' as chess;

/// One move of a play-it-out drill, as the trainer keeps it.
class DrillMove {
  DrillMove({
    required this.fenBefore,
    required this.uci,
    this.replyUci,
    this.takenBack = false,
  });

  /// The position the move was played in.
  final String fenBefore;
  final String uci;

  /// The opponent's answer, when the server gave one — never after a move
  /// that lost the result.
  final String? replyUci;

  /// Set by `Take back`: the move stays in the tree as a side branch of the
  /// position it was played from, and the next move is played from there
  /// (D15).
  bool takenBack;
}

/// The drill's moves as the trainer keeps them: new state, since the drill
/// itself keeps none — its board is rebuilt from the server's FEN after every
/// judged move (docs/PLAN-TRENER-ZAVRSNICA.md, §2).
class DrillLog {
  final List<DrillMove> _moves = [];

  /// Whether the line is a Punish line, which starts after the game's move.
  bool fromGameMove = false;

  List<DrillMove> get moves => List.unmodifiable(_moves);

  /// A new drill, or `Start over`: the reader asking for a clean board.
  void start({required bool fromGameMove}) {
    _moves.clear();
    this.fromGameMove = fromGameMove;
  }

  void played(String fenBefore, String uci, {String? replyUci}) =>
      _moves.add(DrillMove(fenBefore: fenBefore, uci: uci, replyUci: replyUci));

  /// `Take back`: the move is kept, as a side branch (D15). Not removed — the
  /// losing move is the one thing in the drill worth examining.
  void takeBack() {
    if (_moves.isNotEmpty) _moves.last.takenBack = true;
  }
}

/// What the trainer knows when the reader opens Analysis.
class EndgameTreeInput {
  const EndgameTreeInput({
    required this.fen,
    this.found = const [],
    this.replies = const {},
    this.holding = const [],
    this.gameMoveSan,
    this.drill = const [],
    this.drillFromGameMove = false,
  });

  /// The puzzle's position.
  final String fen;

  /// The reader's moves, in the order found (UCI).
  final List<String> found;

  /// The reply each found move got (UCI), where one came.
  final Map<String, String?> replies;

  /// Every move that holds, in the server's order (UCI).
  final List<String> holding;

  /// The move played in the game, as the database keeps it (SAN). Only a
  /// position from a real mistake has one.
  final String? gameMoveSan;

  /// The drill's moves, in the order played, taken-back ones included.
  final List<DrillMove> drill;

  /// True for a Punish drill, which starts after the game's move.
  final bool drillFromGameMove;
}

typedef EndgameTree = ({AnalysisNode root, AnalysisNode standOn});

/// The tree of [input]. Analysis stands on the root, or — [fromDrill] — on
/// the last node the drill's replay produced.
EndgameTree endgameAnalysisTree(EndgameTreeInput input,
    {bool fromDrill = false}) {
  final root = AnalysisNode(fen: input.fen);

  for (final uci in input.found) {
    final move = _child(root, uci);
    if (move == null) continue;
    final reply = input.replies[uci];
    if (reply != null) _child(move, reply);
  }
  for (final uci in input.holding) {
    _child(root, uci);
  }
  AnalysisNode? gameMove;
  final san = input.gameMoveSan;
  if (san != null && san.isNotEmpty) {
    final uci = _uciOfSan(input.fen, san);
    if (uci != null) gameMove = _child(root, uci);
  }

  var last = root;
  final start = input.drillFromGameMove ? gameMove : root;
  if (start != null && input.drill.isNotEmpty) {
    var cursor = start;
    for (final step in input.drill) {
      if (!_sameBoard(cursor.fen, step.fenBefore)) break;
      final move = _child(cursor, step.uci);
      if (move == null) break;
      var after = move;
      final reply = step.replyUci;
      if (reply != null) after = _child(move, reply) ?? move;
      last = after;
      // A move taken back is a leaf beside the move played instead; the
      // drill goes on from the position it was played in.
      if (!step.takenBack) cursor = after;
    }
  }

  return (root: root, standOn: fromDrill ? last : root);
}

/// The child of [parent] that plays [uci], reused when it is there. Null when
/// the move cannot be played. A promotion written without its piece is a
/// queen, as `EndgameSolveSession.sameMove` reads it.
AnalysisNode? _child(AnalysisNode parent, String uci) {
  if (uci.length < 4) return null;
  var tree = analysisTreeFromMoves(parent.fen, [uci]);
  if (tree.playable == 0 && uci.length == 4) {
    tree = analysisTreeFromMoves(parent.fen, ['${uci}q']);
  }
  if (tree.playable == 0) return null;
  final made = tree.root.children.single;
  return parent.addChild(
    childFen: made.fen,
    san: made.moveSan!,
    uci: made.moveUci!,
  );
}

String? _uciOfSan(String fen, String san) {
  final board = chess.Chess.fromFEN(fen);
  if (board.move(san) == false) return null;
  final move = board.history.last.move;
  final promotion = move.promotion;
  return '${move.fromAlgebraic}${move.toAlgebraic}'
      '${promotion == null ? '' : promotion.name.toLowerCase()}';
}

/// Placement, side to move and castling — not the en passant field, which
/// chess.js and the app's package write differently.
bool _sameBoard(String a, String b) {
  List<String> head(String s) =>
      s.trim().split(RegExp(r'\s+')).take(3).toList();
  final x = head(a);
  final y = head(b);
  return x.length == 3 &&
      y.length == 3 &&
      x[0] == y[0] &&
      x[1] == y[1] &&
      x[2] == y[2];
}
