# Task — English pivot, batch 2 of 3: the tutorial, lessons and assignments

**This file plus `docs/brief-prevod-tutorijal-2026-09.md` are the only context
you get. Do not rely on any conversation before them.** Read the brief first,
then `docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-tutorijal`. **Do not commit.**

## What to do

Replace the Serbian user-facing string literals with English in these
twenty-one files, and in the same edit update every test that asserts on the
copy you changed.

In this order — smallest first:

1. `chess_app/lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart`
2. `chess_app/lib/features/tutorial_studio/widgets/tutorial_pgn_panel.dart`
3. `chess_app/lib/features/tutorial_studio/services/tutorial_draft_service.dart`
4. `chess_app/lib/features/assignments/widgets/assignment_detail_gate.dart`
5. `chess_app/lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart`
6. `chess_app/lib/features/assignments/widgets/assign_lesson_dialog.dart`
7. `chess_app/lib/features/assignments/widgets/create_assignment_dialog.dart`
8. `chess_app/lib/features/assignments/screens/custom_assignment_overview_screen.dart`
9. `chess_app/lib/features/assignments/screens/lesson_viewer_screen.dart`
10. `chess_app/lib/features/assignments/screens/my_assignments_screen.dart`
11. `chess_app/lib/features/assignments/services/assignment_api_service.dart`
12. `chess_app/lib/features/assignments/widgets/parent_report_dialog.dart`
13. `chess_app/lib/features/assignments/widgets/trainer_student_archive_view.dart`
14. `chess_app/lib/features/lessons/services/lesson_api_service.dart`
15. `chess_app/lib/features/assignments/screens/custom_puzzle_solver_screen.dart`
16. `chess_app/lib/features/assignments/models/assignment.dart`
17. `chess_app/lib/features/assignments/screens/assignment_review_screen.dart`
18. `chess_app/lib/features/assignments/screens/student_progress_screen.dart`
19. `chess_app/lib/features/lessons/widgets/lesson_step_editor_panel.dart`
20. `chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`
21. `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`

After each file, run the tests for the test files you touched. Run the whole
suite once at the end.

## Method

* One file at a time, finished before the next.
* For each Serbian literal decide **copy or value**. Only copy changes. The
  test: would the app still work if the server had never heard of this string?
  If yes it is copy. `'show'`, `'ask_move'`, `'ask_choice'`, status values, API
  paths and JSON keys are values and stay.
* Use the glossary's terms exactly. **„čas" is a Session. „tutorijal" is a
  Tutorial. „Lesson" never appears on a screen.**
* The copy addresses a player, a student and a trainer — not a child. „Child"
  survives only where the feature is explicitly about parental supervision,
  which in this batch means `parent_report_dialog.dart`.
* When a string changes, `grep` the old text across `chess_app/test/` and change
  every assertion on it in the same edit.
* Two test files need attention beyond string swaps, and both will fail loudly
  if you skip them: `test/screen_names_test.dart` allows `'Studio za
  tutorijal'` by name, and `test/tutorial_vocabulary_test.dart` names Serbian
  strings per file in its `_expected` table.
* Serbian plural helpers become English ones: two forms, not three.
* Comments and `AppLogger` lines are not in scope.

## Rules

* Do not touch `chess_backend/`. Not one file.
* Do not touch anything under `chess_app/lib/` outside the twenty-one files.
* Do not move or edit the anchors in `docs/gates/`.
* Do not delete a test, weaken an assertion, or relax a matcher to make
  something pass. If a test cannot be made green by translating it, stop and
  report it.
* Do not add a raw `ScaffoldMessenger`; messages go through `AppFeedback`.
* Do not commit, branch, or `git add`.

## Done means

* `cd chess_app && flutter test` → **1774 passing, 1 skipped**.
* `cd chess_app && flutter analyze` → 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`.
* `dart format` clean on every file you touched.
* No Serbian letter (`čćžšđ ČĆŽŠĐ`) in any string literal in the 21 files.

## The report

Write it to `REPORT-prevod-tutorijal.md` in the repository root. Numbers you
measured in this run:

1. Test count before and after, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every test file you edited, and why.
5. **Every place you had to choose between Tutorial and Session, and what
   decided it.** This is the batch's whole risk; the reviewer reads it first.
6. Every place the Serbian said something English cannot say the same way.
7. Anything this task or the brief got wrong.

**Write only what you did.** The previous batch's report described updating
matchers for buttons that exist nowhere in the repository. It was invented, in
a report that was otherwise accurate, and it cost an hour to disprove.
