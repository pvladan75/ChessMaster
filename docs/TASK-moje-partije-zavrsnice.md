# Task: the endgames the player threw away, and playing them again

A bounded job for an outside agent. **This file is the only context you get** —
do not rely on any conversation before it, and do not go looking for the plan
documents it was distilled from. When the work is merged, this file is deleted.

Branch: `design/moje-partije-zavrsnice`, off `master`. Commit as `batch 49 — …`,
matching the numbering the earlier design batches used.

One screen and one small change to an existing one, in `chess_app/`, over a
backend that is **already built, tested and frozen**. Nothing in this job
changes `chess_backend/`.

Read §6 before writing anything. §5 is what makes the job possible at all, and
§4 is what will otherwise cost you a day.

---

## 1. Why this job exists

The player has imported their own games. The server can walk every position
that reached seven men or fewer, ask the Syzygy tablebases what it was worth
before and after each of the player's moves, and record every moment where a
win became a draw or a draw became a loss.

That is not an engine's opinion. **It is a fact**, and it is the only place in
this app where a verdict is one.

Measured on a real ten-year archive: 471 games reached the tables, 4255
positions were asked about, and the entry material was overwhelmingly rook and
pawns — `KKPPPRR` 107 times, `KKPPPPR` 40. So the output is, in practice, **a
rook-endgame syllabus built from the player's own games**. That is the sentence
this screen has to make visible.

What is missing is the screen. The drill that plays these positions out already
exists; this is a scan and a list, not a new mode.

## 2. What to build

### 2.1 Running the audit

The audit takes **minutes** — about 10 for a ten-year archive on a first run,
seconds afterwards, because every tablebase answer is cached and shared. So it
behaves like the import: `POST` returns immediately with an `auditId`, and you
poll until `status` is `done` or `failed`.

Six counters come back and they are not decoration. Show at least these four,
and keep them visible:

```
partije 471/471 · pozicije 4255 · iz keša 3980 · nalaza 27
```

**`positionsUnknown` is the one that must never be folded into anything else.**
A position the tables will not commit to is not a position the player got
right, and it is not a mistake either — it is a position nobody judged. If it
is above zero, say so separately. Counting it as either of the other two is the
exact failure this counter was added to prevent.

### 2.2 The findings, grouped by material

A list of moments, worst first. Each one needs:

- **a board preview** from `fen_before`, oriented to the side that was to move;
- **what it cost**, from `wdl_before` and `wdl_after` — see §3, this is the part
  most worth getting right;
- **the game it came from**: `played_at`, `opponent`, `result`;
- **a button that plays the position out** — see §5.

**Group them by material.** This is what turns a list into a syllabus: eight
separate rook-and-pawn findings are one lesson, not eight. Derive the material
from `fen_before` — the piece letters, and nothing else. Give each group a
Serbian name („topovska završnica", „pešačka završnica"), and fall back to
something honest for material you have no name for, never to a wrong name.

Sorting inside a group is by how much was thrown away. Sorting *between* groups
is by how often it happened — the recurring one is the weakness.

## 3. What the numbers mean

`wdl_before` and `wdl_after` are integers from −2 to 2, and **both are already
from the player's point of view**. The server has done the perspective work: a
position's tablebase category belongs to the side to move, each move's category
belongs to whoever moves next, and the server negates the second before storing
it. **Do not negate anything again.**

| value | meaning |
|---|---|
| `2` | win |
| `1` | win, but only ignoring the fifty-move rule |
| `0` | draw |
| `-1` | loss, avoidable only by the fifty-move rule |
| `-2` | loss |

A row exists only where `wdl_after < wdl_before`. So every finding is a drop,
and the size of the drop is what it cost. `2 → 0` is a win turned into a draw;
`0 → -2` is a draw turned into a loss. Those are different sentences and the
screen should say which.

**Never render a finding as centipawns.** There are none, and there is no
exchange rate between "threw away a win" and "lost 300 centipawns". A tablebase
finding and an engine finding do not go on one scale; this screen only ever
shows the first kind.

## 4. The API, exactly

Everything is authenticated with the app's existing bearer token.

| Endpoint | Sends | Gets back |
|---|---|---|
| `POST /games/endgame/audit` | `{ username }` | `202 { auditId }` |
| `GET /games/endgame/audits/:id` | — | one run |
| `GET /games/endgame/mistakes?limit=50` | — | `{ mistakes: [finding] }`, worst first, limit clamped to 1–200 |

A run — **note the snake_case, it is a database row served as it stands**:

```json
{ "id": "12", "subject": "handle", "status": "running|done|failed",
  "games_total": 471, "games_done": 471,
  "positions_probed": 4255, "cache_hits": 3980,
  "positions_unknown": 0, "mistakes_found": 27,
  "error": null, "started_at": "…", "finished_at": null }
```

A finding:

```json
{ "id": "5012", "game_id": "20233", "ply": 78,
  "fen_before": "8/8/4k3/8/4P3/4K3/8/8 w - - 0 40",
  "played_uci": "e3d3", "best_uci": "e4e5",
  "wdl_before": 2, "wdl_after": 0, "due_at": "…",
  "played_at": "2025-11-02T18:41:00.000Z",
  "opponent": "someone", "result": "1/2-1/2" }
```

`best_uci` **can be null**, and here it means something specific: the move
played was already the best available. Those are not mistakes to drill — they
are positions that were lost before the player got there. Do not offer them as
puzzles; the drill would tell a child „netačno" whatever they play.

### Types: what arrives as a string

The backend serves database rows directly, and node-postgres returns two
Postgres types as JSON *strings* rather than numbers. A `as int` cast on any of
them compiles, passes every test whose fake returns a real `int`, and throws the
first time it meets the server. This shipped once already.

| Field | Arrives as |
|---|---|
| `id`, `game_id` | **string** — `"5012"` |
| `ply`, `wdl_before`, `wdl_after`, and every counter on a run | number |
| `due_at`, `played_at`, `started_at`, `finished_at` | ISO-8601 string, or null |
| `best_uci`, `opponent`, `error` | may be null |

`lib/features/archive/models/json_int.dart` already holds a tolerant reader.
Use it for the numbers, keep the ids as strings, and **make your fakes return
the string form** — a fake handing back `5012` where the server sends `"5012"`
is a test that proves the opposite of its claim.

## 5. Playing the position out — read this before designing anything

The endgame trainer already plays tablebase positions and judges every move
against the tables. Two facts decide this whole batch:

- `EndgameApiService.judgeDrillMove({fen, move})` and `fetchReadout({fen, goal})`
  work from a **bare FEN**. The drill machinery does not need a catalogue entry.
- `EndgameTrainerScreen` currently cannot be given a position. It takes
  catalogue filters — `type`, `mode`, `material`, `band` — and fetches a puzzle
  itself.

So the job needs **one new parameter on `EndgameTrainerScreen`**: an optional
starting FEN which, when present, skips the fetch and loads that position
instead. That is a change to a screen six other places already use, so it is
explicitly authorised here — but it must be **additive and default-off**, and
every existing caller must keep behaving exactly as it does now. If you find
yourself changing what happens when the parameter is absent, stop and report
instead.

The goal comes from `wdl_before`, and there are only two answers:

- `wdl_before > 0` → the player had a **win** to convert (`EndgameMode.win`)
- `wdl_before == 0` → the player had a **draw** to hold (`EndgameMode.draw`)

A finding with `wdl_before < 0` cannot exist, because a row is only written when
the outcome dropped and there is nothing below a loss.

## 6. Rules that bite

Each one is a bug this project already shipped. The last three are from batch
48, the job immediately before this one.

1. **Never call `ScaffoldMessenger` directly.** Use `AppFeedback`.
   `test/app_feedback_guard_test.dart` fails if a raw call comes back. Twice a
   message about the work has killed the work: a snackbar that threw before the
   thing it was announcing ran. **Do the thing, then say it.**
2. **A release build paints no overflow warning.** A `Row` wider than the screen
   is silently clipped and the buttons past the edge are unreachable. Where a
   row can grow, use `Wrap`. Every new widget test pumps at `Size(360, 640)`,
   because a *test* build does throw. The counter row in §2.1 is four items and
   will overflow if it is a `Row`.
3. **The project owner is colourblind**, and roughly one boy in twelve has a
   red-green deficiency. Colour may never be the only channel. „Bacio dobitak"
   and „bacio remi" must differ by more than hue — a word, an icon, a number.
4. **User-facing strings are Serbian.** Code, comments and commits are English.
5. **Run `dart format` on every file you touch.** Batch 48 did not, and it left
   six files unformatted.
6. **`flutter analyze` does not exit clean and has not for a long time**: 29
   known `info`s, all `curly_braces_in_flow_control_structures`. What must hold
   is zero errors, zero warnings and **no new infos** — compare the list, not
   the exit code. Batch 48 reported "zero new infos" while adding one, on two
   dead fields in a fake.
7. **A faked service cannot see a request the server would refuse.** This is the
   most important line in this file. Batch 48 shipped two screens that failed on
   *every* load — they sent `color=white` where the backend accepts only `w` —
   and a 910-test suite was green over it, because the widget tests replace
   `ArchiveApiService` wholesale and nothing in them ever sends a real request.
   **`ArchiveApiService.withClient(client)` exists for exactly this.** At least
   one test in this batch must drive the real service over a fake `http.Client`
   and assert the URL, query parameters and body that actually go out.
8. **`find.text` matches the whole string.** Use `find.textContaining` when you
   mean a substring, and **run the suite and read the last line** before
   reporting a number.
9. **Prove every guard by mutation.** Break the thing on purpose, watch the test
   fail, put it back, and say in your report which mutations you ran. A guard
   nobody has watched fail is a guard nobody has tested.

## 7. How this will be judged

- `cd chess_app && flutter test` — **916 tests, 1 skipped, all green before you
  start.** Re-measure rather than trusting that number, and say what it is
  afterwards.
- New widget tests assert what is **drawn** after an interaction, not what was
  stored. `enterText` followed by `find.text` of the same string proves the
  `TextField` works, not that your screen does.
- At least one test pumps at `Size(360, 640)`, and at least one drives the real
  API service over a fake transport (rule 7).
- The golden group is skipped unconditionally in `dart_test.yaml`, and
  `--tags golden` alone does **not** run it — that selects the tests and the
  skip still skips them. If you add a card to the training hub, regenerate with
  `flutter test --tags golden --run-skipped --update-goldens`.

## 8. Not in scope

The opponent-preparation screens and the AI description are behind a decision
that has not been made; do not start them. The engine pass that produces
*engine* mistakes is a desktop job for a later batch — this screen shows only
tablebase findings. Do not touch `chess_backend/`. If the job turns out to need
a change outside `chess_app/`, **write in your report which change and why, then
stop.**

## 9. What to report

A short document with: the test count before and after, the `flutter analyze`
diff (not the exit code), which mutations you ran and what failed, what the
real-transport test asserts, how you named the material groups, every decision
this file did not settle, and anything that looks wrong in the backend contract.

That last one is wanted and has paid off twice: batch 47 found a type bug by
reading the schema, and batch 48 found a field missing from a response. These
endpoints have never been exercised by a real client either.

**You do not need a backend, a database, an `.env` or any credentials, and must
not ask for them.** Build against the shapes in §4, and fake the API the way
`chess_app/test/features/archive/` already does — but read rule 7 again before
deciding that faking is enough.
