# Brief — homework, phase 5: what the student sees, and the gate drawn

`docs/PLAN-DOMACI-ZADATAK.md` §6, phase 5. App only. **Do not touch**
`chess_backend/`, `db.js`, `.env`, `deploy/`, or anything in `docs/` other
than reading it.

## Where this starts

The server half is finished and is not yours to change. It already sends
everything this phase draws:

| | |
|---|---|
| `GET /assignments/mine` | one row per homework, children excluded (`parent_id IS NULL`), with `child_total` and `child_completed` |
| `GET /assignments/:id` | a parent of `kind: 'homework'` carries `children`, in `position` order, each row as `homeworkService.childrenOf` selects it: snake_case, with `passed`, `locked` and `blocked_by` |
| `POST /assignments/:id/open-gate` | the trainer unlocks one child for one student. 404 covers „not yours", „not an item" and „already open" alike |
| 423 | any route that judges or reveals a locked item refuses it, with `{error, locked: true, blockedBy}` — the gate holds on the server, not only on the screen |

Read `chess_backend/services/homeworkService.js` (the three SQL fragments and
`childrenOf`) before you start. You do not need a running server or a
database: every test here answers `http` itself.

**Two facts that decide most of the work:**

1. **`blocked_by` is an id** — the id of the item directly before this one,
   not its position and not its title. The student has to be told which item
   holds theirs shut, *by name*, so the screen resolves that id against the
   children it already holds. The gate's fixture numbers its items 501–503
   against positions 0–2 precisely so that a lookup by index cannot pass.
2. **Nothing in `lib/` can open an assigned game today.** Phase 2b built the
   screen (`AiStudioScreen` with `engineGameTask`) and the server's judge, and
   the only caller in the repository is a test. A „play it out" item exists
   only inside a homework, so **this phase is the door** — CLAUDE.md rule 10,
   and the reason one of the gate's tests is about exactly that push.

## What to build

**0. A client seam on `AssignmentApiService`** (do this first; everything else
rests on it). It calls the top-level `http.get`/`http.post` directly today, so
no test can answer it — which is why none of these flows has ever been tested.

```dart
AssignmentApiService({required this.authToken, http.Client? client})
    : _client = client ?? http.Client();
```

Route **every** request in that file through `_client`. It is mechanical and
must change no behaviour; the existing suite is the check. Add one method:

```dart
/// Null when the item was unlocked, the server's own sentence when not.
Future<String?> openGate(int assignmentId)   // POST /assignments/:id/open-gate
```

**1. The model** (`lib/features/assignments/models/assignment.dart`):

- `enum AssignmentKind { puzzles, lesson, homework, engineGame }`, read from
  the wire spellings `lesson` / `homework` / `engine_game`; anything else stays
  `puzzles`, as now.
- `Assignment.trainerId`, `.childTotal`, `.childCompleted`, `.isHomework`.
- `progress`, for a homework, counts children (`childCompleted / childTotal`,
  0 when there are none): a parent has no `assignment_items` at all, so the
  item-based number would read every homework as 0.
- `AssignmentDetail.children` → `List<HomeworkChild>`, empty for anything that
  is not a homework.

**2. `HomeworkChild`** — `lib/features/homework/models/homework_child.dart`:
`id, title, kind, position, itemKey, lessonId, gate, requireSolved,
gateOpenedAt, completedAt, task, totalItems, attemptedItems, solvedItems,
passed, locked, blockedBy`, plus `state` (`HomeworkChildState.done / open /
locked`) and `openedByTrainer`. `fromJson` refuses a row it cannot read
(no id, no kind) rather than guessing — an item nobody can open must not be
drawn as an item.

**Done wins over locked.** The server cannot send both (`childLockedSql`
requires `completed_at IS NULL`), and the ordering still has to be right:
that exact mistake survived a mutation in the server's own tests in phase 1,
and a finished item drawn as a locked one is the worst of the three states to
get wrong.

**3. `HomeworkAssignmentScreen`** —
`lib/features/homework/screens/homework_assignment_screen.dart`:

```dart
HomeworkAssignmentScreen({
  super.key,
  required UserSession session,
  required int assignmentId,
  AssignmentApiService? api,   // the seam, as everywhere else
})
```

The homework's title and note, `1 of 3 items`, then the items in the
trainer's order, each row carrying its state, and:

- **open** → tapping it opens the screen for its kind (below);
- **locked** → not tappable, and the row says which item unlocks it, by name;
- **done** → marked done; opening it again is fine where it makes sense
  (a tutorial re-read), your call, but a done item must not read as open;
- an item the trainer unlocked says so — the escape hatch is visible, not
  silent;
- an item whose `requireSolved` is set says so too: a student who is stuck
  should be able to see *why* the next item has not opened.

Returning from an item re-reads the homework, so the next item's state is
what the server says and not what the screen assumed.

Whether this reader is the trainer is **read from the payload** — the
parent's `trainer_id` against the session's id — never from a flag a caller
could pass wrongly. The trainer gets an unlock control on a locked row
(`openGate`, then re-read); the student never does.

Route it: `AppRoutes.assignmentHomework` = `/assignments/:id/homework`,
`assignmentHomeworkPath(id)`, in `appRouteTable` beside the other assignment
routes.

**4. One home for „which screen does an item open"** —
`lib/features/assignments/widgets/assignment_item_destination.dart`:

```dart
Widget assignmentItemScreen({
  required UserSession session,
  required AssignmentDetail detail,
  AssignmentApiService? api,
})
```

`appRouteTable`'s three assignment routes each decide this today; move that
decision here and have all of them — and this screen — go through it. A
second copy of it is exactly what this function exists to prevent, and a
homework item is a fourth kind (`engine_game`) that only this phase reaches.

`lesson` → the lesson viewer, `puzzles` → the overview when the positions are
the trainer's own and the tactics screen otherwise (as the route does now),
`engine_game` → `AiStudioScreen(initialCategory: 'engine_game', engineGameTask:
EngineGameTask.fromJson(task), assignmentId: child.id)`. A task
`EngineGameTask.fromJson` refuses is not opened.

The three detail-fed kinds want the child's own detail, which
`AssignmentDetailGate` already fetches by id — reuse it, and pass your `api`
down so one client serves the whole flow.

**5. A payload that says „locked" is not a screen.** `GET /assignments/:id`
answers a locked child with `{locked: true, blockedBy}` and status 200. A
student on a screen that has been open for a while can tap an item the server
has since shut; `AssignmentDetail.fromJson` would read that body as an
assignment with no title and no items, and the destination would be built out
of nothing. Refuse it where the detail is read, and say which item is in the
way.

**6. The doors.**

- `MyAssignmentsScreen`: a homework is **one** row (`Key('assignment-row-<id>')`),
  reading `1 of 3 items`, opening the homework screen. Today it lands in
  „This assignment is already completed", because a parent has no items.
  Add the `api` seam while you are there.
- The trainer's side: on `student_progress_screen.dart`, a row whose kind is
  `homework` opens the same homework screen rather than the review screen.
  The plan says „from the review screen", and that turns out to be the wrong
  place: `buildReview` is built from `assignment_items`, and a parent has
  none, so the review of a homework is an empty page. The lock is visible on
  the homework screen, so the unlock belongs there. Per child, offer the
  review of *that* child — it is an ordinary assignment and its review works.

## The gate

Copy `docs/gates/homework_student_test.dart` into `chess_app/test/`
**unchanged** and make it green: 15 tests, red on master today because
nothing it imports from `lib/features/homework/` exists yet. Its header
states every name and key you must provide — follow it exactly; the keys are
what the next phase's tests will use.

If you believe a test in the gate is wrong, **stop and say so in the
report** — do not work around it. Phase 2b's gate really was wrong, and
phase 3b's brief contradicted its gate; saying so was the right call both
times, and it cost less than a workaround would have.

## Your own tests, in a second file

What the gate cannot reach:

1. **A finished homework.** Every child done → every row `Done`,
   `3 of 3 items`, and the row on the student's list reads as complete rather
   than as 0 of 0.
2. **Both shapes of phone, pumped**: at 360×800 and at 800×360 the rows,
   their state labels and the trainer's unlock are on screen and nothing
   overflows. A release build paints no overflow stripes; a widget test does
   throw.
3. **„Must be solved" is said** on a row that carries it, and not on one that
   does not — scoped to that row, not to the screen.
4. **A stale screen** (point 5 above): the detail answers `{locked: true,
   blockedBy: 502}` and the student is told which item is in the way instead
   of getting an empty assignment.
5. **Coming back re-reads**: returning from an item asks the server for the
   homework again.

Prove each of your rules by mutation before believing the test — break the
rule in `lib/`, watch *which* test goes red, put it back — and say in the
report which test caught each. A compile error is not a catch.

## Pass condition

Run both from `chess_app/`, and paste their summary lines in your report:

```bash
flutter test
flutter analyze
```

- `flutter test` — **2966** today, 1 skipped, all green. Afterwards: 2966 +
  15 (the gate) + yours, still one skipped, none failing.
- `flutter analyze` — **26** issues, every one an `info` and every one
  `curly_braces_in_flow_control_structures`; zero errors, zero warnings.
  Compare the list, not the exit code (it exits 1 today). No new infos, and
  nothing silenced with an `ignore`.

Run `dart format` on every Dart file you touch. Never start a dev server —
the owner owns port 3000.

## Traps measured in this repository

- A `MockClient` answers any URL, so **assert the address**. Phase 2b posted
  to `/api/assignments/...` for a day and every test passed.
- Widget tests draw every glyph as a square without `loadRoboto`
  (`test/support/landscape.dart`). A „pre-existing overflow" reported in
  phase 2b was that, and nothing else.
- `AiStudioScreen` is a `ConsumerWidget`: a pump that reaches it needs a
  `ProviderScope`, as the app's own root has.
- A finder that is unique today stops being unique when the screen grows —
  scope it to the row (`find.descendant`), never weaken it.
- `chess.Chess.fromFEN` does not validate; `EngineGameTask.fromJson` is the
  reader that refuses, and it is the one to go through.
