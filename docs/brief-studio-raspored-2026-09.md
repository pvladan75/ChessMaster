# Brief: the split layout of the tutorial studio (batch 58)

Companion to [TASK-studio-raspored.md](TASK-studio-raspored.md). That file says
what to do; this one says why, what already exists, and what will bite.

This is **P5b** of [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md). P5a — the
„Delovi tutorijala" panel — merged on 6.9.2026 as batch 57.

## Why this job exists

A trainer writes a **tutorial**: a series of worked positions on one theme, with
a comment, arrows and questions, which a child then walks alone on one board.

The screen they write it on grew one control at a time, and it is still a single
scrolling column of everything: the tutorial's name, the list of its parts, the
fields for the part being written, the save button, and the move tree at the
foot. Scrolling down to look at the line takes the list of parts off the screen,
so the two things the author moves between most — *which part am I in* and
*what does this part say* — cannot be seen at once.

P5 was split in two on purpose (6.9.2026, the owner choosing between three
offered orders): a screen that gets a new arrangement **and** new behaviour in
one batch produces a diff nobody can grade in an afternoon. P5a gave the parts
their panel. This one gives the screen its shape.

## What already exists — do not rebuild it

All of it is merged and frozen.

* **`TutorialStudioScreen`** — `screens/tutorial_studio_screen.dart`. It owns
  the draft, the board controller and the text fields. Its `build` already has
  the `LayoutBuilder` and the `wide` branch this batch reshapes:

  ```dart
  final wide = constraints.maxWidth >= Breakpoints.wide;
  final boardSize = wide
      ? (constraints.maxWidth * 0.45).clamp(280.0, constraints.maxHeight - 120)
      : constraints.maxWidth - AppSpacing.lg * 2;
  ```

  `_boardColumn(double)` draws the board and the move strip; `_authoringColumn()`
  draws everything on the right. Those two are the seams — the work is what they
  are put inside, and what `_authoringColumn` is cut into.
* **`TutorialSectionsPanel`** — `widgets/tutorial_sections_panel.dart`, batch 57.
  Stateless, decides nothing: it draws `draft.sections`, marks `draft.selected`
  and reports through its callbacks. **Its constructor, its callbacks and its
  strings are frozen.**
* **`Breakpoints`** — `lib/theme/breakpoints.dart`. `wide` is 840, following
  Material 3's expanded window class. Do not invent a second threshold; there
  used to be two (800 and 900) for the same question and that is why this file
  exists.
* **`AnalysisMoveTreeWidget`**, **`BoardWithCoordinates`**,
  **`ChessBoardWithOverlay`**, **`MoveNavigationControls`**,
  **`MoveKeyboardShortcuts`**, **`AnalysisNodeCursor`** — all already wired in
  this screen, all reused verbatim. A copy of any of that plumbing is a finding,
  not a detail.
* **`AppFeedback`** — `lib/widgets/app_feedback.dart`. Every message goes
  through it and it cannot throw; `test/app_feedback_guard_test.dart` fails if a
  raw `ScaffoldMessenger` comes back. This batch should need no message at all.
* **The theme** — `context.colors`, `AppText`, `AppSpacing`, `AppRadii`. No raw
  colours, no off-scale padding.

## The shape, and the arithmetic behind it

The right column is **fixed at 460 and the board takes the rest**, which is the
reverse of today. §5.1 of the plan is the reason: text fields that grow with the
window get harder to read, not easier, so the board should be the only thing
that changes size. On a 1600 px window the board pane gets a little over 1100
and the board is then limited by the window's *height*, which is what the
existing `clamp` is for — keep it, with the new width feeding it.

At 840 exactly — the narrowest window that still counts as wide — 460 plus the
padding leaves the board around 320. That is small and it is allowed: this
screen is Windows-only, and §5.4 of the plan says a narrow window here must not
be *broken*, not that it must be good. What it must not do is overflow.

The two right-hand panels split **2:3**, the sections panel being the smaller:
it is a table of contents, and the work happens below it. The divider between
them is a plain `Divider`. The plan's sketch marks it draggable; that was
dropped for this batch (owner, 6.9.2026) because a drag needs a remembered
ratio, a minimum height for each half and a rule for what a narrow window does
with it — none of which is decided, and none of which the panel needs to be
usable.

The tutorial's name sits **above** the split, not inside either panel: it names
the whole thing, and the two panels below it are its table of contents and its
contents. (The plan's target eventually moves it into the AppBar beside an
unsaved-changes dot. That is a later decision and not this batch.)

**„Sačuvaj tutorijal" does move into the AppBar**, beside „Unos pozicije", and
out of both layouts — see the measurements below for why, and note that this is
the one thing the narrow layout does not keep. One action, one home.

## The rules that bite

**1. A `Row` that does not fit is clipped in silence in a release build.** No
yellow stripes, no assertion — the widgets past the edge are simply unreachable,
and this project has already lost three of these to it (the move strip, the
Analysis Studio's app bar, a dialog with a fixed 360 px content width on a 360 dp
phone). In a *test* build the overflow does throw, which is why the gate builds
this screen at more than one size. Where a row can grow, use `Wrap`; where a
width is fixed, take it from the constraints.

**2. The sections panel is now inside a box with a fixed height.** Its list is
built with `shrinkWrap: true` and `NeverScrollableScrollPhysics` — correct when
the whole column scrolled, wrong inside an `Expanded`, where a tutorial with a
dozen parts overflows. Its list becomes a scrolling one, and that is the **only**
change permitted in that file. Its fourteen tests in
`test/tutorial_delovi_test.dart` must stay green untouched.

**3. Independent scrolling is the point, not a side effect.** The whole reason
for the split is that the list of parts stops leaving the screen when you read
down the line. One `SingleChildScrollView` wrapped around both halves would
satisfy a screenshot and fail the batch.

**4. Nothing about behaviour changes.** Selecting a part still moves the board,
the tree and the fields; `_syncSelectedSection()` before a selection changes and
`_loadSelectedSection()` after it; nothing reaches the server until „Sačuvaj
tutorijal". If a layout change appears to require touching any of that, **stop
and say so** — that is a contract problem and it is the lead's to fix. The last
two batches each did exactly that and it was the most useful thing in their
reports.

**5. No new strings, and no edited ones.** Every sentence on this screen is
already written and approved, and „Deo" replacing „Primer" was finished in batch
57 — for this screen only. A new literal is copy you invented; a changed one is
somebody's wording rewritten to make a layout fit. The four widget keys the gate
names are the exception, and the only one.

**6. The structural test reads the screen file itself.**
`test/tutorial_studio_test.dart` asserts that `tutorial_studio_screen.dart`
contains `ChessBoardWithOverlay(`, `AnalysisMoveTreeWidget(`,
`MoveNavigationControls(` and `AnalysisNodeCursor(`, and that it declares no
class whose name ends in `Node`, `Cursor`, `Tree` or `Painter`. Splitting the
panes into new widget files would turn the first half of that red. The panes are
private methods; there are no new files in this batch but the gate.

## What was measured before this brief was written

The whole layout was built once as a **throwaway**, on a worktree that was then
discarded, for one reason: to find out whether the gate can be satisfied and
what the contract costs. Three things came out of it, and all three are in the
contract above rather than left for you to discover.

**The save had to leave the pane.** The first shape pinned „Sačuvaj tutorijal"
under the scrolling half. That is exactly where `AppFeedback` draws its
message: the SnackBar covered the button it was complaining about, and one of
the six taps on it in `tutorial_authoring_test.dart` — a frozen gate — failed
against a covered control. With the save in the AppBar the whole suite came out
**green at 1524 passing, 1 skipped, with no edit to any other test**. The
plan's own §5 sketch had it in the AppBar from the start; the measurement only
confirmed why.

**The panel needs `Flexible`, not `Expanded`.** `TutorialSectionsPanel` has to
keep working in the narrow layout, where it sits inside a scroll view and its
height is unbounded — and an `Expanded` under unbounded constraints throws. The
throwaway kept `shrinkWrap: true`, dropped `NeverScrollableScrollPhysics` and
wrapped the list in `Flexible`, which behaves under both.

**The centring is measured on `BoardWithCoordinates`, not on the board.** The
rank and file labels sit on two of the four sides, so the playing surface is
deliberately off centre inside its own widget. The gate's first version
measured the inner board and demanded an asymmetry that would have been a bug
if anyone had built it.

One thing found and deliberately **left alone**: at a phone width of 360 the
studio already overflows by 47 px, on `master`, before this batch — a
horizontal flex somewhere under the narrow branch. It is a real defect, it is
not this batch's, and the gate checks 700 px instead, which is the narrowest a
Windows window realistically gets. Do not go looking for it.

## How it will be judged

By exit code, not by the report:

* **`test/tutorial_raspored_test.dart`** — the gate: nine tests, **2 passing and
  7 failing** against the tree as it stands, measured on 6.9.2026. All nine
  green after. The two that pass today are the two that say what must not
  change.
* **`flutter test`** — every other test still green and the count up by exactly
  the gate's own. `test/tutorial_studio_test.dart`,
  `test/tutorial_delovi_test.dart`, `test/tutorial_authoring_test.dart`,
  `test/tutorial_section_titles_test.dart` and
  `test/tutorial_studio_fields_test.dart` are **untouched** — their assertions
  and their fixtures both.
* **`flutter analyze`** — the same list, nothing newly suppressed. Holding a
  count steady by adding an `ignore_for_file` is a fail; a previous batch did
  exactly that and it was caught by hand.
* **`dart format`** — clean on every file you touched.
* **the diff** — a file outside the ones named here is a finding.
* **the strings gate** — no removed literal in `lib/` at all, and the only
  added ones are the four widget keys. That is the machine-readable form of
  rule 5.

The suite stood at **1515 passing, 1 skipped** and the analyzer at **29 infos,
no warnings and no errors** on `master` at `34ae415`, both measured on 6.9.2026
with nothing else running. Measure them again yourself; a number quoted at you
is not a measurement, and `test/opening_book_service_test.dart` takes ~20 s to
load its dataset and times out when something heavy runs beside it.

## Out of scope, said once

* The „Tok" timeline and `beatsOf` (P6), arrow drawing and
  `BoardAnnotationController` (P7), the four refusals and retiring the old step
  editor (P8). Later batches, with their own briefs.
* The `[Tok]` / `[Stablo]` tab bar. It arrives with P6, which is what gives it a
  second tab; one tab in a `TabBar` is a control that does nothing.
* A draggable divider, a remembered split ratio, moving the tutorial's name into
  the AppBar, and the unsaved-changes dot.
* `chess_backend/`, `lesson_viewer_screen.dart`, Android.
* Any change to the model, the entry type, the save routing or the sections
  panel's API. If you believe one of them has to change for this batch to work,
  **stop and say so in the report.**
