# Brief: PLAN-MOTOR-I-PANELI phases 3, 4 and 5 — the panels in Preparation and the studio

One brief, two workers: **phase 3** (Preparation) and **phases 4–5** (the
tutorial studio, window and phone), each on its own branch with its own gate.
Read `docs/PLAN-MOTOR-I-PANELI.md` whole — D1–D9 were accepted by the owner as
recommended on 3.10.2026, and **A** for the studio — and look at
`docs/skice/paneli/compare_panels.png`: the AFTER halves are what was chosen.

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` and `analyze` rewrite the generated plugin registrant
files under `linux/`, `macos/` and `windows/`; revert them, they are not yours.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## Already built — use, do not rewrite

- `chess_app/lib/core/services/board_engine.dart` — `BoardEngine`, the engine
  glue (phase 1). Attach on arrival, as Preparation now does.
- `chess_app/lib/core/services/position_lookups.dart` — `PositionLookups`
  (phase 2): `show(tablebase:, explorer:)`, `lookUp(fen)`, the read getters,
  `PositionLookups.openingName(fen)`. Analysis uses it; read how.
- `chess_app/lib/features/analysis_studio/widgets/analysis_panels.dart` —
  `PanelScope`, `writingPanels`, `writingPanelShown(scope, key)`,
  `setWritingPanelShown`, `writingPanelMenuEntries(context, scope)` (the ▦
  rows, keyed `<scope>-panel-<label>`). **Never** call `isPanelShownIn` /
  `setPanelShownIn` on the settings directly — `analysis_panels_test` forbids
  it; listen to `AppSettingsService` to redraw when a row is ticked.
- The panel widgets: `StockfishAnalysisWidget`, `OpeningExplorerPanelWidget`,
  `SyzygyPanelWidget` (see Analysis's `_buildPositionInfoPanel` for how the
  two look-ups are drawn, with the opening's name).

## Common rules

- The gate green; every other test green; `flutter analyze` at the same 10
  infos (`CLAUDE.md`, „Commands"). An existing test that reads what you
  changed is rewritten **openly** with a line saying why, never deleted or
  weakened.
- A move tapped in a panel is the reader's move (D3). Nothing is written into
  a comment, beat, narration or tree by a panel (D3/D4).
- The board keeps its size and place whatever is switched on (D5).
- Each screen takes optional `engine` (`BoardEngine?`) and `lookups`
  (`PositionLookups?`) parameters for tests, and owns and disposes what it
  made itself, not what it was given.
- `site/` quotes the app's labels (`manual_labels_test`): if you add words a
  manual page should know, say so in the report; do not invent manual text.
- `dart format` every Dart file you touch. Render with
  `chess_app/test/support/render_look.dart` at 1536 × 792, 900 × 700 and
  360 × 640 with the panels on, look at every picture, delete the scratch
  render test before committing.
- The full suite at the end: base **5750**, 1 skipped, plus your gate's 8.
  A test you did not touch that fails under load is run alone before it is
  believed.
- One commit on your branch. Do not push. Do not start any server.

## Phase 3 — Preparation

Screen: `chess_app/lib/features/preparation/screens/preparation_screen.dart`.
Gate: `chess_app/test/preparation_panels_test.dart` (8 cases).

- ▦ (the `BoardViewMenu` in the strip) gets `trailing:
  (c) => writingPanelMenuEntries(c, PanelScope.preparation)`.
- On a window: the box beside the comment (`Key('prep-engine-box')`) holds,
  stacked and scrolling, the engine panel when its row is ticked, then the
  explorer (with the opening's name) and the tablebase when theirs are. When
  nothing is ticked, the comment takes the pane's width. The tree keeps its
  place.
- On a phone: the `Engine` tab holds the same stack (D7).
- The look-ups: `lookups.show(...)` from the ticked rows on arrival and on
  every settings change; `lookups.lookUp(fen)` wherever the engine is asked
  today (`_jumpTo`, `_playMove`, `_setNewRoot`, `_loadPart`). A tapped move goes
  through `_playMove`.
- `preparation_screen_test`'s „no server" group must stay green as it is: with
  the look-ups hidden (the default) nothing is asked.

## Phases 4 and 5 — the tutorial studio

Screens: `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`
and its part `tutorial_studio_phone_layout.dart`.
Gate: `chess_app/test/studio_panels_test.dart` (8 cases).

- **First the strip** (§1 of the plan): at 1536 × 792 the board column is
  32 px taller than its space and `MoveNavigationControls` ends below the
  window. Size the board from what the column really has (the marks row and
  the strip measured or read from constraints, not a guessed `− 120`), so the
  strip is whole on screen; then reserve the evaluation bar's slot beside the
  board as Preparation does (D5), so turning it on later changes nothing; the
  map column (`Key('map-column')`) must still stand beside the board at
  1536 × 792 (the plan's arithmetic: 1040 − 584 − 30 = 426 ≥ 392 — measure).
- ▦ in the studio's strip, `BoardViewMenu(arrows: true, boardSize: true,
  trailing: (c) => writingPanelMenuEntries(c, PanelScope.studio))`, as in
  Preparation.
- **D6 A**: when any row is ticked, a fourth tab `Engine`
  (`key: Key('studio-tab-engine')`) beside Flow · Tree · PGN, holding the
  ticked panels stacked and scrolling. No row ticked — no tab; if the open tab
  disappears, the Flow opens.
- The engine via `BoardEngine` (attached on arrival, off on arrival, released
  when covered — Preparation's `_onShownChanged` is the model);
  `StockfishAnalysisWidget` **without** `onInsertLineAsVariation` and
  `onLoadFenToMainBoard` (D4). The evaluation bar beside the board, in its
  reserved slot, when the engine panel's switch turns it on.
- The look-ups via `PositionLookups`, asked about `cursor.fen` whenever the
  cursor moves (the screen already follows the controller in
  `_onController`); a tapped move goes through the screen's `_onMove` (UCI
  split as Analysis's `_playUciMove` does), so the part rules hold — a second
  move in a part opens a part, a move held back while the PGN tab has text is
  held back, with today's words.
- **Phase 5, the phone**: a third tab `Engine` (same key) beside Line · Parts,
  only when a row is ticked, with the same stack. ▦ in the phone's strip too.
- `tutorial_studio_test`'s „it grows no second board, tree or cursor of its
  own" must stay green.

## The report

First, **what the brief or the gate got wrong**. Then what changed, the
measured numbers (the gate, the board's size at each window, the full suite,
analyze), which existing tests you rewrote and why, and anything you know is
untested.
