# Task: the endgame screen, and evidence for the next crash

A bounded job for an outside agent. **This file plus
[brief-moje-partije-zavrsnice-ekran-2026-08.md](brief-moje-partije-zavrsnice-ekran-2026-08.md)
are the only context you get** — do not rely on any conversation before them.
When the work is merged, this file is deleted.

Branch: `design/moje-partije-zavrsnice-ekran`, off `master` **after batch 51 has
merged**. Commit as `batch 52 — …`.

## What is asked

Flutter only, in `chess_app/`, against a backend that is already built and
frozen. Read the brief for the *why* and the exact API shapes; this file is the
scope and the method.

1. **A crash breadcrumb** in `main()` — the app currently installs no error
   handler of any kind, and a Windows release build that dies leaves nothing to
   read.
2. **The endgame audit screen**, rebuilt in three respects: no state that
   renders an empty body, no `ChessBoardController` allocated in `build()`, and
   a findings list that is actually lazy.
3. **Following a running audit** when the server answers 409.

**Nothing else.** If the job turns out to need a change outside `chess_app/`,
**write in your report which change and why, then stop.** Do not touch
`chess_backend/`.

## What you need before starting

* **Flutter**, and `cd chess_app && flutter test` green before you change
  anything. Measure the count yourself and report it. Batch 51 landed before
  this job, so the number in the brief is history rather than a target.
* **No backend, no database, no `.env`, and no credentials.** You do not need
  them and must not ask for them. Build against the response shapes in §3 of the
  brief, and fake the API the way `test/features/archive/` already does.
* A phone-sized viewport in every new test: `Size(360, 640)`.

## Where things are

| | |
|---|---|
| `chess_app/lib/main.dart` | where the error handler goes |
| `chess_app/lib/services/engine_download_service.dart` | how this app finds a directory to write into |
| `chess_app/lib/features/archive/screens/endgame_audit_screen.dart` | the screen |
| `chess_app/lib/widgets/board_thumbnail.dart` | `BoardThumbnail(fen:, size:)` — static, skin-aware |
| `chess_app/lib/features/archive/services/archive_api_service.dart` | where the 409 lands |
| `chess_app/lib/widgets/app_feedback.dart` | every message goes through this |
| `chess_app/test/features/archive/endgame_audit_screen_test.dart` | the existing tests and their fake |

## The three changes, in this order

### 1. The crash breadcrumb

A small service that opens a bounded file under
`getApplicationSupportDirectory()` and appends a record: timestamp, error,
stack, platform, build label. Wired in `main()` to `FlutterError.onError` and
`PlatformDispatcher.instance.onError`.

Three constraints, all of them load-bearing:

* **It cannot throw.** Every write inside a `try`. A handler that becomes the
  crash is worse than no handler.
* **It cannot grow without end.** Cap the file and drop the oldest.
* **It carries nothing that identifies a child.** No user id, no names, no room
  codes, no tokens. The repository is public and so is anything a person pastes
  into an issue.

Test it as a unit against a temporary directory: that a record is written, that
the cap holds when the file is already full, and that a write into an
unwritable directory returns quietly instead of throwing. That last test is the
point of the whole file.

### 2. The endgame audit screen

Four explicit states — loading, error with a retry, running with its counters,
done — and **no path through `_buildBody` that renders nothing**. An audit that
finished with no findings says so; an audit that could not start says why and
offers to try again.

Replace the in-`build()` `ChessBoardController` with `BoardThumbnail`, which
takes a FEN and no controller. Drop `boardColor: BoardColor.green` with it; the
reader's chosen skin is `BoardThumbnail`'s default and the owner is colourblind,
so a hardcoded board is not a cosmetic detail here.

Flatten `_buildList` so `ListView.builder` is lazy: a heading is one item and a
card is one item, rather than a whole group being one item.

Tests: each of the four states renders something; a list of fifty findings
allocates no controller and does not build all fifty cards at once; the existing
tests still pass. All at `Size(360, 640)`.

### 3. Following a running audit

`startEndgameAudit` currently throws on anything that is not a 202. Teach it the
409: read `auditId` and `subject` through `jsonInt`/`as String?` per §3 of the
brief, and hand them back rather than losing them in an exception message.

The screen then attaches to that audit and polls it — **saying whose it is.** If
the running audit is for a different handle, the screen says so; the counters
belong to that handle and labelling them with the one that was asked for is a
lie the reader cannot detect.

Test: a 409 with a different `subject` attaches, polls, and names the other
handle on screen.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. The crash breadcrumb and its unit tests.
3. The client's 409 handling, with a unit test using
   `ArchiveApiService.withClient` — that constructor exists so a test can see
   the real request rather than replace it.
4. The screen, then its tests.
5. `dart format` every file you touched.
6. `flutter analyze` — **it does not exit clean and has not for a long time**:
   29 known `info`s, all `curly_braces_in_flow_control_structures`. Zero errors,
   zero warnings and **no new infos**. Compare the list, not the exit code.
7. `flutter test`. Report the count and the delta from your own starting number.

## What must hold

* Zero raw `ScaffoldMessenger` calls. `test/app_feedback_guard_test.dart` fails
  if one appears, and it is not a lint — it is there because a message about the
  work has twice killed the work. **Do the thing, then say it.**
* No `Row` that can outgrow a 360 dp phone.
* No raw colours, no `withOpacity`, no brightness checks, no hardcoded board
  colour.
* User-facing strings in Serbian. Comments and commit messages in English.
* Every integer from the wire read through `jsonInt`.

## Your report

Write `report-batch-52.md` in the worktree root. It must state:

* the test count before and after, both measured by you;
* the `flutter analyze` info count and whether the list changed;
* every file you added user-facing strings in — the `strings` gate needs them
  named;
* **how you proved the lazy list is lazy.** "It uses `ListView.builder`" is not
  proof; the old code used one too and built everything anyway;
* anything the brief got wrong. It was written from a reading of the code, not
  from running it, and a correction is worth more than a clean report.

**Do not claim a number you did not compute in that run**, and **do not describe
any of this as fixing the crash.** The crash is undiagnosed. This work makes the
next one readable.
