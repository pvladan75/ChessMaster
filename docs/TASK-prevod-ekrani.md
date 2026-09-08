# Task — English pivot, batch 1 of 3: screens and the home tabs

**This file plus `docs/brief-prevod-ekrani-2026-09.md` are the only context you
get. Do not rely on any conversation before them.** Read the brief first, then
`docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-ekrani`. Commit label: none — **do not commit.**

## What to do

Replace the Serbian user-facing string literals with English in these thirteen
files, and in the same edit update every test that asserts on the copy you
changed.

Do them in this order. Smallest first, so that running short of time leaves
finished files behind rather than thirteen half-done ones.

1. `chess_app/lib/screens/age_gate_screen.dart`
2. `chess_app/lib/widgets/home/biblioteka_tab.dart`
3. `chess_app/lib/screens/login_screen.dart`
4. `chess_app/lib/widgets/home/dashboard_tab.dart`
5. `chess_app/lib/widgets/home/friends_tab.dart`
6. `chess_app/lib/screens/home_screen.dart`
7. `chess_app/lib/screens/replay_player_screen.dart`
8. `chess_app/lib/screens/shortcuts_screen.dart`
9. `chess_app/lib/widgets/home/home_dialogs.dart`
10. `chess_app/lib/screens/design_gallery_screen.dart`
11. `chess_app/lib/screens/settings_screen.dart`
12. `chess_app/lib/screens/ai_studio_screen.dart`
13. `chess_app/lib/screens/chess_game_screen.dart`

After each file: run `flutter test` for the test files you touched, not the
whole suite. Run the whole suite once at the end.

## Method

* Work through one file at a time and finish it before starting the next.
* For each Serbian literal, decide whether it is **copy** (a user reads it) or a
  **value** (the server, a preference key, a tag, an enum on the wire). Only
  copy changes. The test: would the app still work if the server had never heard
  of this string? If yes, it is copy.
* Comments and `AppLogger` lines are not in scope and are not graded.
* Use the terms in `docs/GLOSSARY-EN.md` exactly. If a term there is wrong, say
  so in the report — do not quietly use a better word.
* Never write „Lesson" on a screen. The live thing is a **Session**.
* When a string changes, find every test asserting on it and change it in the
  same edit. `grep` the old text across `chess_app/test/`.
* Serbian plural helpers become English ones: two forms, not three.

## Rules

* Do not touch `chess_backend/`. Not one file.
* Do not touch anything under `chess_app/lib/features/` — batches 2 and 3.
* Do not move or edit the two anchors in `docs/gates/`.
* Do not delete a test, weaken an assertion, or relax a matcher to make
  something pass. If a test cannot be made green by translating it, stop and
  report it.
* Do not add a raw `ScaffoldMessenger`; messages go through `AppFeedback`.
* Do not commit, do not branch, do not `git add`.

## Done means

* `cd chess_app && flutter test` → **1772 passing, 1 skipped**.
* `cd chess_app && flutter analyze` → 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`.
* `dart format` clean on every file you touched.
* No Serbian letter (`čćžšđ ČĆŽŠĐ`) left in any string literal in the thirteen
  files.

## The report

Write it to `REPORT-prevod-ekrani.md` in the repository root. Numbers you
measured in this run, not a summary:

1. Test count before and after, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every test file you edited, and why.
5. Every place the Serbian said something English cannot say the same way — a
   plural, a case ending, a sentence that worked because of word order. These
   are the decisions and they are what the reviewer needs.
6. Anything this task or the brief got wrong. A correction is worth more than a
   clean report.
