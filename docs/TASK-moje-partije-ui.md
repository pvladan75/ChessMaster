# Task: the archive UI — import screen and opening leak report

A bounded job for an outside agent. **This file plus
[brief-moje-partije-ui-2026-08.md](brief-moje-partije-ui-2026-08.md) are the
only context you get** — do not rely on any conversation before them. When the
work is merged, this file is deleted.

Branch: `design/moje-partije-ui`, off `master`. Commit as `batch 47 — …`,
matching the numbering the earlier design batches used.

## What is asked

Two screens in `chess_app/`, against a backend that is already built, tested and
frozen. Read the brief for the *why* and for the exact API shapes; this file is
the scope and the method.

1. **Import screen.** Pick a `.pgn` file, send it, poll the run, and show the
   four counters with their reasons.
2. **Opening leak report screen.** The list of flagged positions, each with a
   board preview, how often and how badly, the move the player keeps choosing,
   and — when judging was asked for — the master recommendation.

**Nothing else.** If the job turns out to need a change outside `chess_app/`,
**write in your report which change and why, then stop.** Do not widen the
scope, and do not touch `chess_backend/` at all.

## What you need before starting

* **Flutter**, and `cd chess_app && flutter test` green before you change
  anything. Measure the count yourself and report it; do not trust a number
  quoted at you.
* **No backend, no database, no `.env`, and no credentials.** You do not need
  them and must not ask for them. Build against the response shapes documented
  in §3 of the brief, and write your widget tests against a faked API client the
  way the app's other services are faked in `chess_app/test/`. Running this
  against a live server is the project owner's job, and it is written down as
  `TODO-provera.md` item 53.
* A phone-sized viewport in every new test: `Size(360, 640)`.

## Where things are

| | |
|---|---|
| `chess_app/lib/features/` | one folder per feature — add yours the same way |
| `chess_app/lib/widgets/` | `SkinnedChessBoard` lives here; it takes a FEN |
| `chess_app/lib/theme/` | `context.colors`, `app_typography.dart` — no raw `Color(0x…)` |
| `chess_app/lib/widgets/app_feedback.dart` | every message goes through this |
| `chess_app/lib/services/` | the pattern for an API service to copy |
| `chess_app/lib/features/analysis_studio/widgets/board_setup_dialog.dart` | how a `.pgn` is picked today |

## Method, in this order

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Write the API client first, against the shapes in §3, with its own unit
   tests. It is the only place that knows about HTTP.
3. Import screen, then its tests.
4. Report screen, then its tests.
5. `dart format` every file you touched.
6. `flutter analyze` — **it does not exit clean and has not for a long time**:
   29 known `info`s, all `curly_braces_in_flow_control_structures`. What must
   hold is zero errors, zero warnings and **no new infos**. Compare the list,
   not the exit code.
7. `flutter test`. Report the count.

## What must hold

* Zero raw `ScaffoldMessenger` calls. `test/app_feedback_guard_test.dart` fails
  if one appears, and it is not a lint — it is there because a message about the
  work has twice killed the work.
* No `Row` that can outgrow a 360 dp phone. A release build clips silently; a
  test build throws, which is why the viewport size above is not optional.
* No meaning carried by colour alone. The project owner is colourblind and will
  be the one signing this off.
* User-facing strings in Serbian. Code, comments and commit messages in English.
* Every new test asserts what is **drawn** after an interaction, not what was
  stored.
* Prove any guard you add by mutation: break the thing on purpose, watch the
  test fail, put it back. Say in the report that you did.

## What to report

A short document with: the test count before and after, the `flutter analyze`
diff (not the exit code), what you proved by mutation, every decision you made
that the brief did not settle, and anything you found that looks wrong in the
backend contract. That last one is wanted — the API has never been exercised by
a real client, and you are the first.
