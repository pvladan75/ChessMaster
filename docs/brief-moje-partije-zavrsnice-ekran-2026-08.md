# Brief: the endgame screen, and a crash that left no evidence

Written 30.8.2026. Pairs with
[TASK-moje-partije-zavrsnice-ekran.md](TASK-moje-partije-zavrsnice-ekran.md),
which holds the scope and the method. This file holds the *why* and the API
contract.

## 1. Why this job exists

The same evening the archive got its first real use, the owner pressed the
button that checks his endgames and **the application closed**. Not an error
box, not a red screen — the process died. He restarted it and the screen he came
back to showed an app bar over nothing at all.

The cause of the crash is **not known**, and nothing in this job claims to fix
it. What is known is measured:

* The server has no record of the audit ever starting. `endgame_audits` is
  empty, and the row is inserted before anything else happens, so the request
  never reached the route.
* `tablebase_cache` is empty too — not one position was ever probed.
* A Windows release build that dies leaves nothing behind. No log, no dump,
  nothing to read the next morning.

That last point is the first half of this job. **A crash that leaves no evidence
can only be guessed at, and this one has already cost one evening of guessing.**

The second half is three defects on that screen which are real whether or not
they caused it, and two of them are in the memory-pressure family that is the
leading hypothesis.

## 2. What to build

### 2.1 A crash breadcrumb

The app installs no error handler at all — `FlutterError.onError`,
`PlatformDispatcher.instance.onError` and `runZonedGuarded` appear nowhere in
`lib/`. Add one, in `main()`, writing to a small rolling file.

* `path_provider` is already a dependency, and
  `services/engine_download_service.dart` shows the convention:
  `getApplicationSupportDirectory()` and a named subdirectory under it.
* Bounded. A crash log that fills a disk is a second bug. One file, capped, with
  the oldest lines dropped — a few hundred KB is more than enough.
* It must never be able to take down what it reports on. This codebase has
  shipped that exact failure twice — playback that never started because a
  failing audio call sat in front of the timer, and a recording that would not
  stop because `showSnackBar` threw first. Every write is inside a `try`, and a
  handler that throws must not become the crash.
* Nothing in it may identify a child. Timestamps, the error, the stack, the
  platform and the build label. **No user id, no names, no room codes, no
  tokens.** The repository is public and so, eventually, is anything a person
  pastes into an issue.
* Settings already has a build label and a copy button — a way to reach this
  file from Settings would be welcome but is optional. Getting it *written* is
  the point.

### 2.2 The three defects on the endgame audit screen

**A blank screen instead of a state.** `_buildBody` returns a bare `Column`
whenever the audit failed to start: `_loading` is false, `_audit` is null,
`_mistakes` is null, and the two `if`s produce nothing. An app bar over an empty
body. The owner called it "mrtav ekran". The screen needs four explicit states —
loading, error with a retry, running with its counters, and done — and *no path
through `_buildBody` that renders nothing*. An audit that finished and found
nothing says so.

**A `ChessBoardController` built inside `build()`**, at line 310:

```dart
controller: ChessBoardController()..loadFen(m.fenBefore),
```

A new `ChangeNotifier` for every card, on every rebuild, never disposed, up to
fifty at once. `lib/widgets/board_thumbnail.dart` is the answer and already
exists: it takes a FEN, renders a static board, is explicitly "not interactive —
purely a visual identifier for lists", and needs no controller at all.

It also fixes something the current code gets wrong for this owner in
particular. The card hardcodes `boardColor: BoardColor.green`, ignoring the
board skin the reader chose. **The owner is colourblind.** `BoardThumbnail`
takes the reader's chosen skin by default, which is the behaviour every other
list in the app already has.

**A list that is not lazy.** `_buildList` uses `ListView.builder`, but each item
is a whole `Column` holding every card in its group. One group of fifty
findings is fifty boards laid out at once, and the builder buys nothing. Flatten
it: one flat list where a heading and a card are each their own item, so the
builder is actually lazy.

### 2.3 Following an audit that is already running

The server allows one audit per user and refuses a second with 409. Until
30.8.2026 that refusal said only "already in progress" — so a client that
crashed mid-audit could neither start a run nor find the one still going, for
the full hour before the stale run is reaped. That is the second half of the
dead screen.

The refusal now names the run (§3). When `startEndgameAudit` meets a 409, the
screen attaches to the named audit and polls it, saying whose it is — **without
pretending it is the audit that was just asked for.** If the running audit is
for a different handle, say so plainly; the counters belong to that handle and
labelling them with this one would be a lie the reader cannot detect.

## 3. The API, exactly

Everything under `/games`, bearer token as everywhere else. All of it exists on
`master` and is frozen.

| Endpoint | Sends | Gets back |
|---|---|---|
| `POST /games/endgame/audit` | `{ username }` | `202 { auditId }`, or `409` — below |
| `GET /games/endgame/audits/:id` | — | the run |
| `GET /games/endgame/mistakes?limit=` | — | `{ mistakes: [mistake] }`, worst first |

The **409**, which is new and is what §2.3 is about:

```json
{ "error": "Provera završnica je već u toku.",
  "reason": "already-running",
  "auditId": "7",
  "subject": "pvladan" }
```

`auditId` is a `BIGSERIAL` and therefore arrives as a **string**. So does the
run's own `id`. Every counter beside them is `INTEGER` and arrives as a
**number**. `lib/features/archive/models/json_int.dart` reads both and exists
for exactly this; a plain `as int` cast reads them identically right up until it
throws on real data, and a faked API hands out real `int`s so no widget test
would ever catch it.

A run:

```json
{ "id": "7", "subject": "pvladan", "status": "running|done|failed",
  "games_total": 471, "games_done": 120, "positions_probed": 2140,
  "cache_hits": 890, "positions_unknown": 3, "mistakes_found": 11,
  "error": null, "started_at": "…", "finished_at": null }
```

Three things about it the UI must respect rather than smooth over:

1. **`positions_unknown` above zero is not a rounding error.** A position the
   tables will not commit to is a position nobody judged — not one the player
   got right. It is already shown in `danger` when non-zero; keep that.
2. **`games_total` is only the games that reached seven men**, about one in
   nine. An audit that walks 471 of 4126 games and finds nothing is not a
   verdict on the other 3655.
3. **A run can take a long time and that is now correct behaviour.** Requests to
   Lichess are paced and a 429 stops the run for a minute rather than knocking
   through it, so a `running` status that sits still for a while is the system
   working. Do not add a client-side timeout that calls it dead.

A mistake, already modelled by `EndgameMistake`:

```json
{ "id": "3", "game_id": "912", "ply": 74,
  "fen_before": "8/8/8/4k3/8/8/4P3/4K3 w - - 0 1",
  "played_uci": "e1d2", "best_uci": "e2e4",
  "wdl_before": 2, "wdl_after": 0,
  "due_at": "…", "played_at": "…", "opponent": "…", "result": "1/2-1/2" }
```

`best_uci` is nullable, and a mistake without one is not offered as a puzzle —
the screen already does this and it stays.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `lib/widgets/board_thumbnail.dart` | `BoardThumbnail(fen:, size:)`. Static, skin-aware, no controller |
| `lib/features/archive/services/archive_api_service.dart` | the client. `startEndgameAudit` is where the 409 lands |
| `lib/features/archive/models/json_int.dart` | see §3 |
| `lib/widgets/app_feedback.dart` | `error`, `success`, `info`, `warning`. Every message, no exceptions |
| `lib/services/engine_download_service.dart` | how this app finds a directory to write into |
| `lib/screens/settings_screen.dart` | `buildLabel()` and the copy button, if you surface the log |
| `test/features/archive/endgame_audit_screen_test.dart` | the existing tests and their fake |

## 5. Rules that bite

* **`flutter analyze` does not exit clean and has not for a long time.** 29
  `info`s, all `curly_braces_in_flow_control_structures`. Zero errors, zero
  warnings, **no new infos** — compare the list, not the exit code.
* **`flutter test` was 938 passing, 1 skipped** at `7ef10e5`. Batch 51 lands
  before this one and adds more. **Measure it yourself before you start and
  report both numbers**; the number here is history, not a target.
* **Zero raw `ScaffoldMessenger`.** `test/app_feedback_guard_test.dart` fails if
  one appears. It is not a lint. See §2.1 for why.
* **No `Row` that can outgrow a 360 dp phone.** A release build clips silently
  and the buttons past the edge cannot be reached; a test at `Size(360, 640)`
  throws. Use `Wrap` where a row can grow.
* **No raw colours, no `withOpacity`, no brightness checks.** `context.colors`.
  On this screen specifically: no hardcoded board colour.
* **User-facing strings in Serbian.** Comments and commit messages in English.
* **`dart format` every file you touch.**

## 6. How this will be judged

By `python orchestrate.py verify`, not by the report. The gates: `strings`,
`contrast`, `idioms`, `scale`, `dart format`, `worktree`, `flutter analyze`,
`flutter test`.

Beyond them, three questions:

1. Is there any input at all that makes `_buildBody` render an empty body?
2. Does a rebuild of the findings list allocate a controller per card?
3. If the app dies tomorrow, is there a file to read?

## 7. Not in scope

* **Fixing the crash.** Its cause is unknown. This job makes the next one
  legible; it does not claim to prevent it. Do not invent a fix for a defect
  nobody has diagnosed, and do not describe this work as fixing it.
* **Anything the archive home screen owns.** Batch 51 built it. If you find a
  bug in it, write it in your report rather than editing it.
* Any change under `chess_backend/`. The 409 shape in §3 is already on `master`.
  If this job needs a further change, **write in your report which change and
  why, then stop.**
