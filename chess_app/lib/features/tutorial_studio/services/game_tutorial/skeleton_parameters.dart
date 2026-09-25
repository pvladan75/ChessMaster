/// The tutorial's shape. **No threshold since phase 1b** of
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`: what a mistake is, and which other
/// moves count as right, is the mistake rule's (`mistake_rule.dart`), decided
/// by the review's judge and written into the facts — the trainer's pawn
/// slider (`minCost`) and the 0.3 pawns of „near the best" (`near`) went with
/// it, on the owner's word of 25.9.2026.
class SkeletonParameters {
  const SkeletonParameters({
    this.maxMoments = 8,
    this.leadPlies = 3,
    this.answerPlies = 4,
    this.maxAnswerPlies = 8,
  });

  final int maxMoments;
  final int leadPlies;
  final int answerPlies;

  /// The most the answer line is ever extended to, when it would otherwise end
  /// mid-sacrifice. A bound rather than „the whole line": the stored line is
  /// six plies today, and this must not become „show the whole engine PV" the
  /// day that changes.
  final int maxAnswerPlies;

  Map<String, dynamic> toJson() => {
        'max_moments': maxMoments,
        'lead_plies': leadPlies,
        'answer_plies': answerPlies,
        'max_answer_plies': maxAnswerPlies,
      };
}
