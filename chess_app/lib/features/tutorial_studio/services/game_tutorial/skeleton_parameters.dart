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

  Map<String, dynamic> toJson() => {
        'min_cost': minCost,
        'near': near,
        'max_correct': maxCorrect,
        'max_moments': maxMoments,
        'lead_plies': leadPlies,
        'answer_plies': answerPlies,
      };
}
