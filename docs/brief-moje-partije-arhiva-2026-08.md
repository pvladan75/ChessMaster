# Brief: the archive needs a front door

Written 30.8.2026, after the first live import. Pairs with
[TASK-moje-partije-arhiva.md](TASK-moje-partije-arhiva.md), which holds the
scope and the method. This file holds the *why* and the API contract.

## 1. Why this job exists

On 30.8.2026 the owner imported 4126 of his own Lichess games for the first
time. The import worked — 4126 read, 4126 stored, nothing skipped. Within ten
minutes every screen built on top of that archive was unreachable, and it stayed
unreachable.

One cause. The four analysis screens — opening leaks, endgame audit, repertoire
diff, player profile — are rendered only inside this condition in
`archive_import_screen.dart`:

```dart
if (_run!.status == 'done' && _run!.gamesStored > 0) ...[
```

`_run` is set only by the poll timer, only after an upload, only in the current
instance of that screen. Leave the screen and it is null again. So the archive
has a door only in the seconds after an import finishes.

Then it gets worse. The owner re-imported the same file to get back in. The
importer is correctly idempotent, so the second run recorded:

```
Uvoz 2 gotov: {"read":4126,"stored":0,"duplicate":4126,"skipped":0}
```

`games_stored` is 0. The condition fails. **The buttons never come back, and
re-importing is the only thing the screen offers.** His words: "taj ekran
postaje neupotrebljiv."

A `grep` over `chess_app/lib/` confirms there is no second door:
`archiveLeaksPath`, `archiveEndgamesPath`, `archiveProfilePath` and
`archiveRepertoire` each appear in exactly one file — the import screen.

The second, smaller failure the same evening: he built a repertoire from the
archive. The server wrote 2376 moves across both colours and logged it. He saw
nothing, because `repertoire_moves` belongs to `(user, colour)` and the seed
creates no `repertoires` row — and the repertoire list screen reads
`repertoires`. The write succeeded and reported success into a void.

Both are the same shape, and it is the shape this codebase keeps meeting: a step
that works, reports success, and leaves nothing a person can reach.

## 2. What to build

### 2.1 The archive home screen — new

A screen at `/archive` that is the permanent entrance to the player's own games,
and does not depend on an import having just happened.

It shows, per subject the archive holds:

* the handle, and how many of that player's games are stored;
* how many of them ever reached seven men or fewer (that is what the endgame
  audit can work on, and it is about one game in nine — saying so up front stops
  "the audit found nothing" reading as "you play endgames perfectly");
* the date range the games span;
* four doors, always present and never conditional: **Rupe u otvaranju**,
  **Završnice**, **Repertoar**, **Profil i navike**.

Above or below that, one line about the last import run — read from
`GET /games/imports` — saying plainly what it did: how many were read, how many
were new, how many were already there. A re-import that stores nothing must
*say* that it stored nothing because everything was already imported, rather
than looking like a failure. That sentence is half the reason this screen
exists.

And a persistent action to import more games, which pushes the existing
`ArchiveImportScreen`.

When the archive is empty, the screen is the import invitation and nothing else.

### 2.2 The import screen — one condition, and a way out

Change the gate from `gamesStored > 0` to:

```dart
_run!.status == 'done' && (_run!.gamesStored + _run!.gamesDuplicate) > 0
```

That is the precise question. "Did this run leave games in the archive under
this handle?" is true whether they arrived today or three weeks ago; it is false
only for a file that produced nothing, which is the one case where offering the
four screens would be a lie.

Everything else on that screen stays as it is. The four buttons keep their
comment about being offered rather than jumped to — that decision was right and
is not what broke.

### 2.3 The repertoire seed — say where it went

On the repertoire diff screen, the message after a successful write currently
reads:

> Upisano 1253 novih poteza i postavljeno 691 primarnih opcija.

True, and useless: it does not say where they went, and the place they went to
did not appear in any list. The server now names the repertoire it wrote into
(§3), so the message says that name, and the screen offers a way to open it.

## 3. The API, exactly

Everything under `/games`, bearer token as everywhere else. Two additions land
on the backend before this job starts; the rest already exists and is frozen.

| Endpoint | Sends | Gets back |
|---|---|---|
| `GET /games/subjects` | — | `{ subjects: [subject] }` — **new** |
| `GET /games/imports` | — | `{ runs: [run] }`, newest first, max 10 |
| `GET /games/stats` | — | `{ games, with_clocks, reached_tablebase, subjects, oldest, newest, plies }` |
| `POST /games/repertoire/seed` | `{ username, color?, minGames?, dryRun? }` | seed result, now with `repertoireName` |

A `subject`:

```json
{ "subject": "pvladan",
  "games": 4126,
  "reached_tablebase": 471,
  "with_clocks": 3632,
  "oldest": "2015-03-11T19:22:04.000Z",
  "newest": "2026-08-28T21:03:55.000Z",
  "last_import_at": "2026-08-30T17:49:49.163Z" }
```

Own games only — `subject_is_owner = TRUE`. Ordered by `games` descending. The
three dates are nullable. An archive with nothing in it answers
`{ "subjects": [] }`, never a 404.

A `run` — unchanged, and already modelled by `ArchiveRun`:

```json
{ "id": "1", "source": "pgn", "subject": "pvladan", "status": "done",
  "games_read": 4126, "games_stored": 0, "games_duplicate": 4126,
  "games_skipped": 0, "skipped_by_reason": {}, "error": null,
  "started_at": "...", "finished_at": "..." }
```

The seed result gains one nullable field:

```json
{ "dryRun": false, "positions": 687, "moves": 1253,
  "unplayable": 0, "added": 1253, "primary": 691,
  "repertoireName": "Iz mojih partija — beli" }
```

`repertoireName` is null on a dry run, and null if the server could not name one
— in which case say the count and stop, do not invent a name.

**Integers arrive in two spellings.** `id` and `game_id` are `BIGSERIAL`, and
node-postgres hands `int8` back as a *string*; every counter beside them is
`INTEGER` and arrives as a *number*. `lib/features/archive/models/json_int.dart`
exists for exactly this and reads both. Use it for every integer field on this
job, including the ones that look like plain numbers today. A plain `as int`
cast reads the two identically right up until it throws on real data, and a
faked API hands out real `int`s so no widget test would ever catch it.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `lib/features/archive/services/archive_api_service.dart` | the client. Add methods here; it is the only place that knows about HTTP |
| `lib/features/archive/models/` | `ArchiveRun` is done and correct. Add a `ArchiveSubject` model beside it |
| `lib/features/archive/models/json_int.dart` | see §3 |
| `lib/routing/app_routes.dart`, `app_router.dart` | every path is a constant, and screens are pushed by path |
| `lib/widgets/app_feedback.dart` | every message goes through this. No exceptions |
| `lib/theme/` | `context.colors`, `app_typography.dart`, `AppSpacing`, `AppRadii` |
| `test/features/archive/*_test.dart` | five files, each with its own `FakeArchiveApiService` |

**The five fakes are the friction on this job.** Each one `implements
ArchiveApiService`, so every method added to that class breaks all five until
they are updated. That is the design working — a fake that silently ignored a
new method would be a test that passes against an API it has never seen. Update
all five; do not soften the interface to avoid it.

## 5. Rules that bite

* **`flutter analyze` does not exit clean and has not for a long time.** It
  reports 29 `info`s, all `curly_braces_in_flow_control_structures`. What must
  hold is zero errors, zero warnings, and **no new infos**. Compare the list,
  not the exit code.
* **`flutter test` is 938 passing, 1 skipped**, measured 30.8.2026 at
  `7ef10e5`. The one skip is the golden group, skipped unconditionally in
  `dart_test.yaml`. Measure the number yourself before you change anything and
  report both numbers; do not trust the one quoted here.
* **Zero raw `ScaffoldMessenger`.** `test/app_feedback_guard_test.dart` fails if
  one appears. It is not a lint — it is there because a message about the work
  has twice killed the work: playback that never started because a failing audio
  call sat in front of the timer, and a recording that would not stop for a
  child because `showSnackBar` threw first. **Do the thing, then say it.**
* **No `Row` that can outgrow a 360 dp phone.** A release build paints no
  overflow warning; the row is simply clipped and the buttons past the edge are
  unreachable. Three of these shipped. Where a row can grow, use `Wrap`; where a
  width is fixed, take it from `MediaQuery`. Every new widget test runs at
  `Size(360, 640)`, where the overflow does throw.
* **No raw colours.** No `Color(0x…)`, no `withOpacity` (use `withValues`), no
  `Theme.of(context).brightness` checks. Colours come from `context.colors`.
* **User-facing strings stay Serbian.** The users are Serbian children and
  trainers. Code comments and commit messages are English.
* **`dart format` every file you touch.** CI does not enforce it and the
  formatter reindents aggressively, so an unformatted file turns the next diff
  into noise.

## 6. How this will be judged

By `python orchestrate.py verify`, not by the report. Every verdict is an exit
code, a parsed count or a byte comparison — three reports on this project have
been more confident than their diffs, and none of them were lies; all of them
were the model grading itself.

The gates: `strings`, `contrast`, `idioms`, `scale`, `dart format`, `worktree`,
`flutter analyze`, `flutter test`.

`strings` fails on any user-facing string differing from the baseline byte for
byte. This job **adds** strings, which is allowed only for files named in the
allowance — say in your report which files you added strings in, and if the gate
fails on an addition in a new file, that is the harness needing the file listed,
not you needing to delete the string. Removals and edits still fail, always.

Beyond the gates, the job is judged on one question: **after this batch, can a
person who imported games last week reach all four analysis screens without
importing anything?** If the answer needs a caveat, the batch is not done.

## 7. Not in scope

* `endgame_audit_screen.dart` — its blank state, its in-build
  `ChessBoardController` and its non-lazy list are batch 52. Do not touch that
  file; two batches editing it would collide.
* Any change under `chess_backend/`. The two API additions in §3 land before you
  start. If this job turns out to need a third, **write in your report which
  change and why, then stop.**
* The Windows crash reported the same evening. Its cause is not yet known and
  nothing here is a fix for it.
* The storage work — truncating games to head plus endgame tail, and
  aggregating `opening_nodes`. That is a separate track and it is one-way.
