// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b.
//
// Every case this file held tested `LocalPuzzleExtractorService.extractPuzzles`
// / `.buildPuzzlesFromMoments` — the service's own blunder walk, over a pawn
// `blunderThreshold`, labelling a puzzle through `TacticalMotifDetector`. Both
// methods are gone: the review is `GameReviewJudge`'s now
// (`lib/features/analysis_studio/services/game_review_runner.dart`), which
// judges by winning chances (`mistake_rule.dart`), not a pawn threshold this
// class picked, and `buildPuzzlesFromReview` only turns its already-judged
// mistakes into puzzles — with a plain "a mistake was made here" label, not a
// tactical-motif one; that labelling went with the deleted walk.
//
// Where each rule lives now:
// - "worst blunder first" and "capped at maxPuzzles" —
//   `test/core/game_review_judge_test.dart`, "today's puzzles from the
//   mistakes, worst first".
// - "the answer is the best move of the next moment" — the review always
//   asks about every position, including the last one's, so
//   `ReviewedMove.replyLine` already carries the reply; the same test above
//   asserts `puzzles.first.refutationSan`.
// - "does not extract a puzzle when the swing stays under the threshold" —
//   `mistake_rule.dart`'s `judgeMove`/`isMistake`, tested in
//   `test/mistake_rule_test.dart`.
// - The hanging-queen puzzle's tactical label (`themeKey: 'hangingPiece'`) has
//   no successor: `buildPuzzlesFromReview` never asks `TacticalMotifDetector`.

void main() {}
