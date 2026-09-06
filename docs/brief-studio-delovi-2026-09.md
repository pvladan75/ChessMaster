# Brief: the „Delovi tutorijala" panel (batch 57)

Companion to [TASK-studio-delovi.md](TASK-studio-delovi.md). That file says what
to do; this one says why, what already exists, and what will bite.

## Why this job exists

A trainer writes a **tutorial** — a series of worked positions on one theme,
with a comment, arrows and questions — and a child walks it alone on one board.

The screen that writes it can currently only *append*: the running list is four
lines of plain text, and the only control is one button that closes the part
being written and opens the next. A trainer who wants to put a part in the
middle, take one out, or reorder two cannot. Everything needed to do it landed
in the model weeks of work ago and has no surface.

This batch builds that surface, and one thing more: a **join mark**. Two parts
in a row where the second begins on the position the first's line ends at are
shown to the child as one continuous board — no reload, no reset. That is the
best thing about the format and the author cannot currently see it, so
reordering silently breaks it.

## What already exists — do not rebuild it

All of it is merged and frozen.

* **`TutorialDraft`** — `models/tutorial_draft.dart`. Holds `sections`,
  `selected`, `lessonId`, `title`. Its methods are the whole job:

  ```dart
  TutorialSection get section;                  // the one that is open
  set selected(int value);                      // clamped for you
  void addSection({required bool continueFromEnd, String title = ''});
  bool removeSection(int index);                // false when it is the last
  void moveSection(int from, int to);
  void cloneSection(int index);                 // the copy carries no step id
  ```

  `addSection(continueFromEnd: true)` starts the new part on the position the
  open part's line ends at; `false` starts it on the opening position. Both
  select the new part. `removeSection` answering `false` is the refusal — it is
  not an error and it must not throw.

* **`TutorialSection`** — one part. `title`, `kind`, `root` (the tree),
  `cursorNode`, `stepId`. `root.fen` is where the part's board opens.
* **`TutorialStudioScreen`** — `screens/tutorial_studio_screen.dart`. It owns
  `_draft`, the board controller and the text fields, and it already has the two
  methods this batch needs: `_loadSelectedSection()` fills the fields and the
  board from `draft.section`, and `_syncSelectedSection()` writes them back.
  **Call the second before changing the selection and the first after**, or the
  trainer's last sentence lands in the wrong part.
* **`AppFeedback`** — `lib/widgets/app_feedback.dart`. Every message goes
  through it and it cannot throw. Never call `ScaffoldMessenger` directly;
  `test/app_feedback_guard_test.dart` fails if one comes back.
* **The theme** — `context.colors`, `AppText`, `AppSpacing`, `AppRadii`. The
  step editor's own list (`lib/features/lessons/widgets/lesson_step_editor_panel.dart`)
  is the nearest thing to copy: a `ListView.builder` of `ListTile`s with
  `selected:`, and reorder buttons in a `Wrap` above it.

## The rules that bite

**1. Do the thing, then say it.** A message must never be able to take down the
action it reports on. This project has paid for that twice — a playback that
never started because a failing audio call sat in front of the timer, and a
recording that would not stop because `showSnackBar` threw first. Change the
draft, then report; and report through `AppFeedback`.

**2. The screen's fields are a copy of the open part, not the part itself.** The
sentence, the task, the kind and the offered answers live in
`TextEditingController`s and local fields while the trainer types. `_sync…`
writes them into the part; `_load…` fills them from it. A selection change that
skips either loses work silently — the trainer types into part 2 and finds it in
part 1.

**3. A `DropdownButtonFormField` keeps the value it was given.** A rebuild alone
will not move it. The screen already bumps `_fieldsEpoch` and rebuilds the field
under a `KeyedSubtree` for exactly this reason; changing the selection must bump
it too, or the kind shown belongs to the part before. This has bitten this
codebase once already, in `LessonStepEditorPanel._kindEpoch`.

**4. Nothing reaches the server.** Decision 3 of `docs/PLAN-TUTORIJAL.md`: one
write, at the end. Adding, moving, cloning and deleting are local until „Sačuvaj
tutorijal". A batch that saves on any of them has changed what the button means.

**5. A `Row` that does not fit is clipped in silence in a release build.** No
yellow stripes, no assertion — the controls past the edge are simply
unreachable. Five controls in a row will not fit a narrow column: use `Wrap`,
which is what the step editor does with the same buttons.

**6. Serbian, and the strings are frozen.** The exact set is in the gate's
header. „Deo" replaces „Primer" **in this screen only** — the rest of that
rename is a separate vocabulary batch with a table, the way batch 51 was done.

## How it will be judged

By exit code, not by the report:

* **`test/tutorial_delovi_test.dart`** — fourteen tests, the contract. It is
  0/14 green today; all of it must be green.
* **`test/tutorial_authoring_test.dart`** — the replacement copy. 8 of 11 green
  today; all of it must be green. **The three that fail are the add flow. Every
  other assertion in that file is about the single `POST` body and must not
  move.**
* **`flutter test`** — every other test still green, count up by exactly
  fourteen: 1497 -> 1511 on this tree, measured by the lead on 6.9.2026.
* **`flutter analyze`** — the same list, nothing newly suppressed. Holding a
  count steady by adding an `ignore_for_file` is a fail; a previous batch did
  exactly that and it was caught by hand.
* **`dart format`** — clean on every file you touched.
* **the diff** — files outside the ones named here are findings.

## Out of scope, said once

* The split-view layout (P5b), the „Tok" timeline (P6), arrow drawing (P7),
  retiring the old step editor (P8). Later batches, with their own briefs.
* `chess_backend/` — frozen, and this needs nothing from it.
* Any change to the model, the entry type, the save routing or the library card.
  If you believe one of them has to change for this batch to work, **stop and
  say so in the report.** That is a contract problem and it is the lead's to
  fix. The last batch did exactly that and it was the most useful thing in its
  report.
