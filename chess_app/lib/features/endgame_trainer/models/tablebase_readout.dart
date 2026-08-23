/// What the tables say about one position, whole.
///
/// Asked for by hand, in a drill where the reader is stuck. Not a hint that
/// picks a move for them: the finding itself, every legal move with what it
/// leaves behind, so the reader can see why one move is different from another
/// rather than be told which to play.
library;

class ReadoutMove {
  const ReadoutMove({
    required this.san,
    required this.uci,
    required this.outcome,
    required this.holds,
    required this.zeroing,
    this.dtz,
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

  factory ReadoutMove.fromJson(Map<String, dynamic> json) => ReadoutMove(
        san: json['san']?.toString() ?? '',
        uci: json['uci']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? 'draw',
        holds: json['holds'] == true,
        zeroing: json['zeroing'] == true,
        dtz: json['dtz'] is num ? (json['dtz'] as num).toInt() : null,
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
  final List<ReadoutMove> moves;

  factory TablebaseReadout.fromJson(Map<String, dynamic> json) =>
      TablebaseReadout(
        goal: json['goal']?.toString() ?? 'win',
        outcome: json['outcome']?.toString() ?? 'draw',
        holding: json['holding'] is num ? (json['holding'] as num).toInt() : 0,
        total: json['total'] is num ? (json['total'] as num).toInt() : 0,
        pawnless: json['pawnless'] == true,
        deadDraw: json['deadDraw'] == true,
        dtz: json['dtz'] is num ? (json['dtz'] as num).toInt() : null,
        moves: ((json['moves'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ReadoutMove.fromJson)
            .toList(),
      );

  /// The moves that lose although nothing is hanging — what still has to be
  /// got right here. Empty in a position that is over.
  List<ReadoutMove> get dropping => moves.where((m) => !m.holds).toList();
}

/// How a position's own verdict reads in Serbian.
String outcomeWord(String outcome) {
  switch (outcome) {
    case 'win':
      return 'dobitak';
    case 'loss':
      return 'gubitak';
    default:
      return 'remi';
  }
}
