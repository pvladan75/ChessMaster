# Brief: the steps of a tutorial can finally be rearranged

Companion to [TASK-tutorijal-koraci.md](TASK-tutorijal-koraci.md). That file is
the instruction; this one is why the job exists and what will judge it.

## Why

A **tutorijal** is a series of worked examples a trainer writes and a child
walks through alone. The trainer's editor — `LessonStepEditorPanel` — can pick a
step and change what it says, what it asks and what the answer is. It cannot add
a step, remove one, or move one.

So a trainer who realises the third example should come first has one option:
rebuild the tutorial. And a trainer who wants one more example has to leave the
editor entirely, find the position in the Analysis Studio, and use „Napravi
korak od ove pozicije", which appends to the end and sends them back through a
course picker.

This batch is the last piece of the authoring side. After it, phase 5 is the
owner watching all of it run.

## The rule that will bite you, and it is the whole batch

**A step's `id` is its identity, and nothing joins on it.**

Two tables name steps by that value: `assignment_items.step_key` and
`review_items.step_key`. They are not foreign keys. There is no constraint, no
cascade, and no error. So an id that changes is a child's spaced-repetition
schedule and a child's recorded answers pointing at a step that no longer
exists — silently, discovered weeks later if at all.

`buildLessonStep` in `chess_backend/services/lessonSteps.js` says it in as many
words: *„an id quietly regenerated is a student's schedule quietly orphaned,
with no error anywhere."*

The server has a guard against this — `PUT /lessons/:id` answers **409 „Koraci
su stigli bez svojih oznaka"** when a client sends back a list that has lost its
ids. **Read the condition, because it matters to you:**

```js
storedList.length > 0
&& storedList.length === steps.length     // <- this line
&& storedList.some(hasId)
&& !(positionList || []).some(hasId)
```

It requires the stored list and the sent list to be **the same length**. Adding
a step or removing one changes the length, so for two of the three operations in
this batch **the guard is skipped entirely** and whatever you send is written.
There is no safety net under add and remove except the gate and your own care.

What follows from that, concretely:

* a **new** step is sent with **no `id` key at all** — `buildLessonStep`
  generates one, and an id you invent is either refused (it must match
  `^[A-Za-z0-9_-]{1,16}$`) or, worse, a collision;
* **never** create a new step by copying the map of the step beside it.
  `assignment_items` has a UNIQUE index on `(assignment_id, step_key)`, so two
  steps sharing an id is not cosmetic;
* a **move** rearranges the list and touches nothing inside any step;
* a **removal** drops exactly one id and leaves every other step untouched.

**The child's side already survives a deletion**, and this was checked in the
code rather than assumed: `getDue` in `spacedRepetitionService.js` resolves a
review row through `stepByKey` and ends with
`.filter((item) => item.step !== null)`, so a row naming a deleted step stops
appearing rather than serving a board nobody wrote. **That is why this batch
needs no backend change, and the task forbids one.**

## What already exists — do not rebuild it

* **`LessonStepEditorPanel`** (`lib/features/lessons/widgets/`) — a list of
  steps on the left, and on the right the selected step's instruction, kind,
  choices, answer board and a „Pregled" that runs the student's screen without
  judging. `_steps` is a `List<Map<String, dynamic>>`; `_selectedIndex` picks
  one; `_loadStep()` fills the controllers; `_save()` sends `_steps` as
  `positionList`. You are adding to this, not replacing it.
* **`LessonApiService.update`** — merged and frozen. It omits `positionList`
  from the body when it is null, which is what makes a rename safe; you always
  send it, because you are changing the steps.
* **The panel already refuses one thing** — a step that asks for a move while
  carrying a line, because the line is not redacted on its way to the child.
  Leave that alone; a step you *add* has no line, so it cannot trip it.

## Four decisions, already made

You do not get to reopen these; they are frozen in the gate's header.

1. **Up and down, not drag.** `ReorderableListView` is the prettier answer and a
   trainer with twelve steps would want it. It is also the gesture that is hard
   to drive in a test and easy to get subtly wrong, and this batch is the
   mechanical one. Drag is a separate, later decision.
2. **The panel gains a title field.** Without it, three added steps all reach
   the server as „Pozicija" — what `buildLessonStep` writes when the title is
   missing — and the trainer cannot tell them apart in the very list this batch
   is about.
3. **A new step inherits the selected step's position and nothing else.** The
   position is deliberate: a question about the board that was just shown is the
   „show, then ask" shape the child's screen joins without reloading. The kind,
   the instruction and the answer are not inherited.
4. **The last step cannot be removed.** `PUT` writes `position_list = NULL` for
   an empty list, so a tutorial emptied here loses its steps with nothing left
   to join on and complain. Refuse it, in a sentence, without even asking.

## Rules that bite on this codebase

* **The repository is public.** No secrets, IP addresses, email addresses or
  account identifiers in code, comments or docs.
* **User-facing strings stay Serbian**, and the frozen vocabulary is
  „Tutorijal" for the artefact and „Čas" for the live session in a room. Never
  „lekcija", never „kurs" — a gate test fails if either comes back. Code
  comments and your report are English.
* **`flutter analyze` does not exit clean** — 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Zero errors, zero warnings, **no
  new infos**, and **nothing newly silenced**: no `// ignore_for_file:`, no
  `// ignore:`. The previous batch held the count at 29 by hiding three real
  deprecations and its report called that adequately resolved. Compare the list;
  and if a deprecation appears, fix it (this codebase uses `RadioGroup<int>` and
  `DropdownButtonFormField(initialValue:)`, both non-deprecated).
* **Run `dart format` on every Dart file you edit.** Run it; do not report it as
  run — two batches on this project have reported it and had not.
* **Do the thing, then say it**, and say it through `AppFeedback`, which cannot
  throw. A source-reading test fails if a raw `ScaffoldMessenger` call appears.
* **A release build paints no overflow warning.** Four new controls on one row
  above a list is exactly the shape that gets clipped in silence. Use `Wrap`
  where a row can grow.

## Baselines, to measure yourself

`cd chess_app && flutter test` reads **1421 passing, 1 skipped**.
`flutter analyze` reads **29 infos**. The skip is a golden-screenshot group,
skipped unconditionally in `dart_test.yaml`; leave it alone.

Measure both yourself before you start. A number quoted at you is a number
somebody else measured on a different tree.

## How it will be judged

By machine, against `docs/gates/lesson_step_order_test.dart`, which the lead
copies into `chess_app/test/` and runs on your tree. Twelve tests, and **all
twelve are red on the current panel** — measured, not assumed. The file compiles
against the tree as it is, so there is nothing to unblock before you begin.

| test | what it demands |
|---|---|
| the ids travel with their steps, in the new order | a move rearranges, it does not rebuild |
| everything else about the moved step is byte-identical | the kind, the answer and the sentence travel with it |
| the selection follows the step, not the slot | you are still editing the step you moved |
| the ends do not offer a move that has nowhere to go | both buttons disabled at their end |
| it goes out with no id, so the server mints one | the one the 409 guard cannot catch |
| it lands after the step it was added from, and is selected | insertion point and selection |
| it is empty of everything it did not inherit | position only — no kind, answer, instruction or pgn |
| it asks first | a delete is not undoable and may cost a child's answer |
| saying no keeps it | the dialog's „Odustani" means it |
| saying yes drops exactly that id | and disturbs no other |
| the last step is refused, and nothing is sent | no dialog, no empty list |
| add, move and delete are all still local | „Sačuvaj korak" is the only write |

And two files must stay green **unchanged**: `test/lesson_editor_test.dart` and
`test/lesson_answer_stays_hidden_test.dart`. If one has to be edited for your
work to pass, that is a finding, not a chore.

Your report is not the verdict. Those three files are.

## What the comparison is about

This batch is being run to compare a model, and the comparison is on named
things rather than impressions: **did you actually run `dart format`, do the
numbers in your report match the lead's own measurement, did you silence
anything, and did you ship a comment written to yourself rather than to the next
reader.** None of that is about capability. Say what you measured and what you
did not.

## Out of scope

* `chess_backend/`. Frozen, already done, not yours, and this batch needs none.
* Drag-and-drop reordering.
* `TutorialStudioScreen` and everything under `lib/features/tutorial_studio/`.
* Renaming the tutorial itself, or saving it as a new version — those exist
  already, elsewhere in the app.
* The step's `pgn`. No operation here writes or clears a line.
