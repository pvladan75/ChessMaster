# Task: add, remove and reorder steps in the step editor

A bounded job for an outside agent. **This file plus
[brief-tutorijal-koraci-2026-09.md](brief-tutorijal-koraci-2026-09.md) are the
only context you get** — do not rely on any conversation before them.

Branch: `batch/tutorijal-koraci`. Commit as
`batch 55 — tutorijal: dodaj, obriši i premesti korak`. **Do not commit.** Leave
the worktree dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/features/lessons/widgets/lesson_step_editor_panel.dart` exists.
If it does not, **stop and say so**.

## What is asked

Flutter only, in `chess_app/lib/`, against a backend that is **already built,
merged and frozen**. One file does almost all of it:
`lesson_step_editor_panel.dart`. Five things:

1. **A title field** for the selected step — `Key('step-title')`, label
   „Naziv koraka", writing the step's `title`.
2. **„Dodaj korak"** — inserts a new step **after** the selected one, which
   becomes the selected one.
3. **„Obriši korak"** — asks first, then removes the selected step.
4. **„Pomeri gore" / „Pomeri dole"** — icon buttons with those tooltips, moving
   the selected step one place; disabled at the ends.
5. Nothing new saved on its own: all four change the list in memory, and
   „Sačuvaj korak" is still the only thing that writes.

**Nothing else.** Do not touch `chess_backend/` — it is frozen and this batch
needs no change there. Do not add drag-and-drop reordering. Do not touch
`TutorialStudioScreen` or anything under `lib/features/tutorial_studio/`.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of
`docs/gates/lesson_step_order_test.dart`.** Read that header first — all of it —
and treat it as the specification. It says what each control is called, what a
new step inherits, and why each rule is there.

The three that will cost you if you get them wrong:

* **A new step is sent with no `id` field at all.** `buildLessonStep` on the
  server generates one. Never copy the id of the step you added beside — see
  the brief for what that breaks.
* **Every existing step keeps its id**, through a move, through an insertion,
  through a deletion of some other step. This is not a formality; the brief
  explains what an id is bound to.
* **A new step inherits the selected step's `fen` and nothing else.** No kind,
  no instruction, no solution, no pgn.

The step shape you are writing into is the one already in the file: a
`Map<String, dynamic>` per step, in `_steps`, sent as `positionList` by
`_save()`.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the list — not the count, the **list**.
3. Copy `docs/gates/lesson_step_order_test.dart` to
   `chess_app/test/lesson_step_order_test.dart` and run it. It compiles against
   the tree as it is, and **all twelve tests are red**. That is the shape it
   should have before you start.
   **Do not edit that file**, except to run `dart format` on it, which is
   expected. If you believe a test in it is wrong, say so in the report and
   leave it as it is — a gate you edited has stopped being a gate.
4. Build until all twelve are green.
5. These two must stay green **unchanged**:
   `test/lesson_editor_test.dart` and `test/lesson_answer_stays_hidden_test.dart`.
   If a test in either has to be edited for your work to pass, that is a
   finding — write it in the report and stop.
6. **Do not silence the analyzer.** No `// ignore_for_file:`, no `// ignore:`.
   If a warning appears, fix the code that caused it. The previous batch held
   the count at 29 by hiding three real deprecations and called that resolved;
   the lead found it by deleting the line and re-running.
7. If you add tests of your own, put them in **one** file,
   `chess_app/test/lesson_step_order_extra_test.dart` — named here so a second
   new file is still a stray the harness can see. No test without assertions,
   and never mute `FlutterError.onError`.
8. `dart format` every Dart file you touch. Actually run it.
9. `flutter test` and `flutter analyze` after. Both results in the report.

## What the report must contain

Write it to `docs/REPORT-batch-55.md`, under exactly that name.

* the test count before and after, both measured by you in this run;
* the analyzer list before and after — whether it changed, not just how many —
  and an explicit line saying you added no `ignore` comment;
* the twelve gate tests, each with the change that made it green;
* **the `positionList` your save sends after a reorder, copied out of a test
  run**, with the ids visible. Not described — copied;
* anything this task or the brief got wrong. A correction is worth more than a
  clean report.

**Do not write a section you did not measure.** The previous batch's report had
three sections that read as evidence and were not: a quoted request body that
did not match the one the code produces, a mechanism described in a file that
does not import it, and a layout described with a widget that is not there. If
you did not run it, write „nisam merio" and move on — that costs nothing and is
worth more than a paragraph that has to be checked.
