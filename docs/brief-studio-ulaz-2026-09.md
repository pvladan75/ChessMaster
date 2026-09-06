# Brief: the way into the tutorial studio (batch 56)

Companion to [TASK-studio-ulaz.md](TASK-studio-ulaz.md). That file says what to
do; this one says why, what already exists, and what will bite.

## Why this job exists

A trainer writes a **tutorial** — a series of worked positions on one theme,
with a comment, arrows and questions — and a child walks it alone on one board.
The screen that writes it, `TutorialStudioScreen`, is built and merged.

There has been no way to *reach* it except one door inside the Analysis Studio,
which is a room for analysing rather than for writing. Worse, that door had a
fault the owner reported first: opening the studio to start something new came
up carrying the **last** tutorial — its name and all its finished parts. The
screen took an optional handover and loaded its one stored draft slot
unconditionally, so it had no idea what it was being opened for.

That is fixed. The screen now requires a `TutorialEntry` saying **why**. This
batch builds the front door that says it.

## What already exists — do not rebuild it

Read this before writing anything. All of it is merged and frozen.

* **`TutorialEntry`** — `lib/features/tutorial_studio/models/tutorial_entry.dart`.
  A sealed class with exactly three cases and no default:

  ```dart
  const TutorialEntry.blank(String title);
  const TutorialEntry.saved(Map<String, dynamic> lesson);
  const TutorialEntry.fromAnalysis(TutorialHandover h, {bool intoOpenDraft});
  ```

  They behave differently, and the differences are the point:

  | | what it does with the locally stored draft |
  |---|---|
  | `blank` | adopts nothing; if the slot holds work, the screen asks by name |
  | `saved` | adopts it **only** when its `lessonId` matches this lesson |
  | `fromAnalysis` | carries on with the open draft, unless `intoOpenDraft: false` |

* **`TutorialStudioScreen`** — `screens/tutorial_studio_screen.dart`. Takes
  `session`, `entry` (required) and an optional `lessonApi` test seam. You never
  edit it.
* **`isTutorialStudioAvailable`** — `tutorial_studio_availability.dart`. The one
  named predicate for „does this screen exist on this device", with a
  `debugTutorialStudioAvailable` override the gate uses. **Read it. Do not write
  `Platform.isWindows` a second time** — the point of the single home is that
  „which screens make sense on a phone" stays a one-line change later.
* **`LessonApiService.fetchAll()`** —
  `lib/features/lessons/services/lesson_api_service.dart`. Answers
  `Future<List<dynamic>>` with the trainer's saved rows, and **returns an empty
  list on any failure** — it feeds a list that is drawn either way. That matters
  to you: see „the rules that bite".
* **`HomeBibliotekaTab`** — `lib/widgets/home/biblioteka_tab.dart`. Three cards,
  stateless, every action a callback. It gains one `Widget? tutorialCard` field
  and draws it; it learns nothing about tutorials.
* **`AppFeedback`** — `lib/widgets/app_feedback.dart`. Every message goes
  through it and it cannot throw. Never call `ScaffoldMessenger` directly;
  `test/app_feedback_guard_test.dart` fails if one comes back.
* **The theme.** `context.colors`, `AppText`, `AppSpacing`, `AppRadii`. Copy the
  shape of the cards already in `biblioteka_tab.dart` — heading row with an
  icon, a sentence, then full-width buttons.

## What a row of the library looks like

`GET /lessons` returns everything the trainer has saved, and only some of it is
a tutorial:

```json
{ "id": 12, "title": "Opozicija",
  "position_list": [ { "id": "step0001", "fen": "...", "title": "Uvod",
                       "kind": "show" } ] }

{ "id": 13, "title": "Samo pozicija", "fen": "...", "position_list": null }
```

The first is a tutorial. The second is a diagram somebody saved, and opening the
studio on it opens a tutorial with no parts. **A row is a tutorial when
`position_list` is a `List` and is not empty** — nothing else.

## The rules that bite

**1. The whole row travels, not a summary of it.** `TutorialEntry.saved` takes
the `Map` and `TutorialDraft.fromLesson` reads `id`, `title` and `position_list`
off it. Passing `{'id': ..., 'title': ...}` loses every part. Passing the parts
without their `id` is worse and is silent: `assignment_items.step_key` and
`review_items.step_key` name a step by that id, **nothing joins on it**, so a
step whose id went missing takes a child's schedule and their recorded answers
with it and no error is raised anywhere.

**2. „Nothing saved" and „could not reach the server" are different sentences.**
`fetchAll` answers `[]` for both. A picker that shows „Nemate nijedan sačuvan
tutorijal." over a failed request tells the trainer their work is gone. Ask the
question yourself — the simplest honest way is to try the request and tell an
empty answer from a failure by whether the call threw or the list is genuinely
empty; if you cannot tell them apart with the service as it is, **say so in the
report** rather than guessing. The gate expects both sentences and they are
frozen in its header.

**3. A blank name opens nothing.** The tutorial must have a name before the
first save — the studio refuses an unnamed one — and learning that after twenty
minutes of writing is the expensive way. Trim before you judge: three spaces is
a blank name.

**4. Do the thing, then say it.** A message must never be able to take down the
action it reports on. This project has paid for that twice: a playback that
never started because a failing audio call sat in front of the timer, and a
recording that would not stop because `showSnackBar` threw first. Navigate, then
report; and report through `AppFeedback`, which cannot throw.

**5. A `Row` that does not fit is clipped in silence in a release build.** No
yellow stripes, no assertion — the buttons past the edge are simply unreachable.
Where a row can grow, use `Wrap`; where a width is fixed, take it from
`MediaQuery`. The existing cards use full-width buttons and are safe; copy them.

**6. Serbian is the users' language and the strings are frozen.** Every
user-facing string in this app is Serbian, because the users are Serbian
children and trainers. The exact strings this batch may add are listed in the
gate's header, and they belong in `tutorial_library_card.dart` and nowhere else.
A string landing in another file is a finding, not a warning.

## How it will be judged

By exit code, not by the report:

* **`chess_app/test/tutorial_ulaz_test.dart`** — fifteen tests, the contract.
  Copy it from `docs/gates/`; do not edit it.
* **`flutter test`** — every existing test still green, and the count up by
  exactly the fifteen you added.
* **`flutter analyze`** — the same list as before, and nothing newly suppressed.
  Holding a count steady by adding an `ignore_for_file` is a fail, not a pass; a
  previous batch did exactly that and it was caught by hand.
* **`dart format`** — clean on every file you touched.
* **the diff** — files outside the ones this brief names, and strings outside
  the one file, are findings.

## Out of scope, said once

* The studio's layout, the timeline panel, drawing arrows, and retiring the old
  step editor. Those are later phases with their own briefs.
* Renaming „Primer" to „Deo". Later phase.
* `chess_backend/` — frozen, and this needs nothing from it.
* Any change to `TutorialEntry`, `TutorialDraft`, `TutorialSection`,
  `TutorialStudioScreen`, `TutorialDraftService` or `tutorial_save.dart`. If you
  believe one of them has to change for this batch to work, **stop and say so in
  the report.** That is a contract problem and it is the lead's to fix.
