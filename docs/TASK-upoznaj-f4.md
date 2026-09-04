# TASK — the „Upoznaj repertoar" screen

This file plus `docs/brief-upoznaj-f4-2026-09.md` are the only context you get.
**Do not rely on any conversation before them.** Read the brief first; it holds
the reasoning, the exact shapes, the exact strings, and the pass conditions.

Branch: `design/upoznaj-f4`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 4 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side. This
batch reads two endpoints that already exist and adds no request, no route and
no field.

Three files, and no others:

1. **new** `lib/features/repertoire/models/walkthrough_cursor.dart` — the
   cursor. Pure Dart, no widget. §3 of the brief.
2. **new** `lib/features/repertoire/screens/repertoire_walkthrough_screen.dart`
   — the screen. §4 and §5.
3. **edited** `lib/features/repertoire/screens/repertoire_list_screen.dart` —
   one item in the „Još" menu, and the push. §6. Nothing else in that file.

Plus your two test files, §8.

## What you must not do

* **Do not write a second ordering rule.** `forwardBranches` is *derived* from
  the stop list `walkthroughOrder` already returned. Sorting `children` yourself
  — even correctly — fails this batch. §3 of the brief says why, and the reason
  is a defect this codebase has paid for three times.
* **Do not change the contract you are building against**: `walkthroughOrder`,
  `WalkthroughStop`, `lookOfRepertoireMove`, `markOfRepertoireMove`,
  `RepertoireTree`, `RepertoireTreeMove`. If one of them is wrong, **say so in
  the report and stop.** Do not fix it.
* **Do not let the tour write anything.** No save, no delete, no promote, no
  cut, no engine. It reads and it navigates.
* **Do not call `ScaffoldMessenger`.** `AppFeedback` only —
  `test/app_feedback_guard_test.dart` fails on a raw call.
* **Do not invent a string.** Every user-facing string is written out in §5 and
  §6 of the brief. Use those, exactly, and no others.
* **Do not add a named route.** `MaterialPageRoute`, the way `_drill` does it.
* **Do not use an icon this app does not already draw.** `Icons.menu_book_outlined`
  is specified for that reason and it is not a matter of taste — §6.
* **Do not grade yourself on golden tests.** They are skipped unconditionally
  and `--tags golden` alone still skips them; the run exits 0 saying „All tests
  skipped". Widget tests over the real widgets, or nothing.

## What you need before starting

* Flutter, and `flutter test` on the branch **before you change anything**.
  **Measure it yourself and report it; do not trust a number quoted at you.**
  It should be **1167 passing, 1 skipped**. If it is lower, stop and report —
  something is wrong before your work starts.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Compare the list, not the exit
  code.
* No backend, no database, no credentials, no network.

## Method

1. Read the brief whole. §3 and §5 are the contract; §7 is what gets the work
   rejected.
2. Write the cursor and its tests first, against §9's worked tree. It is the
   half that is hard to get right and easy to test, and the screen is much
   easier once it is right.
3. Then the screen, then the menu item.
4. **Mutate tests 1, 5 and 10 and watch each one fail** before you believe them.
   Report what you broke and what failed.
5. `flutter test` — the count must be **1167 plus your own tests**, and no
   existing test may fail. A test you had to change is a finding: report it and
   stop.
6. `flutter analyze` — the list, not the exit code.
7. **`dart format` every Dart file you touched — last.**

## Your report

Write `report-upoznaj-f4.md` in the worktree root, stating:

1. `flutter test` before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after;
3. **the three mutations of step 4**, each with the test that failed and the
   message it failed with. Not „I verified them": the output;
4. **the card's text for each of the seven stops of §9**, printed — the actual
   strings your screen renders, in tour order;
5. any rule in §3 or §5 you found ambiguous, and which reading you took;
6. anything the brief got wrong. A correction is worth more than a clean
   report.

**Do not claim a number you did not compute in that run.**
