# Brief: PLAN-EKRANI phase 2 — the tactics trainer on the shared layout

Read first: `docs/PLAN-EKRANI.md` §3 (rules R1–R8) and phase 1 and 2 under §5.
Phase 1 is the model: read how `chess_app/lib/screens/ai_studio_screen.dart`
now uses `TrainerScreenLayout` and `TrainerInfoPanel`
(`chess_app/lib/widgets/trainer_board_layout.dart`), and how
`chess_app/lib/features/endgame_trainer/screens/endgame_trainer_screen.dart`
does.

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` rewrites the generated plugin registrant files under
`linux/`, `macos/` and `windows/`; revert them, they are not yours.

## The gate

`chess_app/test/tactics_trainer_panel_test.dart` — 12 cases, written by the
lead, all red on the base. **All 12 green** is the pass condition, with the
rest below.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## What to build

The screen is
`chess_app/lib/features/tactics_trainer/screens/tactics_trainer_screen.dart`
(`TacticsTrainerScreen`), in free practice, retry and an assignment.

1. **The counter (plan §2.5).** `TacticsSolveSession.solvedMoveCount`
   (`.../tactics_trainer/models/tactics_puzzle.dart`) floors an odd cursor, so
   after a solve it is one short — a one-move puzzle says „found 0". Make it
   count the reader's moves found; `_showSolution` reads it mid-line, where
   the cursor is even, and must keep working.
2. **Layout (R1).** `TrainerScreenLayout`: the board, the panel, the controls.
   The header card's content (the task line, the rating chip, the counter or
   the motif, „Puzzle: n of m", „Practicing your weakest theme.") goes into
   `TrainerInfoPanel` — chips for the context, the task as its task line
   (it is a `SpokenLine` today and stays one, said as it is said today).
   Its own size picker: give `TrainerScreenLayout` a `controlsWidth` if the
   row of buttons can outgrow the column (phase 1's lesson; measure it).
3. **Verdicts in the panel (R3).** `_buildFeedback`'s two boxes — the spoken
   verdict lines and the rating card („Rating: 1524 (+9)", the puzzle rating
   and the total solved) — are drawn in the panel's message box; the rating
   card is gone as a separate card. Good and not good keep an icon whose shape
   says it.
4. **Actions (R4, R6).** While solving: `Skip` is the one `FilledButton`,
   `Show solution` a `TextButton`. Once the puzzle is over: `Next` — not „Next
   puzzle" — is the one `FilledButton`; `Show solution` stays a `TextButton`
   where it is offered today (after a failure). No `ElevatedButton` in the
   solving screen's body. The empty, done and error screens (`_buildRetryDone`,
   `_buildAssignmentDone`, `_buildError`) may keep their buttons, but their
   one main action should be a `FilledButton` and the rest outlined — say
   what you did.

## What must not change

- **The voice**: `chess_app/test/speech_tactics_test.dart`'s `rig.voice`
  assertions stay as they are. Its literal `find.text('Next puzzle')` names
  the old label; rewrite it openly to `Next`, keeping what it protected.
- **What is recorded**: `tactics_attempt_recording_test`,
  `tactics_unloadable_assignment_test`, `homework_closed_doors_test`,
  `puzzle_history_actions_test` and `landscape_screens_test` stay green;
  where one names the old screen, rewrite it openly and say so in the report.
  Never delete a case to make a run green.
- Do not change `TrainerInfoPanel`'s or `TrainerBoardLayout`'s existing
  behaviour; additions only, and only if the screen needs them. **Phase 3 is
  being built at the same time on another branch** and may add to the same
  file — keep any change there small and say exactly what it is.

## Method

- `dart format` every Dart file you touch.
- Run the gate, then every file that pumps `TacticsTrainerScreen`
  (`grep -rl TacticsTrainerScreen chess_app/test`), then the full suite **with
  nothing else running** (`flutter test` in `chess_app/`; 5644 passed and 1
  skipped on the base, plus the gate's 12 and whatever you add). Then
  `flutter analyze`: no errors, no warnings, and the same 10 infos.
- Render the real screen with `chess_app/test/support/render_look.dart` (a
  scratch test, deleted after) at 1536 × 792, 900 × 700 and 360 × 640, solving
  and solved, and look at it. Say what you saw.
- Commit when green, one commit, ending with the attribution line the session
  gives you.

## Report

Short and checkable: the full suite's tally and analyze's summary line, as
printed; every existing test changed, one line each on what it protected and
how it still does; what you added to the shared widgets; **what the brief or
the gate got wrong**, first.
