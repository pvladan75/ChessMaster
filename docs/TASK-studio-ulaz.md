# Task: the way into the tutorial studio

A bounded job for an outside agent. **This file plus
[brief-studio-ulaz-2026-09.md](brief-studio-ulaz-2026-09.md) are the only
context you get** — do not rely on any conversation before them.

Branch: `batch/studio-ulaz`. Commit as
`batch 56 — ulaz u studio: nov tutorijal i otvaranje sačuvanog`.
**Do not commit.** Leave the worktree dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/features/tutorial_studio/models/tutorial_entry.dart` and
`chess_app/lib/widgets/home/biblioteka_tab.dart` both exist. If either does not,
**stop and say so**.

## What is asked

Flutter only, in `chess_app/lib/`, against a model and a screen that are
**already built, merged and frozen**. Four things:

1. **A new widget**,
   `lib/features/tutorial_studio/widgets/tutorial_library_card.dart`, holding a
   `TutorialLibraryCard` and a top-level `askTutorialDestination` function. It
   draws itself only where `isTutorialStudioAvailable` says the studio exists,
   and it owns both of its dialogs and every string this batch adds.
2. **„Novi tutorijal"** — asks for a name, then opens `TutorialStudioScreen`
   with `TutorialEntry.blank(name)`. A blank name opens nothing.
3. **„Otvori sačuvani tutorijal"** — reads the library, offers the rows that are
   tutorials, and opens the picked one with `TutorialEntry.saved(row)`.
4. **The Analysis Studio's door asks a second question** — into the tutorial
   being written, or into a new one — and passes the answer through as
   `intoOpenDraft`.

Plus the two lines of wiring that put the card on the screen:
`HomeBibliotekaTab` gains one `Widget? tutorialCard` field and draws it;
`home_screen.dart` passes `TutorialLibraryCard(session: ...)`.

**Nothing else.** Do not touch `chess_backend/` — it is frozen and this batch
needs no change there. Do not change anything else under
`lib/features/tutorial_studio/`: the model, the screen and the services are
frozen. Do not rename „Primer" to „Deo" anywhere — that is a later phase.

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of `docs/gates/tutorial_ulaz_test.dart`.**
Read that header first — all of it — and treat it as the specification. It gives
the widget's constructor, every string, what each action does, and why.

The four that will cost you if you get them wrong:

* **`TutorialEntry.blank` for a new tutorial, `TutorialEntry.saved` for an
  existing one, and never anything else.** Those two cases behave differently on
  purpose — see the brief. Opening a new tutorial with the wrong one brings back
  the last tutorial's parts, which is the bug this whole phase exists to remove.
* **The whole library row travels into `TutorialEntry.saved`**, not just its
  title or its id. `TutorialDraft.fromLesson` reads `id`, `title` and
  `position_list` off it, and a step that arrives without its `id` orphans a
  child's schedule.
* **Only rows whose `position_list` is a non-empty `List` are tutorials.**
  `GET /lessons` also returns plain saved positions.
* **`isTutorialStudioAvailable` is read, never rewritten.** A second
  `Platform.isWindows` anywhere in `lib/` is a finding.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the list — not the count, the **list**.
3. Copy `docs/gates/tutorial_ulaz_test.dart` to
   `chess_app/test/tutorial_ulaz_test.dart`. It does **not** compile against the
   tree as it is, because it names the widget you are about to write. That is
   the shape it should have before you start.
   **Do not edit that file**, except to run `dart format` on it, which is
   expected. If you believe a test in it is wrong, **stop and say so in the
   report** — do not work around it. A workaround that satisfies a test without
   satisfying the rule is worth less than a stopped batch.
4. Build the four things above until all fifteen of its tests are green.
5. `dart format` every Dart file you touched. Run it; do not report it as run.
6. `flutter test` and `flutter analyze` again. The suite must be **higher** by
   the fifteen tests you added and lower by none; the analyzer list must be the
   same list, with **nothing new suppressed** — no new `// ignore:` and no new
   `ignore_for_file`.

## The report

`REPORT-batch-56.md`, in the repository root. It must contain:

* the test count **before and after**, both measured by you in this run;
* the analyzer list before and after, item by item, and the word „identical" or
  the difference;
* whether you added any `// ignore:` or `ignore_for_file` — say it in a line of
  its own, even if the answer is no;
* the exact list of files you changed or added;
* **proof of the property, not the mechanism**: quote the `TutorialEntry`
  subtype and its payload that each of the two buttons produced in your own run,
  read out of the constructed `TutorialStudioScreen`. „It calls
  `TutorialEntry.saved`" is not proof that the row arrived whole;
* anything this task or the brief got wrong. A correction is worth more to us
  than a clean report.
