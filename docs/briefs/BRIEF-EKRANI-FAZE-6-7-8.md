# Brief: PLAN-EKRANI phases 6, 7 and 8 — the tour, the player, the groups

One brief, three workers: each takes **one** of the three sections below, on
its own branch, with its own gate. Read `docs/PLAN-EKRANI.md` §3 (rules
R1–R8) and your phase under §5, and look at your screen's picture in
`docs/skice/ekrani/` (`compare_walk.png`, `compare_player.png`,
`compare_groups.png`): the AFTER half is what the owner chose.

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
- Every `Key` the existing tests use stays on the widget it marks, or moves
  with it, unless the gate says otherwise.
- `dart format` every Dart file you touch.
- Run your gate, then every test file that pumps your screen, then the full
  suite (`flutter test`; 5678 passed and 1 skipped on the base, plus your
  gate's cases and whatever you add). **Two other workers run at the same
  time**: a test you did not touch that fails in the full run is run alone
  before it is believed; name any such test in the report. Write your logs
  under a name with your phase in it, never a shared `full.log`.
- Render the real screen with `chess_app/test/support/render_look.dart` (a
  scratch test, deleted after) at 1536 × 792, 900 × 700 and 360 × 640, and
  look at it. Say what you saw.
- One commit when green, ending with the attribution line the session gives
  you.
- Report, short and checkable: the full suite's tally and analyze's summary
  line as printed; every existing test changed; **what the brief or the gate
  got wrong**, first.

## Phase 6 — the repertoire tour

Screen: `chess_app/lib/features/repertoire/screens/repertoire_walkthrough_screen.dart`.
Gate: `chess_app/test/repertoire_walkthrough_layout_test.dart` (3 cases).

On a window (`isWide` and a tree) the card from `_buildCard` — the sentence,
the note, the reply chips, „Prepare reply" — goes to the top of the right
column, the tree (`RepertoireTreePanel`) under it, the board and its strip
alone on the left. The board may now take the height of the window, not a
fixed 600. „Prepare reply" becomes a `FilledButton` (R4). The phone and the
phone on its side keep their layout.

## Phase 7 — the recording player

Screen: `chess_app/lib/screens/replay_player_screen.dart`.
Gate: `chess_app/test/replay_player_layout_test.dart` (5 cases).

- **The bar (R5).** On a window: `Open in Analysis`, `Share…` (only where
  offered today) and `Video` as words — `Video` a menu holding
  `Download video` and `Export to MP4…` (each only where offered today);
  `BarWordMenu` (`chess_app/lib/widgets/bar_word_menu.dart`) is the shared
  widget for a word that opens a menu. The board view menu and the flip
  button stay as icons, as in Analysis. On a phone the words are behind one
  ⋮ (`Icons.more_vert`) in the bar. Keep the keys `replay-share` and
  `replay-download-video` on the items that do those things.
- **The transcript (R4).** `Make a tutorial` and `Transcribe…` /
  `Transcribe again…` are `TextButton`s; on a window they stand in one row
  above the sentences (so the list gets the column), on a phone — in the
  transcript sheet — behind a ⋮ keyed `transcript-actions`. Keep the keys
  `transcript-make-tutorial` and `transcript-transcribe` on them.
- **The deck.** The line „Synchronized playback of moves and arrows" /
  „Audio track in sync" goes.
- §2.2 of the plan: on a 360 × 640 phone the open transcript must show at
  least four sentences.

## Phase 8 — Student groups

Screen: `chess_app/lib/features/groups/screens/groups_screen.dart`.
Gate: `chess_app/test/groups_screen_layout_test.dart` (5 cases).

- **The bar (R8).** `New group` in the app bar on every size; no
  `FloatingActionButton`. Today it lies over the last group's ✎ and 🗑.
- **A window (pattern B, R7).** The groups as a list on the left (about 380
  wide), the chosen group on the right: its name and count, `Rename` and
  `Delete group` as `TextButton`s, its members in columns (each with its ✕),
  `Add students` as a `TextButton`. The first group is chosen when the screen
  opens. Choosing another loads its members into the same pane.
- **A phone.** The list alone; a tap opens the group on its own page (a pushed
  route is fine) with the same content and actions.
- The add, remove, rename and delete flows keep their dialogs and their
  requests exactly as today (`chess_app/test/groups_screen_test.dart` holds
  them).
