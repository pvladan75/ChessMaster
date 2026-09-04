# TASK — the order a repertoire is read in

This file plus `docs/brief-upoznaj-f3-2026-09.md` are the only context you get.
**Do not rely on any conversation before them.** Read the brief first; it holds
the reasoning, the exact shapes, and the pass conditions.

Branch: `design/upoznaj-f3`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 3 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side. This
batch reads a shape the server already returns and adds no request, no route
and no field.

**This batch adds no widget and no user-facing string.** It is one file of pure
Dart and its tests. If you find yourself opening a screen, you have
misunderstood the job — stop and say so in the report.

## What you are building

Two things, both in one new file
`chess_app/lib/features/repertoire/services/walkthrough_order.dart`:

1. `class WalkthroughStop` — one visited move, its line, and its depth.
2. `List<WalkthroughStop> walkthroughOrder(RepertoireTree tree)` — the order a
   tour visits them in.

The exact signatures, fields and ordering rule are in §3 of the brief. They are
a contract, not a suggestion: the screen in phase 4 is briefed against them.

## What you must not do

* **Do not write a `stopKindOf`.** It already exists as
  `lookOfRepertoireMove` in
  `lib/features/repertoire/widgets/repertoire_tree_panel.dart`, and a second
  copy of that condition is exactly the defect this codebase keeps paying for.
  Import it. §4 of the brief.
* **Do not change `RepertoireTree` or `RepertoireTreeMove`.** They are the
  frozen contract this batch reads.
* **Do not sort in place.** `walkthroughOrder` must not mutate the tree it is
  given; a caller draws the same tree afterwards and the drawing's order is the
  server's.
* **Do not add a user-facing string anywhere.** The `strings` gate fails on one,
  and it would be right to.

## What you need before starting

* Flutter, and `flutter test` on the branch **before you change anything**.
  **Measure it yourself and report it; do not trust a number quoted at you.**
  It should be **1155 passing, 1 skipped**. If it is lower, stop and report —
  something is wrong before your work starts.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Compare the list, not the exit
  code.
* No backend, no database, no credentials, no network.

## Method

1. Read the brief whole. §3 is the contract and §5 is what gets the work
   rejected.
2. Write the file, then the tests. The examples in §6 of the brief are
   test cases already written out — every one of them must pass.
3. `flutter test` — the count must be **1155 plus your own tests**, and no
   existing test may fail. A test you had to change is a finding: report it and
   stop.
4. `flutter analyze` — the list, not the exit code.
5. **`dart format` every Dart file you touched — last.**

## Your report

Write `report-upoznaj-f3.md` in the worktree root, stating:

1. `flutter test` before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after;
3. **the ordering, printed for the tree in §6.3 of the brief** — the actual
   list your function returns, in order, as `path` strings. Not a description
   of it: the output;
4. any rule in §3 you found ambiguous, and which reading you took;
5. anything the brief got wrong. A correction is worth more than a clean
   report.

**Do not claim a number you did not compute in that run.**
