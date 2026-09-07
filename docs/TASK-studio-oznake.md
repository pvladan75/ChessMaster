# Task: the trainer draws on the board in the studio

A bounded job for an outside agent. **This file plus
[brief-studio-oznake-2026-09.md](brief-studio-oznake-2026-09.md) are the only
context you get** — do not rely on any conversation before them.

Branch: `batch/studio-oznake`. Commit as `batch 61 — crtanje po tabli u
studiju`. **Do not commit.** Leave the worktree dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/widgets/game_screen/board_annotation_controller.dart` and
`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
both exist. If either is missing, **stop and say so**.

## What is asked

Flutter only, against an interaction that is **already built, merged and
frozen**. Two things:

1. **A new widget**,
   `lib/widgets/game_screen/board_annotation_bar.dart`, holding a stateless
   `BoardAnnotationBar`: an arrow button, a square button, one swatch per colour
   in `ArrowColor.all`, and a clear button. It reports every press through
   callbacks and owns nothing.
2. **The studio wires it to the board.** The bar goes under the board in the
   authoring screen; the screen holds one `BoardAnnotationController`; the board
   is given `isDrawingMode` and `drawingStartSquare` from it and reports square
   taps into it; and the marks land on the node the author is standing on and
   are persisted the way every other edit on that screen is.

`BoardAnnotationController` already does all the deciding — what a tap means,
when a mark is drawn, when it is taken back, what colour it gets, what happens
to a half-drawn arrow. **You are building the surface and the wiring.**

**Nothing else.** Do not open `lib/screens/chess_game_screen.dart` — the room
keeps its own copy of this interaction until P7b, which is a separate batch that
starts with tests the room does not yet have. Do not touch `chess_backend/`, the
viewer, or anything under `chess_app/android/`. Do not change
`board_annotation_controller.dart`, `analysis_node.dart`, `tutorial_draft.dart`,
`step_tree.dart`, `tutorial_save.dart`, `pgn_exporter_service.dart` or the
timeline panel.

**Three rules that will cost you.**

* **Do not write a second copy of a rule the controller already holds.** No
  `indexWhere` over `arrows` in a screen, no „if the same square twice", no
  colour comparison when erasing. Every gesture goes through the controller,
  which is why it exists; a copy is a finding even when it behaves identically
  today.
* **The marks belong to the node, not to the controller.** Every controller
  method is handed the two lists — `node.arrows` and `node.squares` — of the
  node the author is standing on. Hand it the node the *board* is showing.
* **A tap that changed nothing must not be persisted.** Every method returns
  whether anything changed. The first tap of an arrow returns false, and a
  screen that writes a draft on it writes one per tap.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of `docs/gates/tutorial_oznake_test.dart`.**
Read that header first — all of it — and treat it as the specification. It gives
every key, the five Serbian strings that are the whole of the new copy, and what
the controller already offers.

The three that will cost you if you get them wrong:

* **What is judged is the saved `pgn`, not the board.** The gate draws, presses
  „Sačuvaj tutorijal", and reads the request back through `LessonStepLine`. A
  mark that paints and does not travel is the failure this batch exists to
  avoid.
* **Marks on the starting position travel.** „Pogledaj polje d5" is a whole
  lesson step, and the root is the only place such a mark can live. The model
  already handles this — `pgnForSave` names arrows and squares explicitly — so
  it works if you write the marks onto the right node and nowhere else.
* **The board moving cancels a half-drawn arrow.** Call `cancelPending()`
  wherever the cursor moves. It does not leave drawing mode, on purpose.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read the summary line it
   prints („N issues found") rather than counting matches yourself.
3. Read `test/board_annotation_controller_test.dart` — nineteen tests, and they
   are the documentation of the thing you are wiring up. It is faster than
   reading the controller twice.
4. Copy `docs/gates/tutorial_oznake_test.dart` →
   `chess_app/test/tutorial_oznake_test.dart`.
   Eleven tests. Measured against the tree as it is on 7.9.2026: **0 passed, 11
   failed.**

   **Do not edit that file**, except to run `dart format` on it, which is
   expected. If you believe a test in it is wrong, **stop and say so in the
   report** — do not work around it. A workaround that satisfies a test without
   satisfying the rule is worth less than a stopped batch.
5. Build until it is entirely green.

   **No existing test should need an edit of any kind.** A red test elsewhere is
   information: read it and **say so in the report** rather than working around
   it.
6. `dart format` every Dart file you touched. Run it; do not report it as run.
7. `flutter test` and `flutter analyze` again. The suite must be higher by the
   eleven tests of the new file and **lower by none**; the analyzer list must be
   the same list, with **nothing new suppressed** — no new `// ignore:` and no
   new `ignore_for_file`.

## The report

`REPORT-batch-61.md`, in the repository root. It must contain:

* the test count **before and after**, both measured by you in this run;
* the analyzer summary line and list before and after, and the word „identical"
  or the difference;
* whether you added any `// ignore:` or `ignore_for_file` — in a line of its
  own, even if the answer is no;
* the exact list of files you changed or added;
* **proof of what travels, not of what is drawn.** Quote, from your own run, the
  `pgn` string in the request body after drawing one arrow on a move and one
  coloured square on the starting position, and point at the `[%cal]` and
  `[%csl]` in it. „The board shows the arrow" is not proof;
* **the erase rule measured**: the saved line after drawing an arrow, changing
  the colour, and drawing the same pair again;
* every test outside the gate that went red at any point, and what you did about
  it — the expected answer is „none";
* anything this task or the brief got wrong. A correction is worth more to us
  than a clean report.
