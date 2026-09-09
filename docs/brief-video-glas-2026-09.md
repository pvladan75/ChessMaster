# Brief — the narrated tutorial video, batch 68: the switch and the voice list

Written 9.9.2026 by the lead. This brief and `docs/TASK-video-glas.md` are the
whole of the context for this batch.

## Where this sits

A tutorial already exports as a silent 30 fps video (`POST
/lessons/:id/export-video`, phase 2 of `docs/PLAN-ZAVRSNICA.md`). The narration
pipeline behind it is **built and proved end to end** — three sentences spoken in
1.2 s, a 22-second film whose audio track is 22.0005 s long, beats starting on
the seconds the voice does. What is missing is the way a trainer asks for it.

**Everything is spoken in English**, whatever language the trainer wrote in. That
is the owner's rule of 9.9.2026 and it is not a limitation to work around: there
is no language field, no detection, and no second voice to choose between.

## What exists, and must not be rewritten

| file | what it does |
|---|---|
| `services/tts/index.js` | `speak`, `speakBeats`, `voices`, `narrationAvailable` — the cache lives here |
| `services/tts/windows.js` | the first provider: Windows' own `System.Speech`, no key, no network |
| `services/tts/wav.js` | how long a wav is, read from its own header |
| `services/narrationPlan.js` | **the pure core**: per-beat clip lengths → frame timestamps *and* audio segments |
| `services/narrationTrack.js` | those segments → one wav, by concatenation |
| `services/tutorialNarration.js` | `narrateFilm({ events, voice, exportsDir, filename })` — the one door |

`narrateFilm` returns `{ events, audioPath, seconds, spokenBeats }` and is the
only thing this batch calls. When narration is unavailable, refused, or every
beat comes back silent it returns the events **untouched** with `audioPath:
null`, so the caller renders exactly the silent film it would have rendered
anyway. **There is no half-narrated state** — either the timings came from the
voice or they came from the app's reading-speed guess — and this batch must not
invent one.

`chess_backend/test/narration_plan.test.js` is that core's gate, ten tests and
five mutations. Do not edit it. If you think it is wrong, say so in the report.

## The route

`POST /lessons/:id/export-video` gains two optional fields:

```js
{ ..., narrate: true, voice: 'Microsoft Zira Desktop' }
```

* When `narrate` is absent or false, **nothing changes** — the film is the silent
  one that already works, and its tests must stay green untouched.
* When it is true, call `narrateFilm` *before* rendering, and render with what it
  returns: its `events`, its `seconds`, its `audioPath` as `audioFilePath`.
* **Meter the film that was made, not the one that was asked for.** A narrated
  film is longer than the app's estimate, because every beat now lasts as long as
  its sentence takes to say. `METRIC.MP4_RENDER_SECONDS` takes the duration that
  was actually rendered.
* **Delete the narration wav when the render is done.** It is one render's
  scratch, not an artefact: `exports/` is swept on a retention timer, and a file
  that lives for days when it was needed for seconds is a file somebody has to
  reason about later. The mp4 stays, obviously.
* A tutorial that narrates is still refused for everything the silent one is
  refused for, in the same order, and the entitlement is still checked before any
  work.

## The voice list

Two things the app needs before it draws a switch, and one route can answer both:

`GET /lessons/tts/voices` (authenticated) →

```js
{ available: true, voices: [{ id: '…', name: '…', language: 'en-US' }] }
```

`available` is `tts.narrationAvailable()`, and it is false on any machine whose
provider is not configured — which is **the droplet**, because the first provider
is Windows-only. `voices` is `tts.voices()`, already filtered to English.

**A switch the server cannot honour must not be drawn.** That is the whole point
of asking: a trainer who turns narration on and waits two minutes for a refusal
has been lied to by the interface. When `available` is false the app offers
nothing and exports silently, exactly as it does today.

Mount it **above** `GET /lessons/:id`, or `:id` swallows `tts`. This file has
been bitten by route order before; `test/repertoire_route_order.test.js` is what
that cost last time.

## The door

`chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`, the
same sheet that exports the silent film today.

1. Ask the server once, when the sheet opens, whether narration is available.
2. If it is, the export offers a choice before it starts — a switch („Narrate
   this video") and, when it is on, the voice list. If it is not, the export runs
   exactly as it does now, with nothing new on screen.
3. Remember the last choice in the app's own settings, per this app's existing
   preference plumbing. A trainer who narrates one tutorial will narrate the next.
4. Say that it takes longer. Synthesis is seconds, but the film is longer than
   the silent one, so the render is too.
5. Every message through `AppFeedback`. Do the thing, then say it.

## Vocabulary

| | |
|---|---|
| the switch | **Narrate this video** |
| the picker | **Voice** |
| unavailable | nothing on screen at all — never a disabled switch with an explanation |
| while it runs | **Exporting video…** (unchanged) |

## The gate

Backend:

1. `narrate: false` (and absent) renders exactly what it renders today: same
   events, no audio, and `narrateFilm` is never called;
2. `narrate: true` renders with the events and duration `narrateFilm` returned,
   and passes its `audioPath` as `audioFilePath`;
3. metering books the **rendered** duration, not the requested one;
4. the narration wav is gone after a successful render, and the mp4 is not;
5. a narration that fails or comes back silent still produces the silent film —
   a 200 with a video, never a 500;
6. `GET /lessons/tts/voices` answers `available: false` with an empty list when
   the provider is not configured, and resolves before `GET /lessons/:id`.

App:

7. when the server says `available: false`, the sheet shows no switch and the
   request carries no `narrate`;
8. when it says true, the switch and the chosen voice reach the **request** —
   assert on the request, not on the screen;
9. the chosen voice survives closing and reopening the sheet.

**Fake `services/tts` and `services/tutorialNarration` in the backend tests.**
Do not spawn PowerShell and do not spawn ffmpeg: a test that shells out is a test
that fails on a machine without the thing it shells out to, and CI is Linux.

## The rules that bite

* Do not touch the six files in the table above, `videoRenderer.js`, `db.js`,
  `routes/consent.js`, or the parent-consent mail.
* Do not add a database column. The chosen voice lives in the app's settings and
  travels with the request.
* Do not delete a test, weaken an assertion, or relax a matcher.
* `npm test` runs with no `.env`, and the worktree has none. Do not create one.
* Run each suite once, at the end, never both at once.

## How this is graded

| gate | passes when |
|---|---|
| `npm test` | **997 passing** plus your new tests, `.env` moved aside |
| `flutter test` | **1766**, 1 skipped, plus your new tests |
| `flutter analyze` | 29 infos, no warnings — read the summary line |
| `english backend` | no Serbian in the files you touched |
| `dart format` | every Dart file you touched |
| `worktree` | no stray files; the report is the only untracked one |

## What the report must contain

1. Both suite counts, before and after, measured by you.
2. The route's new fields and every status code it can answer with.
3. What you faked in the tests, and how you proved the real thing is still
   called with what you assert it is called with.
4. What you asserted on the **request** rather than on the screen.
5. Anything the narration services could not give you.
6. Anything this brief got wrong.

**Write only what you did.** Quote nothing you have not just grepped.
