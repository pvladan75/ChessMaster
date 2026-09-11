# Undo, the saved version, and a line inserted into a part

Written 11.9.2026. Phase 1 is built; phases 2–4 are not.

## The request

The owner, 11.9.2026, after deleting a part in the studio, not saving, and
opening the tutorial again to find the part still gone:

1. **There is no way back to the version saved on the server.**
2. **There is no undo or redo.**
3. **A part cannot be cut to insert another line.** The example: from
   `8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1`, a demonstration
   `1. Ra1 Kc6 2. Ra6 Bb2 3. c3 Kb5`, and a second line `2. Ra8 Bb2` to show
   from the position after `Kc6`. That makes three parts: the first up to
   `Kc6`, the second the inserted line, the third the original continuation
   `2. Ra6 Bb2 3. c3 Kb5` from the same position. Every comment, square and
   arrow is kept.

## The decisions

The owner, the same day:

- **Undo goes back 100 steps**, for as long as the studio is open. Typing a
  sentence is one step per pause, not one per letter. Closing the studio
  clears the history. Getting back to the saved version is item 2's job.
- **Opening a tutorial that has unsaved changes on this machine asks**:
  continue with the changes, or open the saved version. It is asked only when
  there really are changes. The studio also gets „Discard changes", which
  reloads the saved version and can itself be undone.
- **„Insert a line here"** splits the part at the beat the trainer is standing
  on and leaves them on the new part's first position, to play the line. A
  sideline already played at that beat goes into the new part by itself.

## What exists

- **One on-device slot** (`TutorialDraftService`), written 600 ms after the last
  change and flushed on close. Every change in the studio reaches it through
  `_persist()` — 27 call sites in `tutorial_studio_screen.dart` — and
  `scheduleSave` already encodes the whole draft synchronously on every call. So
  the cost of a snapshot is already being paid; undo keeps the snapshots
  instead of discarding them.
- **The slot holds everything a restore needs**: every part's tree with its
  comments, arrows and squares, the cursor path, the selected part, the kinds
  and answers, the language, and each part's **step id**. The step id is what
  `assignment_items` and `review_items` name a step by, so an undone deletion
  has to bring the part back with the id it had, and a snapshot does.
- **A saved tutorial adopts the slot silently** when its `lessonId` matches
  (`_adoptStoredDraft`). That was deliberate — work survives a closed window —
  and it is why the deletion came back: nothing distinguishes „changes you
  made" from „what is saved", and nothing leads back to the saved version.
- **No `GET /lessons/:id`.** The studio is opened with the row from the library
  list, which can be older than the last save.
- **The cut already exists.** `splitForQuestion` in
  `services/section_split.dart` turns one part into demonstration, question and
  continuation at the cursor, carrying the marks and keeping the first part's
  step id. Item 3 is the same cut with a demonstration in the middle.
- **`treeSignature`** (`services/step_tree.dart`) compares two trees by content,
  ignoring node ids. It is what „is this part untouched" already rests on.

## Phase 1 — undo and redo

First, because it is the safety net for the other two: discarding changes and
splitting a part are both undoable from the day they arrive.

**Built 11.9.2026**, with four things the plan below did not have:

- **Ctrl+Z is the studio's inside text fields too.** The plan left it to a
  focused field. On Windows a field keeps its focus while a piece is dragged on
  the board, so after a sentence and a move, the field's own undo would have
  taken back letters and left the move standing. The studio's history holds
  typing, one step per pause, so one undo covers both.
- **„Preview as student" is an icon now**, with its name as the tooltip. The
  measurement that decided it was wrong, and so was the conclusion (corrected
  the same day, see „The measurements were wrong" below). As Windows draws
  the bar, the words take 147 px and fit: no overflow at 700 dp. Whether the
  words come back is the owner's call.
- **Step ids survive an undo past a save.** Each part carries a key of its own
  on this device (`TutorialSection.localKey`), the studio learns which step id
  each key was given, and a restored part gets its id back; the lesson id never
  goes back to none. Without it, an undo past the first save followed by a
  second save created a second tutorial.
- **The task and the answers now record their changes.** They never called
  `_persist()`, so an edit to them would have been undone together with the
  next unrelated change.
- **The shortcuts are on the „Keyboard Shortcuts" page**, as its own gate
  demands of every key the app binds.

Twenty-seven tests, and 26 mutations, all caught. Two more survived the first
run and were both findings: the task field had no test, and the seal on a redo
was a line no test could fail — a redo only follows an undo, which has already
sealed, so it was deleted. Chasing that one found the real gap: nothing asked
that typing merges again once the trainer carries on after an undo, which
without it would have come back one letter per undo for the rest of the
session.

Measured on the 40-part, 200-move render fixture: a snapshot is 100 KB plus a
38 KB content signature, and recording one takes about 2 ms — about 14 MB for
a full history of the largest tutorial there is.

- **A pure history** (`services/draft_history.dart`): a list of encoded draft
  snapshots with a cursor, 100 steps, the redo half cleared by any new change.
  A change whose content is the same as the last step is not recorded —
  selecting another part or walking the line calls `_persist()` too, and those
  are not edits. **Content** means the draft without the cursor, the selected
  part and the save timestamp; the snapshot itself keeps the cursor, so an
  undo puts the trainer back where the change was made.
- **Typing is merged.** A change from a text field — a comment, the title, the
  labels, the task, an answer — joins the previous step while the same field
  keeps changing without a pause of about a second. So one undo removes a
  sentence, not a letter.
- **Recording** happens in `_persist()`, the one place every change passes
  through, after `_syncSelectedSection()`. A call site that changes the draft
  without calling it would be a change undo cannot see; a test walks the
  screen's actions and asserts each one records a step.
- **Restoring** rebuilds the draft from the snapshot, reloads the open part into
  the editor (`_loadSelectedSection()` — the lesson of 7.9.2026 is that
  skipping it writes defaults back over a part), moves the board to the
  cursor, and writes the slot, without recording the restore as a new step.
- **Controls**: „Undo" and „Redo" in the app bar, disabled when there is nothing
  to undo or redo, and Ctrl+Z / Ctrl+Y (and Ctrl+Shift+Z) on the screen. Inside
  a focused text field Ctrl+Z stays the field's own undo, which is what every
  text field does; the buttons are always the studio's. Where the two buttons
  go is **measured with the real font at 840 and 700 dp**, as the language
  field was — the app bar already carries three icons, „Preview as student"
  and „Save tutorial".
- **The size of a snapshot is measured**, not assumed, on the largest imported
  tutorial, and the number goes in the code beside the limit.

Tests, on the request where it matters: a deleted part comes back with its step
id (the save after the undo sends the original id); a move, an arrow, a
language, a split and a kind change each undo; a typed sentence is one step;
redo re-applies and a new change clears it; the 101st change drops the oldest;
walking the line records nothing. Mutation targets: the no-op check, the typing
merge, the redo clear, the limit, `_loadSelectedSection` on restore.

## Phase 2 — the saved version

**Built 11.9.2026**, with three things the plan below did not have:

- **The draft on the device is adopted at once, and compared when the server
  answers.** Waiting for the answer first would have held the studio for up
  to twenty seconds on a slow line, and swapped out anything written in that
  time. So the question is asked only while nothing has changed since the
  studio opened; after that the saved version is only remembered, and
  „Discard changes" leads back to it.
- **„Open the saved version" is an undoable change**, the same one „Discard
  changes" makes, so neither answer to the question loses anything while the
  studio is open, and the question says so rather than warning.
- **A list row older than the last save** — saved from another device — is
  replaced by the server's version when nothing of the trainer's is on screen.
  The plan named that row as a problem and gave it no fix.

Two smaller rules. What a save counts as saved is taken **before** the request
goes out, so words typed while it is out are still unsaved when it returns. A
draft kept from before the language field takes on the server's language rather
than reading as a change.

Placement: the button sits beside undo and redo. As Windows draws the bar the
actions take 453 px, nothing overflows at 600 dp, and the title's 111 px are
whole down to about 610. (The first measurement said the title was whole only
from 840; it read squares — see „The measurements were wrong" below. The guess
that Windows draws the app bar's icon buttons compact, and so narrower than a
test, was measured and is wrong: they are 48 px there too.)

- **Server: `GET /lessons/:id`**, returning one row with the columns the list
  returns, to exactly the accounts the list shows it to — the list's own
  condition, not a second one written beside it, because three hand-written
  copies of one access rule is how `status = 'accepted'` was lost. Tests with
  `.env` moved aside, including another trainer's tutorial and a student whose
  invitation is not accepted.
- **What „saved" means**: the row fetched when the studio opens, replaced by
  what was sent on each successful save. Compared with the draft by content —
  title, description, labels, language, and per part its kind, name, task,
  answers, orientation and `treeSignature` — never by the text of the encoded
  slot, which carries cursors and timestamps that change without an edit.
- **On open**, for a saved tutorial whose slot holds a draft of it: the fresh
  row is fetched, and if the draft's content differs the trainer is asked —
  „This tutorial has changes you have not saved" — **Continue with my changes**
  or **Open the saved version**. Asked only when they differ. If the server
  cannot be reached, the studio opens with the changes, as today, and says it
  could not check: a question that cannot be answered correctly is not asked.
- **„Discard changes"** in the studio loads the saved version. It is recorded as
  an undo step, so a mistaken press is one Ctrl+Z away. Available only when
  there is something to discard. Placement measured, like the undo buttons.

Tests: the question appears when the slot differs from the server and not when
it matches, even if the cursor moved; „Open the saved version" shows the server's
parts and sends them on the next save; discarding is undoable; a failed fetch
opens the draft and says so; the route's access rules.

## Phase 3 — „Insert a line here"

**Built 11.9.2026.** `splitForLine` in `services/section_split.dart`, and an
„Insert a line here" icon on the **current beat's card in „Flow"**. Four things
the plan below did not settle:

- **Where the button went was decided by measuring.** In the parts panel, as
  Windows draws it, a fourth action pushes the panel's icon buttons onto a
  third row, and the list of parts goes from 114 px to 70 at 1366 × 768 and
  from 87 to 43 at 840 × 700 — one row of parts. On the beat card the icon
  shares a header row with „Delete this move", so a move's card grows by
  nothing. It is drawn on the current beat only, because „here" is where the
  trainer stands, and not at all when the part has no line to cut.
- **When the cut is at the part's own starting position, the continuation
  keeps the step id and the name**, because it *is* the original part. The
  question cut beside it lost the id in that case; it keeps it now too, with a
  test on the save request (the same day, as its own change).
- **The continuation's first position carries the cursor's arrows and squares
  too.** The board reloads there after the new line, and those marks belong to
  that position.
- **A sideline at the cursor goes to the new line and is not left in the
  continuation as well.**

### The measurements were wrong

Every „real Windows font" number this plan gave for the app bar and the parts
panel before this section was measured on squares. The probe loaded Segoe UI
as `Roboto` and `Segoe UI`, which reaches text that inherits the theme's font
family. But the app's theme hands buttons, the app bar title, dialogs, chips,
input labels and tooltips `AppText` styles, which name no family. On Windows
the engine draws a null family in Segoe UI; `flutter_test` draws it in the
square test font, and loading a font under the test font's own name does not
change that. „Choose the answer" measured 221 px as a label and 121 px as a
plain `Text` beside it.

Measured again with those styles given Segoe UI — exactly what the engine does
on Windows:

| | as first reported | as Windows draws it |
|---|---|---|
| title „Tutorial Studio" | 240 px, whole from 840 dp | 111 px, whole from ~610 |
| „Preview as student" as words | 266 px, bar overflowed 700 dp by 23 | 147 px, no overflow at 700 |
| parts panel's action buttons | a row each | two rows for three |
| list of parts at 1366 × 768 | 26 px | 114 px (1.8 rows) |
| 840 × 700 | overflowed 0.8 px | no overflow, list 87 px |

The icon-button widths (48 px) do not depend on a font and stand. The
voice-language plan's dropdown measurement stands too: its entries inherit the
theme's family, which is why that probe read 116 px against 288 on squares.

Also fixed here: phase 1's typing test depended on real time. The history
read `DateTime.now`, so six letters typed by a test merged into one step only
while the machine was idle, and the test failed under the load of the full
suite. The history reads `package:clock` now, which is the test's fake time
inside `testWidgets`. Proved with a copy of the test that sleeps 1.5 s of real
time between letters: it passes on `clock` and fails on `DateTime.now`.

- **A pure cut** beside `splitForQuestion`, sharing its path and copy helpers,
  from a `show` part with at least one move, at the cursor:
  - **A** — the part up to the cursor, keeping the original step id, its name,
    and every comment, arrow and square on it. Omitted when the cursor is the
    part's own starting position.
  - **B** — a new demonstration on the cursor's position. Its first position
    carries the cursor's arrows and squares, because the board does not reload
    across the join from A; not its sentence, which A has just read out. Any
    sideline already played at the cursor becomes B's line.
  - **C** — the original continuation from the same position, with everything
    written on it. Omitted when nothing follows the cursor.
  - The trainer lands on B's first position, ready to play the line.
- **The owner's example is the test**: that FEN, that line with a comment,
  arrow and square on every move, cut after `Kc6`. The three parts are read back
  through the child's parser (`LessonStepLine`) and each comment is asserted on
  the move that carried it; `2. Ra8 Bb2` is played into B; the save request
  carries A with the original step id, and B and C without one.
- **Where the button goes is measured.** The parts panel's action row is where
  the other ways of adding a part live, and it is also the row that overflowed
  840 dp by two pixels when it wrapped. Candidates: that row, the current beat's
  card in „Flow", and the tree's long-press menu. The measurement decides.
- **For the child**: A to B continues on the same board; C starts again on the
  position after the cut, as a page turn, and the narrated walk crosses both
  boundaries as it crosses every other.

## Phase 4 — documents and the live check

- `UPUTSTVO-STUDIO.md`: undo and redo, „Discard changes" and the question on
  open (section 7), and „Insert a line here" (section 2).
- `TODO-provera.md`: a new item — delete a part and undo it; type a comment and
  undo it in one step; close without saving and reopen (the question); discard
  and undo the discard; the owner's example split, saved, and walked as a
  student.

## Out of scope

- Undo history that survives closing the studio. The saved version and the
  question on open cover that.
- More than one local draft. The slot stays one slot.
- Joining parts back together.

## Counts to measure against

App **2024** with 1 skipped, backend **1226** with `.env` moved aside, analyze
29 infos — measured 11.9.2026 before any of this.
