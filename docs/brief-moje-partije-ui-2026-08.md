# Brief: the archive UI — import, and the opening leak report

Written 30.8.2026, for the design agent. Two screens in `chess_app/`, both over
a backend that is **already built, tested and frozen**: sections 0 and 1 of
[PLAN-MOJE-PARTIJE.md](PLAN-MOJE-PARTIJE.md). Nothing in this job changes
`chess_backend/`.

Read §5 before writing anything. It is the part that decides whether the work
can be merged at all.

---

## 1. Why this job exists

A player hands the app a PGN export of their own games — four thousand of them
is normal — and the app tells them where they keep going wrong. The backend
already turns that file into rows and finds the leaks. What is missing is the
two screens a person actually touches.

The finding this is built to show, measured on a real 4126-game archive: **one
position reached 121 times, scored 41.3%, and the same move played in 92 of
them.** That is the shape of every row in the report. Not "you blundered on
move 23 of one game" but "you keep answering this position the same way and it
keeps not working". The screen's whole job is to make that sentence legible in
one glance.

## 2. The two screens

### 2.1 Import

A file picker, a username field, and — the part that matters — **four counters**
that must stay visible and must add up:

```
pročitano 4126 · upisano 4126 · već postojalo 0 · preskočeno 0
```

`preskočeno` is never a bare number. When it is above zero the screen shows the
reasons, which arrive as a map: `unparsable-pgn`, `not-standard-variant`,
`unfinished-game`, `subject-not-in-game`, `no-moves`. "300 preskočeno" is a
number; "300 preskočeno: 297 nije standardni šah, 3 bez poteza" is an answer.
This is the whole reason the backend counts four things instead of one, and a
UI that shows only a spinner and a tick throws it away.

The import takes minutes for a large file. The POST returns immediately with an
`importId`; poll `GET /games/imports/:id` (every 2 s is fine) until `status` is
`done` or `failed`. On `failed`, show `error` — the run writes its own reason
and that string is meant for the user.

### 2.2 Opening leak report

A list of positions. Each row needs, at minimum:

- **a board preview** drawn from `node.fen` (already a complete, legal FEN),
  oriented to `color` — this is the one element that makes the row readable at
  a glance;
- **how often and how badly**: `games` and `score` (0–1, render as a
  percentage);
- **the move they keep playing**: `moves[0]` is the most-played, with `share`
  (its fraction of the position's games) and its own `score`. The headline is
  `Nf3 — 33 od 35 partija · 37%`;
- the other moves tried in the same position, secondary;
- **the master recommendation**, when judging was requested: `judgement.verdict`
  is one of `theory`, `playable`, `mistake`, `unknown`, and
  `judgement.eval.better` is the move to play instead (SAN, may be null).

`ply` is available for context ("10. polupotez"). `fenKey` is the identity — use
it as the widget key, never the index.

## 3. The API, exactly

Everything is under `/games`, all authenticated with the app's existing bearer
token.

| Endpoint | Sends | Gets back |
|---|---|---|
| `POST /games/import/file` | multipart: `archive` (the .pgn, ≤ 25 MB), `username` | `202 { importId, bytes }` |
| `POST /games/import/pgn` | `{ pgn, username }`, ≤ 2 MB | `202 { importId }` |
| `GET /games/imports` | — | `{ runs: [run] }`, newest first |
| `GET /games/imports/:id` | — | one `run` |
| `GET /games/stats` | — | `{ games, with_clocks, reached_tablebase, subjects, oldest, newest, plies }` |
| `GET /games/openings/leaks` | query, below | the report |
| `POST /games/openings/backfill` | — | `{ games, nodes }` |

A `run`:

```json
{ "id": 1, "source": "pgn", "subject": "handle", "status": "running|done|failed",
  "games_read": 4126, "games_stored": 4126, "games_duplicate": 0,
  "games_skipped": 0, "skipped_by_reason": {}, "error": null,
  "started_at": "...", "finished_at": null }
```

`GET /games/openings/leaks` takes `subject` (required), and optionally `color`
(`w`/`b`), `fromPly`, `toPly`, `minGames`, `maxScore`, `speed`, `limit`,
`judge=true`, `judgeLimit`, `minRating`. Judging also needs the header
`X-Lichess-Token`, the player's own — the same header the existing opening-judge
panel already sends. The report:

```json
{ "subject": "handle", "color": null,
  "window": { "fromPly": 6, "toPly": 20 },
  "thresholds": { "minGames": 8, "maxScore": 0.42 },
  "games": 4126, "gamesWithoutNodes": 0,
  "nodes": [
    { "fenKey": "...", "fen": "... w KQkq - 0 1", "ply": 10,
      "games": 35, "score": 0.371,
      "moves": [ { "san": "Nf3", "games": 33, "score": 0.364, "share": 0.943 } ],
      "judgement": { "verdict": "playable", "eval": { "lossCp": 40, "better": "d4" } } } ],
  "judge": { "requested": true, "judged": 10, "nodes": 10 } }
```

Three server behaviours the UI must respect rather than paper over:

1. **`gamesWithoutNodes` above zero means the report is incomplete.** Those
   games were imported before the openings table existed and contribute
   nothing. Say so, and offer the backfill button. An empty report shown as "no
   weaknesses found" when 4126 games were never scanned is the exact failure
   this field exists to prevent.
2. **`toPly` above 20 returns 400 with an explanation.** Do not offer a control
   that can ask for it. Past ply 20 every game is nearly unique and a
   per-position percentage stops meaning anything; the window is a rule, not a
   setting.
3. **`judge.reason === 'no-token'` is not an error state.** The numbers are
   real and complete without it. Show the report, and offer the token as an
   extra. Same for a node whose `judgement.verdict` is `unknown`: that means
   nobody has evaluated the position, and it must **not** be drawn as a
   mistake.

## 4. What already exists — reuse, do not rebuild

- The board: `SkinnedChessBoard`, and it takes a FEN. Skins and themes come from
  the appearance settings that landed 29.8.2026.
- File picking: `FilePicker.pickFiles` with `allowedExtensions: ['pgn']`, as in
  `board_setup_dialog.dart`.
- The existing Lichess-token plumbing for the judge — find it via the opening
  judge panel; do not invent a second place to keep that token.
- Colours and text styles: `context.colors` and `app_typography.dart`. No raw
  `Color(0x...)` anywhere.
- Messages: `AppFeedback`. See §5.

## 5. Rules that bite

These are not style preferences. Each one is a bug this project already shipped.

1. **Never call `ScaffoldMessenger` directly.** Use `AppFeedback`.
   `test/app_feedback_guard_test.dart` fails if a raw call comes back. Twice a
   message about the work has killed the work: a snackbar that threw before the
   thing it was announcing ran. **Do the thing, then say it.**
2. **A release build paints no overflow warning.** A `Row` wider than the screen
   is silently clipped, and the buttons past the edge are simply unreachable.
   Where a row can grow, use `Wrap`; where a width is fixed, take it from
   `MediaQuery`. Every new widget test pumps at `Size(360, 640)`, because a
   *test* build does throw on overflow. The counters row in §2.1 is four items
   and will overflow on a 360 dp phone if it is a `Row`.
3. **The project owner is colourblind, and roughly one boy in twelve has a
   red-green deficiency.** Colour may never be the only channel. A red "loša
   prolaznost" chip and a green "dobra" one that differ only in hue are
   unreadable to the person who will sign this off. Carry the meaning in a
   second channel too — a number, an icon, a shape, a label. See
   `brief-arrow-colours-2026-08.md` for the worked example and the measurement
   harness (`test/support/color_vision.dart`).
4. **User-facing strings are Serbian.** Code, comments and commits are English.
5. **Run `dart format` on every file you touch.** CI does not enforce it and the
   formatter reindents aggressively, so an unformatted file turns the next diff
   into noise.
6. **`flutter analyze` does not exit clean and has not for a long time**: 29
   known `info`s, all `curly_braces_in_flow_control_structures`. What must hold
   is zero errors, zero warnings and **no new infos** — compare the list, not
   the exit code.

## 6. How this will be judged

- `cd chess_app && flutter test` — 900 tests, 1 skipped, all green before you
  start. **Re-measure rather than trusting that number**, and say what it is
  afterwards. A suite that quietly stops running half of itself is the thing
  the count exists to catch.
- New widget tests assert what is **drawn** after an interaction, not what was
  stored. That is how the appearance work was judged and it caught two real
  bugs.
- At least one test pumps at `Size(360, 640)`.
- Prove any guard by mutation before believing it: break the thing on purpose,
  watch the test fail, put it back.

## 7. Not in scope

The endgame audit (section 2 of the plan) is being built on the backend in
parallel and will need its own screen later — do not start it. Neither the
mistake-puzzle set, the repertoire diff, nor the trainer-facing layer belong in
this batch. If the import screen and the report screen both work on a phone,
this job is done.
