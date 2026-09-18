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

`engine_game` tasks gain „for N moves" for **win** as well as **hold**:
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
| 2a | **The line, server half**: the per-move judge in `customPuzzleJudge.js`, the attempt route taking `moves`, `POST /exercises` and `PUT /exercises/:id` for hand-made ones (validating that the line replays) | lead (the judge is authority) | shared fixture `docs/gates/exercise_line_cases.json` — lines with alternatives, a mate that is not the line's move, a line that does not replay, a reply that is illegal; route tests: the reply is released one move at a time and never ahead; first verdict survives a retry; a locked item still answers 423 before judging |
| 2b | **The line, app half**: *Make exercise* in Preparation and in the Library; the tree flattened and read back; the solver playing a line with „try again" | `[implementer]` | the lead's gate file `docs/gates/exercise_make_test.dart` over the same fixture: writer → reader round trip, a variation at the student's move lands in `accept` and one at the opponent's does not, the sheet at 360 × 640, the action reachable from both doors; analyze list unchanged |
| 3a | **The final position, server half**: `forMoves`, the tablebase verdict in the game-result route, `judged_by`, *played, not judged* and its retry on read | lead | fixture extended: win/hold for N with ≤7 pieces, each category including cursed and blessed, a fake tablebase **client** that is unreachable, blocked, and late — asserting on the request; mutations on the side-to-move flip and on „unavailable reads as failed" |
| 3b | **The final position, app half**: the two questions in the sheet, the sentence that says which judge this exercise will get, the three endings on the exercise screen | `[implementer]` | lead's gate file over the shared fixture; „not judged yet" drawn and not styled as a failure; existing `engine_game_screen_test` unchanged |
| 4 | **The Library and the lists**: the chip renamed, the two filters, `BoardThumbnail` on position and exercise rows, the preview dialog, side to move in words; the homework editor's single exercise picker and the removal of the pasted-FEN dialog | `[implementer]` | pumped at 360 × 640 and landscape; the old chip label grepped out of the tests; a position offers no „add to homework"; a scroll check of a long list on the phone goes to the live pass, because a widget test cannot measure it |
| 5 | **The check on save**: tablebase moves into `accept`, the impossible-task warning, the engine's second opinion | `[implementer]` | fake tablebase and fake engine clients; the check failing or timing out never stops the save — proven by mutation |
| 6 | **The device's engine for larger positions** — optional, decided after the live pass of 1–5 (§8) | lead + `[implementer]` | — |
| 7 | **Live pass** | owner | `TODO-provera.md`, items from 185 |

Order: 1 → 2a → 2b is the shortest path to something the owner can watch — a
hand-made exercise, sent and solved. 3 and 4 are independent of each other and
of 2b.

## 8. Open, and deliberately not decided here

1. **Phase 6.** The server has no engine, so a verdict for more than seven
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
3. **„Must be solved" and a failed first try.** The first verdict is final, so
   a gated item with *done means solved* stays locked after one wrong move
   until the trainer opens it. That is today's behaviour for one move and the
   escape hatch exists, but a four-move line fails more often than one move.
   The brief for 2a measures it and brings the owner the choice rather than
   making it.
