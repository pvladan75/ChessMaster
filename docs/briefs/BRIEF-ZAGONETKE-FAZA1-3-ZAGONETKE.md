# Brief — puzzle plan, phase 1.3: the puzzles

`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md` — read §1 (the request), §3 whole
(criteria 0–4, „A missed mate", „One number for decided", „The only moves a
player found", „Nothing trivial is taught as a find", „A chance missed several
times is one puzzle", „With seven men or fewer"), §4 (what a puzzle holds), and
under phase 1 the bullets 1.2a and 1.2b with their „Built" notes. 1.2a built
the judgement (`GameReviewJudge`, `lib/core/services/game_review_judge.dart`),
1.2b the run (`GameReviewRunner`) and the dialog on it. Today's puzzle is still
1.2b's stopgap: every mistake, the position **after** it, one answer
(`LocalPuzzleExtractorService.buildPuzzlesFromReview`). This phase makes a
puzzle what §3 and §4 say it is.

Work in a worktree. Baseline on `master` at `e22e8c4`, measured 24.9.2026 in a
worktree: **4055 passed, 1 skipped**; `flutter analyze` the **23** known infos
(all `curly_braces_in_flow_control_structures`, listed in `CLAUDE.md`). No
server change in this phase — the backend is not touched.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately: a new rule invented to make a broken fixture
pass is not accepted.

## The gate

Four files in `docs/gates/`, copied into `chess_app/test/` as named, and not
edited except to report a fault in them:

| gate file | goes to | holds |
|---|---|---|
| `review_puzzles_test.dart` | `test/core/review_puzzles_test.dart` | the builder: pure, results built by hand |
| `review_puzzle_search_test.dart` | `test/core/review_puzzle_search_test.dart` | the judge's puzzle searches, asserted on the questions asked |
| `keep_review_puzzles_test.dart` | `test/keep_review_puzzles_test.dart` | the keep panel and what it sends |
| `review_dialog_puzzles_test.dart` | `test/review_dialog_puzzles_test.dart` | the dialog's side choice and „no puzzle" |

The dialog file was run on `master` by the lead: its two new rules are red
there for the right reason (no „White" with puzzles alone; no
`review-no-puzzles`), the other two green. The other three do not compile on
`master` — they name the API below.

## What is built

### 1. The rule's two new pieces — `lib/core/services/mistake_rule.dart`

- `const double kStandsOut = 15;` — `B`, the owner's choice of 24.9.2026. One
  move stands out when `W(best) − W(second) ≥ kStandsOut`.
- `bool isTrivialFind(String fenBefore, String answerUci, {String? previousUci})`
  — true when the side to move in `fenBefore` is **in check**, or has **three
  legal moves or fewer**, or `answerUci` is a **capture landing on the square
  `previousUci` landed on**. Exactly phase 0's definition
  (`outside.mjs`: `isRecap || inCheck || legal <= 3`). One function, read by
  the judge (to skip a search) and the builder (to rank and to refuse) —
  rule 12.

### 2. The answer line's one home — `lib/core/services/answer_line.dart` (new)

Plan §4: the lines are cut by the tutorial's `answerPlyCount`, **lifted to one
shared home, not copied**.

- `int answerLineLength(String fen, String mover, List<String> line,
  {required int shortest, required int longest})` — the body of today's
  `answerPlyCount` (`skeleton_moments.dart:176`), moved: start at `shortest`,
  run on while `mover` ('White' / 'Black') is behind where they started,
  never past `longest` or the line. It throws `StateError` on a move that does
  not play, as today. `materialOf` stays where it is (`board_queries.dart`)
  and is imported.
- `answerPlyCount(fen, mover, line, SkeletonParameters p)` in
  `skeleton_moments.dart` becomes a one-line delegate
  (`shortest: p.answerPlies, longest: p.maxAnswerPlies`). The tutorial's
  numbers (4 and 8) do **not** change in this phase — phase 1b raises them with
  its regenerated fixtures. `test/game_tutorial_answer_line_test.dart` must
  stay green untouched: it is the proof that the lift changed nothing.
- `const int kRevealPlies = 12;` and `List<String> revealLine(String fen,
  List<String> line)` — the line cut for the reveal: `shortest` 4, `longest`
  `kRevealPlies`, the mover the side to move in `fen`. Throws `StateError`
  when a move does not play.

### 3. The judge learns what puzzles need — `game_review_judge.dart`

`review(...)` takes `BlunderAlertSide? puzzles` (from
`game_analysis_walker_service.dart`; a cyclic import is fine in Dart). Null —
the default — means no puzzle searches at all and a review exactly as today.

`ReviewStage` gains `answers` (last). `ReviewedMove` gains:

- `String? walkBestUci` — the walk's best move in the position before (its
  line 1's first move), whatever a later look said. Null when the walk did not
  answer there.
- `AnalysisLine? thirdLine` — a third line, when a search below asked for one.
- `List<String>? tablebaseKeepers` — for a move judged by the tablebase: the
  UCI of every move whose result, read for the mover, **equals the position's**
  (`_outcomeOf`, `_invert`, in the tablebase's own order). Null otherwise.

After the deepening and before the assembly, when `puzzles` is set, **the
puzzle stage** — for each move of the side chosen that is judged, not
unsettled and not judged by the tablebase:

- **A mistake whose deciding lines both mate** for the side to move (line 1
  and line 2 of the look it stands on): one search of **three** lines at
  **the depth of that look's line 1**. When it answers, its lines 1–3 become the
  move's `bestLine`, `secondLine`, `thirdLine`. (§3, „A missed mate": `B`
  against the best move that does not mate needs the line after the mates.)
- **A move the player found**: not a mistake, the played move **is**
  `walkBestUci`, the played move is not theory (`bookGames < kTheoryGames`),
  the position is not decided (`isDecided` on the walk's `W(best)`), and not
  `isTrivialFind(fenBefore, uci, previousUci: <the move before, when the
  review has it>)` → one search of **two** lines at the review's depth. When it
  answers, its lines become `bestLine` and `secondLine`. No third line and no
  deepening here: in a decided position there is no only move, so an only
  move is never a mate.

Both go through `_ask` (the store, `searchProblem` on line 1), report
`ReviewProgress(ReviewStage.answers, done, total)`, and stop on `cancel()` as
every other stage does. A search that does not answer leaves the move as it
was. The dialog's stage label for `answers` is „Looking for puzzles".

### 4. The puzzle — `local_puzzle_extractor_service.dart`, rewritten

```dart
enum PuzzleKind { mistake, onlyMove }

const kMistakeInstruction =
    'A mistake was made in this position. Find the best move.';
const kOnlyMoveInstruction =
    'The player found the only good move here. Find it.';

class LocalPuzzle {
  const LocalPuzzle({
    required this.id, required this.kind,
    required this.fen,              // the position BEFORE the game's move
    required this.sourcePlyIndex,
    required this.playedSan, required this.playedUci,
    required this.answers,          // SAN; every right answer, the best first
    this.bestLine = const [], this.refutationLine = const [],
    this.secondLine = const [],     // SAN lists, already cut by revealLine
    required this.bestChances, required this.playedChances,
    this.secondChances,             // null when there is no second line
    this.trivial = false, this.missedTimes = 1,
  });
  String get instruction;           // by kind, the two constants above
  double get lostChances;           // max(0, bestChances − playedChances)
}

class ReviewPuzzles {
  const ReviewPuzzles({this.mistakes = const [], this.onlyMoves = const [],
      this.unplayable = 0});
  List<LocalPuzzle> get all;        // mistakes, then only moves
}

ReviewPuzzles buildPuzzlesFromReview(GameReviewResult result,
    {required int maxPuzzles, BlunderAlertSide side = BlunderAlertSide.both});
```

`fenBefore`, `moveUci`, `refutationSan`, `withRefutation`, `themeLabel`,
`themeKey`, `swing` and `sourceMoveSan` go; `grep` shows their only readers are
the keep panel, the runner and the tests named below.

Chances are the mover's, from the lines' evaluations
(`EngineValue.fromEvaluation(line.evaluation, whiteToMove: move.whiteMoved)`,
`winningChances`); `playedChances` is `bestChances − judgement.lostChances`.
„The move before" is the element before in `result.moves`; the first has none.

**A mistake puzzle**, from a move that `isMistake` and is of the side chosen:

- *judged by the tablebase*: `tablebaseKeepers` holds exactly one move, and
  the engine's `bestLine` starts with it → `answers` is that move's SAN; no
  second line (`secondChances` null); `B` is „no other move keeps the result"
  (§3). Two keepers or more: no puzzle. The mate rule below does not apply.
- *judged by the engine*: with a `secondLine`, else no puzzle (a search that
  gave one line is never read as „only move"). When `bestLine` mates for the
  mover, `answers` are the SANs of the leading lines that mate (1, then 2, then
  3 while they mate), the second is the first line that does not mate, and
  none → no puzzle. Otherwise `answers` = [best], the second is `secondLine`.
  `W(best) − W(second) ≥ kStandsOut`, and **steady**: `walkBestUci` is the
  best line's first move — or, for a mate, one of the mating first moves.
  The played move is never among the answers.

**An only-move puzzle**, from a move that is judged, **not** a mistake, not
unsettled, of the side chosen, not theory, not `isTrivialFind`, and not
decided (`isDecided` on `bestChances`):

- *by the tablebase*: `tablebaseKeepers` is exactly `[uci]` and `bestLine`
  starts with it;
- *by the engine*: `bestLine` starts with the played move, `walkBestUci` is
  the played move, a `secondLine` exists, and the gap is at least
  `kStandsOut`.

`answers` = [the played move's SAN]; no refutation line.

**The lines.** `bestLine` and `secondLine` cut by `revealLine` from `fen`;
`refutationLine` from the review's `replyLine`, cut by `revealLine` from
`fenAfter` — so the side that punishes is the mover. **Every answer is played
and every line replayed** before a puzzle is made (the writer reads its own
work back, §4): one that does not play makes no puzzle and adds one to
`unplayable`, logged through `AppLogger`. It never joins a group below.

**`trivial`** = `isTrivialFind(fen, <the first answer's UCI>, previousUci: …)`.

**One chance, one puzzle.** The mistake puzzles of one side, by ply: each
within **4 plies** of the previous one in its chain is the same chance — the
chain becomes its **first** puzzle, with `missedTimes` = the chain's length.
Grouped after the criteria (a mistake that is no puzzle joins nothing) and
before the ranking.

**Ranking and the cap.** Mistakes: the non-trivial first, then by
`lostChances`, largest first, then by ply; at most `maxPuzzles`. Only moves:
by `W(best) − W(second)`, largest first (a tablebase only move, which has no
second, after the rest), then by ply; at most `maxPuzzles`, **on their own**.

### 5. The run — `game_review_runner.dart`

`judge.review(..., puzzles: options.findPuzzles ? options.side : null)`;
`run.puzzles` stays a `List<LocalPuzzle>` — the builder's `all` — and the run
gains `int puzzlesUnplayable`. Nothing else in the runner changes.

### 6. The dialog — `game_review_dialog.dart`

- The Both / White / Black `SegmentedButton` is shown when Blunder Alert **or**
  the puzzles are on — moved out of the Blunder Alert block, the same widget
  and the same `_blunderSide`. The labels do not change: `site/` quotes them
  (`manual_labels_test`).
- The `answers` stage reads „Looking for puzzles".
- When puzzles were asked for and none was found, the end says so:
  `Text('No puzzle found in this game.', key: Key('review-no-puzzles'))` beside
  the other lines of the end. When `puzzlesUnplayable > 0`, one more caption:
  „N puzzle(s) left out: a line did not replay."

### 7. The keep panel — `keep_puzzles_panel.dart`

- **Mistakes first, ticked; then a heading** `Text('Only moves the player
  found', key: Key('keep-only-moves'))` shown only when there is one, **and the
  only moves under it, not ticked.** Row keys stay `keep-puzzle-$i` and
  `keep-puzzle-tick-$i`, `$i` the index in `widget.puzzles` as handed in —
  whatever order the panel draws them in.
- A row: the board of `fen` (the position before), `puzzleMoveLabel(p)` read
  off `fen` („3. Bc4", „3...Nf6"), then for a mistake „lost N" (chances,
  rounded) and „missed N times" when `missedTimes > 1`, for an only move „the
  only good move"; below it „Answer: " and the answers joined by „ or ".
- `puzzleExerciseDraft(p, name:)`: `fen` = `p.fen`, `instruction` =
  `p.instruction`, `task` `{'type': 'find'}`, `solution` =
  `[ExerciseStep(accept: p.answers)]`, `origin` `'mistakes'`, the source as
  today. **Every answer is played on `p.fen` first**; one that does not play
  → null, and the panel says so as it does today („… does not play there, so it
  was not kept."). No `themes`.

### 8. Tests that held the old shape — rewritten openly, not deleted

- `test/core/game_review_judge_test.dart`, „today's puzzles from the mistakes,
  worst first": rewrite on the new builder or delete it with a comment naming
  where each assertion now lives (the gate's „worst first" and „the position
  before" cases).
- `test/game_review_exercises_test.dart`: its `LocalPuzzle` fixtures move to
  the new constructor. Where a case asserted the position *after* or the old
  instruction („White just played …"), say above it, in a comment, which
  decision of 1.3 superseded it, and assert the new rule.
  Its dialog cases (from line 258) use a fake engine that answers **one line
  whatever is asked**; under 1.3 a mistake with no second line is no puzzle,
  so give the fake a second line clearly below the first rather than change
  what the case asserts about keeping.
- `test/review_runner_test.dart`, „without Blunder Alert nothing is marked;
  puzzles only when asked": its engine's second line has **the same value as
  the first**, so under `B` it finds no puzzle and goes red — the expected red.
  Put the second line 20 chances below the first (for the side to move) and
  keep all its assertions; what it holds is „only when asked", „worst first"
  and the cap, not the old shape. Say so in a comment above it.
- `test/core/local_puzzle_extractor_service_test.dart` is a tombstone comment;
  add one line pointing at `review_puzzles_test.dart`.

## Decided by the lead in this brief (the owner may move any of them)

- **The clock waits for phase 3.** „The clock among the facts" is listed in
  1.3, but its only reader is the words of phase 3, and the review's tree does
  not hold it: `MoveTree.parsePgn` strips `[%clk]` from every comment
  (`cleanPgnComment`) before a node is made. Reading it means a field on the
  node, its JSON, and the parser — built with the reader that needs it, not
  before (a field written and read by nobody is what `parent_allows_recording`
  was). Not built here.
- **The only-move search** costs one two-line search per move the player
  found in a live position, for the side chosen, only when puzzles are asked
  for — some 10–20 a game; on the desktop about a second each at depth 20,
  on the phone about five.
- **`origin` stays `'mistakes'`** for both kinds — no server change. Phase 6
  tells old puzzles from new by their instruction (the old ones say „… just
  played …"), not by the origin.
- **Only moves are capped by *Max puzzles* on their own**, the clearest first.

## Method

- Build in the order of the sections; run each gate file as its piece lands.
- `dart format` every Dart file you touch.
- At the end, in the worktree with nothing else running: the full
  `flutter test` and `flutter analyze`. Predict the count before the run: 4055
  plus the gate's cases, minus any case you deleted, plus any you added — and
  say which.

## Report

1. **What the brief got wrong** — first, before anything else.
2. The worktree's HEAD and branch.
3. The full-run summary line and the analyze summary line, with the predicted
   count beside the measured one.
4. Every test file you changed outside the gate, and for each changed case
   one line: kept / rewritten (what superseded it) / deleted (where its rule
   lives now).
5. Anything you could not make green, with the output.
