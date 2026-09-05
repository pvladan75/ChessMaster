# TASK — the tree's view never moves itself

This file plus `docs/brief-zum-ne-skace-2026-09.md` are the only context you
get. **Do not rely on any conversation before them.** Read the brief first; it
holds the reasoning, what has already been measured, and the pass conditions.

Branch: `design/zum-ne-skace`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 2 of `docs/PLAN-TABLA-I-STABLO.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side.

One source file, and no others:

1. **edited** `lib/features/analysis_studio/widgets/visual_move_tree_widget.dart`
   — the automatic call site around line 424, and one new private method plus
   one new constant. §3 of the brief.

Plus one new test file, `test/move_tree_viewport_test.dart`. §7 of the brief.

## What you must not do

* **Do not edit `_centerOnActive` to stop centring.** It stays exactly as it is,
  because the toolbar button „Centriraj na aktivni potez" calls it and that is
  the user asking. Only the *automatic* call site changes. §3.3.
* **Do not touch `repertoire_build_screen.dart`, `move_tree_widget.dart`,
  `repertoire_tree_panel.dart` or `analysis_studio_screen.dart`.** The rule
  lives in one widget and reaches every screen through it.
* **Do not "fix" the zoom by editing the scale maths.** It has been measured:
  `_centerOnActive` already preserves the scale, and the only two places that
  change it are the user's own zoom and the user's own reset. §2 of the brief
  says where the change most likely comes from and why it is out of scope. A
  report that says the zoom was fixed, without a test that was red before the
  change and green after, fails this batch.
* **Do not fix the state-loss bug of §5.** Measure it, print the two numbers,
  delete your scratch file, report it. That is the whole deliverable there.
* **Do not add a test-only hook to production code** — no
  `@visibleForTesting` field, no exposed controller. §4 shows how to read the
  transform through the `InteractiveViewer` that is already there.
* **Do not change any user-facing string.** Not a tooltip, not a label. The
  `strings` allowance for this batch is empty.
* **Do not add a skipped test.** The suite has exactly one skip (the golden
  group) and it must still have exactly one.
* **Do not edit an existing test to agree with your code.** A test you had to
  change is a finding: report it and stop.
* **Do not grade yourself on golden tests.** They are skipped unconditionally
  and `--tags golden` alone still skips them; the run exits 0 saying „All tests
  skipped".
* **Do not call `ScaffoldMessenger`.** `AppFeedback` only —
  `test/app_feedback_guard_test.dart` fails on a raw call.

## What you need before starting

* Flutter, and `flutter test` on the branch **before you change anything**.
  **Measure it yourself and report it; do not trust a number quoted at you.**
  It should be **1234 passing, 1 skipped**. If it is lower, stop and
  report — something is wrong before your work starts.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`, in
  `positional_evaluator_service.dart`, `tactical_motif_detector.dart`,
  `game_analysis_walker_service.dart`, `review_api_service.dart`,
  `ai_studio_screen.dart` and `matrix_filter_panel.dart`. Compare the list, not
  the exit code — it does not exit clean and has not for a long time.
* No backend, no database, no credentials, no network. This batch needs none of
  them and must not ask.

## The changes, in this order

### 1. The tests first, and watch two of them fail

Write `test/move_tree_viewport_test.dart` before you change the widget. Model it
on `test/repertoire_tree_looks_test.dart`, which already mounts this widget at a
fixed `tester.view.physicalSize` and finds cards by their SAN.

Five tests:

1. **The scale survives a move.** Zoom in twice through the `+` button, read the
   scale off the `InteractiveViewer`'s controller, change `activeNode` to a
   node deep in the tree, pump, read it again. Exactly equal.
   *This one passes against today's code.* It is a regression lock, not a
   diagnosis, and the brief says why. Do not present it as proof of a fix.
2. **A node already inside the viewport moves nothing.** The whole matrix — not
   just the scale — is unchanged after the active node moves to another card
   that is comfortably on screen. **Fails today**, because today every move
   re-centres.
3. **A node past the edge is brought just inside.** After the move, the card's
   rect lies inside the viewport deflated by the margin. **Fails today** only if
   you also assert 4; assert both in separate tests anyway.
4. **And it is not centred.** The same case as 3: the card's centre is *not* at
   the viewport's centre. **This is the test the batch exists for.** A test that
   only checks the card is visible passes against the old centring code and
   proves nothing.
5. **The toolbar button still centres.** With the active card far off, tap
   „Centriraj na aktivni potez" and the card's centre lands at the viewport's
   centre.

Run them now. **2 and 4 must be red before you change anything.** If 2 passes
against today's code your tree is too small for anything to be off screen —
build a deeper one, do not relax the expectation.

### 2. The rule

Then §3.1 of the brief, in the post-frame callback that currently calls
`_centerOnActive`: project the active card, compare against the viewport
deflated by the margin, do nothing if it is inside, otherwise translate by the
minimum offset per axis. Never touch the scale. Never assign the same matrix
back — test 2 can tell the difference.

The margin is a **named constant, 48.0**, with its reasoning in a doc comment.
§3.2 says where the number comes from and what to do if you measure otherwise.

### 3. The measurement that is not a fix

§5 of the brief. A scratch file that mounts the widget in two different subtree
slots across a width threshold, zooms, resizes, and prints the scale twice.
Print the numbers, **delete the scratch file**, quote the output in the report.
A leftover scratch file fails the worktree gate.

## Method

1. Read the brief whole. §2 is what has already been measured; §8 is what gets
   the work rejected.
2. Write the five tests. Run them. Confirm 2 and 4 are red.
3. Make them green with §3.1 and §3.2 of the brief.
4. **Mutate and watch each fail.** Put the unconditional `_centerOnActive` call
   back and confirm 2 and 4 go red. Set the margin to 0 and confirm 3 reacts.
   Report what you broke, which test failed, and the message it failed with.
5. Do the §5 measurement. Delete the scratch file.
6. `flutter test` — the count must be **1234 plus your own five**, and
   no existing test may fail.
7. `flutter analyze` — the list, not the exit code. Still 29.
8. **`dart format` every Dart file you touched — last.**

## Your report

Write `report-zum-ne-skace.md` in the worktree root, stating:

1. `flutter test` before and after, **both measured by you in this run**, with
   the skip count each time;
2. the `flutter analyze` list before and after;
3. **the margin you used**, and — if it is not 48 — the measurement that changed
   it;
4. **the active card's rect and the viewport's rect, printed, for tests 3 and
   4**, before and after the move. This is the property the batch exists for,
   and „it now scrolls to the edge" is not proof of it;
5. **the transform, printed, before and after the move in test 2** — both
   matrices, so the „no change at all" claim is readable rather than asserted;
6. **the two scales from the §5 measurement**, printed, and a plain statement of
   whether the state-loss hypothesis reproduced. If it did not, say so — a
   negative result here is worth as much as a positive one, and it retires a
   hypothesis the lead is otherwise going to spend a day on;
7. **the mutations of step 4**, each with the test that failed and the message
   it failed with. Not „I verified them": the output;
8. anything the brief got wrong. A correction is worth more than a clean report.

**Do not claim a number you did not compute in that run.**
