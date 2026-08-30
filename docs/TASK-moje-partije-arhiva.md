# Task: the archive front door

A bounded job for an outside agent. **This file plus
[brief-moje-partije-arhiva-2026-08.md](brief-moje-partije-arhiva-2026-08.md) are
the only context you get** — do not rely on any conversation before them. When
the work is merged, this file is deleted.

Branch: `design/moje-partije-arhiva`, off `master`. Commit as `batch 51 — …`,
matching the numbering the earlier batches used.

## What is asked

Flutter only, in `chess_app/`, against a backend that is already built and
frozen. Read the brief for the *why* and the exact API shapes; this file is the
scope and the method.

1. **A new archive home screen** at `/archive` — the permanent entrance to the
   player's own games, with the four analysis screens always reachable from it.
2. **Both hub entry points** redirected to it.
3. **One condition fixed** on the existing import screen.
4. **One message fixed** on the existing repertoire diff screen.

**Nothing else.** If the job turns out to need a change outside `chess_app/`,
**write in your report which change and why, then stop.** Do not widen the
scope, and do not touch `chess_backend/` at all.

## What you need before starting

* **Flutter**, and `cd chess_app && flutter test` green before you change
  anything. Measure the count yourself and report it; do not trust a number
  quoted at you. It should be 938 passing, 1 skipped.
* **No backend, no database, no `.env`, and no credentials.** You do not need
  them and must not ask for them. Build against the response shapes in §3 of the
  brief, and write your widget tests against a faked API client the way
  `test/features/archive/` already does. Running this against a live server is
  the project owner's job; it goes into `TODO-provera.md` when the batch merges.
* A phone-sized viewport in every new test: `Size(360, 640)`.

## Where things are

| | |
|---|---|
| `chess_app/lib/features/archive/` | the feature. Screens, models, services, widgets |
| `chess_app/lib/features/archive/services/archive_api_service.dart` | the only place that knows about HTTP |
| `chess_app/lib/routing/app_routes.dart` | every path is a constant here |
| `chess_app/lib/routing/app_router.dart` | the `GoRoute` table |
| `chess_app/lib/features/training/screens/training_hub_screen.dart` | one of the two hub entry points |
| `chess_app/lib/screens/ai_studio_screen.dart` | the other one — search for `onSelectMyGames` |
| `chess_app/lib/widgets/app_feedback.dart` | every message goes through this |
| `chess_app/lib/theme/` | `context.colors`, `app_typography.dart` — no raw `Color(0x…)` |
| `chess_app/test/features/archive/` | five test files, five fakes to update |

## The four changes, in this order

### 1. The API client

Add to `ArchiveApiService`:

* `getSubjects()` → `List<ArchiveSubject>` from `GET /games/subjects`
* `listImports()` → `List<ArchiveRun>` from `GET /games/imports` (the response
  is `{ runs: [...] }`; `ArchiveRun` already parses a run)

Add an `ArchiveSubject` model beside `ArchiveRun`, parsing every integer through
`jsonInt` and every date as nullable.

Add `repertoireName` (nullable `String`) to `RepertoireSeedResult`.

Then update all five `FakeArchiveApiService` classes so the suite compiles.
Unit-test the two new client methods against a fake `http.Client` using
`ArchiveApiService.withClient` — that constructor exists precisely so a test can
see the request rather than replace it, and it is the only kind of test that
would catch a wrong query parameter or a wrong header.

### 2. The archive home screen

`chess_app/lib/features/archive/screens/archive_home_screen.dart`, plus
`AppRoutes.archiveHome = '/archive'` and its `GoRoute`.

Content is in §2.1 of the brief. Three states, all of them explicit:

* **loading** — a spinner, nothing else;
* **empty** — no subjects: the import invitation, and no dead doors;
* **loaded** — one card per subject with its counts and its four doors, plus the
  last-import line and the persistent import action.

A failure to load is its own state with a retry, not a blank screen under an app
bar. There is a live bug of exactly that shape on another screen in this feature
and it is what the owner called "mrtav ekran" — do not add a second one.

Tests: the empty state, the loaded state with two subjects, the error state, and
that each of the four doors pushes the right path with the subject in the query.
All at `Size(360, 640)`.

### 3. The two hub entry points

`onSelectMyGames` currently pushes `AppRoutes.archiveImport` in both
`training_hub_screen.dart` and `ai_studio_screen.dart`. Both become
`AppRoutes.archiveHome`. The import screen keeps its own route and is reached
from the home screen.

### 4. The import screen and the seed message

The one-line condition change is §2.2 of the brief; the message change is §2.3.
Both need a test that fails before the change and passes after — in particular
a run with `gamesStored: 0, gamesDuplicate: 4126, status: 'done'` must show the
four buttons, because that exact run is what the owner hit.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Client and models first, with their unit tests.
3. Home screen, then its tests.
4. The two small edits, each with the test that proves it.
5. `dart format` every file you touched.
6. `flutter analyze` — **it does not exit clean and has not for a long time**:
   29 known `info`s, all `curly_braces_in_flow_control_structures`. What must
   hold is zero errors, zero warnings and **no new infos**. Compare the list,
   not the exit code.
7. `flutter test`. Report the count, and the delta from the number you measured
   at the start.

## What must hold

* Zero raw `ScaffoldMessenger` calls. `test/app_feedback_guard_test.dart` fails
  if one appears, and it is not a lint — it is there because a message about the
  work has twice killed the work.
* No `Row` that can outgrow a 360 dp phone. A release build clips silently; a
  test at `Size(360, 640)` throws. Use `Wrap` where a row can grow.
* No raw colours, no `withOpacity`, no brightness checks. `context.colors`.
* User-facing strings in Serbian. Comments and commit messages in English.
* Every new integer read through `jsonInt`. See §3 of the brief for why.

## Your report

Write `report-batch-51.md` in the worktree root. It must state:

* the test count before and after, both measured by you;
* the `flutter analyze` info count and whether the list changed;
* every file you added user-facing strings in — the `strings` gate needs them
  named;
* anything you found that the brief got wrong. The brief was written from a
  reading of the code, not from running it, and a correction is worth more than
  a clean report.

**Do not claim a number you did not compute in that run.** Three reports on this
project have been more confident than their diffs.
