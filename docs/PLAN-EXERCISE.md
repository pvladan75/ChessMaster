# Plan: the exercise — a position with a task, made by the trainer

Written 18.9.2026 at the owner's request, after `PLAN-DOMACI-ZADATAK.md` passed
its live pass (items 181–184). The decisions in §2 were agreed in conversation
the same day. Phase 1 was built on 18.9.2026; the rest is not in code. The phases in §7 are briefed one at a
time, each with its gate.

`PLAN-ZAVRSNICA.md` froze new capabilities on 8.9.2026. This plan reopens one
row, as the homework plan did: it adds no new kind of activity for the student,
it lets the trainer **make** what could until now only be scanned out of a book.

## 1. The request

The owner, 18.9.2026 (paraphrased from Serbian): *I need a complete answer for
the positions a trainer sends. We must be able to verify that the student
solved it: one move, a series of moves, or a game against the engine — to win,
or to hold a draw for some moves. Verification by Syzygy, by the moves the
trainer entered, by the solution a position already has, by an engine
evaluation on the client. And a way to make these positions — see Preparation.
I am afraid of making it complicated.* And, later: ***a trainer does not send a
position, they send a task with a clear goal** — position plus goal. It becomes
a Library item with a name and labels, sorted by what it asks, and it can be
added to a homework. In lists of positions one should see the board without
opening a board screen.*

## 2. Decisions — owner, 18.9.2026

1. **The word is Exercise** (Serbian: *zadatak*): position + task + name +
   labels. **Task** keeps its glossary meaning — what is asked — and is a field
   of an exercise: *Find the move(s)*, *Win*, *Draw or better*, the last two
   either to the end of the game or for N moves. A **Position** stays a bare
   board and **cannot be put in a homework**; only an exercise can.
2. **The Library's „from book" chip becomes „Exercises"**, six chips stay six.
   A scan is an exercise whose *origin* is a book; origin and task are filters
   inside the chip.
   *Amended 18.9.2026, when phase 4 was briefed: the premise was wrong.
   There never was a „from book" chip — `LibraryChip.positions` holds both a
   saved position and a scanned one, „one kind to the reader". Decision 1 makes
   them two kinds, so one chip cannot hold both: **Exercises** is added after
   Tutorials and **Positions** narrows to bare positions — seven chips, not
   six. One enum line either way, put to the owner as such — **and confirmed
   by the owner the same day: seven chips.***
3. **Lists draw the board** with the existing `BoardThumbnail`; tapping it
   opens a larger static board with the name, the task and who is to move in
   words. No stepping through the solution in the first version. No rendered
   images.
4. **A wrong move in a line is „try again"**; the item counts as attempted and
   the report keeps the first verdict — which is what `recordPuzzleResult`
   already does (`attempted_at IS NULL` in its `WHERE`).
5. **The engine and the tablebase check an exercise when it is made**, not when
   it is solved: what they find becomes stored accepted moves, and the judge
   stays a comparison on the server. The one runtime check is decision 6.
6. **A game „for N moves" is judged by the position it reaches.** The server
   already replays the moves and owns the final FEN; with seven pieces or
   fewer it asks the tablebase, once, at the end. Pieces only leave the board,
   so whether an exercise can be judged this way is known when it is written.
   *Amended by the owner on 19.9.2026, after the live pass (§9): this holds for
   **Draw or better** only. On a **Win** the number means **checkmate in N
   moves** — mate on the board within N of the student's own moves, or the goal
   is missed. The owner read „Win, for N moves" as that the first time he saw
   it, and so will a student; and it is the variant that can be **verified**:
   the rules judge it alone, with no tablebase and no limit on pieces, so a
   trainer can set a middlegame to be finished in 25 moves, which the old
   reading refused. „Keep the win for N moves" is gone, not kept beside it.*
7. **No compatibility for homework already sent** (owner, 18.9.2026, when
   phase 1 started): the app is in testing, the owner is its only user on
   several accounts, and old homeworks may be deleted. So phase 3a renames
   `surviveMoves` rather than reading two spellings, and phase 4 removes the
   inline `engine_game` item rather than keeping two doors. **This does not
   cover the owner's scanned positions**, which are his material: their rows
   are read as they are (§4), and every migration stays additive, because
   nodemon runs `initDB` on every save.

## 3. What exists today, measured

Read on `master` at `612609d`.

| Asked for | State |
|---|---|
| Play against the engine: win, hold, survive N | Built (`services/engineGameTask.js`, `judgeEngineGame`). „Survive" means **not mated within N** and nothing more — a student may reach a lost ending and pass |
| A position with a solution | Built: `custom_puzzles.solution_san`, judged by `services/customPuzzleJudge.js` through `POST /assignments/:id/custom-attempt` (`routes/assignments.js:268`); the solution is released only after the answer |
| The trainer's own move as the solution | The judge exists; **the door does not**. `custom_puzzles` has two writers — `routes/scans.js:214` and `services/homeworkFromArchive.js:175`. Preparation's „Save position" (`chess_game_screen.dart:2079`) writes a `saved_lessons` row with `fen` + `pgn`, which nothing can judge |
| A series of moves | Only as a tutorial part. `solution_san` is `VARCHAR(20)` |
| Syzygy | `services/tablebaseService.js`: `probe(fen)` returns the category **and every legal move with its own category**, behind a permanent shared cache and a pacer; `endgameDrill.judgeMove` uses it. Not used by homework |
| Engine evaluation as a judge | Does not exist |
| The board in a list | `widgets/board_thumbnail.dart`, seven call sites, none in the Library |

`custom_puzzles` is already an exercise in everything but name: `fen`,
`side_to_move`, `solution_san`, `instruction`, `themes[]` (the labels),
`needs_review`. It lacks a name, a task, a line, and a stated origin — the id
prefix (`cust_`, `hw_`) says it today, and **a prefix is not a column**.

In a homework template a find-the-move position is a `positions` item
(`task.puzzleIds`) and a game is an `engine_game` item with its task written
inline in a dialog that takes a pasted FEN. Two doors, two shapes.

## 4. The exercise

One row in `custom_puzzles`, read through **one** function — `exerciseOf(row)`
in a new `services/exercise.js` — and nowhere else:

| Field | Column | Note |
|---|---|---|
| name | `name` (new) | shown in lists; falls back to the source label for scans |
| labels | `themes[]` | as today |
| origin | `origin` (new): `book`, `manual`, `mistakes` | backfilled once from what wrote the row; filters read this, never the id |
| task | `task` JSONB (new) | `{type:'find'}` or the `engine_game` task shape, read by the same `parseEngineGameTask` |
| solution | `solution` JSONB (new) | `[{accept:[san,…], reply:san|null}, …]`, one entry per move of the student |

**An old row is a find-the-move exercise with a one-step solution.**
`exerciseOf` reads `solution_san` as `[{accept:[solution_san], reply:null}]`
when `solution` is null; the column is not dropped and not backfilled, so
every row written before this plan is judged exactly as it was.

`assignableProblem` stays the one refusal and grows one case: a `find`
exercise with no solution, a game exercise whose task does not parse, a row
still marked for review.

### The line, and who judges it

The server has no PGN parser and must not grow one (rule 13). The app flattens
the trainer's tree into the `solution` JSON — main line, plus variations **at
the student's moves** as further entries in `accept` — and **reads its own
work back** by replaying it from the FEN before saving; a line that does not
replay is refused, as `saveCurrentPosition` already does. The server replays
the same JSON with the `chess.js` it already judges games with.

Judging is **per move, on the server**: the attempt route takes the moves
played so far and answers `{correct, reply, done}`. The solution never reaches
the student's device ahead of the answer. The verdict is written **once**, at
the first wrong move or at the end of the line, whichever comes first —
`attempted_at`, `solved` and `played_san`, as today — and later posts change
nothing in the report. A correct move in the middle of a line writes nothing:
a line half played is not an attempt, and must not read as one to the gate. Any checkmate is accepted where the line's own move
mates.

### The game, judged by where it ends

`engine_game` tasks gain „for N moves" for **win** as well as **hold**. *(As
built in 3a: the field keeps its name, `surviveMoves`, and `survive` stays a
goal — see the phase table for why. What follows is the plan as written.)*
`forMoves` on the task, replacing `surviveMoves`, and `survive` becoming
`hold` + `forMoves` (no old spelling is read — decision 7), in `parseEngineGameTask` and its mirror in
the app, both standing on the shared fixture
`docs/gates/engine_game_cases.json`.

When a game ends at the move target and the final position has seven pieces or
fewer, the route asks `tablebase.probe(finalFen)` and reads the category from
the student's side: *win* needs a win, *hold* needs anything but a loss;
cursed wins and blessed losses count as draws, because the fifty-move rule
makes them so. `judgeEngineGame` stays pure; the probe is the route's.

**Absence is a third answer.** A tablebase that does not answer leaves the
item *played, not judged*: moves stored, attempted for the gate, `solved`
null, `judged_by` null. It is judged on the next read of the homework by
either side. „Not judged yet" is shown to both; it must never read as failed.
`judged_by` (`rules`, `tablebase`, `device`) is written with every verdict and
shown to the trainer in the review.

With more than seven pieces the verdict is what it is today — not mated — and
the dialog says so when the exercise is written. Phase 6 replaces that.

**As amended 19.9.2026 (decision 6):** everything above about a *win* at a move
target no longer applies. `judgeEngineGame` never says `needsTablebase` for a
win, `goalMetByTablebase` throws if asked about one, `parseEngineGameTask` no
longer refuses a win with a number on a full board, and the app mirrors all
three (`engineGameVerdict`, `ExerciseJudge.mateInMoves`). The fixture's
`forMoves` half holds the rule on both ends: a checkmate in two missed with
three pieces on (where a tablebase *could* have been asked, and would have said
„won"), a mate given on move N itself, and a checkmate in N set on thirty-two
pieces.

## 5. What the trainer does

**Make.** Preparation gets one action beside „Save position": **Make
exercise**. The same sheet opens from the Library's Exercises chip („New
exercise", board set up in the existing setup dialog).

1. *What is asked?* — **Find the move(s)** · **Win** · **Draw or better**.
2. For *Find*: the solution is the line played on the board from the starting
   position. No line, no exercise — „play the solution on the board first".
   For a game: *How long?* — to the end / for N moves; the engine's strength;
   the side the student plays. The position comes from the board, so **the
   engine may be the one to move first** — the capability the pasted-FEN
   dialog lost on 18.9.2026.
3. Name, labels.
4. **The check, once, on save** (phase 5): with seven pieces or fewer the
   tablebase lists every move that keeps the result — „Kc6, Kd6 and Ke6 all
   win. Accept all?" — or says the task cannot be done („this is a drawn
   position; *Win* cannot be met"). Otherwise the device's engine says when it
   prefers another first move and offers to accept it too. What the trainer
   accepts is written into `accept`. The check advises; it never blocks a save.

**Use.** The homework editor's *Add* offers **a tutorial · exercises · a puzzle
set**. The exercise picker is one list with thumbnails and the two filters.
Under it the wire does not change: the find-the-move exercises picked together
are one `positions` item, each game exercise is one `engine_game` item whose
task is **copied** from the exercise — the snapshot rule, kept by construction.
The pasted-FEN dialog is removed from the editor once the sheet above can do
what it did.

## 6. What the student sees

The homework row names the goal, not the kind: „Find the move · 3 exercises",
„Win as White", „Draw or better for 4 moves, as Black". The solver plays a
line: the student's move, the reply, the next; a wrong move says so and gives
the move back. A game for N moves ends at N with one of three sentences —
met, not met, *not judged yet*.

## 7. Phases, each with its gate

Every brief carries: *if you believe a test in the gate is wrong, stop and say
so in the report — do not work around it.*

| # | Phase | Who | Gate |
|---|---|---|---|
| 1 | **Schema and the one reader**: `custom_puzzles.name/origin/task/solution`, the `origin` backfill, `services/exercise.js` (`exerciseOf`, `assignableProblem` moved in), every reader of `solution_san` moved onto it. Glossary row for **Exercise**. **Built 18.9.2026**, in a worktree, because the owner's nodemon runs `initDB` on every save: also `exerciseColumns()` — the SELECT fragment, so a consumer never names the column — `readSolution` (the line's replay, which phase 2a judges with), `firstMoveOf`, and `assignableProblem(row, { as })`, which refuses a game exercise as a find-the-move item **by default**, so the four paths that build puzzle-kind assignments cannot be handed one when phase 3 starts writing them. The gate as first written was too strong: the scan pipeline and the mistake archive are *writers* of `solution_san` and keep it; the guard is an allow-list with a reason per file | lead (schema, migration) | `test/exercise.test.js` (12), `exercise_schema.test.js` on a real PostgreSQL (5: NOT NULL without a default, the CHECK, the backfill with an `hwx…` id as the trap for an unescaped `_` in `LIKE`, and **both writers run against the real table**), `exercise_one_reader.test.js` (3, comments lexed out, SQL kept), one route test in `homework_gate.test.js`, one in `position_library.test.js`; 14 mutations, each red on the right test — three survived the first pass and are why the writer tests exist; backend 1503 → 1522 with the database, 1441 → 1454 without, no `.env` in the worktree |
| 2a | **The line, server half**: the per-move judge in `customPuzzleJudge.js`, the attempt route taking `moves`, `POST /exercises` and `PUT /exercises/:id` for hand-made ones (validating that the line replays). **Built 18.9.2026**: `judgeLine` judges **every** move in the list and goes on from the author's move (`continuesOn`); the route writes the verdict once — first wrong move or end of line — and a line never releases its answer, only the reply; `services/exerciseAuthoring.js` stores what the readers read back, not the payload, keeps an exercise's position for good (409), and answers 404 for „not yours"; also `GET /exercises/:id`, which the editor in 2b needs, and the whole line in the review under the same reveal rule as one move. 26 + 12 + 4 + 1 tests, 17 mutations each red on the right test, backend 1522 → 1565 with the database and 1454 → 1486 without. The wire 2b builds on is §7a | lead (the judge is authority) | shared fixture `docs/gates/exercise_line_cases.json` — lines with alternatives, a mate that is not the line's move, a line that does not replay, a reply that is illegal; route tests: the reply is released one move at a time and never ahead; first verdict survives a retry; a locked item still answers 423 before judging |
| 2b | **The line, app half**: *Make exercise* in Preparation; the tree flattened and read back; the solver playing a line with „try again". Narrowed 18.9.2026 so it stays one bounded job: the Library's door moves to phase 4 with the chip it belongs to, and a game exercise made from the board to 3b with the two questions it asks. Brief: `docs/briefs/BRIEF-EXERCISE-FAZA2B-APP.md`. The server gained one field for it, `retry`, so the solver is told a wrong move may be played again rather than inferring it from which fields are null. **Built 18.9.2026** by the implementer, graded and taken by the lead: gate byte-identical, nothing outside `chess_app/`, no new `// ignore`, `findMove` imported rather than copied, the label chips extracted from `SavePositionDialog` into `LabelChipInput` rather than duplicated. The worker's own mutation step found a real bug in its first pass — a retryable wrong move froze the board, because „first verdict recorded" and „board locked" shared one map | `[implementer]` | **Green**: 18 gate + 6 own, app 3053 → 3077, analyze the same 26 infos; 12 mutations by the lead, each red on the right test. The lead's gate file `docs/gates/exercise_make_test.dart` over the same fixture: writer → reader round trip, a variation at the student's move lands in `accept` and one at the opponent's does not, the sheet at 360 × 640, the action reachable from both doors; analyze list unchanged |
| 3a | **The final position, server half**: `forMoves`, the tablebase verdict in the game-result route, `judged_by`, *played, not judged* and its retry on read. **Built 18.9.2026.** The field was **not** renamed: it stays `surviveMoves` on the wire, now allowed on `win` and `hold` as well — the app in the tree reads and writes that name, and a rename bought a nicer word at the price of two ends that disagree until 3b. `win` for N moves is **refused** with more than seven pieces (nothing could judge it); `hold`/`survive` there stay „not lost", `judged_by = 'rules'`. `judgeEngineGame` stays pure and says `needsTablebase`; `recordEngineGameResult` asks, with three answers — met, not met, **no answer** (`solved` and `judged_by` NULL, attempted for the gate). Only `TablebaseUnavailable` is „no answer"; a fault throws and writes nothing. `getAssignmentDetail` asks again for anything waiting, by either side, and cannot be stopped by it. `childrenOf` sends `pending_items`, which 3b draws | lead | fixture extended: win/hold for N with ≤7 pieces, each category including cursed and blessed, a fake tablebase **client** that is unreachable, blocked, and late — asserting on the request; mutations on the side-to-move flip and on „unavailable reads as failed" |
| 3b | **Built 19.9.2026** by the implementer, graded and taken by the lead (gate byte-identical, nothing outside its files, 7 mutations each red on the right test). The worker **stopped on a contradiction in the brief** — „keep `engine_game_screen_test` unchanged" and the rule that breaks one of its cases — rather than weakening either; the lead re-aimed that test. **The final position, app half**: the two questions in the sheet, the sentence that says which judge this exercise will get, the three endings on the exercise screen | `[implementer]` | lead's gate file over the shared fixture; „not judged yet" drawn and not styled as a failure; existing `engine_game_screen_test` unchanged |
| 4a | **The Library's server half** (lead, 18.9.2026): `listScanned` sends `origin`, `task` (never the solution) and the exercise's name as `title`; the search reads the name; and the shelf asks `assignableProblem` *as what the exercise is* — with the find-the-move default every game exercise on it read „cannot be set". The two filters are the app's: the list is loaded whole | lead | 2 tests in `position_library.test.js`, 4 mutations each red on the right test |
| 4 | **Built 19.9.2026** by the implementer, graded and taken by the lead (gate byte-identical, nothing outside its files, 7 mutations: six red, one **survived** — nothing tested that a game exercise's board is turned to the student's side; `test/exercise_board_side_test.dart` now does). The pasted-FEN „play it out" dialog is gone from the homework editor with its tests; `fen_completion` stays, it has other readers. App 3083 → 3125 over both phases, analyze the same 26 infos. **The Library and the lists**: the chip renamed, the two filters, `BoardThumbnail` on position and exercise rows, the preview dialog, side to move in words; the homework editor's single exercise picker and the removal of the pasted-FEN dialog | `[implementer]` | pumped at 360 × 640 and landscape; the old chip label grepped out of the tests; a position offers no „add to homework"; a scroll check of a long list on the phone goes to the live pass, because a widget test cannot measure it |
| 5 | **Built 19.9.2026** by the implementer, graded and taken by the lead: gate byte-identical, nothing outside `chess_app/`, the two older sheet tests untouched, 9 mutations — eight red, one **survived** (a slow check answering after the trainer changed the task; `test/exercise_check_stale_test.dart` now covers it). The lead made the default checker **silent under `flutter test`**: sheet tests that pass no checker used to reach the real engine and network, and were green only because this workstation fails fast. App 3125 → 3157, analyze the same 26 infos. Not verified: the real tablebase and the real engine behind the check — only fakes ran. **The check on save**: tablebase moves into `accept`, the impossible-task warning, the engine's second opinion | `[implementer]` | fake tablebase and fake engine clients; the check failing or timing out never stops the save — proven by mutation |
| 6 | ~~The device's engine for larger positions~~ — **closed by the owner, 19.9.2026: not needed, will not be built.** Where no tablebase answers, *the trainer takes the engine's place and gives the verdict*: phase 9 puts the student's moves and the position reached in front of them, with the sentence „the position reached is yours to judge". A verdict from the student's own device was the part most likely to differ between a phone and a PC (§8.1), and it is the one the trainer's eye replaces | — | — |
| 7 | **Live pass** | owner | `TODO-provera.md`, items from 185. **Run 19.9.2026** on 185.1–5 and 186.1–2 plus two reports: §9 |
| 8 | **Checkmate in N, the task said everywhere, and the homework's own counts** (§9, findings 2 and 3). **Built 19.9.2026** by the lead: decision 6 as amended, on both ends and the shared fixture; the task's number in the homework row's title (`childTitle`), in the board's banner with the moves left (`engineGameGoalSentence`) and in the closing dialog (`engineGameEndingWords`); `child_total` / `child_completed` sent with a homework's detail, which had been read as „0 of 0 items" | lead | `engine_game_for_moves.test.js`, `homework_gate.test.js` (real database), `exercise_game_own_test.dart`, `exercise_task_words_test.dart`, `engine_game_goal_test.dart`; 8 mutations, each red on the right test. Live: item 189 |
| 9 | **What the trainer sees of a game** (§9, finding 1): the verdict on the row in words and shape, not the tick of „done"; the review of a game item showing **the moves the student played and the position reached** instead of the puzzle review's „correct 0 · board not available · viewed"; tapping the row opens that, not Analysis on the bare position. **This is also the judge of last resort** (owner, 19.9.2026): where no tablebase answers — more than seven pieces, or the service down — the trainer has the position and decides; it replaces most of what phase 6 was for. **Measured 19.9.2026: the moves, the ending, the judge and the verdict were all stored** (`assignment_items.game_moves / game_ending / judged_by / solved`) **and the review read none of them** — a game item has no puzzle id, so `shapeItem` shaped it as a lesson step with no step. No schema change. **Server half built 19.9.2026 (lead, `7065ab9`)**: the review sends `kind: 'game'` — the position given, the task in the shape `exerciseTaskWords` reads, the moves, the position they reach (replayed on the server; null when they do not replay), the ending, `judgedBy`, the verdict, and `pending`. The homework row needs nothing from the server: each child already carries its solved / attempted / pending / total counts and the row never said them. **App half built 19.9.2026** by the implementer in a worktree, graded and taken by the lead: gate byte-identical, three files touched and nothing else, no new `ignore`, the gate and nine neighbouring files green on master, the report's „what the brief got wrong" empty. Five mutations: four red on the right test, one **survived** — nothing checked that the two boards are turned to the side the student played; that was the gate's hole, not the worker's, and the gate now asks it (red under the mutation since). The review of a game is a card with the task in `exerciseTaskWords`' words, the verdict in `engineGameSaidWords`' words and the closing dialog's icon shapes, the moves numbered from the position (`gameMovesText`), „Start" and „Position reached", „Ended: …" from `engineGameEndingWords`, „Judged by …", and two honest sentences — *not judged yet* and *only „not checkmated" could be checked* — each ending „the position reached is yours to judge". The homework row says „Goal met" / „Goal not met" / „N of M correct" to both sides, and the trainer's tap on a played item opens the review. Live: item 190. Not in this phase: stepping through the student's moves on a live board (the first version shows the move text and the two boards) | lead, then `[implementer]` | `assignment_review.test.js` (5 pure, red first), `homework_gate.test.js` (1 on the real database, 2 mutations red); app: `homework_game_review_test.dart` |
| 10 | **The picker and the Exercises chip show exercises only** (§9, findings 5 and 6): rows the picker refuses („has no solution, so an answer cannot be judged") are not listed; and the chip's premise is re-measured — a scanned position with **no task and no solution** is read as „Find the move" by `exerciseAskOf`, so every scan passes as an exercise. Only a row with something to judge is one. **Measured and built 19.9.2026 (lead).** The owner's question — where did the scans get their exercise status — has two answers. A scan whose book **printed an answer** has been a real find-the-move exercise since phase 1 (`solution_san`, read by `exerciseOf`); those are right to be there. A scan **without** one was there only because `LibraryEntry.isExercise` was `kind == scan` and `exerciseAskOf` reads a task-less row as „find". The server already said everything needed on every row (`hasSolution`, `task`, `assignable`, `blockedReason`), so this is an app-only change with no restart: `isExercise` is now *a scan with a solution, or a game* — one home, asked by the chips, the picker, the row's subtitle and the preview. The Exercises chip shows exercises; a bare scan stands under **Positions**, its row naming its source and claiming no task; the homework picker lists exercises only. **Blocked-but-visible survives, narrowed**: an exercise *marked for review* still shows greyed with its reason, because that one is the trainer's to fix | lead | `test/exercise_shelves_test.dart` (6; five red on the old code, the sixth already true), 4 mutations each asserted to apply and each red on the right test. Six fixtures in four older files gained the `hasSolution` the real wire always carries. Live: item 191 |
| 11 | **Built 19.9.2026** by the implementer in a worktree, graded and taken by the lead: gate byte-identical, four files under `chess_app/lib` and two tests, no new `ignore`, the report's „what the brief got wrong" empty. **Grading found one fault and mutation two holes, all three in the lead's gate**: a game's board was turned by the side to move rather than by the side the student plays (the gate's game had Black for both); „the main move cannot be removed" stood on a line where removing it stops the line replaying, so the *reader* refused and the guard could be deleted unnoticed; and nothing looked at the board shown after a step is chosen, because the gate's moves go in through `onMove`. `test/exercise_edit_lead_test.dart` (4) now asks all three; 17 mutations, each red on the right test. App 3218 → 3257, analyze the same 26 infos. Live: item 192. **Open a saved exercise**: see its solution, add accepted moves, save over it (`PUT /exercises/:id` exists since 2a; nothing in the app calls it). The sheet also says, for a line, that a variation on the student's own move is an accepted alternative — it works (185.2) and nothing tells the trainer. **Decided with the owner 19.9.2026**: its own screen with a board — the line to step through, a move **played on the board** at the student's turn accepted as well, an alternative removable and the main move not — whose *Save* opens the sheet that exists, prefilled, which saves over the exercise; for **every exercise of mine**, hand-made or scanned with a printed answer (my trainer's and a bare scan open as before). **Measured before writing: no server change.** Phase 2a already tests `PUT` on a hand-made row and on a scanned one (`exercise_authoring.test.js`), and the server *allows* find → game; the app does not offer it, because a find exercise already sent is judged from this row one move at a time, while a game's task is copied into the homework when it is sent. So the kind is locked in the editor, the position is never sent, and what the sheet does not show (`thinkSeconds`) travels through. One reader: `ExerciseLineEdit` builds the candidate line and asks `ExerciseLine.read`; it has no rule of its own. Brief: `docs/briefs/BRIEF-EXERCISE-FAZA11-APP.md` | lead + `[implementer]` | `docs/gates/exercise_edit_test.dart` over the shared fixture — the pure edit (every chess claim in it run against the real reader first), the sheet in edit mode asserting on the `PUT` (no `fen`, the labels nobody touched, a game's answers sent back whole), the editor played through the board's own `onMove`, and the Library's door for a hand-made row, a scanned one and a trainer's. Red on master for one reason only: the three things it names do not exist |
| 12 | **Built 19.9.2026 by the lead, inline** — one parameter on the board and conditionals on four screens, cheaper done than briefed. Every item goes through one door (`assignmentItemScreen`) to four screens. `ChessBoardWithOverlay.copyPosition` (default true) closes the right click and Ctrl+C; **a closed board still takes its place on top of `BoardOnScreen` and says no there** — left out, Ctrl+C would be answered by whichever board lies beneath. The solver and the tutorial viewer pass false; tactics passes `!isAssignment`. „Play it out" with an `assignmentId` loses its three Analysis buttons, both engine panels and the engine-arrows switch of both menus, and registers a no-op for Ctrl+C (its own board never copied). The same game outside an assignment keeps all of it. Not decided: the doors stay closed after the game is judged. `test/homework_closed_doors_test.dart` (11, with controls), 15 mutations — one per door — each red on the right test. App 3257 → 3268, analyze the same 26 infos. Live: item 193. **The engine and „send to Analysis" are off while a homework item is open** (§9, finding 4). Cheap and worth doing; it does not stop a second device, which phase 9 answers better. **And the board gives no FEN away there** (owner, 19.9.2026): the right-click „copy FEN" on the board is off inside a homework item, so carrying the position to another screen means setting it up by hand | lead | `test/homework_closed_doors_test.dart` |

### 7a. The wire phase 2b builds on

`POST /exercises`, `PUT /exercises/:id` — body `{ name, fen, instruction?,
themes?, task, solution? }`; `task` is `{ type: 'find' }` with `solution:
[{ accept: [san, …], reply: san | null }, …]`, or `{ type: 'game', side, goal,
… }` as the engine-game task without its `fen`. `PUT` may omit `fen` and may
not change it. Answers `{ exercise: { id, fen, sideToMove, name, instruction,
themes, origin, task, solution, needsReview, assignable, blockedReason } }`,
201 on create; 422 with the reason when the line does not replay; 409 for a
changed position; 404 for „not yours" and „not there" alike. `GET
/exercises/:id` answers the same shape.

`POST /assignments/:id/custom-attempt` — body `{ puzzleId, moves: [san, …],
msTaken }`, the student's own moves so far (`moveSan` is still read as a line of
one). Answers `{ correct, reason, playedSan, done, step, reply, continuesOn,
solutionSan }`: `reply` is the one move the last right move earned;
`continuesOn` is the author's move to show first when an accepted alternative
was played; `solutionSan` is set only for a one-move exercise. A wrong move in
a line may be sent again; the report keeps the first verdict.

Both ends stand on `docs/gates/exercise_line_cases.json` — `judged` for the
solver, `refused` and `normalised` for the writer's read-back.

Order: 1 → 2a → 2b is the shortest path to something the owner can watch — a
hand-made exercise, sent and solved. 3 and 4 are independent of each other and
of 2b.

## 8. Open, and deliberately not decided here

*(§9, the live pass of 19.9.2026, is below this section.)*

1. **Phase 6 — closed 19.9.2026, not built: the trainer is the judge where no
   tablebase answers (§7, row 6). What follows is the reasoning as it stood.**
   The server has no engine, so a verdict for more than seven
   pieces means trusting the student's device: a fixed depth, a wide fixed
   margin (proposal: *hold* is no worse than −1.5, *win* no less than +1.5,
   from the student's side), `judged_by = 'device'`, and the trainer's review
   showing the final position so theirs is the last word. It is the part most
   likely to give different answers on a phone and a PC, which is why it waits
   for evidence that „not mated" is not enough.
2. **The tablebase as the opponent** in positions of seven pieces or fewer. An
   „Easy" engine gives the draw back and holding it proves little;
   `bestReply` in `tablebaseService.js` exists, and the endgame trainer plays it. It costs a request per move and a child
   waiting on a pacer. Not in this plan; ask again after the live pass.
3. **„Must be solved" and a failed first try — closed 18.9.2026: the switch
   is gone.** Measured in 2a, put to the owner as two options; the owner asked
   whether the switch was needed at all, and it was not. It was the one thing
   in a homework that could trap a student, the trainer's unlock existed
   largely to compensate for it, and the review already shows what was solved.
   Removed from the schema (both columns dropped), the rule
   (`childPassedSql` is `completed_at IS NOT NULL`), the editor and the
   student's screen. „Done" is *attempted*, everywhere. What follows is the
   reasoning as it stood. The first verdict is final, so
   a gated item with *done means solved* stays locked after one wrong move
   until the trainer opens it. That is today's behaviour for one move and the
   escape hatch exists, but a four-move line fails more often than one move.
   Measured 18.9.2026 (`homework_gate.test.js`, *measured for the owner*): the
   next item stays locked even after the student finishes the line on a second
   try. Either it stays so (the trainer's unlock is the way out), or, for lines
   only, „solved" comes to mean *finished the line*, however many tries — the
   report would still show that the first try failed.

## 9. The live pass of 19.9.2026

The owner ran 185.1–5 and 186.1–2 and filed two reports, as a student on a
phone and as the trainer on Windows (answers and screenshots in the QA tool,
outside the repo). 185.2, 185.3, 186.1 and 186.2 passed. **The machinery works;
what the pass found is that neither reader is told enough.**

1. **The trainer cannot tell a student who met every goal from one who met
   none.** Both homeworks read „3 of 3 items" with a tick, every row „Done":
   „done" is *attempted* (§8.3), and the verdict reaches the student's dialog
   and nowhere else. The review of a game is the puzzle review — „correct 0",
   „board not available", „viewed" — and tapping the row opens Analysis on the
   bare position. → phase 9.
2. **„0 of 0 items"** over a homework of three. The lists' query sends
   `child_total` and `child_completed`; the detail's did not, and the app read
   the absence as zero. → phase 8, built.
3. **The student is never told the number.** „Win to the end" and „Win, for N
   moves" were both the row „Play it out: win it" and the banner „White to
   move — win the game"; passing the number showed „Goal met — the number of
   moves to survive was reached". The judging was as decided (a win *kept*, by
   tablebase); the owner, like any student, read it as a mate to give. Decision
   6 amended; the words now come from one place per screen. → phase 8, built.
4. **The student can turn the engine on, or send the position to Analysis.** →
   phase 12, and phase 9 for what a switch cannot stop.
5. **The homework picker lists what it refuses** — a screen of scans marked
   „has no solution, so an answer cannot be judged" above the two rows that
   can be sent. The owner: a position gets its meaning by being put in an
   exercise, so it does not belong in this dialog at all. → phase 10.
6. **The Exercises chip is full of scanned positions**, and the hand-made
   exercise among them opens in Analysis like any position; a saved exercise
   cannot be opened, read or changed. → phases 10 and 11.
7. 185.1's wording is stale: the board editor has refused a position that is
   not chess since 19.9.2026, so „an empty board" cannot be reached. The item
   keeps its text (the QA tool matches answers by it) and is superseded by
   189. The owner's two questions there — how a position and its solving move
   are entered in one action, and how several solutions are — are answered by
   185.2 (play the line; a variation on the student's move is an alternative)
   and are phase 11's hint.
