# Task: drilling your own mistakes, and the repertoire you already play

A bounded job for an outside agent. **This file is the only context you get** —
do not rely on any conversation before it, and do not go looking for the plan
documents it was distilled from. When the work is merged, this file is deleted.

Branch: `design/moje-partije-drill`, off `master`. Commit as `batch 48 — …`,
matching the numbering the earlier design batches used.

Two screens in `chess_app/`, over a backend that is **already built, tested and
frozen**. Nothing in this job changes `chess_backend/`.

Read §6 before writing anything. It is the part that decides whether the work
can be merged at all, and §5 is the part that will otherwise cost you a day.

---

## 1. Why this job exists

A player has imported their own games — four thousand is normal — and the
backend has already found two things in them.

**The mistakes they actually made**, each one a position and the move they
played in it, on the same SM-2 spaced-repetition schedule the app already uses
for lessons. Not a puzzle set somebody wrote for them: their own blunder, from
their own game, coming back a week later.

**The repertoire they already play**, read out of the archive rather than typed
in. And then the more useful half — where they *left* it. "You reached a
position you had prepared in 340 games and played something else in 118 of
them" is a sentence with a drill attached to it.

What is missing is the two screens a person touches.

## 2. The two screens

### 2.1 The mistake drill

The loop is: a position, the player finds a better move than the one they
played, then they say how hard it was and the item is rescheduled.

- **The board is `fenBefore`** — one move *before* the mistake, so the player
  meets the position as they met it in the game, not the wreckage after.
- **The answer is `bestUci`.** Compare the move the player makes against it.
- **`bestUci` can be null, and that is the trap in this screen.** Both writers
  are allowed to leave it empty: the tablebase auditor writes null when the
  move played was already the best one available in a lost position, and the
  client engine pass writes null when it had no principal variation. **An item
  with no `bestUci` must never be handed to a player as a puzzle** — without an
  answer, every move they make is told „netačno". Filter those out of the
  drill, and if you want to show them at all, show them as something to look at
  rather than something to solve. Say in your report how many the fixture had.
- **Four grade buttons**, not six. The app already has them: `ReviewGrade` in
  `lib/features/reviews/services/review_api_service.dart` carries both the
  Serbian label and the number (`again` 1, `hard` 3, `good` 4, `easy` 5), and
  those numbers are **exactly** what this endpoint expects — it takes either
  the name or the quality number. Reuse the enum; do not write a second set of
  four words for the same four grades.
- The server answers with `intervalDays` and a ready-made Serbian
  `description` — „sutra", „za 3 dana", „za 2 nedelje", „za mesec dana". Print
  the server's sentence rather than composing your own from the number, because
  the phrasing switches unit at 7 and 30 days and a second implementation will
  disagree with the first.
- **Around the position, the game it came from**: `playedAt`, `opponent`,
  `result`, `opening`, and which colour the player had. A mistake with a date
  and an opponent on it is a memory; a bare FEN is a puzzle.
- Two kinds of item, and they are not interchangeable. `kind: 'engine'` carries
  `swingCp` (how much it cost, in centipawns) and often a `theme`.
  `kind: 'tablebase'` carries `wdlBefore` and `wdlAfter` (−2..2) and **no
  centipawns at all**. Do not invent a swing for a tablebase item, do not put
  the two on one scale, and do not print „0 centipoena" for an item that simply
  does not have the number.

### 2.2 The recurrence panel

`GET /games/mistakes/recurrence` is what makes the drill worth doing, and it is
a small screen or a section on the drill screen — your call.

One missed fork is a bad evening; the same motif missed forty times is a
weakness. It comes back as two separate lists, **and they must stay separate**:
`motifs` (from engine findings, bucketed by tactical theme) and `endings` (from
tablebase findings, bucketed by material signature).

**The endings `key` is not readable and you must not print it raw.** It is the
board's piece letters, sorted — uppercase White, lowercase Black — so a rook
and pawns against a rook and pawns is `KPRkpr`, and `KPk` is a king and pawn
ending. Turn it into Serbian words. "Stalno gubiš topovske završnice" is a
sentence a child can act on; `KPRkpr` is a hash. Decide the mapping yourself,
keep it small, and fall back to something honest for a signature you have no
name for — never to a wrong name.

Ranking happens inside each list and never across the two — there is no
exchange rate between "cost 300 centipawns" and "threw away a won ending", and
inventing one would make every number under it quietly wrong.

### 2.3 The repertoire from the archive

Two actions on one screen.

**Seed.** `POST /games/repertoire/seed` with `dryRun: true` returns a plan and
writes nothing. **Show the plan first, always** — the count of positions and
moves, and a sample of what would be added. Only a second, explicit press
writes it. The player may already have a hand-built repertoire, and while the
server is careful not to overwrite their decisions, "I pressed a button and my
repertoire changed" is not something to discover afterwards.

**Diff.** `GET /games/repertoire/diff` is the headline: three numbers —
`coveredGames`, `followedGames`, `leftGames` — and then the positions,
worst first. Each position carries `prepared` (what the repertoire says) beside
`played` (what actually happened), so the row reads as a comparison and not as
a scolding.

One thing the server is deliberate about and the screen must not blur: a
position the repertoire says nothing about is **not** a deviation. It is a gap.
The diff already excludes them; do not add a control that mixes them back in.

## 3. The API, exactly

Everything is authenticated with the app's existing bearer token.

| Endpoint | Sends | Gets back |
|---|---|---|
| `GET /games/mistakes/due?limit=20` | — | `{ items: [item] }`, soonest due first, limit clamped to 1–100 |
| `POST /games/mistakes/:id/grade` | `{ grade: 'again'\|'hard'\|'good'\|'easy' }` | `{ ok, item, intervalDays, dueAt, description }` |
| `GET /games/mistakes/stats` | — | totals, split by kind |
| `GET /games/mistakes/recurrence` | — | `{ sampled, motifs: [bucket], endings: [bucket] }` |
| `POST /games/repertoire/seed` | `{ username, color?, minGames?, dryRun? }` | the plan, or what was written |
| `GET /games/repertoire/diff?username=&color=&limit=` | — | the three numbers and the positions |

A due item — **note the snake_case, it is a database row served as it stands**:

```json
{ "id": "4471", "game_id": "20233", "ply": 34,
  "fen_before": "8/8/4k3/8/4P3/4K3/8/8 w - - 0 45",
  "played_uci": "e3d3", "best_uci": "e4e5",
  "kind": "engine", "theme": "fork", "swing_cp": -310,
  "wdl_before": null, "wdl_after": null,
  "interval_days": 6, "repetitions": 2, "lapses": 0,
  "due_at": "2026-08-30T09:00:00.000Z",
  "played_at": "2025-11-02T18:41:00.000Z", "opponent": "someone",
  "result": "0-1", "subject_color": "w", "opening": "French Defence" }
```

A grade answer:

```json
{ "ok": true, "intervalDays": 15, "dueAt": "2026-09-14T…",
  "description": "za 2 nedelje",
  "item": { "id": "4471", "ease_factor": "2.50", "repetitions": 3, … } }
```

A grade the server refuses comes back `400 { "error": "…" }` with the reason
already in Serbian. Print it; do not translate it again.

A recurrence bucket:

```json
{ "key": "fork",   "count": 41, "worstSwing": 780, "example": "4471" }
{ "key": "KPRkpr", "count": 17, "worstSwing": 0,   "example": "5012" }
```

The seed plan (`dryRun: true`) and the write differ in shape, so handle both:

```json
{ "dryRun": true,  "positions": 648, "moves": 1132, "unplayable": 0,
  "plan": [ { "color": "w", "fenKey": "…", "fen": "…", "san": "Nf3",
              "uci": "g1f3", "games": 212, "share": 0.61, "ply": 3 } ] }

{ "dryRun": false, "positions": 648, "moves": 1132, "unplayable": 0,
  "added": 1132, "primary": 648 }
```

`unplayable` above zero is a bug report, not a statistic — if it is not zero,
say so on screen and put the number in your report.

The diff:

```json
{ "subject": "handle", "color": "w",
  "coveredGames": 340, "followedGames": 222, "leftGames": 118,
  "positions": [
    { "fenKey": "…", "fen": "…", "color": "w", "ply": 6,
      "games": 35, "leftGames": 21,
      "prepared": [ { "san": "Nf3", "games": 14, "score": 0.57 } ],
      "played":   [ { "san": "d4",  "games": 21, "score": 0.31 } ] } ] }
```

Both repertoire endpoints answer `400 { error }` for a missing or bad
`username`, and the message is already Serbian.

## 4. Types: what arrives as a string

**Read this before you write a model.** The backend serves database rows
directly, and node-postgres returns two Postgres types as JSON *strings* rather
than numbers. A `as int` cast on any of them compiles, passes every test whose
fake returns a real `int`, and throws the first time it meets the server. This
exact bug shipped in batch 47 and was caught only by reading the schema.

| Field | Postgres type | Arrives as |
|---|---|---|
| `id`, `game_id`, `example` | `BIGSERIAL` / `BIGINT` | **string** — `"4471"` |
| `ease_factor` | `NUMERIC(4,2)` | **string** — `"2.50"` |
| `ply`, `swing_cp`, `wdl_before`, `wdl_after`, `interval_days`, `repetitions`, `lapses` | `SMALLINT` / `INTEGER` | number |
| `score`, `share` | computed in JS | number |
| `due_at`, `played_at` | `TIMESTAMPTZ` | ISO-8601 string |
| `theme`, `best_uci`, `opponent`, `opening`, `wdl_*` on an engine item | nullable | may be `null` |

Write one tolerant reader that takes either a number or a numeric string, and
route every id through it. **Then make your fakes return the string form**, so
the tests exercise the shape the server actually sends. A fake that hands back
`4471` where the server sends `"4471"` is a test that proves the opposite of
what it claims.

## 5. What already exists — reuse, do not rebuild

- **The board.** `SkinnedChessBoard` takes a FEN and is the interactive one;
  `BoardThumbnail` (`lib/widgets/board_thumbnail.dart`) is the small
  non-interactive preview and takes `fen`, `size` and `isWhiteBottom`. The
  drill needs the first — the player has to be able to make a move. The
  repertoire diff rows need the second.
- **The archive feature folder.** `lib/features/archive/` already holds an API
  service, models and two screens from batch 47. **Follow its shape and put
  your work beside it**, and reuse `lib/features/archive/models/json_int.dart`
  — that is the tolerant reader from §4, already written.
- **Spaced repetition.** `lib/features/reviews/` is the lesson-review version of
  this loop, with `ReviewGrade` in its `services/review_api_service.dart` and a
  working four-button UI in `screens/review_session_screen.dart`. Match its
  wording and layout — two vocabularies for the same four grades is worse than
  either. Note what that screen does with ordering, too: it reveals first and
  grades second, so nobody can tap „Lako" before seeing the answer.
- Colours and text styles: `context.colors` and `lib/theme/app_typography.dart`.
  No raw `Color(0x…)` anywhere.
- Messages: `lib/widgets/app_feedback.dart`. See §6.
- Routing: `lib/routing/app_routes.dart` and `app_router.dart`. The training hub
  is `lib/widgets/ai_studio/category_selection_hub.dart` — a new card there
  needs its callback added at **both** of its call sites, and its four golden
  screenshots regenerated with
  `flutter test --tags golden --run-skipped --update-goldens`.

## 6. Rules that bite

These are not style preferences. Each one is a bug this project already shipped,
and the last three are from batch 47 — the job immediately before this one.

1. **Never call `ScaffoldMessenger` directly.** Use `AppFeedback`.
   `test/app_feedback_guard_test.dart` fails if a raw call comes back. Twice a
   message about the work has killed the work: a snackbar that threw before the
   thing it was announcing ran. **Do the thing, then say it.**
2. **A release build paints no overflow warning.** A `Row` wider than the screen
   is silently clipped and the buttons past the edge are unreachable. Where a
   row can grow, use `Wrap`. Every new widget test pumps at `Size(360, 640)`,
   because a *test* build does throw.
3. **The project owner is colourblind**, and roughly one boy in twelve has a
   red-green deficiency. Colour may never be the only channel — carry the
   meaning in a number, an icon, a shape or a label as well. A "good" and a
   "bad" chip that differ only in hue are unreadable to the person signing this
   off.
4. **User-facing strings are Serbian.** Code, comments and commits are English.
5. **Run `dart format` on every file you touch.** CI does not enforce it and the
   formatter reindents aggressively, so an unformatted file turns the next diff
   into noise.
6. **`flutter analyze` does not exit clean and has not for a long time**: 29
   known `info`s, all `curly_braces_in_flow_control_structures`. What must hold
   is zero errors, zero warnings and **no new infos** — compare the list, not
   the exit code.
7. **`find.text` matches the whole string.** Batch 47 reported "all green" with
   a failing test because it asserted `find.text('2. polupotez')` against a
   widget drawing `2. polupotez · uspeh 45.0%`. Use `find.textContaining` when
   you mean a substring, and **run the suite and read the last line** before
   reporting a number.
8. **A test that cannot reach the widget is not a test of it.** Batch 47 claimed
   its four counters were laid out so they could not overflow; they were drawn
   in no test at all, because the only path that renders them runs through a
   file picker a widget test cannot drive. If a widget is hard to reach, **lift
   it into its own widget and test it directly** — do not assert on the screen
   around it and call it covered.
9. **Prove every guard by mutation.** Break the thing on purpose, watch the test
   fail, put it back, and say in your report which mutations you ran. A guard
   nobody has seen fail is a guard nobody has tested.

## 7. How this will be judged

- `cd chess_app && flutter test` — **908 tests, 1 skipped, all green before you
  start.** Re-measure rather than trusting that number, and say what it is
  afterwards. A suite that quietly stops running half of itself is the thing
  the count exists to catch.
- New widget tests assert what is **drawn** after an interaction, not what was
  stored. `enterText` followed by `find.text` of the same string proves the
  `TextField` works, not that your screen does.
- At least one test pumps at `Size(360, 640)`.
- The golden group is skipped unconditionally in `dart_test.yaml`, and
  `--tags golden` alone does **not** run it — that selects the tests and the
  skip still skips them. Use `--run-skipped`.

## 8. Not in scope

The engine pass that produces engine mistakes (`POST /games/mistakes`) is a
whole-archive desktop job and belongs to a later batch — this screen drills what
is already stored. Opponent preparation is being built on the backend in
parallel; do not start it. If the job turns out to need a change outside
`chess_app/`, **write in your report which change and why, then stop.** Do not
widen the scope, and do not touch `chess_backend/` at all.

## 9. What to report

A short document with: the test count before and after, the `flutter analyze`
diff (not the exit code), which mutations you ran and what failed, how many
fixture items had a null `bestUci`, every decision you made that this file did
not settle, and anything you found that looks wrong in the backend contract.
That last one is wanted — batch 47 found a real bug in it by reading the schema,
and these endpoints have never been exercised by a real client either.

**You do not need a backend, a database, an `.env` or any credentials, and must
not ask for them.** Build against the shapes in §3 and §4, and fake the API the
way `chess_app/test/features/archive/` already fakes it. Running this against a
live server is the project owner's job and is written down separately.
