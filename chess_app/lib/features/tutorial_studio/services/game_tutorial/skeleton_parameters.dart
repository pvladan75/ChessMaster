class SkeletonParameters {
  const SkeletonParameters({
    this.minCost = 1.0,
    this.near = 0.3,
    this.maxCorrect = 3,
    this.maxMoments = 8,
    this.leadPlies = 3,
    this.answerPlies = 4,
  });

  final double minCost;
  final double near;
  final int maxCorrect;
  final int maxMoments;
  final int leadPlies;
  final int answerPlies;

  /// The same parameters at another threshold — what the trainer's slider
  /// changes, and the only field of these a trainer ever sets.
  SkeletonParameters withMinCost(double value) => SkeletonParameters(
        minCost: value,
        near: near,
        maxCorrect: maxCorrect,
        maxMoments: maxMoments,
        leadPlies: leadPlies,
        answerPlies: answerPlies,
      );

  Map<String, dynamic> toJson() => {
        'min_cost': minCost,
        'near': near,
        'max_correct': maxCorrect,
        'max_moments': maxMoments,
        'lead_plies': leadPlies,
        'answer_plies': answerPlies,
      };
}
