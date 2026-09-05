# Task: the trainer writes the step

A bounded job for an outside agent. **This file plus
[brief-interaktivna-lekcija-7-2026-09.md](brief-interaktivna-lekcija-7-2026-09.md)
are the only context you get** — do not rely on any conversation before them.

Branch: `batch/interaktivna-lekcija-7`. Commit as
`batch 50 — interaktivna lekcija, trenerov editor`. **Do not commit.** Leave the
worktree dirty; the lead reads the diff.

## What is asked

Flutter only, in `chess_app/lib/`, against a backend that is already built and
frozen. The brief has the exact shapes; this file is the scope and the method.

1. `LessonStepEditorPanel` — new: the ordered steps, and the three fields of the
   selected one (the sentence, what it asks, the answer).
2. A preview that runs `LessonViewerScreen` and does not judge.
3. „Napravi korak od ove pozicije" in the Analysis Studio.
4. `CreateCourseDialog` loses its per-step instruction control.

**Nothing else.** If the job turns out to need a change outside those four,
**write in your report which change and why, then stop.** Do not widen the
scope, and **do not touch `chess_backend/` at all** — it is finished, frozen, and
not yours.

## What you need before starting

* Flutter, and `flutter test` run **before you change anything**. It reads
  **1334 passing, 1 skipped, and one file failing to load** — that file is
  `test/lesson_editor_test.dart`, which is your grade. It does not load because
  it imports `LessonStepEditorPanel`, which does not exist yet; that widget is
  the first thing you build. Measure the numbers yourself and report them; do
  not trust the ones here.
* **No backend, no database, no credentials.** You do not need them and must not
  ask for them. Build against §3 of the brief and fake the service the way
  `test/lesson_editor_test.dart` already does.
* The panel must work at **360 × 640**. A release build paints no overflow
  warning — it simply clips, and controls past the edge become unreachable.
  Three of those shipped on this project. Where a row can grow, use `Wrap`;
  where a width is fixed, take it from `MediaQuery`.

## Where things are

| | |
|---|---|
| `test/lesson_editor_test.dart` | **the specification.** Read it first and read it whole |
| `lib/features/lessons/services/lesson_api_service.dart` | every call to `saved_lessons`. **Read only** |
| `lib/features/assignments/screens/lesson_viewer_screen.dart` | the preview instantiates this. **Read only** |
| `lib/widgets/create_course_dialog.dart` | keeps the order, loses the instruction control |
| `lib/screens/ai_studio_screen.dart` | where the new button belongs |
| `lib/widgets/app_feedback.dart` | every snackbar, without exception |
| `docs/PLAN-INTERAKTIVNA-LEKCIJA.md` | §2.4, §4 and §6 are the reasoning behind the rules |

## The changes, in this order

### 1. The panel — no studio, no preview

`LessonStepEditorPanel({required session, required api, required lesson})`, at
`lib/features/lessons/widgets/lesson_step_editor_panel.dart`. The signature is
fixed by the gate.

The steps in order; the selected one editable. `instruction` in a field keyed
`const Key('step-instruction')`. `kind` as a choice of three. The answer
according to the kind: `solutionSan` **played on the board rather than typed**,
optional `acceptedSans`, or 2–4 choices with exactly one correct.

`Sačuvaj korak` sends the whole list through `api.update`. Carry each stored step
map through and put back what you did not change — §3.3 of the brief is the
reason, and it is the one thing in this batch that destroys data if it is wrong.

### 2. The preview

`Pregled` opens `LessonViewerScreen` in your own container, **with an `api` you
pass it**. Without one it builds a real service and posts against the trainer's
own account from inside a preview.

### 3. The studio button

„Napravi korak od ove pozicije": the current FEN plus the line's PGN, through
`api.appendStep`. Show the server's answer if it refuses.

### 4. The dialog gives up one field

Remove the per-step instruction control from `CreateCourseDialog` — the icon
button tooltipped „Zadatak za učenika" and the dialog it opens. An `instruction`
arriving with a position from the library still travels; that is data, not
authoring.

## Method

1. Read the brief whole. §2 is the rule everything rests on, §5 is what gets the
   work rejected.
2. Read `test/lesson_editor_test.dart` whole before writing any code.
3. Work in the order above. The panel has no dependency on the preview.
4. `dart format` every file you touched.
5. `flutter analyze` — it reports **29 issues and does not exit clean**, all
   `info`, all `curly_braces_in_flow_control_structures`. Compare the list, not
   the exit code: zero errors, zero warnings, no new infos.
6. `flutter test`. Report the count and the delta from your own starting number.

## What must hold

* **The server decides what a step may be.** Send what was typed; show what came
  back, in the words it came back in.
* **A step keeps its id.** Never invent one, never drop one, never build a step
  map from scratch.
* **One renderer for the student's screen.** The preview instantiates
  `LessonViewerScreen`.
* **The preview posts nothing.**
* **Never a raw `ScaffoldMessenger`.** `AppFeedback` exists because a snackbar
  once threw and took down the recording it was reporting on. Do the thing, then
  say it.
* **Right and wrong may not differ by hue alone.** The owner is colourblind, and
  „which choice is correct" is exactly where a tick belongs and a green
  background does not.
* **Do not edit anything under `test/`.** Those tests are your grade. If one
  looks like it can only be passed by changing something the brief calls
  finished, say so in the report and stop.

## Your report

Write `report-batch-50.md` in the worktree root. It must state:

* `flutter test` before and after, both measured by you, and the 6 named tests
  passing;
* the `flutter analyze` count, and whether the list changed;
* every file you added a user-facing string to — this batch adds copy, so list
  them all;
* **proof of the properties, not the mechanisms.** „Ids survive an edit" is
  proved by reading the list the service was handed — which is what the gate
  does — not by stating that you copied the map;
* anything this brief or this task file got wrong.
