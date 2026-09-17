# Plan: the app organised by what the user wants to do

Written 16.9.2026 at the owner's request, as a proposal with three variants.
Nothing in it is built. The owner chooses a variant and answers the questions
in §9; the phases in §8 are then briefed one at a time, each with its gate.

The wireframes for every variant are in
[skice/reorganizacija.html](skice/reorganizacija.html) — open the file in a
browser. The text below is complete without them; they show the same thing.

## 1. The request, and what it reopens

The owner, 16.9.2026 (paraphrased from Serbian): *the app has many functions,
scattered across screens, and a future user will not find their way. Similar
things are done in different places under different names — writing a tutorial
has its own screen, but Analysis has four buttons at the top that lead
somewhere else, the same word appears in the left menu of Preparation and of a
live session. Go through the app, stand where the user stands, and organise it
so they can find things. Offer more than one variant, with sketches of the
screens. And reconsider writing tutorials on Android — the earlier decision was
no, because of the screen, but it can change if there is a solution.*

`PLAN-ZAVRSNICA.md` froze „Reorganising the app by function" as **out** on
8.9.2026, on the argument that a manual which says which door a job is behind
buys most of what moving the doors would buy. The manual is written (Phase 4),
and the owner's request is the verdict on that argument: it bought time, not
the fix. This plan is the owner reopening that row, the way five other rows of
the same table were reopened by the owner's later decisions. The freeze rule
of 1c still holds for *features*: nothing here adds a capability the app does
not have. It moves, merges, renames and deletes.

## 2. What the user sees today

Measured on `master` at `bd64f9c`, by reading every screen's labels and every
push out of it. The full inventory (file and line for each label) was produced
for this plan and is summarised here; a phase brief quotes the lines it needs.

**The shell.** Four tabs — Training, Sessions, Library, People — and a
Settings icon. The manual describes them as *practice on your own · the live
lesson and homework · your material · students and trainers*. That is what
they were meant to be. What they hold:

| Tab | What it actually holds |
|---|---|
| Training | The practice hub: repertoire, my games, my mistakes, tactics, mates, endgames. Plus the „Resume session / Resume analysis" strip |
| Sessions | New session, Join by code, **Preparation**, My assignments, Review, Recorded material |
| Library | **Interactive tutorials** (Windows only), Open Preparation with an empty board, **Open Analysis**, Scan positions, My saved positions |
| People | Trainer panel (today's sessions, homework to review), requests, My students, My trainers, the Student groups icon (only when you have a student) |

**Findings, numbered so the variants can cite them.**

- **F1 — One artefact, four editors.** A tutorial (`saved_lessons` with a
  `position_list`) is written in the Tutorial Studio; in the room's „Create
  tutorial (multiple positions)" dialog (`CreateCourseDialog`, which can order
  parts but not write one); in the old step panel (`LessonStepEditorPanel`,
  which is what Android gets); and Analysis's „Create step from this
  position" appends a part titled „New task" with no screen at all. The
  answer-leak refusal is written twice, independently.
- **F2 — Thirteen actions in the Analysis bar** (eleven off Windows), of which
  four are tutorial doors with four names and three destinations: *Create
  step from this position*, *Edit tutorial steps*, *Create interactive
  tutorial*, *Make a tutorial from this game*. On a phone eleven of the
  thirteen hide behind „More tools".
- **F3 — Preparation has two doors** (Sessions card and Library button) and
  shows the user a room code „STUDIO" although every label calls it
  Preparation. Analysis has two (Library card and the resume chip).
- **F4 — Six shelves in five places.** Saved tutorials (Library card, Windows
  only); positions saved from the room (visible *only* inside the room's left
  list — the Library never shows them); positions from a scanned book (Library
  → My saved positions); saved analyses (a dialog inside Analysis); saved
  puzzle sets (another dialog inside Analysis, written silently by „Review
  entire game"); recordings (Sessions tab). A trainer who saved a position in
  Preparation has nowhere on Home to find it.
- **F5 — The trainer panel is under People.** Today's sessions and homework to
  review sit beside „Send request", not beside Sessions.
- **F6 — Dead and half-true UI.** „New Session" promises *or schedule a time
  for students*; the schedule dialog has no caller. The Premium modal has no
  caller. The 6-digit validation of the room code is bypassed by the visible
  Join button. „Student groups" vanishes when the last student leaves, groups
  and all.
- **F7 — Nothing to write with on Android.** The Library's tutorial card draws
  nothing off Windows; the two studio buttons in Analysis are Windows-only;
  the only door left is the room's „Create tutorial", behind a drawer that
  exists only for the host.
- **F8 — Tools filed as material.** Analysis and the scanner are under
  *Library*; a user who wants to analyse a game looks for a board, not a
  shelf.
- **F9 — The training hub is drawn twice**, once as the tab and once inside
  the drill screen after the back arrow, with the same ten cards.
- **F10 — The room's left column is a library, a setup dialog and an editor
  in one.** „Tutorials and positions" holds Board Setup, Save position, Import
  PGN, Create tutorial, a FEN field, search, filter chips and the list.
- **F11 — Names that describe furniture.** „Library of positions and
  tutorials", „Friends & Contacts" (the code calls them students and
  trainers), „Recorded material", „Interactive tutorials" (there is no other
  kind), „Save current tutorial / position" for saving a position.
- **F12 — Groups, walkthrough, coverage, replay, review and the endgame
  trainer are each reachable from exactly one deep place.** Most are fine
  where they are; groups is not (F6).

## 3. The rules the reorganisation is built on

1. **A tab is a verb, or a shelf — never both.** Practise, Teach, Analyse are
   verbs; Library is a shelf. Tools live under verbs, things you keep live on
   the shelf.
2. **One artefact, one editor, one door per screen.** A tutorial is written in
   the Tutorial Studio and nowhere else. A screen that can hand something to
   the studio has *one* control for it, and the questions come after the tap.
3. **What you make is listed where you would look for it, and in one list.**
   Everything a user keeps — tutorials, positions, analyses, recordings — is
   one library with kind filters, read by the Home shelf and by the room's
   left column alike.
4. **The home adapts to what the data says, never to a role field.** The
   glossary's rule (trainer is a position in a relationship) holds: a person
   with students sees their students' work; a person with a trainer sees what
   was set them; both without asking.
5. **A name says what the screen is for**, in the glossary's words. No
   „interactive", no „material", no „studio" outside the Tutorial Studio.
6. **Nothing is added.** Dead code is deleted, not hidden. The freeze on
   features stands.
7. **The manual is part of the change.** Every page that says „in the X tab"
   is rewritten in the same phase that moves X; `manual_labels_test` holds the
   labels, and a new test holds the *places*.

## 4. What every variant does first — the foundation

These fix F1, F2, F4, F5, F6, F10 and F11 without touching the tabs. They are
Variant A in full, and the first phases of B and C. A reader who wants the
cheapest possible improvement stops here.

**S1 — One editor.** The Tutorial Studio is the only place a tutorial is
written. The room's „Create tutorial (multiple positions)" and the row menu's
„Edit positions" go, and with them `CreateCourseDialog`. On Windows the row's
„Edit tutorial" already opens the studio. Off Windows, until S7 lands, the
room keeps one door — „Edit tutorial" into the old panel — and the plan says
so honestly on the screen: *Writing a tutorial is done on Windows for now.*
`LessonStepEditorPanel` is retired by S7, not before.

**S2 — One door in Analysis.** The four buttons become one menu, **„Use in a
tutorial"**, with the questions inside it:

```
Use in a tutorial ▾
  New tutorial from this position
  New tutorial from this line          (only when the node has children)
  New tutorial from this game          (only when the tree has moves; runs the engine)
  ─────
  Add this position to a tutorial…     (picker; today's "Create step")
  Add this line to a tutorial…         (picker + "from here / from start")
  ─────
  Open a tutorial to edit…             (picker; today's "Edit tutorial steps")
```

Off Windows, before S7, the three „New tutorial" rows are absent and the menu
has four rows. The bar goes from 13 actions to 10, grouped: *Board setup ·
Engine (Review game, Auto analysis, Extend) · Keep (Save analysis, Puzzle sets,
Export PGN) · Use in a tutorial · Board view*. Settings and Engine logs move to
the overflow on every width.

**S3 — One library.** A `LibraryScreen` lists everything the user keeps, with
kind chips: **Tutorials · Positions · Analyses · Recordings · Puzzle sets**,
and one search field. Every kind keeps its own row actions (a tutorial: open,
send, video, delete; a position: open in Analysis, add to a tutorial, assign;
a recording: play). The room's left column reads the same list through the
same service, filtered to what can go on a board. Positions saved from the room
and positions from a scanned book are one kind with a source label.

*Decided while writing the gate, 17.9.2026:* the server already has this view
— `GET /library/positions` over `services/positionLibrary.js`, three shelves
(`scan`, `position`, `analysis`) kept apart and read as one list. Rule 12
says extend it, not build a second merge on the client: phase 3 adds the
kinds **`tutorial`** (`saved_lessons` with a `position_list`, with its parts
count and video state) and **`recording`** (`session_recordings` of this
host) to that service, and the client's `LibraryEntry` grows the same two
kinds. Puzzle sets are device-local and stay a client-side kind. So this is a
small backend change after all, in the one file that already owns the rule.
The room's column keeps its own list and its tag filter in **3a**; **3b**
moves it onto the shared widget once that widget exists and the tag chips
have a home in it.

**S4 — Dead UI out.** `showScheduleSessionDialog`, `showScheduledSuccessDialog`,
`_scheduledSessions`, `showPremiumModal` deleted with their strings; the New
Session card's subtitle becomes true; the visible Join button goes through the
6-digit check; „Student groups" is drawn whenever the user has a student *or a
group*; Preparation shows no room code.

**S5 — Preparation has one door**, on the Sessions tab (Variant A) or the
Teach tab (B, C). The Library's „Open Preparation with an empty board" goes.

**S6 — The panel moves to where sessions are.** The trainer panel (Today, To
review, Homework due, Stalled, Inactive) leaves People and sits at the top of
the Sessions tab (A) or the Teach tab (B, C). People keeps relationships,
groups and the way into a student's progress.

**S7 — Tutorial Studio on the phone.** §7. Its own decision; the foundation
does not depend on it, but S1 is only complete with it.

**Names**, decided here, changed in one strings batch:

| Was | Is |
|---|---|
| Interactive tutorials | **Tutorials** |
| Library of positions and tutorials | **Library** (the screen), *Everything you keep* (the card's line) |
| Recorded material / You have no saved material. | **Recordings** / *No recordings yet.* |
| Friends & Contacts | **Students and trainers** |
| Save current tutorial / position; Tutorial / position name | **Save position**; *Position name* |
| Tutorials and positions (room column) | **Library** (the column), with *Board* actions separated above it |
| Create tutorial (multiple positions) | gone (S1) |
| New Session — *Start a session as host or schedule a time for students.* | **New session** — *Open a room and invite your student.* |
| Open Preparation with an empty board | gone (S5) |
| Positions from your book → Scan positions | **Scan a book** (Analyse tab in B, C; Library tools row in A) |

## 5. The three variants

### Variant A — Same four tabs, one door per job

The foundation (S1–S6) and nothing structural. The four tabs stay, so the
manual's map stays true in its first sentence.

```
Training    the hub, unchanged
Sessions    [panel: Today · To review · Due · Stalled]   ← from People
            New session · Join by code · Preparation
            My assignments · Review · Recordings
Library     Tools:   Analysis · Scan a book
            Keep:    Tutorials · Positions · Analyses · Recordings · Puzzle sets (one list, S3)
People      Requests · My students · My trainers · Student groups · → progress
```

*What it fixes:* F1, F2, F4, F5, F6, F10, F11. *What it leaves:* F8 (Analysis
is still under a shelf), and the Sessions tab still mixes the trainer's and
the student's work. *Cost:* the home widgets (`dashboard_tab`, `biblioteka_tab`,
`friends_tab`), the Analysis toolbar, the room's left column, one new
`LibraryScreen`; six manual pages re-read. Tests: the tab names are pinned in
two files, the moved labels in about ten. *Risk:* low; every screen behind a
card is untouched.

*Who it suits:* the owner who wants the doors fixed before the release and
the tabs left alone.

### Variant B — Tabs by what you want to do (recommended)

Five destinations. Every tab is a verb except the shelf, and the shelf is
inside the verb that fills it.

```
Home        what is for me now — adaptive, from data (rule 4)
            Resume session / Resume analysis
            Today's sessions · To review · Homework due       (if I teach anyone)
            Set for me · Due for review · Join by code         (if anyone teaches me)
            Recordings (last three) · Notifications
Practise    the hub, unchanged — except the progress line and „Retry failed"
            on its cards, which are `PLAN-NAPREDAK-VEZBI.md` (built 17.9.2026)
Analyse     Analysis (the board) · Saved analyses · My games (import, leaks, profile,
            repertoire from games) · Scan a book
Teach       Tutorials (list · New · Import) · Preparation · New session
            Library (S3, everything you keep)
            Students: My students · groups · requests · → progress
People      → merged into Teach and Home; the requests ("I am a trainer / I am a
            student") live on Teach → Students and on Home for the student side
```

Four tabs plus Home; on a phone the bottom bar holds five, which Material
allows. `Ctrl+1…5`.

*Why Analyse is a tab:* it is the one tool every kind of user opens — player,
student, trainer — and today it is the third button on a shelf. *Why Teach
holds the library:* the things you keep are the things you teach with; a
player who never teaches keeps analyses (on Analyse) and nothing else. *Why
Home is adaptive and not a role:* rule 4 — a person with students *and* a
trainer sees both blocks; a person with neither sees Resume, Join by code and
the manual's first page.

*What it fixes:* everything in A plus F8, and it separates the trainer's work
from the student's without a role switch. *Cost:* A plus the home shell
(`home_screen.dart`, 1460 lines, the tab list, the rail, the shortcuts, the
Android back history), a new `HomeTab`, a `TeachTab` assembled from today's
cards, and the manual's first two pages rewritten with the new map. *Risk:*
medium — every test that names a tab, every deep link that assumes four
tabs, and the landscape home layout that was measured on 16.9.2026 at four
phone sizes has to be re-measured with five destinations.

*Who it suits:* the release. This is the variant the rest of this plan is
written against; A is its first half.

### Variant C — The app knows whether you teach

Two shells over one app. `teaches` is true when the user has an accepted
student, has saved a tutorial, or has switched **„Show teaching tools"** on
in Settings; otherwise false. The bottom bar is one of two:

```
Player / student:   Home · Practise · Analyse · My trainer
                    (My trainer = assignments, review, join, trainers and requests)
Trainer:            Home · Teach · Students · Analyse · Practise
```

*What it fixes:* everything in B, and a student never sees Preparation, New
session or a Tutorials card. *What it costs beyond B:* two tab lists, two
sets of shortcuts, a Settings switch with its own test, and the case where
the same person is both (the trainer shell must still show „Set for me" on
Home, so Home is built once and both shells use it). *Risk:* the switch
itself — a trainer whose only student ended the relationship wakes up in the
student shell with the Tutorials card gone, which is F6's shape again unless
„has saved a tutorial" is part of the predicate. It is, above; it still has to
be proved by test.

*Who it suits:* a later release, after real users have shown that trainers
are confused by practice cards or students by teaching cards. Nothing in B
prevents C; C is B with a second tab list.

**Recommendation: B, built as A first.** Phases 1–4 are A; phase 5 is the
tab change; phase 6 is the phone studio. The owner can stop after 4 and ship
A.

## 6. The screens — how they look

Drawn in `skice/reorganizacija.html` for every variant; described here so a
brief can quote it.

### 6.1 Home (Variant B), desktop and phone

Desktop: the rail on the left with five destinations and Settings at the foot,
as today. The body is a single column of *blocks*, not cards: a block is a
heading and rows, with no border. Blocks appear in this order and only when
they have rows: **Resume** (two chips) · **Today** (the panel's sessions,
each with *Enter*) · **To review** (assignments, each with *Review*) ·
**Set for me** (the student's assignments, each with *Open*, and a *Due for
review: N* row) · **Join a session** (the code field and *Join*) ·
**Recordings** (three rows, *All recordings* link). An empty Home says one
sentence and links to the manual.

Phone portrait: the same blocks, one column, bottom bar with five icons.
Phone landscape (height < 480): the rail becomes the left strip as it does
today; blocks in one scrolling column.

### 6.2 Teach (Variant B)

Three cards, then the library:

```
[ Tutorials ]  Write a tutorial the student walks alone.     New · Import · (list below)
[ Preparation ] Your board, your library, no student.         Open
[ New session ] Open a room and invite your student.          Start · code field · Join
── Students ────────────────────────────────────────────
   My students (rows → progress)   · Groups   · Send a request (trainer/student chips)
── Library ─── Tutorials · Positions · Analyses · Recordings · Puzzle sets ── search ──
   rows with kind icon, title, labels, date, row actions
```

On a phone the library is its own screen behind a *Library* row, because a
list of 200 positions under three cards is a scroll nobody wants; on desktop
it is inline. The Windows-only guard on the Tutorials card goes with S7; until
then the card is drawn on every platform with *New* and *Import* disabled and
the sentence from S1.

### 6.3 Analyse (Variant B)

The board *is* the tab: the Analysis screen mounted as the tab's body, with
its own app bar row replaced by the tab header. Three rows above the board
on desktop, a *More* sheet on a phone: **Saved analyses · My games · Scan a
book**. The Analysis toolbar after S2:

```
[Board view ▾] [Setup] │ [Review game] [Auto analysis] [Extend line] │ [Save] [Puzzle sets] [Export PGN] │ [Use in a tutorial ▾] │ ⋮ (Settings, Engine logs)
```

Ten visible on ≥ 840 dp; on a phone: Board view, Setup, Use in a tutorial,
and ⋮ with the rest. Landscape on a phone keeps the 16.9.2026 layout (board
left, strip right).

### 6.4 The room and Preparation

The left column splits into what it actually is:

```
Board                       Library                           (search)
  Set up position             [All] [Mine] [From trainer]
  Import PGN                  ▸ Sicilian: the Najdorf   tutorial · 6 parts   ⋮ (Open in studio · Send · Delete)
  Save position               ▸ Rook ending, 1.Kf2      position              ⋮ (Open · Rename · Delete)
  Paste FEN ______  ⏎         ▸ …
```

„Create tutorial" is gone (S1); the row menu keeps *Open in Tutorial Studio*
(Windows, and Android after S7). The student's *Show my position to trainer*
stays at the top of their column. Preparation's app bar says **Preparation**
and nothing about a room.

### 6.5 The Tutorial Studio on desktop

Unchanged. The redesign of 6–7.9.2026 (parts panel, flow, tree, PGN, the
question card) stays exactly as it is; this plan touches its doors, not its
body.

## 7. Writing a tutorial on the phone — the decision reopened

**Decision 5 of `PLAN-TUTORIJAL.md`** made the studio Windows-only because it
carries a board, a tree, the fields of one node *and* the list of parts, and a
phone is 360–410 dp. The sentence in `tutorial_studio_availability.dart` was
written to be reversed by one line — *„stays a one-line change only while
this predicate has exactly one home"* — and it has exactly one home.

**What is actually platform-bound in the studio: nothing.** The screen and its
services import no `dart:io` except `narration_storage` (a directory path,
`path_provider` works on Android). Recording (`record`), file import
(`file_picker`), playback (`audioplayers`) and the video export (server-side)
all run on Android. The reason was the *layout*, and the screen already has a
narrow branch (board on top, the authoring column under it) that the plan of
6.9.2026 said *„must not be broken, does not have to be good"*.

**What stands in the way is that the screen is the model.** There is no
`TutorialDraftController` class; the controller the studio plan drew in §4 was
never made — the draft, the selected part, the cursor, the orientation, the
history and the marks live in `_TutorialStudioScreenState`, 2693 lines. A
second layout over that state means either a second copy of it (rule 12,
never) or the extraction the plan asked for.

**The solution: one controller, two layouts, one part at a time.**

1. **Extract `TutorialDraftController`** (the class in `PLAN-STUDIO-REDIZAJN.md`
   §4, verbatim where it still fits) from the screen state. The desktop screen
   becomes a layout over it. The gate is the existing studio test set —
   `tutorial_authoring_test`, `tutorial_reopen_test`, `tutorial_ulaz_test`,
   the history tests — green before and after with no test edited, plus new
   controller tests that build a two-part tutorial with a question and assert
   the `positionList` **without pumping a frame**, which is what the seam was
   for.
2. **A phone layout, `TutorialStudioPhoneLayout`**, chosen when
   `!Breakpoints.isWide(context)` on a touch platform, over the same
   controller:

   ```
   Portrait (360 × 640)                 Landscape (640 × 360, height < 480)
   ┌──────────────────────────┐         ┌───────────┬──────────────────────┐
   │ ‹ Tutorial title    Save │         │           │ Line │ Task │ Parts   │
   ├──────────────────────────┤         │           ├──────────────────────┤
   │                          │         │   board   │ 1.e4 e5 2.Nf3 Nc6    │
   │          board           │         │  (whole   │ ──────────────────── │
   │                          │         │  height)  │ Comment on 2.Nf3     │
   ├──────────────────────────┤         │           │ [__________________] │
   │ ◀◀ ◀  1.e4 e5 2.Nf3  ▶ ▶▶│         │ ◀◀ ◀ ▶ ▶▶ │ Draw ▢  ▶ Preview    │
   ├──────────────────────────┤         └───────────┴──────────────────────┘
   │  Line  │  Task  │ Parts  │
   ├──────────────────────────┤
   │ Comment on 2.Nf3         │   Line:  the move strip, the comment field for the
   │ [____________________]   │          cursor's move, the Draw toggle (arrows and
   │ Draw ▢  Flip ⟳           │          squares, the annotation bar already shared
   └──────────────────────────┘          with the room)
                                  Task:  kind (Show / Find the move / Choose the
                                         answer), the task text, the answers
                                  Parts: the list — kind icon, title, moves count;
                                         New part (three kinds), up, down, clone,
                                         delete; tapping a part selects it
   ```

   The Flow and Tree panels are not drawn on the phone; the Tree is reachable
   as the fullscreen dialog Analysis already has, for reading. Undo/Redo,
   Preview, Record narration, Export video, Save as .pgn, Position setup sit
   in the app bar's overflow. The landscape shape is the one the owner
   accepted for every board screen on 16.9.2026 (`LandscapeBoardLayout`).
3. **Retire the two other editors.** `LessonStepEditorPanel` and
   `CreateCourseDialog` are deleted; `tutorial_editor_entry.dart` opens the
   studio everywhere; `isTutorialStudioAvailable` becomes `true` and is then
   deleted with its debug override; the Tutorials card and the Analysis menu
   lose their platform guard.

**What a phone gives up, said plainly:** seeing the whole flow at once, two
panes, keyboard shortcuts, and writing speed. A trainer who writes a
thirty-part tutorial will still do it on Windows. What the phone gets is what
Decision 5 took away: fixing a comment on the bus, adding one part from a
position saved in Preparation, and the same app on both devices.

**The gate, before anyone builds it:** widget tests at `Size(360, 640)` and
`Size(640, 360)` that (a) create a tutorial with two parts, one a question,
through the phone layout and assert the saved `positionList` is byte-equal to
the one the desktop layout produces for the same actions on the same
controller; (b) reach every action in §7.2 by tapping, none by keyboard; (c)
throw on any overflow — a test build does, a release build clips. And the
mutation: remove the phone layout's Save and watch (a) fail.

**Cost, honestly:** the extraction is the largest single item in this plan —
a 2693-line stateful screen with history, drafts and narration threaded
through it. It is lead work (rule: a change where one missed reader corrupts
data — here, a draft — is not delegated cold). The phone layout itself is an
implementer phase against the gate above. The retirement is a deletion batch.

**Recommendation:** yes, reverse Decision 5 — after the foundation and the
tabs, as the last phase, because the extraction is also the one refactor that
makes the studio testable without a frame, which every later studio change
pays for.

## 8. Phases

Each phase has a gate written and proved satisfiable before it is briefed;
the brief names its carrier. The sentence every brief carries: *If you believe
a test in the gate is wrong, stop and say so in the report — do not work
around it.*

| # | Phase | Carrier | Gate |
|---|---|---|---|
| 0 | Decisions (§9) and the strings table; `docs/gates/home_map_test.dart` written for the chosen variant: which labels sit on which tab, which are gone | lead | the gate is red on `master` for the right reason — **done 17.9.2026**: the glossary has the four tabs, the gate has one group per phase (5, 1, 2, 6c) and every group failed on `master` at `bd64f9c` on the first string it names |
| 1 | S2 — *Use in a tutorial* in Analysis; the four buttons and their three `_` methods become one menu over the same three flows; `analysis_studio_screen.dart` class doc corrected | implementer | **done 17.9.2026**, merged `bfeaadb`. The sheet (`teach_menu.dart`, 10 tests) is the lead's; the gate `analysis_teach_door_test.dart` (4 tests, red on master on three) is in `test/` and green; the transfer dialog is gone; the manual's Analysis page names the door. App 2819 → 2831, analyze 26 |
| 2 | S1 (Windows half) + S4 + S5 + names — the room loses *Create tutorial* and *Edit positions*; `CreateCourseDialog` deleted; dead dialogs deleted; Preparation's one door; the strings table applied | implementer | **done 17.9.2026**, merged `6a7ac83`. The phase-2 group of `docs/gates/home_map_test.dart` (4 tests) is green; seven tests went with the deleted editor; the manual's quotes were superseded by the batch that rewrote the pages the same day. Master after it: 2839, 1 skipped, analyze 26 |
| 3 | S3 — `LibraryScreen` and the shared library list used by the room's column | implementer | **3a done 17.9.2026**, merged `2671241`: the server's view gains `tutorial` and `recording` (backend gate 6 tests, 1406 → 1412); `LibraryList` (gate 9 tests) and `LibraryScreen` at `/library`, the door on the Library tab, the tutorial row's five actions lifted into `TutorialRowActions`; a saved analysis opens whole through the Analysis screen's new `initialTree` (`8c3d418`). **3b done 17.9.2026 (lead, Fable)**: the room's left column draws `LibraryList` narrowed to All · Tutorials · Positions, with Mine / From trainer and the label panel — both now the widget's own (`originChips`, `labels`), so the Library screen filters by labels too, as the manual had promised; the column reads `GET /library/positions` like the Library does and fetches a row (`LessonApiService.fetchRow`) only when an action needs its parts or description; the tutorial shelf carries its tags (backend gate); the row actions stay as they were (Edit tutorial · Rename · Save as new version · Delete; Edit · Delete), and a trainer's rows have none. `test/room_library_test.dart` reads the screen and drives the column. Master after 3a: 2859, 1 skipped, analyze 26 |
| 4 | S6 — the panel to Sessions; People trimmed; manual pages 1, 2, 5, 6, 7, 8 rewritten (this is **Variant A complete**) | implementer (code), lead (manual) | **Folded into 5, 17.9.2026.** With Variant B chosen and the manual already rewritten to it (batch `prirucnik-b`), moving the panel to Sessions and then to Home would have been the same move twice; the panel went straight to Home in phase 5 |
| 5 | Variant B — the shell: `Home`, `Teach`, `Analyse`, five destinations, shortcuts, back history, landscape at four phone sizes; manual pages 0 and 1 | lead (shell), implementer (tabs' bodies) | **done 17.9.2026 (lead, Fable).** Four destinations — Home · Practise · Analyse · Teach — with People folded into Teach (students, groups, requests) and Home (the panel, what is set for me, join by code). `HomeDashboardTab` is Home (resume strip, the panel, „Set for me", „Due for review", „Join a session", recordings — the student's blocks only for someone with a trainer or a review due); `TeachTab` (Preparation, New session, Library, the students card); `AnalyseTab` mounts the Analysis screen as the tab's body, built on first visit, with „My games" and „Scan a book" above it and no second header; the old Library tab deleted. `docs/gates/home_map_test.dart` moved into `test/` green (its 6c group stays as `docs/gates/one_editor_test.dart`); the two `map_b_*` files and the manual test's allowance are gone; the four landscape sizes re-measured by `home_landscape_test` |
| 6a | §7.1 — `TutorialDraftController` extracted | lead | the studio's existing tests unchanged and green; controller tests without a frame |
| 6b | §7.2 — the phone layout | implementer | the gate in §7 |
| 6c | §7.3 — retirement of the two editors and the platform guard; the Android door in the room and the Tutorials card | implementer | `LessonStepEditorPanel`, `CreateCourseDialog`, `isTutorialStudioAvailable` absent from `lib/`; `tutorial_ulaz_test` on both platform answers |
| 7 | Live pass, one `TODO-provera` item per phase, on Windows and on a phone | owner | ticked by the owner |

Phases 1, 2 and 3 are independent of each other and can run as three
worktrees; 4 needs 2; 5 needs 4; 6a needs nothing and can start any time.

**Who carries what, by model — the owner's request of 17.9.2026.** The split
follows the global rule (lead Opus, worker Sonnet, escalation Fable, sweeps
Gemini) with two deliberate exceptions, both because the work is the shape
Fable is kept for.

| Model | Carries | Why |
|---|---|---|
| **Fable 5.1** (this session) | Phase 0 (done); **6a**, the controller extraction — one stateful screen of 2693 lines with history, drafts and narration threaded through it, where one missed reader corrupts a draft; grading of 6b | The multi-layer refactor is the escalation shape; everything else is cheaper elsewhere |
| **Opus 5** (the lead session for phases 1–5) | Briefs and gates for 1–4; phase 5, the shell (`home_screen.dart`, five destinations, shortcuts, back history, landscape re-measured); every merge; the manual's pages 0–1 | Lead work that does not need Fable's price. The owner switches this session's model after phase 0 |
| **Sonnet 5** — `implementer` | Phases 1, 2, 3 in three worktrees; 4's code; the bodies of the new tabs in 5; 6b and 6c; `PLAN-NAPREDAK-VEZBI` phases 1 and 2 | Bounded work against a gate that already exists |
| **Sonnet 5** — `verifier` | The three counts before every merge | Numbers are re-derived, never trusted from a report |
| **Gemini** (`agy`, `gemini-3.8-flash-high`) | The strings batch of §4's table (mechanical, ~12 files, graded by the gate's phase-2 group and the vocabulary anchors); the manual's pages 2–8 rewritten to the new map (words only, graded by `manual_labels_test` and the new `manual_places_test`) | Volume with a machine gate, where Max quota is better saved. Ask the owner for the quota reading before launching; about a third of the 5-hour quota per batch |
| **Haiku 4.5** | Lookups while briefing: „every caller of X" | An answer that is a location, not a judgement |

Order on the calendar: Gemini's strings batch runs first inside phase 2 (the
implementer then deletes the dialogs against a tree whose names are already
right); phases 1 and 3 run beside it; 6a starts on Fable as soon as phase 0 is
merged, in its own worktree, because it touches nothing the other phases do.

**What each phase does to the numbers.** Baseline on `master` 16.9.2026:
2819 app tests (1 skipped), 26 analyze infos in five named files, 1376 backend
tests. Phase 2 and 6c *reduce* the count (deleted dialogs take their tests
with them) — a drop there is expected and is written into the brief with the
list of tests that go, so the rule „a lower number means find out why" has
its answer ready.

## 9. Questions for the owner — answered 17.9.2026

The owner accepted the proposal the next morning. The answers, verbatim in
substance, are the decisions this plan is now built against:

1. **Variant B**, built as A first (phases 1–4, then 5).
2. **The phone studio: yes.** Decision 5 of `PLAN-TUTORIJAL.md` is reversed:
   the controller is extracted (6a), the phone layout *Line | Task | Parts*
   is built (6b), and the two old editors are deleted (6c).
3. **Tab names: Home · Practise · Analyse · Teach.** `docs/GLOSSARY-EN.md`
   gains a row per tab in phase 0.
4. **People goes** as a separate tab; its rows go to Teach (students, groups,
   requests) and Home (the student's side).
5. **The Analysis board is the body of the Analyse tab** (6.3 as drawn).

What the answers change in §8: nothing in the order; phase 5's gate names
four destinations and Ctrl+1…4; phase 6 is confirmed rather than optional.

## 10. What this plan does not do

- It does not touch `chess_backend/`. Every list it joins is already fetched.
- It does not merge the room, Preparation and Analysis into one board screen
  (`PLAN-ZAVRSNICA.md` 1b: different work, built for different work).
- It does not merge the drills (F9's twin hub is deleted, not the drills).
- It does not add drag-and-drop to the parts list, on the phone or off it.
- It does not change a route path in `app_routes.dart` — deep links are a
  contract. New tabs are indices, not paths.
- It does not rename a column, a wire field or a Dart identifier — `lesson`
  still means the tutorial in code, as the glossary records.
- It does not decide the audience or consent questions; a student's Home is
  what the data makes it, and nothing here reads `users.role`.
