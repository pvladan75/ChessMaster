# Task — the narrated tutorial video, batch 68

**This file plus `docs/brief-video-glas-2026-09.md` are the only context you
get.** Read the brief first, then come back here.

If you cannot find a file this task names, **stop and say so.**

Branch: `batch/video-glas`. **Do not commit.**

The narration pipeline is built, tested and proved end to end. Your work is the
way a trainer asks for it: two fields on a route, one voice list, and a switch.

## What to do

### 1. `chess_backend/routes/lessons.js`

**a.** `POST /:id/export-video` accepts `narrate` (boolean) and `voice` (string).

* Absent or false → **the current behaviour, unchanged**, and
  `services/tutorialNarration` is not called at all.
* True → `const narrated = await narrateFilm({ events, voice, exportsDir, filename })`
  before rendering, then render with `narrated.events`, `narrated.seconds` and
  `audioFilePath: narrated.audioPath`.
* Book `METRIC.MP4_RENDER_SECONDS` with the duration actually rendered.
* Delete `narrated.audioPath` after the render returns, success or failure. The
  mp4 stays.
* Everything else about the route — the entitlement first, the ownership
  condition, the 400s, the clamp, the metering last, the download token —
  stays exactly as it is.

**b.** `GET /:id`-safe new route `GET /lessons/tts/voices`, authenticated,
answering `{ available, voices }` from `tts.narrationAvailable()` and
`tts.voices()`. **Mount it before `GET /:id`** or `:id` swallows `tts`.

### 2. `chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`

* Ask the voices route once when the saved-tutorials sheet opens.
* `available: false` → nothing new on screen, and the export request carries no
  `narrate`.
* `available: true` → before the export starts, offer a switch („Narrate this
  video") and a voice picker; send `narrate` and `voice` with the request.
* Remember the choice in the app's settings, the way this app already remembers
  preferences.
* Say that a narrated export takes longer.
* Messages through `AppFeedback`.

### 3. The tests

Backend, faking `services/tts` and `services/tutorialNarration` — **never
spawning PowerShell or ffmpeg**:

1. `narrate` absent/false → the narration door is never opened, and the render
   gets the events the request carried;
2. `narrate: true` → the render gets `narrated.events`, `narrated.seconds` and
   `narrated.audioPath`;
3. metering books the rendered duration, not the requested one;
4. the narration wav is deleted after the render and the mp4 is not;
5. narration that returns `audioPath: null` still answers 200 with a video;
6. `GET /lessons/tts/voices` answers `{available:false, voices:[]}` when the
   provider is off, and resolves before `GET /lessons/:id`.

App:

7. `available: false` → no switch on screen, and no `narrate` in the request;
8. `available: true` → the switch and the chosen voice are in the **request**;
9. the chosen voice survives reopening the sheet.

## Rules

* Do not touch `chess_backend/services/tts/`,
  `chess_backend/services/narrationPlan.js`,
  `chess_backend/services/narrationTrack.js`,
  `chess_backend/services/tutorialNarration.js`,
  `chess_backend/test/narration_plan.test.js`, `chess_backend/videoRenderer.js`,
  `chess_backend/db.js`, `chess_backend/routes/consent.js`, or the
  parent-consent mail in `chess_backend/services/mailService.js`.
* Do not add a database column or write a migration.
* Do not delete a test, weaken an assertion, or relax a matcher.
* Do not commit, branch, or `git add`.

## Done means

```bash
cd chess_backend && npm test
```

* **997 passing** plus your new tests, `.env` moved aside. This worktree has no
  `.env`; do not create one.

```bash
cd chess_app && flutter test
```

* **1766 passing, 1 skipped**, plus your new tests.
* `flutter analyze` reports 29 issues, all `info`. Read its summary line.
* `dart format` on every Dart file you touched.

## The report

Write it to `REPORT-video-glas.md` in the repository root.

1. Both suite counts, before and after, measured by you.
2. The route's new fields and every status code it can answer with.
3. What you faked, and how you proved the real call still carries what you
   assert it carries.
4. What you asserted on the request rather than on the screen.
5. Anything the narration services could not give you.
6. Anything this task or the brief got wrong.

**Write only what you did.** Quote nothing you have not just grepped.
