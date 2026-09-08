# Task — English pivot, batch 65b: the archive, the shared widgets and the services

**This file plus `docs/brief-prevod-ostatak-2026-09.md` are the only context you
get. Do not rely on any conversation before them.** Read the brief first, then
`docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-ostatak`. **Do not commit.**

This is the **last** translation batch. When it lands, the app has no Serbian
user-facing copy left.

## What to do

Replace the Serbian user-facing string literals with English in these fifty-five
files, and in the same edit update every test that asserts on the copy you
changed. Then delete `serbian_plural.dart` and its two tests, as below.

In this order — smallest first:

1. `chess_app/lib/core/build_info.dart`
2. `chess_app/lib/core/models/move_cursor.dart`
3. `chess_app/lib/core/services/eval_cache.dart`
4. `chess_app/lib/core/services/local_puzzle_extractor_service.dart`
5. `chess_app/lib/features/archive/services/archive_api_service.dart`
6. `chess_app/lib/features/library/models/library_entry.dart`
7. `chess_app/lib/models/recording_models.dart`
8. `chess_app/lib/screens/age_gate_screen.dart`
9. `chess_app/lib/services/app_settings_service.dart`
10. `chess_app/lib/services/speech_service.dart`
11. `chess_app/lib/services/stockfish_service_native.dart`
12. `chess_app/lib/widgets/engine_line_dialog.dart`
13. `chess_app/lib/widgets/game_screen/branch_choice_sheet.dart`
14. `chess_app/lib/widgets/game_selector_dialog.dart`
15. `chess_app/lib/features/archive/screens/player_profile_screen.dart`
16. `chess_app/lib/features/trainer_panel/services/trainer_panel_api_service.dart`
17. `chess_app/lib/services/account_standing_service.dart`
18. `chess_app/lib/services/local_recording_service.dart`
19. `chess_app/lib/services/oauth_pkce.dart`
20. `chess_app/lib/theme/arrow_colors.dart`
21. `chess_app/lib/theme/board_skins.dart`
22. `chess_app/lib/widgets/account_stats_card.dart`
23. `chess_app/lib/widgets/desktop_shortcuts.dart`
24. `chess_app/lib/widgets/game_screen/board_annotation_bar.dart`
25. `chess_app/lib/widgets/game_screen/course_step_bar.dart`
26. `chess_app/lib/widgets/game_screen/move_navigation_controls.dart`
27. `chess_app/lib/widgets/parent_email_dialog.dart`
28. `chess_app/lib/widgets/pgn_import_dialog.dart`
29. `chess_app/lib/widgets/promotion_picker.dart`
30. `chess_app/lib/widgets/speakable_info.dart`
31. `chess_app/lib/features/archive/screens/archive_home_screen.dart`
32. `chess_app/lib/features/library/widgets/course_picker_dialog.dart`
33. `chess_app/lib/features/reviews/services/review_api_service.dart`
34. `chess_app/lib/features/trainer_panel/models/trainer_panel.dart`
35. `chess_app/lib/routing/app_router.dart`
36. `chess_app/lib/widgets/matrix_filter_panel.dart`
37. `chess_app/lib/services/engine_download_service.dart`
38. `chess_app/lib/widgets/engine_settings_dialog.dart`
39. `chess_app/lib/features/archive/screens/archive_import_screen.dart`
40. `chess_app/lib/services/desktop_google_sign_in_io.dart`
41. `chess_app/lib/services/server_status_service.dart`
42. `chess_app/lib/widgets/save_position_dialog.dart`
43. `chess_app/lib/widgets/share_position_dialog.dart`
44. `chess_app/lib/widgets/stockfish_analysis_widget.dart`
45. `chess_app/lib/services/billing_service.dart`
46. `chess_app/lib/features/archive/screens/repertoire_diff_screen.dart`
47. `chess_app/lib/features/archive/widgets/import_counters.dart`
48. `chess_app/lib/features/reviews/screens/review_session_screen.dart`
49. `chess_app/lib/features/library/widgets/position_picker_dialog.dart`
50. `chess_app/lib/features/trainer_panel/widgets/trainer_panel_view.dart`
51. `chess_app/lib/widgets/create_course_dialog.dart`
52. `chess_app/lib/features/archive/screens/opening_leak_report_screen.dart`
53. `chess_app/lib/features/groups/screens/groups_screen.dart`
54. `chess_app/lib/features/groups/widgets/room_guests_dialog.dart`
55. `chess_app/lib/features/archive/screens/mistake_drill_screen.dart`

**Run the whole suite once, at the end.** Do not run it per file. You may run a
single test file when you have a specific reason to.

## The deletion, after the fifty-five files are done

`lib/core/services/serbian_plural.dart` has no caller left in `lib/`. Delete it
and its two tests:

```
chess_app/lib/core/services/serbian_plural.dart
chess_app/test/serbian_plural_test.dart
chess_app/test/serbian_plural_screens_test.dart
```

First run `grep -rn "serbian_plural\|serbianPlural" chess_app/lib`. If it finds a
caller, **stop and report it** instead of deleting. **Count how many tests those
two files hold before you delete them** — you must report that number, because it
is the only reason the suite count is allowed to fall.

## Method

* One file at a time, finished before the next.
* For each Serbian literal decide **copy or value**. Only copy changes. API
  paths, JSON keys, entitlement ids, the material keys in `mistake_drill_screen`
  (`KPRkpr`, `KRkr`, `KPk`, `KQkq`, `KBNk`, …), `'w'`/`'b'` and anything
  compared against a server response are values and stay.
* **Log lines ARE in scope in this batch** — the gate reads them. Keep the
  bracketed tag (`[Billing]`, `[Reviews]`, `[Panel]`, `[EvalCache]`,
  `[ServerStatus]`, `[StockfishService]`) and every interpolation exactly, and
  translate the sentence plainly. Comments are still out of scope.
* Use the brief's vocabulary table exactly: Session, assignment, room, Trainer,
  observer, guest, review, due, deviation, opening leak, endgame, marks,
  entitlements, sign-in.
* Six of your files appear in `test/tutorial_vocabulary_test.dart`'s frozen
  table — update **only** those six entries, and leave every other entry alone.
* Colour and skin names use the plain colour word (`Orange`, `Purple`,
  `Classic`), never a decorative one. Two entries both becoming `Classic` in
  `board_skins.dart` is correct — one is a board, one is a piece set.
* `age_gate_screen.dart` carries the 13+ refusal. Keep the interpolation, address
  a **player**, never say "child", and do not add advice about asking a parent.
* When a string changes, `grep` the **old Serbian words** across
  `chess_app/test/` and change every assertion on it in the same edit. Do not
  grep for accented letters alone: a Serbian assertion can have none.
* When you translate a `contains` or `isNot(contains(...))`, check the new string
  cannot also match the case the test rules out. `'slika'` is not a substring of
  `'slike'`; `'image'` **is** a substring of `'images'`. Report any you find.

## Rules

* Do not touch `chess_backend/`. Not one file.
* Do not touch `lib/core/services/speech_text.dart` or
  `test/speech_text_test.dart`. They are the lead's and are already done.
* Do not touch anything under `chess_app/lib/` outside the fifty-five files and
  the one deletion.
* Do not move or edit the anchors in `docs/gates/`. Run them; report what still
  fails.
* Do not delete a test, weaken an assertion, or relax a matcher to make
  something pass. The two `serbian_plural` test files are the only exception,
  and only because the code they test is being deleted. If a test cannot be made
  green by translating it, stop and report it.
* Do not add a raw `ScaffoldMessenger`; messages go through `AppFeedback`.
* Do not commit, branch, or `git add`.

## Done means

* `cd chess_app && flutter test` → the before-count minus the tests in the two
  deleted files, and nothing else. State all three numbers.
* `cd chess_app && flutter analyze` → 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Read the summary line it prints on
  its own — do not count with a grep pattern that cannot match a `warning`.
* `dart format` clean on every file you touched.
* No Serbian letter (`čćžšđ ČĆŽŠĐ`) in any string literal anywhere under
  `chess_app/lib/`. This batch is the one that can say **anywhere**.

## The report

Write it to `REPORT-prevod-ostatak.md` in the repository root.

1. Test count before, after, and how many tests the two deleted files held. The
   three numbers must add up.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated — **and call the number what it
   actually is**. The last report's table was `git diff --numstat` added lines
   labelled "translated literals", and the real count was less than half of it.
4. Every test file you edited, and why.
5. Every sentence you rewrote rather than translated, and every `contains` whose
   English form might match what its Serbian form could not.
6. Every term in the brief's table that turned out wrong or missing, and every
   endgame name you were unsure of.
7. Which assertions in the two `docs/gates/` anchors still fail, if any.
8. Anything this task or the brief got wrong.

**Write only what you did.** Three reports in this series had accurate numbers
and one invented section each. **Quote nothing you have not just grepped.** A
short report that is entirely true is worth more than a thorough one that is not.
