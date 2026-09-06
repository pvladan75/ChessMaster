# Task: the „Delovi tutorijala" panel

A bounded job for an outside agent. **This file plus
[brief-studio-delovi-2026-09.md](brief-studio-delovi-2026-09.md) are the only
context you get** — do not rely on any conversation before them.

Branch: `batch/studio-delovi`. Commit as
`batch 57 — panel delova tutorijala`. **Do not commit.** Leave the worktree
dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/features/tutorial_studio/models/tutorial_draft.dart` and
`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
both exist. If either does not, **stop and say so**.

## What is asked

Flutter only, in `chess_app/lib/features/tutorial_studio/`, against a model that
is **already built, merged and frozen**. Two things:

1. **A new widget**,
   `lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart`, holding
   a stateless `TutorialSectionsPanel`. It draws the parts of the tutorial with
   their numbers and names, marks the one that is open, and offers: „+ Dodaj
   deo", „Pomeri gore", „Pomeri dole", „Kloniraj deo", „Obriši deo", and a join
   mark on a part that continues the one before it.
2. **The screen uses it** in `_authoringColumn`, **replacing** the plain running
   list that is there now. Selecting a part must move the board, the tree and
   the fields with it.

The model already does all the work — `addSection`, `removeSection`,
`moveSection`, `cloneSection`, `selected`. You are building the surface.

**Nothing else.** Do not touch `chess_backend/`. Do not change
`tutorial_draft.dart`, `tutorial_entry.dart`, `step_tree.dart`,
`tutorial_save.dart`, `tutorial_draft_service.dart` or
`tutorial_library_card.dart`. Do not build the split-view layout, the timeline
panel, or arrow drawing — those are later batches. Do not rename „Primer" to
„Deo" **outside** `lib/features/tutorial_studio/`.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of
`docs/gates/tutorial_delovi_test.dart`.** Read that header first — all of it —
and treat it as the specification. It gives the widget's constructor, every
string, what each control does, and why the join mark exists.

The three that will cost you if you get them wrong:

* **The panel is stateless and decides nothing.** It draws `draft.sections`,
  marks `draft.selected`, and reports through its callbacks. Every mutation goes
  through the screen, which owns the draft, the board controller and the text
  fields. A panel that mutates the draft itself leaves the screen's fields
  showing a part nobody is looking at.
* **Selecting a part moves the board, the tree and the fields.** The screen
  already has the method that does it. Highlighting a row and leaving the board
  where it was is the failure this panel exists to prevent.
* **The last part cannot be removed.** `removeSection` answers `false`; the
  screen says so in a sentence, through `AppFeedback`.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read the summary line it
   prints („N issues found") rather than counting matches yourself.
3. Copy **both** of these into the suite:
   * `docs/gates/tutorial_delovi_test.dart` → `chess_app/test/tutorial_delovi_test.dart`
     — new. Measured against the tree as it is: **0 passed, 14 failed.**
   * `docs/gates/tutorial_authoring_test.dart` → `chess_app/test/tutorial_authoring_test.dart`
     — **it replaces the file already there.** Measured as it is: **8 passed,
     3 failed.** The three that fail are the ones that commit a part; every
     other assertion in it is untouched and green, and must stay green.

   **Do not edit either file**, except to run `dart format` on them, which is
   expected. If you believe a test in one is wrong, **stop and say so in the
   report** — do not work around it. A workaround that satisfies a test without
   satisfying the rule is worth less than a stopped batch.
4. Build until both are entirely green.
5. `dart format` every Dart file you touched. Run it; do not report it as run.
6. `flutter test` and `flutter analyze` again. The suite must be higher by the
   fourteen tests of the new file and lower by none; the analyzer list must be
   the same list, with **nothing new suppressed** — no new `// ignore:` and no
   new `ignore_for_file`.

## The report

`REPORT-batch-57.md`, in the repository root. It must contain:

* the test count **before and after**, both measured by you in this run;
* the analyzer summary line and list before and after, and the word „identical"
  or the difference;
* whether you added any `// ignore:` or `ignore_for_file` — in a line of its
  own, even if the answer is no;
* the exact list of files you changed or added;
* **proof of the property, not the mechanism**: for the selection, quote what
  the board's FEN and the tree's root were before and after you chose a
  different part, from your own run. „It calls `onSelect`" is not proof the
  board followed;
* anything this task or the brief got wrong. A correction is worth more to us
  than a clean report.
