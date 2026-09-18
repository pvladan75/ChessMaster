# Brief — the exercise, phase 5: the check on save

`docs/PLAN-EXERCISE.md`, phase 5, decision 5. App only. **Do not touch**
`chess_backend/`, `db.js`, `.env`, `deploy/`, or anything in `docs/` other
than reading it. Do not start a server.

**Two rules about your own processes**, both learned from the last batch: do
not search the disk from `/` (or `C:\`) — the package sources you may want are
under `chess_app/.dart_tool/package_config.json`'s paths; and **stop anything
you start in the background before you report**. A worker left a whole-disk
`find` running for two hours after it had finished.

## Where this starts

A trainer makes an exercise in Preparation (`make_exercise_sheet.dart`): a
position plus a task, *Find the move(s)* with a line played on the board, or a
game — *Win* / *Draw or better*. The server judges a student's answer by
comparing it with **stored accepted moves**; nothing is evaluated when the
exercise is solved. So whatever a tablebase or an engine knows has to be asked
**when the exercise is made**, put to the trainer, and written into the
solution only if the trainer says so.

Everything the check needs already exists in the app. **Use these; write no
second one of any of them:**

| | |
|---|---|
| the tablebase | `SyzygyTablebaseService.instance.lookup(fen)` → `SyzygyResult?` (`features/analysis_studio/services/syzygy_tablebase_service.dart`). Null when it cannot be reached. **`SyzygyResult.fromJson` sorts `moves`, best for the mover first** — do not rely on the wire's order. A move's `category` is the *opponent's*, who is to move after it |
| the engine | `StockfishService.analyzePositionSync(fen, depth:, multiPV:, timeout:)` → `List<AnalysisLine>`, `bestMoveSan` per line, `evaluation` a string **from White's side** |
| reading an evaluation | `parseEval` in `features/position_scanner/services/side_proposal.dart` — null for what it cannot read, and null must stay „say nothing" |
| finding a move by SAN | `findMove` in `features/tutorial_studio/services/game_tutorial/board_queries.dart` — the Dart `chess` package refuses `Rd8` for `Rd8#`; this does not |
| piece count, task words | `exercise_task_words.dart` (`exercisePieceCount`, `tablebasePieces`, `exerciseAskOf`) |

**The two rules above all others:**

1. **The check advises; it never blocks a save.** It runs while the trainer
   fills in the name. Save is enabled the moment it would be without the
   check. A tablebase that does not answer, an engine that throws or never
   comes back, is „nothing found" — and the sheet must not show a spinner that
   never ends: when the check gives up, the line that said „Checking…" goes.
2. **A finding is never applied by itself.** A finding that offers moves has
   one button, *Accept*; pressing it calls `acceptFinding` and the solution
   text in the sheet updates. A finding that only warns has no button.

## What to build

**1. `lib/features/exercises/models/exercise_check.dart`** — pure, no I/O,
exactly as the gate's header states: `ExerciseFinding`, `studentFens`,
`tablebaseFindings`, `gameFinding`, `engineFinding`, `acceptFinding`,
`maxAcceptedMoves`, `enginePrefersByPawns`.

Words, in the trainer's terms — name the moves, never a category or a number
of centipawns: *„Kd6 and Ke6 also keep the win. Accept them?"*, *„Your move Kc4
lets the win go."*, *„10 moves keep the win here — too many to accept; this may
not be an exercise."*, *„With best play this position is a draw, so ‚Win'
cannot be met against a perfect defence."*, *„The engine prefers Bb5 to your
Bc4. Accept it too?"*

**2. `lib/features/exercises/services/exercise_checker.dart`** — the runner,
with the two askers injected (`TablebaseAsk`, `EngineAsk`). Its defaults wrap
the two real services above; engine depth 18, `multiPV: 3`. It never throws and
never outlasts its timeout.

**3. The sheet** takes an optional `ExerciseChecker checker` (defaulting to the
real one) and starts the check when it opens and again when the task changes.
Findings are listed under the solution, each with its words and, when it
offers moves, *Accept*. For a game exercise the one possible finding is the
warning. The check is for the *current* choice: a finding from „Win" must not
still be showing under „Draw or better".

## The gate

`docs/gates/exercise_check_test.dart` → copy to `chess_app/test/`, green and
**unchanged**. It is red on master.

> If you believe a test in the gate is wrong, **stop and say so in the
> report** — do not work around it. A workaround that satisfies a test without
> satisfying the rule is worth less than a stopped batch.

## Your own tests — `chess_app/test/exercise_check_own_test.dart`

Every one with a fake `ExerciseChecker` (fake askers under the real runner —
fake the client, not the method) and a `MockClient` for the save:

1. The sheet at `Size(360, 640)` and `Size(640, 360)` with an *alsoKeeps*
   finding: no overflow, the words present, *Accept* present. Load the real
   font first (`loadRoboto`).
2. Pressing *Accept*, then Save: the request body's `solution[0].accept`
   carries the accepted moves **after** the main move. Without pressing it,
   it does not. Assert on the request.
3. **Save is not held up**: with askers that never answer, Save is enabled as
   soon as the name is typed, the save goes through, and no „Checking…" is
   left on screen once the checker's timeout has passed.
4. A warning (`mainMoveLetsGo` or `taskImpossible`) shows its words and **no**
   *Accept*; Save still works.
5. Switching the task from *Win* to *Draw or better* drops the *Win* finding.
6. The existing sheet tests — `test/exercise_make_own_test.dart`,
   `test/exercise_game_own_test.dart` — stay green **unchanged**. They build
   the sheet without a checker; if the default checker would reach the network
   or start an engine in a test, that is a fault in the default, not in those
   tests: make the default safe to construct and inert until asked, and give
   those tests nothing to wait for. If you cannot keep them unchanged, stop
   and say so.

Watch each new test fail once on wrong code before you believe it.

## Pass condition

```bash
cd chess_app && flutter test test/exercise_check_test.dart test/exercise_check_own_test.dart
cd chess_app && flutter test          # 3125 + yours, 1 skipped, 0 failed
cd chess_app && flutter analyze       # the same 26 infos, all curly_braces_in_flow_control_structures
```

Compare the analyze **list**; no new `// ignore`. `dart format` can itself
create that info by splitting a long `if (...) return x;` onto two lines
without braces: format first, analyze after, brace what it split. Run the full
suite with nothing else running: `game_tutorial_run_test` and
`opening_book_service_test` time out under load and pass alone — if one of
those is red, re-run it alone before believing it.

## Report

Machine-checkable facts first: the three commands' last lines, files added
and changed, the count before and after with the arithmetic, branch and
commit, and **a line confirming no background process of yours is left
running**. Then **„What the brief got wrong"**. No prose about behaviour a
test could state.
