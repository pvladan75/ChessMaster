# Task: what the archive says about a player, and what a trainer may do with it

A bounded job for an outside agent. **This file is the only context you get** —
do not rely on any conversation before it, and do not go looking for the plan
documents it was distilled from. When the work is merged, this file is deleted.

Branch: `design/moje-partije-profil`, off `master`. Commit as `batch 50 — …`.

Two screens in `chess_app/`, over a backend that is **already built, tested and
frozen**. Nothing in this job changes `chess_backend/`.

Read §7 before writing anything, and §3 before designing the trainer half. §3
is the one rule in this brief that is about honesty rather than about crashes,
and it is the one most likely to be broken by building something that looks
good.

---

## 1. Why this job exists

The archive has been imported and analysed from four directions — openings,
endgames, mistakes, repertoire — and every one of those is a *position*. What
is missing is the shape of the player: which colour they score worse with, what
happens to them in blitz, whether their games die before move twenty, and what
the clock does to them.

All of it is one `GROUP BY` over games already stored. No engine, no network,
no waiting.

And the other half: a trainer can already be shown a student's leaks and
recurring mistakes, and can turn them into homework made of positions **that
child actually got wrong**. Nobody chose those positions. That is the whole
point of the feature and the sentence the screen has to earn.

## 2. The two screens

### 2.1 The player's own profile

`GET /games/profile?username=` returns seven groupings plus a clock section.
Each grouping is a list of `{key, games, score}`, sorted by `games` descending,
where `score` is 0–1.

- `byColor` — `w` and `b`. Render as „beli"/„crni".
- `bySpeed`, `byTermination` — the key may be `'nepoznato'`; that is a real
  bucket, not a missing value.
- `byLength` — keys are already Serbian: „do 20. poteza", „20-40. potez",
  „preko 40. poteza".
- `byPhase` — also Serbian: „stigla do tablica", „stigla u završnicu",
  „rešena pre završnice".
- `byYear` — sorted oldest first, and carries `avgElo` as well.
- `byOpening` — `"B90 Sicilian Defence"` style keys, only openings with 10+
  games, at most 25.

**A grouping is only worth showing beside its own count.** „Sa crnim skoruješ
38%" over nine games is noise; over nine hundred it is the finding. Put the
number of games next to every percentage, always. This is the single most
common way a report like this lies without saying anything false.

### 2.2 The clock

`clock` is its own object and the most interesting part of the screen:

```json
{ "sampled": 400, "reachedMove20": 356, "lostOnTime": 41,
  "hurriedShare": 0.12,
  "atMove20": [ { "key": "under-30s", "games": 88, "score": 0.31 },
                { "key": "30-60s",    "games": 120, "score": 0.44 },
                { "key": "60-120s",   "games": 96, "score": 0.52 },
                { "key": "over-120s", "games": 52, "score": 0.58 } ] }
```

`atMove20` buckets games by **how much time was left at move 20**, with the
score in each. That is a sentence a player can act on: "when you reach move 20
with under thirty seconds you score 31%; with over two minutes, 58%."

`hurriedShare` is the fraction of the player's moves after the opening that took
under three seconds. `lostOnTime` is games lost on the clock. `sampled` is how
many games carried clock data at all — **show it**, because a clock section
computed from 12 games and one computed from 400 look identical otherwise.

The four bucket keys are not Serbian. Translate them.

### 2.3 The trainer's view of a student

Reached from the existing student screen — see §5. `GET /assignments/student/:id/archive`:

```json
{ "subject": "handle", "games": 4126,
  "leaks":   { … the opening leak report, limit 10 … },
  "mistakes":{ "byKind": {…}, "total": 0, "due": 0, "mature": 0 },
  "recurrence": { "sampled": 0, "motifs": [bucket], "endings": [bucket] },
  "trend":   [ { "month": "2025-09", "games": 41, "score": 0.48, "avgElo": 1642 } ] }
```

When the student has imported nothing, it answers
`{ "subject": null, "games": 0, "leaks": null, "mistakes": null }` — handle that
first, because it is the state every trainer will meet before any student has
imported anything. „Učenik još nije uvezao partije" is the screen, not an error.

Then homework: `POST /assignments/from-archive` with
`{ studentId, count?, kind?, title?, instructions?, dueAt?, dryRun? }`.

**`dryRun: true` first, always.** It returns the positions that would be set and
writes nothing:

```json
{ "dryRun": true, "candidates": 37,
  "chosen": [ { "mistakeId": "4471", "kind": "engine", "theme": "fork",
                "fen": "…", "playedSan": "Nd2", "solutionSan": "Ne5",
                "playedAt": "…", "opening": "French Defence" } ] }
```

A trainer should see which of a child's mistakes are about to become homework
before the child does. Only a second, explicit press sends it. The real call
answers `201` with `{ dryRun: false, assignment, items, candidates, skipped }`.

Refusals come back with a Serbian message already written — `403` for a student
who is not theirs, `400` for the rest, including „Sebi se domaći ne zadaje."
Print the server's message; do not compose your own.

## 3. The trend is not a before-and-after

`trend` is twelve months of `{month, games, score, avgElo}`, newest last.

**It must never be drawn, labelled, or described as "before and after", and
nothing on the screen may attribute a change in it to anything.** No "since you
started working on endgames", no arrow, no green-up-red-down against a training
plan, no split of the series into two halves with a divider.

The reason is not caution. A real before-and-after needs a date to compare
across — the day a student started working on something — and **nothing in the
schema records one.** Draw it as a before-and-after and you credit a training
plan with whatever the player happened to do that month. It would look like the
most valuable number on the screen and it would be an invention.

Draw it as what it is: months, games per month, score per month. If you want a
single sentence over it, it can say the direction of the last twelve months and
nothing about the cause.

This is the backend's own wording, in the source, at the point that computes it.
It is repeated here because the temptation lives entirely in the UI.

## 4. Types: what arrives as a string

The backend serves database rows directly, and node-postgres returns two
Postgres types as JSON *strings* rather than numbers. A `as int` cast on any of
them compiles, passes every test whose fake returns a real `int`, and throws the
first time it meets the server. This shipped once already.

| Field | Arrives as |
|---|---|
| `mistakeId`, any `id`, `gameId` | **string** — `"4471"` |
| `games`, `score`, `avgElo`, `sampled`, `count`s | number |
| `score`, `hurriedShare` | number 0–1, **or `null`** when nothing was sampled |
| `oldest`, `newest`, `playedAt`, `dueAt` | ISO-8601 string, or null |
| `theme`, `opening`, `avgElo`, `subject` | may be null |

`lib/features/archive/models/json_int.dart` holds a tolerant reader. Use it for
numbers, keep ids as strings, and **make your fakes return the string form** — a
fake handing back `4471` where the server sends `"4471"` is a test that proves
the opposite of its claim.

`score: null` is not zero. It means no games, and „0%" is a different and false
statement.

## 5. What already exists — reuse, do not rebuild

- **The archive feature folder.** `lib/features/archive/` holds the API service,
  models and four screens from batches 47–49. Put the profile screen beside
  them and follow their shape.
- **The trainer's student screen already exists**:
  `lib/features/assignments/screens/student_progress_screen.dart`, on route
  `/students/:id`. Related pieces sit under `lib/features/trainer_panel/` —
  `widgets/trainer_panel_view.dart`, `services/trainer_panel_api_service.dart`,
  `models/trainer_panel.dart`. The archive view belongs **inside the existing
  student screen**, as a section or a tab — not as a second, separate screen for
  the same student. `AppRoutes.studentProgressPath(id, name:)` already exists.
- **The board**: `BoardThumbnail(fen:, size:, isWhiteBottom:)` for previews,
  `SkinnedChessBoard` for anything interactive.
- **The real-transport seam**: `ArchiveApiService.withClient` — see rule 1.
- Colours and text: `context.colors`, `lib/theme/app_typography.dart`. No raw
  `Color(0x…)`.
- Messages: `lib/widgets/app_feedback.dart`.

## 6. Reachability is part of the job

**Three batches in a row have built screens the app cannot open**, and every
time the suite was green, because a widget test constructs a screen directly and
never asks whether anyone can get to it.

So, explicitly, and it will be checked:

1. The profile screen has a route in `app_routes.dart` + `app_router.dart`, and
   something the user can press that reaches it. The archive import screen
   already offers three such hand-offs after a finished run — add a fourth, the
   same way, since the profile needs the same handle.
2. The trainer's archive view is reachable from the existing student screen.
3. **A test asserts each of those paths.** Not that the widget builds — that the
   route resolves and the entry point exists.

If a new card is added to the training hub, its callback must be added at
**both** call sites of `CategorySelectionHubWidget`, and the four golden
screenshots regenerated with
`flutter test --tags golden --run-skipped --update-goldens`.

## 7. Rules that bite

Each one is a bug this project already shipped.

1. **A faked service cannot see a request the server would refuse.** Batch 48
   shipped two screens that failed on *every* load — they sent `color=white`
   where the backend accepts only `w` — under a 910-test green suite, because
   the widget tests replace the API service wholesale. **At least one test must
   drive the real service over a fake `http.Client`** via
   `ArchiveApiService.withClient` and assert the URL, query parameters and body
   that actually go out.
2. **Never call `ScaffoldMessenger` directly.** Use `AppFeedback`.
   `test/app_feedback_guard_test.dart` fails if a raw call returns. Twice a
   message about the work has killed the work. **Do the thing, then say it.**
3. **A release build paints no overflow warning.** A `Row` wider than the screen
   is clipped in silence. Use `Wrap` where a row can grow. Every new widget test
   pumps at `Size(360, 640)`. A profile screen is mostly rows of
   label-count-percentage, and it is exactly the shape that overflows.
4. **Colour is never the only channel.** The project owner is colourblind and
   will sign this off. A red bar and a green bar that differ only in hue are
   unreadable; carry the meaning in a number or a label too.
5. **User-facing strings are Serbian.** Code, comments and commits are English.
6. **`dart format` every file you touch.** Batches 48 and 49 both skipped this.
7. **`flutter analyze` does not exit clean**: 29 known `info`s, all
   `curly_braces_in_flow_control_structures`. Zero errors, zero warnings, **no
   new infos** — compare the list, not the exit code. Dead fields in a fake
   count.
8. **`find.text` matches the whole string.** Use `find.textContaining` for a
   substring, and **read the last line of the suite** before reporting a count.
9. **Assert what is drawn, not what was stored.**
10. **Prove every guard by mutation.** Break it, watch the test fail, put it
    back, and say which mutations you ran.

## 8. How this will be judged

- `cd chess_app && flutter test` — **920 tests, 1 skipped, all green before you
  start.** Re-measure and say what it is afterwards.
- At least one test pumps at `Size(360, 640)`; at least one drives the real API
  service over a fake transport; at least one asserts reachability.
- A test that fails if the trend is labelled as a before-and-after would be
  welcome, and is the kind of thing §3 exists for.

## 9. Not in scope

Opponent preparation and the AI description are behind a decision nobody has
made; do not start them. Do not touch `chess_backend/`. If the job needs a
change outside `chess_app/`, **write in your report which change and why, then
stop.**

## 10. What to report

Test count before and after, measured yourself. The `flutter analyze` diff, not
the exit code. Which mutations you ran and what failed. What your
real-transport test asserts, and what your reachability test asserts. How you
translated the clock buckets. Every decision this file did not settle. And
anything that looks wrong in the backend contract — that is wanted, and has paid
off in all three previous batches.

**You do not need a backend, a database, an `.env` or any credentials, and must
not ask for them.**
