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

/// A single detected tactical finding (e.g. "this fork", "this pin") with the
/// motif tag(s) it corresponds to, a human-readable description, and the
/// squares to highlight on the board.
class MotifFinding {
  final List<TacticalMotif> motifs;
  final String description;
  final List<String> affectedSquares;

  /// True when this finding is a threat/advantage for the side that just
  /// moved (good for the move); false when it's a threat/advantage for the
  /// opponent instead (bad for the move — e.g. the move left a piece
  /// hanging, or walked into a fork).
  final bool favorsMover;

  /// Roughly "how much material is at stake" (in pawn units, king=1000) —
  /// the value of the most valuable piece involved. Lets callers rank or
  /// filter findings so a hanging pawn doesn't crowd out a hanging queen or
  /// a mate threat in a short summary.
  final int significance;

  const MotifFinding({
    required this.motifs,
    required this.description,
    required this.affectedSquares,
    required this.favorsMover,
    required this.significance,
  });

  /// Order-independent identity used to compare findings across positions
  /// (e.g. "is this the same finding before and after a move?").
  String get diffKey {
    final sortedMotifs = motifs.map((m) => m.name).toList()..sort();
    final sortedSquares = List<String>.from(affectedSquares)..sort();
    return '$favorsMover::${sortedMotifs.join(',')}::${sortedSquares.join(',')}';
  }
}

class MotifResult {
  final List<MotifFinding> findings;

  const MotifResult({required this.findings});

  List<TacticalMotif> get motifs => findings.expand((f) => f.motifs).toSet().toList();

  String get description => findings.map((f) => f.description).where((d) => d.isNotEmpty).join(' | ');

  List<String> get affectedSquares => findings.expand((f) => f.affectedSquares).toSet().toList();

  bool get hasMotif => findings.isNotEmpty;

  factory MotifResult.empty() => const MotifResult(findings: []);
}

/// The tactical findings a single move introduced or resolved, obtained by
/// diffing the position before and after the move. Meant to drive
/// human-facing explanations of why a move is good or bad.
class MoveMotifDiff {
  final List<MotifFinding> created;
  final List<MotifFinding> resolved;

  const MoveMotifDiff({required this.created, required this.resolved});

  bool get hasChanges => created.isNotEmpty || resolved.isNotEmpty;
}
