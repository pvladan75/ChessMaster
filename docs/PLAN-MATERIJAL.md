# Material: positions, exercises and puzzles — one model, three verbs

Written 23.9.2026 by the lead (Fable), from the owner's request of the same
day. **Nothing in code.** To be carried out by the owner with Opus as the lead
of that session, phase by phase; each phase names who builds it and the gate
that decides it is done.

Every brief handed to a worker carries this sentence, in its method section:
*If you believe a test in the gate is wrong, stop and say so in the report — do
not work around it.*

Baseline to re-measure before phase 0, in a worktree (rule: measure a baseline
where nothing is being edited): app **3876** (1 skipped), backend **1637**
without a database / **1769** with, `flutter analyze` the same 26 infos
(`CLAUDE.md`, header). Every phase ends with its arithmetic in
`docs/LESSONS.md` and the block in `CLAUDE.md` updated.

## 1. The request

The owner, 23.9.2026, paraphrased from Serbian: *scanning PDFs works, but a
position from a font book and one from a picture book are handled
differently, and the difference should be the purpose, not the source. Font
books were puzzles with printed solutions; picture books were studies and
theory. For a puzzle whose side to move is unknown we use the engine on both
sides, and if one side has a move convincingly better than every other, that is
the puzzle. We are in a logical knot. I want the simplest model that gives the
user a powerful tool without cluttering the interface: how scanned material is
used, how it is searched, and whether it goes to students as homework or serves
the user's own growth. Users are trainers, students, and people who are
neither and train alone. A big reset is not something I will run from.*

Three additions the same day:

- Only the owner uses the app, in testing. **Everything that exists may be
  deleted; it was trial material. Nothing existing has to be adapted** — no
  compatibility, no backfill, no second reader.
- The four proposals of the lead's first answer were accepted: derived state,
  engine on demand, solo verdicts, and — as first stated — positions saved from
  the board joining the exercise table. **The fourth rests on a wrong premise
  and is revised in §3, decision 7.**
- *I also have puzzles that come out of Analysis, from evaluating games. See
  what you do with them.* §3, decision 8.

The owner's own words on the model: **a position is one thing, an exercise is
another.** That sentence is the model; §3 only writes down what follows.

## 2. What exists, measured 23.9.2026

Read on `master` at `3032445`. Paths: `APP` = `chess_app/lib/`,
`BE` = `chess_backend/`, `T` = `chess_app/test/`.

**Both scanner paths already land in one table.** `POST /scans/confirm`
(`BE/routes/scans.js`, `BE/services/scanIntake.js:65-98`) writes
`custom_puzzles` with a `cust_` id and `origin = 'book'` for the font path
(`APP/features/position_scanner/screens/scan_review_screen.dart:227-268`) and
the picture path (`image_scan_screen.dart:515-566`) alike. What differs is the
**arrival shape**:

| | font book | picture book |
|---|---|---|
| side to move | the printed solution, else the only legal side, else unknown (`positionScanner/verify.mjs:105-128`) | unknown until the trainer touches it (`models/image_scan.dart:116-128`, `sideTouched`) |
| printed solution | `solutionSan`, verified to play on confirm | none |
| label, themes | from the book | none |
| `needs_review` | `problem != null \|\| sideSource == 'unknown'` | `!sideTouched` |

**The engine check for the side runs in one place, after saving.** „Check
with engine" on `SavedPositionsScreen`
(`saved_positions_screen.dart:220-276`), a screen reachable only from the
snackbar after a scan (`app_routes.dart:89`, `/scan/saved`).
`SideProposalRunner.run` (`services/side_proposal_runner.dart:72-118`) takes
`List<SavedPosition>` — saved rows, never the boards on the review screen —
searches the same board once with each side to move (multiPV 1), refuses the
cloud engine (`ensureUsableEngine`), and `decideSide`
(`services/side_proposal.dart:101-168`) answers: one side mates → **high**;
gap of at least 3.0 pawns → **medium**; both similar or both mate → **none**.
A proposal is held in memory and written only when accepted; „Accept
confident" takes `high` on rows still marked for review
(`saved_positions_screen.dart:132-139`). **It keeps the evaluation, not the
move** (`_evalFor` reads `lines.first.evaluation` only), though
`AnalysisLine` carries `bestMoveSan` (`APP/models/analysis_models.dart:17-31`).
The picture path, which has no printed solution and needs this most, never
sees it.

**„Position" and „exercise" are one row read by one function.** `exerciseOf`
(`BE/services/exercise.js:107-141`): a row with a solution or a game task is
an exercise; a row with neither is a bare position (`problem: 'has no
solution'`). `assignableProblem` (164-174) refuses a bare or `needs_review`
row. The app repeats the rule as `LibraryEntry.isExercise`
(`APP/features/library/models/library_entry.dart:161-162`) — a second home.

**„Make exercise" copies.** The Library's `_makeExercise`
(`library_screen.dart:431-449`) opens `MakeExerciseSheet` over a fresh
`MoveTree` and the sheet calls `POST /exercises`
(`make_exercise_sheet.dart:407-408`, `exercise_api_service.dart:42`), which
inserts an `ex_` row with `origin = 'manual'` and no source fields
(`BE/services/exerciseAuthoring.js:112-125`). The scan stays, unchanged. Book,
page and label are lost. **Yet `PUT /exercises/:id` already edits any row the
account owns, keeps its position and its origin, and requires only a name and
a task** (`updateExercise`, 148-167) — the in-place write exists on the server
and the app never calls it for a scan.

**Nobody can solve their own exercise.** `CustomPuzzleSolverScreen`
(`APP/features/assignments/screens/custom_puzzle_solver_screen.dart`) reads
from `AssignmentDetail` only the id (173, 233), the title and the
instructions (234-255, 314); the positions arrive as a list. Its one coupling
is `submitCustomAttempt` → `POST /assignments/:id/custom-attempt`. That route
(`BE/routes/assignments.js:273-339`) judges through `firstMoveOf` +
`judgeAttempt` (`BE/services/customPuzzleJudge.js:48-94`, pure) and writes
`assignment_items` through `recordPuzzleResult`; **it writes no
`user_puzzle_attempts` row.** The attempt log (`BE/db.js:843-870`) has
`source VARCHAR(20)` with no CHECK, validated by the frozen `SOURCES` list in
`BE/services/puzzleProgress.js:14-21` and mirrored by `PuzzleSource` in
`APP/core/services/puzzle_attempt_api.dart:19-57`; `hub_progress_test.dart:185`
expects exactly four „Retry failed (21)" buttons for `PuzzleSource.all`. Retry
mode is a `retry=1` flag on the route, each destination fetching its own ids;
`TrainingHubScreen._onRetry` (83-94) has no default case. Spaced repetition
(`review_items`, `mistake_reviews`, the repertoire drill) can hold no
`custom_puzzles` row. Parked question 5 of 20.9.2026 (`STANJE-RADA.md`) says
all of this.

**A game task already plays without a homework.** `AiStudioScreen`
(`APP/screens/ai_studio_screen.dart:97-118`) with `engineGameTask` and
`assignmentId == null` plays the task and shows the local verdict; it posts
nothing (`_finishEngineGame`, 2501-2544, raw `http.post` to
`/assignments/:id/game-result`). `judgeEngineGame`
(`BE/services/engineGameTask.js:146-243`) is pure; `askTablebase`
(`assignmentService.js:543-559`) is not exported.

**Two shelves for the same rows.** The Library (`library_list.dart`) has
kind chips, the task and origin filters under Exercises, a label panel, and a
client-side search over title and themes only (231-234). The server's
`search` (`BE/services/positionLibrary.js:58-65`) also matches instruction,
source and label, and the screen never sends it (`library_screen.dart:163`).
A scan entry already carries `sourceTitle`, `sourcePage`, `sourceLabel`,
`needsReview`, `origin` and `task` on the wire (`positionLibrary.js:85-108`).
`SavedPositionsScreen` has what the Library lacks — a chip per book, the
count needing review, the engine check, multi-select for „Add to tutorial"
and „Assign" — and lacks what the Library has: search, labels, „Make
exercise". `GET /scans/puzzles` (`scans.js:612-639`) has that screen as its
only caller (`scanner_api_service.dart:505`).

**Puzzles from a game review are a fourth thing.** „Review entire game"
(`APP/features/analysis_studio/widgets/game_review_dialog.dart:138-150`)
walks the game, and `LocalPuzzleExtractorService.buildPuzzlesFromMoments`
(`APP/core/services/local_puzzle_extractor_service.dart:126-158`) packages up
to five blunders as `LocalPuzzle` — the position **after** the blunder, the
blunder move, the swing, a motif label, `fenBefore`; **no answer**. The set is
saved at once, under a timestamp title, to `puzzle_sets` (`BE/db.js:294-304`,
JSONB) through `PuzzleSetRepository` with a device copy. It is a Library kind
of its own (`LibraryKind.puzzleSet`, the seventh chip) and opens the
Analysis Studio's „puzzle mode" (`analysis_studio_screen.dart:1437-1463`):
the board at `fenBefore`, the blunder played after 900 ms, the engine on, a
snackbar with the motif. **That is a study door, not a solver: nothing is
judged and nothing is recorded.** It cannot be sent to a student. (The
homework editor's „A puzzle set" is Lichess criteria — themes, count, rating
— not one of these sets: `homework_editor_screen.dart:194-197, 225-229`.)

**The „from mistakes" rows are the same shape as those puzzles would be.**
`BE/services/homeworkFromArchive.js:70-90`: a `custom_puzzles` row with the
position before the student's mistake, the engine's better move as the
answer, an instruction sentence naming the move played, `origin =
'mistakes'`, an `hw_` id stable by content. A Find exercise, judged by the
server, assignable.

**A position saved from the board is not a bare position.** The room's
„Save position" (`APP/screens/chess_game_screen.dart:1786-1816` →
`POST /lessons/save`) writes a `saved_lessons` row with `fen = the tree's
root` and `pgn = the whole tree` — main line, sidelines, comments, arrows —
and the room column **reads that line back** on tap
(`loadLessonPosition(entry.fen, entry.pgn)`, 1515-1534). Assigned as a
lesson it is a one-step lesson with its line (`BE/services/lessonSteps.js:
309-319`). The Library's „Make exercise" works on it today, by copy, from
the root position. Moving these rows into `custom_puzzles` would need a
`pgn` column or lose the line, and touches about 25 app test files and 10
backend ones (the measurement is in the lead's session of 23.9.2026; the
list is reproducible with `grep -l "LibraryKind.position\|position_list"
test/`).

**A bug on the way.** „Assign to student" on a **game** exercise from the
Library card posts to `/assignments/custom`
(`library_screen.dart:507-515`), whose `createCustomAssignment` asks
`assignableProblem(row)` with the default `as: 'find'`
(`assignmentService.js:743`) and refuses every game task; when all are
refused the answer is 400. The only writer of an `engine_game` assignment is
`sendHomework` (`BE/services/homeworkSend.js:166-177`). The lead's first
answer called this a one-line fix; it is not — the direct route can only make
a find assignment, so the card must go through a homework.
`AssignPositionsDialog` also lists pending students
(`assign_positions_dialog.dart:71-73`), whom the server then refuses.

## 3. Decisions — owner 23.9.2026, with the lead's revisions marked

1. **One row, three states, and the state is derived from the row, never
   chosen by the source.**

   | State | Rule (`exerciseOf`, one home) | What it can do |
   |---|---|---|
   | unsettled | `needs_review`: side unknown, or the printed solution would not play | asked about before any door (`settledFen`, as today); nothing else |
   | position | settled, no solution and no task | **Study**: Analysis, a tutorial part, the room's board, play it out |
   | exercise | settled, a solution or a game task | Study, **Solve**, **Send** |

   Origin (`book`, `manual`, `mistakes`) stays a fact and a chip. **No
   screen branches on it.** The font path and the picture path differ only
   in what a board arrives with, and both go through the same settle step
   (phase 2).

2. **Seven chips stay** (Tutorials, Exercises, Positions, Analyses,
   Recordings, Puzzle sets, All). Folding Exercises and Positions into one
   chip would buy one fewer chip and a book's boards in one place; the source
   filter (phase 3) gives the second without the first, and a scan that
   becomes an exercise in place simply moves from the one chip to the other
   — the two chips *are* the two states. The Puzzle sets chip goes with
   decision 8, so the shelf ends at six.

3. **The engine at scan time: on demand, per batch, and a proposal until a
   person accepts it** — the rule of 19.8.2026 (`STANJE-RADA` archive, „Motor
   predlaže, trener odlučuje") unchanged. One side mates → high; a gap of
   3.0 pawns → medium; otherwise no proposal. High proposals may be accepted
   in bulk, side and answer together. A medium one is accepted one by one,
   and its answer only if the person ticks it — a book can ask for a
   defence. Automatic checking is not built; it is a later option, not a
   rule.

4. **Solo verdicts.** Find, Checkmate in N and Draw or better judge
   themselves (server, tablebase where one answers). **Play N moves has no
   trainer when I play my own: it records nothing.** The owner's words:
   „played and nothing more".

5. **Three verbs on every exercise card, for every account: Study, Solve,
   Send.** Send is drawn only when the account has accepted students (a
   server that cannot be reached is not an account with no students — the
   button stays). A student who scans their own book is a solo user for that
   material. The labels on screen stay as they are („Open", „Assign to
   student", „Send to student"); the new word is **Solve**, entered in
   `docs/GLOSSARY-EN.md`.

6. **No compatibility, no migration, no backfill.** The owner's words:
   everything that exists is trial material and may be deleted. Every
   deletion of rows or tables is the lead's, on a count shown to the owner
   and his yes, with the owner's server stopped (nodemon runs `initDB` on
   every save — rule 20 of `CLAUDE.md`). `initDB` stays additive in *shape*
   for the one reason that has nothing to do with compatibility: it runs on
   every start.

7. **Positions saved from the board are not moved — revised by the lead,
   23.9.2026, after measurement.** The owner's yes was given to the lead's
   sentence „today they live in `saved_lessons` and can never become
   exercises", and that sentence was false: the Library makes an exercise of
   one by copy today, which is the right thing for a row that is a **line**
   with a root. What §2 shows is that a saved position is what the room puts
   on the board, line and all; an exercise has no line (Find is one move,
   `PLAN-EXERCISE.md` §10). Two things that carry different material stay in
   two tables, and the Positions chip already shows both to the reader. If
   the owner still wants the move after reading §2, it is a plan of its own:
   a `pgn` column on `custom_puzzles` or the loss of the line, and the test
   files named above.

8. **A puzzle from a game review is a Find exercise with `origin =
   'mistakes'`** — the shape `homeworkFromArchive.js` already writes: the
   position after the blunder, the engine's refutation as the answer, a
   sentence naming the move just played, the motif as a label, the game's
   name as the source. It is shown to the person before it is kept (as the
   scanner shows its positions), it is solved by the one solver (phase 1),
   it can be sent, and it counts on the „My exercises" card. **`puzzle_sets`,
   its routes, the repository, the device copy, the seventh chip and the
   studio's puzzle mode are deleted.** The blunder „reveal" animation (900
   ms, then the move) goes with the puzzle mode; the study door is the
   exercise's own screen and Analysis. The extractor (`LocalPuzzle`,
   `buildPuzzlesFromMoments`) stays as the finder.

9. **One shelf.** The Library absorbs what `SavedPositionsScreen` had that
   the Library lacked — a source filter and a „Needs attention" chip — and
   the screen, its route and `GET /scans/puzzles` are deleted. Two things
   are lost knowingly: the engine re-check of rows *already settled*
   (disagreement detection) and multi-select for „Add to tutorial" and
   „Assign" over saved rows. The homework picker already multi-picks
   exercises; the rest is asked for again if missed (§6).

## 4. The model on one page

```
                 scanner (font | picture)      board / room        game review
                          │                          │                  │
                    settle + propose          Save position        keep as exercises
                   (phase 2, both paths)      (unchanged, a line)     (phase 4)
                          │                          │                  │
                          ▼                          ▼                  ▼
   custom_puzzles ── unsettled ──► position ──► exercise      saved_lessons (line)
                     (ask first)     │  in place, phase 3  ▲         │
                                     │                     │ by copy │
                                     └─────────────────────┴─────────┘
   verbs on an exercise:   Study (open)   ·   Solve (phase 1, 5)   ·   Send (students)
   verbs on a position:    Study (open)   ·   Make exercise
   the shelf:              Library — chips by state, source filter, needs attention, search
   the drill:              Practise → „My exercises": solved · to retry · Solve · Retry
```

Who sees what: a **trainer** sees all three verbs; a **student** sees Study
and Solve on their own material and receives exercises through homework; a
**solo user** sees Study and Solve. Nothing else differs.

## 5. Phases, each with its gate

Order: 0 → 1 → 2 → 3 → 4 → 5 → 6. Phase 1 is first because it is the one
the other four make worth having, and it changes no schema. Phases 2 and 3
are independent of each other; 4 needs 3 (the source filter) and 1 (the
solver); 5 is optional and last. Every app phase ends with `dart format` on
what it touched, `flutter analyze` read against the 26 infos, the full app
suite with nothing else running, and every backend phase with `npm test` with
`.env` moved aside (the environment CI has) and, where a route reaches the
database, on a throwaway cluster (`CLAUDE.md`, the four commands).

### Phase 0 — two small things first [implementer] — built 23.9.2026

*Built by the lead inline (too small to brief). Baseline measured in a
worktree at `fe1af7e`: app 3876 (1 skipped), backend 1637 / 1769, analyze
the 26 infos — all as quoted above. After: app 3879, analyze list identical,
backend untouched. Both mutations red; the gate is
`test/assign_game_exercise_test.dart`. Checked live inside item 231.*

**Build.**

- „Assign to student" on a **game** exercise opens the homework editor
  seeded with that one item: `HomeworkEditorScreen` gains an optional
  `initialItems` (through the existing `_addItems`, `homework_editor_screen.
  dart:164-172`), and the Library's `_assign` sends a game entry there via
  `homeworkItemsFromExercises([entry])`; a Find entry keeps
  `AssignPositionsDialog`. Two doors for one verb is a wart the plan accepts,
  because the direct route cannot carry a game and the editor is where a
  trainer sees what is sent.
- `AssignPositionsDialog` lists accepted students only (`status ==
  'accepted'`, the way `hasTrainer` is computed in `home_screen.dart:932`).
- The baseline, in a worktree: both suites, the analyze list.

**Gate.** `T/assign_game_exercise_test.dart`: fake the client — a game
exercise's Assign pushes the editor with one `engineGame` row whose task is
the entry's task minus `type` (assert on the editor's rows), and a Find
exercise still posts to `/assignments/custom`; a pending student is not in
the dialog's list. Mutation: swap the branch (game → dialog) → red; drop the
status filter → red. Nothing on the server.

### Phase 1 — Solve my own exercises, and „My exercises" on Practise — built 23.9.2026

*Built by the lead inline, both halves (writing a gate precise enough to
hand over cost as much as the code). App 3879 → 3891, backend 1637 → 1656
without a database and 1769 → 1788 with one; analyze list unchanged. Where it
departs from the text below:* **the queue carries positions, not ids** —
`{fresh, retry}` in the shape `CustomPosition.fromJson` reads, never the
answer, so the solver needs no second fetch; **`POST /api/puzzles/attempt`
refuses `own`** (`SERVER_JUDGED` in `puzzleProgress.js`) — not in the plan,
and without it `own` in `SOURCES` let a client log a solve nothing judged;
**the card's „to retry" and its button are the queue's count**, because the
fold keeps failures on exercises deleted or changed since; **the solver
builds the homework's `SolveTarget` itself from `detail`**, so the overview
and the three test files that construct it are untouched. The owner's `hw_`
rows (made from a student's mistakes) are his own find exercises by this
rule and sit in his queue. Mutations: server six of six red on the right
case; app — each lock guard alone survives (there are three: the board's
`_verdict` and `_alreadyAnswered`, and `_onMove`'s), all three removed is red;
`!fromTrainer` in the Solve condition survived because `_actionsFor` gives a
trainer's material no buttons at all, so the clause was deleted and the
mutation moved to that early return, which is red.

**Server [lead].**

- `POST /exercises/:id/attempt` `{moveSan, msTaken?}` — the owner's row
  (404 otherwise, as every route in `routes/exercises.js`);
  `assignableProblem(row)` must be null, else 409 with that reason (an
  unsettled or bare position cannot be solved, and the sentence exists);
  judged by `firstMoveOf` + `judgeAttempt` — **the same two calls the
  homework route makes, and nothing else** (`exercise_one_reader.test.js`
  fails a new file that names `solution_san`); answers `{correct, reason,
  playedSan, solutionSan}`, the shape `CustomAttemptResult.fromJson` reads.
  **It writes the `user_puzzle_attempts` row itself**, `source = 'own'`,
  `solved` from its own verdict — never from the client, which is what the
  `/attempt` route's non-lichess branch does (`puzzles.js:568-581`) and is
  wrong for a server-judged exercise. It must not call `recordPuzzleResult`.
- `SOURCES` gains `'own'` (`puzzleProgress.js:14-21`); `ATTEMPTS_SQL` gives
  it no bucket. `GET /api/puzzles/retry?source=own` then works through the
  existing fold.
- `GET /exercises/queue` → `{fresh: [ids], retry: [ids]}`: *fresh* = the
  owner's Find exercises with `assignableProblem(row, {as: 'find'}) ===
  null` and no `own` attempt, oldest first; *retry* = `retryIds(rows, 'own')`
  — one home. Game exercises are never in either list (phase 5 says why).
- `getStudentProgress` and `idleStudents` read every row regardless of
  source; an `own` row therefore counts as activity and in accuracy. That is
  deliberate — it *is* activity — and a case says so, so the choice is
  visible.

**App [implementer].**

- `CustomPuzzleSolverScreen` decoupled from `AssignmentDetail`: it takes a
  `SolveTarget` (title, instructions, positions, `submit(puzzleId, moveSan,
  ms)`, and the door after a verdict). The homework overview builds one over
  the assignment — its behaviour and its tests unchanged — and the Library
  and the Practise card build one over `ExerciseApiService.attempt`. After a
  verdict, „Open" leads to the exercise's own screen.
- `PuzzleSource.own` in `puzzle_attempt_api.dart` (`all` and `retryable`);
  `ExerciseApiService.attempt(id, san)` and `queue()`.
- Doors: a **Solve** button on the Library card of an own Find exercise;
  a **My exercises** card on Practise, in the Tactics phase, with the
  progress line (`_progressLine`) and „Retry failed (n)" (`_retryButton`),
  its action **Solve** over the queue (fresh, then retry) at
  `/exercises/solve`, retry at `/exercises/solve?retry=1`, and the
  `_onRetry` dispatch case added. The card is drawn only when the account
  owns at least one Find exercise (the queue and the progress together say
  so); a card with nothing seen shows no line, as the others.

**Gate.** Backend `test/exercise_solo.test.js` (handlers with a stub pool,
as `puzzle_progress_routes.test.js` does): correct, wrong, „a different mate,
but mate"; not the owner → 404; a bare position and a game exercise → 409
with the reason; the attempt row written with `source = 'own'` and the
server's verdict (mutation: write the client's `solved` → red); no
`UPDATE assignment_items` in the query log (mutation: call
`recordPuzzleResult` → red); the queue leaves attempted ids out of *fresh*
and lists failed ones in *retry*; `puzzle_progress.test.js` and
`puzzle_attempt_api_test.dart` extended for the new source, openly. App
`T/exercise_solve_own_test.dart`: fake the client — Solve on a card posts to
`/exercises/<id>/attempt` with the SAN played through the board's own
`onMove`; the verdict shown; the board locked after one move (mutation:
lock removed → red); the homework path still posts to
`/assignments/:id/custom-attempt` (its own files green, untouched);
Practise: the card's line and retry button, the retry route carries
`retry=1` (mutation: dispatch case removed → red); `hub_progress_test.dart`
and its copy in `docs/gates/` go from four buttons to five **openly**, with
the supersession written above the assertion; `training_hub_layout_test`
gains the card title; 360 × 640. Live: item 231.

### Phase 2 — Settle and propose before saving, on both scanner screens — built 23.9.2026

*Built by the lead inline, both halves. App 3891 → 3906, backend 1656 → 1660
without a database and 1788 → 1794 with one; analyze list unchanged. The
picture screen's cases live in `image_scan_screen_test.dart` (group „phase 2
— the engine before saving"), which already walks a picture book to its
boards; `scan_settle_test.dart` holds the font screen's. Departures and
finds:* **a hand flip on the font path now settles the side** (`sideSource =
'trainer'`), as it always had on the picture path — until now a flipped font
board was still saved marked for review; **a board only one side can be to
move in costs one search**, for that side, so its answer is known too (it
cost none before and had no move); **the bar and the note are one widget
file** (`widgets/side_suggestions.dart`) both screens draw, and
`SideSuggestions.depths` is the depth list's home (`SavedPositionsScreen`
keeps its own until phase 3 deletes it). **Two faults on master**: the font
scanner's grid was 0 px tall on a phone (the screen is one scroll now, with a
minimum card width), and `AdaptiveCardRows` never re-measured a card that grew
in place (it does on every rebuild now, with a case in its own test). Twelve
app mutations and four server ones, each red on its case; two survived first
and removed a redundant flag.

**Build.** [lead: runner, model, column · implementer: the screens]

- `SideProposalRunner.run` over `(id, fen)` pairs instead of
  `List<SavedPosition>`, and `SideProposal` gains `answerSan` — the proposed
  side's best move from the same search (`lines.first.bestMoveSan`);
  `decideSide` takes the moves beside the evaluations. `isPlayableWith` and
  `parseEval` untouched.
- On `ScanReviewScreen` and `ImageScanScreen`, one bar button **„Suggest
  sides with the engine"**, enabled when any accepted board is unsettled
  (font: `sideSource == 'unknown'`; picture: `!sideTouched`), with the depth
  picker (12 … `kMaxEngineDepth`, default 16 — it moves here from
  `SavedPositionsScreen`), progress „n of N" and Stop; the cloud-engine
  refusal said in words, as today. A board the person already flipped is
  never in the run.
- Under each proposed board: the reason and both evaluations, and two
  buttons — **„Set side"** and **„Set side and answer"**. In the bar,
  **„Accept all confident"**: high proposals only, side and answer together.
  Accepting sets the side (`fen` / `sideToMove`, `sideSource = 'engine'`,
  `sideTouched`), clears the review mark, and with the answer sets
  `solutionSan` + `solutionLegal = true` + `solutionSource = 'engine'`;
  `ReadBoard.toScannedPosition` carries all of it.
- Server: `custom_puzzles.solution_source VARCHAR(8)` nullable [lead] —
  `'book'` for a printed solution, `'engine'` for an accepted proposal;
  `prepareRow` verifies an engine answer exactly as a printed one and drops
  it with `needs_review` if it does not play. `deriveInstruction` unchanged:
  it says „mates in one" and nothing else.

**Gate.** `T/scan_settle_test.dart` with a fake runner through the
constructor seam: unknown boards get proposals and settled ones are not in
the run (mutation: run over all → red); „Set side" flips the fen and the
confirm body carries `needsReview: false`; „Set side and answer" puts
`solutionSan` and `solutionSource: 'engine'` in the body; „Accept all
confident" takes high only (mutation: medium too → red); a board flipped by
hand before the run is left alone; Stop keeps what landed; the same four
cases on the picture screen over `ReadBoard`; the refusal on a cloud engine.
Pure: `decideSide` returns the answer move with the side. Backend
`scan_intake` cases: `solution_source` stored; an engine answer that does
not play is dropped and the row marked, as a printed one is (mutation on
the branch). Live: item 232 — including a real run on a picture book, timed:
two searches per board at depth 16 are seconds each, and a batch of fifty is
minutes; the number goes in the item.

### Phase 3 — Exercise in place; the Library is the one shelf — built 23.9.2026

*Built by the lead inline. App 3906 → 3915, backend 1660 → 1664 without a
database and 1794 → 1799 with one; analyze list unchanged; fourteen app
mutations and one server one, all red, none survived. Departures:* **the
server's `search` stays** — `PositionPickerDialog` calls it, deliberately
(only 500 rows per shelf arrive, so a client filter would hide what a big
library looks for); **the picker was measured and kept**, only its empty text
changed; the Library's own search now reads the same fields the server's
does. **„View" after a save chooses the chip** — Exercises when most saved
boards carry an answer, Positions otherwise — because a font book's positions
are mostly exercises and a fixed Positions chip would open on nothing.
**`isExercise` cases went to `position_library.test.js`**, which covers scanned
rows; `library_kinds.test.js` does not. **Assign only** — the tutorial's
„Send to student" was left as it was. **Optional „Suggest a move" not built.**
Two faults on master found on the way: the Library header over the rows had
no ceiling (136 px over the screen at 360 x 640), and `site/` quoted two
labels of the deleted screen (`manual_labels_test` caught it; the manual now
describes the Library).

**Build.**

- **In place** [implementer]: `MakeExerciseSheet` and
  `ExerciseEditorScreen.make` gain `existingId`; with it the sheet saves by
  `api.update(existingId, draft)` (a draft without `fen`, as an edit sends
  today) and never by `create`; the Library passes `entry.id` for a scan.
  The row keeps its id, `origin = 'book'`, `source_*`. The sheet's name
  field is prefilled with the entry's title. Server: `present()` sends
  `sourceTitle` / `sourcePage` / `sourceLabel`; nothing else changes.
- **State on the wire** [lead]: `positionLibrary.js` sends `isExercise`
  computed by `exerciseOf` (`problem === null`), and `LibraryEntry.isExercise`
  reads that field — one home for the rule.
- **The Library absorbs Saved Positions** [implementer]:
  - a **Source** filter (single choice, clearable, drawn under Exercises and
    Positions) built from the `sourceTitle` of the entries shown — books
    now, games after phase 4;
  - a **„Needs attention (n)"** toggle chip over `needsReview`;
  - the search box matches title, labels, `sourceTitle`, `sourceLabel` and
    `instruction` — the fields the server's `search` matches — and the
    server's `search` parameter is deleted if a grep of `APP` finds no
    caller, its test cases re-aimed at the client;
  - the post-save snackbar on both scanner screens says „In the Library" and
    its View opens the Library on the Positions chip with the source set
    (measure what the route takes; `initialFromTrainer` is the precedent);
  - **„Assign to student" drawn only with accepted students**:
    `GroupApiService.acceptedStudents()` on load; `null` keeps the button;
  - `PositionPickerDialog` (the homework's picker) draws `LibraryList` on the
    Exercises chip with its filters, multi-pick — measure the dialog first,
    it may already have most of this; its stale empty text is corrected;
  - **deleted**: `SavedPositionsScreen`, `/scan/saved`, `listSaved`,
    `GET /scans/puzzles` and its tests, `SavedPositionsScreen.depths`
    (re-homed on the scanner screens). Before deleting
    `saved_positions_side_test.dart`, each of its four rules is found or
    added over the Library (`side_to_move_gate_test`,
    `library_card_doors_test`): set-it asks and keeps the answer; the tap
    asks first and then opens Analysis; „Add to tutorial" asks first and the
    part carries the side. `engine_depth_ceiling_test`,
    `desktop_shortcuts_test`, `navigation_flow_test` re-aimed. `site/`
    grepped for „Saved Positions"; the manual already says the Library.
  - Optional, only if it costs an afternoon: „Suggest a move" on
    `ExerciseEditorScreen.make`, playing the exercise checker's top move as
    the answer, replaceable. If not, say so in the report.

**Gate.** `T/library_one_shelf_test.dart`: Make exercise on a scan sends
`PUT /exercises/cust_…` and no `POST` (mutation: POST → red), and the entry
then shows under Exercises with „From a book"; the source filter narrows
(fixture: two books whose entries share a label, so the label alone cannot
do the filter's job — rule 6); needs-attention narrows; the search finds a
book name, a label and an instruction on fixtures where the title alone
matches nothing (the first filter must cut); Assign hidden with no accepted
students and shown when the fetch fails; the snackbar's View route; the
router has no `/scan/saved`; 360 × 640 and 1200 × 800. Backend
`library_kinds.test.js` gains `isExercise` cases (a game row with no
solution is an exercise — mutation `isExercise = hasSolution` → red);
`position_library.test.js` keeps the owner scoping that the deleted route's
tests held. Live: item 233.

### Phase 4 — Puzzles from a game review are exercises; puzzle sets go — built 23.9.2026

*Built by the lead inline. The owner saw the count — 5 sets, 25 puzzles, on
two test accounts — and said to delete them. App 3915 → 3901, backend 1664 →
1658 / 1799 → 1794 (tests of deleted code went with it); analyze unchanged;
seven app mutations and every server rule red. Departures:* **the list is its
own widget** (`KeepPuzzlesPanel`), so the gate tests it and the draft builder
without an engine; the dialog is tested once over a one-move game whose
blunder is the last move, with an engine that implements `StockfishService`.
**The kept count is said by the studio**, after the dialog closes, through
`AppFeedback` (a raw snackbar from the dialog is what the guard forbids).
**`last_move_reaches_board_test`'s floor went from 4 to 3**, openly: the
studio's last-move marker was only ever set by the puzzle reveal. **The
device key `analysis_studio_puzzle_sets` is left where it is** — nothing reads
it, nothing migrates it. **The table was dropped by the lead's own mistaken
start of the server**, three seconds against the managed database, after the
owner's yes and with his server stopped (recorded in `LESSONS.md`).

**Server [lead].**

- `parseExercise` accepts `origin` — `'manual'` (default) or `'mistakes'`;
  `'book'` from a client is refused, only a scan may say it — and `source
  {title ≤ 255, label ≤ 16}`; `createExercise` writes `origin`,
  `source_title`, `source_label`; `present` sends them.
- `DROP TABLE IF EXISTS puzzle_sets` in `initDB`, `routes/puzzleSets.js` and
  its mount gone, `puzzle_sets_routes.test.js` gone — after the count of the
  owner's sets is shown and he says yes, with his server stopped.
  `analysis_replace_routes.test.js` and `book_calibrations_routes.test.js`
  mention the router: read why before touching them.

**App [implementer].**

- `GameReviewDialog`: after the walk, the found puzzles are **listed** —
  thumbnail, „after 23…Qe7", the refutation, the swing, the motif — all
  ticked, a name field (the analysis title if it has one, else „Game of
  dd.mm.yyyy"), and **„Keep N as exercises"**. The refutation is the next
  moment's `engineLineBefore.bestMoveSan` (its `fenBefore` is this moment's
  `fenAfter`); where there is none — the game's last move — one
  `analyzePositionSync` at the dialog's depth, and if that gives nothing the
  puzzle is listed as „no answer found" and cannot be ticked. Each ticked
  puzzle is `POST /exercises` with `origin: 'mistakes'`, `name = "<name>,
  move N"`, `instruction = "<Side> just played <move>."` (a fact, not a
  task), `themes = [themeKey]` when there is one, `task {type: 'find'}`,
  `solution [{accept: [refutation]}]`, `source {title: name, label:
  "<move>"}` — and **the writer reads its own work back**: the move is
  replayed on the FEN before the request is sent.
- Deleted: `PuzzleSetRepository`, `PuzzleSetApiService`, the device copy (the
  app stops reading its key; no migration), `LibraryKind.puzzleSet` and its
  chip (six), `SavedPuzzleSetsDialog`, the studio's `initialPuzzles` mode
  (`_loadPuzzleAtIndex`, `_applyPuzzleOpponentMove`, `_activePuzzleSet`),
  the Library's `_openPuzzleSet`, `LocalPuzzle.toPuzzleMap` if unused. Tests
  grepped for `puzzleSet`, `PuzzleSetRepository`, `initialPuzzles`,
  `SavedPuzzleSetsDialog` in `T/` **and `T/support/`** (`device_only_puzzle_
  sets.dart`), and in `docs/gates/`. Rules kept before deleting
  `puzzle_sets_sync_test.dart`: „a server that cannot be reached is not an
  empty account" is checked to hold for the Library's own list and added
  there if it does not; the rest is about a table that no longer exists.
  `lists_grid_3a_test.dart` loses its saved-sets half and keeps the
  homework-templates half.

**Gate.** `T/game_review_exercises_test.dart`: fake the client and the
engine — over a fixture walk with three blunders the dialog posts one
`POST /exercises` per ticked puzzle with the asserted body; an unticked one
is not posted; the solution is the next moment's best move (mutation: the
blunder move → red; `origin: 'manual'` → red); the last-move puzzle runs one
search or is not offered; `library_list_test` says six chips (openly, with
the supersession of the 18.9 „seven" written above it). Backend
`exercise_authoring.test.js`: origin accepted and refused, source stored and
presented. Both counts fall by the deleted tests; the arithmetic in
`LESSONS.md`. Live: item 234. Supersedes `TODO-provera` 211 and 207.1 —
**a line appended under each, never a reworded body** (`spoji.py` matches on
the text).

### Phase 5 — Own game exercises are recorded [lead: route · implementer: door] — built 23.9.2026

*Built by the lead inline, both halves. App 3901 → 3906, backend 1658 →
1667 / 1794 → 1803, as predicted before the run; analyze unchanged; six server
and seven app mutations, all red. Departures:* **`askTablebase` and
`sharedTablebase` are exported from `assignmentService.js`** rather than
moved — one home either way, and the homework's code stays where it is.
**`pending` is false for „Play N moves"** played alone: nothing will judge it,
so nothing waits. **The end-of-game dialog says so, for one's own game only**:
„Played" for a game with no goal, no trainer named, and for a tablebase that
did not answer, that the game was not counted — a homework's pending game is
asked again later (`judgePendingGames`), one's own is not.

- App: the own game exercise's card gets **„Play"** (Solve for a game):
  `AiStudioScreen(initialCategory: 'engine_game', engineGameTask:
  EngineGameTask.fromJson(entry.task), exerciseId: entry.id)`;
  `_finishEngineGame` posts through `ExerciseApiService.gameResult(id,
  moves, resigned)` with an injectable client when `exerciseId != null`,
  and to the assignment route when `assignmentId != null` — one or the
  other, never both.
- Server: `POST /exercises/:id/game-result {moves, resigned}` — the owner's
  row, a game task; `judgeEngineGame`, then the tablebase where it says
  `needsTablebase` (`askTablebase` moves to one exported home); an
  `own` attempt row with `solved = goalMet` **only when judged**; a `play`
  goal writes nothing (decision 4); a silent tablebase writes nothing and
  answers `pending: true` — absence is a third answer. Response as the
  homework route's: `{goalMet, judgedBy, pending, ending, outcome}`.
- The queue of phase 1 stays Find-only; a failed Win is retried from its
  card, not from the solver.

**Gate.** Backend: a win judged by the rules writes a solved row; a hold at
the move target with seven pieces asks the tablebase (the fake client's
request asserted) and writes by its answer; a silent tablebase writes no
row and says pending; `play` writes no row and `judgedBy` is null
(mutation: write `solved: false` for play → red); not the owner → 404; a
Find exercise → 409. App: the door carries the task (asserted on the pushed
route's arguments); the result goes to the exercises route and not the
assignments one (mutation). Live: item 235.

### Phase 6 — the owner's live pass [owner]

Items 231–235 in `TODO-provera.md`, one per phase, inserted **above** item
230 (the newest block runs newest-first from line 5881). Phase 0 is checked
inside 231. Each item names the screen, the tap, and what must be seen, in
the register that file uses.

## 6. Not in this plan

- **Spaced repetition over own exercises.** The retry queue is enough for
  now; `PLAN-NAPREDAK-VEZBI.md` phase 3 (SM-2 on the second failure) stays
  optional and unbuilt, and would cover `own` as one more source.
- **Editing the name and labels of a bare position** (`PATCH
  /scans/puzzles/:id` takes only the side and the instruction). Labels
  arrive with a font book and with a game's motif; a picture book's
  positions are found by source and page. Asked for again if missed.
- **Multi-select in the Library** — the „Add to tutorial" and „Assign" over
  several saved rows that `SavedPositionsScreen` had (decision 9).
- **The engine re-check of settled rows** (decision 9).
- **Moving positions saved from the board** (decision 7) — its own plan, if
  ever.
- **Automatic side proposals** at scan time (decision 3).
- **Vector-drawn boards**, camera photographs, OCR of move text —
  `PLAN-SKENER-SLIKE.md` §6, unchanged.
- **The blunder reveal animation** of the studio's puzzle mode (decision 8).
- Renaming the homework sheet's „A puzzle set" (Lichess criteria): once the
  Library has no Puzzle sets chip the name is unambiguous.

## 7. What decides it

Two numbers from the live pass, both in item 232: how long „Suggest sides
with the engine" takes on a full picture-book batch, and how many of its
high proposals the owner overturns by hand. A proposal that is slow is a
cost; one that is often wrong at „high" is the thing decision 3 exists to
prevent, and would send the threshold back to §2 rather than to the screen.
