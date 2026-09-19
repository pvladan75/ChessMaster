# Brief — the exercise, phase 11: open a saved exercise

`docs/PLAN-EXERCISE.md`, phase 11 (§9, finding 6). App only. **Do not touch**
`chess_backend/`, `db.js`, `.env`, `deploy/`, or anything in `docs/` other
than reading it. Do not start a server.

**Two rules about your own processes**: do not search the disk from `/` (or
`C:\`) — package sources are under the paths in
`chess_app/.dart_tool/package_config.json`; and **stop anything you start in
the background before you report**.

## Where this starts

A trainer makes an exercise in Preparation (`make_exercise_sheet.dart`) and it
lands in the Library under *Exercises*. From there it can be sent, and nothing
else: tapping the row opens **Analysis on the bare position**
(`library_screen.dart`, `_open`) — no solution to read, no way to change it.
The owner's live pass of 19.9.2026: *„a saved exercise cannot be opened, read
or changed."*

The server has had the whole of it since phase 2a — `GET /exercises/:id` and
`PUT /exercises/:id`, for hand-made rows and scanned ones alike — and the app
has had `ExerciseApiService.load` and `.update` since 2b. **Nothing calls
them.** This phase is the caller.

Decided with the owner, 19.9.2026:

- **Its own screen, with a board.** The solution is a line to step through; a
  move **played on the board** at the student's turn becomes an accepted
  alternative; an alternative can be taken back, the main move cannot. *Save*
  opens the sheet that already exists, prefilled, and the sheet saves over the
  exercise.
- **Every exercise of mine** — hand-made, and a scan whose book printed an
  answer (`LibraryEntry.isExercise`). My trainer's (`fromTrainer`) is not mine
  to edit and opens as it does today; so does a bare scan, which is a position.
- **The kind does not change.** A find exercise already sent is judged from
  this row, one move at a time; turning it into a game under a student's
  homework would leave them an item nothing can judge. A game may move between
  *Win* and *Draw or better*: a game's task is copied into the homework when it
  is sent, so an edit reaches only what is sent afterwards.
- **The position does not change** — the server answers 409. The editor never
  offers it, and an edit sends no `fen`.

**Use these; write no second one of any of them:**

| | |
|---|---|
| what an accepted move is | `ExerciseLine.read` (`models/exercise_line.dart`) — the app's copy of the server's `readSolution`, reason for reason. `ExerciseLineEdit` builds the candidate steps and asks it; it has **no** rule of its own about legality, duplicates or the limit of eight |
| a move by its squares or its SAN | `findMove` in `features/tutorial_studio/services/game_tutorial/board_queries.dart`; the Dart `chess` package refuses `Rd8` for `Rd8#` |
| the board | `ChessBoardWithOverlay` inside `BoardWithCoordinates`, as `custom_puzzle_solver_screen.dart` draws it (`_boardView`). Its `onMove(from, to, promotion)` is the seam the gate plays through |
| the line's text | `_solutionText` in the sheet — „1. Qh5 (or Qf3) g6  2. Qxe5+". The screen shows the same format: make it one function both read, do not write it twice |
| the form, the check, the save | `MakeExerciseSheet` — name, instruction, labels, the game's questions, phase 5's findings and *Accept*, the refusal shown in the server's words. The editor screen has none of these of its own |
| the game task's map | `exerciseGameTask` (`models/exercise.dart`) — it already takes `thinkSeconds` |
| feedback | `AppFeedback`, after the thing is done, never before |

## What to build

The gate's header states every signature and key. In short:

1. **`models/exercise_line_edit.dart`** — `ExerciseLineEdit`, pure.
2. **`MakeExerciseSheet.edit(...)`** — a second constructor beside the one that
   exists (which must keep working, with its tests, unchanged). Prefilled;
   titled „Edit exercise"; the kind locked; `api.update(id, draft)` with
   `fen: null`; pops with the saved `Exercise`. The phase-5 check runs in this
   mode exactly as it does when making one — over the steps it was given.
   In the **making** mode, under a find line that reads, one new sentence,
   exported as `kVariationHint`: that a variation played on the student's own
   move is accepted as an alternative. It works since 2b and nothing tells the
   trainer (owner, 185.1).
3. **`screens/exercise_editor_screen.dart`** — `ExerciseEditorScreen`. Loads;
   shows name, task in words (`exerciseTaskWords`), the board turned to the
   student's side, the line, the steps to choose from, the alternatives with
   their remove buttons, one sentence saying that a move played on the board
   is accepted as well, *Save*. Portrait and landscape
   (`LandscapeBoardLayout`, as the solver uses it). The board is for entering
   alternatives at the chosen step — it does not play the line forward.
4. **`LibraryScreen`** — the `exerciseApi` seam, the door in `_open`, a reload
   and „Exercise saved." after a saved edit. `BoardPreviewDialog`'s *Open*
   already calls the same `_open`; nothing to do there.

## The gate

`docs/gates/exercise_edit_test.dart` → copy to `chess_app/test/`, green and
**unchanged**. It is red on master (it does not compile: the three things above
do not exist).

> If you believe a test in the gate is wrong, **stop and say so in the
> report** — do not work around it. A workaround that satisfies a test without
> satisfying the rule is worth less than a stopped batch.

## Your own tests — `chess_app/test/exercise_edit_own_test.dart`

`MockClient`s that answer by path and method; assert on the request.

1. The editor with a **game** exercise and with a **one-move** exercise (no
   step to choose between) at `Size(360, 640)` and `Size(640, 360)`: no
   overflow, *Save* reachable. `loadRoboto` first.
2. A **promotion** as an alternative: a position where the main move promotes
   to a queen; `onMove(from, to, 'n')` adds the knight promotion as the board
   spells it. (Look at how the solver turns `promotion` into a move before
   writing your own.)
3. With **Black** to move in the exercise, the board is turned to Black and a
   move played lands as Black's.
4. **Cancel in the sheet loses nothing**: add an alternative, open the sheet,
   Cancel — the editor is still open and the alternative is still in the line;
   no `PUT` was sent.
5. **Leaving with an unsaved change asks first**; leaving with none does not.
6. In the Library, a **bare scan** (`hasSolution: false`, no game task) does
   not open the editor and asks for no `/exercises/…`.
7. The sheet in edit mode runs the check over the steps it was given: with a
   fake `ExerciseChecker` (fake askers under the real runner, as
   `exercise_check_own_test.dart` does) an *alsoKeeps* finding's *Accept* puts
   its moves into the `PUT`'s `solution[0].accept` after the ones already
   there.
8. The existing sheet tests — `exercise_make_own_test.dart`,
   `exercise_game_own_test.dart`, `exercise_check_own_test.dart`,
   `exercise_check_stale_test.dart` — stay green **unchanged**.

Watch each new test fail once on wrong code before you believe it.

## Pass condition

```bash
cd chess_app && flutter test test/exercise_edit_test.dart test/exercise_edit_own_test.dart
cd chess_app && flutter test          # 3218 + the gate's + yours, 1 skipped, 0 failed
cd chess_app && flutter analyze       # the same 26 infos, all curly_braces_in_flow_control_structures
```

Compare the analyze **list**; no new `// ignore`. `dart format` every Dart file
you edit — format first, analyze after: the formatter can itself create that
info by splitting a long `if (...) return x;` without braces. Run the full
suite with nothing else running: `game_tutorial_run_test` and
`opening_book_service_test` time out under load and pass alone — if one of
those is red, re-run it alone before believing it.

## Report

Machine-checkable facts first: the three commands' last lines, files added and
changed, the count before and after with the arithmetic, branch and commit,
and **a line confirming no background process of yours is left running**. Then
**„What the brief got wrong"**. No prose about behaviour a test could state.
