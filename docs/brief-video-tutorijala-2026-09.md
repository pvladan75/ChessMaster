# Brief — a tutorial becomes a video, batch 67: the route and the door

Written 9.9.2026 by the lead. This brief and `docs/TASK-video-tutorijala.md` are
the whole of the context for this batch.

## Where this sits

Phase 2 of `docs/PLAN-ZAVRSNICA.md` is four pieces and **three of them are
done**:

1. **A tutorial becomes a list of events** — `tutorialVideoOf` in
   `chess_app/lib/features/tutorial_studio/services/tutorial_video.dart`, gated
   by `chess_app/test/tutorial_video_test.dart`.
2. **A dwell time per beat** — `dwellSecondsFor`, in the same file: twelve
   characters a second, floor 2s, ceiling 12s.
3. **The renderer draws the teaching** — `chess_backend/videoRenderer.js` takes
   `caption`, `arrows`, `squares` and `orientation` per event and draws them,
   gated by `chess_backend/test/video_renderer.test.js` (15 tests, reading
   pixels out of a rendered frame).

Yours is the fourth: **the route and the door.** A tutorial export beside the
recording export, metered by the entitlement that already exists, and one button
where a trainer already stands.

It has been proved end to end before you were briefed: a two-part tutorial,
arrows, coloured squares, captions and a board turned round for the second part,
rendered to a 19-second MP4 with `ffmpeg` on the lead's machine. **Nothing about
the rendering is your problem.** What is missing is the way in and the way out.

## What already exists, and must be copied rather than reinvented

**`POST /recordings/:id/export-mp4`** in `chess_backend/routes/recordings.js` is
the shape. Read it before writing a line. It checks the entitlement *before*
doing any work, renders to `chess_backend/exports/`, signs a short-lived
download token bound to that one filename, and books the metering **after** the
render succeeded.

**`GET /recordings/export-download/:filename`** serves it. **Reuse that route.**
Do not add a second endpoint that serves files out of `exports/` — it is the one
place in this server that has to defend against a path escaping a directory, and
one is easier to keep right than two.

**`replay_player_screen.dart`** (around line 495) is how the app asks for an
export and what it does with the answer: a dialog with the link, opened with
`launchUrl`, because the system browser cannot send an `Authorization` header
and that is exactly why the token travels in the URL.

**`TutorialDraft.fromLesson`** turns a saved tutorial into the draft
`tutorialVideoOf` reads. It is the same reader the studio uses when it reopens a
tutorial, and it is the **only** one: do not parse a `pgn` anywhere in this
batch.

## The route

`POST /lessons/:id/export-video`, in `chess_backend/routes/lessons.js`.

**The events come from the app.** That is a rule rather than a convenience: the
server stores a step's `pgn` as opaque text and has no PGN reader, and giving it
one would be a second parser disagreeing with the app's — which this project has
already paid for once. The app holds the tree, the comments and the drawings, so
it builds the list and the server renders it.

Body:

```js
{ events: [...], seconds: 180, title: 'Slaba polja u centru',
  resolution: '720p', pieceStyle: 'classic', boardTheme: 'wood' }
```

What it must do, in this order:

1. `authenticateToken`, then `requireEntitlement(ENT.MP4_EXPORT)` — **before**
   any work, because rendering costs real CPU.
2. Resolve the tutorial with the condition this file already uses for update,
   delete and clone: `id = $1 AND (user_id = $2 OR trainer_id = $2)`. A 404 when
   it does not resolve. **A student who was sent a tutorial does not render it**
   — that is somebody else's row and somebody else's entitlement.
3. Refuse a body that cannot be a film: `events` not a non-empty array,
   `seconds` not a positive integer. Clamp `seconds` to 3600 rather than
   refusing a long one — the renderer clamps it too, and a tutorial that runs
   long is a real tutorial.
4. Render with `renderRecordingToMP4`, `audioFilePath: null` — **the video is
   silent by decision**, the sentences are on screen, and TTS is out of scope
   for the whole project. `showMoveText: false`, because the caption band is
   under the board and „Last move: Nd5" would sit between the board and the
   sentence about it.
5. Sign the download token and answer with the same `downloadUrl` shape the
   recording export answers with.
6. Book `METRIC.MP4_RENDERS` and `METRIC.MP4_RENDER_SECONDS` **after** the
   render returned, never before: a failed job costs CPU and the user is not
   charged a quota for a file they did not get.

**Do not touch `db.js`.** There is no column on `saved_lessons` for a video and
this batch does not add one; the URL is answered, not stored. If you think it
should be stored, say so in the report.

## The door

`chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`,
the sheet listing saved tutorials. It already has two icons per row — „Send to
student" and delete — and a `_busy` flag so neither can start twice. **The video
is the third icon**, and it shares that flag.

What happens when it is pressed:

1. `TutorialDraft.fromLesson(row)` → `tutorialVideoOf(draft)`.
2. **Refuse before sending anything** when `canRenderVideo` is false — an empty
   tutorial renders no frames, and `ffmpeg` given no frames fails with a message
   about a pipe rather than about a tutorial. Say so in a sentence.
3. Refuse when `fitsInOneFilm` is false, and say how long it is: one frame per
   second means an hour of film is an hour of drawing.
4. Otherwise POST, and on success show the link the way
   `replay_player_screen.dart` does.
5. Every message goes through `AppFeedback`. **Do the thing, then say it**: this
   project has twice had an action killed by the message reporting it.

The rendering takes tens of seconds. Say that it started, keep the row busy, and
do not leave a dead sheet with no explanation.

## Vocabulary

`docs/GLOSSARY-EN.md` holds. The words this batch needs:

| | |
|---|---|
| the artefact | **tutorial** — never „lesson" in a sentence a user reads |
| the file | **video**, and the action is **Export video** |
| where it lands | **Download** |
| the refusal | „This tutorial has nothing to show yet." / „This tutorial is too long to render as one video." |

The server's messages are English like the rest of it since batch 66b.

## The gate

Backend, in `chess_backend/test/`:

* the route refuses without the entitlement, and **does not render** — the
  refusal must come before any work;
* somebody else's tutorial is a 404, and the query carries both the id and the
  user;
* an empty `events` array is a 400 and nothing is written to `exports/`;
* `seconds` above 3600 is clamped, not refused;
* metering is booked **after** a successful render and not after a failed one;
* the answer carries a `downloadUrl` bound to the file that was written.

App, in `chess_app/test/`:

* the third icon exists on a saved-tutorial row and is disabled while the row is
  busy;
* a tutorial with nothing in it is refused **without a request being sent** —
  assert on the fake API, not on the screen;
* a normal tutorial sends `events` and `seconds` that match `tutorialVideoOf`
  for the same draft. **Assert on the request**: this is the one place where a
  wrong number is invisible until somebody watches a video to the end.

Do not test the drawing. That is `video_renderer.test.js`'s job and it is done.

## The rules that bite

**`npm test` runs with no `.env`, and the worktree has none.** That is the
environment CI has. Do not create one.

**Do not shell out to `ffmpeg` in a test.** The gate for the renderer does not,
and neither should this one: a test that spawns a process is a test that fails
on a machine without it. Fake the renderer where you need to.

**Do not touch** `videoRenderer.js`, `tutorial_video.dart`, `db.js`,
`routes/consent.js`, or the parent-consent mail. If the renderer is missing
something you need, that is a finding for the report, not an edit.

**Both suites must be run once, at the end, and never both at once.**
`test/opening_book_service_test.dart` loads a 20-second dataset and times out
when anything heavy runs beside it.

## How this is graded

| gate | passes when |
|---|---|
| `npm test` | **979 passing** plus your new backend tests, `.env` moved aside |
| `flutter test` | **1762**, 1 skipped, plus your new app tests |
| `flutter analyze` | 29 infos, no warnings, no errors — read the summary line |
| `english backend` | no Serbian in the files you touched |
| `dart format` | every Dart file you touched |
| `worktree` | no stray files; the report is the only untracked one |

Measure both counts yourself, before and after.

## What the report must contain

1. Both suite counts, before and after, measured by you.
2. The route's shape as you wrote it: path, body, answers, and every status code.
3. Every refusal you added, and where it fires.
4. What you asserted **on the request** rather than on the screen.
5. Anything the renderer or `tutorialVideoOf` could not give you.
6. Anything this brief got wrong.

**Write only what you did.** Reports in this series have had accurate numbers and
one invented section each. Quote nothing you have not just grepped.
