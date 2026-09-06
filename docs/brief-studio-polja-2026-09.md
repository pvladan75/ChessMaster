# Brief: the tutorial is written in the timeline (batch 60)

Companion to [TASK-studio-polja.md](TASK-studio-polja.md). That file says what
to do; this one says why, what already exists, and what will bite.

This is **P6b** of [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md). P6a — the
„Tok" timeline, drawing only — merged on 7.9.2026 as batch 59.

## Why this job exists

A trainer writes a **tutorial**: a series of worked positions on one theme, with
a comment and a question on each, which a child then walks alone on one board.

Batch 59 gave the author the tutorial in the order the child meets it: a card
per beat, the sentence between the move that arrived and the move that leaves,
a chip per branch at a fork. It reads. It cannot be written in.

So the screen currently says the same thing twice. The timeline shows a sentence
on the card of the move it belongs to, and a single field beside the timeline is
where that sentence is actually typed — with nothing on screen saying which move
that field is about except the author's memory of where they are standing. **The
field is the writing surface and the card is the reading surface, for one
string.** That is the fault this batch closes: the sentence is edited on its own
card, the question is asked where the line runs out, and the column above stops
being a second place to write the same things.

That is §5.2 of the plan, which has had this shape from the start: 🗣 is
`node.comment`, *edited in place*, and „the last beat carries no move, and under
it sits the question card".

## What already exists — do not rebuild it

All of it is merged and frozen.

* **`TutorialFlowPanel`** — `widgets/tutorial_flow_panel.dart`, 159 lines. One
  `_BeatCard` per beat: header („Polazna pozicija" / „posle 1. e4"), the comment
  as text, then either the fork chips or „pa se igra: …". It gains two
  parameters in this batch and stays a renderer.
* **`beatsOf(root, current)`** — `models/tutorial_beat.dart`. The projection,
  gated headless and proved by nine mutations. `beat.node`, `beat.index`,
  `beat.isCurrent`, `beat.arrivedLabel`, `beat.playsLabel`, `beat.isLast`,
  `beat.branches`. Do not walk the tree yourself and do not compute a move
  number: `AnalysisNode.moveNumberLabel` is where that rule lives, and a second
  copy of it is a finding.
* **`AnalysisNode.id`** — every node already carries a stable identity. That is
  what a card's state is keyed by.
* **The screen's own state** — `_currentKind`, `_instructionController`,
  `_choiceControllers`, `_currentCorrectChoice`, `_currentSolutionSan`,
  `_fieldsEpoch`, and the pair `_loadSelectedSection()` / `_syncSelectedSection()`,
  which are the one place a part's fields are read out of and written back into
  the model. Everything the question card shows comes from there and goes back
  there.
* **`_jumpTo`** — the one cursor. `onSelect` already hands work to it.
* **The theme** — `context.colors`, `AppText`, `AppSpacing`, `AppRadii`. No raw
  colours, no off-scale padding.
* **`AppFeedback`** — every message goes through it and it cannot throw. This
  batch should need no message at all.

## The rules that bite

**1. A card's field belongs to that card's node, and this is the one way this
batch can destroy work in silence.** A `TextEditingController` built for one node
and still on screen for another writes the first node's sentence onto the second.
Nothing on screen looks wrong: the text is in a box, the box is on a card, and
the trainer finds out when a child reads the wrong words under the wrong move.
Key each card's state by `beat.node.id`; let Flutter tear the state down when the
node changes rather than reassigning `controller.text` yourself. That is why the
gate asserts on the **request body** almost everywhere and hardly at all on the
widgets: this property is invisible from the screen.

**2. The line re-projects under the fields.** Pressing a fork chip changes which
nodes the cards are for. The fields must follow. This is `_fieldsEpoch` one layer
out — the same trap that was written for the kind dropdown, which keeps the value
it was given in its own state and does not move on a rebuild alone.

**3. The keys move house, they do not move away.** Twenty-three references in
five test files drive this screen by key, and one of them is the frozen gate that
asserts on the `POST` body. `Key('example-sentence')` is the comment field **of
the current beat's card** — so it still exists exactly once, and it still holds
the sentence of the move the author is standing on, because
`tutorial_authoring_test.dart` reads that controller and asks whether walking
back brings the earlier sentence back.

**4. The question card is drawn under the last beat, once.** Not under the
current beat, not on every card. „The question is asked when the line has run
out" is a statement about the child's experience, and the card is where the
author sees it.

**5. Nothing new is said.** No new user-facing string in this batch: the labels
travel with their fields, „Komentar za trenutni potez" included. The only new
literals are `Key('beat-comment-<index>')` and `Key('question-card')`. If the
strings gate reports more added than that, you have written a widget twice —
which is exactly what it caught in batch 58, where the title field arrived copied
into both layout branches.

**6. Both layout branches still exist.** `_authoringPaneWide()` and
`_authoringColumn()` draw the same parts for a wide and a narrow window. Whatever
you build has to be *one* widget used by both. Below `Breakpoints.wide` the
screen is a resized desktop window, not a phone: it must not break, it does not
have to be good.

**7. Reaching a control is not the same as drawing it.** The lower half of the
wide layout is a scroll of its own — batch 58 exists because of that — and the
question card now sits at the bottom of it, under every beat. Existing tests
*tap* „Tip zadatka", „Dodaj odgovor" and the delete buttons, and a tap on a
control below the fold misses. If a frozen test can no longer reach a control it
used to tap, **stop and say so**: that is a contract problem and it is the lead's
to fix, not something to solve by editing the test. Batch 58's own gate helper
failed exactly this way, and it failed only in file order, which is the worst way
to find out.

## What was measured before this brief was written

The batch was **trial-built once by the lead and the trial discarded**, the way
the last three were. It paid for itself before a line of this batch was written:

**It found a fault that predates the whole plan.** The gate asked for „Zadatak za
učenika" to be inside the timeline and it was **nowhere** — because a saved
tutorial's kind had never been loaded into the editor at all. `initState` set the
title and the board FEN by hand and never called `_loadSelectedSection()`, so the
fields sat at their defaults and the first `_persist()` wrote those defaults back
over the part. Opening a saved question and pressing „Sačuvaj tutorijal" without
touching anything downgraded it to a plain position — `kind: show`, `instruction`
gone, `choices` gone — and said „Tutorijal je sačuvan." Fixed on `master` in
`ad8c11a`, with three tests that drive the widget and read the request
(`test/tutorial_reopen_test.dart`).

**And it narrowed an assertion that a working P6b would have failed.**
`tutorial_authoring_test.dart` asked whether the previous sentence was in *any*
field, meaning „is it still in front of me, waiting to be typed over" — and this
batch gives every card a field of its own. It reads the controller of
`Key('example-sentence')` now, which is the one field the author types in. Landed
separately in `3c9d481`, so this batch needs no edit to a frozen gate.

Both are on `master` already. What the trial did **not** produce is a promise
that nothing else moves: treat a red test outside the gate as information, and
report it.

## How it will be judged

By exit code, not by the report:

* **`test/tutorial_tok_edit_test.dart`** — the gate: nine tests, **2 passing and
  7 failing** against the tree as it stands, measured on 7.9.2026. All nine green
  after. The two that already pass are in the file so that moving house does not
  break them.
* **`flutter test`** — every other test still green and the count up by exactly
  nine: **1554 → 1563** on this tree, 1 skipped either way, measured on 7.9.2026
  with nothing else running.
* **`flutter analyze`** — the same list, all 29 of them `info` level and every
  one `curly_braces_in_flow_control_structures`; the summary line says „29 issues
  found". Nothing newly suppressed. Holding a
  count steady by adding an `ignore_for_file` is a fail; a previous batch did
  exactly that and it was caught by hand.
* **`dart format`** — clean on every file you touched.
* **the diff** — two files: the panel and the screen. A third is a finding.
* **the strings gate** — two keys added, nothing else added and nothing removed.

`test/opening_book_service_test.dart` takes ~20 s to load its dataset and times
out when something heavy runs beside it. Measure the suite with nothing else
running.

## Out of scope, said once

* Arrows and squares on the card (P7) — nothing in the studio writes them yet, so
  a card that summarised them would summarise an empty list on every beat of
  every tutorial that exists. The extraction of `BoardAnnotationController` from
  the room is its own batch.
* The four refusals and retiring `LessonStepEditorPanel` on Windows (P8).
* Anything above the tabs: the tutorial's name, the parts panel, the save button,
  the P5b split. All frozen.
* `chess_backend/`, `lesson_viewer_screen.dart`, Android.
* Any change to `beatsOf`, to `AnalysisNode` or to the draft model. If you
  believe one of them has to change for this batch to work, **stop and say so in
  the report.** That is a contract problem and it is the lead's to fix. Earlier
  batches have done exactly that, and it was the most useful thing in their
  reports.
