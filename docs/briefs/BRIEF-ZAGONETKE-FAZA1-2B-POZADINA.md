# Brief — puzzle plan, phase 1.2b: the review in the background

`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1, the bullet „1.2 — the review's
judgement" and its sub-bullets (read them whole: *the dialog is not the
review's home*, *the result lands on the game*, *the phone has one engine*,
*a run that is stopped resumes*, *the budget is work*), and the 1.2a „Built"
note under it. 1.2a built the judgement (`GameReviewJudge`,
`lib/core/services/game_review_judge.dart`) with no screen in it. The dialog
(`lib/features/analysis_studio/widgets/game_review_dialog.dart`) still runs
the **old** path. This phase moves the dialog onto the judge, takes the run
out of the dialog, and deletes the old path.

Work in a worktree. Baseline on `master` at `154c7be`: **4030 passed, 1
skipped**, `flutter analyze` the 26 known infos (all
`curly_braces_in_flow_control_structures`, listed in `CLAUDE.md`).

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately: a new rule invented to make a broken fixture
pass is not accepted (1.2a lost a puzzle's answer that way).

## What is built

### 1. `GameReviewRunner` — the review's home

New file `lib/features/analysis_studio/services/game_review_runner.dart`. The
gate fixes its surface; everything the gate names must exist with that shape.

- `ReviewOptions` — `const ReviewOptions({required int depth, bool
  markMistakes = false, BlunderAlertSide side = BlunderAlertSide.both, bool
  insertBetterLine = true, bool findPuzzles = false, int maxPuzzles = 5})`.
- `ReviewedGame` — the game a run was started on, **by its moves**: the root's
  FEN, the UCI path from the root to the start node, and the UCI main line
  (first children) from the start node. `chainIn(AnalysisNode root)` answers
  the nodes of those moves in *that* tree — matching every step by
  `moveUci`, not by child index — or null when the tree does not hold them all
  (a different root FEN, a move missing).
- `abstract interface class ReviewBoard { AnalysisNode get reviewRoot; void
  reviewLanded(); }` — a live screen that can take a result.
- `enum ReviewRunStatus { running, done, cancelled, failed }`,
  `enum ReviewLanding { onBoard, inDraft, notLanded }`.
- `GameReviewRun` (a `ChangeNotifier`): `game`, `options`, `gameTitle`,
  `status`, `progress` (the judge's last `ReviewProgress`), `result`
  (`GameReviewResult?`), `tally` (`EngineAnswerTally`), `marked` (int),
  `puzzles` (`List<LocalPuzzle>`), `landing` (`ReviewLanding?` — null when
  nothing was asked to land, i.e. Blunder Alert off), `failure` (String?),
  and `Future<void> get finished`, which completes however the run ends.
- `GameReviewRunner` (a `ChangeNotifier`):
  `GameReviewRunner({BookLookup? book, TablebaseLookup? tablebase})` and
  `static final instance`. Defaults: the book as
  `game_tutorial_run.dart:224` asks it (`walkMastersBook` with the session's
  token and `ecoOpeningNames`), the tablebase
  `SyzygyTablebaseService.instance.lookup`.
  - `GameReviewRun start({required AnalysisNode root, required AnalysisNode
    start, required ReviewOptions options, required StockfishService engine,
    String? gameTitle})` — throws `StateError` while a run is under way.
    Returns at once; the run goes on without any widget.
  - `current` (the run under way, or the last one until `dismiss()`),
    `isRunning`, `cancel()`, `dismiss()`.
  - `attachBoard(ReviewBoard)` / `detachBoard(ReviewBoard)`.
  - `watch()` / `unwatch()` / `bool get watched` — a dialog open on the
    runner watches it; the end is said as a message only when nobody watches.

**The run.** The analyzer is `EvalCache.instance.wrapMoves(engine
.analyzePositionSync, engine: engine.answerStoreName, tally: run.tally)`, the
judge `GameReviewJudge(analyzer:, book:, tablebase:)`, asked with the start
node's FEN, the main line's UCI moves and `options.depth`. Then, when the judge
answers: puzzles when `findPuzzles`
(`LocalPuzzleExtractorService().buildPuzzlesFromReview(result, maxPuzzles:)`),
and the marks when `markMistakes` — `GameAnalysisWalkerService().markMistakes`
on the chain it lands on, with `side` and `insertBetterLine`.

**The engine is held for the whole run**: `engine.hold(run)` before the first
question, `engine.release(run)` after the last, in a `finally` — whether the
run ends done, cancelled or failed. Exactly one of each (the gate counts).

**Where it lands** (only when `markMistakes`), in this order:
1. **A live board**: the most recently attached `ReviewBoard` whose
   `reviewRoot` holds the game (`chainIn`). Mark it, call `reviewLanded()`
   once → `onBoard`.
2. **No board attached at all**: the one-slot draft
   (`AnalysisDraftService.instance.load()`), if it holds the game. Mark its
   tree and write it back with `flush(...)` — keeping its current node and its
   orientation, and with **the run's epoch** → `inDraft`.
3. Otherwise → `notLanded`. **A live board owns the draft**: while any board
   is attached, the draft is never written, because the board's own debounced
   save would overwrite it and the marks would be lost *and called landed*.

**The account.** The run takes `AccountLocalState.epoch` when it starts. On
every progress callback from the judge it checks `isCurrent(epoch)`; when a
sign-out has raised it, it cancels the judge. A run that is not current lands
nothing and ends `cancelled`. The draft write carries the run's epoch, so the
fence holds at the last step too — the lesson of 1.1: *a fence against „after"
stands at the last step, not the first.*

**Cancel** sets the judge's flag; the search in flight finishes (at most its
own timeout) and the run ends `cancelled`, with nothing marked. Do **not**
stop the engine's search from the runner (the gate's fakes do not implement
`stopAnalysis`, deliberately). A cancelled run resumes from the store when
started again — nothing more is needed for that (plan: *a run that is stopped
resumes*).

### 2. The engine hold — `StockfishService`

In `stockfish_service_native.dart` **and** `stockfish_service_stub.dart`:
`void hold(Object owner)`, `void release(Object owner)`,
`ValueListenable<bool> get held`, `ValueListenable<int> get
refusedWhileHeld`, and `@visibleForTesting int get debugRequestId` /
`debugMultiPV` (`_requestId`, `_currentMultiPV`). While held:

- `stopAnalysis()` does nothing to the engine — no `_requestId++`, no `stop`.
  `detach` goes through it, so leaving Analysis no longer cuts the search.
- `setMultiPV(n)` from a screen is remembered and applied on `release`. The
  review's own searches must still set MultiPV: `_analyzePositionSyncNow`
  moves to a private setter that the hold does not stop.
- `analyzePosition(...)` (the live, debounced search) is refused before any
  timer: it returns, and `refusedWhileHeld` goes up by one.
- `_activateTopSubscriber()` does nothing: the callback fields belong to the
  review's search while it runs (`analyzePositionSync` hijacks
  `onMultiPVUpdated` / `onEvaluationChanged`), and a screen attaching or
  detaching must not swap its own in under it.
- `release(owner)` from anyone but the holder does nothing. On a real
  release: apply the remembered MultiPV, then `_activateTopSubscriber()` so
  the screen on top gets the engine back and asks again.

The sync searches themselves (`analyzePositionSync`, one at a time since
1.2a) are **not** held back: the exercise checker, the scanner's side
proposal and the repertoire's engine queue behind the review's searches, as
they already do.

### 3. `ReviewNotice` — the end said wherever the reader is

New file `lib/widgets/review_notice.dart`,
`ReviewNotice({required Widget child, GameReviewRunner? runner})` (default
`GameReviewRunner.instance`), placed in `main.dart`'s builder beside
`EngineNotice` — read that widget first; it is the model, including why it
sits above the router. It says, through `AppFeedback` and never by throwing:

- when a run ends **done or failed** and `!runner.watched`: a message that
  begins **„Game review done"** — what was marked, or „no mistake found at
  depth D" for a clean game, the puzzles waiting („open Review game in
  Analysis to keep them"), and, as a warning, a result that did not land
  („The game changed while it was reviewed — the marks were not written.").
  A failed run says it stopped and why. A **cancelled** run says nothing.
- when `StockfishService().refusedWhileHeld` goes up: once per hold, a
  message containing **„busy with the game review"**. Six screens use the
  engine (`chess_game_screen`, `ai_studio_screen` …); a live search refused
  in silence is the codebase's recurring bug, so it is said here, once, for
  all of them.

### 4. The dialog

`GameReviewDialog` loses `onCompleted` and gains `GameReviewRunner? runner`
(default `instance`). It `watch()`es the runner in `initState` and
`unwatch()`es in `dispose`. It owns no walk and no state of the run: it draws
what `runner.current` says.

- **Setup**: as today, **without** the „Blunder threshold: N pawns" slider
  (the plan: its only readers were this dialog and the extractor). Say in the
  text that the review may take long and goes on if the window is closed. The
  existing labels stay („Start analysis", „Blunder Alert — tag mistakes and
  suggest a better move", „Extract puzzles from detected blunders", the side
  choice, the better line, Max puzzles, the depth slider, „Analyze only from
  the current position forward").
- **A run under way on another game**: setup is drawn, Start is off, and a
  line keyed `review-other-game` says a review of another game is under way,
  with its progress and a way to cancel it.
- **Running** (key `review-running`), for a run on *this* game — also when
  the dialog is reopened during it: the stage in words and a progress bar
  (walk „N / M positions", the book, the tablebase „N / M", looking again „N /
  M", looking deeper „N / 24 searches" — the stage is `ReviewProgress.stage`),
  a button keyed `review-keep-working` that closes the dialog and leaves the
  run going, and one keyed `review-cancel` that cancels and closes. The
  `PopScope` that blocked closing goes: closing no longer loses anything.
- **Done** (key `review-done`), for a finished run on this game — also when
  reopened after the end, until closed with the button keyed `review-close`,
  which calls `runner.dismiss()`:
  - „Done — reviewed N positions." (N = moves + 1, as today);
  - keyed `review-depth`: the depth the review stands on
    (`result.depth`), in a sentence containing „depth D";
  - when Blunder Alert was on, „Marked N mistake." / „Marked N mistakes."
    (`run.marked`; the gate reads „Marked 2 mistakes." and „Marked 0
    mistakes.");
  - keyed `review-clean`, only when the game is clean
    (`result.cleanWhere`, restricted to the side chosen when Blunder Alert
    is on): „No mistake found at depth D." — never when anything is marked,
    unsettled or unjudged;
  - keyed `review-unsettled` / `review-unjudged`, only when non-zero, with the
    count — what they mean in one plain clause each (the looks still
    disagreed; the engine did not answer);
  - keyed `review-from-store`, only when `tally.fromStore > 0`: how many
    answers came from earlier searches;
  - the book not asked (`bookUnavailable`), the tablebase not answering
    (`tablebaseUnanswered`), a result that did not land — each only when it
    happened;
  - the puzzles in `KeepPuzzlesPanel`, as today, or Close.
- **Remove the dialog's own last-move search.** `ReviewedMove.replyLine`
  already carries the answer (the walk searched the last position); a
  mistake whose reply is mate on the board has no answer and is listed as
  such, which `KeepPuzzlesPanel` already does.

### 5. Analysis

`AnalysisStudioScreen` gains `GameReviewRunner? reviewRunner` (default
`instance`). Its `State` implements `ReviewBoard` (`reviewRoot` →
`_rootNode`; `reviewLanded` → `setState` and `_saveDraft()`), attaches in
`initState`, detaches in `dispose`. `_showGameReviewDialog` passes the runner
and drops `onCompleted`. While `StockfishService().held` is true **and** the
engine switch is on, the engine panel says so in a widget keyed
`analysis-engine-busy` (in `StockfishAnalysisWidget` or beside it — your
choice; the gate finds it with `skipOffstage: false`), instead of an empty
panel. Nothing when the switch is off.

### 6. The old path, deleted

`GameAnalysisWalkerService.annotateNodeChain` and `.tagBlunders`;
`LocalPuzzleExtractorService.extractPuzzles`, `.buildPuzzlesFromMoments`,
`_nextOf`, `_buildPuzzle`, its `_walker`/`cancel` and whatever then has no
reader; `GameMoment.isBlunderBeyond` if nothing in `lib/` reads it any more.
`analyzeGame` **stays** — `game_facts.dart` (the tutorial) reads it until
phase 1b.

**Tests of deleted code are rewritten openly, not deleted in silence.** For
each case you remove or change in `game_analysis_walker_service_test`,
`local_puzzle_extractor_service_test`, `game_review_honest_test`,
`game_review_exercises_test` and `engine_depth_ceiling_test`, write in the
file's header what rule it held and where that rule lives now — most are
already held by `game_review_judge_test` (the side filter, the better line,
the puzzles' cap and order) or by the gate. A rule that surviving code still
needs and nothing else holds **moves** to a surviving test (`CLAUDE.md`, phase
5a: the only 18-year boundary once lived in a deleted file). The „already
decided → larger threshold" rule of `tagBlunders` is superseded by winning
chances (`+19 against +14` in the judge's test); say so.

Every existing test that opens `GameReviewDialog` must pass it a runner with
a fake book and tablebase: the default tablebase is the Lichess service, whose
pacing sleeps on a fake clock and hangs a widget test (1.2a's lesson — the
queue that waited for ever). The honest test's position has four men.

## The gate

Three files, **byte-identical** copies from `docs/gates/` into
`chess_app/test/`:

- `review_runner_test.dart` — 13 cases: where the result lands (board, draft,
  another game's draft, a board that lost the moves, a board that owns the
  draft, a review from a position forward), the side and the puzzles, the
  hold, cancel, a sign-out, one review at a time, the store.
- `review_dialog_test.dart` — 9 cases: the slider gone, closed-while-running
  and the end said by `ReviewNotice`, reopened during a run, what the end
  says, a clean game, an unjudged move, the store, Cancel, another game.
- `engine_hold_test.dart` — 8 cases: stop/detach, MultiPV, callbacks, a live
  search refused, only the holder releases, the refusal said, Analysis says
  busy, and a review landing on a live Analysis screen and its draft.

They do not compile on `master` — that is expected; every other red must be
the right red. Written by the lead and **not yet run**: if a case is wrong,
stop and say which and why.

## What not to change

- `GameReviewJudge`, `mistake_rule.dart`, `EvalCache` — 1.2a's, graded. If
  you believe one of them must change, stop and say so.
- `KeepPuzzlesPanel` and what a kept exercise is.
- The Analysis screen's engine lifecycle beyond what §5 says
  (`_onShownChanged`, `TickerMode`, the draft epoch).
- No new `// ignore`. No foreground service, no isolate.

## How it is graded

- The three gate files byte-identical to `docs/gates/`. Checked.
- `dart format` on every Dart file touched.
- `flutter analyze`: the same 26 infos, no new one. Paste the summary line.
- `flutter test` — full run, foreground, **nothing else running** (rule 19:
  `game_tutorial_run_test` alone takes minutes). Paste the summary line.
- `site/`: grep it for every label you changed or removed
  (`manual_labels_test` holds the manual to the app's words).
- **Prove the hold by mutation**, each alone, each run under a timeout, each
  chained `mutate && run` (the lead's lesson of 21.9: a mutation that did not
  apply reads as a survivor): (1) `stopAnalysis` ignores the hold; (2)
  `_activateTopSubscriber` ignores the hold; (3) the runner never calls
  `hold`; (4) the runner writes the draft while a board is attached; (5) the
  runner ignores the epoch. Report which case went red for each, and revert.

## In your report

In this order: the numbers (tests before/after with the arithmetic — gate
cases added, cases deleted or rewritten, by file; analyze); the mutations and
the case each turned red; every case you believe wrong in the gate; the
texts you chose for the stages and the end; and **what this brief got wrong**
— anything it asserts about the code that did not hold. Write that section
even if it is empty.
