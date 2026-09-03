# TASK — the board's own menu, and three switches in it

This file plus `docs/brief-strelice-na-tabli-2026-09.md` are the only context
you get. **Do not rely on any conversation before them.** Read the brief first;
it holds the reasoning, the exact shapes, and the pass conditions.

Branch: `design/strelice-na-tabli`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 1 of `docs/PLAN-JEDNOSTAVNOST.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side.

If the job turns out to need a change outside `chess_app/lib/` and
`chess_app/test/`, **write in your report which change and why, then stop.**

## What you need before starting

* Flutter, and `flutter test` green before you change anything. **Measure the
  count yourself and report it; do not trust a number quoted at you.** It should
  be 1108 passing and 1 skipped.
* No backend, no database, no credentials. You do not need them and must not ask
  for them.
* Every new menu needs a widget test that pumps at `Size(360, 640)`. §5 of the
  brief says why this is not optional.

## Where things are

| | |
|---|---|
| `chess_app/lib/widgets/board_coordinates_button.dart` | the control you are replacing — read its doc comment, the reasoning carries over |
| `chess_app/lib/services/app_settings_service.dart` | `showChosenMoveArrow`, `showStatisticsArrows`, `showEngineArrows` and their setters — **already written, do not add more** |
| `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart` | `_boardArrows()` at 1504 — the three sources meet here |
| `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart` | `arrows:` at 1133, the rehearsal's own arrow |
| `chess_app/lib/features/analysis_studio/screens/analysis_studio_screen.dart` | `engineArrows: _engineArrows` at 1929 |
| `chess_app/lib/widgets/game_screen/chess_board_with_overlay.dart` | takes `arrows` and `engineArrows`; **do not change it** |

## The files you may add

Exactly these, and no others. The harness allows for them by name; **a file by
another name fails the untracked-tree gate and takes the whole round with it.**

| path | what |
|---|---|
| `chess_app/lib/widgets/board_view_menu.dart` | the menu |
| `chess_app/test/board_view_menu_test.dart` | its test |

Everything else is an edit to a file that already exists. Leave no scratch
files: no `.py` helpers, no notes, no `.bak`.

## The changes, in this order

### 1. The menu

`BoardViewMenu` replaces `BoardCoordinatesButton` at **all ten** call sites
(`grep -rn "BoardCoordinatesButton" lib`). Same icon position in the app bar,
same app-wide settings behind it.

It always offers **coordinates**. It offers the three arrow switches only when
the screen says it draws arrows — `BoardViewMenu(arrows: true)` — which is true
on exactly three screens: the repertoire build screen, the repertoire drill
screen, and the Analysis Studio. Everywhere else the menu is the coordinates
switch it replaces, and looks it.

Delete `board_coordinates_button.dart` once nothing imports it. A widget nobody
can reach is worse than one nobody wrote.

### 2. The switches actually switch something

* **`repertoire_build_screen.dart`, `_boardArrows()` (1504).** Three sources
  meet in that method and each one answers to its own switch: `_replyArrows` and
  the `_shareArrows` branch are the **statistics**, `_engineArrows()` is the
  **engine**, `_keptArrows()` is **your chosen moves**. Off means that source
  contributes nothing; it does not mean the method returns early, because the
  next source down is still allowed to draw.
* **`repertoire_drill_screen.dart` (1133).** `_prefixArrow` is the move the
  rehearsal is showing you — the chosen-move switch.
* **`analysis_studio_screen.dart` (1929).** `_engineArrows` — the engine switch.

### 3. It survives a restart, and the board redraws at once

The settings are already persisted; what you must not do is read them once into
a field. `AppSettingsService` is a `ChangeNotifier` and the board has to follow
it — flipping a switch redraws the board **without leaving the screen**.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Reuse what exists: `AppSettingsService`, `ListenableBuilder`, `AppFeedback`,
   the theme. A second copy of any of them fails the batch on review even if the
   gates pass.
3. `flutter analyze` must stay at **29** issues — all `info`, all
   `curly_braces_in_flow_control_structures`. Zero errors, zero warnings, no new
   infos: compare the list, not the exit code.
4. `flutter test`. Report the count and the delta from your own starting number.
5. **`dart format` every Dart file you touched — last, after everything else is
   green.** Two earlier batches were failed by this.

## What must hold

* **User-facing strings stay Serbian.** Code comments and your report are
  English.
* **Never use `ScaffoldMessenger` directly** — `AppFeedback` only.
* **Colour is never the only carrier of a fact.** A switch that is on must be
  readable as on without seeing its colour.
* **Do the thing, then say it.** A message must never be able to take down the
  action it reports on.

## Your report

Write `report-strelice-na-tabli.md` in the worktree root, stating:

1. `flutter test` count before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after — the count, and whether the set
   of files changed;
3. every file you added user-facing strings to;
4. **how you proved each switch reaches the board** — not that the setting was
   written, but that the arrow stopped being drawn. Describing the code is not
   proof;
5. **how you proved the board redraws without leaving the screen**;
6. every call site of `BoardCoordinatesButton` you replaced, and the file that
   still imports it if any does;
7. anything the brief got wrong.

**Do not claim a number you did not compute in that run.** A correction is worth
more than a clean report.
