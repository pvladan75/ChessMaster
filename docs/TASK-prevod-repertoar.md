# Task — English pivot, batch 3 of 4: repertoire and the trainers

**This file plus `docs/brief-prevod-repertoar-2026-09.md` are the only context
you get. Do not rely on any conversation before them.** Read the brief first,
then `docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-repertoar`. **Do not commit.**

## What to do

Replace the Serbian user-facing string literals with English in these
twenty-six files, and in the same edit update every test that asserts on the
copy you changed.

In this order — smallest first:

1. `chess_app/lib/features/puzzle_trainer/puzzle_notifier.dart`
2. `chess_app/lib/features/repertoire/widgets/repertoire_position_ask.dart`
3. `chess_app/lib/features/training/widgets/resume_strip.dart`
4. `chess_app/lib/features/repertoire/screens/repertoire_walkthrough_screen.dart`
5. `chess_app/lib/features/repertoire/services/repertoire_api_service.dart`
6. `chess_app/lib/features/repertoire/widgets/unconfirmed_banner.dart`
7. `chess_app/lib/features/tactics_trainer/services/tactics_api_service.dart`
8. `chess_app/lib/features/endgame_trainer/models/endgame_puzzle.dart`
9. `chess_app/lib/features/repertoire/widgets/fork_repertoire_dialog.dart`
10. `chess_app/lib/features/repertoire/widgets/repertoire_gate_picker.dart`
11. `chess_app/lib/features/repertoire/services/walkthrough_speech.dart`
12. `chess_app/lib/features/repertoire/widgets/repertoire_comment_panel.dart`
13. `chess_app/lib/features/endgame_trainer/services/endgame_api_service.dart`
14. `chess_app/lib/features/endgame_trainer/screens/endgame_picker_screen.dart`
15. `chess_app/lib/features/endgame_trainer/services/holding_pattern.dart`
16. `chess_app/lib/features/repertoire/screens/repertoire_coverage_screen.dart`
17. `chess_app/lib/features/repertoire/widgets/repertoire_tree_panel.dart`
18. `chess_app/lib/features/repertoire/screens/repertoire_new_screen.dart`
19. `chess_app/lib/features/repertoire/widgets/breadth_dialog.dart`
20. `chess_app/lib/features/endgame_trainer/models/drill_step.dart`
21. `chess_app/lib/features/tactics_trainer/screens/tactics_trainer_screen.dart`
22. `chess_app/lib/features/endgame_trainer/screens/blunder_walk_screen.dart`
23. `chess_app/lib/features/repertoire/screens/repertoire_list_screen.dart`
24. `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart`
25. `chess_app/lib/features/endgame_trainer/screens/endgame_trainer_screen.dart`
26. `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart`

After each file, run the tests for the test files you touched. Run the whole
suite once at the end.

## Method

* One file at a time, finished before the next.
* For each Serbian literal decide **copy or value**. Only copy changes. API
  paths (`'$backendUrl/repertoire/drill/answer'`), JSON keys and anything
  compared against a server response are values and stay.
* Use the brief's vocabulary table exactly: branch, spine, breadth, coverage,
  unconfirmed move, queue, drill, sparring, endgame, draw, win, holds.
* Translate the **voice**, not only the nouns. These sentences were written
  plainly on purpose.
* `walkthrough_speech.dart` is spoken aloud by a voice, not printed. Write what
  a person would say; no abbreviations.
* `holding_pattern.dart` and `drill_step.dart` assemble sentences from pieces.
  Where Serbian conjugates to the number of moves, **rewrite the sentence**
  rather than reword it.
* Serbian plural helpers become English ones: two forms, not three.
* When a string changes, `grep` the old text across `chess_app/test/` and change
  every assertion on it in the same edit.
* Comments and `AppLogger` lines are not in scope.

## Rules

* Do not touch `chess_backend/`. Not one file.
* Do not touch anything under `chess_app/lib/` outside the twenty-six files —
  the analysis studio, `lib/widgets/`, `lib/core/` and `lib/services/` are the
  next batch.
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
* No Serbian letter (`čćžšđ ČĆŽŠĐ`) in any string literal in the twenty-six
  files.

## The report

Write it to `REPORT-prevod-repertoar.md` in the repository root. Numbers you
measured in this run:

1. Test count before and after, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every test file you edited, and why.
5. **Every sentence you rewrote rather than translated** — the assembled
   verdicts, the plurals, anything that only worked because of Serbian word
   order. The reviewer reads this first.
6. Every term in the brief's table that turned out wrong or missing.
7. Anything this task or the brief got wrong.

**Write only what you did.** Both previous reports had accurate numbers and one
invented section each — buttons that exist nowhere, and copy saying „Puzzle
session" that was never written. A short report that is entirely true is worth
more than a thorough one that is not.
