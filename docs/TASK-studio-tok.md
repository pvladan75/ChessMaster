# Task: the „Tok" timeline, drawing only

A bounded job for an outside agent. **This file plus
[brief-studio-tok-2026-09.md](brief-studio-tok-2026-09.md) are the only context
you get** — do not rely on any conversation before them.

Branch: `batch/studio-tok`. Commit as `batch 59 — panel „Tok"`. **Do not
commit.** Leave the worktree dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/features/tutorial_studio/models/tutorial_beat.dart` and
`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
both exist. If either does not, **stop and say so**.

## What is asked

Flutter only, against a model that is **already built, merged and frozen**. Two
things:

1. **A new widget**,
   `lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart`, holding a
   stateless `TutorialFlowPanel`. It calls `beatsOf(root, current)` and draws one
   card per beat: the move that arrived, the sentence, the move that leaves — or,
   at a fork, one chip per branch. Pressing a card or a chip reports through
   `onSelect`.
2. **The screen shows it behind a tab.** At the foot of the authoring pane,
   where the heading „Linija ovog dela" and the move tree are today, two tabs:
   **„Tok"** (the panel, and the default) and **„Stablo"** (the existing
   `AnalysisMoveTreeWidget`, unchanged). The heading goes.

`beatsOf` already does all the thinking — the order, the labels, the fork, the
line the author is standing on. **You are building the surface.**

**Nothing else.** Do not touch `chess_backend/`, the viewer, or anything under
`chess_app/android/`. Do not edit anything **in the pane above** — the parts
panel, the fields, the save. Do not build inline editing of the comment or the
question, the question card under the last beat, or arrow and square drawing:
those are P6b and P7, with their own briefs. Do not change
`tutorial_beat.dart`, `analysis_node.dart`, `tutorial_draft.dart`,
`tutorial_sections_panel.dart`, `step_tree.dart` or `tutorial_save.dart`.

**Two rules about the model, and they are the ones that will cost you.**
Do not compute a move number and do not walk the tree: `beat.arrivedLabel`,
`beat.playsLabel` and `branch.label` are already „1. e4" and „1... e5", and
`AnalysisNode.moveNumberLabel` is where that rule lives. A second copy of
either is a finding.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of `docs/gates/tutorial_tok_test.dart`.** Read
that header first — all of it — and treat it as the specification. It gives the
widget's constructor, every string, every key, what a card holds and in which
order, and why.

The three that will cost you if you get them wrong:

* **The sentence sits between the move that arrived and the move that leaves.**
  That is the order the child gets it in, and the panel exists to show the
  author what the child gets.
* **Both tabs stay built and only one is shown.** `AnalysisMoveTreeWidget`
  carries a zoom that an earlier batch fought to keep across a layout change,
  and a tab that throws the widget away and builds a new one throws that away
  too. An `IndexedStack` does this.
* **The panel is stateless and decides nothing.** It reports through
  `onSelect`; the screen owns the cursor and moves the board.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read the summary line it
   prints („N issues found") rather than counting matches yourself.
3. Copy `docs/gates/tutorial_tok_test.dart` →
   `chess_app/test/tutorial_tok_test.dart`.
   Twelve tests. Measured against the tree as it is: **0 passed, 12 failed.**

   **Do not edit that file**, except to run `dart format` on it, which is
   expected. If you believe a test in it is wrong, **stop and say so in the
   report** — do not work around it. A workaround that satisfies a test without
   satisfying the rule is worth less than a stopped batch.
4. Build until it is entirely green.

   **No existing test should need an edit of any kind.** The whole panel was
   built once as a throwaway before this task was written, and with the
   preparation already on `master` the suite came out green — nothing else
   touched. So a red test elsewhere is information: read it and **say so in the
   report** rather than working around it.
5. `dart format` every Dart file you touched. Run it; do not report it as run.
6. `flutter test` and `flutter analyze` again. The suite must be higher by the
   twelve tests of the new file and **lower by none**; the analyzer list must be
   the same list, with **nothing new suppressed** — no new `// ignore:` and no
   new `ignore_for_file`.

## The report

`REPORT-batch-59.md`, in the repository root. It must contain:

* the test count **before and after**, both measured by you in this run;
* the analyzer summary line and list before and after, and the word „identical"
  or the difference;
* whether you added any `// ignore:` or `ignore_for_file` — in a line of its
  own, even if the answer is no;
* the exact list of files you changed or added;
* **proof of the property, not the mechanism.** For the re-projection: quote,
  from your own run, the headers the panel drew **before** you pressed the other
  reply at a fork and the headers it drew **after**. „It calls `onSelect`" is not
  proof the timeline followed;
* **the tab switch measured the same way**: that the tree widget's `State` object
  is the same instance before and after switching away and back;
* every test outside the gate that went red at any point, and what you did about
  it — the expected answer is „none";
* anything this task or the brief got wrong. A correction is worth more to us
  than a clean report.
