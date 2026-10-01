/// What the tables say about one position, whole.
///
/// Asked for by hand, in a drill where the reader is stuck. Not a hint that
/// picks a move for them: the finding itself, every legal move with what it
/// leaves behind, so the reader can see why one move is different from another
/// rather than be told which to play.
library;

import 'package:chess_app/core/services/mate_distance.dart';

class ReadoutMove {
  const ReadoutMove({
    required this.san,
    required this.uci,
    required this.outcome,
    required this.holds,
    required this.zeroing,
    this.dtz,
    this.dtm,
    this.checkmate = false,
  });

  final String san;
  final String uci;

  /// 'win', 'draw' or 'loss', for the player making the move.
  final String outcome;

  /// Whether it keeps what there was to keep.
  final bool holds;

  /// Whether it resets the fifty-move counter — a capture or a pawn move. In a
  /// won position that is progress by definition, which is why it is here
  /// beside the distance rather than left to be inferred from it.
  final bool zeroing;

  /// Half-moves to the next zeroing move, not to mate. Null where the tables
  /// give none.
  final int? dtz;

  /// The tablebase's distance to mate, as it gave it — the opponent's after
  /// this move, in plies (`mateInAfterMove` reads it). Null where no source
  /// knew it: our own tables never do, and seven men mostly do not.
  final int? dtm;

  /// Whether the move mates, which carries no [dtm] of its own.
  final bool checkmate;

  /// „mate in 21" / „mated in 20" for the player making the move, or null.
  int? get mateIn => mateInAfterMove(dtm, checkmate: checkmate);

  factory ReadoutMove.fromJson(Map<String, dynamic> json) => ReadoutMove(
        san: json['san']?.toString() ?? '',
        uci: json['uci']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? 'draw',
        holds: json['holds'] == true,
        zeroing: json['zeroing'] == true,
        dtz: json['dtz'] is num ? (json['dtz'] as num).toInt() : null,
        dtm: json['dtm'] is num ? (json['dtm'] as num).toInt() : null,
        checkmate: json['checkmate'] == true,
      );
}

class TablebaseReadout {
  const TablebaseReadout({
    required this.goal,
    required this.outcome,
    required this.holding,
    required this.total,
    required this.pawnless,
    required this.deadDraw,
    required this.moves,
    this.dtz,
    this.dtm,
  });

  final String goal;
  final String outcome;

  /// How many of the legal moves keep the result.
  final int holding;
  final int total;

  final bool pawnless;

  /// Nothing left to hold: no pawns, and every move that loses does so by
  /// giving a piece away. The trainer's own rule, and the reason a dead drawn
  /// rook ending can be closed instead of shuffled out to a repetition.
  final bool deadDraw;

  final int? dtz;

  /// The position's own distance to mate, as the tablebase gave it.
  final int? dtm;

  /// The moves in the server's order, which is the tablebase's: best first
  /// for the side to move, whichever side that is. Never sorted again here.
  final List<ReadoutMove> moves;

  /// „mate in 28" / „mated in 27" for the side to move, or null.
  int? get mateIn => mateInFromPosition(dtm);

  /// True when a move that wins or loses came without a distance to mate —
  /// Lichess did not answer, or seven men — so that move is placed by DTZ
  /// and the screen must not let DTZ pass for a distance to mate.
  bool get mateDistanceMissing =>
      moves.any((m) => m.outcome != 'draw' && m.mateIn == null);

  factory TablebaseReadout.fromJson(Map<String, dynamic> json) =>
      TablebaseReadout(
        goal: json['goal']?.toString() ?? 'win',
        outcome: json['outcome']?.toString() ?? 'draw',
        holding: json['holding'] is num ? (json['holding'] as num).toInt() : 0,
        total: json['total'] is num ? (json['total'] as num).toInt() : 0,
        pawnless: json['pawnless'] == true,
        deadDraw: json['deadDraw'] == true,
        dtz: json['dtz'] is num ? (json['dtz'] as num).toInt() : null,
        dtm: json['dtm'] is num ? (json['dtm'] as num).toInt() : null,
        moves: ((json['moves'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ReadoutMove.fromJson)
            .toList(),
      );

  /// The moves that lose although nothing is hanging — what still has to be
  /// got right here. Empty in a position that is over.
  List<ReadoutMove> get dropping => moves.where((m) => !m.holds).toList();
}

/// How a position's own verdict reads on screen.
String outcomeWord(String outcome) {
  switch (outcome) {
    case 'win':
      return 'win';
    case 'loss':
      return 'loss';
    default:
      return 'draw';
  }
}
