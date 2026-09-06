# Brief: the „Tok" timeline, drawing only (batch 59)

Companion to [TASK-studio-tok.md](TASK-studio-tok.md). That file says what to
do; this one says why, what already exists, and what will bite.

This is **P6a** of [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md). P5b — the
split layout — merged on 6.9.2026 as batch 58.

## Why this job exists

A trainer writes a **tutorial**: a series of worked positions on one theme, with
a comment and a question on each, which a child then walks alone on one board.

What the child gets is a **sequence**: standing on a position they are told what
there is to see, and then a move is played onward. What the author has to read
that back from is a **move tree** — the right shape for editing a line and the
wrong shape for answering „what will this feel like". A tree does not say what
comes after what, and it does not show where the words are.

„Tok" is the same tutorial in the order the child meets it. It is the view D6
makes the default, and the tree stays beside it as the second tab, because a
fork is a tree-shaped thing and promoting a sideline is a tree operation.

**P6 was split in two** (owner, 6.9.2026), the way P5 was: this batch **draws**.
Editing the comment and the question inside the cards, and taking the fields out
of the pane, is P6b.

## What already exists — do not rebuild it

All of it is merged and frozen.

* **`beatsOf(root, current)`** — `models/tutorial_beat.dart`. The projection,
  gated headless in `test/tok_beats_test.dart` and proved by nine mutations. It
  answers every question about *what* the timeline says:

  ```dart
  beat.node          // the AnalysisNode this beat is a view of
  beat.index         // 0 at the opening position
  beat.isCurrent     // where the author stands — exactly one beat
  beat.arrivedLabel  // „1. e4" — the move that arrived; null at the opening
  beat.playsLabel    // „1... e5" — the move that leaves; null on the last beat
  beat.isLast
  beat.branches      // at a fork: each with .label and .taken
  ```

  It walks up from `current` to the root, then down first children to the end of
  the line, so a sideline the author is standing in **is** the line it projects.
* **`AnalysisNode.moveNumberLabel`** — „4. " or „4... ", read out of the FEN,
  because a tutorial part may open on any position and the ply from the root is
  not the move number. The labels above already use it.
* **`TutorialStudioScreen`** — it owns the draft, the board, the cursor and
  `_jumpTo`, which is what `onSelect` hands work to.
* **`AnalysisMoveTreeWidget`** — the tree, unchanged, moving into the second tab.
* **The theme** — `context.colors`, `AppText`, `AppSpacing`, `AppRadii`. No raw
  colours, no off-scale padding.
* **`AppFeedback`** — every message goes through it and it cannot throw. This
  batch should need no message at all.

## The rules that bite

**1. The order of a card is the child's order.** Header, then the sentence, then
the move out. It comes from the viewer's narration loop, which is the definition
of what the child experiences: standing on a node the viewer draws that node's
marks, speaks that node's comment, and only *then* plays the move onward. A card
that drew the move above the sentence would teach the author something false
about their own tutorial — and the author is about to make decisions from it.

**2. Both tabs stay built.** `AnalysisMoveTreeWidget` carries a zoom that
`PLAN-TABLA-I-STABLO` phase 2 fought to keep across a layout change. A tab that
rebuilds it throws that away, and no assertion about *drawing* would notice.
`IndexedStack` keeps the hidden one alive.

**3. The hidden tab is offstage, and that is visible from the tests.**
`find.byType` skips offstage widgets by default. That is why the gate says
`hitTestable()` where it means „is showing" and `skipOffstage: false` where it
means „exists". Three existing files' helpers were given `skipOffstage: false`
by the lead **before** this batch, precisely so you do not have to touch them.

**4. Marks are not drawn.** Nothing in the studio writes arrows or squares yet —
the editor that does is P7 — so a card that summarised them would summarise an
empty list on every beat of every tutorial that exists.

**5. Do not compute a move number and do not walk the tree.** Both are done, and
a second copy of a rule is the fault this codebase has paid for more than once:
three hand-written copies of one condition all forgot `status = 'accepted'`, and
two writers of one field encoded a mate two different ways. The gate reads your
source and fails on `fullmove`, on a second `moveNumberLabel`, and on
`.children.first`.

**6. Serbian, and the strings are frozen.** The exact set is in the gate's
header. „Linija ovog dela" **goes** — the two tabs replace that heading, and its
string goes with it.

## What was measured before this brief was written

The whole panel was built once as a **throwaway**, on a branch that was then
discarded, to find out whether the gate can be satisfied and what the contract
costs. Two things came out of it, and both are already handled:

**The gate's own helper was wrong.** It read the tree with `find.byType(...)`,
which finds nothing while the tree is the hidden tab — so the gate failed on
itself. It uses `skipOffstage: false` now.

**The same rule broke twenty assertions in three existing files**, none of whose
tests are about tabs. Their `tree()` helpers were given `skipOffstage: false` on
`master` before this batch. One of the twenty was not a fixture problem at all:
`tutorial_authoring_test.dart` asserted that a sentence appears **nowhere** on
screen, meaning „the field no longer holds it" — and the timeline draws that
sentence on its own card, correctly. A working feature would have failed it. The
lead narrowed it to ask about the `TextField`.

With that preparation in place the trial ran the **whole suite green**. That is
the state this batch is expected to reach: no existing test edited, at all.

## How it will be judged

By exit code, not by the report:

* **`test/tutorial_tok_test.dart`** — the gate: twelve tests, **0 passing and 12
  failing** against the tree as it stands, measured on 6.9.2026. All twelve
  green after.
* **`flutter test`** — every other test still green and the count up by exactly
  twelve: **1539 → 1551** on this tree, measured with nothing else running.
* **`flutter analyze`** — the same list, nothing newly suppressed. Holding a
  count steady by adding an `ignore_for_file` is a fail; a previous batch did
  exactly that and it was caught by hand.
* **`dart format`** — clean on every file you touched.
* **the diff** — two files: the new panel and the screen. A third is a finding.
* **the strings gate** — the five frozen strings and the four keys are added,
  „Linija ovog dela" is removed, and nothing else moves.

`test/opening_book_service_test.dart` takes ~20 s to load its dataset and times
out when something heavy runs beside it. Measure the suite with nothing else
running.

## Out of scope, said once

* Inline editing of the comment and the question, and the question card under
  the last beat (P6b). Arrows and squares (P7). Retiring the old step editor
  (P8).
* Anything above the tabs in the authoring pane: the parts panel, the fields,
  the save button, the P5b layout. All frozen.
* `chess_backend/`, `lesson_viewer_screen.dart`, Android.
* Any change to `beatsOf` or to `AnalysisNode`. If you believe one of them has
  to change for this batch to work, **stop and say so in the report.** That is a
  contract problem and it is the lead's to fix. The last three batches each did
  exactly that, and it was the most useful thing in their reports.
