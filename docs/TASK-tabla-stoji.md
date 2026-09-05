# TASK — the board stays, the rest scrolls

This file plus `docs/brief-tabla-stoji-2026-09.md` are the only context you get.
**Do not rely on any conversation before them.** Read the brief first; it holds
the reasoning, the measured numbers, and the pass conditions.

Branch: `design/tabla-stoji`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 3 of `docs/PLAN-TABLA-I-STABLO.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side.

Two source files, and no others:

1. **edited** `lib/features/repertoire/screens/repertoire_build_screen.dart` —
   `_buildBoardColumn` (the header/scroll split, §3 of the brief) and
   `_boardSize` (the height clamp, §4). **Nothing else in that file.**
2. **edited** `lib/features/repertoire/widgets/unconfirmed_banner.dart` — the
   vertical compaction of §5. No string changes.

Plus one new test file, `test/repertoire_board_sticky_test.dart`, §7.

## What you must not do

* **Do not touch `visual_move_tree_widget.dart` or `move_tree_widget.dart`.**
  Another batch owns those files in a parallel worktree right now. Editing them
  fails this batch even if the edit is correct.
* **Do not change any user-facing string.** Not „Pregledaj nepotvrđene", not the
  sentence, not a tooltip. §5 measured that shortening the sentence saves
  nothing anyway — it is inside an `Expanded`.
* **Do not make the banner one row at 360 dp by shrinking a label.** It stacks
  there on purpose; the reason is written in the file.
* **Do not hard-code the header's height** as a constant you measured once. A
  banner that is not shown costs nothing. Derive or measure it. §4.
* **Do not change the wide layout's column structure** — the tree beside the
  board, `commentBeside`, the three-column arrangement. The split goes inside
  the board column.
* **Do not call `ScaffoldMessenger`.** `AppFeedback` only —
  `test/app_feedback_guard_test.dart` fails on a raw call.
* **Do not edit an existing test to agree with your code.** A test you had to
  change is a finding: report it and stop.
* **Do not grade yourself on golden tests.** They are skipped unconditionally
  and `--tags golden` alone still skips them; the run exits 0 saying „All tests
  skipped". Widget tests over the real widgets, or nothing.

## What you need before starting

* Flutter, and `flutter test` on the branch **before you change anything**.
  **Measure it yourself and report it; do not trust a number quoted at you.**
  It should be **1212 passing, 1 skipped**. If it is lower, stop and report —
  something is wrong before your work starts.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Compare the list, not the exit
  code.
* No backend, no database, no credentials, no network.

## Method

1. Read the brief whole. §4 and §5 are the work; §7 is what gets it rejected.
2. **Measure first.** Pump `UnconfirmedBanner` at 360 and 900 and print its
   height. You should get 134 and 78. If you do not, say so and stop — the
   brief's targets came from those numbers and would be wrong.
3. Write the tests of §7 and watch tests 2 and 3 fail against today's code. If
   test 2 passes before you change anything, your fling is not scrolling
   anything — fix the test, not the expectation.
4. Then the banner (§5), then `_boardSize` (§4), then the split (§3). In that
   order: the split is the part that cannot be judged until the other two are
   right.
5. **Mutate tests 2 and 3 and watch each fail** — put the column back inside one
   `SingleChildScrollView`; give the board the full height. Report what you
   broke and what failed.
6. `flutter test` — the count must be **1212 plus your own tests**, and no
   existing test may fail.
7. `flutter analyze` — the list, not the exit code.
8. **`dart format` every Dart file you touched — last.**

## Your report

Write `report-tabla-stoji.md` in the worktree root, stating:

1. `flutter test` before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after;
3. **the banner's height at 360 and 900, before and after** — four numbers you
   printed in this run, not four you were told;
4. **the board's rect at 360×640 before and after a fling** of the scrolling
   region, printed. This is the property the batch exists for, and „it is in a
   Column now" is not proof of it;
5. **the height of the scrolling region at 360×640** after your change, printed.
   If it is under 80 px, say so plainly rather than calling the batch done;
6. **the two mutations of step 5**, each with the test that failed and the
   message it failed with. Not „I verified them": the output;
7. anything in §4 you found ambiguous, and which reading you took;
8. anything the brief got wrong. A correction is worth more than a clean report.

**Do not claim a number you did not compute in that run.**
