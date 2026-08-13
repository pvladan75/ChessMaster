enum PositionalFactor {
  doubledPawn,
  isolatedPawn,
  backwardPawn,
  passedPawn,
  pawnIslands,
  openFile,
  semiOpenFile,
  centerControl,
  knightOutpost,
  bishopPair,
  colorComplexWeakness,
  kingShield,
}

/// A single detected positional/strategic finding (e.g. "White has an
/// isolated pawn on d4") with the factor tag, a human-readable description,
/// the squares to highlight, and how it bears on the side that just moved.
class PositionalFinding {
  final List<PositionalFactor> factors;
  final String description;
  final List<String> affectedSquares;

  /// True when this finding favors the side that just moved (a strength of
  /// theirs, or a weakness of the opponent's); false otherwise. Same
  /// convention as [MotifFinding.favorsMover] in tactical_motif.dart, so the
  /// two can share UI (green/red chips, "Pažnja"/"Rešeno" phrasing).
  final bool favorsMover;

  /// Roughly "how structurally important is this" — used the same way as
  /// [MotifFinding.significance], to rank/filter findings in a summary.
  final int significance;

  const PositionalFinding({
    required this.factors,
    required this.description,
    required this.affectedSquares,
    required this.favorsMover,
    required this.significance,
  });

  String get diffKey {
    final sortedFactors = factors.map((f) => f.name).toList()..sort();
    final sortedSquares = List<String>.from(affectedSquares)..sort();
    return '$favorsMover::${sortedFactors.join(',')}::${sortedSquares.join(',')}';
  }
}

class PositionalResult {
  final List<PositionalFinding> findings;

  const PositionalResult({required this.findings});

  List<PositionalFactor> get factors => findings.expand((f) => f.factors).toSet().toList();

  String get description => findings.map((f) => f.description).where((d) => d.isNotEmpty).join(' | ');

  List<String> get affectedSquares => findings.expand((f) => f.affectedSquares).toSet().toList();

  bool get hasFinding => findings.isNotEmpty;

  factory PositionalResult.empty() => const PositionalResult(findings: []);
}

/// The positional findings a single move introduced or resolved, obtained by
/// diffing the position before and after the move — mirrors [MoveMotifDiff].
class PositionalMoveDiff {
  final List<PositionalFinding> created;
  final List<PositionalFinding> resolved;

  const PositionalMoveDiff({required this.created, required this.resolved});

  bool get hasChanges => created.isNotEmpty || resolved.isNotEmpty;
}
