# Task: a lesson step that asks something back — the screen

A bounded job for an outside agent. **This file plus
[brief-interaktivna-lekcija-4b-2026-09.md](brief-interaktivna-lekcija-4b-2026-09.md)
are the only context you get** — do not rely on any conversation before them.
When the work is merged, this file is deleted.

Branch: `batch/interaktivna-lekcija-4b`, off `40f8da2` — the commit that carries this file and the brief. Commit as
`batch 48 — interaktivna lekcija, ekran koji pita`. **Do not commit.** Leave the
worktree dirty; the lead reads the diff.

## What is asked

Flutter only, in `chess_app/lib/`, against a backend that is already built and
frozen. The brief has the exact request and response shapes; this file is the
scope and the method.

1. `LessonStep` learns what its step asks: a `LessonStepKind` and its `choices`.
2. `AssignmentApiService` gets `answerLessonStep` and `revealLessonStep`, with
   `StepAnswerResult` and `StepRevealResult`.
3. `LessonViewerScreen` asks the question, shows the server's verdict, and
   offers „Pokaži mi" after the second wrong answer.

**Nothing else.** If the job turns out to need a change outside
`chess_app/lib/`, **write in your report which change and why, then stop.** Do
not widen the scope, and **do not touch `chess_backend/` at all** — it is
finished, frozen, and not yours.

## What you need before starting

* Flutter, and `flutter test` green-except-one before you change anything. It
  reads **1297 passing, 1 skipped, and one file failing to load** — that file is
  `test/lesson_step_asks_test.dart`, which is your grade and is red on purpose.
  Measure the numbers yourself and report them; do not trust the ones here.
* **No backend, no database, no credentials.** You do not need them and must not
  ask for them. Build against the shapes in §3 of the brief and fake the client
  the way `test/lesson_step_asks_test.dart` already does.
* The student's screen must work at **360 × 640**. A release build paints no
  overflow warning — it simply clips, and buttons past the edge become
  unreachable. Three of those shipped on this project. Where a row can grow, use
  `Wrap`; where a width is fixed, take it from `MediaQuery`.

## Where things are

| | |
|---|---|
| `test/lesson_step_asks_test.dart` | **the specification.** Read it first and read it whole |
| `lib/features/assignments/screens/lesson_viewer_screen.dart` | the screen you are extending |
| `lib/features/assignments/services/assignment_api_service.dart` | `submitCustomAttempt` is the same shape as what you are adding |
| `lib/features/assignments/models/assignment.dart` | `LessonStep` |
| `lib/widgets/action_banner.dart` | the one look for "this expects something from you" |
| `lib/widgets/app_feedback.dart` | every snackbar, without exception |
| `docs/PLAN-INTERAKTIVNA-LEKCIJA.md` | §2.4, §2.5, §2.6 are the reasoning behind the rules |

## The changes, in this order

### 1. The model — no screen, no network

`LessonStepKind { show, askMove, askChoice }`, parsed from the wire's
`"show" | "ask_move" | "ask_choice"`. **An absent kind is `show`, and so is one
you do not recognise** — an old app meeting a newer kind has a child in front of
it and nobody to tell, so it shows the board and asks nothing.

`LessonStep.choices` is a `List<String>` of the option texts, in the order they
arrived. That order is the answer: a choice is sent back as an index.

Proved by the four tests in `the model carries what the step asks`.

### 2. The service — the two calls

Beside `submitCustomAttempt`, which already does exactly this for scanned
positions: post, parse, return null on any failure rather than throwing.

Returning null is not an error path to tidy away. It is the case where a child
on school wifi loses the answer they just sent, and the screen has to say so.

### 3. The screen

* an `api` parameter, defaulting to the real service, so the tests can fake it;
* a `submitMove` the board's move handler goes through, so a test drives the
  same path a real move does;
* the board is playable on `show` and `ask_move`, **locked on `ask_choice`**;
* the verdict, in the server's own words for a wrong answer;
* „Pokaži mi" **after the second** wrong answer, not the first — one miss is a
  try, not a child who is stuck.

## Method

1. Read the brief whole. §2 is the rule everything rests on, §5 is what gets the
   work rejected.
2. Read `test/lesson_step_asks_test.dart` whole before writing any code.
3. Work in the order above. The model has no dependencies; the screen has both.
4. `dart format` every file you touched.
5. `flutter analyze` — it reports **29 issues and does not exit clean**, all
   `info`, all `curly_braces_in_flow_control_structures`. Compare the list, not
   the exit code: zero errors, zero warnings, no new info.
6. `flutter test`. Report the count and the delta from your own starting number.

## What must hold

* **The answer never reaches the client.** The server judges. If you want the
  right answer in Dart to make something work, you have found a mistake in the
  brief — report it and stop.
* **Serbian strings only**, and only the five in §4 of the brief. The gate
  compares them byte for byte.
* **Never a raw `ScaffoldMessenger`.** `AppFeedback` exists because a snackbar
  once threw and took down the recording it was reporting on. Do the thing, then
  say it.
* **Right and wrong may not differ by hue alone.** The owner is colourblind, and
  their live sign-off is what this feature ships on.
* **No timer, no score, no streak.** Children use this side by side in a room.
* **Do not edit anything under `test/`.** Those tests are your grade.

## Your report

Write `report-batch-48.md` in the worktree root. It must state:

* `flutter test` before and after, both measured by you, and the 14 named tests
  passing;
* the `flutter analyze` count, and whether the list changed;
* every file you added a user-facing string to;
* **proof of the properties, not the mechanisms.** "The board is locked on a
  choice step" is proved by reading `isAllowedToMove` back out of the widget —
  which is what the test does — not by stating that you set it;
* anything this brief or this task file got wrong.
