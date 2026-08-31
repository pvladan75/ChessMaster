# TASK — the repertoire build screen gets its tree, on one screen

This file plus `docs/brief-repertoar-raspored-2026-08.md` are the only context
you get. **Do not rely on any conversation before them.** Read the brief first;
it holds the API contract, the rules and the pass conditions.

Branch: `design/repertoar-raspored`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Step 1 of `docs/PLAN-REPERTOAR.md`, and nothing else: layout. No new endpoint,
no new table, no change to what any position means.

**Do not touch `chess_backend/` at all.**

## Order

1. Move `_convert` and `_markOf` out of
   `chess_app/lib/features/repertoire/screens/repertoire_tree_screen.dart` into a
   widget the build screen can hold. Do not rewrite them.
2. Put `AnalysisMoveTreeWidget` on `RepertoireBuildScreen`, with `activeNode`
   following the board and a tap moving the board.
3. Two layouts around `Breakpoints.isWide` — two columns wide, one column
   narrow with the panel below the controls.
4. The one-row strip under the board: parent → current → children, with marks.
5. Let the board grow past 420 on wide windows.
6. Delete `RepertoireTreeScreen`, its route wiring in the list screen, and its
   test file — moving any assertion that still means something onto the panel.
7. Tests: one widget test per layout (360 × 640 and 1400 × 900), each asserting
   `tester.takeException()` is null.

## Method

* `dart format` every Dart file you touch.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Zero errors, zero warnings, no new
  infos.
* `flutter test` must stay green and the count must not fall below **985**.
* Reuse what exists. `AnalysisMoveTreeWidget`, `Breakpoints`, `numberedLine` and
  the conversion are all already written; a second copy of any of them fails the
  batch on review even if the gates pass.
* If a file this task names does not exist, **stop and say so**. Do not
  substitute the nearest plausible file.
* Leave no scratch files in the tree.

## Report

Write `report-repertoar-raspored.md` in the repository root, containing:

1. test count before and after, both measured by you in this run;
2. the analyze list before and after — count, and whether the set of files
   changed;
3. every file you added user-facing strings to;
4. proof of the property rather than the mechanism: a test that pumps the wide
   layout and finds board and tree on screen together, quoted;
5. anything the brief got wrong.
