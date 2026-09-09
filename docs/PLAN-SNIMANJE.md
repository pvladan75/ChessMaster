# Rehearse & Record — the trainer's own voice on a tutorial

Written 9.9.2026, after the video export was measured under load and the two
bottlenecks turned out to be the same one wearing two coats.

**Two parts.** The first is the trainer's own voice, which takes synthesis off
the server. The second is the pipeline that draws the film — refusing a render
that cannot finish, taking the render out of the request, and the deferred lane
the owner proposed. They are one document because the first depends on the
second: a recorded tutorial is a *longer* tutorial, and the ceiling it runs into
is what part two is about.

Two items from the same list are already built and are not repeated here: the
preview (`docs/STANJE-RADA.md`, „Pregled pre renderovanja", 9.9.2026) and one
video per tutorial with a link on demand („Tutorijal pamti svoj film", the same
day).

**The phases are logical, not calendar.** The order is fixed — a phase does not
start before the one in front of it is finished — but no date is promised here
and none should be added.

## Why

Narration today is piper on the server, and it is bounded by two things that do
not get better with more work:

**The language.** Piper offers a handful of models. A trainer teaching in
Serbian, Hungarian or Greek either has no voice or has one that reads chess
notation as prose — `services/spokenMoves.js` exists because five languages
each needed their own vocabulary before „Bd5" stopped coming out as *boulevard
cinq*. Every new language is another vocabulary, hand-written, and it is still a
synthesiser reading somebody else's sentence.

**The CPU.** Synthesis happens inside the render queue, on the same machine, in
the same slot — measured: a twenty-five beat tutorial spends about a minute
there before a frame is drawn. It is also the *variable* part of a render, which
is what makes „is this tutorial too long to export" impossible to answer
honestly.

A trainer speaking into their own microphone removes both, and removes them from
the server rather than moving them.

## What is decided

| | | |
|---|---|---|
| Trainer records narration locally, app captures markers | **in** | The whole point |
| Markers taken from the recorder's audio clock | **in** | Wall clock drifts; see phase 1 |
| Local rehearsal and replay with no server | **in** | A retake must cost nothing |
| Audio uploaded at export, muxed by the existing renderer | **in** | `ffmpegArgsFor` already does this |
| Piper stays as the fallback | **in** | A trainer who will not record still needs a voice |
| Recording bound to the beat list it was made against | **in** | Signature, not a flag; see phase 5 |
| Server-side trimming of pauses (`audioTrimmer`) | out | Trimming audio invalidates the markers |
| Re-recording one beat inside a take | out | A retake is the whole take; see „not being done" |
| Video editing, waveform UI, noise reduction | out | Same |
| Recording a lesson with anybody else present | out | Unchanged since 26.8.2026 |

## What already exists, and what does not

**The renderer needs no change at all.** `ffmpegArgsFor` already takes an audio
file, adds it as a second input, encodes to AAC at 192 kbit and ends with
`-shortest` — so an AAC or Opus recording muxes in the one pass that already
happens, and the Opus-in-MP4 compatibility question answers itself because the
audio is re-encoded anyway.

**The event list already carries what is needed.** `tutorialVideoOf` emits
`timestampMs` per event, and `narrationPlan`/`retimeEvents` exist precisely to
*overwrite* those numbers once real durations are known. Rehearse & Record
supplies the real numbers from the start, so all four narration stages —
`speakBeats`, `narrationPlan`, `buildNarrationTrack`, `retimeEvents` — are
skipped rather than replaced. The concat of clips and silences, the per-beat
breath, and the 60-second runaway-clip guard all disappear with them.

**What does not exist is a recorder.** The app has `audioplayers` (playback
only) and no recording package. The one place that records today is the room,
through **Agora** (`agora_service.dart:446`, `startAudioRecording`), which needs
a live RTC session and is therefore no use in the studio. This is the single
largest unknown in the plan and it is phase 0.

**The upload pattern exists.** `local_recording_service.dart` already saves a
take locally, keeps it in `SharedPreferences` and uploads it multipart; the
server side is `routes/recordings.js` with multer into `uploads/`, capped at
100 MB.

## Phase 0 — the spike, before anything is designed around it

One throwaway build, on **both** targets, answering one question: can the
recorder tell us where it is in its own file?

* A recorder package that works on Android **and** Windows — `record` is the
  obvious candidate and its Windows support is exactly what must be proved
  rather than assumed.
* It must expose the recorded **position**, not just „started at". If it does
  not, the position is derived from the file itself (bytes written ÷ byte rate,
  or a container probe), and if neither is possible the package is rejected.
* Measure the gap between „start" returning and the first sample landing. On
  Android a microphone warm-up of a few hundred milliseconds is ordinary, and
  it is the whole reason for the rule below.

The spike is thrown away. What survives is a number and a yes/no.

## Phase 1 — the client records, and the markers come from the audio

The trainer opens a tutorial in the studio, presses **Rehearse**, and talks. Each
press of „Next" (spacebar on desktop) advances one beat and writes a marker.

**The rule this phase exists for: a marker is the recorder's position, never
`DateTime.now()`.** If recording starts 200 ms after the button, or the OS
suspends the microphone for a moment, wall-clock markers drift — and they drift
*progressively*, so the film is fine at the start and wrong at the end, which is
the half nobody re-checks. Every marker is read from the recorder's own clock,
and the beat list is then `{ eventIndex, timestampMs }` against the audio's own
zero.

Pausing is a first-class action and it **pauses the marker clock too**. This is
deliberately not the room's arrangement, where the microphone ran through the
pauses and `services/audioTrimmer.js` cut them out on the server: cutting audio
after the fact moves every marker after the cut, which is the same drift by
another route. A tutorial's recording is uploaded needing no surgery.

## Phase 2 — rehearsal, with no server in it

The take is played back locally against the Flutter board: the audio plays, the
markers fire, the pieces move, the arrows appear. The trainer watches their own
lesson and decides.

**A retake costs nothing and must be visibly free** — no upload, no queue, no
CPU on the server, no quota. This is what makes the whole feature worth
building: the expensive path (render) is entered once, by choice, after the
trainer has already seen that the timing is right.

The take lives in the app's own storage until it is exported, the way
`LocalRecordingService` already keeps a room recording.

## Phase 3 — the upload, and what the server checks

`POST /lessons/:id/narration`, multipart, alongside the marker list.

* **multer**, into `uploads/`, with a size cap. 100 MB is the existing one; a
  20-minute AAC is far under it.
* **`ffprobe` decides the duration**, not the client. `-shortest` means a
  duration that is too long ends the film early and one that is too short leaves
  a tail of nothing; both look like the renderer is broken. The client's own
  number is compared with the probe's and a disagreement is refused with a
  sentence, not silently corrected.
* **The markers are validated against that duration**: monotonic, first at or
  after zero, last before the end, one per event of the film. A marker list that
  does not describe this tutorial is refused before anything is stored.
* **Bound to the tutorial**: `saved_lessons` gains `narration_filename`,
  `narration_seconds`, `narration_recorded_at` and the beat signature from phase
  5 — the same shape as the `video_filename` columns added on 9.9.2026, and for
  the same reason: a file the row does not name is a file nobody can reach.
* **Deleted with the tutorial.** `uploads/` is never touched by cleanup code
  because it holds the one thing this project cannot reproduce, and a trainer's
  recorded voice belongs to that class — so deletion has to be *explicit*, on
  the tutorial's own delete path and on „record again". An export can age out on
  a timer because it can be re-rendered; a performance cannot.

## Phase 4 — the export, which is the part that barely changes

`POST /lessons/:id/export-video` gains one branch. When the tutorial has a
narration and the trainer asked for it:

1. the marker list replaces the app's computed `timestampMs` on the events —
   the same substitution `retimeEvents` performs today, from a different source;
2. `spokenMs` for each beat is the gap to the next marker, so the caption is
   revealed at the speed it is actually being spoken (without it the existing
   fallback reveals over 75 % of the gap, which is close but not the voice);
3. `audioFilePath` is the uploaded file, and `renderRecordingToMP4` muxes it
   exactly as it muxes a synthesised track today.

Nothing in `videoRenderer.js` changes. The frame loop, the caption band, the
4 fps rate for a captioned film, the abort, the progress reporting — all of it
already works on „events with timestamps plus an audio file", which is what a
recorded tutorial is.

The clamps that exist for a *guessed* pace stop applying: `dwellSecondsFor`'s
2-to-12-second window is a reading-speed estimate, and a trainer who dwells
forty seconds on one position gets forty seconds.

## Phase 5 — the recording is bound to the lesson it was made against

Edit a sentence, add a part, reorder two — and the markers no longer name the
beats they were recorded against. Silently, and the film is wrong somewhere in
the middle.

This repository already has the pattern and the reasoning: `TutorialSection`
invalidates its cached `pgn` by comparing `treeSignature` against the tree
itself, chosen over a `bool edited` because **a flag is the version of this that
one mutator forgets to set**. The narration stores the signature of the beat
list it was recorded against; when the tutorial's own signature no longer
matches, the studio says so and offers two doors — record again, or export
without the voice. It never exports a recording against a beat list that has
moved.

Two smaller rules that follow. A signature over the **beats**, not over the
whole draft: renaming the tutorial must not invalidate an hour of narration. And
the mismatch is shown in the studio, where it can be fixed, rather than at
export, where it is a refusal.

## Phase 6 — piper stays

Two producers, one event list, one renderer. The narrated-by-piper path is not
removed, because:

* a trainer who will not record still needs a voice;
* a tutorial edited after recording needs *something* until it is re-recorded;
* the five vocabularies in `spokenMoves.js` are already written and tested, and
  they cost nothing while they sit there.

The export sheet asks one question with three answers — the trainer's own
recording (where one exists and matches), a synthesised voice (where the server
has one), or silence.

## The rules this is built under

**This is the first thing since 26.8.2026 to put a human voice back on the
server, and it is inside the existing rule rather than a reopening of it.**
`services/recordingConsent.js` states the rule in as many words: a trainer alone
in a room records teaching material, nobody else is in the recording, so nobody
else has to agree to it. What must not be assumed is the *enforcement*: today it
is keyed to a room roster, and the studio has no room. The check is re-expressed
for this path, keeping both of its sharp edges — **eighteen, not
`AGE_OF_CONSENT`**, and **an unknown age refuses**, because „we never asked"
must not read as „yes" for the one artefact that cannot be taken back.

**A recording is not reproducible.** Every other file this server writes can be
made again from what is in the database. This one cannot, which is why it lives
under `uploads/` rules — never in git, never swept by a timer — and why
deleting it has to be somebody's explicit act rather than a side effect.

## What is deliberately not being done

**Re-recording a single beat inside a take.** It sounds cheap and it is not: two
takes spliced together need a cut, a crossfade and a marker rebase, and the
result is an editor. A retake is the whole take, and phase 2 is what makes that
acceptable — the trainer already knows it is wrong before they have spent
anything.

**Server-side pause trimming.** `audioTrimmer` exists and works for the room's
recordings; using it here would cut the audio under the markers. Pausing the
marker clock at the source is the same feature without the drift.

**A waveform, noise reduction, levels.** A phone microphone in a quiet room is
enough for a chess lesson, and every one of these is a week that buys nothing a
retake does not.

**Recording anyone but the trainer.** Unchanged, and not up for discussion in
this document.

## Open decisions for the owner

1. **Does a recorded narration make the tutorial's video re-renderable by a
   student?** Today only the owner and the trainer can export. A recorded voice
   makes a tutorial a finished product; whether a student may render their own
   copy of it is a product decision, not a technical one.
2. **What happens to the recording when the tutorial is shared or cloned?**
   `POST /lessons/:id/clone` mints fresh step ids on purpose. The voice should
   probably follow the clone — but a copy of a file whose only copy is on this
   server doubles the thing that cannot be reproduced.
3. **A cap on narration length**, if any. The queue's ceilings are about
   drawing, and a 40-minute recording is a 10-minute render — which is over the
   300 s connection budget and therefore waits on the deferred lane.

## What this does not solve

It removes synthesis from the render queue, which makes render time
deterministic and a pre-flight refusal honest. It does **not** shorten the
drawing: a 20-minute recorded tutorial is still about 5 minutes of frames at the
measured rate, over the 300 s that nginx allows a proxied request. If anything
it makes long films more likely, because a trainer talking naturally is slower
than twelve characters a second.

So part one assumes, and does not replace, the deferred render lane and the
chunking that goes with it — which is what part two is.

---

# Part two — the pipeline that draws it

Numbered as they were asked, and only the two that are left: **4** refusing a
render that cannot finish, and **5** taking the render out of the request. The
owner's hybrid is what they become when they are built together.

## 4 — refuse before drawing, not after

**Better than the abort, and for the trainer rather than for the server.** The
abort added on 9.9.2026 stops work nobody is waiting for; this stops work that
was never going to arrive. A sentence beats a progress bar that dies at 300 s.

The arithmetic is available before anything is drawn. The app already sends
`seconds`; the frame count is `seconds × 4` for a captioned film and `seconds ×
1` for a silent one, and the render time is that divided by a drawing rate.

**The rate is a configured number, not a constant in the code, and it is
measured on the machine that will do the drawing.** On the development machine
the same 120-second film was drawn eight times at 15.4, 15.9, 18.7, 20.2, 23.8,
24.3, 27.9 and 30.2 seconds — **a factor of two on identical input** — so the
figure to configure is the slow end, with a margin, and the droplet's own number
is unknown until somebody measures it there. A threshold derived from one sample
would refuse films that would have rendered perfectly well.

Three rules for the refusal:

* **The budget is what is left of the connection**, not the whole of it: the
  films already queued in front of this one spend the same 300 seconds. The
  check reads the queue's depth, and the answer changes with it.
* **It says what to do.** "This tutorial is 36 minutes long; the server can
  render about N minutes in one go. Split it into two tutorials, or export it
  without narration." A refusal with no door is a bug report from the user's
  side.
* **It is temporary by design.** Once part 5 exists, "too long for a request" is
  not a refusal at all — it is a routing decision, and the same arithmetic picks
  the lane instead of the error.

## 5 — the render leaves the request

Today the render happens inside the POST, which is why there is a ceiling at
all. `services/renderProgress.js` says why it was built that way, and it was
right at the time: *"The alternative was returning 202 with an id and inventing
a job model; this is a progress bar, not an infrastructure."* Item 4 and the
hybrid are the pressure that changes that answer.

**Most of the pieces are already in place**, and the two that landed on 9.9.2026
are exactly the missing ones:

* the client already names its own job (`jobId`) and polls a progress route;
* a finished film already has a home — `saved_lessons.video_filename` — and a
  link is already minted on demand by `GET /lessons/:id/video`. That is why
  "one video per tutorial" was built before this: **an asynchronous render needs
  somewhere to put its result**, and until that column existed there was
  nowhere.

What changes:

1. `POST /lessons/:id/export-video` answers **202 with the job id** as soon as
   the request is accepted, and the drawing happens behind it.
2. The job becomes a **row**, not a map entry. `renderProgress` is in memory
   with a five-minute TTL and dies with the process — correct for a bar watched
   inside one request, useless for a film that outlives it. The result is
   already durable; the *state* has to be too.
3. The app polls what it already polls, and when the job is done it fetches the
   link it already knows how to fetch. The "Video ready!" dialog stops being
   tied to a request that is still open.
4. **The abort's trigger moves.** The disconnect abort must not fire on this
   path: with a 202 the socket closes immediately, and "the client is gone"
   would kill every render at birth. It becomes an explicit cancel — `DELETE
   /lessons/export-video/:jobId` — and everything under it (`renderAbort.js`,
   the frame-loop check, the piper kill, the partial cleanup, the slot release)
   stays exactly as it is. Only the thing that fires the signal changes.
5. **Being told it is ready.** `services/notifications.js` already exists and
   already reaches the app, which is the whole of the "you will get it later"
   half.

## The hybrid — the owner's proposal, and the part that makes it work

> "kada je opterećenost servera veća, onda se korisniku kaže da će renderovanje
> krenuti kasnije (u periodu manje opterećenosti) i da će svoj video dobiti
> kasnije (možda preko noći)… ne bih dozvolio da jedan veliki render koči
> nekoliko manjih duže vreme."

Both halves are right, and they are **two separate mechanisms** that are easy to
confuse:

**Deferring** is about *when* — a long film is accepted, queued for a quiet
period, and its trainer is told. It needs part 5 (a job that outlives a request)
and, conceptually, nothing else.

**Not blocking small films** is about *order*, and deferring does not solve it.
Today's queue is strict FIFO with one slot, so a 36-minute film blocks three
2-minute ones for nine minutes even if everything else in this document is
built.

### Chunking, and why it is the real answer to blocking

> "ako veliki tutorijal ima mnogo delova, može li se renderovati deo po deo, pa
> to posle sklopiti u jedan video?"

Yes — and the prize is not parallelism, it is **preemption**. If a 40-part film
is twelve chunks, the machine is free between chunks, so somebody else's short
film waits about thirty seconds instead of nine minutes. That is the
requirement, met without throwing away frames already drawn.

It fits the code: a tutorial is already parts, splitting the event list at part
boundaries is a pure function on the client's side of the line, and ffmpeg's
concat demuxer is already used in this repository — `services/narrationTrack.js`
joins the narration clips with it.

Four rules it needs:

* **Rebase the timestamps per chunk.** Events carry absolute times; a chunk
  starts at zero.
* **Split only at part boundaries**, never inside a beat. A part boundary is an
  `init` event, which is exactly where the film already reloads the board.
* **Decide what a failed chunk means** before building it: retry that chunk and
  keep the rest, or fail the film. Silence here is how half a film gets
  published.
* **With a recorded narration, do not cut the audio.** Draw the chunks silently,
  concatenate the video, and mux the trainer's one continuous take over the
  finished picture in a single pass — `ffmpegArgsFor` already does exactly that.
  Cutting a recording into twelve pieces to match twelve chunks rebuilds the
  drift problem from part one on purpose.

### Fairness, which today does not exist

> "šta ako jedan korisnik pošalje više tutorijala na renderovanje?"

Today: `RENDER_CONCURRENCY` is 1 and `RENDER_QUEUE_MAX` is 2, so **one trainer
pressing Export three times fills the queue and everybody else is refused with a
429.** FIFO has no idea who is asking. This is a live problem, not a future one.

Two changes, both small and both inside `renderQueue.js`:

* **Round-robin across accounts** instead of first-come-first-served: the queue
  takes the next job from the account that has waited longest, not the next job
  in line. Twelve chunks from one big tutorial then interleave with other
  people's films rather than running ahead of them.
* **A cap per account** — one drawing, one waiting. A trainer who queues five
  tutorials slows only themselves, and the fifth goes to the deferred lane
  instead of taking somebody else's turn.

### What the trainer sees

Three states, and the app already draws two of them:

* **rendering now** — the bar, as today;
* **waiting** — "two films in front of yours", re-announced whenever the queue
  moves, because a position that never changes is indistinguishable from a queue
  that has stopped (already built);
* **deferred** — "this one is long, so it will be rendered tonight and you will
  be told when it is ready". **No invented estimate**: null is "no estimate",
  never zero, which is the rule the progress bar already follows.

## Order, and what depends on what

1. **4** is the cheap interim and can land alone. It stops the worst outcome —
   a trainer waiting five minutes for nothing — with arithmetic that already
   exists.
2. **5** turns that refusal into a routing decision, and needs the job row. It
   depends on "one video per tutorial", which is done.
3. **Chunking** and **fairness** come with the deferred lane, because that is
   where twelve jobs from one film stop being a problem and start being the
   mechanism.
4. **Part one** — the recording — can be built at any point after phase 0, and
   is independent of all of the above. It makes them more necessary, not less.
