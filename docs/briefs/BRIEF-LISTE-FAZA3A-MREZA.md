# Brief — lists, phase 3a: templates and puzzle sets onto the grid

`docs/PLAN-LISTE.md`, phase 3a. **App only.** Do not touch `chess_backend/`,
`db.js`, `.env`, `deploy/`, or anything in `docs/` other than reading it. Do
not start a server.

**Two rules about your own processes**: do not search the disk from `/` (or
`C:\`) — package sources are under the paths in
`chess_app/.dart_tool/package_config.json`; and **run `flutter test` in the
foreground and wait for it**. It takes about nine minutes on this machine,
most of it `game_tutorial_run_test`. Your report must state that no process
you started is still running, and how you confirmed it.

**If you believe a test in the gate is wrong, stop and say so in the report —
do not work around it.** A workaround that satisfies a test without satisfying
the rule is worth less than a stopped phase.

## The point of the phase

The owner: *when I said there is a lot of space on a wide screen, I did not
mean it should be cut down by capping the item width; I meant it should be
used.* A wide window must show **more items**, not the same items stretched.
`ListTile` cannot do that — its three slots keep their intrinsic size and only
the gap between them grows.

Phase 2 built the one home for the answer:
`chess_app/lib/widgets/adaptive_card_grid.dart`. **Use it. Do not write a
second grid, and do not pass it a column count — it has none.** It works the
count out from the constraint it is handed, which is why the phone is
unchanged by construction.

## The two targets

### 1. `features/homework/screens/homework_list_screen.dart`

A `ListView.separated` of `Card` → `ListTile` (line ~159). Move the rows onto
`AdaptiveCardGrid`.

**The keys are load-bearing and must not change**: `homework-list-row-$id`,
`homework-list-send-$id`, `homework-list-delete-$id`.
`homework_side_and_delete_test.dart` and `homework_editor_doors_test.dart`
reach a row through them, and **you may not edit either file**. The key must
stay on a widget whose top-left is the card's, because the gate measures where
rows are painted.

What a row says does not change: the title, and `N items · sent to M`.

### 2. `features/analysis_studio/widgets/saved_puzzle_sets_dialog.dart`

A `Column` of `Card` → `ListTile` inside `Container(width: 460)`. Move the
sets onto `AdaptiveCardGrid`, and **take the dialog's size from
`MediaQuery`** — a dialog fixed at 460 cannot fit two columns of cards, so the
grid alone would change nothing.

**This dialog has a bug on master and fixing it is part of the phase.** At
360 × 640 it overflows: `A RenderFlex overflowed by 1.3 pixels on the right`.
`Dialog`'s default insets leave about 280 for a `Container` asking for 460,
and the row's trailing `Row` — a delete `IconButton` beside an `Open`
`ElevatedButton` — does not fit in what is left. A **release build paints no
overflow warning**; it clips silently, so nobody has seen this. The gate has a
case for it.

Follow `features/library/widgets/board_preview_dialog.dart` for how a dialog
in this codebase reads its size, and `widgets/game_selector_dialog.dart` for
the version written last (phase 1). Note the trap recorded in both:
`AlertDialog` lays title, content and actions out under an `IntrinsicWidth`,
so a `SizedBox` inside one does not get the width it asks for. This dialog is
a plain `Dialog`, which does not do that — but do not assume; measure.

## The gate

`docs/gates/lists_grid_3a_test.dart`. **Copy it byte-identical** into
`chess_app/test/lists_grid_3a_test.dart`. Do not edit it. Run against master
by the lead on 20.9.2026: **4 green, 3 red.**

Red — the work: templates side by side at 1400, sets side by side at 1400, and
the phone overflow.

Green and guarding — the phone still draws one per line (both screens), the
three row keys and the delete confirmation, what a template row says, and that
`Open` still hands over *that* set's puzzles.

Note how the layout cases are written: they read **where cards are painted**,
never a width. Phase 1 learned that a width assertion can pass on master while
the fault stands. You are free about composition as long as the cards land
where the gate says.

## What not to change

- **Do not touch `LibraryList`.** It is phase 3b and it is harder: two
  callers, board thumbnails, and a test helper that reads `ListTile.title`.
- **Do not edit any existing test file.** If you believe one must change,
  stop and say so. Nothing in this phase should require it — that is why these
  two targets were split out.
- **Do not cap any width.** No `maxWidth`, no `CenteredPane`. That is the
  answer the owner rejected.
- **Do not touch the three Home tabs** (`dashboard_tab`, `friends_tab`,
  `teach_tab`) and their `maxWidth: 700`. They stay by the owner's decision.
- Do not change what a row says or what its buttons do.

## Choosing the tile height

`AdaptiveCardGrid.defaultTileHeight` is 112 — a title and two or three short
facts. If a card needs more, pass `tileHeight:`; **do not** change the default
or the 420 width, both of which are shared. Say in your report what you passed
and why.

## How it is graded

- The gate file in `chess_app/test/` **byte-identical** to
  `docs/gates/lists_grid_3a_test.dart`. Checked, not trusted.
- Nothing outside the two source files above and that one new test file.
- No new `// ignore`.
- `dart format` on every Dart file you touched.
- `flutter analyze`: the **same 26 infos**, no new one. Paste the summary line.
- `flutter test` green, full run, foreground. Baseline is **3400 passed, 1
  skipped**; it should rise by the gate's 7 plus any case of your own.
- **Prove the gate can fail on your own code.** Set
  `AdaptiveCardGrid.maxTileWidth` to 2000 locally, run the gate, and report
  which cases go red — the two "side by side" cases must. Revert it, and say
  in the report that you did.

## In your report

In this order: the numbers; the sentence about your own processes; the tile
heights you chose; any case in the gate you think is wrong; and **what this
brief got wrong** — anything it asserts about the code that turned out not to
hold. Write that section even if it is empty.
