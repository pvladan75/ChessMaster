# Plan: homework — one container around everything a trainer sends

Written 17.9.2026 at the owner's request, as a proposal with three variants.
**Adopted the same day: variant A**, with the answers to §8 recorded in §9.
The phases in §7 are briefed one at a time, each with its gate; phase 0
started 17.9.2026.

## 1. The request

The owner, 17.9.2026 (paraphrased from Serbian): *until now a trainer sends a
student positions, exercises and tutorials as separate items. There should be
something that wraps them: a homework. The trainer creates it with a title and
instructions, puts into it everything they could send before, chooses and
changes the order the student sees the items in, and decides whether the
student may go on to the next item before finishing the previous one (watch
the tutorial first, then solve the positions). Be careful with one thing:
today a trainer can send a position, but there is no **task** — what should the
student do with it: find the best move, play it out against the engine, hold
the draw…* And, sent while the inventory was being taken: **creating a homework
and sending it to a student are two independent things.**

That last sentence decides the shape. A homework is an *artefact* the trainer
writes and keeps, like a tutorial; sending it is a separate act, repeatable,
to one student at a time or to several. The glossary already has both words:
**Assignment** is the thing sent (`assignments` on the wire), **Task** is what
one part asks. Homework is an assignment; a task is what each item in it asks.

`PLAN-ZAVRSNICA.md` froze new capabilities on 8.9.2026. This plan adds one —
a position played out against the engine, with a goal — and the owner's request
is the row being reopened, the way the reorganisation was.

## 2. What exists today, measured

Inventory taken on `master` after commit `948a0db` (file and line for every
row in the survey that produced this; the phase briefs quote what they need).

**Five ways to send, one table underneath.** Every path ends in one
`assignments` row — trainer, student, title, instructions, `kind`, due date,
`completed_at`, `reviewed_at` — and its `assignment_items`:

| Path | Trainer picks | `kind` | Items | Student's screen | Order |
|---|---|---|---|---|---|
| Puzzle drill | themes, count, rating range | `puzzles` | one row per Lichess puzzle | `TacticsTrainerScreen`, pending only | strict queue |
| Hand-picked positions (scans, Library) | student, title, note, due | `puzzles` | `cust_…` ids into `custom_puzzles` | `CustomAssignmentOverviewScreen` → solver | free (`solve_order.dart`) |
| Homework from the student's mistakes | student only | `puzzles` | `hw_…` ids, same table | same as above | free |
| Tutorial from the student page | one saved lesson, note, due | `lesson` | one row per step, `step_key` | `LessonViewerScreen` | linear, reopenable |
| Tutorial „Send" from the Library | one student | `lesson` | same | same | same |

`kind` is a two-value `CHECK` (`db.js:772`). `assignment_items.position`
„orders and nothing else" (`db.js:843`) since the `step_key` migration, whose
comment is the precedent for every ordering column here: **an index is never
an identity** — inserting a step once re-aimed a child's answers and SM-2
schedule at a different board.

**What does not exist.** No container above an assignment, no order between
assignments, no gate of any kind (the only gate in the product is
`review_items.due_at <= now`). No task on a position: a custom position is
always „find the move", judged against the scan's solution; a tutorial part
carries its own task (show / ask for a move / ask from a list). No way to send
a repertoire, an analysis or a recording. No group delivery — phase 8 of the
lesson plan (`assignments.group_id`, one click to a group) was cancelled by the
owner on 6.9.2026, and with it the question whether a group send costs one
quota unit or N. Quota is per `assignments` row, 5 a month on the free tier.

**What „done" means today.** Computed, never declared: `markCompleteIfDone`
is the single writer of `completed_at`, and it fires when no item has
`attempted_at IS NULL`. Accuracy is `solved / attempted`, null for lessons.

**Playing against the engine exists, on one screen.** The exercise screen
(`ai_studio_screen.dart`) plays mate-in-N, basic mates and „find the winning
path" against Stockfish at a level. *Correction, phase 0:* the first draft of
this paragraph said it detected checkmate and nothing else. It reads the
verdict through `drill_outcome.dart`, which already covered every draw by rule
via `chess.dart`'s `in_draw` — what it lacked was the **reason**, the move
limit and resignation, and it read the verdict only after the engine's move:
a reader who stalemated the engine got silence and the engine was asked to
move in a finished game. The opponent's strength and think time moved onto that screen on
17.9.2026 (`engine_opponent_sheet.dart`), with a note in the sheet that an
assigned game will carry its own strength and not offer the sheet.

## 3. The task on a position

This is the part the owner said to be careful with, so it comes before the
container. A position sent with no task is a board the student looks at.
Every item in a homework names its task, and the task decides three things:
what the student does, what counts as **done** (for the gate and for
`completed_at`), and what counts as **solved** (for the report).

| Task | On what | The student | Done | Solved |
|---|---|---|---|---|
| **Find the move** | a position with a solution (scan, custom) | plays one move | one attempt | move is the solution (existing judge) |
| **Play the line** | a tutorial part that asks for a move | plays the line, the part replies | the part is passed | every move right first time |
| **Answer** | a tutorial part that asks from a list | picks | picked | picked right |
| **Read** | a tutorial | steps through it | last part reached | its questions right |
| **Solve the set** | puzzle criteria or picked puzzles | solves each | every puzzle attempted | accuracy |
| **Play it out** *(new)* | any position, either side | plays against the engine at the trainer's level until the game ends | the game ended | the goal was met |

The goals of **Play it out**, for the first version: **win**, **hold** (a draw
or better), **survive** (do not lose within N of your moves). Mate-in-N stays
what it is on the exercise screen. Each goal needs the board to know the game
is over, which today it does not: a game verdict service — checkmate,
stalemate, threefold repetition, fifty moves, insufficient material, a ply cap
so a student cannot be held on a board for ever, and resign — is the first
thing built, on the shared board, with a table of positions that prove each
ending. The strength (Easy / Medium / Hard) and think time travel **on the
item**; the exercise screen reads them from the assignment and does not offer
the opponent sheet.

The owner's three examples — find the best move, play against the engine to
the end, hold the draw — are the first, sixth-win and sixth-hold rows. Others
that could follow, not in this plan: play a repertoire line from a given
position (needs a way to send a repertoire, which does not exist); annotate a
game in Analysis (needs a reader for the student's tree); reach an evaluation
(a number as a goal reads as a puzzle rating to a child — not proposed).

## 4. Three ways to build the container

### A — the homework is written once and sent as a set of assignments *(recommended)*

Two new tables for the artefact: `homeworks` (trainer, title, instructions)
and `homework_items` (`item_key` — a minted id, never an index — `position`,
`kind`, `task` JSONB, `gate` = „not before the previous is done",
`require_solved` = „done means solved, not attempted"). A homework is a Library
kind beside tutorials, scans and positions, made and edited from the Teach
tab.

Sending creates **one `assignments` row per item**, as it does today, plus a
**parent** row of `kind = 'homework'` that the children point at
(`assignments.parent_id`, `assignments.position`, `assignments.gate`). Every
student screen that exists — the tactics trainer, the custom overview and
solver, the lesson viewer — is opened exactly as now, from the child; the
homework screen is a list of its children with a state each: done, open,
locked *(„after: Watch the tutorial")*. `markCompleteIfDone` on a child asks
whether the parent is complete; nothing else changes underneath.

What is new: the two tables; the parent/child columns and the parent's
completion; the Library kind, its editor (a list with up/down, the pattern the
studio's Parts panel already has) and its „Send"; the homework screen on the
student side and its row in „My assignments" („2 of 5"); and the one new task,
Play it out, with its verdict service and its `kind = 'engine_game'`
assignment.

Why this one: the student's screens are untouched, which is where the tests
and the live checks are; a child assignment stays a plain assignment for the
trainer panel, notes and review; and the snapshot rule holds by construction —
a homework edited after it was sent does not change what was sent, because
what was sent are assignments. Quota is the question in §8.

### B — the homework is a tutorial with new kinds of parts

A tutorial already is an ordered list of parts, each with a task, edited in a
studio that reorders, clones and renames parts, sent from the Library, read in
a viewer that walks it in order and remembers where the reader stopped. Add
part kinds that carry no board of their own — *a puzzle set*, *a position
played out*, *another tutorial* — and the homework is a tutorial.

Cheapest to author, because the studio exists. But the studio is a board
editor and a puzzle set has no board; the viewer plays parts in one line and
would have to push other screens for the new kinds; and the vocabulary,
frozen on 6.9.2026, says a tutorial is *the* artefact — a tutorial containing
tutorials is the word coming apart. It also makes the gate a property of a
tutorial, which no existing tutorial wants. Not recommended.

### C — one assignment with mixed items

One `assignments` row per send, `assignment_items` grouped by a
`homework_item_key`, each group with its kind and task. Fewest rows, no
parent/child. But every student screen must learn to read one assignment
with mixed content, the three orderings that already exist over one
`position` column (queue, free, linear) would meet in one list, and the
custom solver, the tactics trainer and the lesson viewer each open today from
„an assignment", not „part of one". The cost lands on exactly the screens A
leaves alone. Not recommended.

## 5. What the trainer does (variant A)

**Teach → Homework** (a card beside Tutorials): the list of their homeworks;
*New homework*; a row opens the editor. The same list is the Library's
„Homework" chip. **The editor**: title, instructions, the items in order; *Add*
opens one sheet — *a tutorial* (mine), *positions* (my scans and saved
positions — each with its task: find the move, or play it out with a goal, a
side and a strength), *a puzzle set* (the criteria dialog as it is). Per item:
up / down / remove, the gate switch *„not before the previous is done"*, and
under it *„done means solved"*, off by default, with its warning (§6). **Send**,
from the row or the editor: student, due date, a note — the existing dialog.
Sent copies are listed under the homework („sent to Ana, 12.9, 3 of 5").

The homework made from a student's mistakes stays what it is — it is made *of*
one student and cannot be a template — but it can be added at send time as
an item („their own mistakes, up to N") if the owner wants; §8.

## 6. What the student sees, and the gate

„My assignments" shows a homework as one row with its progress; opening it
lists the items in the trainer's order — done ✓, open, locked with the name of
what unlocks it. Tapping an open item pushes the same screen as today; coming
back lands on the list with the next open item marked. Within a puzzle set
the order stays free, as `solve_order.dart` decided and for the same reason.

**The gate must not trap.** The lesson in `solve_order.dart` — homework that
cannot be finished does not get done — applies harder here, because a locked
item hides the rest. So *done* for the gate is **attempted** unless the trainer
says otherwise: a tutorial read to the end, a position answered once, a game
played to its end, a set with every puzzle tried. „Done means solved" is
offered per item, off by default, and the editor says beside it what it does:
*a student who cannot solve this cannot go on*. And the trainer can open a
locked item for one student from the review screen — a `gate_opened_at` on the
child, written by the trainer, is the escape hatch; the student sees the item
unlock and a note saying who opened it.

## 7. Phases, each with its gate

The order follows what can be watched running soonest. Every brief carries:
*if you believe a test in the gate is wrong, stop and say so in the report —
do not work around it.*

| # | Phase | Who | Gate |
|---|---|---|---|
| 0 | **Game verdict** on the shared board: mate, stalemate, repetition, fifty moves, insufficient material, ply cap, resign; the exercise screen's basic-mate and winning-path drills use it. **Built 17.9.2026** (lead, inline — smaller than a brief): `GameEnding`, `GameVerdict`, `verdictFor` in `drill_outcome.dart`, one rule with `outcomeFor` delegating; the exercise screen reads it after the reader's move too, names the draw in a dialog, and does not ask the engine to move in a finished game. No resign control yet — phase 2 adds it with the game it belongs to | ~~implementer~~ lead | a table of positions, one per ending, each proven to end and each of the others proven not to (`drill_outcome_test`, seven mutations); the exercise screen's existing tests unchanged; live: `TODO-provera` 181 |
| 1 | **Schema**: `homeworks`, `homework_items`, `assignments.parent_id/position/gate/gate_opened_at`, `kind += 'homework', 'engine_game'`; parent completion in `markCompleteIfDone`; `GET /assignments/:id` of a parent returns its children with state. **Built 17.9.2026**: also `assignments.homework_id/item_key/require_solved/task`, a shape CHECK, unique child position and item; the rule in `services/homeworkService.js` as SQL fragments interpolated into every reader *and* every answer-writing UPDATE; `POST /:id/open-gate`; a child cannot be withdrawn alone (409); lists, trainer panel and progress count a homework once; an item notifies nobody, the homework once | lead | `test/homework_gate.test.js` on a **real** PostgreSQL (24 tests: schema, gate, completion, readers, and the routes refusing a locked item before judging or revealing); 22 mutations, each red on the right test; backend 1412 → 1437 with the database, `.env` moved aside; CI gets a `postgres:17` service |
| 2a | **Play it out, the server half**: the task's shape and its verdict (`services/engineGameTask.js`), `assignment_items.game_moves/game_ending`, `POST /:id/game-result` judging the moves rather than trusting a verdict from the client. **Built 17.9.2026** | lead (schema, and the judge is authority) | `test/engine_game_task.test.js` over the shared fixture `docs/gates/engine_game_cases.json` (16 cases, 5 refusals, every position replayed on a real board) + 5 in `homework_gate.test.js` for the route; 24 mutations, each red on the right test; backend 1437 → 1470 with the database |
| 2b | **Play it out, the app half**: the task and its verdict in the app, the exercise screen playing an assigned game at *the task's* strength with the opponent sheet absent, ending by the verdict, posting the moves. **Built 17.9.2026** by the implementer; graded and merged by the lead, who corrected the gate (below) and fixed a portrait regression the work uncovered | implementer — brief: `docs/briefs/BRIEF-DOMACI-FAZA2-APP.md` | `docs/gates/engine_game_goal_test.dart` + `engine_game_screen_test.dart`: 37 tests, app 2906 → 2943, analyze 26 unchanged; four mutations on the lead's own fixes, each red on the right test |

**The gate was wrong, and the worker stopped rather than working around it.**
Its `rejected` loop asserted `EngineGameTask.fromJson` returns null for all
five refusals in the fixture, but the „illegal move" entry carries a task
**identical** to an accepted case — what is wrong with it is the move list,
which `fromJson` never sees. Corrected on the lead's side: the loop covers the
four „bad task" entries, a new test asserts both kinds are present (so neither
loop can pass by being empty), and the illegal move is asserted to be refused
by the board, which is the app's equivalent of the server's refusal.
| 3a | **Authoring, the server half**: `services/homeworkTemplate.js` and `routes/homeworks.js` — write, read, edit, withdraw; the item list reconciled by key (kept, minted, deleted) with `position` rewritten from the list; every task validated per kind, and what it points at checked as the trainer's own and usable. **Built 17.9.2026** | lead | `test/homework_template.test.js` on a real PostgreSQL: 16 tests, the phase's gate among them (a reorder keeps every key), plus the routes' status codes; 14 mutations, each red on the right test; backend 1470 → 1486 with the database |
| 3b | **Authoring, the app half**: model, API service, the editor with reorder and the two switches, and the doors — a Teach card and a Library door. **Built 17.9.2026** in `lib/features/homework/`; the Library's door is an `ActionChip` beside its six frozen chips, since a template has no FEN and is not a shelf entry. Graded here, with three corrections: the trainer picks the student's colour (§9 item 2 — the picker had read it off the FEN), a delete asks first and says the sent copies stay, and the gate's own unnecessary cast was removed | implementer — brief: `docs/briefs/BRIEF-DOMACI-FAZA3-APP.md` | `docs/gates/homework_editor_test.dart` green unchanged (12), the implementer's own 6 (both doors pumped at two sizes, one item of each kind, a refusal shown), my 5 on the three corrections, 4 mutations each red on the right test; app 2943 → 2966, analyze back to the 26 known infos |
| 4 | **Send**: one dialog → parent + children in one transaction, quota per §9; sent copies listed under the homework. **Built 17–18.9.2026**, both halves — the dialog (`widgets/homework_send_dialog.dart`, reachable from the list row and the editor's app bar) sends **one request per student**, offers only students who have accepted, and names any student the server refused without swallowing the ones it did not; the editor lists what has already gone out, read from each copy's own children: `services/homeworkSend.js` plans every item before it opens a transaction, resolves each item's content *now and for that student*, and copies the gates and keys; `POST /homeworks/:id/send` takes one student and therefore charges one unit, refunded on every way out that writes nothing | lead | `test/homework_send.test.js`: 12 tests — every kind arriving in order with its key and a working gate chain, one row in the student's list, two sendings independent, an edit to the template afterwards changing nothing, and four refusals that write **nothing at all**; plus `test/puzzle_resolution.test.js` (5) for a bug this phase found. 15 mutations, each red on the right test; backend 1486 → 1503 with the database |
| 5 | **Built 18.9.2026.** The student's homework screen and its row; the gate drawn, the escape hatch. Three things the reading turned up, all in the brief: `AssignmentApiService` calls the top-level `http` and gets a **client seam** first, or none of this can be tested; the decision „which screen does an item open“ moves into one function the router's three assignment routes also use; and the unlock goes on the homework screen rather than the review screen, because `buildReview` is built from `assignment_items` and a parent has none. **This phase is also the only door to phase 2b** — nothing in `lib/` opens an assigned game today | implementer — brief: `docs/briefs/BRIEF-DOMACI-FAZA5-APP.md` | `docs/gates/homework_student_test.dart` green unchanged (15), the implementer's own 6, and 7 from grading: three answers from `fetchDetail` (the server sends **423** for a locked item, which the brief got wrong), the trainer not told „your trainer“ unlocked it, a child's review reachable, and one wording for „how far“. 6 mutations red on the right test; app 2966 → 2994 |
| 6 | **Live pass** | owner | `TODO-provera.md` items |

Phases 1–5 each add a row to `docs/GLOSSARY-EN.md` where they add a word;
*Homework* and *Task* are already there.

## 8. Questions for the owner

1. **Sending to several students at once.** Variant A makes it one dialog with
   a student list — but each student costs one quota unit per *child*, or per
   *parent*? The 6.9.2026 cancellation closed „one or N" by removing the
   feature; this reopens it. Proposal: **one unit per parent per student**,
   so a five-item homework to one student costs what one assignment costs
   today, and to three students costs three.
2. **Play it out, first goals**: win, hold, survive N — all three, or fewer?
   And who picks the side: the position's turn, or the trainer?
3. **„Done" for the gate**: attempted by default, solved on request (§6) — or
   solved always, with the escape hatch doing the rest?
4. **The student's own mistakes as an item** at send time, or left as the
   separate path it is?
5. **Where the trainer finds it**: Teach → Homework card plus a Library chip,
   as §5 says — or Library only?

## 9. Decisions — owner, 17.9.2026

Variant **A**. And, question by question:

1. **Quota**: one unit per student for the whole homework — the parent row —
   whatever the number of items inside. The children cost nothing.
2. **Play it out**: all three goals, win / hold / survive N. **The trainer
   picks the side** the student plays; the engine takes the other.
3. **The gate**: „done" is *attempted* by default; „must be solved" is the
   trainer's option per item; manual unlock is the escape hatch. As §6.
4. **The student's own mistakes** stay the separate path they are. Not in the
   template.
5. **Access**: a card on the Teach tab and a filter chip in the Library.

Phase 0 may start.

