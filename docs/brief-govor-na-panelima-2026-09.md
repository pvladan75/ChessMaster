# Brief: the screen says out loud what it is asking for

Written 3.9.2026. Pairs with [TASK-govor-na-panelima.md](TASK-govor-na-panelima.md),
which holds the scope and the method. This file holds the *why*, the widget
contract exactly, and the rules that bite.

Phase 2 of [PLAN-JEDNOSTAVNOST.md](PLAN-JEDNOSTAVNOST.md). Phase 0 is merged:
`SpeakableInfo`, `SpeechToggleButton` and the settings behind them exist and are
tested. **This batch wires them. It does not design them.**

## 1. Why this job exists

The owner: *„treba da uvedemo TTS za info panele gde to nemamo, da korisnik čuje
šta treba da uradi, da mu se serviraju informacije, ne mora sve da čita sa
ekrana, iako stoji, to može da bude naporno. I da u ekranu može da isključi/
uključi TTS bez izlaska iz ekrana."*

Two halves, and the second is the one that decides whether the first is
tolerable. A screen that reads itself out and cannot be silenced where it is
being read is a screen people turn off once and never turn on again.

The users are children. The screen they meet most is a board with a question
under it, and the question is the thing worth hearing while the eyes stay on the
pieces.

## 2. What to build

### 2.1 Which panels

Three on the drill screen and three on the build screen. Nothing else — a screen
where every sentence has a speaker beside it is a screen with a column of
speakers down the side of it.

**Drill** (`repertoire_drill_screen.dart`):

* the question — „Šta igrate belim?" / „Šta igrate crnim?" together with the
  instruction under it, spoken as **one** sentence. Two `SpeakableInfo` widgets
  stacked would say the second thing over the first;
* the verdict, built at line 991 as
  `'Tačno — Nf3 · protivnik d5 · sledeće za 3 dana'`. The `·` separators are for
  the eye; when you hand it to speech, the sentence should not read as a list of
  fragments. `SpeechService.speakable` already turns notation into words — read
  what it does before deciding whether the separators need replacing, and say in
  your report what you chose;
* the sentence shown when nothing is due.

**Build** (`repertoire_build_screen.dart`): `_note`, the unconfirmed banner's
sentence, and the finished screen's sentence.

### 2.2 What speaks by itself, and what waits to be asked

`autoSpeak: true` **only** on the drill's question and its verdict. Those two
are the loop: a question arrives, you answer, you are told how it went. That is
what somebody wants read to them while looking at the board.

Everything else gets the control and stays quiet. The reason is in phase 0's
own doc comment and it is worth repeating: a screen where every panel announces
itself is the noise this feature is trying not to be. A note about a spine that
finished is true; it is not asking anything.

### 2.3 The switch, in the app bar

`SpeechToggleButton`, beside the board menu, on both screens. It writes the same
app-wide setting the settings screen writes and stops the voice the moment it is
turned off. It is one widget and it is finished — do not wrap it, do not add a
second confirmation, do not put it in a menu.

## 3. The contract, exactly

Already written in `lib/widgets/speakable_info.dart`. Do not change it.

```dart
SpeakableInfo({
  required String text,   // shown and spoken; the screen's own wording
  TextStyle? style,
  bool autoSpeak = false, // speak on appear and on change, if speech is on
  Widget? child,          // drawn instead of the plain text; `text` is still spoken
  AppSettingsService? settings, // tests only
  SpeechService? speech,        // tests only
})

SpeechToggleButton({ AppSettingsService? settings, SpeechService? speech })
```

Behaviour you can rely on, and must not re-implement:

* the speaker control is **never a no-op**: pressed with speech off it turns
  speech on and speaks; pressed while speaking it stops;
* nothing is spoken when `autoSpeak` is false until the control is pressed;
* every call into the engine is guarded — a machine with no voice renders the
  panel exactly as before;
* `SpeechService.speak` ignores a repeat of the sentence it just said, unless
  `force: true`. That is why a question that has not changed does not say itself
  twice when the widget rebuilds.

`SpeechService` also gives you `speakable(text)`, which turns notation into
words, and `speaking`, and `stop()`.

For tests: `SpeechService.forTesting(engine)` plus a fake `TtsEngine`
(`languages`, `setLanguage`, `setSpeechRate`, `speak`, `stop`).
`test/phase0_widgets_test.dart` has one to copy, and shows the
`SharedPreferences.setMockInitialValues({})` the settings singleton needs.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `SpeakableInfo`, `SpeechToggleButton` | the whole of the speech UI |
| `SpeechService.instance` | the engine, its state machine and its guards |
| `AppSettingsService.instance` | `speechEnabled`, `speechRate`, `speechLanguage` |
| `AppFeedback` | the only way to show a message |
| `test/phase0_widgets_test.dart` | the fake engine, and how speech is set up in a test |

## 5. Rules that bite

**A message must never take down the action it reports on.** Twice in this
codebase: playback that never started because a failing audio call was awaited
in front of the timer, and a recording that would not stop for a child because
`showSnackBar` threw first. **Do the thing, then say it.** No `await` on a
speech call before a `setState` that puts the answer on screen.

**What is spoken is what is written.** Pass the sentence the screen already
shows. A second wording for the voice drifts from the visible one within a
month, and then the app says something the screen does not.

**Speech is off by default.** Every panel must look and behave exactly as it
does today for a reader who never turns it on — which is most of them. A layout
that only works once a speaker icon is there has broken the common case.

**A release build paints no overflow warning.** A speaker button beside a
sentence is a row that grows, and the verdict line is the longest sentence on
the drill screen. `Wrap` where a row can grow, and **pump every panel you touch
at `Size(360, 640)`**.

**`flutter analyze` compares a list, not an exit code** — 29 infos, all
`curly_braces_in_flow_control_structures`. A thirtieth fails you.

**Prove the sentence, not the call.** A test asserting `speak` was called proves
plumbing. The property is that the words spoken are the words shown: assert on
the string your fake engine received.

## 6. How it will be judged

Nine gates, every one an exit code: nothing under `chess_backend/`; `strings`
byte-identical outside the allowance; `contrast`, `idioms`, `scale`;
`dart format --set-exit-if-changed`; `worktree` clean; `analyze` at 29;
`tests` at 1108 before and your own number after.

Then the diff is read for what no gate reaches: whether anything auto-speaks
that should not, whether a speech call was put in front of an action, and
whether the spoken string is the shown string.

## 7. Out of scope

* Anything in `chess_backend/`.
* Changing `SpeakableInfo`, `SpeechToggleButton` or `SpeechService`.
* Speech anywhere outside the two repertoire screens named in §2.1. The lesson
  room, the endgame trainer and the tactics trainer are a later phase and a
  different set of sentences.
* Choosing a voice, a rate or a language. That is the settings screen's job and
  it already does it.
* Reading the board out — announcing pieces and squares is a different feature
  with a different design, and it is not this one.
