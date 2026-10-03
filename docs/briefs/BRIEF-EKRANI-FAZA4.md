# Brief: PLAN-EKRANI phase 4 — the room

Read `docs/PLAN-EKRANI.md` §3 (rules R1–R8) and **Phase 4** under §5, and look
at `docs/skice/ekrani/compare_room.png`: the owner chose **AFTER B** and the
**student's seat as drawn**. Where this brief and the picture differ, the
brief wins; it says where and why.

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` and `analyze` rewrite the generated plugin registrant
files under `linux/`, `macos/` and `windows/`; revert them, they are not yours.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## The screen and the gate

- Screen: `chess_app/lib/screens/chess_game_screen.dart` (`ChessGamePage`,
  about 3470 lines — read `build`, `buildLeftSidebar`, `buildRightSidebar`,
  `_buildMoveTreeSection`, `_buildArrowEditButtons`, `_buildStudentStrip`).
- Also: `chess_app/lib/features/exercises/widgets/make_exercise_sheet.dart`
  (`MakeExerciseButton` — only the room uses it; it may draw as a quiet row).
- Gate: `chess_app/test/room_layout_test.dart`, 15 cases, written by the lead.
  Ten are red on master for the reason each names; five are green on master
  on purpose (see the comments above them) and must stay green.

## What to build

1. **Window — the board takes the height (B).** Move the engine panel
   (`_buildStockfishAnalysisWidget()`) from under the board to the top of the
   Moves column. Size the board from the height the middle column actually
   has (window height − the bar − the strip − the student's answers when
   seated as a student − the evaluation bar when it is shown − spacing), bound
   by the column's width as today, times `boardSizeScale` as today. The
   middle column must not scroll at 1536 × 792 or at 900 × 700. A
   `LayoutBuilder` around the middle column is the natural way; do not guess
   the bar's height from a constant if you can read the constraint.
2. **Window — the Moves column.** The tree (`MoveHistoryView`) takes what the
   column leaves, never less than 150; the column scrolls only when its
   contents are taller than the window (the engine's lines, the arrow colours
   while drawing). Measured on master at 1536 × 792: the column is already
   ~37 px longer than the window, and the engine panel is ~180 px tall at this
   width — so the room for the tree comes from the quieter buttons (see 4).
   Drop the „Move tree" sub-label under „Moves" if you need its 25 px.
3. **The Board column.** Wrap the actions in a widget with
   `key: Key('room-board-actions')`. One quiet list of words, none filled:
   `TextButton.icon` (or a `ListTile`) aligned left, full width, at least 40
   tall. In this order: `Set up position…`, `Paste FEN…`, `Import PGN…`,
   `Export PGN`, `Save position`, `Save analysis`, `Make exercise` (the last
   only where it is offered today). `Paste FEN…` opens
   `AnalysisBoardSetupDialog(initialTab: BoardSetupTab.fen)` — exactly how
   Analysis opens it — and the FEN `TextField` with its button goes, with
   `fenPasteController` if nothing else reads it. Keep the keys
   `prep-export-pgn` and `prep-save-analysis` on their actions.
4. **The Moves column's buttons.** `To main line`, `Delete variation` and
   `Insert evaluation into comment`: `TextButton.icon`, the first two on one
   row where they fit. The arrows: today's words and behaviour
   (`Draw arrows` ↔ `Done drawing`, `Undo arrow`, `Clear all arrows`, the
   colour row while drawing), quiet — no filled or tinted slab; `Draw arrows`
   may stay outlined so its state reads by its word and its icon. The heading
   `Arrow drawing (Trainer)` keeps its text (two tests read it).
5. **The student's seat.** The Board column keeps `Export PGN`,
   `Save position`, `Save analysis` and the Library; `Set up position…`,
   `Paste FEN…` and `Import PGN…` are drawn only when `isLeader`. The four
   answers in `_buildStudentStrip` stand on one row under the board on a
   window: `Show my position to trainer` outlined, the three answers as
   `TextButton`s; on a phone they still wrap.
6. **The phone held upright** (not wide, not `LandscapeBoardLayout`). Under
   the board: the strip, then (student) the answers, then the tree, then one
   `Wrap` of `To main line`, `Delete variation`, `Comment…` and the arrow
   controls (leader), then the engine last. The comment field is **not** in
   the column: `Comment…` opens it on its own — a modal bottom sheet with the
   field (`key: Key('room-comment-field')`, the same `commentController`, so
   what is typed is the move's) and `Insert evaluation into comment`, padded
   by `MediaQuery.viewInsets` so the keyboard does not cover it.
   **The picture put the arrows in a sheet; they stay inline**, because
   drawing needs the board and a modal sheet blocks it. On a window the
   comment field stays in the Moves column with the same key. A move's
   comment stays readable without a tap — `MoveHistoryView` already draws
   comments in the tree; check it on the phone render.
7. **Held sideways** (`LandscapeBoardLayout`): the engine is already in the
   panels; whatever you do to `buildRightSidebar`, the engine is drawn once
   (the gate's „one engine panel" cases). Nothing else changes there.

## Rules

- The gate green; every other test green; `flutter analyze` at the same 10
  infos as `master` (`CLAUDE.md`, „Commands").
- **Existing tests:** sixteen test files pump this room. A test that reads an
  old label you renamed (`Set up position`, `Import PGN`, `Paste FEN string...`)
  is rewritten **openly** to the new name, with a line saying why — never
  deleted, never weakened. Known readers: `room_prepared_line_test.dart`
  („the board panel still ends above the fold" — keep its rule, update its
  names), `home_map_test.dart` („the new names are there"),
  `room_teaching_tools_test.dart`, `room_drawing_test.dart`,
  `room_screen_test.dart`, `room_not_recorded_test.dart`. Grep the shared
  helpers in `test/support/` too, not only the widget's name.
- `site/` quotes the app's labels and `manual_labels_test` holds it: grep
  `site/` for every label you change and correct the manual where it names the
  room's old buttons.
- Every `Key` an existing test uses stays.
- `dart format` every Dart file you touch.
- Run the gate, then every test file that pumps `ChessGamePage`, then the full
  suite (base 5715, 1 skipped, per `CLAUDE.md`). A test you did not touch that
  fails under load is run alone before it is believed.
- Render with `chess_app/test/support/render_look.dart` (`robotoTheme`,
  `loadRenderFonts`, `capture`) at 1536 × 792 (trainer and student), 900 × 700
  (trainer) and 360 × 640 (trainer, after one move, and with the comment
  sheet open), and look at every picture. Delete the scratch render test
  before committing.
- One commit on your branch.

## The report

First, **what the brief or the gate got wrong**. Then what changed, the
numbers you measured (the gate before/after, the board's size at each window,
the tree's height at 1536 × 792, the full suite, analyze), which existing
tests you rewrote and why, and anything you know is untested.
