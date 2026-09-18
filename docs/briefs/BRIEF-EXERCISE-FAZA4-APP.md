# Brief — the exercise, phase 4: the Library tells an exercise from a position, and lists draw their boards

`docs/PLAN-EXERCISE.md`, phase 4. App only. **Do not touch**
`chess_backend/`, `db.js`, `.env`, `deploy/`, or anything in `docs/` other
than reading it. Do not start a server.

**Another worker is building phase 3b at the same time**, in another
worktree. Stay out of its files: `lib/screens/ai_studio_screen.dart`,
`lib/core/models/engine_game_task.dart`,
`lib/features/exercises/widgets/make_exercise_sheet.dart`,
`lib/features/exercises/models/exercise.dart`,
`lib/features/homework/models/homework_child.dart`,
`lib/features/homework/screens/homework_assignment_screen.dart`. If you
believe you need one of them, stop and say so in the report.

## Where this starts

The owner's rule: **a trainer does not send a position, they send an
exercise** — a position plus a task, with a name and labels. The server
already says so. `GET /library/positions` sends, for every row of kind
`scan` (the wire name stays `scan`): `title` (the exercise's name when it has
one), `origin` (`book` | `manual` | `mistakes`), `task` (`{type:'find'}` or the
game task **with its `fen`**), and `assignable` judged *as what the exercise
is*. Read `listScanned` in `chess_backend/services/positionLibrary.js`.

`lib/features/exercises/models/exercise_task_words.dart` already exists
(written by the lead): `ExerciseAsk`, `exerciseAskOf`, `exerciseTaskWords`,
`sideToMoveWords`. **Use it; do not word a task anywhere else.**
`lib/widgets/board_thumbnail.dart` already draws a static board from a FEN in
the reader's own skin, and is used on seven screens — none of them the Library.

**Three facts that decide most of the work:**

1. **There was never a „Scans" chip.** `LibraryChip.positions` holds *both* a
   saved position and a scanned one — „one kind to the reader". The owner has
   now said they are two kinds. So the chips become seven: **Exercises**
   (`{scan}`) after Tutorials, and **Positions** narrowed to `{position}`.
   Several tests assert the old set — `test/library_list_test.dart`,
   `test/room_library_test.dart`, `test/homework_editor_doors_test.dart`, and
   `docs/gates/library_list_test.dart` *(read-only for you; its copy in
   `test/` is yours to update)*. **A red test here is an earlier decision, not
   a stale one**: update each to the new rule, and leave a comment saying what
   superseded it (`docs/PLAN-EXERCISE.md`, decision 2, as amended 18.9.2026).
   Do not delete an assertion to get green; re-aim it.
2. **The room's column** (`lib/screens/chess_game_screen.dart`, grep
   `LibraryChip.positions`) lists `[all, tutorials, positions]`. A trainer
   loads a scanned position onto the room's board from there today; after the
   split that is an exercise. Add `LibraryChip.exercises` to that list, or the
   feature becomes unreachable from the room (CLAUDE.md rule 10).
3. **The owner is colour-blind.** Who is to move is said **in words**
   (`sideToMoveWords`), never as a coloured dot. A selected filter is told from
   an unselected one by more than hue — `ChoiceChip`/`FilterChip` with their
   check mark do this already; do not replace them with tinted containers.

## What to build

**1. The model**: `LibraryEntry.origin`, `.task`, `.isExercise`.

**2. The chips and the two filters.** When the Exercises chip is selected, a
second row appears under the chips: *what it asks* — `ExerciseAsk`'s three
labels — and *where it came from* — `ExerciseOrigin`'s three. Each row is
single-choice and may be cleared. They use `filterExercises`. They are not
drawn under any other chip. On a phone the rows must not push the list off the
screen: `Wrap`, and the header already scrolls with the list below
`LibraryList.headerScrollsBelow`.

**3. The boards.** Rows of kind `scan` and `position` lead with a
`BoardThumbnail` (about 56 px; wrap the row's board in a `RepaintBoundary` —
64 piece widgets per row in a long list), turned to the student's side for a
game exercise (`task['side'] == 'b'`). The other kinds keep their icon.
Tapping the board opens `BoardPreviewDialog`; tapping the rest of the row
opens the entry as today. An exercise's subtitle starts with
`exerciseTaskWords(entry.task)`.

**4. `BoardPreviewDialog`**: the name, the task in words *for an exercise only*,
`sideToMoveWords(entry.fen)`, a static board as large as the screen allows
(240–320 px on a 360-wide phone, from `MediaQuery`, never a fixed width), and
„Open" when `onOpen` was given.

**5. The same boards in `PositionPickerDialog`** rows — that is the dialog the
homework editor picks from.

**6. One door for exercises in the homework editor.** *Add* offers **A
tutorial · Exercises · A puzzle set** — three, not four. „Exercises" opens
`PositionPickerDialog(purpose: PickerPurpose.homework)`, which **for that
purpose lists exercises only** (kind `scan`): a bare position cannot be put in
a homework. What is chosen goes through `homeworkItemsFromExercises` and every
item it returns is added. „Play it out" and `pickEngineGameTask` leave the
editor — a game exercise is now made in Preparation (phase 3b) and picked
here. Delete `pickEngineGameTask` and its dialog if nothing else uses them
(grep first; `test/homework_play_it_out_fen_test.dart` and
`test/fen_completion_test.dart` test that dialog's FEN handling — if the
dialog goes, say in the report which of their tests went with it and which
still guard something that remains, e.g. `fen_completion`).
An `engine_game` item already in a saved homework still shows and still saves.

**7. A door to making one.** On the Exercises chip, the Library shows
**New exercise**, which opens Preparation (the studio room — find how
`TeachTab`'s „Preparation" card opens it, and use the same call). The sheet
that makes an exercise lives there; this is a door, not a second editor.

## The gate

`docs/gates/exercise_library_test.dart` → copy to `chess_app/test/`, green and
**unchanged**. It is red on master.

> If you believe a test in the gate is wrong, **stop and say so in the
> report** — do not work around it. A workaround that satisfies a test without
> satisfying the rule is worth less than a stopped batch.

## Your own tests — `chess_app/test/exercise_library_own_test.dart`

1. The Library list at `Size(360, 640)` and `Size(640, 360)` with the
   Exercises chip selected: both filter rows present, no overflow; selecting
   *Win* leaves only the win exercise's row; under the Positions chip the
   filter rows are **absent** (scope the finder to the list, do not weaken it).
2. `PositionPickerDialog` for `PickerPurpose.homework`: a position row is not
   offered; for `PickerPurpose.lesson` it still is. Thumbnails present.
3. The homework editor: *Add* shows three choices and no „Play it out";
   picking one find and one game exercise adds **two rows**, and the saved
   request body is asserted on — a `positions` item with the id, an
   `engine_game` item whose task has the exercise's `fen`, `side`, `goal`.
4. A homework that already holds an `engine_game` item opens, shows it, and
   saves it back unchanged.
5. The room's library column offers the Exercises chip.
6. „New exercise" is present under the Exercises chip and absent under others.

Watch each new test fail once on wrong code before you believe it.

## Pass condition

```bash
cd chess_app && flutter test test/exercise_library_test.dart test/exercise_library_own_test.dart
cd chess_app && flutter test          # 3083 + yours − any you removed with the dialog (say which), 1 skipped, 0 failed
cd chess_app && flutter analyze       # the same 26 infos, all curly_braces_in_flow_control_structures
```

Compare the analyze **list**; no new `// ignore`. **`dart format` can itself
create that info**: it splits a long `if (...) return x;` onto two lines
without braces. Format first, analyze after, and brace what it split. The
full suite is sensitive to load, and another worker is running beside you:
`game_tutorial_run_test` and `opening_book_service_test` time out under load
and pass alone — if one of those is red, re-run it alone before believing it.
After a rename, grep the old word in the tests (rule 5).

## Report

Machine-checkable facts first: the three commands' last lines, files added,
changed and **deleted**, the count before and after with the arithmetic,
branch and commit. Then **„What the brief got wrong"**. No prose about
behaviour a test could state.
