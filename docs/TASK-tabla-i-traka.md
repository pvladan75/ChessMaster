# TASK — the board says what was just played, and what it is called

This file plus `docs/brief-tabla-i-traka-2026-09.md` are the only context you
get. **Do not rely on any conversation before them.** Read the brief first; it
holds the API contract, the reasoning and the pass conditions.

Branch: `design/tabla-i-traka`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 2 of `docs/PLAN-REPERTOAR-2.md`, requirements 1 and 7, and nothing else.
Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** No new endpoint, no new table, no
change to what any position means. Everything this batch needs is already on
`master` and frozen.

If the job turns out to need a change outside `chess_app/lib/` and
`chess_app/test/`, **write in your report which change and why, then stop.** Do
not widen the scope.

## What you need before starting

* Flutter, and `flutter test` green before you change anything. **Measure the
  count yourself and report it; do not trust a number quoted at you.** It should
  be 1068 passing and 1 skipped.
* **No backend, no database, no credentials.** You do not need them and must not
  ask for them. Fake the client the way `chess_app/test/repertoire_gate_test.dart`
  already does — `class _FakeApi extends RepertoireApiService` over a
  `MockClient`.
* Every new widget test must pump at `Size(360, 640)`. §5 of the brief says why
  this is not optional.

## Where things are

| | |
|---|---|
| `chess_app/lib/widgets/game_screen/chess_board_with_overlay.dart` | the widget that gains two parameters. Its `lastMoveSquares` static already computes them |
| `chess_app/lib/widgets/board_overlay_painter.dart` | `ChessBoardPainter`, which **already draws** the highlight. Do not edit it |
| `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart` | tracks from/to, gets the banner |
| `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart` | the same |
| `chess_app/lib/features/analysis_studio/services/opening_book_service.dart` | `lookupByFen`, and the `compute()` trap |
| `chess_app/lib/features/analysis_studio/screens/analysis_studio_screen.dart` | an ECO banner already written, around line 1681 — read it, do not import it |
| `chess_app/test/repertoire_gate_test.dart` | the fake-API pattern to copy |

## The changes, in this order

### 1. `ChessBoardWithOverlay` takes the two squares

Add `final String? lastMoveFrom;` and `final String? lastMoveTo;`, both
optional, defaulting to null, and forward them to **both** `ChessBoardPainter`
instances — the drawing-mode one and the `if (!widget.isDrawingMode)` one. There
are two, at roughly lines 296 and 314. Passing only one is the bug this step
exists to avoid: the highlight would vanish the moment drawing mode was entered.

Nothing else about the widget changes, and no existing caller is edited — both
parameters are optional, so every screen that does not pass them behaves exactly
as it does today.

**Test:** a widget test that pumps the board with the two squares set and
asserts the painter received them. Prove the property, not the mechanism — see
§6 of the brief.

### 2. The build screen and the drill screen track the move

Both keep `String? _lastMoveFrom` / `_lastMoveTo` in state and pass them down.
Set them when a move is played on the board, and **clear them** when the board
jumps somewhere that was not reached by a move — a new position loaded from the
walk, a node tapped in the tree, a line replayed from the start. A stale
highlight pointing at squares from the previous position is worse than none.

`ChessBoardWithOverlay.lastMoveSquares(game)` already computes the pair from a
`chess.Chess`. Use it rather than tracking the squares by hand where the game
object is available.

### 3. The ECO banner

A new widget, `chess_app/lib/features/repertoire/widgets/opening_banner.dart`,
above the board on both screens. It shows `ECO · Name` for the position, and
follows the **last-named-position rule** in §2.3 of the brief: deep positions are
not in the dataset, and the banner must keep showing the last name it had rather
than going blank four moves into a line.

It must take an **injectable lookup**, defaulting to the real service. §2.4 of
the brief explains why a widget test cannot use the real one.

**Test:** one file, `chess_app/test/repertoire_opening_banner_test.dart`, with at
minimum: a named position shows its name; a position the lookup does not know
keeps the previous name; and a pump at `Size(360, 640)` with a long opening name
where `tester.takeException()` is null.

That exact path is allowed for in the harness. **A test file by another name will
fail the untracked-tree gate.**

## The files you may add

Exactly these two, and no others. The harness allows for them by name; **a file
by another name fails the untracked-tree gate and takes the whole round with
it**, which has already cost this project two rounds of agent time.

| path | what |
|---|---|
| `chess_app/lib/features/repertoire/widgets/opening_banner.dart` | step 3 |
| `chess_app/test/repertoire_opening_banner_test.dart` | its test |

Everything else is an edit to a file that already exists. If you believe you need
a third file, **say so in the report and put the code in one of the two** — do
not add it and hope.

Leave no scratch files: no `.py` helpers, no notes, no `.bak`. Four runs out of
four have left scratch files behind and every one of them failed this gate.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Work in the order above — each step compiles and tests green before the next.
3. Reuse what exists. The painter, `lastMoveSquares`, `Breakpoints`, `AppText`,
   `AppSpacing` and `context.colors` are all already written; a second copy of
   any of them fails the batch on review even if the gates pass.
4. If a file this task names does not exist, **stop and say so.** Do not
   substitute the nearest plausible file.
5. `dart format` every Dart file you touch.
6. `flutter analyze` must stay at **29** issues — all `info`, all
   `curly_braces_in_flow_control_structures`, in the six files listed in §6 of
   the brief. It does **not** exit clean and never has. Zero errors, zero
   warnings, no new infos: compare the list, not the exit code.
7. `flutter test`. Report the count and the delta from your own starting number.
8. Leave no scratch files in the tree.

## What must hold

* **User-facing strings stay Serbian.** The users are Serbian children and
  trainers. Code comments and your report are English.
* **Never use `ScaffoldMessenger` directly** — `AppFeedback` only.
  `test/app_feedback_guard_test.dart` fails if a raw call comes back, and the
  reason is in §5 of the brief.
* **Colour is never the only carrier of a fact.** §5 again; this one is not
  negotiable and not a matter of taste.
* Do not edit `board_overlay_painter.dart`. The drawing is done.
* Do not touch the Analysis Studio's own last-move layer. It already works.

## Your report

Write `report-tabla-i-traka.md` in the worktree root. It must state:

1. `flutter test` count before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after — the count, and whether the set
   of files changed;
3. every file you added user-facing strings to;
4. **how you proved the highlight reaches both painters** — naming the two call
   sites is not proof; the broken version had two call sites too;
5. **how you proved the last-named rule** — a test that walks past the end of
   the dataset and still reads a name;
6. anything the brief got wrong.

**Do not claim a number you did not compute in that run.** A correction is worth
more than a clean report.
