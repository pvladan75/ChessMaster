# Brief: the trainer writes the step

Phase 7b of [PLAN-INTERAKTIVNA-LEKCIJA.md](PLAN-INTERAKTIVNA-LEKCIJA.md).
Flutter only, in `chess_app/lib/`. The backend is finished and frozen; there is
no endpoint to add, no schema to change, and **nothing under `chess_backend/` is
yours**.

## 1. Why this job exists

Everything a lesson step can be has been buildable on the server since phase 4a
and readable by the student since phase 6 — a board, a line, arrows, coloured
squares, a sentence read aloud, a question with a right answer. **No trainer can
write one.** `CreateCourseDialog` picks positions from the library and orders
them; it cannot set what a step asks, and a dialog is the wrong container for
authoring anyway. So the one thing standing between this feature and a live
lesson is a screen for the person making it.

That is also why `TODO-provera.md` item 108 cannot be started: checking a step
that asks currently means typing JSON into `position_list` by hand.

## 2. The rule everything else follows from

**The server is the only authority on what a step may be.**

`buildLessonStep` refuses rather than repairs, and each refusal names the rule
that was broken, in the trainer's language — a step that asks for a move without
a solution, a SAN that is not legal in the position, more than six accepted
moves, choices that are not 2–4 with exactly one correct. The editor's job is to
**send what the trainer typed and show what comes back**.

Do not re-implement any of those checks in Dart. A second copy drifts from the
first, and the copy nobody is testing is the one in Dart. The same rule already
governs answers — §2.4 of the plan — and it is the reason the student's screen
has no judge in it either.

## 3. The contract — what is where

### 3.1 `LessonApiService` — `lib/features/lessons/services/lesson_api_service.dart`

Landed 5.9.2026 for this batch. Every call the app makes to `saved_lessons` goes
through it.

```dart
Future<List<dynamic>> fetchAll({...});
Future<List<String>> fetchLabels();
Future<String?> save({required String title, ..., List<Map<String, dynamic>>? positionList});
Future<String?> update({required int id, required String title, ..., List<Map<String, dynamic>>? positionList});
Future<String?> delete(int id);
Future<String?> appendStep({required int lessonId, required Map<String, dynamic> step});
```

**`null` means it worked; a non-null `String` is the server's own sentence and is
what the trainer must see.** Never replace it with wording of your own.

**`positionList` is omitted from the request when you pass null**, and the server
reads a request that never mentions the steps as „leave them alone". Passing an
empty list clears them. This is not a nicety: until 5.9.2026 a rename deleted
every step of a course, silently.

### 3.2 The step, as the server takes it

```jsonc
{
  "id": "a3f9c1d2",        // never invent, never drop — see §3.3
  "title": "…",
  "fen": "…",
  "pgn": "…",              // optional: variations, {text}, [%cal], [%csl]
  "instruction": "…",      // what the reader is asked, or told
  "kind": "show",          // "show" | "ask_move" | "ask_choice"; absent = show

  "solutionSan": "Ra8#",           // kind: ask_move
  "acceptedSans": ["Ra7"],         // optional, at most 6

  "choices": [                     // kind: ask_choice, 2–4 of them
    { "text": "Otvoriti liniju", "correct": true },
    { "text": "Zameniti damu" }
  ]
}
```

### 3.3 The id is the one thing you may not lose

`review_items` and `assignment_items` key a student's memory and their recorded
answers to a step's **id**. A step that comes back without the one it went in
with orphans every one of those rows — silently, because nothing joins on them.

The server refuses the obvious version of this with a 409 („Koraci su stigli bez
svojih oznaka."), but only when the whole list arrives stripped. **Carry each
step's map through your editor and put back what you did not change**, exactly
as `CreateCourseDialog` already does. Never build a fresh map from your own
fields.

### 3.4 What already exists and must be reused

| | |
|---|---|
| `lib/features/lessons/services/lesson_api_service.dart` | every call. Do not write a second one, do not use `http` directly |
| `lib/features/assignments/screens/lesson_viewer_screen.dart` | **the preview.** Instantiate it; do not draw a second renderer |
| `lib/widgets/create_course_dialog.dart` | keeps ordering and picking; **loses its per-step instruction control** |
| `lib/screens/ai_studio_screen.dart` | where „Napravi korak od ove pozicije" belongs |
| `lib/widgets/app_feedback.dart` | every snackbar, without exception |
| `lib/widgets/action_banner.dart` | the one look for „this expects something from you" |

## 4. What to build

### 4.1 `LessonStepEditorPanel`

New, at `lib/features/lessons/widgets/lesson_step_editor_panel.dart`. The gate
constructs it directly, so this signature is fixed:

```dart
LessonStepEditorPanel({
  super.key,
  required UserSession session,
  required LessonApiService api,
  required Map<String, dynamic> lesson,   // as the server returns it, `position_list` and all
})
```

It shows the lesson's steps in order and lets the trainer edit the selected one:

* **the sentence** — `instruction`, in a field keyed `const Key('step-instruction')`;
* **what it asks** — `kind`, one of the three;
* **the answer** — `solutionSan` and `acceptedSans` for a move, the 2–4 choices
  with exactly one marked correct for a choice. `solutionSan` is captured by
  **playing the move on the board**, not typed: a trainer typing SAN is a
  trainer typing `Nf3` when they meant `Nxf3`, and the server will refuse it
  correctly and uselessly.

Two buttons the gate presses by their exact labels: **`Sačuvaj korak`**, which
sends the whole list through `api.update`, and **`Pregled`**, which opens the
preview.

### 4.2 The preview

`LessonViewerScreen` in a different container — a dialog or a route, your
choice. **Pass it an `api` of your own**; without one it builds a real
`AssignmentApiService` from the session and would mark steps seen, and post
answers, against the trainer's own account from inside a preview. It shows the
step; it does not judge, and the trainer already knows the answer.

### 4.3 The studio button

„Napravi korak od ove pozicije" in `ai_studio_screen.dart`: takes the board's
current FEN and the line's PGN (`[%cal]` and `[%csl]` included — the exporter
already writes them) and calls `api.appendStep`. The server's refusal, if any, is
what the trainer sees.

### 4.4 The dialog gives up one field

`CreateCourseDialog` loses the per-step instruction control — the icon button
tooltipped „Zadatak za učenika" and the dialog behind it. Everything else about
it stays. An `instruction` that arrives **with** a position from the library is
data, not authoring: keep passing it through.

## 5. What gets this rejected

* **Validating a step in Dart.** §2. Send it; show the refusal.
* **Replacing the server's sentence** with „Čuvanje nije uspelo".
* **Building a step map from scratch** instead of carrying the stored one, or
  inventing an `id`.
* **A second preview renderer** instead of `LessonViewerScreen`, a second
  banner, a raw `ScaffoldMessenger`, or a second lesson service.
* **A preview that posts anything.**
* **Touching `chess_backend/`**, `lesson_api_service.dart`, or anything under
  `test/`.
* **Colour as the only difference between two things** — the owner is
  colourblind, and „which choice is the correct one" is exactly the place a tick
  is right and a green background is not.
* **New packages.** Nothing goes in `pubspec.yaml`.

## 6. How you will be judged

Machine-checked, in this order:

1. `flutter test` — **the 6 tests in `test/lesson_editor_test.dart` must pass**,
   and the whole suite must be at least **1340** passing with 1 skipped. The file
   does not currently load at all: it imports a widget that does not exist yet,
   which is the first thing you are building. Measure both numbers yourself.
2. `flutter analyze` — 29 issues, all `info`, all
   `curly_braces_in_flow_control_structures`. **It does not exit clean and never
   has.** Zero errors, zero warnings, no new infos.
3. `dart format` on every file you touched.
4. The `strings`, `idioms`, `contrast`, `scale` and `worktree` gates.

## 7. Your report

Not a summary. Numbers you computed in this run:

* `flutter test` before and after, both measured by you;
* the `flutter analyze` count and whether the list changed;
* every file you added a user-facing string to — this batch **does** add copy,
  so list them;
* **proof of the property, not the mechanism.** „Ids survive" is proved by
  reading the list the service was handed, which is what the gate does, not by
  saying you copied the map;
* **anything this brief got wrong.** Corrections are worth more than a clean
  report, and two of the last three batches found real errors here — including
  one where the gate itself was wrong and the batch changed the app to satisfy
  it. If a test looks like it can only be passed by changing something the brief
  calls finished, **say so and stop** rather than changing it.
