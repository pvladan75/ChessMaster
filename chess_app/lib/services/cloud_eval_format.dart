/// Lichess's cloud evaluation, turned into the label the panels draw.
///
/// The whole file exists for one sentence, and the sentence is the part that
/// was wrong: **Lichess reports cloud evaluations from White's point of view.**
/// `mate: -8` with Black to move means White is being mated in 8, not Black,
/// and `cp: 22` means White stands a fifth of a pawn better whoever is to move.
/// Verified against the live API on 24.8.2026 with three positions whose sign
/// is not arguable — Black a queen up with White to move (`mate: -8`), White a
/// rook up with Black to move (`mate: 14`), and 1.f3 e5 2.g4 Qh4# (`mate: -1`).
///
/// The app draws evaluations from White's side too, so nothing has to be
/// flipped here. It used to be: the online path negated the score for every
/// position with Black to move, which showed every such evaluation with its
/// sign inverted — and only for one colour, which is exactly the shape of fault
/// that survives a hundred glances.
///
/// The **native** engine is the opposite case and must keep its flip. UCI
/// reports `score cp` relative to the side to move, so an engine line in a
/// Black-to-move position does need negating to become White-relative. Two
/// sources, two conventions; this function is only ever for the cloud.
String cloudEvalLabel({num? cp, int? mate}) {
  if (mate != null) {
    return mate > 0 ? 'M$mate' : '-M${mate.abs()}';
  }
  if (cp != null) {
    final score = cp / 100.0;
    return score > 0
        ? '+${score.toStringAsFixed(2)}'
        : score.toStringAsFixed(2);
  }
  return '0.00';
}
