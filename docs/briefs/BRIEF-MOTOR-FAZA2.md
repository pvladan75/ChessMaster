# Brief: PLAN-MOTOR-I-PANELI phase 2 — `PositionLookups`, and Analysis onto it

Read `docs/PLAN-MOTOR-I-PANELI.md` (§1, D8, phase 2). The owner accepted
D1–D9 as recommended on 3.10.2026.

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` and `analyze` rewrite the generated plugin registrant
files under `linux/`, `macos/` and `windows/`; revert them, they are not yours.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## The gate

- `chess_app/test/position_lookups_test.dart` (7 cases) — the class.
- `chess_app/test/analysis_lookups_test.dart` (4 cases) — Analysis on it.

Neither compiles until the class exists; read both before writing anything,
they are the specification.

## What to build

1. **`chess_app/lib/core/services/position_lookups.dart`**, a `ChangeNotifier`:
   - `PositionLookups({SyzygyTablebaseService? tablebase, OpeningExplorerService? explorer})`,
     defaulting to each service's `instance`.
   - `void show({bool? tablebase, bool? explorer})` — a `null` leaves that
     panel as it is. Showing a panel asks for the position already looked up;
     hiding one clears what it showed (and drops its answer in flight).
   - `void lookUp(String fen)` — asks each **shown** panel about `fen`; a
     hidden panel asks nothing. The tablebase only when
     `PositionInfoService.analyzeFen(fen).isSyzygyReady`, always with
     `mateDistance: true`.
   - Read: `tablebaseEligible`, `tablebaseLoading`, `tablebase`
     (`SyzygyResult?`); `explorerLoading`, `explorer`
     (`OpeningExplorerResult?`), `explorerReason` (`String?`).
   - A request id per look-up, as Analysis has today: a late answer for an
     older position is dropped. After `dispose` nothing is told and nothing
     throws.
   - `static String openingName(String fen)` — the banner's text, moved from
     Analysis's `_buildPositionInfoPanel` (ECO and name from
     `OpeningBookService` outside the endgame, else the phase's name), so
     Preparation and the studio draw the same words.
2. **Analysis onto it.** `AnalysisStudioScreen` takes an optional
   `PositionLookups? lookups` (owned and disposed by the screen when it made
   it, not when it was given one). Its `_syzygy*` / `_openingExplorer*`
   fields and the two `_fetch…IfEligible` methods go; `_triggerEngineAnalysis`
   and `_initEngine` call `lookups.lookUp(fen)`; the panels read the class.
   The screen tells it which panels are shown — on arrival and whenever
   `AppSettingsService` changes (it already listens) — from
   `isPanelVisible('syzygy')` and `isPanelVisible('opening_explorer')`; keep
   those reads in the screen, `analysis_panels_test` allows only the screen
   and `analysis_panels.dart` to call `isPanelVisible(`. Moves tapped in a
   panel still go through `_playUciMove`.

## Rules

- The gate green; every other test green; `flutter analyze` at the same 10
  infos (`CLAUDE.md`, „Commands"). Analysis's own tests
  (`analysis_*_test.dart`, `syzygy_*`, `opening_*`) unchanged and green.
- No change to what Analysis shows or to its words.
- `dart format` every Dart file you touch.
- The full suite at the end: base **5734** + 11 = **5745**, 1 skipped. A test
  you did not touch that fails under load is run alone before it is believed.
- One commit on your branch. Do not push. Do not start any server.

## The report

First, **what the brief or the gate got wrong**. Then what changed, the
measured numbers (gate, the Analysis test files, full suite, analyze), and
anything you know is untested.
