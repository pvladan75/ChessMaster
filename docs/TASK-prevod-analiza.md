# Task — English pivot, batch 65a: the analysis studio and the scanner

**This file plus `docs/brief-prevod-analiza-2026-09.md` are the only context you
get. Do not rely on any conversation before them.** Read the brief first, then
`docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-analiza`. **Do not commit.**

## What to do

Replace the Serbian user-facing string literals with English in these
twenty-nine files, and in the same edit update every test that asserts on the
copy you changed.

In this order — smallest first:

1. `chess_app/lib/features/analysis_studio/services/opening_explorer_service.dart`
2. `chess_app/lib/features/analysis_studio/widgets/opening_explorer_panel_widget.dart`
3. `chess_app/lib/features/analysis_studio/widgets/opening_picker.dart`
4. `chess_app/lib/features/position_scanner/services/side_proposal_runner.dart`
5. `chess_app/lib/widgets/ai_studio/grouped_moves_dialog.dart`
6. `chess_app/lib/widgets/ai_studio/pgn_solution_tree_widget.dart`
7. `chess_app/lib/features/analysis_studio/widgets/visual_move_tree_widget.dart`
8. `chess_app/lib/widgets/ai_studio/studio_info_header.dart`
9. `chess_app/lib/features/analysis_studio/services/auto_tree_generator_service.dart`
10. `chess_app/lib/features/analysis_studio/widgets/move_tree_widget.dart`
11. `chess_app/lib/features/analysis_studio/widgets/quick_extend_dialog.dart`
12. `chess_app/lib/widgets/ai_studio/solution_graph_widget.dart`
13. `chess_app/lib/features/analysis_studio/services/position_info_service.dart`
14. `chess_app/lib/features/analysis_studio/widgets/tactical_findings_panel_widget.dart`
15. `chess_app/lib/features/analysis_studio/widgets/saved_puzzle_sets_dialog.dart`
16. `chess_app/lib/features/position_scanner/services/side_proposal.dart`
17. `chess_app/lib/features/analysis_studio/services/chess_platform_import_service.dart`
18. `chess_app/lib/features/analysis_studio/widgets/auto_analysis_dialog.dart`
19. `chess_app/lib/features/analysis_studio/widgets/positional_findings_panel_widget.dart`
20. `chess_app/lib/features/position_scanner/widgets/assign_positions_dialog.dart`
21. `chess_app/lib/features/position_scanner/services/scanner_api_service.dart`
22. `chess_app/lib/features/analysis_studio/widgets/board_setup_dialog.dart`
23. `chess_app/lib/features/analysis_studio/widgets/game_review_dialog.dart`
24. `chess_app/lib/features/position_scanner/screens/scan_review_screen.dart`
25. `chess_app/lib/features/analysis_studio/widgets/opening_judge_panel_widget.dart`
26. `chess_app/lib/features/analysis_studio/dialogs/analysis_studio_dialogs.dart`
27. `chess_app/lib/widgets/ai_studio/category_selection_hub.dart`
28. `chess_app/lib/features/position_scanner/screens/saved_positions_screen.dart`
29. `chess_app/lib/features/analysis_studio/screens/analysis_studio_screen.dart`

**Run the whole suite once, at the end.** Do not run it per file. The previous
batch was told to and spent its entire budget on twenty-six suite runs; that
instruction is withdrawn. You may run a single test file when you have a
specific reason to.

## Method

* One file at a time, finished before the next.
* For each Serbian literal decide **copy or value**. Only copy changes. API
  paths, JSON keys, `'w'`/`'b'`, ECO codes and anything compared against a
  server response are values and stay.
* Use the brief's two vocabulary tables exactly. The first one — fork, pin,
  skewer, discovered check, overloaded piece, deflection, doubled/isolated/
  backward/passed pawn, outpost, bishop pair, pawn shield — is **already
  shipped** in `lib/core/services/tactical_motif_detector.dart` and
  `positional_evaluator_service.dart`. The two findings panels in this batch
  must agree with them word for word.
* "Vežba" in these screens is a **puzzle**, not a drill — the code says
  `extractedPuzzles`, `_maxPuzzles`, `saved_puzzle_sets_dialog.dart`.
* "Linija" is a **file** (a–h) in the opening and positional panels, and a
  **line** of moves in the engine panel and the tree. Read each one.
* "Strana" is a **page** of a book in the scanner and the **side to move** in
  the side proposals. Both appear in `saved_positions_screen.dart` and
  `scan_review_screen.dart`.
* Opening names in `position_info_service.dart` have settled English forms.
  If you are unsure of one, report it rather than inventing it.
* When a string changes, `grep` the **old Serbian words** across
  `chess_app/test/` and change every assertion on it in the same edit. Do not
  grep for accented letters alone: a Serbian assertion can have none.
* Comments and `AppLogger` / `debugPrint` lines are not in scope.

## Rules

* Do not touch `chess_backend/`. Not one file.
* Do not touch `lib/core/services/tactical_motif_detector.dart` or
  `lib/core/services/positional_evaluator_service.dart`. They are done.
* Do not touch anything under `chess_app/lib/` outside the twenty-nine files —
  `lib/core/`, `lib/services/`, `lib/features/archive/`, `lib/features/groups/`,
  `lib/features/library/`, `lib/features/reviews/`,
  `lib/features/trainer_panel/`, `lib/theme/`, `lib/routing/` and `lib/widgets/`
  outside `lib/widgets/ai_studio/` are the next batch.
* Do not move or edit the anchors in `docs/gates/`.
* Do not delete a test, weaken an assertion, or relax a matcher to make
  something pass. If a test cannot be made green by translating it, stop and
  report it.
* Do not add a raw `ScaffoldMessenger`; messages go through `AppFeedback`.
* Do not commit, branch, or `git add`.

## Done means

* `cd chess_app && flutter test` → **1772 passing, 1 skipped**.
* `cd chess_app && flutter analyze` → 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Read the summary line it prints on
  its own — do not count with a grep pattern that cannot match a `warning`.
* `dart format` clean on every file you touched.
* No Serbian letter (`čćžšđ ČĆŽŠĐ`) in any string literal in the twenty-nine
  files.

## The report

Write it to `REPORT-prevod-analiza.md` in the repository root. Numbers you
measured in this run:

1. Test count before and after, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every test file you edited, and why.
5. **Every sentence you rewrote rather than translated** — anything that only
   worked because of Serbian word order, and every plural helper you changed.
   The reviewer reads this first.
6. Every term in the brief's tables that turned out wrong or missing, and every
   opening name you were unsure of.
7. Anything this task or the brief got wrong.

**Write only what you did.** Two reports in this series had accurate numbers and
one invented section each — buttons that exist nowhere, copy that was never
written. A short report that is entirely true is worth more than a thorough one
that is not.
