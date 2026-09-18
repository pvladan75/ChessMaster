# Brief — the exercise, phase 2b: made in Preparation, solved as a line

`docs/PLAN-EXERCISE.md`, phase 2b. App only. **Do not touch**
`chess_backend/`, `db.js`, `.env`, `deploy/`, or anything in `docs/` other
than reading it. Do not start a server; every test here answers `http` itself.

## Where this starts

A trainer does not send a position, they send an **exercise**: a position plus
a task. The server half is finished (phases 1 and 2a) and is not yours to
change. Read §7a of the plan — it is the whole wire — and these two files:

| | |
|---|---|
| `chess_backend/services/exercise.js` → `readSolution` | the rules a solution must keep, and the **exact words** of each refusal. Your reader repeats both |
| `chess_backend/services/customPuzzleJudge.js` → `judgeLine` | how an answer is judged: every move in the list, one reply released at a time, the line going on **from the author's move** even after an accepted alternative (`continuesOn`) |

Both ends stand on one fixture, `docs/gates/exercise_line_cases.json`.

**Three facts that decide most of the work:**

1. **The Dart `chess` package is stricter than the server's chess.js.**
   `Chess.move('Rd8')` answers **false** when the move's real spelling is
   `Rd8#`; chess.js plays it. Measured 18.9.2026. A trainer's line and the
   fixture both contain moves written without their `+`/`#`, so the reader
   must find the legal move by SAN **with the decoration stripped** and then
   spell it as the board does. `findMove` in
   `lib/features/tutorial_studio/services/game_tutorial/board_queries.dart`
   already does exactly this. Use it (move it to `lib/core/` if the import
   direction bothers you, leaving a re-export) — **do not write a second one**.
2. **The line starts at the tree's root, never at `tree.current`.** On
   6.9.2026 a lesson step took its `fen` from the current node and its line
   from the root, saved a line that could not be replayed, and said „saved"
   (CLAUDE.md, „The recurring bug"). `ExerciseLine.fromTree` reads
   `tree.root.fen` and `tree.root.children`, and **reads its own work back**
   through `ExerciseLine.read` before returning it.
3. **The report keeps the first verdict.** A wrong move in a line may be played
   again (`retry: true`), and the student may then finish the line — but the
   item was answered wrongly, and stays so. Whatever the solver keeps per
   position (`_answered`, `onAnswered`) is written at the **first** verdict —
   the first wrong move, or `done` — and not overwritten by a later success.

## What to build

**1. The models and the reader/writer** — `lib/features/exercises/models/`,
shapes exactly as the gate's header states them: `ExerciseStep`, `Exercise`,
`ExerciseDraft`, `ExerciseLineReading`, `ExerciseLine.read`,
`ExerciseLine.fromTree`, `ExerciseLinePlay`.

`fromTree`, precisely: walk the main line (`children.first`) from the root.
Moves at even depth (0, 2, …) are the student's; at each of those, the other
children of the same parent are **accepted alternatives**, in tree order after
the main move. Moves at odd depth are replies; other children there are
ignored and **counted** (`ignoredReplies`). A main line that ends on a reply
loses that reply (`droppedReply: true`) — a line ends on the student's move.

**2. `ExerciseApiService`** — `lib/features/exercises/services/`, with the
client seam every newer service here has (`HomeworkApiService` is the pattern).
A refusal (422, 409) is returned **in the server's words** with its status;
it is not swallowed into `null`.

**3. `submitCustomAttempt` takes `moves`**, and `CustomAttemptResult` gains
`done`, `retry`, `reply`, `continuesOn`, `step`, with the defaults the gate's
header names. Update every caller.

**4. „Make exercise" in Preparation.** Beside „Save position" in
`lib/screens/chess_game_screen.dart` (the studio room; grep `'Save position'`),
one action: **Make exercise**. It opens a dialog or sheet —
`lib/features/exercises/widgets/make_exercise_sheet.dart` — that shows:

- the task, said as a fact: **Find the move** (one step) or **Find the moves**
  (more). Only this task in this phase; the game tasks are phase 3b.
- the solution as the trainer will recognise it, read from
  `ExerciseLine.fromTree(moveTree)`: the moves, alternatives in brackets —
  e.g. `1. Qh5 (or Qf3) g6  2. Qxe5+`.
- when `droppedReply`: *„The last move is the opponent's and is not part of
  the solution."* When `ignoredReplies > 0`: *„Variations at the opponent's
  moves are not used."* Said, not hidden.
- when the reading is not ok (no moves on the board): the reason, and **no
  Save**. „Play the solution on the board first."
- name (required), instruction (optional), labels (the chip input
  `SavePositionDialog` already has — reuse it, do not copy it).

Save calls `ExerciseApiService.create`. **The sheet returns its result to the
caller and the caller says it** through `AppFeedback` — a dialog that pops
itself and then calls `AppFeedback` says nothing, because the guard sees a dead
context (learned in homework phase 4). A refusal from the server is shown in
the sheet, in the server's words, and the sheet stays open.

Vocabulary is `docs/GLOSSARY-EN.md`: **Exercise**, **Task**, **Trainer**,
**Student**. Never „puzzle" for this, never „child".

**5. The solver plays a line.** `custom_puzzle_solver_screen.dart` keeps an
`ExerciseLinePlay` per position:

- a right move that does not finish: the board goes to `play.fen` (the
  author's move when `continuesOn` is set, then the reply) and the student
  moves again. Say so in words — *„Correct. Keep going."*
- a wrong move with `retry`: the board goes back to `play.fen`, *„Not that
  move. Try again."* No solution is shown; the server sent none.
- `done`, or a wrong answer without `retry` (a one-move exercise): the verdict
  as the screen shows it today, solution and all.

**Do the thing, then say it**: the board is put right before any message is
shown, and every message goes through `AppFeedback` or plain widgets in the
tree — never a raw `ScaffoldMessenger`.

## The gate

`docs/gates/exercise_make_test.dart`. Copy it to `chess_app/test/` and leave it
there **green and unchanged**. It is red on master: the files do not exist.

> If you believe a test in the gate is wrong, **stop and say so in the
> report** — do not work around it. A workaround that satisfies a test without
> satisfying the rule is worth less than a stopped batch.

## Your own tests, in a second file

`chess_app/test/exercise_make_own_test.dart`, covering what the gate cannot
reach:

1. **The door is reachable**: pump the studio room (or the smallest widget
   that holds its controls — say which and why) and find „Make exercise";
   tapping it opens the sheet. CLAUDE.md rule 10: every layer can be right and
   the feature unreachable.
2. The sheet at `Size(360, 640)` **and** landscape `Size(640, 360)`, with a
   two-move line with an alternative: no overflow, the solution text present,
   Save enabled only once a name is typed. Load the real font first
   (`loadRoboto` — grep the test helpers; a missing font was once reported as
   a „pre-existing overflow").
3. The sheet with an empty tree: the reason shown, no Save.
4. A 422 from a `MockClient`: the server's words shown, the sheet still open,
   and **the request asserted on** (rule 7).
5. The solver through the real screen with a `MockClient`: a right move, a
   wrong move, the right move — assert the three request bodies' `moves`
   (`['Qh5']`, `['Qh5','Qxh7']`, `['Qh5','Qxe5+']`), that the board after the
   wrong move is the board before it, and that `onAnswered` fired **once**,
   with `false`. Driving the board: if there is no way to play a move in a
   widget test, add the smallest `@visibleForTesting` hook and say so.

Watch each new test fail once on wrong code before you believe it.

## Pass condition

```bash
cd chess_app && flutter test test/exercise_make_test.dart test/exercise_make_own_test.dart
cd chess_app && flutter test          # 3053 + the new ones, 1 skipped, 0 failed
cd chess_app && flutter analyze       # the same 26 infos, all curly_braces_in_flow_control_structures
```

Compare the analyze **list**, not the exit code; no new `// ignore`. Run
`dart format` on every Dart file you touch. Run the full suite with nothing
else running: `game_tutorial_run_test` and `opening_book_service_test` time
out under load and pass alone — if a red appears, read *which* test.

## Report

Machine-checkable facts first: the three commands' last lines, the files
added and changed, the count before and after. Then a section titled **„What
the brief got wrong"** — read first by the lead. Do not describe behaviour in
prose where a test could state it.

## Traps measured in this repository

- A release build paints no overflow; a widget test at 360×640 throws. Where a
  row can grow, `Wrap`.
- A widget that takes optional callbacks draws only what it was given — if the
  door is a callback into a shared strip, check every screen that builds the
  strip.
- An assertion of absence is a claim about the whole screen; scope the finder.
- `Icons.*` newly referenced can come out blank on Windows from a stale icon
  font — not a test matter, but prefer an icon the app already uses.
