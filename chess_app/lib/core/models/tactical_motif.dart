enum TacticalMotif {
  pin,
  fork,
  discoveredAttack,
  skewer,
  deflection,
  overloading,
  hangingPiece,
  mateThreat,
  doubleAttack,
  mateThreatAndPieceAttack,
}

class MotifResult {
  final List<TacticalMotif> motifs;
  final String description;
  final List<String> affectedSquares;

  const MotifResult({
    required this.motifs,
    required this.description,
    required this.affectedSquares,
  });

  bool get hasMotif => motifs.isNotEmpty;

  factory MotifResult.empty() => const MotifResult(
        motifs: [],
        description: '',
        affectedSquares: [],
      );
}
