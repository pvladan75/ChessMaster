/// The review's verdicts written into a tutorial's facts —
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1b.
///
/// Until 1b a tutorial kept a moment when the move cost `minCost` pawns, the
/// eight most expensive, which made „+19 against +14" a moment and a mistake
/// in an equal position under a pawn not one. Now what a mistake is has one
/// home, `mistake_rule.dart`, and one judge, `GameReviewJudge` — the same
/// walk, book, tablebase and deepening the whole-game review runs — so the
/// review's `??` and the tutorial's moments are the same moves (rule 12).
///
/// **The verdicts are facts.** The judge needs the engine; the skeleton must
/// stay a pure function of the facts, because the harness (`skeleton.py`)
/// reads the same facts and the fixtures hold the two to each other. So the
/// run judges the game once and writes what it found onto every played move,
/// and the skeleton reads only that.
library;

import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart'
    show kFactsMate;

/// The winning chances of a facts value (`value_for_mover`, centipawns, a mate
/// written as [kFactsMate] less its distance) for the side it is written for.
/// A mate is 100 or 0 whatever its distance, as [winningChances] says.
double chancesOfValue(int valueForMover) {
  if (valueForMover > kFactsMate ~/ 2) return 100;
  if (valueForMover < -(kFactsMate ~/ 2)) return 0;
  return winningChances(EngineValue.cp(valueForMover));
}

double _two(double x) => (x * 100).roundToDouble() / 100;

/// The only moves a player found in [result], by ply, with the gap in
/// chances to the second move — the extractor's own criteria (`B`, the book,
/// a decided position, nothing trivial), asked of it rather than copied.
Map<int, double> onlyMovesFound(GameReviewResult result) {
  final found = LocalPuzzleExtractorService()
      .buildPuzzlesFromReview(result, maxPuzzles: result.moves.length + 1)
      .onlyMoves;
  return {
    for (final p in found)
      p.sourcePlyIndex:
          p.secondChances == null ? 100.0 : p.bestChances - p.secondChances!,
  };
}

/// Writes [result]'s verdict onto the played move of every row it judged, as
/// `played['judged']`:
///
/// - `lost` — the chances the move lost, two decimals;
/// - `mistake` — a settled mistake (`ReviewedMove.isMistake`);
/// - `reason` — why, or null;
/// - `unsettled` — the looks still disagreed;
/// - `only`, and `gap` beside it — the only move that held, and the player
///   found it ([onlyMovesFound]);
///
/// or `{unjudged: why}` for a move the engine did not answer. Row `i`'s move is
/// the judge's ply `i`: both start from the same position.
void applyReviewVerdicts(
  List<Map<String, dynamic>> rows,
  GameReviewResult result, {
  Map<int, double>? onlyMoves,
}) {
  final only = onlyMoves ?? onlyMovesFound(result);
  for (final move in result.moves) {
    if (move.ply >= rows.length) break;
    final played = rows[move.ply]['played'] as Map<String, dynamic>?;
    if (played == null) continue;
    final judgement = move.judgement;
    if (judgement == null) {
      played['judged'] = {'unjudged': move.unjudgedWhy ?? 'no answer'};
      continue;
    }
    final gap = only[move.ply];
    played['judged'] = {
      'lost': _two(judgement.lostChances),
      'mistake': move.isMistake,
      'reason': judgement.reason?.name,
      'unsettled': move.unsettled,
      'only': gap != null,
      if (gap != null) 'gap': _two(gap),
    };
  }
}
