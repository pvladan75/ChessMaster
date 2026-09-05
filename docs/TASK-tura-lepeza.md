# TASK — a fan of unanswered replies is one stop, not four

This file plus `docs/brief-tura-lepeza-2026-09.md` are the only context you get.
**Do not rely on any conversation before them.** Read the brief first; it holds
the reasoning, the exact rule, and the pass conditions.

Branch: `design/tura-lepeza`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 4 of `docs/PLAN-TABLA-I-STABLO.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side.

One source file, and no others:

* **edited** `lib/features/repertoire/services/walkthrough_order.dart` — the
  rule of §5 of the brief, inside `walkthroughOrder`. Nothing else in that file.

Plus your tests, in the existing
`test/repertoire_walkthrough_order_test.dart`.

## What you must not do

* **Do not touch `_ordered`.** The sibling order is settled, tested, and the
  owner's own rule. Changing it — even correctly — fails this batch.
* **Do not touch `walkthroughBeats`, `walkthrough_speech.dart`, or any screen.**
  This batch decides which stops exist, not what they say. If you believe a
  sentence is wrong, say so in the report and stop.
* **Do not write the gap condition again.** Call `lookOfRepertoireMove`. Three
  hand-written copies of one condition in this codebase each forgot the same
  clause, and a test fails when a fourth appears.
* **Do not drop the lone gap.** With exactly one unanswered reply there is no
  fork sentence, so that stop is the only place a hole is ever said. §2 of the
  brief. This is the half that is easy to get wrong.
* **Do not mutate the tree.** The same object is drawn afterwards by a screen
  that knows nothing about this function.
* **Do not edit an existing test to agree with your code.** A test you had to
  change is a finding: report it and stop.
* **Do not grade yourself on golden tests.** They are skipped unconditionally
  and `--tags golden` alone still skips them; the run exits 0 saying „All tests
  skipped".

## What you need before starting

* Flutter, and `flutter test` on the branch **before you change anything**.
  **Measure it yourself and report it; do not trust a number quoted at you.**
  It should be **1212 passing, 1 skipped**. If it is lower, stop and report —
  something is wrong before your work starts.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Compare the list, not the exit
  code.
* No backend, no database, no credentials, no network.

## Method

1. Read the brief whole. §5 is the rule; §7 is what gets the work rejected.
2. Write the four tests of §7 **first**, and watch tests 1 and 2 fail against
   today's code. If test 1 passes before you change anything, the rule is
   already implemented or your fixture is wrong — stop and report.
3. Then the rule, in `walkthroughOrder`.
4. **Mutate tests 1 and 2 and watch each fail** — first by skipping every gap
   rather than only fans, then by removing the rule entirely. Report what you
   broke and what failed.
5. `flutter test` — the count must be **1212 plus your own tests**, and no
   existing test may fail.
6. `flutter analyze` — the list, not the exit code.
7. **`dart format` every Dart file you touched — last.**

## Your report

Write `report-tura-lepeza.md` in the worktree root, stating:

1. `flutter test` before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after;
3. **the two mutations of step 4**, each with the test that failed and the
   message it failed with. Not „I verified them": the output;
4. **the stop list your code produces for the §7 case 3 tree**, printed in
   order, each stop as its SAN and its `kind`. This is the case the rule is
   easiest to get wrong on;
5. any rule in §5 you found ambiguous, and which reading you took;
6. anything the brief got wrong. A correction is worth more than a clean
   report.

**Do not claim a number you did not compute in that run.**
