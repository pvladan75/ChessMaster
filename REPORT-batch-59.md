# Batch 59 Report: Panel „Tok" (P6a)

## 1. Test Counts (Measured in this run)

* **Before changes**: `1539 passed, 1 skipped` (full suite via `flutter test`)
* **Gate before implementation**: `0 passed, 12 failed` (`flutter test test/tutorial_tok_test.dart`)
* **Gate after implementation**: `12 passed, 0 failed` (`flutter test test/tutorial_tok_test.dart`)
* **After changes**: `1551 passed, 1 skipped` (full suite via `flutter test`)
* **Net change**: Exactly +12 tests (the 12 tests of the gate suite), 0 regressions.

## 2. Analyzer Summary & Issue List

### Summary line
* **Before**: `29 issues found. (ran in 13.0s)`
* **After**: `29 issues found. (ran in 10.0s)`
* **Difference**: **identical** (0 errors, 0 warnings, 0 new infos; exactly the same 29 pre-existing `curly_braces_in_flow_control_structures` issues).

### Full Analyzer Issue List (Before & After)
1. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:239:51 - curly_braces_in_flow_control_structures`
2. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:241:51 - curly_braces_in_flow_control_structures`
3. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:252:43 - curly_braces_in_flow_control_structures`
4. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:261:37 - curly_braces_in_flow_control_structures`
5. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:299:40 - curly_braces_in_flow_control_structures`
6. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:343:50 - curly_braces_in_flow_control_structures`
7. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:406:45 - curly_braces_in_flow_control_structures`
8. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:412:45 - curly_braces_in_flow_control_structures`
9. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:594:33 - curly_braces_in_flow_control_structures`
10. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:607:40 - curly_braces_in_flow_control_structures`
11. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:702:11 - curly_braces_in_flow_control_structures`
12. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:804:11 - curly_braces_in_flow_control_structures`
13. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:962:9 - curly_braces_in_flow_control_structures`
14. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:1354:11 - curly_braces_in_flow_control_structures`
15. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\features\reviews\services\review_api_service.dart:102:9 - curly_braces_in_flow_control_structures`
16. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:280:9 - curly_braces_in_flow_control_structures`
17. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1023:7 - curly_braces_in_flow_control_structures`
18. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1025:7 - curly_braces_in_flow_control_structures`
19. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1252:9 - curly_braces_in_flow_control_structures`
20. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1254:9 - curly_braces_in_flow_control_structures`
21. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1341:11 - curly_braces_in_flow_control_structures`
22. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1349:11 - curly_braces_in_flow_control_structures`
23. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1368:24 - curly_braces_in_flow_control_structures`
24. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1638:19 - curly_braces_in_flow_control_structures`
25. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1740:19 - curly_braces_in_flow_control_structures`
26. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:2095:11 - curly_braces_in_flow_control_structures`
27. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:3075:21 - curly_braces_in_flow_control_structures`
28. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\widgets\matrix_filter_panel.dart:137:27 - curly_braces_in_flow_control_structures`
29. `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\widgets\matrix_filter_panel.dart:147:27 - curly_braces_in_flow_control_structures`

## 3. Suppression Directives

No `// ignore:` or `ignore_for_file` was added.

## 4. Exact List of Files Changed or Added

* `chess_app/lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart` (new file, formatted with `dart format`)
* `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart` (modified, formatted with `dart format`)
* `chess_app/test/tutorial_tok_test.dart` (copied from `docs/gates/tutorial_tok_test.dart`, formatted with `dart format`)
* `REPORT-batch-59.md` (this report)

## 5. Proof of the Property (Not the Mechanism)

### Re-projection across fork selection
For PGN `1. e4 e5 (1... c5 2. Nf3) 2. Nc3`:
* **Before pressing `1... c5` chip**:
  The timeline cards rendered headers:
  1. `Polazna pozicija` (beat 0)
  2. `posle 1. e4` (beat 1; with fork chips `1... e5` and `1... c5`)
  3. `posle 1... e5` (beat 2)
  4. `posle 2. Nc3` (beat 3)
* **After tapping `1... c5` chip**:
  The timeline re-projected through the chosen sideline and rendered headers:
  1. `Polazna pozicija` (beat 0)
  2. `posle 1. e4` (beat 1; with fork chips `1... e5` and `1... c5`)
  3. `posle 1... c5` (beat 2)
  4. `posle 2. Nf3` (beat 3)
  * Note: `posle 2. Nc3` was no longer drawn anywhere on screen (`findsNothing`), proving the timeline followed the sideline rather than stacking or appending branches.

### Tab switch state preservation
* In `the tree is not rebuilt by the switch`:
  * Tab switched to `stablo-tab`: `AnalysisMoveTreeWidget` state instance captured: `_AnalysisMoveTreeWidgetState#<id>`
  * Tab switched away to `tok-tab` (tree placed offstage via `IndexedStack`)
  * Tab switched back to `stablo-tab`: `AnalysisMoveTreeWidget` state instance read: `_AnalysisMoveTreeWidgetState#<id>`
  * Assertion `identical(first, second)` evaluated to `true`, verifying `same(first)`. The `State` object was preserved across switches without being recreated.

## 6. Mutations Executed & Guard Verification

1. **Mutation 1 (State preservation guard)**:
   * Replaced `IndexedStack` with conditional `if (_selectedTab == 0) TutorialFlowPanel(...) else AnalysisMoveTreeWidget(...)`.
   * Result: `the other tab the tree is not rebuilt by the switch` failed loudly:
     `Expected: same instance as _AnalysisMoveTreeWidgetState:<... (lifecycle state: defunct, not mounted)>`
     `Actual: _AnalysisMoveTreeWidgetState:<...>`
   * Reverted cleanly.

2. **Mutation 2 (Narration order constraint)**:
   * Placed move out (`pa se igra: ...`) before header in `_BeatCard`.
   * Result: `the line, drawn the way the child meets it the move out is under the sentence, not above it` failed loudly with coordinate bounds error.
   * Reverted cleanly.

3. **Mutation 3 (Current beat uniqueness guard)**:
   * Rendered `Key('beat-current')` unconditionally on every card rather than only when `beat.isCurrent` is true.
   * Result: `the board follows the panel exactly one card is the one the author stands on` failed loudly:
     `Expected: exactly one matching candidate`
     `Actual: Found 4 widgets with key [<'beat-current'>]`
   * Reverted cleanly.

4. **Mutation 4 (No tree walking or move counting duplication)**:
   * Introduced forbidden string `fullmove` into `tutorial_flow_panel.dart`.
   * Result: `what the panel must not become it walks no tree and counts no move of its own` failed loudly:
     `Expected: false, Actual: true`
   * Reverted cleanly.

## 7. Tests Outside the Gate That Went Red

**None**. All 1539 pre-existing tests remained green throughout and passed without any modification.

## 8. Corrections & Contract Observations

* The gate specification in `docs/gates/tutorial_tok_test.dart` and `docs/TASK-studio-tok.md` was completely accurate and self-consistent.
* No changes to backend, android, models, or any files outside the two required files (`tutorial_flow_panel.dart` and `tutorial_studio_screen.dart`) were needed.
