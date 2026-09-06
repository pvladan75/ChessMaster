# Report: Batch 60 — Polja se sele u tok

## Test Count Before and After

- **Before**: 1554 passed, 1 skipped (measured locally on `batch/studio-polja` before changes).
- **Gate Test Before (`chess_app/test/tutorial_tok_edit_test.dart`)**: 2 passed, 7 failed.
- **Gate Test After**: 9 passed, 0 failed.
- **After (Full Suite)**: 1563 passed, 1 skipped (measured locally with nothing else running).
- **Delta**: +9 passed, 0 failed, 0 skipped regressions.

## Analyzer Summary and List

- **Summary Before**: `29 issues found. (ran in 7.1s)`
- **Summary After**: `29 issues found. (ran in 4.9s)`
- **List Comparison**: **identical**
  All 29 pre-existing issues are `info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - ... - curly_braces_in_flow_control_structures`.
  Zero errors, zero warnings, zero new infos.

## Suppression Check

No // ignore: or ignore_for_file was added.

## Files Changed or Added

- `chess_app/lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart` (modified)
- `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart` (modified)
- `chess_app/test/tutorial_tok_edit_test.dart` (added gate test)
- `REPORT-batch-60.md` (added report)

## Proof of What Gets Saved

The request body's `pgn` string was measured by opening a saved tutorial (`pgn: '1. e4 e5 2. Nf3'`), typing into `beat-comment-1` (card 1, move `1. e4`) without standing on it, and asserting on the payload captured by the HTTP mock client:

```
[Event "Analysis Studio Session"]
[Site "Sahovski trener"]
[Date "2026.09.07"]
[Round "1"]
[White "Player"]
[Black "Analysis Engine"]
[Result "*"]

 1. e4 { Beli zauzima centar. } e5 2. Nf3 *
```

Where the sentence sits:
The comment `{ Beli zauzima centar. }` sits inside curly brackets immediately after `1. e4` and prior to `e5`. This proves that typing into the card for node `1. e4` wrote directly to that node's comment and was serialized at the exact move location in the PGN, rather than writing to whatever node the cursor was standing on.

## Re-projection Measurement

Tested with `pgn: '1. e4 e5 {Klasičan odgovor.} (1... c5 {Sicilijanka.} 2. Nf3) 2. Nc3'`:

- **Before pressing fork chip `1... c5`**:
  - `beat-1` (`1. e4`): text `""`
  - `beat-2` (`1... e5`): text `"Klasičan odgovor."` (`find.widgetWithText(TextField, 'Klasičan odgovor.')` finds 1)
  - `beat-3` (`2. Nc3`): text `""`
- **After pressing fork chip `1... c5`**:
  - `beat-1` (`1. e4`): text `""`
  - `beat-2` (`1... c5`): text `"Sicilijanka."` (`find.widgetWithText(TextField, 'Sicilijanka.')` finds 1)
  - `beat-3` (`2. Nf3`): text `""`
  - The text `"Klasičan odgovor."` is completely gone from all fields (`find.widgetWithText(TextField, 'Klasičan odgovor.')` finds 0).

## Tests Outside Gate That Went Red

none

Every existing test outside the gate remained green throughout.

## Mutations Run

1. **Mutation 1 (Keying cards by index instead of `beat.node.id`)**:
   - Change: In `tutorial_flow_panel.dart`, changed `key: ValueKey(beats[i].node.id)` to `key: ValueKey(beats[i].index)`.
   - Result: Test `re-projecting takes the fields with it` failed with `Expected: exactly one matching candidate. Actual: _AncestorWidgetFinder:<Found 0 widgets with type "TextField" that are ancestors of widgets with text "Sicilijanka.": []>`.
   - Outcome: Reverted; test passed green. Proves that keying by `beat.node.id` is necessary for Flutter to tear down card state on branch switches.

2. **Mutation 2 (Current beat key following)**:
   - Change: In `tutorial_flow_panel.dart`, changed `key: beat.isCurrent ? const Key('example-sentence') : Key('beat-comment-${beat.index}')` to unconditionally use `Key('beat-comment-${beat.index}')`.
   - Result: Tests failed with `Found 0 widgets with key [<'example-sentence'>] descending from widgets with type "TutorialFlowPanel"`.
   - Outcome: Reverted; test passed green. Proves `Key('example-sentence')` follows the active beat.

3. **Mutation 3 (Question card placement)**:
   - Change: In `tutorial_flow_panel.dart`, rendered `question` above the beat cards in `Column` instead of under the last beat.
   - Result: Test `the question card is under the last beat, and only there` failed with `Expected: a value greater than or equal to <1059.0>. Actual: <616.0>`.
   - Outcome: Reverted; test passed green. Proves that the question card is positioned below the last beat.

## Observations / Discrepancies in Task/Brief

1. **Comment in Test 1 vs Initial Cursor Position**:
   In `docs/gates/tutorial_tok_edit_test.dart`, line 198 states:
   `// The author is standing on the last move and edits the *second* card.`
   However, when `open(tester)` opens a saved lesson (`pgn: '1. e4 e5 2. Nf3'`), `TutorialSection.fromStep` initializes `cursorNode` to `root` (`AnalysisNode(fen: startFen)`), which corresponds to beat 0, not beat 3 (`2. Nf3`). Therefore, when the test begins, the author is standing on beat 0.
   Furthermore, because `root.comment` in PGN is serialized before move 1 (`1. e4`), an erroneous implementation that writes to `_current` (beat 0) would place the comment before `1. e4`, which still happens to be before `e5`. Thus `expect(pgn.indexOf('Beli zauzima centar.'), lessThan(pgn.indexOf('e5')))` alone would not differentiate a write to beat 0 from a write to beat 1. If the test explicitly selected `beat-3` before typing into `beat-comment-1`, it would strictly enforce that the comment is placed on beat 1 rather than the cursor node beat 3.
