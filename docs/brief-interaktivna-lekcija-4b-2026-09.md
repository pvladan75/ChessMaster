# Brief — a lesson step that asks something back (client half)

Phase 4b of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`. Written for an outside agent
that has none of the conversation which produced it.

## 1. Why this job exists

A trainer prepares a lesson about one idea — a weak square, exploiting a pin,
the plan in a pawn structure — and the student walks through it alone at home,
or on their own device in a classroom while the trainer helps whoever is stuck.

Until now a lesson step was a **picture**: a board, some text, maybe a line to
step through. This phase makes a step able to **ask**:

* `ask_move` — the board waits for the student to play a move;
* `ask_choice` — two to four written options, one of them right, for when the
  question is about an idea rather than a move („koji je strateški plan").

**The server side is finished and frozen** (commit `c9d0513`). It judges, it
records, and it keeps the answer. Your job is the screen.

## 2. The one rule that shapes everything here

**The answer is not on the client, and must never be put there.**

`GET /assignments/:id` redacts it: a student's payload has no `solutionSan`, no
`acceptedSans`, and no flag saying which choice is correct. This is deliberate —
sending the solution so the client could mark its own work would hand the
student the very thing being asked of them. The backend has kept this rule for
scanned positions since before this feature existed.

So: **you cannot judge an answer locally, and must not try.** Every verdict
comes back from the server. If you find yourself wanting the right answer in
Dart in order to make something work, you have found a mistake in this brief —
say so in your report and stop, rather than working around it.

## 3. The contract — exact shapes

### 3.1 What a step looks like on the wire

`GET /assignments/:id` returns `steps: [...]`, each already redacted:

```jsonc
{
  "id": "a3f9c1d2",              // stable; never construct or alter one
  "title": "Slaba polja",
  "fen": "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1",
  "pgn": "1. Ra8# { Mat. }",     // optional
  "instruction": "Nađi mat u jednom potezu.",  // optional
  "kind": "show" | "ask_move" | "ask_choice",  // may be ABSENT — see below
  "choices": [ { "text": "Otvoriti liniju" }, { "text": "Zameniti damu" } ]
}
```

* **`kind` may be absent**, and absent means `show`. Every lesson saved before
  this feature has no `kind` at all, and every one of them must keep working.
* **A `kind` you do not recognise is also read as `show`.** This is the opposite
  of the server's rule, and deliberate: the server refuses an unknown kind
  because a trainer who typed one must be told, while an old app meeting a newer
  kind has nobody to tell and a child in front of it. Show the board, ask
  nothing, do not break the lesson.
* `choices` carries **only** the text. There is no `correct` field and there
  will never be one.

### 3.2 Answering — `POST /assignments/:id/step/:position/answer`

Body, one of:

```jsonc
{ "moveSan": "Ra7" }      // ask_move
{ "choiceIndex": 1 }      // ask_choice, 0-based, in the order given
```

Response `200`:

```jsonc
{
  "correct": true,
  "reason": "drugi tačan potez",   // server's own words, in Serbian
  "playedSan": "Ra7",              // null for a choice, null if illegal
  "solutionSan": "Ra8#",           // released only now, after answering
  "correctIndex": 1                // ask_choice only, else null
}
```

Errors: `400` no answer sent, `404` not your homework or no such step, `409`
the step is a `show` step and does not take an answer.

### 3.3 „Pokaži mi" — `POST /assignments/:id/step/:position/reveal`

No body. Response `200`:

```jsonc
{ "solutionSan": "Ra8#", "acceptedSans": ["Ra7"], "correctIndex": null }
```

Recorded server-side as its own thing — **not** as a wrong answer. The trainer's
review has to be able to tell „rešenje otkriveno" from „netačno", because those
are different facts about a child.

### 3.4 What already exists and must be reused

| | |
|---|---|
| `lib/features/assignments/screens/lesson_viewer_screen.dart` | the screen. Extend it; do not write a second one |
| `lib/features/assignments/services/assignment_api_service.dart` | add the two calls here, beside `submitCustomAttempt`, which is the same shape |
| `lib/features/assignments/models/assignment.dart` | `LessonStep` lives here |
| `lib/widgets/action_banner.dart` | **the** look for "this expects something from you". Use it; do not invent a second one |
| `lib/widgets/app_feedback.dart` | every snackbar goes through this. A raw `ScaffoldMessenger` fails a gate |
| `lib/widgets/game_screen/chess_board_with_overlay.dart` | the board, with `isAllowedToMove` |

## 4. Serbian strings — the complete list

The `strings` gate compares user-facing literals byte for byte, and this batch
**adds** some. These are the only new ones allowed, and they must appear exactly
as written:

| where | string |
|---|---|
| correct, nothing more to say | `Tačno.` |
| correct, but the lesson continues from the author's move | `Tačno. Mi nastavljamo posle $san.` |
| the escape, after two wrong answers | `Pokaži mi` |
| what the reveal shows | `Rešenje: $san` |
| the server did not answer | `Odgovor nije poslat — proveri vezu.` |

**A wrong answer's text is the server's `reason`, shown verbatim.** Do not
compose your own. „taj potez nije moguć u ovoj poziciji" and „nije traženi
potez" mean very different things to a child, and the server already knows
which happened.

Every string in the app is Serbian, for Serbian children and trainers. Do not
add English to any screen.

## 5. What gets this rejected

* **Judging on the client.** §2.
* **A second viewer screen**, or a second banner, or a raw `ScaffoldMessenger`.
* **Editing any file under `test/`.** The tests are the grade; changing them is
  changing your own mark. If a test looks wrong, say so in the report and stop.
* **Touching `chess_backend/` at all.** It is frozen and it is not yours.
* **Colour as the only difference between right and wrong.** The owner is
  colourblind. Correct and incorrect must differ by icon or shape, not only hue —
  `ActionBanner` already does this and is why it exists.
* **A timer, a score, a streak, or anything ranking one child against another.**
  This screen is used in a classroom where children can see each other's
  screens.
* **New packages.** Nothing goes in `pubspec.yaml`.

## 6. How you will be judged

Machine-checked, in this order:

1. `flutter test` — **the 14 tests in `test/lesson_step_asks_test.dart` must
   pass**, and the whole suite must be at least **1311** passing with 1 skipped.
   Measure both numbers yourself; do not trust these.
2. `flutter analyze` — 29 issues, all `info`, all
   `curly_braces_in_flow_control_structures`. **It does not exit clean and never
   has.** Zero errors, zero warnings, and no info that is not already on that
   list.
3. `dart format` on every file you touched.
4. The `strings`, `idioms` and `worktree` gates.

The tests are red right now because the API they call does not exist yet. That
is the job: `LessonStepKind`, `LessonStep.choices`, an `api` parameter on
`LessonViewerScreen`, a `submitMove` the tests can drive, and the two service
calls with `StepAnswerResult` / `StepRevealResult`. Read the test file — it is
the specification, and it was written before the implementation on purpose.

## 7. Your report

Not a summary. Numbers you computed in this run:

* `flutter test` before and after, both measured by you;
* the `flutter analyze` count and whether the list changed;
* every file you added a user-facing string to;
* **proof of the property, not the mechanism** — "the board is locked on a
  choice step" is proved by reading `isAllowedToMove`, not by saying you set it;
* **anything this brief got wrong.** A correction is worth more than a clean
  report, and previous batches on this project have found real errors in briefs.
