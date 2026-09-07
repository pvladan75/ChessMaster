# Brief: the trainer draws on the board in the studio (batch 61)

Companion to [TASK-studio-oznake.md](TASK-studio-oznake.md). That file says what
to do; this one says why, what already exists, and what will bite.

This is **P7a** of [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md). P6 — the
timeline, and then writing in it — merged on 7.9.2026 as batches 59 and 60.

## Why this job exists

A trainer writes a **tutorial**: a series of worked positions on one theme, with
a sentence and a question on each, which a child then walks alone on one board.

Half of what those lessons are about is a **square** rather than a move — a weak
square, an outpost, the hole a pawn left behind — and the other half is a plan
that only makes sense with an arrow drawn on it. The model has known that for a
long time: `AnalysisNode` has carried `arrows` and `squares` since phase 2 of
`PLAN-INTERAKTIVNA-LEKCIJA`, `PgnExporterService` writes them as `[%cal]` and
`[%csl]`, `LessonStepLine` reads them back, and the child's viewer draws them.
The studio shows them, read-only, and has done since it existed.

**Nothing anywhere writes one.** Every arrow in every lesson in this app got
there by being typed into a PGN by hand. That is what this batch closes, and it
is the last missing verb in the authoring screen.

## What already exists — do not rebuild it

All of it is merged and frozen.

* **`BoardAnnotationController`** —
  `lib/widgets/game_screen/board_annotation_controller.dart`, and it is the
  whole of the thinking. Nineteen headless tests in
  `test/board_annotation_controller_test.dart`, six mutations caught. Read the
  tests: they are the documentation.

  ```dart
  enum AnnotationMode { off, arrow, square }

  c.setMode(AnnotationMode.arrow);        // forgets a half-drawn arrow
  c.setColor(ArrowColor.r.id);            // the next mark only
  c.tap('e2', arrows: n.arrows, squares: n.squares);  // false: only remembered
  c.tap('e4', arrows: n.arrows, squares: n.squares);  // true: drew Ge2e4
  c.cancelPending();                      // the board moved; stays in the mode
  c.clearMarks(arrows: n.arrows, squares: n.squares);
  ```

  It holds the interaction and **never the marks**: the two screens that will
  use it keep two different node types carrying the same two lists, so every
  operation is handed those lists and edits them in place. Each returns whether
  anything changed.
* **`ChessBoardWithOverlay`** — already draws arrows and square rings, already
  ignores piece taps while `isDrawingMode` is true, already reports
  `onSquareTapForDrawing`. The studio passes `isDrawingMode: false` and an empty
  callback today; this batch fills those in. Nothing about the board changes.
* **`ArrowColor.all`** — five colours, each with an `id` (the letter that goes
  into the PGN), a Serbian `name` and a `color`. `ArrowColorButton` is the
  existing swatch widget. The list is **generated from the catalogue, never
  listed by hand**: it was listed once, the list said four while the catalogue
  held five, and nobody noticed for months.
* **`pgnForSave`** — already treats a part with no moves but with a mark on its
  root as a part that must be sent. You do not need to touch it, and you must
  not.
* **The theme** — `context.colors`, `AppText`, `AppSpacing`, `AppRadii`. No raw
  colours, no off-scale padding.
* **`AppFeedback`** — every message goes through it and it cannot throw. This
  batch should need no message at all.

## The rules that bite

**1. The controller is the only place these rules live.** No second
`indexWhere` over a node's arrows, no „the same square twice means cancel", no
colour test when erasing. This repository has paid for a duplicated rule more
than once — three hand-written copies of one SQL condition all forgot
`status = 'accepted'`, and two writers of one field encoded a mate two different
ways. The controller was extracted *before* the second copy was written, which
is the only cheap moment to do it.

**2. Erasing ignores the colour, and it will look like a bug to you.** Drawing
the same pair again removes the arrow whatever colour the picker is on. That is
deliberate and carried over from the room: the mistake being corrected is
„wrong arrow", not „right arrow, wrong colour", and having to remember the
colour it was drawn in would be worse than the button this gesture replaced. The
gate asserts it.

**3. Marks belong to the node the board is showing.** Hand the controller
`_current.arrows` and `_current.squares`. The screen already has `_current`, and
the timeline already reports selections through `_jumpTo`. A mark written onto
the root while the author stands three moves in is the P6b fault wearing a
different coat, and it is invisible on screen — which is why the gate saves and
reads back.

**4. A half-drawn arrow does not outlive what it was drawn on.** `pendingFrom`
names a square on the position the author was looking at. Every place the cursor
moves — the timeline, the move controls, the parts panel, a played move — calls
`cancelPending()`. It does not leave drawing mode: a trainer who had to press
the brush again after every move would stop using the feature.

**5. Do not persist a tap that drew nothing.** The first tap of an arrow returns
false. `_persist()` is debounced but it is not free, and a draft written per tap
is a draft written while the author is still deciding.

**6. Serbian, and there are exactly five new strings.** They are listed in the
gate's header. The room's own drawing copy stays in the room: „Nacrtaj strelicu"
and „Izbriši sve strelice" are the words of a different surface, and reusing
them here would make one string mean two layouts.

**7. Both layout branches still exist.** `_authoringPaneWide()` and the narrow
column draw the same screen twice. The bar is one widget used by both, the way
`_titleField()` and `_sectionsPanel()` are — batch 58 had a widget arrive
written once per branch, and the strings gate caught it as „added copy" in a
batch that added none.

## What is not in this batch, and why

**The room.** `chess_game_screen.dart` keeps its private copy of this
interaction for now. The plan called P7 „one extraction, two call sites", and
the second call site is being held back on purpose: **the room has no tests of
its drawing at all** — not one — and it is the screen a live lesson runs on,
where an arrow is also recorded to the timeline and broadcast to the child's
board. Rewiring it would be a refactor of the highest-stakes screen in the app
with nothing to catch a regression but a report. P7b does it, and starts by
writing those tests.

That leaves two copies of one rule standing for a while, which is a real cost
and is written down rather than pretended away.

Also out: undo buttons (the bar clears; a single mark is taken back by drawing
it again), the old lesson step editor, `chess_backend/`, Android, and any change
to the controller, the exporter, the draft model or the P6 layout. If you
believe one of them has to change for this batch to work, **stop and say so in
the report.** That is a contract problem and it is the lead's to fix; earlier
batches have done exactly that, and it was the most useful thing in their
reports.

## How it will be judged

By exit code, not by the report:

* **`test/tutorial_oznake_test.dart`** — the gate: eleven tests, **0 passing and
  11 failing** against the tree as it stands, measured on 7.9.2026. All eleven
  green after.
* **`flutter test`** — every other test still green and the count up by exactly
  eleven: **1582 → 1593** on this tree, 1 skipped either way, measured on
  7.9.2026 with nothing else running.
* **`flutter analyze`** — the same list, all 29 of them `info` level; the
  summary line says „29 issues found". Nothing newly suppressed: holding a count
  steady with an `ignore_for_file` is a fail, and a previous batch did exactly
  that.
* **`dart format`** — clean on every file you touched.
* **the diff** — two files: the new bar and the studio screen. A third is a
  finding, and `chess_game_screen.dart` in the diff is a failed batch.
* **the strings gate** — the five strings above plus the keys, nothing else
  added and nothing removed.

`test/opening_book_service_test.dart` takes ~20 s to load its dataset and times
out when something heavy runs beside it. Measure the suite with nothing else
running.

## Use `ArrowColorButton`, and do not draw a swatch of your own

The colour picker is the one control in this app whose whole job is to
distinguish hues, and the work of making it readable without them is already
done and documented in that widget: each swatch carries the **initial of its
Serbian name** (C, N, Z, P, Lj — five distinct letters, which is luck worth
using), selection is carried by a ring and a glow, and an unselected swatch is
never dimmed. That last one is a fix, not an oversight: dimming to 40 % turned
red into `#782934` and orange into `#785434` and collapsed the worst pair to
1.10:1 — the two colours hardest to separate became hardest to separate *in the
control whose job is to separate them*.

The owner is colourblind, and so is roughly one boy in twelve who will use this.
A hand-rolled circle in `arrow.color` would undo all of the above in four lines.
Build the row by generating one `ArrowColorButton` per entry in
`ArrowColor.all`, never by listing colours.
