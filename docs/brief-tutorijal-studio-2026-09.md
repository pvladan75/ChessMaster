# Brief: writing a tutorial in one sitting

Companion to [TASK-tutorijal-studio.md](TASK-tutorijal-studio.md). That file is
the instruction; this one is why the job exists and what will judge it.

## Why

A **tutorijal** is a series of worked examples on one theme: a trainer writes
it, a child walks through it alone. The trainer's ask, in their own words, was
to write the whole thing **in one sitting, before anything is saved** — put a
position up, play the line, say what each move is for, then „next position",
and again, and again, and only at the end press save.

None of that was possible. The trainer's only route was the Analysis Studio's
„Napravi korak od ove pozicije", which saves **one** position into an existing
tutorial and sends you back to a course picker each time. Writing six examples
meant six round trips through a dialog, and a half-written tutorial sat in the
library the whole time.

The screen this batch finishes already exists and already opens. It has the
board, the move tree, the navigation strip, and a draft that survives being
closed. What it does not have is anything to write **with**, or anything to
write **into** — no fields, no list of examples, no save. That is this batch.

## What already exists — do not rebuild it

* **`TutorialStudioScreen`** (`lib/features/tutorial_studio/screens/`) — the
  shell. A board (`ChessBoardWithOverlay` inside `BoardWithCoordinates`), the
  move tree (`AnalysisMoveTreeWidget`), the strip (`MoveNavigationControls` over
  an `AnalysisNodeCursor`, which asks at a fork instead of walking into the
  first child), the handover from the Analysis Studio, and `_authoringColumn`,
  which is where your work goes. Its doc comment says so.
* **`TutorialDraft` / `TutorialExample`** (`lib/features/tutorial_studio/models/`)
  — the draft and one example, with `toJson` already matching what the server
  validates, `choices` already rendered as `[{text, correct}]`, and
  `TutorialDraft.positionList` already building the body of the save.
* **`TutorialDraftService`** — keeps the draft on the device, examples and
  working tree both, and is already wired into the screen. You add examples to
  the draft; you do not write a second persistence layer.
* **`StudioLessonStep.from(node)`** (`lib/features/analysis_studio/services/`) —
  one node answers for both the position and the line. It also reads the result
  back the way the student's screen will read it, so `replays` is a claim about
  that screen. Use it to build every example.
* **`LessonStepEditorPanel`** (`lib/features/lessons/widgets/`) — the trainer's
  existing step editor. **Read it before you write a field.** Its labels are the
  ones you reuse — „Zadatak za učenika", „Tip zadatka", „Samo prikaži",
  „Traži potez na tabli", „Traži odgovor iz liste", „Ponuđeni odgovori",
  „Dodaj odgovor", „Tačan potez: …" — and its `RadioGroup<int>` + `Radio<int>`
  is the shape for marking the correct answer. A trainer who has learned that
  screen must not have to learn a second vocabulary here.
* **`LessonApiService.save`** — merged, tested, frozen. One `POST` writes a
  whole tutorial.

## The one rule that will bite you

**An example that asks for a move must not carry a line.**

The server hands a step to a child through `redactStepForStudent`. That function
takes out `solutionSan`, `acceptedSans` and the `correct` flags — and it leaves
`pgn` alone, deliberately, because the line *is* the lesson. Then
`lesson_viewer_screen.dart` reads that line for **every** kind of step.

So an `ask_move` example whose line begins with the answer prints the answer
under the question, and the child finds it by pressing „Sledeći potez".

Two consequences, both asserted by the gate:

1. With the kind set to „Traži potez na tabli", a move played on the board is
   **recorded as the answer** — shown as „Tačan potez: Nf3" — and the board goes
   **back** to the position. It is not added to the tree. This is exactly what
   `LessonStepEditorPanel` already does, on the board that is already there
   rather than on a second one.
2. An example that has a line **and** asks for a move is refused before the
   save, in a sentence a trainer can act on. The demonstration belongs to the
   example *before* the question — which is the „show, then ask" shape the
   viewer was built for: the child's board does not reload between the two when
   the second example starts on the position the first one ended at. That is
   also why „+ Dodaj sledeću poziciju" puts you there.

`ask_choice` is **not** restricted. Its answers are text and its `correct` flags
are redacted, so a line under it gives nothing away.

## Two more that have cost this project time

* **Refuse before sending, not after.** A save that reaches the server and comes
  back 400 tells a trainer they lost the last twenty minutes. Three things are
  checked in the app: a tutorial with no name, the `ask_move` case above, and an
  `ask_choice` example with no answer marked correct. The server refuses all
  three correctly — that is not the point.
* **Do the thing, then say it.** A message must never be able to take down the
  action it reports on. Save first, then the snackbar, and the snackbar goes
  through `AppFeedback`, which cannot throw. A source-reading test fails if a
  raw `ScaffoldMessenger` call comes back.

## Rules that bite on this codebase

* **The repository is public.** No secrets, IP addresses, email addresses or
  account identifiers in code, comments or docs.
* **User-facing strings stay Serbian**, and the frozen vocabulary is
  „Tutorijal" for the artefact and „Čas" for the live session in a room. Never
  „lekcija", never „kurs" — a gate test fails if either comes back, and it also
  fails on „Ova tutorijal", because the noun is masculine and everything
  agreeing with it changes too. Code comments and your report are English.
* **`flutter analyze` does not exit clean** — 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Zero errors, zero warnings, **no
  new infos**: compare the list, not the exit code.
* **Run `dart format` on every Dart file you edit.** Run it; do not report it
  as run — a previous batch on this plan reported it and had not.
* **A release build paints no overflow warning.** A row of fields beside a board
  and a tree is exactly the shape that gets clipped in silence. The screen is
  Windows-only for now, but a window can be dragged narrow: check 1200 dp and
  840 dp, and where a row can grow, use `Wrap`.
* **Do not write a second model of the move tree.** `AnalysisNode` is the model.
  Two models of one tree is a fault this codebase has already paid for twice.

## Baselines, to measure yourself

`cd chess_app && flutter test` reads **1400 passing, 1 skipped** on the base
commit. `flutter analyze` reads **29 infos**. The skip is a golden-screenshot
group, skipped unconditionally in `dart_test.yaml`; leave it alone.

Measure both yourself before you start. A number quoted at you is a number
somebody else measured on a different tree.

## How it will be judged

By machine, against `docs/gates/tutorial_authoring_test.dart`, which the lead
copies into `chess_app/test/` and runs on your tree. It drives the screen
through its own controls and asserts on the **request**, not on the screen — a
test that watched for „sačuvano" would pass over a body with one example
missing, or two in the wrong order, or a question with no answer in it.

Eleven tests. On the current tree the file does not compile at all, because
`lessonApi` does not exist yet; once it does, **ten are red and one is green** —
„the save is written once, in one place" passes today because nothing saves at
all, and it has to still pass when something does. What each one demands:

| test | what it demands |
|---|---|
| two examples, in order, with their words and their question | the whole flow, and exactly one `POST` at the end |
| every example replays from its own position | `StudioLessonStep.from` owns the fen/pgn pairing |
| the examples are numbered as they are written | „Primer 1", „Primer 2" in the running list |
| the next example starts where the last line ended | the end of the main line, with an empty tree |
| the sentence field follows the move you are standing on | no leftover text written onto the next node |
| a tutorial with no name | refused, nothing sent |
| a question about a move, on an example that has a line | refused, nothing sent |
| a move played as the answer is not added to the line | recorded, board reverts, no pgn in the body |
| offered answers with none of them marked right | refused; then marked, and exactly one `correct: true` |
| the fen and the pgn of an example still come from one node | `StudioLessonStep` used, `PgnExporterService` not |
| the save is written once, in one place | at most one `save(` call site |

And, separately: **`test/tutorial_studio_test.dart` must stay green unchanged.**
Thirteen tests that say the shell still works — the board, the strip, the fork,
the draft outliving the screen, no second board or cursor, one platform
predicate. If one of them has to be edited for your work to pass, that is a
finding, not a chore. Report it and stop.

Your report is not the verdict. Those two files are.

## Out of scope

* `chess_backend/`. Frozen, already done, not yours.
* Adding, removing or reordering steps inside `LessonStepEditorPanel` — a later
  batch.
* Re-opening a committed example to edit its **tree**. An example is flattened
  to `fen` + `pgn` when it is committed, and reading a PGN back into an
  `AnalysisNode` needs an importer that does not exist. Adding examples does not
  need one. **Do not write one**, and do not offer an „edit Primer 1" that
  cannot do what it says.
* Assigning the tutorial, scheduling it, or anything to do with a student
  reading it.
* The Analysis Studio, apart from leaving its door alone.
