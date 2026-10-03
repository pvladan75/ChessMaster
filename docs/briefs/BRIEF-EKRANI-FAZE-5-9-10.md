# Brief: PLAN-EKRANI phases 5, 9 and 10 — the exercise editor, My games and Import games, the repertoire comparison

One brief, three workers: each takes **one** section below, on its own
branch, with its own gate. Read `docs/PLAN-EKRANI.md` §3 (rules R1–R8) and
your phase under §5, and look at your screen's picture in `docs/skice/ekrani/`
(`compare_editor.png`, `compare_games.png` and `compare_import.png`,
`compare_diff.png`): the AFTER half is what the owner chose.

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` and `analyze` rewrite the generated plugin registrant
files under `linux/`, `macos/` and `windows/`; revert them, they are not yours.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## Common rules

- The gate's cases all green is the pass condition, with every other test
  green and `flutter analyze` at the same 10 infos (no errors, no warnings).
- An existing test that names the old screen is rewritten **openly** — a
  comment above it saying what changed and what it still protects — never
  deleted to make a run green. Say each one in the report.
- Every `Key` the existing tests use stays on the widget it marks.
- The user manual under `site/` quotes labels and `manual_labels_test` holds
  it to them: grep `site/` for every label you change or move.
- `dart format` every Dart file you touch.
- Run your gate, then every test file that pumps your screen, then the full
  suite (`flutter test`; 5693 passed and 1 skipped on the base, plus your
  gate's cases and whatever you add). **Two other workers run at the same
  time**: a test you did not touch that fails in the full run is run alone
  before it is believed; name any such test. Log under a name with your phase
  in it.
- Render the real screen with `chess_app/test/support/render_look.dart` (a
  scratch test, deleted after) at 1536 × 792, 900 × 700 and 360 × 640, and
  look at it. Say what you saw.
- One commit when green, ending with the attribution line the session gives
  you. Report, short and checkable: the full suite's tally and analyze's
  summary line as printed; every existing test changed; **what the brief or
  the gate got wrong**, first; anything you know is untested.

## Phase 5 — the exercise editor

Screen: `chess_app/lib/features/exercises/screens/exercise_editor_screen.dart`.
Gate: `chess_app/test/exercise_editor_layout_test.dart` (4 cases).

On a window: `TrainerBoardLayout` (`chess_app/lib/widgets/trainer_board_layout.dart`)
— the board sized by the window's height, the panel (`_panels()`: the task,
the answer and its alternatives, the hints) beside it, and the footer (the
variation hint, the error, `Save`) in that panel, `Save` a `FilledButton` of
its own width (the key `exercise-editor-save` stays). On a phone the layout
the shared one gives (board, then `Save`, then the panel is fine; say what you
chose). The phone on its side keeps `LandscapeBoardLayout`. The save sheet,
the leave guard and every flow stay as they are (`exercise_edit_own_test`,
`exercise_edit_lead_test`, `exercise_answer_hold_test` hold them).

## Phase 9 — My games and Import games

Screens: `chess_app/lib/features/archive/screens/archive_home_screen.dart`,
`.../archive_import_screen.dart`. Gate:
`chess_app/test/archive_screens_layout_test.dart` (5 cases).

- **My games**: `Import games` in the app bar (on a phone too), and the
  „Import more games" button at the bottom gone; the players' cards on
  `AdaptiveCardGrid` (`chess_app/lib/widgets/adaptive_card_grid.dart`), each
  card its name, its count, its delete, and the three doors as `TextButton`s
  of one kind with their labels unchanged; recent imports under the cards.
- **Import games**: one centred column (about 620 wide) — the username field,
  `Select PGN file` as the one `FilledButton`; the running and the finished
  import in a card under it: „Import completed" said there instead of the
  `AppFeedback.success` snackbar, the four figures (read, stored, already
  there, skipped) and the reasons, and the three doors as `TextButton`s. A
  failure that is the import's own may stay as it is said today; say what you
  did.

## Phase 10 — the repertoire comparison

Screen: `chess_app/lib/features/archive/screens/repertoire_diff_screen.dart`.
Gate: `chess_app/test/repertoire_diff_layout_test.dart` (3 cases).

On a window: White / Black and the three figures on one row; the deviations
as a compact list or table one glance wide (move, prepared, played instead,
games) on the left; the chosen deviation's position on a `BoardThumbnail`
(`chess_app/lib/widgets/board_thumbnail.dart`) beside it, with `Open in
Analysis` (the analysis route, as other screens open a position) and `Games
through this position` (`PositionGamesScreen`) as `TextButton`s. The first
deviation is chosen on opening. **The pane asks the server nothing** — every
row already carries `fen` and `fenKey`. On a phone the list, and a tap shows
the position (under the row, or on a page of its own — say which).
