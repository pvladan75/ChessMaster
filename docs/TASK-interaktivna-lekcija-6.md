# Task: the lesson step draws what the author drew, and says what it shows

A bounded job for an outside agent. **This file plus
[brief-interaktivna-lekcija-6-2026-09.md](brief-interaktivna-lekcija-6-2026-09.md)
are the only context you get** — do not rely on any conversation before them.

Branch: `batch/interaktivna-lekcija-6`. Commit as
`batch 49 — interaktivna lekcija, crtež i glas`. **Do not commit.** Leave the
worktree dirty; the lead reads the diff.

## What is asked

Flutter only, in `chess_app/lib/`. No server, no database, no credentials — you
do not need them and must not ask for them. Everything this job uses already
exists and is already tested; the job is the wiring.

1. `LessonViewerScreen` hands the current position's **arrows** and **squares**
   to the board it already builds.
2. The same screen offers its sentences through `SpeakableInfo` — the step's
   task, and the trainer's note on the move.

**Nothing else.** If the job turns out to need a change outside
`lesson_viewer_screen.dart`, **write in your report which change and why, then
stop.** Do not widen the scope.

## What you need before starting

* Flutter, and `flutter test` run **before you change anything**. It reads
  **1327 passing, 1 skipped and 7 failing** — the seven are
  `test/lesson_step_narration_test.dart`, which is your grade and is red on
  purpose. An eighth test in that file passes already; §6 of the brief says why.
  Measure the numbers yourself and report them; do not trust the ones here.
* The screen must work at **360 × 640**. A release build paints no overflow
  warning — it simply clips, and anything past the edge becomes unreachable.
  Three of those shipped on this project. Where a row can grow, use `Wrap`;
  where a width is fixed, take it from `MediaQuery`.

## Where things are

| | |
|---|---|
| `test/lesson_step_narration_test.dart` | **the specification.** Read it first and read it whole |
| `lib/features/assignments/screens/lesson_viewer_screen.dart` | the screen, and the only file you should need to change |
| `lib/move_tree.dart` | `PgnLine`, `ChessArrow`, `SquareMark` — **read only** |
| `lib/widgets/game_screen/chess_board_with_overlay.dart` | `arrows` and `squares` — **read only**, shared by every screen |
| `lib/widgets/speakable_info.dart` | every spoken sentence, without exception |
| `lib/widgets/app_feedback.dart` | every snackbar, without exception |
| `docs/PLAN-INTERAKTIVNA-LEKCIJA.md` | §2 is the reasoning behind the rules |

## The changes, in this order

### 1. The drawing

The screen already parses the step's PGN into a `PgnLine` and keeps `_fens`,
`_moves` and `_comments` from it. Keep the arrows and the squares the same way,
and read them off `_moveIndex` **on every build**, not once when the step loads:

* `_moveIndex == 0` is the position before the first move — the drawing comes
  from `line.rootArrows` and `line.rootSquares`;
* `_moveIndex == k > 0` — from `arrows[k - 1]` and `squares[k - 1]`, the same
  offset `_comments[_moveIndex - 1]` already uses;
* a step with no line draws nothing, and must keep drawing nothing.

Stepping forward and back is a real case, not an edge one: it is how a child
reads a line. The gate walks it.

### 2. The voice

`SpeakableInfo` around the sentences the screen already draws — the step's
`instruction`, and the note under the move. `text` is what is spoken and it is
the same string that is drawn; use `child:` when the screen draws the sentence
itself with its own styling.

`autoSpeak` stays `false`. Do not add a speech switch to this screen.

## Method

1. Read the brief whole. §2 is the rule everything rests on, §5 is what gets the
   work rejected.
2. Read `test/lesson_step_narration_test.dart` whole before writing any code.
3. Work in the order above. The drawing has no dependency on the voice.
4. `dart format` every file you touched.
5. `flutter analyze` — it reports **29 issues and does not exit clean**, all
   `info`, all `curly_braces_in_flow_control_structures`. Compare the list, not
   the exit code: zero errors, zero warnings, no new info.
6. `flutter test`. Report the count and the delta from your own starting number.

## What must hold

* **Nothing is only heard.** Every `SpeakableInfo` sentence is also drawn, and
  the gate checks it as a property over the whole screen.
* **The board widget and the painter are finished.** They are shared by every
  screen in the app and they are not yours.
* **Never a raw `ScaffoldMessenger`.** `AppFeedback` exists because a snackbar
  once threw and took down the recording it was reporting on. Do the thing, then
  say it.
* **The step that asks keeps working.** Narration is added to it, not instead of
  it: the options stay, the board stays locked on a choice, „Pokaži mi" still
  appears after the second wrong answer.
* **No new Serbian strings.** The sentences belong to the trainer.
* **Do not edit anything under `test/`.** Those tests are your grade.

## Your report

Write `report-batch-49.md` in the worktree root. It must state:

* `flutter test` before and after, both measured by you, and the 8 named tests
  passing;
* the `flutter analyze` count, and whether the list changed;
* **proof of the properties, not the mechanisms.** „The drawing follows the move
  index" is proved by stepping forward and back and reading `arrows` and
  `squares` back off the board widget — which is what the gate does — not by
  stating that you indexed it;
* any file you added a user-facing string to, if you added one at all;
* anything this brief or this task file got wrong.
