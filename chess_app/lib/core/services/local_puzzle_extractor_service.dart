import 'package:chess_app/core/services/game_review_judge.dart';

/// One blunder-derived exercise: the position right after the mistake (the
/// side to move there is the puzzle solver), tagged with why it's winnable.
class LocalPuzzle {
  final String id;
  final String fen;
  final String themeLabel;
  final String? themeKey;
  final double swing;
  final String sourceMoveSan;
  final int sourcePlyIndex;

  /// Position right before the blunder, and the blunder move itself in UCI
  /// (e.g. "e2e4") — kept so the puzzle-viewing UI can show the position
  /// before the mistake and then play/highlight the move that caused it,
  /// instead of dropping the solver straight into [fen]. Nullable so puzzles
  /// persisted before this field existed still deserialize.
  final String? fenBefore;
  final String? moveUci;

  /// The answer: the engine's best move in [fen], for the side that did not
  /// blunder — the next moment's own best move, since its position before is
  /// this one's position after (`docs/PLAN-MATERIJAL.md`, phase 4). Null for
  /// the game's last move, which has no next moment; the review then asks
  /// the engine once, and keeps no puzzle it cannot answer.
  final String? refutationSan;

  const LocalPuzzle({
    required this.id,
    required this.fen,
    required this.themeLabel,
    required this.themeKey,
    required this.swing,
    required this.sourceMoveSan,
    required this.sourcePlyIndex,
    this.fenBefore,
    this.moveUci,
    this.refutationSan,
  });

  LocalPuzzle withRefutation(String? san) => LocalPuzzle(
        id: id,
        fen: fen,
        themeLabel: themeLabel,
        themeKey: themeKey,
        swing: swing,
        sourceMoveSan: sourceMoveSan,
        sourcePlyIndex: sourcePlyIndex,
        fenBefore: fenBefore,
        moveUci: moveUci,
        refutationSan: san,
      );
}

/// Today's puzzles from a whole-game review — `docs/PLAN-MATERIJAL.md` phase 4,
/// and, since `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md` phase 1.2b, the review's own
/// judgement rather than a threshold this class picked.
///
/// The blunder walk this class used to run itself
/// (`extractPuzzles`/`buildPuzzlesFromMoments`, and the tactical labelling
/// that went with them) is gone: the review is `GameReviewJudge`'s now
/// (`game_review_runner.dart`), and [buildPuzzlesFromReview] only turns its
/// already-judged mistakes into puzzles. `GameMoment.isBlunderBeyond`, which
/// only those deleted methods read, went with them.
class LocalPuzzleExtractorService {
  /// Today's puzzles from a review's mistakes ([ReviewedMove.isMistake]),
  /// worst first by chances lost, at most [maxPuzzles]: the position after the
  /// mistake, its answer the [ReviewedMove.replyLine]'s first move (null when
  /// the review has none). Phase 1.3 rewrites what a puzzle is; this keeps
  /// today's shape on the review's rule.
  List<LocalPuzzle> buildPuzzlesFromReview(
    GameReviewResult result, {
    required int maxPuzzles,
  }) {
    final mistakes = result.moves.where((m) => m.isMistake).toList()
      ..sort((a, b) =>
          b.judgement!.lostChances.compareTo(a.judgement!.lostChances));

    return mistakes.take(maxPuzzles).map((m) {
      final reply = m.replyLine;
      final answer = reply != null && reply.bestMoveSan.isNotEmpty
          ? reply.bestMoveSan
          : null;
      return LocalPuzzle(
        id: 'local_${m.ply}_${DateTime.now().microsecondsSinceEpoch}',
        fen: m.fenAfter,
        themeLabel: 'A mistake was made here — find the best move',
        themeKey: null,
        swing: -(m.judgement!.lostChances),
        sourceMoveSan: m.san,
        sourcePlyIndex: m.ply,
        fenBefore: m.fenBefore,
        moveUci: m.uci,
        refutationSan: answer,
      );
    }).toList();
  }
}
