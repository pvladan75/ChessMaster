# Task: the fields, the running list, and the one save

A bounded job for an outside agent. **This file plus
[brief-tutorijal-studio-2026-09.md](brief-tutorijal-studio-2026-09.md) are the
only context you get** — do not rely on any conversation before them.

Branch: `batch/tutorijal-studio`. Commit as
`batch 54 — tutorijal: polja, lista primera i jedno čuvanje`. **Do not commit.**
Leave the worktree dirty; the lead reads the diff.

Run this only on a tree that already has phase 4a merged — the file
`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
must exist. If it does not, **stop and say so**.

## What is asked

Flutter only, in `chess_app/lib/`, against a backend that is **already built,
merged and frozen**. You finish one screen that already opens, already has a
board and a move tree, and already keeps a draft. Four things:

1. **The fields for the example being written** — the sentence for the node the
   trainer is standing on, the task, the kind, the offered answers, the answer.
2. **The running list** — Primer 1, Primer 2, … with
   „+ Dodaj sledeću poziciju u tutorijal" under it.
3. **One „Sačuvaj tutorijal"** at the end, which sends the whole tutorial in a
   single `POST /lessons/save`.
4. **A seam so a test can watch that request:** a named parameter `lessonApi`
   on `TutorialStudioScreen`, defaulting to
   `LessonApiService(authToken: session.token)`.

They go in `_authoringColumn`, which exists and whose doc comment says what
belongs there and in what order.

**Nothing else.** Do not touch `chess_backend/`. Do not add, remove or reorder
steps inside `LessonStepEditorPanel` — that is a later batch. Do not build a
second board, a second move tree or a second cursor; the ones on the screen are
the ones you use.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of `docs/gates/tutorial_authoring_test.dart`.**
Read that header first — all of it — and treat it as the specification. It
names every control, every key, every label, and the four rules that were
decided before this batch started.

The three that are easiest to get wrong, repeated here so they are not missed:

* **The sentence is per node. The task, the kind, the offered answers and the
  answer are per example.** A kind written onto every node is a second model of
  what a lesson step is.
* **„+ Dodaj sledeću poziciju" starts the next example on the position the last
  line ended at** — the end of the main line — and saves nothing.
* **An example that asks for a move carries no line.** The correct move is
  played on the same board, recorded, and the board goes back to the position.
  An example that has both a line and „Traži potez na tabli" is refused before
  the save. The reason is in the brief; it is not a matter of taste.

The wire shape is already built and is not yours to change:

```dart
// lib/features/tutorial_studio/models/tutorial_draft.dart
class TutorialExample { … Map<String, dynamic> toJson(); }
class TutorialDraft   { … List<Map<String, dynamic>> get positionList; }
```

`TutorialDraft.positionList` is what goes into the save. Build the body from it;
do not assemble a second one beside it.

```dart
// lib/features/lessons/services/lesson_api_service.dart
Future<String?> save({
  required String title, String? description, List<String>? tags,
  String? fen, String? pgn, List<Map<String, dynamic>>? positionList,
});
```

Returns `null` on success, or the server's own sentence on failure. **Pass the
server's sentence on to the trainer** — replacing it with „Čuvanje nije uspelo"
throws away the only part that helps.

An example's `fen` and `pgn` come from `StudioLessonStep.from(node)` and from
nowhere else. That class exists so the two cannot come from different places,
which they used to.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the list — not the count, the list.
3. Copy `docs/gates/tutorial_authoring_test.dart` to
   `chess_app/test/tutorial_authoring_test.dart` and run it. It will not
   compile until you add the `lessonApi` seam; after that **ten of the eleven
   are red**. The eleventh — „the save is written once, in one place" — is green
   today only because nothing saves at all, and it has to stay green.
   **Do not edit that file.** If you believe a test in it is wrong, say so in
   the report and leave it as it is — a gate you edited has stopped being a
   gate.
4. Build until all eleven are green.
5. `test/tutorial_studio_test.dart` must stay green **unchanged**. If a test in
   it has to be edited to make your work pass, that is a finding — write it in
   the report and stop.
6. Add your own tests for anything you had to decide that the gate does not
   reach. Put them in **one** file, `chess_app/test/tutorial_studio_fields_test.dart`
   — named here so that a second new file is still a stray the harness can see.
   Not decoration: **no test with no assertions in it, and never mute
   `FlutterError.onError`.** A previous batch did both, and its own test stayed
   green over a real 91 px overflow that a release build clips in silence.
7. `dart format` every Dart file you touch. Actually run it; do not report it as
   run.
8. `flutter test` and `flutter analyze` after. Both results in the report.

## What the report must contain

Write it to `docs/REPORT-batch-54.md`, under exactly that name.

* the test count before and after, both measured by you in this run;
* the analyzer list before and after — whether it changed, not just how many;
* the eleven gate tests, each with the change that made it green;
* the exact request body your save sends, **copied out of a test run**, not
  described;
* where you put the fields and the list, and how the screen behaves at 1200 dp
  and at 840 dp;
* anything this task or the brief got wrong. A correction is worth more than a
  clean report.
