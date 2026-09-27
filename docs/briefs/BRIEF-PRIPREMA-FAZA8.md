# Brief — Preparation, phase 8: the doors of „Make a tutorial"

`docs/PLAN-PRIPREMA.md` — read §3 (R1–R8), §4's **D2**, **D5–D7**, **D18**
and **T4–T5**, and phase 8 under §6. The core and the server are built and
graded by the lead; this is the part a trainer reaches: „Make a tutorial" on
a recording's Library card and in its player, the flow behind both, and the
recording's voice offered in the export of the tutorial it became.

**Work only in the worktree you are given**, on a branch made from
`priprema-faza-8` (run `git merge --ff-only priprema-faza-8` first if your
worktree started from `master`, and check `git log --oneline -3` shows
`feat(preparation): phase 8, the core` and `…, the voice`). App commands run
from its `chess_app/`; run `flutter pub get` there before anything else, and
before any `dart format` (without the package config it formats in the
newest style and reformats files you never touched). Touch nothing in
`D:\Projekti\chess_master` itself, commit on your branch only, push nothing.
**Never start the server.** `flutter test` rewrites the seven generated
plugin registrants under `linux/`, `macos/` and `windows/` with other line
endings; leave them, the lead restores them.

Baseline measured on `priprema-faza-8` by the lead with nothing else
running: see „The pass condition". `flutter analyze`: the **22** known infos,
all `curly_braces_in_flow_control_structures`.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately. **And when a test's own timing or helper is
what stands in your way, say that — do not change what a screen does for a
person in order to fit it.**

## What is already here, and is the lead's

- `docs/gates/recording_tutorial_doors_test.dart` — **the gate**. Copy it to
  `chess_app/test/recording_tutorial_doors_test.dart` and do not edit the copy
  except to report a fault. **Its head comment is the frozen contract**: the
  flow's name and parameters, the requests in order, every key and every
  sentence it reads. Proved before you got it (see the lead's note at the
  end of this brief).
- **The core** — `lib/features/tutorial_studio/services/recording_tutorial.dart`:
  `recordingTutorialOf({events, durationMs, sentences, title, language})`
  returns a `RecordingTutorial` (`draft` — already read back through the one
  reader — `markersMs`, `signature`, `beats`) or throws
  `RecordingTutorialRefused` whose `reason` is a sentence for the trainer.
  Do not change it; its gate is `test/recording_to_tutorial_test.dart`.
  **The flow composes nothing of its own**: the tutorial saved is
  `draft.positionList`, the voice's body is `markersMs`, `beats`,
  `signature`, all from this one call.
- `filmPositionsSignatureOf(stops)` in `tutorial_video.dart` — what a copied
  voice is held to (D18). Read the comment above it.
- The server, built:
  - `GET /recordings/:id` — the recording: `title`, `source`
    (`preparation` | `room`), `host_id`, `duration_ms`, `timeline_json`
    (`SessionRecording.fromJson` reads it).
  - `GET /recordings/:id/transcript` — `{ available, languages, transcript }`,
    `transcript` null or `RecordingTranscript` (`RecordingTranscriptApi`
    already reads it).
  - `POST /lessons/save` — `LessonApiService.saveTutorial` (with
    `language: LanguageWrite.of(transcript?.language)`); 201 with the row,
    `position_list` carrying the step ids the server minted.
  - `POST /lessons/:id/narration/from-recording`
    `{ recordingId, markersMs, beats, signature }` → 201
    `{ narration: { ms, beats, follows: 'positions', recordedAt } }`, or
    `{ error }` with 400/403/404/409/500 — read
    `chess_backend/routes/lessons.js`, `attachRecordingVoice`.
  - `GET /lessons/:id/narration` now also answers `follows` (`'positions'`
    for a copied voice, null otherwise) and `signature`.
  - `GET /library/positions` — a recording row now carries
    `fromPreparation` (true only for a lesson recorded in Preparation).

## The pass condition

```
flutter test test/recording_tutorial_doors_test.dart
flutter test test/recording_to_tutorial_test.dart test/library_card_doors_test.dart test/tutorial_video_recording_test.dart test/tutorial_video_export_test.dart test/replay_transcript_test.dart test/tutorial_editor_door_test.dart
```

all green, **and** the full app suite at the baseline **plus the gate's 16
plus yours** (say how many, by file), 1 skipped, **and** `flutter analyze`
with the same 22 infos and nothing new, no `// ignore` added. Run
`dart format` on every Dart file you touch. No existing test is deleted,
skipped or weakened; one rewritten must be rewritten openly, with a comment
saying which rule superseded what. **Expect one kind of rewrite**: a test of
the export that asserts the exact list of requests for a tutorial with *no*
take on the device will now also see `GET /lessons/<id>/narration` — that is
this phase's new question, not a regression. List every such test.

## What is built

1. **The flow** — `lib/features/tutorial_studio/services/recording_tutorial_flow.dart`,
   `makeTutorialFromRecording(context, session:, recordingId:, client:)`,
   every request through `client`:
   - the recording, then its transcript;
   - a recording whose `source` is not `preparation` is refused with the
     gate's sentence, before anything is written;
   - no transcript: the dialog (its text contains „no transcript"; say
     that the tutorial will have its moves and your voice but no words),
     `recording-tutorial-without-words` / `recording-tutorial-cancel`;
   - the core, then `saveTutorial`, then the voice, then the studio through
     `openTutorialEditor` — opened on the row the save answered (id, title,
     language, `position_list` **with the server's step ids**; a row
     opened without them would make the studio's next save mint new ones);
   - a progress dialog that cannot be dismissed while it runs;
   - **the guard against a second start is set before the first `await`**,
     keyed by the recording's id (the double „Record" of phase 3, the double
     „Start" of 22.9: a guard that waits for the thing to exist is open for as
     long as the thing takes to arrive), and released however the flow ends;
   - **do the thing, then say it**: a refused voice leaves the tutorial made,
     so the studio opens and the message says it was made without the voice,
     with the server's sentence. Every message through `AppFeedback`.
2. **The Library's door** — `LibraryEntry.fromPreparation` (read from the
   row, false when absent); on a recording card with it, an `IconButton`
   with the tooltip „Make a tutorial" beside „Play". `LibraryScreen` takes
   an optional `http.Client? client` (a real one when null) and hands it to
   the flow. The shelf reloads after, so the new tutorial is on it.
3. **The player's door** — `transcript-make-tutorial`, a button reading
   „Make a tutorial", in the transcript panel under its list (so it exists
   exactly where the panel does, beside the board, in the phone's sheet and
   in the sideways column). It uses the player's own `http.Client`. Measure
   it at 360 × 640 upright in the sheet and at 900 × 700: the words must not
   be clipped (`didExceedMaxLines` where you give `maxLines`), and the list
   above it keeps its room.
4. **The export** — `tutorial_video_export.dart`:
   - when this device holds **no** take for the tutorial, ask the server
     (`GET /lessons/<id>/narration`, one new `LessonApiService` method that
     returns the whole answer, not only the take id);
   - a voice with `follows: 'positions'` is judged by **its beats and its
     signature against `filmPositionsSignatureOf(filmBeatsOf(draft))`** —
     never against `filmSignatureOf`, which would refuse it for a corrected
     spelling (D18);
   - usable: offered as `export-voice-recording` like a take, its length
     from `ms`, with a line containing „From the recording"; chosen, it is
     sent as `useRecording: true`, the positions signature, **no take id and
     no upload**;
   - unusable: not offered, and one sentence says why — the gate reads
     „Your recording was laid over <n> beats, and the tutorial has <m> now."
     and, for the same count, a sentence containing „since it was made from
     your recording". End both with what the trainer can do (export without
     the voice, or make the tutorial again);
   - a take on this device wins, exactly as today; a server answer with any
     other `follows` offers nothing new.
   `takeMismatchOf` stays the one judge of a device take. If you add a judge
   for the copied voice, put it beside it in `narration_take.dart`, one
   function, with its own unit cases.

## Rules that are not in the gate, and are graded

- **No `Tooltip` inside another `Tooltip`, no Material `Slider`** — the
  Windows screen-reader crash (`CLAUDE.md`, 22.9 and 26.9.2026). An
  `IconButton`'s own `tooltip` is fine on its own.
- Text that must be read is not clipped.
- A seam the gate cannot see is a false one: every request of the flow goes
  through the `client` it was given, including the save and the studio's
  own `LessonApiService` (pass one built on that client to
  `openTutorialEditor`).
- No change to the core, the server, or `recordingTutorialOf`'s rules. If
  you believe one is wrong, say so in the report.

## Cases you add

At least these, each watched red on the wrong code before green:

1. `LibraryEntry.fromJson`: `fromPreparation` true, false, and absent
   (absent is false).
2. The copied voice's judge, unit cases: the same positions with other
   words is usable; one position moved is not; one beat more is not.
3. The player's door at 360 × 640 upright, in the sheet: the button is on
   screen whole and its words are not clipped.
4. The flow's guard is released after a refusal: a room recording refused,
   then the same id started again, sends its requests again.

## What is not built

- Translation (phase 9), the manual and the glossary (phase 10).
- No change to how a take is recorded over a tutorial, or to the studio's
  narration banner.
- No door from a recording straight into a homework (D7).

## The report

1. **What the brief or the gate got wrong**, first, with the case's name and
   what you measured. If nothing: say so.
2. The pass condition's commands, their last lines, as run by you — the
   gate, the neighbours, the full app suite, `flutter analyze`'s summary.
3. Cases you added, by file and name, and for each the wrong code you
   watched it fail on.
4. Every existing test you rewrote, with the rule that superseded it.
5. Anything you saw that is outside this phase — reported, not fixed.

## The lead's note on the gate

Proved on `priprema-faza-8` on 27.9.2026, where the full app suite is
**4867 passed, 1 skipped** (measured with nothing else running; 4828 on
`master` + 37 cases of the core + 2 of the reader).

- Copied into `test/` as it is, it fails to compile on exactly three names
  and nothing else: the file `recording_tutorial_flow.dart`,
  `makeTutorialFromRecording`, and `LibraryScreen`'s `client`.
- With an inert flow (returns null, sends nothing) and a `client` parameter
  that nothing reads, **14 of 16 are red, each at the missing behaviour**:
  the flow cases at their empty request list or their absent sentence, the
  Library's at the absent button, the player's at the absent key, the
  export's at the absent option or sentence. The two green are absence
  cases, green by nature on code that does nothing: „a student watching it
  has no such door" and „a take recorded over the tutorial elsewhere is not
  offered from the server". Guard them with your own mutations.
- **None of it has been watched going green.** The flow cases compare the
  saved `positionList` with the core's after removing the `[Date "…"]`
  header the exporter stamps; if that comparison is what fails you, say so
  rather than changing how the list is built.

Pass condition, then: **4867 + 16 = 4883 passed, 1 skipped, plus yours.**
