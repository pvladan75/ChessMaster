/// What makes a finding before a move the same finding after it.
///
/// A finding names squares, and until 13.9.2026 those squares were its
/// identity — so a piece that moved took its finding to a new identity, and one
/// move reported the same hanging queen twice: „no longer hanging" on the
/// square it left, and hanging on the square it reached. A walking king did the
/// same with its missing pawn shield on every step.
///
/// So the squares of a finding from *before* the move are read as they stand
/// *after* it: the square the moved piece left is the square it went to.
/// Everything else about a finding — its kind, and whom it favours — is
/// compared as it is.
///
/// Only the piece named by the move is followed. A castling rook or a pawn
/// taken en passant is not, and a finding about one of those reads as ended and
/// begun — which is what every finding did before, not something new.
library;

/// The identity [TacticalMotifDetector.explainMove] and
/// [PositionalEvaluatorService.explainMove] compare findings by. Pass
/// [lastMoveUci] for a finding read from the position *before* that move, and
/// nothing for one read after it.
String findingKey({
  required bool favorsMover,
  required Iterable<String> kinds,
  required List<String> squares,
  String? lastMoveUci,
}) {
  final moved = lastMoveUci != null && lastMoveUci.length >= 4;
  final from = moved ? lastMoveUci.substring(0, 2) : null;
  final to = moved ? lastMoveUci.substring(2, 4) : null;
  final followed = [for (final square in squares) square == from ? to! : square]
    ..sort();
  final sortedKinds = [...kinds]..sort();
  return '$favorsMover::${sortedKinds.join(',')}::${followed.join(',')}';
}
