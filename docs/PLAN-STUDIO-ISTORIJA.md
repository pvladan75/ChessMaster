# Undo, the saved version, and a line inserted into a part

Written 11.9.2026. Nothing in it is built yet.

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
