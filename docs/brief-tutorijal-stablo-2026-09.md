# Brief: the tree reaches the student

Companion to [TASK-tutorijal-stablo.md](TASK-tutorijal-stablo.md). That file is
the instruction; this one is why the job exists, what already exists to reuse,
and what will judge it.

## Why

The app is a chess coaching platform for Serbian children. A **tutorijal** is a
series of worked examples a trainer writes and a child walks through alone: each
step is a position, a line of moves, a sentence per move, coloured squares and
arrows, and sometimes a question.

A trainer teaching the opposition wants to show what happens when the defending
king goes **either** way — the main line, and the sideline with its own
sentence. Today the trainer can write that: the studio exports variations,
`MoveTree.parsePgn` reads them, and they sit in the tree the viewer builds. The
viewer then calls `mainLine()`, which follows first children, and the sideline
is gone. Nobody would report this as a bug, because it looks like the trainer
forgot to write it.

## What already exists — reuse it, do not rebuild it

This is the most important section in the brief. Almost everything you need is
written.

* **`MoveTreeCursor`** — `lib/core/models/move_cursor.dart`. A `MoveCursor` over
  a `MoveTree` and a `MoveNode`, with `first/previous/next/last`,
  `forwardBranches` and `takeBranch`. It is what the room and the studio already
  navigate with.
* **`MoveNavigationControls`** — `lib/widgets/game_screen/`. The one strip in
  the app. When a cursor reports more than one forward branch, it already opens
  the chooser and already refuses to move when the reader closes it without
  choosing. You give it a cursor; you do not touch it.
* **`showBranchChoice`** — `lib/widgets/game_screen/branch_choice_sheet.dart`.
  The chooser. Its title is „Odavde ide više linija — kojom?" and it lists the
  moves by SAN, marking the main line with a star rather than preselecting it.
* **`LessonStepLine.read`** — `lib/features/lessons/models/lesson_step_line.dart`.
  The single reader of a step's line: parses the `pgn` against the step's own
  `fen` and reports `rejectedMoves`, the count of moves that could not be
  played. The trainer's studio refuses to save a step where that is non-zero.
  **That contract must not change** — `studio_lesson_step_test.dart` and
  `lesson_step_line_test.dart` hold it.
* **`MoveNode`** carries `san`, `fen`, `comment`, `arrows`, `squares`,
  `children`, `parent`. Everything the screen draws is already on the node.

## The flow you must not break

Two things landed on 6.9.2026 and are the reason this feature exists at all.
Read `lesson_narration_test.dart` before you start; it is short and it is the
specification.

**1. The line is walked at the speed of the voice.** When speech is on, a
narrated walk speaks the sentence about the position and plays the next move
when the voice has finished — `SpeechService.speak` completes on
`awaitSpeakCompletion`, with a watchdog for platforms that never report it. With
speech off there is no autoplay and no timer: the child presses „Sledeći potez".
On a machine with no voice the „Pročitaj mi liniju" button is not drawn at all.

**Your change to it:** at a fork, the walk **stops**. It does not take the first
child. A walk that chose silently would make the sideline unreachable for
exactly the child who is listening instead of pressing — the child this whole
feature is for.

**2. Showing turns into asking on one board.** When a step's line ends on a
position that the *next* step stands on, the viewer moves to that step without
reloading the board and without recomputing the orientation, the narrator reads
the question, and the board unlocks. Positions are compared on the first four
FEN fields — placement, side to move, castling, en passant — deliberately not
the move counters.

**Your change to it:** „the end of the line" becomes „the end of the **main**
line". Standing in a sideline must never auto-advance into the next step.

## Rules that bite on this codebase

* **The repository is public.** No secrets, IP addresses, email addresses or
  account identifiers in code, comments or docs.
* **User-facing strings stay Serbian.** The users are Serbian children and
  trainers. Code comments and your report are English.
* **`flutter analyze` does not exit clean** — 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`, in six files. What must hold is
  zero errors, zero warnings and **no new infos**: compare the list, not the
  exit code.
* **Run `dart format` on every Dart file you edit.** CI does not enforce it and
  an unformatted file turns the next diff into noise.
* **A message must never be able to take down the action it reports on.** Do the
  thing, then say it, and say it through `AppFeedback` — a source-reading test
  fails if a raw `ScaffoldMessenger` call comes back.
* **The recurring fault in this codebase is a step that skips silently, reports
  success, and fails one layer later.** It has appeared nine times. If something
  cannot be done, fail loudly rather than falling back.

## Baselines, to measure yourself

`cd chess_app && flutter test` reads **1372 passing, 1 skipped** on the base
commit plus whatever batch 51 added. The skip is a golden-screenshot group,
skipped unconditionally in `dart_test.yaml`; leave it alone.

## How it will be judged

By machine, against `docs/gates/tutorial_branching_test.dart`, which the lead
copies into `chess_app/test/` and runs on your tree. It drives the screen
through its own controls and never names a private field, so it neither passes a
rewrite that broke the feature nor fails a refactor that did not.

Six tests. On the current tree **one passes and five fail** — that is the shape
it should have before you start:

| test | today | after you |
|---|---|---|
| the fork is offered, not decided | red | green |
| the sideline carries its own words and its own marks | red | green |
| closing the sheet leaves the board where it was | red | green |
| going back from a sideline returns to the fork | red | green |
| the narrated walk stops at a fork instead of choosing | red | green |
| **a step with no branches never shows the sheet** | **green** | **green** |

That last row is the one to watch. It passes today, and a change that breaks it
has traded the ordinary lesson away for the branching one.

On top of the gate: the five test files named in the task must pass
**unedited**. That is the real verdict. Everything else can be satisfied by a
rewrite that broke the flow; only that says the flow survived.

Your report is not the verdict. The gate is.

## Out of scope

* `chess_backend/` — frozen, and not yours.
* The PGN format, `MoveTree`, `MoveTreeCursor`, `MoveNavigationControls`, the
  branch sheet — shared with the room and the studio, and finished.
* The trainer's side: writing sidelines in the studio is a later batch. This one
  is only the reading half.
* Any change to `StudioLessonStep` or the save-time check that a step's line
  replays from its own position.
