# Brief: PLAN-EKRANI phase 3 — My mistakes on the shared layout

Read first: `docs/PLAN-EKRANI.md` §3 (rules R1–R8) and phases 1 and 3 under
§5. Phase 1 is the model: read how `chess_app/lib/screens/ai_studio_screen.dart`
now uses `TrainerScreenLayout` and `TrainerInfoPanel`
(`chess_app/lib/widgets/trainer_board_layout.dart`).

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` rewrites the generated plugin registrant files under
`linux/`, `macos/` and `windows/`; revert them, they are not yours.

## The gate

`chess_app/test/mistake_drill_panel_test.dart` — 13 cases, written by the
lead, all red on the base. **All 13 green** is the pass condition, with the
rest below.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## What to build

The screen is `chess_app/lib/features/archive/screens/mistake_drill_screen.dart`
(`MistakeDrillScreen`).

1. **SAN (plan §2.4).** Every move the screen names — the best move, the move
   tried, the move played in the game — in SAN, worked out from
   `MistakeItem.fenBefore`. Measured 3.10.2026: the app has no shared
   UCI → SAN helper, and three private copies of the inverse; put
   `sanOfUci(String fen, String uci)` beside `uciOfSan` in
   `chess_app/lib/core/services/move_motif.dart`, with pure cases of its own
   (a castle, a capture, a promotion, an illegal move → null), and use it.
   When the answer is shown without a move, the verdict names the best move and
   the game's move and does not say „you tried nothing".
2. **Layout (R1).** `TrainerScreenLayout`: the board, the panel, the controls.
   The prompt card's content goes into `TrainerInfoPanel`: the game (opponent,
   date, opening, result, colour) and the count („1/5") as chips; the task
   „White to move. Recall the better move." as the task line, drawn and not
   spoken (it is not spoken today — `TrainerInfoPanel.task` may be null with
   `taskText`); `Open this game in Analysis` and `Remove from drill` as text
   buttons under it or with the controls — say where.
3. **The verdict in the panel (R3)**, in the panel's message box, with an icon
   whose shape says good or not good; the engine's loss or the tablebase's
   before → after under it, as today.
4. **Actions (R4).** Before an answer: `Show answer` is the one
   `FilledButton`. After it: „How well did you recall it?" and the four grades
   **on screen without scrolling** at 1536 × 792 and 900 × 700 — today they
   are below the fold at both. The grade the reader most likely wants is the
   one `FilledButton` — `Again` after a wrong answer or a shown answer,
   `Good` after a right one — and the other three `OutlinedButton`s, in the
   order Again, Hard, Good, Easy. No colour-coded slabs, no `ElevatedButton`
   in the drill's body. (The lead's reading of R4 for four peer choices; the
   owner may overrule it, so keep it one condition in one place.)
5. The done screen (`_buildDone`) may keep its layout; its one main action
   should be a `FilledButton`, the rest outlined — say what you did.

## What must not change

- What is sent: a grade still goes to `gradeMistake` with its name; removal
  still asks first. `test/features/archive/mistake_drill_screen_test.dart`,
  `mistake_drill_open_game_test.dart` and `landscape_screens_test.dart` stay
  green; where one names the old screen, rewrite it openly and say so. Never
  delete a case to make a run green.
- Do not change `TrainerInfoPanel`'s or `TrainerBoardLayout`'s existing
  behaviour; additions only, and only if the screen needs them. **Phase 2 is
  being built at the same time on another branch** and may add to the same
  file — keep any change there small and say exactly what it is.

## Method

- `dart format` every Dart file you touch.
- Run the gate, then every file that pumps `MistakeDrillScreen`
  (`grep -rl MistakeDrillScreen chess_app/test`), then the full suite **with
  nothing else running** (`flutter test` in `chess_app/`; 5644 passed and 1
  skipped on the base, plus the gate's 13 and whatever you add). Then
  `flutter analyze`: no errors, no warnings, and the same 10 infos.
- Render the real screen with `chess_app/test/support/render_look.dart` (a
  scratch test, deleted after) at 1536 × 792, 900 × 700 and 360 × 640, before
  and after an answer, and look at it. Say what you saw.
- Commit when green, one commit, ending with the attribution line the session
  gives you.

## Report

Short and checkable: the full suite's tally and analyze's summary line, as
printed; every existing test changed, one line each on what it protected and
how it still does; what you added to the shared widgets; **what the brief or
the gate got wrong**, first.
