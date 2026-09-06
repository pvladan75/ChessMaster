# Task: edit, rename, or save a tutorial as a new version

A bounded job for an outside agent. **This file plus
[brief-tutorijal-verzije-2026-09.md](brief-tutorijal-verzije-2026-09.md) are the
only context you get** — do not rely on any conversation before them.

Branch: `batch/tutorijal-verzije`. Commit as
`batch 53 — tutorijal: uredi, preimenuj, sačuvaj kao novu verziju`. **Do not
commit.** Leave the worktree dirty; the lead reads the diff.

Run this only on a tree that already has batch 51 (the vocabulary) merged.

## What is asked

Flutter only, in `chess_app/lib/`, against a backend that is **already built,
merged and frozen**. Three actions on a saved tutorial, wherever the trainer's
list of them is shown:

1. **Uredi tutorijal** — opens `LessonStepEditorPanel`, which already exists and
   already edits a step's sentence, kind, choices and answer. You wire the
   action; you do not rewrite the panel.
2. **Preimenuj** — a small dialog with the title, saved with
   `LessonApiService.update` and **no `positionList`**. The server leaves the
   steps alone when the request says nothing about them; sending an empty list
   instead would destroy every step, silently.
3. **Sačuvaj kao novu verziju** — `LessonApiService.clone`, then open the copy.
   The original must come out untouched. This is how a trainer makes an easier
   or harder version of the same material for a different group.

**Nothing else.** Do not touch `chess_backend/` — it is frozen and the endpoint
you need is already there. Do not change `LessonStepEditorPanel`'s fields, and
do not add step add/remove/reorder — that is a later batch.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

Already merged and not yours to change:

```dart
// lib/features/lessons/services/lesson_api_service.dart
Future<int?> clone({required int id, String? title});
String? cloneError;   // why the last clone returned null
```

`clone` returns the **new tutorial's id**, or null with the reason in
`cloneError`. A null `title` means the server names it `naslov (kopija)`.

```
POST /lessons/:id/clone   { title? }
 201 { ...the new row, including id }
 400 { error }   unparseable id
 404 { error }   not found, or not yours
```

Every copied step gets a fresh id on the server. You do not send steps.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the list.
3. Find where saved tutorials are listed for a trainer and put the three actions
   there. Name the file you chose in the report and say why.
4. Write widget tests for all three. In particular: **a rename must send no
   `positionList`** — assert on the request body, not on the screen.
5. `dart format` every file you touch.
6. `flutter test` and `flutter analyze` after. Both numbers in the report.

## What the report must contain

Write it to `docs/REPORT-batch-53.md`.

* the test count before and after, both measured by you in this run;
* the analyzer list before and after — whether it changed, not just how many;
* which screen you put the three actions on, and why that one;
* the exact request body your rename sends — copied from a test, not described;
* anything the brief got wrong. A correction is worth more than a clean report.
