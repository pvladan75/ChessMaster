import 'package:chess/chess.dart' as chess;
import 'package:chess_app/models/analysis_models.dart';

/// One played move, annotated with engine eval (before/after, from the
/// perspective of whoever played it) and tactical/positional commentary.
/// Produced by `GameAnalysisWalkerService.analyzeGame`.
class GameMoment {
  final int plyIndex;
  final String moveSan;
  final String moveUci;
  final String fenBefore;
  final String fenAfter;
  final chess.Color moverColor;

  /// The engine's own top line for [fenBefore] — i.e. what it would have
  /// played instead of [moveSan]. Free byproduct of the eval walk (the
  /// engine is already queried at every position anyway), kept around so a
  /// blunder can be paired with a short "better move" line without a second
  /// engine pass. Null when the engine returned no line for this position.
  final AnalysisLine? engineLineBefore;

  /// Raw engine eval strings (White-relative, e.g. "1.23" or "-M4") for the
  /// positions before and after this move — kept around for display/PGN
  /// export, since `AnalysisNode.eval` is stored White-relative too.
  final String? evalBeforeRaw;
  final String? evalAfterRaw;

  /// Eval before/after in pawn units, from the *mover's* perspective
  /// (mate scores collapse to a large finite magnitude). Null when the
  /// engine didn't return a usable eval for that position.
  final double? evalBeforeForMover;
  final double? evalAfterForMover;

  /// evalAfterForMover - evalBeforeForMover. Negative means the position
  /// got worse for the side that just moved — i.e. they blundered.
  final double? swingForMover;

  final String tacticalComment;
  final String positionalComment;

  const GameMoment({
    required this.plyIndex,
    required this.moveSan,
    required this.moveUci,
    required this.fenBefore,
    required this.fenAfter,
    required this.moverColor,
    this.engineLineBefore,
    required this.evalBeforeRaw,
    required this.evalAfterRaw,
    required this.evalBeforeForMover,
    required this.evalAfterForMover,
    required this.swingForMover,
    required this.tacticalComment,
    required this.positionalComment,
  });

  String get combinedComment => [tacticalComment, positionalComment]
      .where((s) => s.isNotEmpty)
      .join(' | ');

  /// True when this move gave up at least [threshold] pawns of value from
  /// the mover's own perspective — a blunder the opponent can now exploit.
  bool isBlunderBeyond(double threshold) =>
      swingForMover != null && swingForMover! <= -threshold;
}
