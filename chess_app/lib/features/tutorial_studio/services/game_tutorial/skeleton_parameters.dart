class SkeletonParameters {
  const SkeletonParameters({
    this.minCost = 1.0,
    this.near = 0.3,
    this.maxCorrect = 3,
    this.maxMoments = 8,
    this.leadPlies = 3,
    this.answerPlies = 4,
    this.maxAnswerPlies = 8,
  });

  final double minCost;
  final double near;
  final int maxCorrect;
  final int maxMoments;
  final int leadPlies;
  final int answerPlies;

  /// The most the answer line is ever extended to, when it would otherwise end
  /// mid-sacrifice. A bound rather than „the whole line": the stored line is
  /// six plies today, and this must not become „show the whole engine PV" the
  /// day that changes.
  final int maxAnswerPlies;

  /// The same parameters at another threshold — what the trainer's slider
  /// changes, and the only field of these a trainer ever sets.
  SkeletonParameters withMinCost(double value) => SkeletonParameters(
        minCost: value,
        near: near,
        maxCorrect: maxCorrect,
        maxMoments: maxMoments,
        leadPlies: leadPlies,
        answerPlies: answerPlies,
        maxAnswerPlies: maxAnswerPlies,
      );

  Map<String, dynamic> toJson() => {
        'min_cost': minCost,
        'near': near,
        'max_correct': maxCorrect,
        'max_moments': maxMoments,
        'lead_plies': leadPlies,
        'answer_plies': answerPlies,
        'max_answer_plies': maxAnswerPlies,
      };
}
