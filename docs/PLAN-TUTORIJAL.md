# Plan: the interactive tutorial

Written 6.9.2026, before any of it is built. It supersedes nothing: it is the
next layer on `PLAN-INTERAKTIVNA-LEKCIJA.md`, whose phases 0–7 are merged and
whose step model this plan keeps unchanged.

The vision, in the owner's terms: a trainer builds a **tutorial** — a series of
worked examples on one theme — in one continuous authoring session, on a screen
built for writing rather than for analysing; a child reads it as one continuous flow on one board, hears
the line explained a move at a time, may step off into the sidelines the trainer
prepared, and is asked to play the answer on the same board the demonstration
arrived at.

Four things are asked for. They are not equally hard, and they do not depend on
each other in the order they were asked.

| | ask | where it lands |
|---|---|---|
| R1 | „Lekcija" becomes „Tutorijal" | user-facing strings, app-wide |
| R2 | one unbroken flow, show → ask, no reset | `LessonViewerScreen` — **built 6.9.2026** |
| R3 | the student explores sidelines | `LessonViewerScreen` navigation |
| R4 | continuous authoring, „+ Dodaj sledeću poziciju" | a new `TutorialStudioScreen` |
| R5 | Uredi / Preimenuj / Sačuvaj kao novu verziju | backend + library UI |

## What already exists — do not rebuild it

Read this section before writing any brief. Most of the pedagogical model asked
for is already in the tree, and the expensive mistake here is a worker
reimplementing it beside itself.

* **A step already carries a whole line.** `pgn` per step, read by
  `LessonStepLine.read` — one parser, comments, `[%cal]`, `[%csl]`, and a count
  of moves that did not replay. Variations are **parsed and kept in the tree**
  today; only `mainLine()` throws them away. R3 is therefore a navigation
  change, not a format change.
* **The narrated walk exists** (6.9.2026): the move is played when the sentence
  in front of it has been read out — `SpeechService.speak` completes on
  `awaitSpeakCompletion`, with a watchdog. Speech off means no autoplay and no
  timer; the child steps.
* **The show → ask join exists** (6.9.2026): a step whose position equals the
  one on the board does not reload the board and does not recompute the
  orientation, and a narrated walk crosses the join by itself and reads the
  question. R2 is **done in code, unverified live** (`TODO-provera.md` 27–29).
* **The trainer's step editor exists** — `LessonStepEditorPanel`: pick a step,
  edit the sentence, the kind (`show` / `ask_move` / `ask_choice`), the choices,
  and play the correct move on a board. It cannot yet add, remove or reorder
  steps, and it cannot edit the line itself.
* **The backend is built and frozen for everything except R5.**
  `POST /lessons/save`, `PUT /lessons/:id` (with the two guards: a request that
  says nothing about steps leaves them alone; a list that lost its ids is
  refused with 409), `POST /lessons/:id/steps` (server-side append),
  `DELETE /lessons/:id`, `GET /lessons`, `GET /lessons/labels`.
* **A branch-aware cursor already exists** — `MoveTreeCursor` in
  `lib/core/models/move_cursor.dart`, with `forwardBranches` and `takeBranch`,
  and `MoveNavigationControls` already asks the branch sheet at a fork. R3 is a
  swap, not an invention.

Baselines to quote in every brief: **1372 app tests, 1 skipped; 945 backend
tests; `flutter analyze` reports 29 infos and no errors or warnings.**

## Decisions — all approved by the owner, 6.9.2026

Approved exactly as recommended. They are frozen; a batch does not reopen one.

1. **Does „Tutorijal" replace the word everywhere, or only for the authored
   artefact?** There are two different things called „lekcija" today: the thing
   a trainer writes and assigns, and the **live lesson in a room** with a
   trainer and a child. My recommendation: the artefact becomes „Tutorijal",
   the live session stays „čas". Renaming both leaves the child unable to tell
   „otvori tutorijal" from „uđi u čas".
2. **Does a clone get fresh step ids?** My recommendation: **yes**. A step id is
   the identity of a step, and two tutorials sharing one is the kind of
   ambiguity this codebase pays for a year later. It costs nothing: the new
   tutorial has no progress rows yet.
3. **Does the authoring flow save at the end, or as it goes?** My
   recommendation: **at the end, in one `POST /lessons/save`**, with the draft
   held in memory and persisted locally the way `AnalysisDraftService` already
   persists the working tree. Saving as it goes needs no new endpoint either
   (`POST /:id/steps` exists), but it leaves half-written tutorials in the
   library, which is what the owner asked to avoid — „u jednom dahu ... pre
   konačnog čuvanja".
4. **Does authoring get its own screen?** The owner raised it, and the numbers
   say yes: `analysis_studio_screen.dart` is **2383 lines with twelve toolbar
   actions**, an engine panel, an opening explorer, a tablebase panel and two
   findings panels. That is a room for *analysing*, and a trainer writing a
   tutorial has to ignore nine of the twelve things in it while carrying a
   running list of examples that has nowhere to sit.
   My recommendation: **a new screen, `TutorialStudioScreen`**, with one entry
   point from the Studio that hands over the position or the whole tree, so a
   line worked out with the engine becomes a tutorial without being retyped.
   See phase 4.
5. **The authoring screen is Windows-only, for now.** Raised by the owner when
   confirming decision 4: a screen carrying a board, a move tree, the fields for
   one node **and** a running list of examples is a desktop screen, and Android
   is 360–410 dp. So `TutorialStudioScreen` is gated behind one named predicate
   — `!kIsWeb && Platform.isWindows`, the shape `engine_settings_dialog.dart`
   already uses — and the Studio's door to it is simply not drawn on Android.
   Nothing else changes on Android, and **nothing is removed from it in this
   plan**: which other parts of the app stop making sense on a phone is a
   separate decision the owner will take later, with the screen in front of
   them. The predicate gets one home so that decision is a one-line change.

   *A child's screens are not affected.* Reading a tutorial is
   `LessonViewerScreen`, which is a board and a strip, and it stays on both.

## Frozen contracts (lead)

Written before any batch starts, and not changed while one is running.

### C1. The vocabulary table

A frozen table, one row per occurrence, in `docs/TABELA-TUTORIJAL.md`: the file,
the current string, the replacement, and — for every occurrence that is **not**
renamed — the reason. 64 occurrences of `ekcij` across 22 files in
`chess_app/lib`, of which some are the live session and some are identifiers and
comments. The table is the contract; the worker does not decide.

Precedent: `TABELA-RECNIK-2026-09.md`, which worked exactly because the
judgement happened before the batch rather than inside it.

### C2. What the viewer holds (R3)

`LessonViewerScreen` stops holding five parallel lists indexed by ply, and holds
the tree and a node:

```dart
MoveTree? _tree;      // from LessonStepLine, null when the step is one position
MoveNode  _node;      // where the child is standing; _tree.root at the start
```

Everything the screen draws is read off `_node`: `_node.comment`,
`_node.arrows`, `_node.squares`, `_node.fen`. The root's comment is the note
about the starting position, which is what it already is. `MoveTreeCursor`
replaces `LinearMoveCursor`; the branch sheet the strip already owns is what
makes a sideline reachable.

`LessonStepLine` grows one field — `MoveTree? tree` — beside the `PgnLine` it
already returns. `replays` and `rejectedMoves` keep their meaning, and the
studio's save-time check is untouched.

**Three rules that fall out of it, and each gets a gate test:**

* **A narrated walk stops at a fork and asks.** It does not take the first
  child. Taking the main line silently is precisely the fault the branch sheet
  was written for in the repertoire.
* **The join fires only from the end of the main line.** A child standing in a
  sideline never auto-advances into the next step — they came off the path on
  purpose.
* **A step with no branches behaves exactly as it does today.** `forwardBranches`
  is empty, no sheet appears, and every existing viewer test stays green
  unchanged. If a test has to be edited to pass, that is a finding, not a
  chore.

### C3. `POST /lessons/:id/clone` (R5)

Lead-owned, landed and frozen **before** the UI batch that consumes it.

```
POST /lessons/:id/clone   { title? }
 201 { ...the new row }
 400 { error }   unparseable id
 404 { error }   not found, or not yours (same permission as PUT: user_id OR trainer_id)
 500 { error }
```

Copies title (or `title` from the body, else `"<title> (kopija)"`), description,
tags, fen, pgn and every step. **Mints a fresh id for every step** — see
decision 2. Never copies assignments, schedules or answers.

`LessonApiService` gains exactly one method against it:
`Future<int?> clone({required int id, String? title})`.

### C4. The authoring draft (R4)

Held by `TutorialStudioScreen` (decision 4), not by the Analysis Studio.

```dart
class TutorialDraft {
  String title;
  List<TutorialExample> examples;   // Primer 1, Primer 2, …
}
class TutorialExample {   // exactly one lesson step, as the backend already takes it
  String fen; String pgn; String title; String? instruction;
  LessonStepKind kind; List<String> choices; String? solutionSan;
}
```

The draft is client-side and is saved in one `POST /lessons/save` with
`positionList` built from `examples`. **No new backend for R4.** The step shape
is the one `services/lessonSteps.js` already validates — the brief quotes it
rather than restating it.

**One field was added to C4 on 6.9.2026, by the lead, before batch E started:
`int? correctChoice`.** The list above froze `List<String> choices`, which is
right for the *student's* model — the answer never travels to the child — but
the author has to say which answer is the right one, and the server takes
`[{text, correct}]` with exactly one `correct: true`. Without it an `ask_choice`
example cannot be saved at all. Written down here rather than discovered inside
a batch, which is the only reason a contract is frozen in the first place.

## Phases

| # | what | owner | needs |
|---|---|---|---|
| 0 | contracts C1–C4, gates, the clone endpoint | lead | **done 6.9.2026** |
| 1 | vocabulary: „Lekcija" → „Tutorijal" | **worker** batch A | **done 6.9.2026** |
| 2 | tree navigation in the viewer | **worker** batch B | **done 6.9.2026** |
| 3a | `POST /lessons/:id/clone` + `LessonApiService.clone` | **lead** | decision 2 |
| 3b | Uredi / Preimenuj / Sačuvaj kao novu verziju | **worker** batch C | **done 6.9.2026** |
| 4a | `TutorialStudioScreen`: board, tree, handover from the Studio, draft model | **lead** | **done 6.9.2026** |
| 4b | per-node fields, „+ Dodaj sledeću poziciju", the running list, one save | **worker** batch 54 | **done 6.9.2026** |
| 4c | the step editor gains add / remove / reorder | **worker** batch F | gate written 6.9.2026 |
| 5 | live check with the owner | lead + owner | all |

**The vocabulary goes first on purpose.** Everything phases 3b–4c adds is new
user-facing text, and a sweep that runs after them has to chase strings that
were written in the old word by a worker who was told the old word. This is the
same lesson the last vocabulary sweep paid for.

## What phase 0 delivered, 6.9.2026

Everything below is on `master`'s working tree, and the two gates have been run
against the current code to prove they fail for the right reasons.

* **`docs/TABELA-TUTORIJAL.md`** — the frozen vocabulary, five tables: ~50 rows
  to „Tutorijal", three to „Čas", the do-not-touch list with a reason each, and
  the twelve backend strings.
* **The backend half is applied** (Table D). Twelve user-facing strings on the
  server now say „tutorijal", so the app and the server cannot disagree in front
  of a child. `npm test` with `.env` moved aside: **956 passing**.
* **`POST /lessons/:id/clone`** — written, tested, frozen. Copies everything,
  **mints a fresh id for every step** by stripping ids and running the list back
  through `buildLessonSteps`, never writes to the source row, and shortens a
  long title so the `VARCHAR(255)` column cannot overflow into a 500. Eleven
  tests, and the two that matter proved by mutation: copy the ids instead of
  minting them, and the id test goes red; drop the title shortening, and the
  overflow test goes red.
* **`LessonApiService.clone`** — the app-side contract batch C builds against.
* **Two gate files**, written before the batches they judge:
  * `docs/gates/tutorial_vocabulary_test.dart` — run against the current tree,
    it is red in the two ways it should be (50 leftover strings, every
    replacement missing) and green on the two that must stay green (nothing
    renamed outside the table, no wrong gender agreement yet to find).
  * `docs/gates/tutorial_branching_test.dart` — run against the current tree,
    **one of six passes**, and it is the right one: „a step with no branches
    never shows the sheet". The other five describe behaviour that does not
    exist yet.
* **Three briefs**, ready to hand out: `TASK-tutorijal-recnik.md`,
  `TASK-tutorijal-stablo.md`, `TASK-tutorijal-verzije.md`, each with its
  `brief-*-2026-09.md`.

**Order they go out in.** Batch A runs **alone**: it touches twenty files, and
every other batch touches at least one of them. B and C can then run in
parallel — B is the viewer and the step-line model, C is the trainer's list and
dialogs, and they do not meet.

### Phase 1 — vocabulary (worker batch A) — done 6.9.2026

Merged as batch 51. The gate passed all five tests and moved into
`chess_app/test/tutorial_vocabulary_test.dart`, where it stays. 18 files, 60
changed lines, measured by the lead rather than read from the report — which had
undercounted one file and was right about the work.

**The harness's own gates said FAIL, and all three findings were wrong.** Its
`strings` gate reported the string changes the task demanded (its header had
already said there were no allowances for this task); its `contrast` finding at
`dashboard_tab.dart:64` predates the batch, since that file's only change is one
string on a different line; and its `worktree` failure was the report file the
task told the worker to write. Worth keeping as the sharpest example yet of the
rule that a gate needs allowances for the work its own brief demanded — and of
why the verdict is the gate written *for this batch*, not the generic one.



*Scope:* user-facing Serbian strings in `chess_app/lib` only, exactly as C1's
table dictates.

*Explicitly not:* API field names, `saved_lessons` and its columns,
`position_list`, route paths, class names, file names, `chess_backend/` at all.
Renaming an identifier is not this batch and is not free — it is a diff nobody
can review beside a string change.

*Gate (lead):* a scanner over `lib/`, run against the worktree, that
(a) fails on any user-facing string containing a forbidden form, (b) fails if a
row of the table was not applied, (c) fails if a file outside the table changed,
(d) `flutter test` count is not lower than 1372, (e) `flutter analyze` list
unchanged. Proved by mutation before it is believed: revert one row, watch it go
red.

### Phase 2 — tree navigation (worker batch B) — done 6.9.2026

Merged as batch 52. All six gate tests green, and the real condition held: the
five existing viewer and narration files pass **unedited**. Two files changed,
63 lines added and 107 removed — a net simplification, which is what replacing
five parallel lists with a tree and a node should look like.

Lead fixes while grading, both of the same kind: the batch left „Potez N od M"
being recomputed inside `build` under three comments written as thinking aloud,
including its own word „approximation" for a number a child reads. Extracted to
`_lineProgress` with a name and the reasoning — on a branching step the
denominator is the length of *the line you are on*, and there is no single
number of moves in a tree. It had also reported `dart format` as run when it
was not.

Its two corrections were both right, and one was about this plan: the brief
quoted 1372 tests, and the commit it was given had 1377 because batch A had
merged in between. It measured rather than quoted, which is exactly what the
task file asks for.



*Scope:* `LessonViewerScreen` and `LessonStepLine` only. Swap the cursor, read
everything off the node, keep the narrated walk and the join working.

*Gate (lead), written before the batch:*

1. a step whose pgn has a sideline: the sheet appears at the fork, choosing the
   second reply puts **that** move on the board with **its** comment and **its**
   arrows;
2. a narrated walk **stops** at the fork instead of choosing;
3. the join still fires from the end of the main line, and **not** from a
   sideline;
4. every test in `lesson_viewer_line_test.dart`, `lesson_narration_test.dart`,
   `lesson_step_narration_test.dart`, `lesson_board_playable_test.dart` and
   `lesson_step_asks_test.dart` passes **unedited**.

Point 4 is the real gate. The others can be satisfied by a rewrite that breaks
the flow; only that one says the flow survived.

### Phase 3 — versions

*3a is mine.* An endpoint, its tests, and the `.env`-moved-aside run that is the
only honest check that CI can load them — the failure mode from 5.9.2026.
Cloning is a write, and writes stay with the lead.

**Done 6.9.2026, merged as batch 53 — and it taught the method something.**
This was the one batch launched **without a lead-written gate**; the plan said
five things would be checked by hand instead. What happened is that the worker
wrote its own test and graded itself with it, and that test had a „sanity check"
with no assertions in it and muted `FlutterError.onError` for every RenderFlex
message — which made it green over a **real** 91 px overflow in the filter
panel's title, the kind a release build clips in silence. Rewritten by the lead;
the overflow fixed in `matrix_filter_panel.dart`, where it had been all along.

**The rule, and it is not a footnote: a batch with no gate written for it grades
itself.** Every batch from D onward gets its gate written first, without
exception.

Other lead fixes: a `String? dummy` parameter left in `fetchLessons`; the test
seam renamed from `overriddenLessonApi` to `lessonApi` and explained; a menu
item restored, because the new menu had replaced the only route to the dialog
that edits which positions a tutorial is made of — unreachable until batch F
without it; and one new analyzer info, an unbraced `if`, which the „no new
infos" rule catches only if somebody compares the list.

*3b is a worker batch:* three actions on a tutorial in the library — Uredi
(opens `LessonStepEditorPanel`, which already exists), Preimenuj (PUT with no
`positionList`, which the backend already protects), Sačuvaj kao novu verziju
(the frozen clone endpoint, then open the copy). Gate: a rename does not touch
the steps (there is already a backend test for that shape —
`lesson_rename_keeps_steps.test.js` — and the app side needs its own).

### Phase 4 — the authoring flow, on a screen of its own

The largest batch, and the one most likely to need splitting.

**A new screen, not a twelfth toolbar action.** The Analysis Studio is 2383
lines and twelve actions of *analysis* — engine, explorer, tablebase, motifs,
game review — and every one of them is noise to a trainer writing a tutorial.
More concretely: the authoring flow needs a **running list of examples** on
screen at all times, and there is no room for it in a layout already carrying
a board, a move tree and an engine panel.

`TutorialStudioScreen` holds four things and nothing else:

1. the board, with drawing on (`ChessBoardWithOverlay`,
   `BoardWithCoordinates`);
2. the move tree of the example being written (`MoveTreeWidget`,
   `AnalysisNodeCursor`, `MoveNavigationControls`);
3. the fields for the node the trainer is standing on — the sentence, the kind,
   the question, the choices; the same four `LessonStepEditorPanel` already
   edits;
4. the running list: Primer 1, Primer 2, …, with „+ Dodaj sledeću poziciju u
   tutorijal" under it, and one „Sačuvaj tutorijal" at the end.

**It reuses, it does not fork.** The model stays `AnalysisNode`; the board, the
tree widget, the navigation strip, `BoardSetupDialog` and `StudioLessonStep`
are the existing ones. A copy of any of that plumbing in the new screen is a
finding, not a detail — two models of one tree is the fault this codebase has
already paid for twice (`AnalysisNode` versus `MoveTree` arrows, and the two
PGN parsers).

**The Studio keeps one door to it**: „Kreiraj interaktivni tutorijal" hands over
the current position — or the whole tree — so a line worked out with the engine
becomes a tutorial without being retyped. That replaces neither „Napravi korak
od ove pozicije" nor „Uredi korake lekcije"; those stay for adding one position
to something that already exists.

What must hold:

* the trainer never leaves the screen mid-flow, and never goes back to the
  library;
* a start position comes from three places — a FEN typed in, the board editor
  (`BoardSetupDialog`, which exists), or the position handed over from the
  Studio;
* „+ Dodaj sledeću poziciju u tutorijal" adds Primer N to the running draft and
  puts the board on the new start position, **without saving anything**;
* the draft survives leaving the screen, the way the analysis tree already does
  through `AnalysisDraftService`;
* one save at the end writes the whole tutorial.

*Split:* **4a** the screen shell — board, tree, navigation, the handover from
the Studio, the draft model, nothing saved yet. **4b** the per-node fields and
the running list, plus the single save. Two batches, because a screen that both
appears and saves in one batch is a diff nobody can grade in an afternoon.

*Gate:* a widget test that builds a two-example tutorial end to end without ever
calling `save`, then asserts the single `POST` body — every example present, in
order, with its pgn and its question. Plus: `StudioLessonStep.from` still owns
the fen/pgn pairing, so every example replays from its own position — that check
exists and must be reused, not reimplemented. Plus a diff check: no board,
tree-widget or cursor code copied into the new screen.

#### 4a — done by the lead, 6.9.2026

**The split of labour changed here, and the owner asked for the change.** The
plan had 4a as worker batch D; the owner's instruction on 6.9.2026 was „write
the gate for batch D and set up the shell for `TutorialStudioScreen`", which is
the recommendation from the handoff note: a new screen described in prose is the
kind of batch that most often comes back the wrong shape, so **the lead builds
the shell and the worker gets the fields and the running list**. Batch D is
therefore retired as a worker batch and what was 4b becomes the next one.

What landed: `lib/features/tutorial_studio/` — the screen, `TutorialDraft` and
`TutorialExample`, `TutorialHandover`, `TutorialDraftService`, and the
availability predicate; plus the Studio's door and one shared primitive
(below). Thirteen tests in `test/tutorial_studio_test.dart`, written first and
proved by seven mutations. 1400 in the app, `flutter analyze` still 29 infos and
no errors or warnings.

Three things it decided that the plan had left open, each with a reason:

* **A handover wins over the stored working tree, but the examples already
  written come back either way.** That is the flow the door is for: work the
  next example out in the Studio, hand it over, carry on with the same tutorial.
  Discarding the list because a new position arrived would throw away the most
  expensive thing on the screen.
* **The draft is persisted as the tree, not as the PGN.** `TutorialExample`
  holds `pgn`, and reading a PGN back into an `AnalysisNode` would be a second
  importer beside the Studio's — exactly the fork this plan forbids. The stored
  draft therefore carries `workingTree` as node JSON beside the examples.
* **`onPgnLoaded` is not wired on the setup dialog.** A line brought in from a
  PGN arrives through the door as a whole tree; the alternative was copying the
  Studio's private `_importPgn`.

One shared primitive was added rather than a sixth copy of a private helper:
`playedMove` in `lib/core/services/legal_moves.dart` — what a move is called and
where it leaves the board, in one call. The same fifteen lines are written five
times in `lib/` today as a private `_sanFor`, and every copy answers only half
the question, so its caller keeps a second game object beside it. **Folding
those five onto it is a standalone chore**, deliberately not done inside this
work.

*Still open on the screen, for 4b or later:* a committed example is flattened to
`fen` + `pgn`, so re-opening Primer 1 to edit its tree needs the PGN importer
that does not exist yet. Adding an example does not need it; editing one back
does. Say so in batch E's brief rather than letting it be discovered.

#### 4b — done 6.9.2026, as batch 54

`gemini-3.1-pro-high` through `agy`, one round, 10.5 minutes, gate 11/11 and
phase 4a's 13 green and untouched. Merged as `4817285`. Four mutations by the
lead confirm the gate measures the work rather than passing beside it.

Three lessons, and the first is about the harness rather than the worker:

1. **Fill the allowances before launching.** Batches 51–53 each came back
   `VERDICT: FAIL` with nothing wrong, partly because the harness's report
   pattern is anchored lower-case and this project's reports are `REPORT-...`.
   With an entry naming the three files this batch was asked to create, the run
   graded clean on the first round.
2. **„No new infos" needs a second half: nothing new suppressed.** This batch
   held the count at 29 with a file-level `ignore_for_file: deprecated_member_use`
   over three real deprecations, and its report called that adequately resolved.
   The lead replaced it with `RadioGroup<int>` — the shape the brief actually
   named.
3. **The half that works can make the other half invisible.** The tutorial's
   title reached the controller and never the draft, so it alone did not survive
   a reopen while every example did.

The batch's own correction was the most valuable thing in its report:
`PgnExporterService` always writes headers, so `pgn` is never the empty string
and an example with no moves must carry `''` explicitly. The gate had assumed
otherwise.

*Still open for a later batch:* an `ask_choice` example with fewer than two
answers is refused by the server rather than in the app — the sentence is good
and arrives late, which is the same class this batch fixed for the other two
cases.

#### The gate as it was written, before the batch

Unchanged in substance: the per-node fields, the running list with „+ Dodaj
sledeću poziciju u tutorijal", and the one `POST /lessons/save`. They go in
`_authoringColumn`, which exists and says so.

**The gate is written and lives in `docs/gates/tutorial_authoring_test.dart`**
(6.9.2026), where the vocabulary and branching gates lived until the batches
they judge landed — a gate naming controls nobody has built does not compile,
and a suite that does not compile says nothing about anything else. It moves to
`chess_app/test/tutorial_authoring_test.dart` in the merge commit. Its header
carries the full frozen control list; the brief points at it rather than
restating it.

Writing it settled four things the plan had left to be guessed. The first three
are ordinary; **the fourth is a real change and the owner may overrule it.**

1. **The sentence is per node; the task, the kind, the offered answers and the
   answer are per example.** „The fields for the node the trainer is standing
   on" reads as if all four were per node, and they are not — a step is what
   the server stores, and a kind on every node is a second model of a step.
2. **„+ Dodaj sledeću poziciju" starts the next example on the position the
   last line ended at**, i.e. the end of the main line. That is precisely the
   position the child's screen joins on, so show → ask happens on one board
   with no reset. The board editor is still there for going elsewhere.
3. **Three things are refused before anything is sent**, each in its own
   sentence: a tutorial with no name, an `ask_move` example that carries a
   line, and an `ask_choice` example with no answer marked correct. The server
   refuses all three correctly; a refusal that arrives after the trainer
   believed they were finished is the expensive way to learn it.
4. **An `ask_move` example carries no line, and its answer is played on the
   same board — recorded, with the board going back to the position.** This
   came out of the server rather than out of taste:
   `redactStepForStudent` takes out `solutionSan`, `acceptedSans` and the
   `correct` flags, and **leaves `pgn` alone**, because the line *is* the
   lesson; `lesson_viewer_screen.dart` then reads that line for every kind. So
   a question whose line begins with the answer prints the answer under the
   question. The interaction is the one `LessonStepEditorPanel` already has, on
   the board that is already there rather than on a second one, and the
   demonstration belongs to the example *before* the question — which is the
   show → ask pattern phase 7 built anyway. `ask_choice` is not restricted:
   its answers are text and its `correct` flags are redacted.

*Still open, and it goes in the brief:* a committed example is flattened to
`fen` + `pgn`, so re-opening Primer 1 to edit its **tree** needs a PGN importer
that does not exist. Adding an example does not need one; editing a committed
one does. Batch E adds examples — it does not have to reopen them — but it must
not pretend it can.

### Phase 4c — add, remove, reorder; gate written 6.9.2026

`docs/gates/lesson_step_order_test.dart`, twelve tests, **all twelve red on the
current panel** — measured, not assumed. It compiles against today's tree, so
the batch's work is the only thing between it and green.

**This is the most dangerous batch in the plan, and not because it is hard.**
A step's `id` is its identity: `assignment_items.step_key` and
`review_items.step_key` name steps by it and nothing joins on it, so an id that
changes orphans a child's schedule and their recorded answers with no error
anywhere. `PUT /lessons/:id` guards against exactly that with a 409 — **and the
guard cannot fire for this batch**, because it requires
`storedList.length === steps.length` and both adding and removing change the
length. For two of the three operations, the gate is the only thing there.

Checked rather than assumed while writing it: the child's side already survives
a removal. `getDue` resolves a review row through `stepByKey` and ends with
`.filter((item) => item.step !== null)`, so a row naming a deleted step stops
appearing rather than serving a board nobody wrote. **No backend work is needed
for 4c, and the task forbids any.**

Four decisions the gate freezes, with reasons:

1. **Up and down, not drag.** `ReorderableListView` is prettier and is what a
   trainer with twelve steps would want; it is also the gesture that is hard to
   drive in a test and easy to get subtly wrong. This batch is the mechanical
   one — it is the clean comparison for `gemini-3.8-flash-high` — so it gets
   the unambiguous control. Drag is a later, separate decision.
2. **The panel gains a title field.** It edits the instruction, the kind, the
   choices and the answer, and not the name, so three added steps would all
   reach the server as „Pozicija" — what `buildLessonStep` writes when a title
   is missing — and the trainer could not tell them apart in the very list this
   batch is about.
3. **A new step carries no `id`** and inherits only the position it was added
   from. The position is deliberate (it is what makes „show, then ask" one
   board); the question is not.
4. **The last step cannot be removed.** `PUT` writes `position_list = NULL` for
   an empty list, so a tutorial emptied here loses its steps with nothing left
   to join on and complain.

Two files must stay green **unchanged**: `test/lesson_editor_test.dart` and
`test/lesson_answer_stays_hidden_test.dart`. If either has to be edited, that is
a finding.

## Role split

**Lead (me).** Everything irreversible and everything that decides shape:

* the four contracts above, and the vocabulary table, before any batch;
* the backend half in full — the clone endpoint, its tests, the `.env`-aside
  run. **No worker touches `chess_backend/`**, and every task file says so;
* the gate tests, written **before** the batch they judge, and each one proved
  by mutation before it is trusted;
* running the gates against the worktree, reading the diff, and merging;
* the docs: `STANJE-RADA.md`, `TODO-provera.md`, `CLAUDE.md` counts.

**Worker (via `TASK-*.md` + `brief-*-2026-09.md`).** Bounded implementation
against a frozen contract, in its own worktree (`mislisha-batch-a|b|c`), on its
own branch, **never committing**:

* batch A — the vocabulary sweep;
* batch B — the cursor swap in the viewer;
* batch C — the three version actions in the library UI;
* ~~batch D — `TutorialStudioScreen`, the shell~~ — **retired 6.9.2026**; the
  owner asked the lead to build the shell, see phase 4a;
* batch E — the authoring fields, the running list and the save;
* batch F — add / remove / reorder in the step editor.

**Which model.** Batches A and B ran `gemini-3.1-pro-high` and both failed the
same way: the architecture was sound and the *literal steps* were not. B
reported `dart format` as run when it had not been, left three comments written
as thinking aloud in shipped code, and put its own word „approximation" in a
string a child reads; A undercounted a file in its report. None of that is
capability. The owner's suggestion on 6.9.2026 — try `gemini-3.8-flash-high`,
which follows a task more literally — is aimed at exactly that, so:

* **the next mechanical batch runs on `gemini-3.8-flash-high`** — batch F (add,
  remove and reorder in the step editor) is the clean comparison, because its
  brief is mostly steps;
* the new-screen batch is no longer a batch — the lead built 4a. **Batch E
  stays on a high-reasoning model**: it is asked to lay out fields and a list
  beside a tree, not to follow steps;
* and the comparison is on named things, not impressions: did it run
  `dart format`, did its report's numbers match the lead's own, and did it ship
  a comment written to itself.

Every task file opens the same way: *this file plus the brief are the only
context you get*; the baseline numbers to measure **itself**, not to quote; what
is out of scope; and *if a named file is missing, stop and say so* — a worker
that cannot find a file substitutes the nearest plausible one and reports
success.

**The report is never the verdict.** Every batch is graded by exit code: the
test count the worker measured before and after, the analyzer list compared
rather than counted, the scanner's output, and the diff.

## Out of scope, said once so it is not rediscovered

* Renaming database columns, API fields or Dart identifiers. The word changes
  for the reader, not for the schema.
* Group lessons. Refused by the owner on 6.9.2026 and still refused.
* Recording. A tutorial has no audio; the replay is a `timeline_json`.
* Autoplay on a timer. The line moves at the speed of a voice or at the speed
  of a child's finger, and there is no third option.
