# Brief: the trainer writes a homework — phase 3, app half

For an `implementer` (Sonnet 5), in a worktree. The lead has built the server
half and written the gate; this brief is the app half only.

Read first: `docs/PLAN-DOMACI-ZADATAK.md` §4, §5 and §7 (phase 3), this file
whole, and the header of `docs/gates/homework_editor_test.dart`, which states
the exact API and the widget keys you must provide. Do not read
`docs/LESSONS.md` or `docs/TODO-provera.md` — grep them if you need a why.

## What exists already (do not rebuild it)

- **The server half**, on `master`: `chess_backend/services/homeworkTemplate.js`
  and `routes/homeworks.js`, mounted at `/homeworks`:
  - `GET /homeworks` → `{ homeworks: [ { id, title, instructions, item_count, sent_count, updated_at } ] }`
  - `POST /homeworks` → 201 with the saved homework
  - `GET /homeworks/:id` → `{ id, title, instructions, items: [ { item_key, position, kind, task, gate, require_solved } ], sent: [...] }`
  - `PUT /homeworks/:id` → 200 with the saved homework
  - `DELETE /homeworks/:id` → `{ success: true }`
  - Refusals: 400 for a bad body (no title, an item whose task the kind does
    not allow, two items claiming one key, more than 20 items), 422 for a
    tutorial or position that is not the trainer's own or cannot be judged,
    404 for another trainer's homework. **Show the server's `error` string**;
    it names the item (`item 2: …`).
- **The wire contract for items.** You send the list as the editor shows it.
  An item that already exists carries its `itemKey`; a new one carries none;
  an item you leave out is deleted. **You never send `position`** — order is
  the list, and the server numbers it. An item's key is the identity a sent
  homework points back at, so a key must never be derived from an index.
- **The four item kinds** and what their `task` holds: `lesson`
  (`{lessonId}`), `positions` (`{puzzleIds: ['cust_…']}`), `puzzles`
  (`{themes, count, minRating, maxRating}`), `engine_game` (the „play it out"
  task: `{fen, side, goal, surviveMoves?, level?, thinkSeconds?, plyCap}` —
  the app already reads and validates exactly this shape in
  `lib/core/models/engine_game_task.dart`, phase 2; reuse it, do not write a
  second reader).
- **Pickers you can reuse rather than invent**: the Library's own list
  (`lib/features/library/`) for choosing a tutorial or scanned positions, and
  `CreateAssignmentDialog` (`lib/features/assignments/widgets/`) for the
  puzzle-set criteria. If reuse is awkward, say so in the report rather than
  duplicating a screen.

## What to build

**1. The model and the service** — `lib/features/homework/models/homework.dart`
and `lib/features/homework/services/homework_api_service.dart`, to the API in
the gate's header. `fromJson` **refuses** (returns null) rather than guessing;
`toJson` omits `itemKey` when there is none.

**2. The editor** — `lib/features/homework/screens/homework_editor_screen.dart`:
title, instructions, the items in order, each row with up / down / remove and
the two switches (`gate`, `requireSolved`), and one **Add** control that offers
the four kinds. Every control carries the key the gate's header lists.

Beside the „done means solved" switch, say what it does in one line: *a student
who cannot solve this cannot go on* (plan §6). The first item's gate switch
changes nothing — the server ignores a gate with nothing before it — so do not
offer it on the first row.

**3. The doors.** A „Homework" card on the Teach tab and a „Homework" chip in
the Library, both opening the list of the trainer's homeworks, with *New
homework* and a row per homework opening the editor. Follow how the Tutorials
card and the Library's chips are built today.

## The gate

Copy `docs/gates/homework_editor_test.dart` into `chess_app/test/` **unchanged**
and make it green. It is red on master today: nothing under
`lib/features/homework/` exists.

Add, in a second file, widget tests for what the gate cannot reach:

1. **Reachability, pumped — not counted in the source.** The Teach card and the
   Library chip must be *found on a pumped screen* at 360×800 and at 800×360,
   and tapping each must reach the list. A source-reading check is not enough:
   phase 2b found controls that had existed for weeks inside a card nothing
   ever placed in the tree (CLAUDE.md rule 10).
2. **Add an item of each kind** and assert the saved body carries the right
   `kind` and a task the server would accept.
3. **A refusal is shown.** With a client answering 400 and
   `{"error":"item 2: a positions item needs at least one position."}`, that
   sentence reaches the screen, and the editor does not claim it saved.
4. **The first row offers no gate switch**, the others do.

Pass condition, run from `chess_app/`:

```bash
flutter test
flutter analyze
```

`flutter test` must be **2943 plus your new tests**, none failing, one skipped.
`flutter analyze` must report the same 26 infos as today — zero errors, zero
warnings, no new infos. Run `dart format` on every file you touch.

**Prove your own tests.** Break each new rule once — send `position` instead of
the list order, derive a key from the index, drop the `itemKey` of an existing
item, swallow the server's error — and watch the right test go red. List the
mutations and what caught each in your report.

## Traps, measured

1. **A `MockClient` answers any URL.** Assert the address as well as the body:
   phase 2b posted to `/api/assignments/…`, which this server does not serve,
   and its test could not see it (rule 7).
2. **Widget tests draw text as squares** unless `loadRoboto` (see
   `test/support/landscape.dart`) runs in `setUpAll`. Without it a row
   „overflows" by a hundred pixels in the test and by nothing on a phone, and
   consuming that exception hides the real ones (rule 8).
3. **`chess.Chess.fromFEN` does not validate** — it returns an empty board for
   nonsense. For an `engine_game` item, read the task through
   `EngineGameTask.fromJson`, which already refuses properly.

## Method

- One rule, one home: reuse `EngineGameTask`, the Library's pickers and the
  existing criteria dialog rather than writing a second of anything.
- Do the thing, then say it: save, then report; a failed save is reported
  through `AppFeedback` and must not be able to swallow the save.
- If you believe a test in the gate is wrong, **stop and say so in the report**
  — do not work around it. A workaround that satisfies a test without
  satisfying the rule is worth less than a stopped batch. (Phase 2b's gate
  really was wrong, and saying so was the right call.)
- Report: what you built, both commands' summary lines, your mutation list with
  the test each one turned red, and a section „what the brief got wrong".
