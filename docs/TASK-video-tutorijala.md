# Task — a tutorial becomes a video, batch 67: the route and the door

**This file plus `docs/brief-video-tutorijala-2026-09.md` are the only context
you get.** Read the brief first, then `docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.**

Branch: `batch/video-tutorijala`. **Do not commit.**

Three of phase 2's four pieces are already built and gated. Yours is the fourth:
the way in and the way out. Nothing about the drawing is your problem.

## What to do

### 1. The route — `chess_backend/routes/lessons.js`

Add `POST /lessons/:id/export-video`, modelled on
`POST /recordings/:id/export-mp4` in `chess_backend/routes/recordings.js`. Read
that route first; copy its order of operations exactly.

* `authenticateToken`, then `requireEntitlement(ENT.MP4_EXPORT)`, before any
  work.
* Resolve the row with `id = $1 AND (user_id = $2 OR trainer_id = $2)`, the
  condition update, delete and clone in this file already use. 404 otherwise.
* Body: `{ events, seconds, title, resolution, pieceStyle, boardTheme }`.
  400 when `events` is not a non-empty array or `seconds` is not a positive
  integer. Clamp `seconds` to 3600 rather than refusing.
* `videoRenderer.renderRecordingToMP4` with `audioFilePath: null` and
  `showMoveText: false`.
* Sign a download token the way the recording export does and answer with a
  `downloadUrl` pointing at the **existing**
  `GET /recordings/export-download/:filename`. Do not add a second download
  route.
* Book `METRIC.MP4_RENDERS` and `METRIC.MP4_RENDER_SECONDS` only after the
  render succeeded.

### 2. The door — `chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`

A third icon on each saved-tutorial row, beside „Send to student" and delete,
sharing the same `_busy` flag.

* `TutorialDraft.fromLesson(row)` → `tutorialVideoOf(draft)`.
* `canRenderVideo` false → refuse with a sentence, send nothing.
* `fitsInOneFilm` false → refuse with a sentence that says how long it is, send
  nothing.
* Otherwise POST through the API service the card already uses, and show the
  result the way `chess_app/lib/screens/replay_player_screen.dart` shows a
  finished export.
* Every message through `AppFeedback`. Do the thing, then say it.

### 3. The tests

Backend, in `chess_backend/test/`:

1. no entitlement → refused, and the renderer is never called;
2. somebody else's tutorial → 404, and the query carries the user;
3. empty `events` → 400, nothing written to `exports/`;
4. `seconds` over 3600 → clamped, not refused;
5. metering booked after a successful render, and **not** after a failed one;
6. the answer carries a `downloadUrl` naming the file that was written.

App, in `chess_app/test/`:

7. the icon is on the row and disabled while it is busy;
8. an empty tutorial is refused **with no request sent** — assert on the fake
   API;
9. a normal tutorial sends the `events` and `seconds` `tutorialVideoOf` produces
   for that draft. **Assert on the request.**

Fake the renderer. **Do not spawn `ffmpeg` in a test.**

## Rules

* Do not touch `chess_backend/videoRenderer.js`,
  `chess_app/lib/features/tutorial_studio/services/tutorial_video.dart`,
  `chess_backend/db.js`, `chess_backend/routes/consent.js`, or the
  parent-consent mail in `chess_backend/services/mailService.js`.
* Do not add a database column and do not write a migration.
* Do not add a second download route.
* Do not delete a test, weaken an assertion, or relax a matcher.
* Do not commit, branch, or `git add`.
* Run each suite once, at the end, and never both at once.

## Done means

```bash
cd chess_backend && npm test
```

* **979 passing** plus your new tests, with `.env` moved aside. This worktree has
  no `.env`; do not create one. If the suite dies at import rather than failing a
  test, say so and stop.

```bash
cd chess_app && flutter test
```

* **1762 passing, 1 skipped**, plus your new tests.
* `flutter analyze` reports 29 issues, all `info`. Read the summary line it
  prints; do not count them with a regex.
* `dart format` on every Dart file you touched.

## The report

Write it to `REPORT-video-tutorijala.md` in the repository root.

1. Both suite counts, before and after, measured by you.
2. The route: path, body, answers, every status code.
3. Every refusal you added, and where it fires.
4. What you asserted on the **request** rather than on the screen.
5. Anything the renderer or `tutorialVideoOf` could not give you.
6. Anything this task or the brief got wrong.

**Write only what you did.** Quote nothing you have not just grepped.
