# Report: Batch 57 — Panel delova tutorijala

## 1. Test Counts

* **Before changes**: 1497 passed, 1 skipped (`03:14 +1497 ~1: All tests passed!`)
* **After changes**: 1511 passed, 1 skipped (`03:44 +1511 ~1: All tests passed!`)
* **Difference**: Exactly +14 tests (1497 -> 1511), corresponding to the 14 new gate tests in `test/tutorial_delovi_test.dart`.

Breakdown of gate test baselines:
* `test/tutorial_delovi_test.dart`:
  * Before implementation: 0 passed, 14 failed
  * After implementation: 14 passed, 0 failed
* `test/tutorial_authoring_test.dart`:
  * Before implementation: 8 passed, 3 failed
  * After implementation: 11 passed, 0 failed

## 2. Static Analysis (`flutter analyze`)

* **Before changes**: `29 issues found. (ran in 8.5s)`
* **After changes**: `29 issues found. (ran in 3.2s)`
* **Comparison**: **identical**

The list of 29 pre-existing issues before and after:
```
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:239:51 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:241:51 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:252:43 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:261:37 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:299:40 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:343:50 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:406:45 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:412:45 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:594:33 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:607:40 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:702:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:804:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:962:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:1354:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\features\reviews\services\review_api_service.dart:102:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:280:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1023:7 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1025:7 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1252:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1254:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1341:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1349:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1368:24 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1638:19 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1740:19 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:2095:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:3075:21 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\widgets\matrix_filter_panel.dart:137:27 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\widgets\matrix_filter_panel.dart:147:27 - curly_braces_in_flow_control_structures
```

## 3. Suppression Directives

No `// ignore:` or `ignore_for_file` was added.

## 4. Files Changed or Added

* **Added**:
  * `chess_app/lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart`
  * `chess_app/test/tutorial_delovi_test.dart` (copied from `docs/gates/tutorial_delovi_test.dart`)
* **Changed**:
  * `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
  * `chess_app/test/tutorial_authoring_test.dart` (copied from `docs/gates/tutorial_authoring_test.dart`)

## 5. Proof of the Property (Selection Behavior)

When switching parts on `TutorialStudioScreen`, the board controller, the move tree, and the text fields synchronously follow the chosen part:

In `test/tutorial_delovi_test.dart` (`choosing a part takes the board and the tree with it`):
* **Initial part (Deo 1)**:
  * Comment typed: `'Prvi deo govori ovo.'`
  * Move played: `1. e4`
* **Second part added (Deo 2)** with `continueFromEnd: false`:
  * Move played: `1. d4`
  * **Before selection switch** (standing on Deo 2):
    * Active section: Deo 2
    * Tree root child: `d4` (`tree(tester).rootNode.children.single.moveSan == 'd4'`)
    * Board FEN: `rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1` (after 1. d4)
    * Sentence textfield: `''`
* **User chooses Deo 1** (`tapText(tester, 'Deo 1')`):
  * **After selection switch**:
    * Active section: Deo 1
    * Tree root child: `e4` (`tree(tester).rootNode.children.single.moveSan == 'e4'`)
    * Board FEN: `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` (`openingFen.split(' ').first`)
    * Sentence textfield: `'Prvi deo govori ovo.'` (`find.widgetWithText(TextField, 'Prvi deo govori ovo.') findsOneWidget`)

The board, tree root, and text fields all updated to reflect the selected section rather than staying stale on the previously opened section.

## 6. Mutations Executed to Prove Guards

1. **Last Part Refusal Guard**:
   * *Mutation*: In `TutorialStudioScreen._removeSection`, changed the refusal message from `'Poslednji deo ne može biti obrisan.'` to `'MUTATED REFUSAL'`.
   * *Result*: `test/tutorial_delovi_test.dart` failed immediately at `testWidgets('the last part is refused, in a sentence')` because it expected `'Poslednji deo ne može biti obrisan.'`.
   * *Status*: Reverted cleanly.

2. **Join Mark Guard**:
   * *Mutation*: In `TutorialSectionsPanel._isJoined`, forced it to return `false`.
   * *Result*: `test/tutorial_delovi_test.dart` failed immediately at `testWidgets('marks a part that continues the one before it')` with `Expected: exactly one matching candidate, Actual: 0 found`.
   * *Status*: Reverted cleanly.

3. **Reorder Bounds Guard**:
   * *Mutation*: In `TutorialSectionsPanel.build`, forced `canMoveDown = true;`.
   * *Result*: `test/tutorial_delovi_test.dart` failed at `testWidgets('the ends cannot be moved past')` with `Expected: null, Actual: Closure: () => void`.
   * *Status*: Reverted cleanly.

## 7. Observations & Feedback

1. **Icon Collision in `test/tutorial_studio_fields_test.dart`**:
   `test/tutorial_studio_fields_test.dart` had a selector `find.byIcon(Icons.delete).first` intended to delete a choice item. Because `TutorialSectionsPanel` is positioned above the choice items in `_authoringColumn`, using `Icons.delete` on the panel's `'Obriši deo'` button caused `find.byIcon(Icons.delete).first` in that pre-existing test to tap the panel delete button instead of the choice delete button. Using `Icons.delete_outline` for `'Obriši deo'` resolved this collision cleanly while adhering to the design system and passing all 14 tests in `tutorial_delovi_test.dart` (which queries by tooltip `'Obriši deo'`).
2. **Flutter `ListTile` Material Ancestor Requirement**:
   In test mode, Flutter asserts that a `ListTile` with custom selection decoration or ink splash must have a `Material` widget ancestor rather than a bare `DecoratedBox`. Wrapping `TutorialSectionsPanel` in a `Material` widget with `context.colors.surface` cleanly satisfied this assertion.
