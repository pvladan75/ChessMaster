# Brief: PLAN-EKRANI phase 1 — the puzzle screen on the shared layout

Read first: `docs/PLAN-EKRANI.md` §3 (rules R1–R8), §4.1, and phase 1 under §5.
Then `chess_app/lib/widgets/trainer_board_layout.dart` and how
`chess_app/lib/features/endgame_trainer/screens/endgame_trainer_screen.dart`
uses it (`_buildBody`: `LandscapeBoardLayout.applies` → the landscape layout,
otherwise `TrainerBoardLayout` by `Breakpoints.isWide`).

You are on branch `ekrani-faza-1` in a worktree. Run `flutter pub get` in
`chess_app/` before anything else, and before `dart format`.

## The gate

`chess_app/test/puzzle_screen_panel_test.dart` — 22 cases, written by the lead.
20 are red on the branch's base, 2 are green guards. **All 22 green** is the
pass condition, together with the rest below.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## What to build

The screen is `chess_app/lib/screens/ai_studio_screen.dart` (`AiStudioScreen`),
all of its modes: `mate_puzzle`, `basic_mate`, `winning_position`,
`engine_game` („Play it out"), and its `retry` and assigned variants.

1. **Layout (R1).** Choose the layout as the endgame trainer does — by window,
   never by `MediaQuery.orientation`. Window ≥ `Breakpoints.wide`:
   `TrainerBoardLayout` with `TrainerInfoPanel` beside the board. Phone
   upright: the panel under the board, the whole body scrolling as the
   endgame trainer's does. `LandscapeBoardLayout.applies`: the existing
   landscape layout with the panel in its `panels` column. If the
   three-way choice is about to be written a second time, lift it into one
   function beside `TrainerBoardLayout` (plan §4.1) and have the endgame
   trainer call it too — without changing what the endgame trainer draws
   (its tests must stay green untouched).
2. **The bar (R5).** Back, title, the opponent button where it is offered
   today, `BoardViewMenu`. The landscape header row with its Analysis / Try
   again / Next icons goes; on a landscape phone the bar is the compact one
   (`LandscapeBoardLayout.toolbarHeight`).
3. **The panel (R2).** Chips (the mode, e.g. „Mate in 1"; the reader's
   rating where it is known), the task line, then the verdict, then — once
   the puzzle is solved, failed or its solution shown — the solution tree
   (`_buildSolutionTreeSection`) and, by B, the engine panel. „Play it out"
   keeps its turn line (`Key('engine-game-turn')`) in the panel. Extend
   `TrainerInfoPanel` where it needs to be (e.g. extra children under the
   message, a message given as drawn text), keeping every existing caller's
   drawing unchanged.
4. **Verdicts (A, R3).** Replace every snackbar, dialog and sheet that says a
   verdict with one piece of state the panel draws (the plan lists them:
   `_showSnackBar` at the verdict sites, `_showFailureDialog`'s bottom sheet,
   the „Puzzle Solved!" dialog in `_submitPuzzleResult`,
   `_showDrillEndedDialog`, `_showEndgameWinDialog`). The texts the gate
   names are the texts the panel draws: the spoken line where there is one
   („Incorrect. Try another move.", „Checkmate. Puzzle solved."), the
   existing sentence where the drill ended („Stockfish delivered checkmate.
   Try again.", „The game is drawn: stalemate. Try again."). The new rating
   is in the panel after a solve. The failure sheet's three choices become
   the panel's buttons, **with the same side effects**: `Next` after a wrong
   move records the failure (`_submitPuzzleResult(false, …)`) before the next
   puzzle; `Show solution` after a wrong move records it and replays;
   `Try again` undoes the move and clears the verdict. `_showEngineGameEndedDialog`
   stays a dialog **only for an assigned game**, and there alone (not also in
   the panel); one's own game („exerciseId") says its verdict in the panel.
   `AppFeedback` stays for what is not a verdict (a failed load, „Engine did
   not respond…" may stay or move — say which in the report).
5. **Engine (B).** `StockfishAnalysisWidget` exists only once the puzzle is
   solved, failed or its solution shown, on `winning_position` and
   `basic_mate`; never on `mate_puzzle`; on `engine_game` as today; never while
   an assigned game runs (`_assigned`, unchanged).
6. **Actions (R4, R6).** One `FilledButton`: `Next`. `Try again`,
   `Show solution`, `Open in Analysis` (where offered today) as `TextButton`s;
   `Resign` as an `OutlinedButton` while „Play it out" runs. No
   `ElevatedButton` left on the screen's body. The labels „Analysis 🔬",
   „Try Again", „Next Position", „Next Puzzle" go.
7. **Basic checkmate** is no longer titled „Practice: easy (Checkmate
   Stockfish)": a task in words, with the level as a chip.

## What must not change

- **The voice.** Every sentence said today is said at the same moment, and
  nothing new is said — in particular a mode that says no task today (Basic
  checkmate) still says none (`TrainerInfoPanel.autoSpeak`). `speech_pilot_test`'s
  `rig.voice` assertions are the check; two of its literal expectations name
  the old screen (`tap(find.text('Next Position'))`, `find.text('Incorrect
  Move!')`) — rewrite those two openly, keeping what they protected.
- Every other test file green. Where a test names the old screen (e.g.
  `landscape_screens_test`'s `byTooltip('Next Position')`), rewrite it to the
  new one and say so in the report — never delete a case to make a run green.
- The server: nothing on the wire changes except where the gate asks.

## Method

- `dart format` every Dart file you touch (after `pub get`).
- Run the gate, then the files that pump `AiStudioScreen`
  (`grep -rl AiStudioScreen chess_app/test`), then the full suite **with
  nothing else running** (`flutter test` in `chess_app/`; 5605 passed and 1
  skipped before this phase, plus the gate's 22 and whatever you add). Then
  `flutter analyze`: no errors, no warnings, and no new infos — the 22 known
  ones are `curly_braces_in_flow_control_structures`, several of them in this
  file; fixing the ones your change touches is welcome, say how many.
- Commit on the branch when green, one commit, message ending with
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## Report

Short, and checkable:
- the full suite's tally and `flutter analyze`'s summary line, as printed;
- every existing test you changed, with one line each on what it protected and
  how it still does;
- what you added to `TrainerInfoPanel` / `TrainerBoardLayout`;
- anything left as a snackbar or dialog, and why;
- **what the brief or the gate got wrong**, first.
