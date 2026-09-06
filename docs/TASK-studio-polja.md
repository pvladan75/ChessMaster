# Task: the tutorial is written in the timeline

A bounded job for an outside agent. **This file plus
[brief-studio-polja-2026-09.md](brief-studio-polja-2026-09.md) are the only
context you get** — do not rely on any conversation before them.

Branch: `batch/studio-polja`. Commit as `batch 60 — polja se sele u tok`. **Do
not commit.** Leave the worktree dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart` and
`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
both exist, and the screen already draws the „Tok" / „Stablo" tabs. If either
is missing, **stop and say so**.

## What is asked

Flutter only. The timeline drawn by the previous batch becomes the place the
tutorial is **written**, and the standalone fields leave the column above it.
Two things:

1. **`TutorialFlowPanel` gains two parameters and stays a renderer.**
   `onCommentChanged(AnalysisNode, String)` and `question` (a `Widget` the
   screen builds and hands in). Every beat card gets a comment field of its own;
   the `question` widget is drawn **under the last beat** and nowhere else.
2. **`TutorialStudioScreen` stops drawing the fields beside the timeline.** The
   sentence field, the kind dropdown, „Zadatak za učenika", the offered answers
   and the recorded correct move move **into** the panel — the sentence onto its
   own beat's card, the rest into the question widget the screen hands in. What
   is left above the tabs is the tutorial's name and the parts panel.

The state stays where it is. `_currentKind`, `_instructionController`,
`_choiceControllers`, `_currentCorrectChoice`, `_currentSolutionSan` and
`_fieldsEpoch` are **per part**, they belong to the screen, and moving them into
the panel would give the panel a model — which is the one thing it must not
have.

**Nothing else.** Do not touch `chess_backend/`, the viewer, or anything under
`chess_app/android/`. Do not build arrow or square drawing (P7), the refusals or
the retiring of the old step editor (P8). Do not change `tutorial_beat.dart`,
`analysis_node.dart`, `tutorial_draft.dart`, `tutorial_sections_panel.dart`,
`step_tree.dart`, `tutorial_save.dart` or the P5b split layout.

**Three rules about the model, and they are the ones that will cost you.**

* **A card's field belongs to that card's node.** Typing into the third card
  writes the third node's comment, whichever node the author is standing on. Key
  each card's state by `beat.node.id` and let Flutter tear it down when the node
  changes. A controller built for one node and still on screen for another
  writes the first node's sentence onto the second — silently, and over a
  trainer's work.
* **The keys do not move away; they move house.** Twenty-three references in five
  test files drive this screen by key. `Key('example-sentence')` is now the
  comment field **of the current beat's card**, so there is still exactly one of
  it and it still follows the author. `example-kind`, `example-instruction`,
  `example-choice-<n>` and `example-choice-delete-<n>` keep their names inside
  the question card. Renaming any of them is rewriting five test files instead
  of building a feature, and the diff will say so.
* **Nothing new is said.** No new user-facing string: every label already
  exists and travels with its field („Komentar za trenutni potez" moves with the
  sentence). The only new literals are the two new keys.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of `docs/gates/tutorial_tok_edit_test.dart`.**
Read that header first — all of it — and treat it as the specification. It gives
the panel's constructor, every key, where the question card sits, and why.

The three that will cost you if you get them wrong:

* **The line re-projects under the fields.** Pressing a fork chip changes which
  nodes the cards are for; the fields must follow the branch that was chosen,
  not keep the text of the line that was left. That is the `_fieldsEpoch` trap
  one layer out.
* **The question is asked where the line runs out.** The question card is drawn
  under the **last** beat, once, and it is where the kind, the task and the
  answers now live.
* **The panel decides nothing.** It reports a comment through
  `onCommentChanged` and a selection through `onSelect`; the screen owns the
  cursor, the board, the draft and the save.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read the summary line it
   prints („N issues found") rather than counting matches yourself.
3. Copy `docs/gates/tutorial_tok_edit_test.dart` →
   `chess_app/test/tutorial_tok_edit_test.dart`.
   Nine tests. Measured against the tree as it is on 7.9.2026: **2 passed, 7
   failed.** The two that already pass are „the current beat keeps the key the
   rest of the suite uses" and „the question still reaches the server" — they
   pass because the field and the question exist *somewhere* today. They are in
   the file so that moving house does not break them, and a batch that reddens
   one of them has broken something that worked.

   **Do not edit that file**, except to run `dart format` on it, which is
   expected. If you believe a test in it is wrong, **stop and say so in the
   report** — do not work around it. A workaround that satisfies a test without
   satisfying the rule is worth less than a stopped batch.
4. Build until it is entirely green.

   **No existing test should need an edit of any kind.** The two changes that
   this batch would otherwise have needed are already on `master` — see the
   brief. So a red test elsewhere is information: read it and **say so in the
   report** rather than working around it. In particular, an existing test that
   can no longer *reach* a control it taps is a contract problem, not a fixture
   problem, and it is the lead's to fix.
5. `dart format` every Dart file you touched. Run it; do not report it as run.
6. `flutter test` and `flutter analyze` again. The suite must be higher by the
   nine tests of the new file and **lower by none**; the analyzer list must be
   the same list, with **nothing new suppressed** — no new `// ignore:` and no
   new `ignore_for_file`.

## The report

`REPORT-batch-60.md`, in the repository root. It must contain:

* the test count **before and after**, both measured by you in this run;
* the analyzer summary line and list before and after, and the word „identical"
  or the difference;
* whether you added any `// ignore:` or `ignore_for_file` — in a line of its
  own, even if the answer is no;
* the exact list of files you changed or added;
* **proof of what gets saved, not of what gets drawn.** Quote, from your own
  run, the `pgn` string in the request body after typing a sentence into a card
  that is **not** the one the author is standing on, and say where in it the
  sentence sits. „The field shows the text" is not proof the right node was
  written;
* **the re-projection measured the same way**: the text in the fields before you
  pressed a fork chip and after;
* every test outside the gate that went red at any point, and what you did about
  it — the expected answer is „none";
* anything this task or the brief got wrong. A correction is worth more to us
  than a clean report.
