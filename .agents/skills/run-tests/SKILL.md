---
name: run-tests
description: Runs Flutter unit, widget, and golden tests for Mislisha, handling platform cleanliness and analysis.
---

# Test Execution Workflow

## 1. Run Standard Test Suite
```bash
cd chess_app && flutter test
```
- Expectation: 767+ passed, 1 skipped (golden suite).

## 2. Run / Update Golden Screenshot Tests
```bash
cd chess_app && flutter test --tags golden --run-skipped --update-goldens test/design_gallery_golden_test.dart
```
- Generates the 4 reference PNGs in `design-screenshots/`.
- **`--run-skipped` is the load-bearing flag.** `dart_test.yaml` marks the `golden`
  tag with `skip:`, and that wins over `--tags golden` on its own — the run then
  reports `All tests skipped` and exits 0, so it looks like it worked and no PNG
  is written. Verified: with both flags, 4 tests run.
- Afterwards, **look at the PNGs**. A golden that renders every glyph as a grey
  box is a passing test and a worthless artefact; that is how the first four
  screenshots on this project were produced.

## 3. Run Static Analysis
```bash
cd chess_app && flutter analyze
```
- Expectation: 29 baseline info issues, 0 errors, 0 warnings.

## 4. Reset Platform Worktree
```bash
git checkout -- chess_app/linux chess_app/macos chess_app/windows
```
