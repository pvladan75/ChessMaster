# Brief: the repertoire build screen gets its tree, on one screen

Written 31.8.2026 for one batch. This is step 1 of
[PLAN-REPERTOAR.md](PLAN-REPERTOAR.md) and nothing else.

## Why this job exists

The project owner built a repertoire for the first time and said the process is
confusing. The reason is structural: the screen asks you to build a tree while
never showing you the tree. Every question is one position with a breadcrumb
above it, so every answer is a decision made blind.

A graphical tree does exist — `RepertoireTreeScreen` — but it is a **separate
screen**, so looking at what you are building means leaving the board and coming
back. The owner's words: *"ne znači mnogo ako korisnik mora da promeni ekran da
vidi stablo poteza pa da se vraća."*

There is also a plain waste: the board is capped at 420 px, so on a 1900 px
window most of the screen is empty — while the thing he wanted to see was one
navigation away.

**This batch changes layout only.** No new endpoint, no new table, no change to
what any position means. If you find yourself editing anything under
`chess_backend/`, you have misread the brief.

## What already exists, and must be reused rather than rebuilt

**`AnalysisMoveTreeWidget`**
(`chess_app/lib/features/analysis_studio/widgets/move_tree_widget.dart`) is the
answer to this problem that the app already has. Analiza has no separate tree
screen; it embeds this panel. It provides, already working:

* a toggle between PGN text and the graphical tree,
* a height cap (420) so it sits under a board without eating it,
* a fullscreen button (`_openFullscreen`) showing the same tree at 85 % height,
* and in fullscreen, closing on a node tap, so a jump lands you back at the
  board.

Take that widget as it is. Do **not** write a second tree, and do not copy
`VisualMoveTreeWidget` into the repertoire feature.

**`Breakpoints.isWide(context)`** (`chess_app/lib/theme/breakpoints.dart`, 840
dp) is the app-wide answer to "is there room for two columns". Use it. Do not
introduce another threshold.

**`RepertoireTreeScreen`**
(`chess_app/lib/features/repertoire/screens/repertoire_tree_screen.dart`) holds
the conversion this batch needs: `_convert` turns a `RepertoireTree` into an
`AnalysisNode` tree, and `_markOf` writes the per-card marks (`★`, a share
percentage, `?`, `…`, `✂`). Move those out into a widget; do not rewrite them.

**`numberedLine`** (`chess_app/lib/features/repertoire/line_text.dart`) numbers a
line the way a book does. Already shared by both repertoire screens.

## The API contract — frozen, and complete for this batch

No route changes. Everything needed is on master and working:

* `GET /repertoire/tree?color&rootFen&rootPath&minRating&maxPly` →
  `RepertoireApiService.repertoireTree(...)` → `RepertoireTree`. Costs no
  Lichess quota. Returns `{root, state, children[], maxPly, truncated}`; each
  node has `uci, san, fen, mine, role?, share, state, children[]`, where `state`
  is `open` / `unopened` / `cut` / `decided`.
* Everything the build screen already calls stays exactly as it is.

If you believe you need a new endpoint to finish this batch, **stop and say so
in the report** rather than inventing one.

## What to build

### 1. The tree becomes a panel on the build screen

`RepertoireBuildScreen` gains the tree. It loads it through
`repertoireTree(...)` alongside the walk it already loads, converts it with the
code moved out of `RepertoireTreeScreen`, and renders it with
`AnalysisMoveTreeWidget`.

* `activeNode` follows the position on the board.
* Tapping a node moves the board to that position — the tree **is** the
  navigation. The build screen's question panel follows it.
* Refresh the tree after a move is kept, after a cut, and after a branch is
  restored. It costs no Lichess quota, so a re-read is acceptable; a local patch
  is nicer if it is not fiddly.

`RepertoireTreeScreen` stops being a screen: delete it and its route wiring in
`repertoire_list_screen.dart`, and delete its test file, moving any assertions
that still mean something onto the new panel. The fullscreen view survives
inside `AnalysisMoveTreeWidget` and must keep working.

### 2. Two layouts

**Wide (`Breakpoints.isWide`)** — two columns: board plus question and controls
on the left, the tree panel filling the rest on the right. The board is capped
at 420, so the left column should be about 460–520; the tree takes what is left.

**Narrow** — one column, exactly the order it has now, with the tree panel added
**below** the controls, collapsed to its default height. No navigation.

### 3. The strip

A single row directly under the board, on both layouts, always visible: the
parent move → the current position → its children, each with its mark (`★`, the
share percentage, `?`, `…`, `✂`). Tapping an entry navigates there, same as the
tree.

This is the part of the tree you need while answering a position, and it is the
only part that is readable at 360 dp. Keep it to one row with horizontal
scrolling; it must never wrap into a block that pushes the controls off screen.

### 4. The board grows on wide screens

The 420 cap is a phone number. On a wide window take the smaller of (available
column width − padding) and something the height allows, up to about 560. Do not
let the board push the question panel off the bottom.

## Rules that bite

* **`flutter analyze` does not exit clean and has not for a long time.** It
  reports exactly **29** issues, every one an `info` of
  `curly_braces_in_flow_control_structures`. What must hold is: zero errors,
  zero warnings, and **no new infos**. Compare the list, not the exit code.
* **Run `dart format` on every Dart file you touch.** CI does not enforce it and
  an unformatted file turns the next diff into noise.
* **A release build paints no overflow warning.** In a *test* build an overflow
  throws, which is why every screen here has a 360 × 640 widget test. Write one
  for each layout — 360 × 640 and something wide such as 1400 × 900 — and assert
  `tester.takeException()` is null after the interactions.
* **Serbian stays Serbian.** Every user-facing string in the app is Serbian; the
  users are Serbian children and trainers. Code comments and this report are
  English.
* **Do not touch `chess_backend/` at all.** Not a route, not a service, not a
  test.
* **If a file this brief names does not exist, stop and say so** in the report.
  Do not substitute the nearest plausible file.

## How this will be judged

By machine, not by the report:

* `cd chess_app && flutter test` — the count must be **≥ 985** and the suite
  green (1 skipped, the golden group, is expected). Measure it yourself before
  and after; do not trust a number quoted at you.
* `cd chess_app && flutter analyze` — 29 issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Any error, any warning, or a
  thirtieth info fails the batch.
* `dart format --output=none --set-exit-if-changed` over the files you touched.
* The orchestrator's own gates (`python orchestrate.py verify`), including the
  untracked-tree gate: **do not commit**, and do not leave scratch files behind.
  Three runs out of three have left one.

## What the report must contain

`report-repertoar-raspored.md` in the repository root. Numbers you computed in
this run, not adjectives:

1. Test count **before** and **after**, both measured by you.
2. The analyze list before and after — the count and whether the set of files
   changed.
3. Every file you added user-facing strings to.
4. **Proof of the property, not the mechanism.** "It uses `Breakpoints.isWide`"
   is not proof the wide layout works; a widget test that pumps at 1400 × 900
   and finds the tree and the board on screen together is.
5. Anything this brief got wrong. A correction is worth more than a clean
   report.

## Out of scope

Everything else in `PLAN-REPERTOAR.md`: the `source` column, the auto-spine,
pruning by reachability, the replies panel beside the board, engine notes. Those
are later batches and several of them are the lead's, because they are one-way.

Do not change what any position, move or state *means*. This batch moves pixels
and nothing else.
