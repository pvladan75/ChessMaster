# REPORT — Batch 58: Podeljeni raspored studija

## 1. Test count before and after
* **Before**: 1515 passed, 1 skipped (measured via `flutter test` on clean branch `batch/studio-raspored`)
* **After**: 1524 passed, 1 skipped (measured via `flutter test` after changes)
* **Difference**: +9 passed (all 9 tests from `chess_app/test/tutorial_raspored_test.dart`), 0 failed, 0 regressions.

## 2. Analyzer summary line and list before and after
* **Summary line before**: `29 issues found. (ran in 5.5s)`
* **Summary line after**: `29 issues found. (ran in 5.6s)`
* **List before and after**: **identical**
  Both lists contain exactly the 29 pre-existing `curly_braces_in_flow_control_structures` infos:
  - `lib/core/services/game_analysis_walker_service.dart`: lines 239, 241, 252
  - `lib/core/services/positional_evaluator_service.dart`: lines 261, 299, 343, 406, 412, 594, 607, 702
  - `lib/core/services/tactical_motif_detector.dart`: lines 804, 962, 1354
  - `lib/features/reviews/services/review_api_service.dart`: line 102
  - `lib/screens/ai_studio_screen.dart`: lines 280, 1023, 1025, 1252, 1254, 1341, 1349, 1368, 1638, 1740, 2095, 3075
  - `lib/widgets/matrix_filter_panel.dart`: lines 137, 147

## 3. Analyzer suppressions
Added any `// ignore:` or `ignore_for_file`: **no**.

## 4. Exact list of files changed or added
* `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart` (modified)
* `chess_app/lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart` (modified)
* `chess_app/test/tutorial_raspored_test.dart` (added; gate copied from `docs/gates/tutorial_raspored_test.dart`)

## 5. Proof of the property, not the mechanism
Measured directly off the laid-out render tree on a window of 1600×1000 (via Flutter WidgetTester):
* **Width of authoring pane (`authoring-pane`)**: `460.0 px`
* **Width of board pane (`board-pane`)**: `1104.0 px`
  - Total row width: `1600 - 24 (outer padding) = 1576.0 px`
  - Panes breakdown: `1104.0 (board-pane) + 12.0 (gap) + 460.0 (authoring-pane) = 1576.0 px`
* **Width and height of the board**:
  - `ChessBoardWithOverlay` size: `788.0 × 788.0 px`
  - `BoardWithCoordinates` size: `808.0 × 808.0 px` (board clamped to `constraints.maxHeight - 120 = 824.0 px`, minus `AppSpacing.sm * 2 = 16.0 px`)
* **Centring of the board in `board-pane`**:
  - Left edge of `board-pane`: `12.0 px`
  - Right edge of `board-pane`: `1116.0 px`
  - Left edge of `BoardWithCoordinates`: `160.0 px` (`boardRect.left - paneRect.left = 148.0 px`)
  - Right edge of `BoardWithCoordinates`: `968.0 px` (`paneRect.right - boardRect.right = 148.0 px`)
  - Horizontal slack: `1104.0 - 808.0 = 296.0 px` (distributed symmetrically as `148.0 px` on each side)
* **Heights of the two right-hand panels**:
  - `sections-half` height: `336.0 px`
  - `editor-half` height: `504.0 px`
  - Ratio: `336.0 / 504.0 = 2 / 3` (exact 2:3 flex split)

## 6. Every test outside the gate that went red at any point
**None**.
All 1515 existing tests passed without modification.

## 7. Independent scroll, measured the same way
* `sections-half` outermost scroll position before scrolling editor: `0.0 px`
* `editor-half` scroll position jumped to its maximum extent: `173.0 px`
* `sections-half` outermost scroll position after scrolling editor: `0.0 px` (sections panel did not move by even 1 pixel)
* Position of `Deo 1` tile in `sections-half`: exactly `Rect.fromLTWH(1136.0, 196.0, 444.0, 48.0)` before and after scrolling `editor-half`
* Position of `tutorial-title` field above the split: exactly `Rect.fromLTWH(1128.0, 68.0, 460.0, 48.0)` before and after scrolling `editor-half`

## 8. Layout behavior at 840 and 839
* **At 840 exactly** (`constraints.maxWidth >= Breakpoints.wide`):
  - Enters the split wide layout.
  - `authoring-pane` is fixed at `460.0 px`.
  - `board-pane` receives the remaining `840 - 24 (padding) - 12 (gap) - 460 = 344.0 px`.
  - `ChessBoardWithOverlay` is `311.6 × 311.6 px` (< 420 px).
  - No horizontal overflow (0 exceptions, 0 clipped pixels).
* **At 839 exactly** (`constraints.maxWidth < Breakpoints.wide`):
  - Switches to the narrow layout with a single vertically scrolling column (`SingleChildScrollView`).
  - `board` takes the full width minus outer padding: `839 - 32 = 807.0 px` (`ChessBoardWithOverlay` width is `771.0 px` > 700 px).
  - `authoring-pane` with side-by-side split is not drawn; instead `_authoringColumn` sits below the board in the scroll view.
  - „Sačuvaj tutorijal" remains in the AppBar, keeping a consistent action home across both layouts.

## 9. Mutations run to prove guards
1. **Authoring pane fixed width (460 px)**:
   - *Mutation*: Changed authoring pane width from 460 to 500 in `_authoringPaneWide`.
   - *Result*: `the authoring pane is 460 and the board pane has the rest` failed (`Expected: <460.0>, Actual: <500.0>`), and `at 840 the panes stand side by side` failed with RenderFlex overflow by 40 px.
2. **Flexible scrolling inside TutorialSectionsPanel**:
   - *Mutation*: Removed `Flexible` around `ListView.builder` inside `TutorialSectionsPanel`.
   - *Result*: `the list of parts scrolls inside itself` failed (`A RenderFlex overflowed by 478 pixels on the bottom`).
3. **Board horizontal centring**:
   - *Mutation*: Replaced `Center` with `Align(alignment: Alignment.centerLeft)` in `board-pane`.
   - *Result*: `the board is centred in the space it is given` failed (`Expected: a numeric value within <1> of <288.0>, Actual: <8.0>, differs by <280.0>`).

## 10. Notes on the task and brief
The brief and contract were remarkably precise and well-specified. The measurements taken during the throwaway build matched the production implementation exactly:
- `Flexible` with `shrinkWrap: true` and physics dropped inside `TutorialSectionsPanel` correctly prevents unbounded height exceptions in narrow layout while preventing RenderFlex overflows in the bounded flex split of wide layout.
- Moving „Sačuvaj tutorijal" into the AppBar eliminates any collision with `AppFeedback` SnackBar messages and ensures the save button is always visible and hit-testable regardless of scroll position in `editor-half`.
