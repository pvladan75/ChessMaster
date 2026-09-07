# Report: batch 61 — crtanje po tabli u studiju (P7a)

## 1. Test Count Before and After

- **Before**: 1582 passed, 1 skipped (`+1582 ~1: All tests passed!`)
  - Gate `chess_app/test/tutorial_oznake_test.dart` before implementation: 0 passed, 11 failed.
- **After**: 1593 passed, 1 skipped (`+1593 ~1: All tests passed!`)
  - Gate `chess_app/test/tutorial_oznake_test.dart` after implementation: 11 passed, 0 failed.
- **Delta**: exactly +11 passed tests, 0 regressions, 1 skipped preserved.

## 2. Analyzer Summary Line and List Before and After

- **Before**:
  `29 issues found. (ran in 129.1s)`
  All 29 issues were the pre-existing `curly_braces_in_flow_control_structures` in:
  - `lib/core/services/game_analysis_walker_service.dart:239, 241, 252`
  - `lib/core/services/positional_evaluator_service.dart:261, 299, 343, 406, 412, 594, 607, 702`
  - `lib/core/services/tactical_motif_detector.dart:804, 962, 1354`
  - `lib/features/reviews/services/review_api_service.dart:102`
  - `lib/screens/ai_studio_screen.dart:280, 1023, 1025, 1252, 1254, 1341, 1349, 1368, 1638, 1740, 2095, 3075`
  - `lib/widgets/matrix_filter_panel.dart:137, 147`
- **After**:
  `29 issues found. (ran in 5.5s)`
- **Comparison**:
  The list before and after is **identical**.

## 3. Suppressions

No `// ignore:` or `ignore_for_file` was added.

## 4. Exact List of Files Changed or Added

- **Added**: `chess_app/lib/widgets/game_screen/board_annotation_bar.dart`
- **Modified**: `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
- **Added (gate test)**: `chess_app/test/tutorial_oznake_test.dart`

## 5. Proof of What Travels, Not of What is Drawn

Measured against `LessonApiService` saves decoded in test runs:

1. **Drawing one arrow on a move** (move 1 `e4`, arrow from `g1` to `f3` in green):
   Request body `positionList[0]['pgn']`:
   ```pgn
   [Event "Analysis Studio Session"]
   [Site "Sahovski trener"]
   [Date "2026.09.07"]
   [Round "1"]
   [White "Player"]
   [Black "Analysis Engine"]
   [Result "*"]

    1. e4 { [%cal Gg1f3] } e5 2. Nf3 *
   ```
   Point at: `[%cal Gg1f3]` attached to move `1. e4`.

2. **One coloured square on the starting position** (step with no moves, square `d5` in green):
   Request body `positionList[0]['pgn']`:
   ```pgn
   [Event "Analysis Studio Session"]
   [Site "Sahovski trener"]
   [Date "2026.09.07"]
   [Round "1"]
   [White "Player"]
   [Black "Analysis Engine"]
   [Result "*"]

   { [%csl Gd5] }  *
   ```
   Point at: `[%csl Gd5]` on the root position.

3. **Both arrow and coloured square on the starting position** (`d5` square, `d5->e7` arrow):
   Request body `positionList[0]['pgn']`:
   ```pgn
   [Event "Analysis Studio Session"]
   [Site "Sahovski trener"]
   [Date "2026.09.07"]
   [Round "1"]
   [White "Player"]
   [Black "Analysis Engine"]
   [Result "*"]

   { [%cal Gd5e7] [%csl Gd5] }  *
   ```
   Point at: `[%cal Gd5e7]` and `[%csl Gd5]` on the root position with zero played moves.

## 6. The Erase Rule Measured

After drawing arrow `d2` -> `d4` in green, switching color code to Red (`ArrowColor.r.id`), and drawing `d2` -> `d4` again:
- The controller removed the existing arrow despite the active color code mismatch.
- Saved PGN line has no arrows: `rootArrows` is empty (`[]`), and `pgn` is `null` / empty without `[%cal]`.

## 7. Mutation Testing

Three mutations were executed to prove the guards:

1. **Mutation 1 — Cursor movement canceling pending arrow start**:
   - Mutation: Commented out `_annotationController.cancelPending();` in `_jumpTo()`.
   - Result: `testWidgets('moving the board forgets a half-drawn arrow')` failed:
     ```
     Expected: empty
       Actual: ExpandIterable<List<ChessArrow>, ChessArrow>:[ChessArrow:Ge2e4]
     an arrow was finished across a move of the board, so it was drawn from a square on the position the author had left
     ```
   - Reverted: guard restored and passing.

2. **Mutation 2 — Mode button toggle behavior**:
   - Mutation: Modified `_toggleArrowMode()` to unconditionally set `_annotationController.setMode(AnnotationMode.arrow)` instead of toggling off if already in arrow mode.
   - Result: `testWidgets('pressing „Strelica" puts the board in drawing mode')` failed:
     ```
     Expected: false
       Actual: <true>
     the same button does not turn drawing off again
     ```
   - Reverted: guard restored and passing.

3. **Mutation 3 — Clear marks clearing both arrows and squares**:
   - Mutation: Modified `_clearMarks()` to call `clearArrows()` instead of `clearMarks()`.
   - Result: `testWidgets('„Obriši oznake" takes both kinds off this node')` failed:
     ```
     Expected: empty
       Actual: [SquareMark:Gd5]
     ```
   - Reverted: guard restored and passing.

## 8. Outside Test Regressions

None. Every existing test in the test suite passed cleanly on the first run and in the final full run.

## 9. Observations & Notes

- In `docs/gates/tutorial_oznake_test.dart` line 231, the reason message reads `'the same button does not turn drawing off again'`, whereas the assertion `expect(board(tester).isDrawingMode, isFalse)` asserts that the button **does** turn drawing off again.
- In `board_annotation_bar.dart`, `package:chess_app/theme/app_spacing.dart` was initially imported directly; `flutter analyze` flagged this as `unnecessary_import` because `app_colors.dart` re-exports it. Removing the direct import restored the analyzer issue list to be identical to baseline.
