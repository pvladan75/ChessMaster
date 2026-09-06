# Task: the split layout of the tutorial studio

A bounded job for an outside agent. **This file plus
[brief-studio-raspored-2026-09.md](brief-studio-raspored-2026-09.md) are the
only context you get** — do not rely on any conversation before them.

Branch: `batch/studio-raspored`. Commit as
`batch 58 — podeljeni raspored studija`. **Do not commit.** Leave the worktree
dirty; the lead reads the diff.

Run this only on a tree where
`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart` and
`chess_app/lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart`
both exist. If either does not, **stop and say so**.

## What is asked

Flutter only, and it is **layout**: no new behaviour, no new sentence, no new
model. On a window at or above `Breakpoints.wide` the studio becomes

```
Row
├ Expanded            the board pane — board, then the move strip
└ SizedBox(width: 460)   the authoring pane
    ├ „Naziv tutorijala"                    fixed, above the split
    ├ Expanded(flex: 2)  TutorialSectionsPanel — scrolls on its own
    ├ Divider
    └ Expanded(flex: 3)  the rest, scrolling on its own:
         the fields for the open part, „Linija ovog dela", the move tree
```

and **„Sačuvaj tutorijal" moves into the AppBar**, beside „Unos pozicije",
leaving *both* layouts — the narrow one included, so the action keeps one home.
That is the one thing below the breakpoint that does change.

The board is **centred** in its pane: past a certain window width the board is
limited by the height instead, and the width left over goes on both sides of it
rather than all on one.

Three things follow from it, and they are the job:

1. **The right column is a fixed 460, and the board takes what is left.** Today
   the board is 45 % of the window and the right column is `Expanded`. Reverse
   it.
2. **The two right-hand panels scroll independently.** Today the whole column is
   one `SingleChildScrollView`, so reading down the tree carries the list of
   parts off the screen. After this, the list of parts stays where it is.
3. **Below `Breakpoints.wide` the layout is what it is today** — board on top,
   one scrolled column under it — minus the save, which is now in the AppBar
   for every width.

**Nothing else.** Do not touch `chess_backend/`, the viewer, or anything under
`chess_app/android/`. Do not build the „Tok" timeline, the `[Tok]/[Stablo]`
tabs, beat cards, arrow drawing or a draggable divider — those are later
batches, and a `TabBar` with one tab in it is a control that does nothing. Do
not change `tutorial_draft.dart`, `tutorial_entry.dart`, `step_tree.dart`,
`tutorial_save.dart` or `tutorial_draft_service.dart`.

**Add no new files.** The panes are private methods of the screen, not new
widgets — `test/tutorial_studio_test.dart` asserts that
`tutorial_studio_screen.dart` itself names `ChessBoardWithOverlay(`,
`AnalysisMoveTreeWidget(`, `MoveNavigationControls(` and `AnalysisNodeCursor(`,
and moving any of them into a file of its own turns that test red. The one new
file is the gate you are told to copy in. If you believe a widget has to be
extracted for this to work, **stop and say so in the report.**

If a file named here is missing, **stop and say so in the report.** Do not find
the nearest plausible file and edit that.

## The contract, exactly

**It is written out in the header of
`docs/gates/tutorial_raspored_test.dart`.** Read that header first — all of it —
and treat it as the specification.

The three that will cost you if you get them wrong:

* **No new user-facing string, and no existing one edited.** This batch moves
  widgets; every sentence on that screen is already written and already
  approved. A new string means you invented copy, and a changed one means you
  rewrote somebody's wording to make your own layout fit. The **only** new
  literals allowed are the four widget keys the gate names — `board-pane`,
  `authoring-pane`, `sections-half`, `editor-half` — which are how a layout is
  measured from outside.
* **A `Row` that does not fit is clipped in silence in a release build.** No
  stripes, no assertion — the controls past the edge are simply unreachable.
  460 plus the gaps must still leave the board a sane width at 840, which is
  why the board is clamped and not merely proportional.
* **The panel now lives in a box with a fixed height.** `TutorialSectionsPanel`
  draws its list with `shrinkWrap: true` and `NeverScrollableScrollPhysics`,
  which was right inside a scrolling column and is wrong inside an `Expanded`:
  a tutorial with a dozen parts will overflow. Its list becomes a scrolling one.
  **That is the only change permitted in that file** — its constructor, its
  callbacks and its strings are frozen, and its fourteen tests must stay green.
  Note that the same widget still has to work in the **narrow** layout, where
  its height is unbounded, so an `Expanded` inside it will throw there; the
  throwaway build used `Flexible` with `shrinkWrap: true` kept and the physics
  dropped, which works under both.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read the summary line it
   prints („N issues found") rather than counting matches yourself.
3. Copy `docs/gates/tutorial_raspored_test.dart` →
   `chess_app/test/tutorial_raspored_test.dart`.
   Nine tests. Measured against the tree as it is: **2 passed, 7 failed.** The
   two that already pass are the two that describe what must *not* change — the
   board keeping the whole window below the breakpoint, and a 700 px window
   laying out without an overflow. They must still pass afterwards.

   **Do not edit that file**, except to run `dart format` on it, which is
   expected. If you believe a test in it is wrong, **stop and say so in the
   report** — do not work around it. A workaround that satisfies a test without
   satisfying the rule is worth less than a stopped batch.
4. Build until it is entirely green.

   **No existing test should need an edit of any kind.** The whole layout was
   built once as a throwaway before this task was written, and with the save in
   the AppBar the suite came out green — 1524 passing, 1 skipped — without a
   line changed in any other file. So a red test elsewhere is information: read
   it, and **say so in the report** rather than adding a scroll to work around
   it. Changing what an existing test asserts is not allowed at all.
5. `dart format` every Dart file you touched. Run it; do not report it as run.
6. `flutter test` and `flutter analyze` again. The suite must be higher by the
   tests of the new file and **lower by none** — in particular
   `test/tutorial_studio_test.dart`, `test/tutorial_delovi_test.dart`,
   `test/tutorial_authoring_test.dart`, `test/tutorial_section_titles_test.dart`
   and `test/tutorial_studio_fields_test.dart` are all untouched and all stay
   green. The analyzer list must be the same list, with **nothing new
   suppressed** — no new `// ignore:` and no new `ignore_for_file`.

## The report

`REPORT-batch-58.md`, in the repository root. It must contain:

* the test count **before and after**, both measured by you in this run;
* the analyzer summary line and list before and after, and the word „identical"
  or the difference;
* whether you added any `// ignore:` or `ignore_for_file` — in a line of its
  own, even if the answer is no;
* the exact list of files you changed or added;
* **proof of the property, not the mechanism**, and for this batch that is
  measurement, not description. From your own run, at a window of 1600×1000:
  the measured width of the authoring pane, the measured width of the board,
  and the two panels' heights. „It uses `SizedBox(width: 460)`" is not proof the
  board got the rest — a `Row` that overflows also contains one;
* **every test outside the gate that went red at any point**, and what you did
  about it — the expected answer is „none";
* **the independent scroll, measured the same way**: the sections panel's offset
  before and after you scroll the pane under it. It must not move;
* what the layout does at 840 exactly, and at 839 — the width where it changes
  shape;
* anything this task or the brief got wrong. A correction is worth more to us
  than a clean report.
