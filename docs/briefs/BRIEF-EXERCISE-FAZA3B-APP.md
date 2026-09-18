# Brief — the exercise, phase 3b: a game exercise made from the board, and a verdict the app cannot give

`docs/PLAN-EXERCISE.md`, phase 3b. App only. **Do not touch**
`chess_backend/`, `db.js`, `.env`, `deploy/`, or anything in `docs/` other
than reading it. Do not start a server.

**Another worker is building phase 4 at the same time**, in another worktree.
Stay out of its files: `lib/features/library/**`,
`lib/features/homework/screens/homework_editor_screen.dart`,
`lib/features/homework/widgets/homework_item_pickers.dart`. If you believe you
need one of them, stop and say so in the report.

## Where this starts

The server half is finished (plan, phase 3a). Read `judgeEngineGame`,
`goalMetByTablebase` in `chess_backend/services/engineGameTask.js` and
`recordEngineGameResult` in `chess_backend/services/assignmentService.js`.

A game may now be asked **for N moves** with any goal — keep the win, or hold
the draw, for the student's next N moves. Such a game stops at the N-th move
with no result of its own, and is judged by **the position it reached**: with
seven pieces or fewer the server asks a tablebase. The app cannot ask one. So:

**The two facts that decide the work:**

1. **At a move target a tablebase will judge, the app does not know whether
   the goal was met — and must not say.** `ai_studio_screen.dart`'s
   `_finishEngineGame` shows „Goal met / Goal not met" from its own board and
   ignores what `POST /assignments/:id/game-result` answers. For these games it
   must wait for the answer and say the **server's** word, or „not judged yet"
   when the answer is `pending: true` or never came. Everywhere else it
   announces at once, as today.
2. **„Not judged yet" is not a failure.** The tablebase could not be reached;
   the game is recorded, counts as done for the gate, and is judged the next
   time anybody opens the homework. It is drawn as neither solved nor failed —
   and, the owner being colour-blind, **never by hue alone**: say it in words,
   with an icon of a different *shape* from the two verdicts.

The field is `surviveMoves` on the wire for every goal. It was not renamed; do
not rename it.

`lib/features/exercises/models/exercise_task_words.dart` already exists
(written by the lead, tested in `test/exercise_task_words_test.dart`):
`ExerciseAsk`, `exerciseTaskWords`, `exerciseForMoves`, `sideToMoveWords`,
`exercisePieceCount`, `tablebasePieces`, `ExerciseJudge`, `exerciseJudgeFor`,
`exerciseJudgeWords`. **Use it; do not word a task anywhere else.**

## What to build

**1. The model changes and the three small new things** the gate's header
states exactly: `EngineGameTask.fromJson`, `EngineGameVerdict.needsTablebase`,
`engineGameVerdict`'s move target for every goal, `engine_game_said.dart`,
`exerciseGameTask`, `HomeworkChild.pendingItems`.

**2. The exercise screen** (`lib/screens/ai_studio_screen.dart`). When
`verdict.needsTablebase`: send the result first, read the answer through
`EngineGameServerVerdict.fromJson`, and show the dialog with
`engineGameSaidWords(engineGameSaid(verdict, server))`. **Do the thing, then
say it**: the game is marked finished and the result sent before any dialog,
and a failure to send still ends the game on screen. The posting is a
top-level `http.post` today; the existing `test/engine_game_screen_test.dart`
shows how it is answered in a test — keep that test green unchanged.

**3. The sheet** (`lib/features/exercises/widgets/make_exercise_sheet.dart`)
asks **what** before anything else — three choices, in `ExerciseAsk`'s words:
*Find the move* · *Win* · *Draw or better*.

- *Find*: exactly what the sheet does today.
- *Win* / *Draw or better*: two more questions and nothing else new —
  **How long?** „To the end of the game" / „For N moves" (a small number
  field, 1–50); **The student plays** White / Black, *nothing pre-selected
  when the position does not decide it* — here it never does, so Save stays
  off until it is chosen (an answer offered in advance is an answer
  half-given; learned 18.9.2026 on the homework dialog). Engine strength:
  Easy / Medium / Hard (`lako` / `srednje` / `tesko`), Medium selected.
- Under the questions, one line: `exerciseJudgeWords(exerciseJudgeFor(...))`.
  When it is `refused`, Save is off — the server would refuse it.
- A game exercise needs **no line on the board**, only the position: the
  „play the solution first" refusal applies to *Find* alone. The position is
  `moveTree.root.fen` — the root, as everywhere in this feature.
- Save sends `ExerciseDraft(task: exerciseGameTask(...), solution: null)`.

**4. The homework row** (`homework_assignment_screen.dart`): a child with
`pendingItems > 0` says *„Played — not judged yet"* on its row, with the
shape rule above.

## The gate

`docs/gates/exercise_game_test.dart` → copy to `chess_app/test/`, green and
**unchanged**. It is red on master.

> If you believe a test in the gate is wrong, **stop and say so in the
> report** — do not work around it. A workaround that satisfies a test without
> satisfying the rule is worth less than a stopped batch.

## Your own tests — `chess_app/test/exercise_game_own_test.dart`

1. The sheet at `Size(360, 640)` and `Size(640, 360)`, *Win* chosen, „for N
   moves": no overflow, Save off until a side is chosen, the judge sentence
   present. Load the real font first (`loadRoboto`).
2. The sheet with an **empty tree**, *Draw or better*: Save works (no line is
   needed) and the request body is asserted on — `task`, no `solution`, the
   root's `fen`.
3. A position with more than seven pieces, *Win*, „for N moves": the refused
   sentence shown, Save off, **no request sent**.
4. The exercise screen with an assigned „win for 2 moves" game (the fixture's
   first `forMoves.judged` case): after the second move the request goes out,
   and the dialog says the server's word — once for `goalMet: true`, once for
   `pending: true` („not judged yet", and not the text „Goal not met"), once
   for a failed request. Assert the dialog is absent before the answer.
5. The homework row with `pending_items: 1` at `Size(360, 640)`: the words are
   there, scoped to that row.

Watch each new test fail once on wrong code before you believe it.

## Pass condition

```bash
cd chess_app && flutter test test/exercise_game_test.dart test/exercise_game_own_test.dart
cd chess_app && flutter test          # 3083 + yours, 1 skipped, 0 failed
cd chess_app && flutter analyze       # the same 26 infos, all curly_braces_in_flow_control_structures
```

Compare the analyze **list**; no new `// ignore`. **`dart format` can itself
create that info**: it splits a long `if (...) return x;` onto two lines
without braces. Format first, analyze after, and brace what it split. The
full suite is sensitive to load, and another worker is running beside you:
`game_tutorial_run_test` and `opening_book_service_test` time out under load
and pass alone — if one of those is red, re-run it alone before believing it.

## Report

Machine-checkable facts first: the three commands' last lines, files added
and changed, the count before and after, branch and commit. Then **„What the
brief got wrong"**. No prose about behaviour a test could state.
