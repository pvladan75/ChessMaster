# Task: the student can walk the sidelines the trainer wrote

A bounded job for an outside agent. **This file plus
[brief-tutorijal-stablo-2026-09.md](brief-tutorijal-stablo-2026-09.md) are the
only context you get** — do not rely on any conversation before them.

Branch: `batch/tutorijal-stablo`. Commit as
`batch 52 — tutorijal: stablo u pregledaču`. **Do not commit.** Leave the
worktree dirty; the lead reads the diff.

Run this only on a tree that already has batch 51 (the vocabulary) merged. If
`chess_app/lib/features/assignments/screens/lesson_viewer_screen.dart` still
says „Ova lekcija nema nijedan korak.", **stop and say so in the report** — you
have the wrong base commit.

## What is asked

Flutter only, and only these two files:

* `chess_app/lib/features/assignments/screens/lesson_viewer_screen.dart`
* `chess_app/lib/features/lessons/models/lesson_step_line.dart`

A lesson step carries its line as PGN, and that PGN can contain variations —
`MoveTree.parsePgn` already reads them and keeps them in the tree. The screen
then calls `mainLine()` and throws them away, so a sideline the trainer wrote is
**parsed, stored, and unreachable**.

1. `LessonStepLine` gains `MoveTree? tree` beside the `PgnLine line` it already
   returns. `replays` and `rejectedMoves` keep their exact meaning — the
   trainer's studio checks a step with them before saving and that must not
   change.
2. `LessonViewerScreen` stops holding five parallel lists indexed by ply
   (`_fens`, `_moves`, `_comments`, `_arrows`, `_squares`) and holds the tree
   and the node the child is standing on. Everything drawn is read off that
   node: `node.comment`, `node.arrows`, `node.squares`, `node.fen`. The root's
   comment stays what it is — the note about the starting position, shown
   before the first move.
3. `LinearMoveCursor` is replaced by `MoveTreeCursor`, which already exists in
   `lib/core/models/move_cursor.dart` with `forwardBranches` and `takeBranch`.
   `MoveNavigationControls` already opens the branch sheet when a cursor
   reports more than one branch — **you do not write a chooser.**
4. The narrated walk **stops at a fork** instead of taking the first child.

**Nothing else.** Do not touch `chess_backend/`. Do not change the PGN format,
`MoveTree`, `MoveTreeCursor`, `MoveNavigationControls` or the branch sheet — all
four are finished and shared with other screens. If the job turns out to need a
change in one of them, **write in your report which change and why, then stop.**

## The hard part, named

The step-to-step flow that already exists must survive this. In particular:

* the **narrated walk**: a move is played only when the sentence in front of it
  has finished being spoken;
* the **join**: when a step's line ends on a position the *next* step stands on,
  the lesson goes on by itself, reads the question and unlocks the board —
  without reloading the board or recomputing the orientation. With a tree, „the
  end of the line" means **the end of the main line**. A child standing in a
  sideline must never auto-advance: they came off the path on purpose.
* a step with **no** branches must behave exactly as it does today, down to the
  strip's „Potez N od M".

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself.
2. Read these five test files first. They are the specification of the flow you
   must not break: `lesson_viewer_line_test.dart`, `lesson_narration_test.dart`,
   `lesson_step_narration_test.dart`, `lesson_board_playable_test.dart`,
   `lesson_step_asks_test.dart`.
3. **They must pass unedited.** If you believe one of them is wrong, say so in
   the report and stop — do not edit it. A test edited to make a refactor pass
   is how a working feature is quietly removed.
4. `dart format` every file you touch.
5. `flutter test` and `flutter analyze` after. Both go in the report.

## What the report must contain

Write it to `docs/REPORT-batch-52.md`.

* the test count before and after, both measured by you in this run;
* the analyzer list before and after — whether it changed, not just how many;
* **which of the five named test files you had to look at twice**, and why;
* how you made the narrated walk stop at a fork — in one paragraph, not a
  diff;
* anything the brief got wrong. A correction is worth more than a clean report.
