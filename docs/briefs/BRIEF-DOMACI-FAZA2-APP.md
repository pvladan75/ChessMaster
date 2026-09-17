# Brief: „play it out" on the exercise screen — homework phase 2, app half

For an `implementer` (Sonnet 5), in a worktree. The lead has built the server
half and written the gate; this brief is the app half only.

Read first: `docs/PLAN-DOMACI-ZADATAK.md` §3 and §7 (phase 2), and this file
whole. Do not read `docs/LESSONS.md` or `docs/TODO-provera.md` — grep them if
you need a why.

## What exists already (do not rebuild it)

- **The verdict rule**: `chess_app/lib/core/models/drill_outcome.dart` —
  `GameEnding`, `GameVerdict`, `verdictFor(game, side, {plyCap, resigned})`,
  `endingLabel`. Phase 0. The board's five endings, the move limit and
  resignation are already read there, in a fixed order, and proven by
  `test/drill_outcome_test.dart`.
- **The server half**, on `master`: `chess_backend/services/engineGameTask.js`
  (the task's shape and the same verdict, judged again from the moves) and
  `POST /assignments/:id/game-result`, which takes
  `{ moves: ["e4", ...], resigned?: bool }` and answers
  `{ goalMet, ending, outcome, ownMoves }`, or 422 for a game that is not over
  and for a move the position cannot play, 409 for a second attempt, 423 for a
  locked item. **The client never sends a verdict**; it sends the moves.
- **The shared fixture**: `docs/gates/engine_game_cases.json`, read by both
  suites. Every position and move in it was replayed on a real board.
- **The exercise screen**: `chess_app/lib/screens/ai_studio_screen.dart` plays
  positions against Stockfish today (`basic_mate`, `winning_position`), reads
  its opponent's strength from `AppSettingsService` and offers
  `EngineOpponentButton` in both its headers.

## What to build

**1. The task and its verdict** — `lib/core/models/engine_game_task.dart`, and
`GameEnding.moveTarget` added to `drill_outcome.dart`. The exact API is written
at the top of the gate (`docs/gates/engine_game_goal_test.dart`); follow it to
the letter, including the refusals (`fromJson` returns **null** for a bad task,
never a guessed default) and the 200-ply default.

`engineGameVerdict` must read the board **through `verdictFor`** and add only
what a board cannot know: the „survive" target. One rule, one home — do not ask
`chess.Chess` about mate or draws a second time.

**2. The screen plays an assigned game.** Reached with an
`engine_game` assignment: the student's homework screen (phase 5) will push it,
so for now add the route/parameter and open it from
`AppRoutes.trainingDrill`-style navigation as the other categories are opened.
On that screen:

- the board starts at `task.fen`, turned toward `task.side`, and the student
  plays that side; Stockfish plays the other;
- **the strength is the task's**, not the reader's: `task.level` and
  `task.thinkSeconds` decide how the engine plays here, and
  `EngineOpponentButton` is **not** drawn on an assigned game (a student does
  not choose the opponent the trainer chose);
- a banner says the goal in words: win / hold a draw / survive N moves, and for
  „survive" how many of the student's own moves are left;
- when `engineGameVerdict(...).ending != null` the game stops, a dialog says
  what happened (`endingLabel`) and whether the goal was met, and the moves are
  posted to `POST /assignments/:id/game-result`;
- **do the thing, then say it**: post the result before showing the dialog, and
  report a failed post through `AppFeedback`. A snackbar must never be able to
  take down the recording (`CLAUDE.md`, "the recurring bug").
- a **Resign** button, which ends the game with `resigned: true`.

## The gate

Copy `docs/gates/engine_game_goal_test.dart` into `chess_app/test/` unchanged
and make it green. It is red on master today: the model does not exist.

Add, in a second file, a widget test per goal — win met, win missed, hold met by
a draw, survive met at its number, survive missed by mate — driving the real
screen with a fake engine and a fake API, asserting:

1. the dialog that appears names the ending and says whether the goal was met;
2. the request body sent to `game-result` carries the moves **and no verdict**
   (fake the client, assert on the request — `CLAUDE.md` rule 7);
3. `EngineOpponentButton` is **not** found on an assigned game, and still is on
   the ordinary drill;
4. no overflow at `Size(360, 640)` in portrait and landscape.

Pass condition, run from `chess_app/`:

```bash
flutter test
flutter analyze
```

`flutter test` must be **2906 + your new tests**, none failing, one skipped;
`flutter analyze` must report the same 26 infos as today — zero errors, zero
warnings, no new infos. Run `dart format` on every file you touch.

**Prove your own tests.** Break each new rule on purpose once — invert the mate
victim, drop the survive target, let the strength come from settings — and watch
the right test go red before you believe it green. Say in your report which
mutations you ran and which test caught each.

## Two traps, measured

1. **`chess.Chess.fromFEN` does not validate.** Given „not a fen" the Dart
   package returns an **empty board** and throws nothing — measured
   17.9.2026. The gate's refused case „a position that is not a position"
   therefore cannot pass by asking the package; use
   `lib/services/fen_legality.dart` (`fenIllegalReason` / `isFenLegal`) in
   `fromJson`. The server refuses the same FEN because `chess.js` does throw,
   which is why the fixture holds the case at all.
2. **The plies `verdictFor` counts are the ones played from the task's
   position.** `chess.Chess.fromFEN` starts with an empty history, so
   `history.length` is the number of half-moves played in this game and the
   move limit means what the server means by it. Do not count from screen
   state.

## Method

- One node answers for both: the task the screen plays is the task the server
  judged; never rebuild it from screen state.
- If you believe a test in the gate is wrong, **stop and say so in the report**
  — do not work around it. A workaround that satisfies a test without satisfying
  the rule is worth less than a stopped batch.
- Report: what you built, the two commands' output, your mutation list, and a
  section „what the brief got wrong".
