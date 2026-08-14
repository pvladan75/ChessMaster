/// Parses an engine eval string ("1.23", "-0.50", "M4", "-M4") into a
/// White-relative pawn-unit value. Mate scores collapse to a large but
/// finite magnitude (100 minus the mate distance) so they still compare
/// sensibly against ordinary evals without needing special-casing at every
/// call site.
///
/// Shared by [GameAnalysisWalkerService] (whole-game review) and the live
/// engine callback in Analysis Studio — both used to have their own copy of
/// this with different mate-magnitude constants (100 vs 10000), so the same
/// node's `eval` could jump by two orders of magnitude depending on which
/// path last wrote it.
double? parseWhiteRelativeEval(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final numeric = double.tryParse(raw);
  if (numeric != null) return numeric;

  final mateMatch = RegExp(r'(-)?M(\d+)').firstMatch(raw);
  if (mateMatch == null) return null;
  final distance = int.tryParse(mateMatch.group(2)!) ?? 1;
  final magnitude = 100.0 - distance;
  return mateMatch.group(1) != null ? -magnitude : magnitude;
}
