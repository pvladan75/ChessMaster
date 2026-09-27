# Brief — Preparation, phase 7: the transcript on a recording's player

`docs/PLAN-PRIPREMA.md` — read §4's **D9**, **D15** and phase 7 under §6.
The server half is built and measured; this is the app's half: „Transcribe"
on the player, the sentences beside the board, a tap on one moves the
player to it, and its text can be corrected. Times cannot be edited.

**Work only in this worktree**:
`D:\Projekti\chess_master\.claude\worktrees\priprema-faza-7` (branch
`priprema-faza-7`). App commands run from its `chess_app/`. Touch nothing in
`D:\Projekti\chess_master` itself, commit nothing, push nothing. `pub get`
has been run. **Never start the server.** `flutter test` rewrites the seven
generated plugin registrants under `linux/`, `macos/` and `windows/` with
other line endings; leave them, the lead restores them.

Baseline measured in this worktree on 27.9.2026, at `7c9bff06`, with nothing
else running: **4796 passed, 1 skipped**; `flutter analyze` the **22** known
infos (all `curly_braces_in_flow_control_structures`). The gate adds 24.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately. **And when a test's own timing or helper is
what stands in your way, say that — do not change what a screen does for a
person in order to fit it.**

## What is already here, and is the lead's

- `docs/gates/replay_transcript_test.dart` — **the gate**. Copy it to
  `chess_app/test/replay_transcript_test.dart` and do not edit the copy
  except to report a fault. **Its head comment is the frozen contract**:
  the model's names, every key, every word on the screen it reads.
  Proved before you got it: it fails to compile on the contract's names
  and nothing else (`RecordingTranscript`, `TranscriptSentence`,
  `sentenceAt`, the model file); without its model group it runs on
  `master`, the three absence cases are green there and every other case is
  red — the layout cases exactly at the missing panel, after both boards
  were measured. **None of it has been watched going green.**
- The server (`chess_backend/routes/recordingTranscript.js`, read its head):
  - `GET /recordings/:id/transcript` →
    `{ available, languages: ['en','sr-Latn','de','es','it','fr'], transcript }`,
    `transcript` null or
    `{ language, vendor, model, durationMs, sentences: [{startMs, endMs, text, heard}], updatedAt }`.
    404 for anybody but the host.
  - `POST` `{ language }` → 201 `{ transcript }`; a refusal is
    `{ error, reason? }` with 400/404/409/413/422/429/500/502/503. It takes
    seconds (1.4 s for 2.5 minutes of sound; a 30-minute take perhaps 20),
    so the screen holds the button, not the player.
  - `PUT` `{ texts: [one string per sentence] }` → 200 `{ transcript }`.
    Nothing else is read from the body.

## The pass condition

```
flutter test test/replay_transcript_test.dart
flutter test test/replay_share_test.dart test/replay_audio_test.dart test/replay_frame_test.dart test/replay_space_key_test.dart test/replay_squares_test.dart test/home_recording_delete_test.dart test/usage_screen_test.dart
```

all green, **and** the full app suite at **4796 + 24 = 4820 passed, 1
skipped, plus yours** (say how many, by file), **and** `flutter analyze` with
the same 22 infos and nothing new, no `// ignore` added. Run `dart format`
on every Dart file you touch. No existing test is deleted, skipped or
weakened; one rewritten must be rewritten openly, with a comment saying
which rule superseded what.

## What is built

1. **The model** — `lib/models/recording_transcript.dart`, as the contract
   says. `sentenceAt` is the one answer to „which sentence is being said":
   the last one whose start has passed. The panel and nothing else asks it.
2. **One client for the three routes** — `lib/services/` beside
   `lesson_recording_api.dart`, taking the player's `http.Client` (the
   tests hand the player a `MockClient`; a call that goes around it is a
   call the gate cannot see). An answer that is not the shape above is „no
   transcript, not offered" — never a crash, never a message: the existing
   player tests answer every unknown path with `[]`.
3. **The panel** on `ReplayPlayerScreen`, asked for only when the reader is
   the host and the recording's `source` is `preparation`:
   - drawn when the server offers transcribing or a transcript exists;
   - no transcript: „No transcript yet." and „Transcribe…"; with one, the
     sentences and „Transcribe again…", which asks first (the dialog says it
     „replaces" the transcript and its corrections);
   - the language dialog: the server's languages by their
     `TutorialLanguage` labels, Serbian (Latin) chosen first, and one
     sentence saying the recording's sound is sent to Groq to be heard;
   - while the request is out, „Transcribing…" in place of the button, and a
     second tap sends nothing — the guard is set **before** the request, not
     when it returns (the double „Record" of phase 3);
   - a refusal is the server's own sentence through `AppFeedback.error`, and
     the panel is as it was;
   - each sentence shows its start as `m:ss` and its whole text; a tap moves
     the player there (the screen's own `_seekTo`); the sentence being said
     is marked by a border **and** the `transcript-current` marker — **never
     by colour alone**, the owner does not see hue;
   - a pencil opens the sentence as a `TextField`; Save sends every text
     (`PUT`), Cancel restores; a refused save keeps the field open with what
     was typed; a corrected sentence shows „Heard: …" under it, as text;
   - an emptied sentence is allowed (the vendor invents words over silence)
     and reads as „(nothing said)".
4. **Where it stands.** From 840 wide and not on a phone held sideways
   (`LandscapeBoardLayout.applies`): a column right of the board and its
   controls, and **the board no smaller than it is today** — the board is
   bound by height at every desktop size, so the column takes width the
   board never had. On a phone held sideways: the `panels` slot of
   `LandscapeBoardLayout`, which today is empty. Upright below 840: a
   „Transcript" button in the control deck (`replay-transcript-open`) opens
   the panel in a bottom sheet at most 60% of the screen tall; the app bar
   is already full at 360.
5. **Usage this month** — every `stt_<provider>_seconds` is one row,
   „Recordings transcribed", minutes rounded up, after the narration row
   (`countedRows` in `usage_screen.dart`, as the voices' characters are).

## Rules that are not in the gate, and are graded

- **No `Tooltip` inside another `Tooltip`, no Material `Slider`** — the
  Windows screen-reader crash (`CLAUDE.md`, 22.9 and 26.9.2026). An
  `IconButton`'s own `tooltip` is fine on its own.
- Text that must be read is not clipped: measure with `didExceedMaxLines`
  wherever you give a `maxLines`.
- A long transcript (a 30-minute take is some 400 sentences) is a lazy
  list, not a `Column` of 400.
- Every message goes through `AppFeedback`.

## Cases you add

At least these, each watched red on the wrong code before green:

1. The client: a `GET` answering `[]`, `{}`, and a 500 is „nothing to
   draw", and none of them throws.
2. A student's player asks the server nothing about a transcript even when
   the recording is from Preparation — already in the gate; add the case
   for a **room** recording whose reader is the host at 360 × 640 (the
   deck's new button is absent there too).
3. 400 sentences: the panel builds, scrolls to the last, and a tap on it
   moves the player.

## What is not built

- No change to the server, the timeline, the recording or its sound.
- No tutorial from a recording (phase 8), no translation (phase 9).
- No automatic scrolling of the list while it plays.

## The report

1. **What the brief or the gate got wrong**, first, with the case's name and
   what you measured. If nothing: say so.
2. The pass condition's commands, their last lines, as run by you — the
   gate, the player's files, the full app suite, `flutter analyze`'s summary.
3. Cases you added, by file and name, and for each the wrong code you
   watched it fail on.
4. Every existing test you rewrote, with the rule that superseded it.
5. Anything you saw that is outside this phase — reported, not fixed.
