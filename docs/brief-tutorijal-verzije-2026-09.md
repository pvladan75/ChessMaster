# Brief: versions of a tutorial

Companion to [TASK-tutorijal-verzije.md](TASK-tutorijal-verzije.md). That file
is the instruction; this one is why the job exists and what will judge it.

## Why

A **tutorijal** is a series of worked examples a trainer writes and a child
walks through alone. Trainers teach the same material to groups of different
strength, so the ask is simple and concrete: keep one tutorial, and make an
easier or a harder version of it for another group — **without touching the
original**, which is already assigned to children who are working through it.

Today a trainer can create and delete a tutorial and nothing else. There is no
rename that is safe, and no way to copy one.

## What already exists

* **`LessonStepEditorPanel`** (`lib/features/lessons/widgets/`) — the trainer's
  step editor: the ordered steps, and for the selected one its sentence, its
  kind (`show` / `ask_move` / `ask_choice`), its choices, and the correct move
  played on a board. It has a „Pregled" that runs the student's screen without
  judging anything. It is finished for this batch; you open it, you do not
  rewrite it.
* **`LessonApiService`** (`lib/features/lessons/services/`) — `fetchAll`,
  `save`, `update`, `delete`, `appendStep`, and now `clone`.
* **`POST /lessons/:id/clone`** — merged, tested, frozen. It copies the title,
  description, tags, fen, pgn and every step, **mints a fresh id for every
  copied step**, and never writes to the source row. The copy belongs to
  whoever asked for it.

## The one rule that will bite you

**A rename must send no `positionList`.**

`PUT /lessons/:id` distinguishes „leave the steps alone" from „there are none
now" by whether the request *mentions* `positionList` at all. Sending an empty
list writes `position_list = NULL` — every step of the tutorial gone, silently,
with nothing logged and nothing joining on them to complain.

This is not hypothetical. The app already had a rename that did exactly this,
and the only reason no data was lost is that the caller happened never to hand
it a tutorial with steps. `lesson_rename_keeps_steps.test.js` exists on the
server because of it. Your rename gets its own test on this side: assert the
**request body**, not the screen.

There is a second guard on the same route: a step list that comes back with
every id stripped is refused with 409 and the message „Koraci su stigli bez
svojih oznaka…". If you see that, you have read a tutorial, dropped the ids and
sent it back — read the ids and keep them.

## Rules that bite on this codebase

* **The repository is public.** No secrets, IP addresses, email addresses or
  account identifiers in code, comments or docs.
* **User-facing strings stay Serbian**, and the frozen vocabulary is
  „Tutorijal" for the artefact and „Čas" for the live session in a room. Never
  „lekcija" and never „kurs" — batch 51 removed both and a gate test fails if
  either comes back. Code comments and your report are English.
* **`flutter analyze` does not exit clean** — 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Zero errors, zero warnings, **no
  new infos**: compare the list, not the exit code.
* **Run `dart format` on every Dart file you edit.**
* **A message must never take down the action it reports on.** Do the thing,
  then say it, and say it through `AppFeedback` — a source-reading test fails if
  a raw `ScaffoldMessenger` call comes back. That means: clone first, then the
  snackbar, then open the copy.
* **A release build paints no overflow warning.** Three actions on a row on a
  360 dp phone is exactly the shape that gets clipped silently. Use `Wrap`, or a
  menu, and test at `Size(360, 640)` where the overflow does throw.

## Baselines, to measure yourself

`cd chess_app && flutter test` reads **1372 passing, 1 skipped** on the base
commit plus whatever batch 51 added. The skip is a golden-screenshot group,
skipped unconditionally in `dart_test.yaml`; leave it alone.

## How it will be judged

There is no pre-written gate file for this batch. What is checked instead:

1. **The rename's request body**, read out of your own test. No `positionList`
   key at all — not an empty list, not null.
2. **The clone opens the copy, not the original.** A test that asserts the id
   the screen navigates to is the one the lead will look for.
3. **`flutter test` count up by at least three**, and the analyzer list
   unchanged.
4. **The 360 dp layout**, because a third action is what pushes a row over.
5. The vocabulary gate from batch 51 still green — no „lekcija", no „kurs" in
   anything you add.

Your report is not the verdict. Those five are.

## Out of scope

* `chess_backend/`. Frozen, already done, not yours.
* Adding, removing or reordering steps inside `LessonStepEditorPanel` — a later
  batch.
* The new authoring screen (`TutorialStudioScreen`) — a later batch.
* Any migration of the stored tag value `'lekcija_kurs'`. It is data, it stays,
  and it is the lead's job if it ever moves.
