# TASK — the screen reads itself out, and can be told to stop

This file plus `docs/brief-govor-na-panelima-2026-09.md` are the only context
you get. **Do not rely on any conversation before them.** Read the brief first;
it holds the reasoning, the exact widget contract, and the pass conditions.

Branch: `design/govor-na-panelima`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 2 of `docs/PLAN-JEDNOSTAVNOST.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side.

**Do not change `SpeakableInfo`, `SpeechToggleButton` or `SpeechService`.** They
were written and tested in phase 0 precisely so this batch does not have to
decide how speech behaves. If one of them cannot do what a panel needs, **say so
in your report and stop** — do not work around it.

If the job turns out to need a change outside `chess_app/lib/features/` and
`chess_app/test/`, write which change and why, then stop.

## What you need before starting

* Flutter, and `flutter test` green before you change anything. **Measure the
  count yourself and report it; do not trust a number quoted at you.** It should
  be 1108 passing and 1 skipped.
* No backend, no database, no credentials.
* `test/phase0_widgets_test.dart` shows how to drive speech in a test: a fake
  `TtsEngine`, `SpeechService.forTesting`, and the settings singleton. **Copy
  that pattern.** A test that reaches the real engine talks to the machine
  running the suite.

## Where things are

| | |
|---|---|
| `chess_app/lib/widgets/speakable_info.dart` | `SpeakableInfo` and `SpeechToggleButton` — the whole contract, already written |
| `chess_app/lib/services/speech_service.dart` | `speak`, `stop`, `speaking`, `SpeechState` — do not change |
| `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart` | the question, the verdict at 991, the app bar at 1084 |
| `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart` | `_note`, the banner, the finished screen, the app bar at 2378 |
| `chess_app/test/phase0_widgets_test.dart` | the fake engine and the way speech is set up in a test |

## The files you may add

Exactly these, and no others. **A file by another name fails the untracked-tree
gate and takes the whole round with it.**

| path | what |
|---|---|
| `chess_app/test/govor_na_panelima_test.dart` | the tests for everything below |

Everything else is an edit to a file that already exists. Leave no scratch
files.

## The changes, in this order

### 1. The drill speaks what it asks

`SpeakableInfo` around:

* the question — „Šta igrate belim?" / „Šta igrate crnim?" and the sentence
  under it, as **one** spoken sentence rather than two;
* the verdict built at line 991 („Tačno — Nf3 · protivnik d5 · …");
* the sentence shown when there is nothing due.

The question and the verdict get `autoSpeak: true`. Everything else gets the
speaker control and stays quiet until it is pressed. §2.2 of the brief says why
that line is drawn where it is.

### 2. The build screen speaks what it is waiting for

`SpeakableInfo` around `_note`, the unconfirmed banner's sentence, and the
finished screen's sentence. **None of these auto-speak** — they are true, they
are not questions.

### 3. The switch is in the app bar

`SpeechToggleButton` in the app bar of both screens, beside the board menu.
Nothing else: it is one widget and it already does the whole job.

### 4. It works with no voice on the machine

Speech is off by default and many machines have no Serbian voice at all. Every
panel must read exactly as it does today when speech is unavailable, and the
speaker control must not throw. Phase 0 guards this; your job is not to undo it
by, for example, awaiting a speech call before showing a widget.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Reuse what exists. A second speaker button, a second way to read a setting,
   or a `flutter_tts` call of your own fails the batch on review even if the
   gates pass.
3. `flutter analyze` must stay at **29** issues — all `info`, all
   `curly_braces_in_flow_control_structures`. Compare the list, not the exit
   code.
4. `flutter test`. Report the count and the delta from your own starting number.
5. **`dart format` every Dart file you touched — last.**

## What must hold

* **User-facing strings stay Serbian.** What is spoken is what is written: pass
  the sentence the screen already shows. **Do not compose a second wording for
  the voice.**
* **Never use `ScaffoldMessenger` directly** — `AppFeedback` only.
* **Do the thing, then say it.** A speech call must never sit in front of the
  action it describes. This project has shipped that bug twice: playback that
  never started because a failing audio call was awaited first, and a recording
  that would not stop because a snackbar threw.
* Every screen you touch keeps working with speech **off** — which is the
  default and therefore the case most readers see.

## Your report

Write `report-govor-na-panelima.md` in the worktree root, stating:

1. `flutter test` count before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after;
3. every panel you wrapped, and which ones auto-speak;
4. **how you proved a panel speaks the sentence it shows** — the string your
   fake engine actually received, quoted;
5. **how you proved nothing is spoken when speech is off**;
6. **how you proved a machine with no voice still renders every panel**;
7. anything the brief got wrong.

**Do not claim a number you did not compute in that run.**
