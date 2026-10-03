# Screens: one way to lay out a board, a list and an action

Written 3.10.2026 by the lead (Opus), from item 5 of the owner's list of
2.10.2026 („Ekrani za sređivanje"). Nothing in code yet.

Every brief handed to a worker carries this sentence, in its method section:
*If you believe a test in the gate is wrong, stop and say so in the report — do
not work around it.*

Paths: `APP` = `chess_app/lib/`, `T` = `chess_app/test/`,
`SK` = `docs/skice/ekrani/` (the pictures this plan was decided from).

## 1. The request and what the owner decided

The owner, 3.10.2026, translated: the list item said the puzzle screen goes
first, then the other screens he marks, then one plan with shared rules.

The session rendered the puzzle screen as it is (real code, real fonts, at his
window of 1536 × 792 and a 360 dp phone) beside the endgame trainer, the board
screen most recently rebuilt, and drew the puzzle screen in the endgame
trainer's pattern (`SK/puzzle_today_1536.png`, `SK/endgame_today_1536.png`,
`SK/puzzle_proposal_1536.png`, `SK/puzzle_proposal_360.png`). It proposed five
shared rules and put three questions. His answers, the same day:

- **A — yes.** A verdict is said in the panel beside the board, not in a
  dialog: „Puzzle Solved!", „VICTORY!", the „Incorrect Move!" sheet and the
  snackbars all go.
- **B — yes.** On „Find the winning path" and „Basic checkmate" the engine
  panel appears only once the puzzle is solved or failed, so it gives no help
  while the reader is still solving.
- **C — screens 1, 2 and 3** (the room, My mistakes, the tactics trainer), and
  for 4–12 he asked to see each one before and after. Every one was rendered as
  it is and drawn as proposed (`SK/compare_*.png`; the overview of a homework's
  boards and the student's tutorial video with no change proposed,
  `SK/today_*.png`). His answer: **„Sve od 4 do 12 kako si nacrtao, napiši
  plan"** — all of 4–12 as drawn.

So this plan covers the puzzle screen and eleven more: the room, My mistakes,
the tactics trainer, the recording player, the repertoire tour, the exercise
editor, My Assignments, the homework review, a homework's item list, Student
groups, My games with Import games, and the repertoire comparison. The homework
overview (`CustomAssignmentOverviewScreen`) and the tutorial video
(`VideoAssignmentScreen`) are left as they are.

## 2. What the renders showed

Each picture is a real screen rendered by a scratch test with the app's dark
theme and Roboto (the helper is §4.3), so what it shows is what the code draws.

Faults already in the app, found by looking — each is fixed by the phase that
rebuilds its screen, and each phase's gate holds it:

1. **Student groups:** the floating „New group" button lies over the last
   group's ✎ and 🗑 at 1536 × 792 and on the phone (`SK/compare_groups.png`).
2. **Recording player on a phone:** with the transcript open, one sentence is
   visible — „Make a tutorial" and „Transcribe again…" take the rest
   (`SK/compare_player.png`, bottom left).
3. **Repertoire tour at 1536 × 792:** the card that says what the tour is
   saying runs off the window, and its reply chips are not on screen at all
   (`SK/compare_walk.png`).
4. **My mistakes** names moves in UCI: „The best move was e1g1, and you tried
   f3g5" (`APP/features/archive/screens/mistake_drill_screen.dart`, the lines
   that print `bestUci` and `_playerMoveUci`). The owner had already noted it
   on 2.10.2026.
5. **Tactics trainer:** after a solve the rendered screen still said „Moves
   needed: 1 · found 0" (`tactics_trainer_screen.dart`, the line that prints
   `session.solvedMoveCount`). **Not yet known whether this is the app or the
   render's rig** — phase 3 finds out first.

What is wrong with the shape of the screens, in general — the reasons for §3:

- The most important sentence on the puzzle screen, the task, is the smallest
  text on it (11 px in a 24 px header).
- Actions are drawn twice (the puzzle screen's header icons *and* three
  full-width buttons) or as full-width coloured slabs (the editor's „Save", the
  room's Board column, My games' cards).
- Verdicts arrive in five different ways on one screen: two dialogs, a bottom
  sheet, snackbars and a banner.
- On a 1536 px window nearly every list is one card column 1500 px wide with
  its one action at the far right edge (groups, My games, My Assignments, the
  homework list, the homework review, the comparison).
- Boards sized from the width of a column rather than the height of the
  window (the puzzle screen's landscape layout, the exercise editor at 440).

## 3. The rules

These hold for every screen this plan touches, and for any screen built after
it. Each phase's gate holds its screen to the ones that apply.

**R1. A board screen has one layout.** The endgame trainer's: on a window at
least `Breakpoints.wide` (840) wide, the board sized by the window's height
and a panel beside it, the two centred together; on a phone held upright the
panel under the board; on a phone on its side (`LandscapeBoardLayout.applies`)
the existing landscape layout with the panel in its side column. One widget
holds it (§4.1). A screen does not choose between landscape and portrait by
`orientation` — the puzzle screen does today, which is why a desktop window
gets the phone-on-its-side layout.

**R2. The task is in the panel, at reading size.** `titleMedium` or larger,
never in a bar or a header row, and it is the `SpokenLine` the screen says —
the speaker stays beside it, as now.

**R3. A verdict is said where the task is.** In the panel, under the task, in
the panel's message box (good / not good is said in words and by an icon's
shape, never by colour alone — the owner is colourblind). Not a dialog, not a
bottom sheet, not a snackbar. A dialog is kept only where something has ended
and the only way on is to leave (the end of an assigned game, which today
offers only „Back"); even there the verdict is drawn in the panel as well.
`AppFeedback` stays for what is not a verdict — a network failure, a refusal
from the server.

**R4. One filled button per state.** The action the reader most likely wants
next — usually „Next" — is the one `FilledButton`; everything else is a
`TextButton` (or an `OutlinedButton` where a second action must stand out).
No coloured slabs, no full-width buttons on a window, no emoji in a label.

**R5. Each action has one place.** Not an icon in the bar *and* a button. The
bar holds the way back, the title and the screen's menus; where a bar has more
than two actions they are words (`BarWordMenu`, as in Analysis and
Preparation), not a row of unlabelled icons.

**R6. One action, one word, on every screen.** „Try again", „Show solution",
„Open in Analysis", „Next". Labels this plan changes are grepped in `T/` and in
`site/` (the manual quotes labels and `manual_labels_test` holds it to them —
none of the puzzle screen's current labels is quoted there, measured
3.10.2026).

**R7. A list on a window uses the width.** Peer cards: `AdaptiveCardGrid`
(the column count falls out of the width, never written down). A list whose
rows each lead somewhere worth seeing: pattern B, the list beside a pane that
shows the chosen row (as the Library and the Repertoire do,
`docs/PLAN-LISTE.md`). A list whose rows are steps or a form: one column of
reading width, centred (about 620–820 px). A card's action sits beside the
card's own figures, never at the far edge of a 1500 px row.

**R8. Nothing floats over content.** No floating action button over a list; a
„New …" action is in the bar.

## 4. Building blocks

### 4.1 `TrainerBoardLayout` and `TrainerInfoPanel` (phase 0)

`EndgameBoardLayout` and `EndgameInfoPanel` live in
`APP/widgets/endgame_info_panel.dart` and are used by the endgame trainer and
the blunder walk. They are the shape R1–R3 describe, so they become the shared
pieces under names that do not say „endgame": `TrainerBoardLayout` and
`TrainerInfoPanel`, in `APP/widgets/trainer_board_layout.dart`. Nothing about
them changes in phase 0 — a move and a rename, so the endgame screens are
pixel-for-pixel what they were. What the later phases need from them is added
in the phase that needs it, with a case:

- the panel's message box takes an icon whose shape says good / not good (R3);
- the panel takes extra children under the message (the solution tree on the
  puzzle screen, the engine panel after a solve);
- the screen's own choice between the three layouts (R1) is lifted out of
  `endgame_trainer_screen.dart`'s `_buildBody` into one function beside the
  layout, so five screens do not copy it.

### 4.2 Lists

Nothing new: `AdaptiveCardGrid` / `AdaptiveCardColumns` / `AdaptiveCardRows`
(`APP/widgets/adaptive_card_grid.dart`), the Library's pattern B
(`LibraryList` with `onSelect` / `selectedId`, `BoardPreviewPanel`), and
`BarWordMenu`. If a phase finds itself writing a second list-and-pane, it
lifts the Library's into a shared widget first rather than copying it (one
rule, one home).

### 4.3 The render helper

The helper that made the pictures (`loadRenderFonts`, `robotoTheme`,
`capture`) is in `T/support/render_look.dart` since 3.10.2026 — not a test,
never imported by the suite — so the lead's rendered look after each phase is
one short file and not a rebuilt rig. A scratch render test that uses it is
written in a worktree or deleted before the full suite runs. Its limits, measured 3.10.2026: a `RichText` with no
font family (the room's move tree, the review's „Played / Solution" lines) and
a dialog title still draw as boxes, because they take no style from the theme;
the helper documents that rather than hiding it.

## 5. Phases

Each phase is one screen or one pair of screens that share a shape. Each gate
renders its screen with real fonts (`loadRoboto`) at **1536 × 792**,
**900 × 700**, **360 × 640** and the four `landscapePhones`, and asserts:

- nothing overflows (`tester.takeException()` is null at every size);
- the task (on board screens), the verdict after a move, and the one filled
  button are on screen without scrolling at 1536 × 792 and 900 × 700 — with an
  `_expectSeen` that asks every `Scrollable` ancestor, as the repertoire's
  gate does, because a panel laid out below its own scroll box's fold passes
  `expectOnScreen`;
- a board is square (`width == height`), measured — clipping is not overflow;
- exactly one `FilledButton` in each state the phase names;
- what the phase removes is looked for where it would have been drawn.

And after the gate is green, the lead renders the real screen with the §4.3
helper and looks at it before calling the phase done — on the owner's window
and on the phone. A phase is not done on a green gate alone (the 27.9 and 2.10
lessons: the gate's own fixture fit; the real content did not).

### Phase 0 — the shared pieces `[lead]` — built 3.10.2026

**Done:** the two classes renamed and moved to
`APP/widgets/trainer_board_layout.dart` with their test
(`T/trainer_board_layout_test.dart`) and the source path that
`T/speech_endgames_test.dart` reads; nothing else in them changed. Full suite
5605 passed, 1 skipped — the baseline measured in a fresh worktree of
`865a15b0` the same day gave 5604 and one failure, which was the checkout and
not the code (`speech_clips_test` compared `manifest.json` byte for byte, and a
fresh Windows clone writes it with CRLF; the test now compares the text, proved
red on wrong content). `flutter analyze`: the same 22 infos.

- `TrainerBoardLayout` / `TrainerInfoPanel` as §4.1, every reader moved, the
  old file gone (grep `EndgameBoardLayout`, `EndgameInfoPanel` and
  `sideWidth` in `APP/` and `T/`).
- `T/support/render_look.dart` (§4.3) names Roboto in the dialog theme too,
  which one render agent had to patch locally.
- Gate: the full suite, unchanged in count; the endgame trainer's and the
  blunder walk's layout tests green without an edit.

### Phase 1 — the puzzle screen `[implementer]` — built 3.10.2026

**Done** (branch `ekrani-faza-1`, worker's commit `98add0af`, the lead's
grading on top): every item below, the gate green, and on the way two faults
already on master — „Try again" left a mate puzzle with no start to replay
from, and a restart left the solution tree where the last solve ended.
`TrainerInfoPanel` grew a nullable `task` (Basic checkmate and „Play it out"
say no task, as before), `taskLeading`, `taskExtra`, `messageText`,
`messageIcon` and `children`; `TrainerBoardLayout` a `scale`, a `panelWidth`
(the puzzle screen's 340, for the solution tree's header) and — at grading —
`controlsWidth`; and the three-way choice of R1 is `TrainerScreenLayout`, which
the endgame trainer calls too. `flutter analyze` fell from 22 infos to 10:
the twelve in this file went with the rewrite.

**What grading found.** The gate pumped `ThemeData.dark()`, whose buttons are
smaller than the app's: rendered in the app's own theme, the row of four
buttons (507 px) wrapped under a 465 px board at 900 × 700 and „Next" was half
under the window, while the gate passed. The gate now pumps
`robotoTheme(AppTheme.dark)` and went red there („FilledButton is off screen at
900×700"); `TrainerBoardLayout.controlsWidth` gives up a second line's height
when the column is narrower than the buttons, and the board at 900 × 700 is
408 (the gate's 440 assumed one line, and was lowered openly to 400). Proved
by mutation: `controlsWidth: null` turns that case red again. Two more
mutations held: the engine panel shown while solving (gate, two cases) and a
give-up after a wrong move recorded as a skip (the worker's
`puzzle_screen_actions_test`; the gate's own case checks only `solved: false`).

`APP/screens/ai_studio_screen.dart`, all four of its modes (Mate in N, Basic
checkmate, Find the winning path, Play it out) and its retry and assigned
variants. As `SK/puzzle_proposal_1536.png` and `_360.png`:

- **Layout (R1):** `TrainerBoardLayout` by window width, `LandscapeBoardLayout`
  only where it applies; the `orientation` test in `build` and
  `_buildActiveBoardScreen` goes. The bar: back, title, the opponent button
  where it is offered now, `BoardViewMenu`. Nothing else in the bar (R5) —
  the landscape header's Analysis / Try again / Next icons go.
- **Panel (R2):** chips (the mode, „Mate in 1"; the reader's rating), the task
  line as it is spoken now (`_taskLine`, side icon beside it), then the
  verdict, then — once solved, failed or shown — the solution tree
  (`_buildSolutionTreeSection`) and, by B, the engine panel. „Play it out"
  keeps its turn line („Your move" / the engine's) in the panel.
- **Verdicts (A, R3):** one piece of state, „what the panel says now", set
  where each of these is today and drawn in the panel:
  the snackbars „Incorrect move! Try another move.", „Great! Now solve the
  opponent's other defense.", „Congratulations! Puzzle solved! 🎉" (three
  sites), „Engine did not respond. Play your move again."; the „Puzzle
  Solved!" dialog with the new rating; the „Incorrect Move!" bottom sheet
  (`_showFailureDialog`) and its choices; `_showDrillEndedDialog`
  (loss / draw in Basic checkmate); `_showEndgameWinDialog` („VICTORY!").
  Their choices become the panel's buttons. `_showEngineGameEndedDialog`
  stays a dialog only for an **assigned** game, where „Back" is the only way
  on — and there it is the dialog alone, not drawn in the panel as well
  (corrected 3.10.2026 while writing the gate: five tests hold „Goal met" to
  one widget, and twice is one too many); one's own game says it in the panel.
  What is spoken does not change: every verdict is the same `SpokenLine` it is
  today, said when it is drawn (the speech plan's D4).
- **Engine (B):** `StockfishAnalysisWidget` is built only when the puzzle is
  solved, failed or its solution shown, on the modes that have it now, and
  never while an assigned game runs (`_assigned`, unchanged).
- **Actions (R4, R6):** under the board, centred on it: `Try again`,
  `Show solution` (before the end), `Open in Analysis` (where it is offered
  now) as text buttons; `Next` as the one filled button; `Resign` as an
  outlined button while a game of „Play it out" runs. „Analysis 🔬",
  „Try Again", „Next Position" and „Next Puzzle" go.
- The title „Practice: easy (Checkmate Stockfish)" becomes the task in words
  — the panel's chip names the level.
- The file's `curly_braces_in_flow_control_structures` infos that the change
  touches are fixed with it; the new count is measured and written into
  `CLAUDE.md` with the list, never assumed.

Gate (beyond §5's list): a wrong move, a right move, a solve, a failure and a
draw in Basic checkmate each leave `find.byType(AlertDialog)`,
`find.byType(BottomSheet)` and `find.byType(SnackBar)` empty and the verdict's
text in the panel; the engine panel is absent before the end and present after
it on Find the winning path; the speech pilot's **voice** assertions
(`T/speech_pilot_test.dart`, every `rig.voice` line) stay as they are — the
voice is not this phase's to move. Two of its literal expectations name the
old screen (it taps „Next Position" and finds „Incorrect Move!") and are
rewritten openly, with what they protected kept; so is
`landscape_screens_test`'s `byTooltip('Next Position')`.

**The gate is `T/puzzle_screen_panel_test.dart`**, written by the lead on
3.10.2026: 22 cases, 20 red on `e0c870da` for the right reason (no
`TrainerBoardLayout`, a bottom sheet, the dialogs, the engine panel while
solving, no filled button) and none throwing; two green there on purpose, as
guards of what must not change (Mate in N never shows the engine panel; an
assigned game keeps its dialog).

### Phase 2 — the tactics trainer `[implementer]` — built 3.10.2026

**Done** (worker's `5f4e6891`, the lead's `bb6f299b`): `TrainerScreenLayout`,
the header card and the rating card in `TrainerInfoPanel`, `Skip` / `Next`
the one filled button, `Show solution` a text button, the counter counting the
reader's moves (`ceil`; reverting it turns three gate cases red). No addition
to the shared widgets, no `controlsWidth` needed (two buttons, 270 px). On the
owner's word at grading, a finished puzzle's task line says how it ended
(„Solved.", „Not solved.") instead of „Find the best move", and is not said
again — the endgame trainer's rule; a gate case, red first. Live check [266.4].

`APP/features/tactics_trainer/screens/tactics_trainer_screen.dart`, onto
§4.1: the header card's task into the panel, the rating card after a solve
into the panel's message, `Next` in view on the owner's window (today below
the fold). First, finds out whether „Moves needed: 1 · found 0" after a solve
is real (§2.5) with a case against the real session — fixed if it is, the
render's rig named if it is not.

**Gate:** `T/tactics_trainer_panel_test.dart` (lead, 3.10.2026), 12 cases,
all red on `4cebfe89` for the right reason — among them the counter, measured
real: `solvedMoveCount` floors an odd cursor, so a one-move puzzle solved says
„found 0" and a two-move one „found 1". Brief `docs/briefs/BRIEF-EKRANI-FAZA2.md`.

### Phase 3 — My mistakes `[implementer]` — built 3.10.2026

**Done** (worker's `228556d6`, the lead's `507e0b5d`): `TrainerScreenLayout`,
the game as chips and the task (drawn, not spoken) in the panel, the verdict
in the panel's box with a tick, a cross or an „i", `sanOfUci` beside
`uciOfSan` with seven pure cases, every move in SAN, the grades on screen at
1536 × 792 and 900 × 700 with the likely one filled (`_likelyGrade`, one
line). The worker found and fixed what the gate could not see: the task's
side was read off the board **after** the answer, so „White to move" turned
into „Black to move" (a case of its own, red on the old line); and an empty
promotion string was taken as a promotion. At grading the render showed
„O-O" breaking at its hyphen at the panel's edge; the verdict is now one short
sentence a line. Left for the owner: on a phone held upright the grades are a
scroll under the panel, as `Next` is on the puzzle screen and the endgame
trainer — the shared phone order (board, panel, buttons) is one decision for
all three. Live check [266.5].

**Gate:** `T/mistake_drill_panel_test.dart` (lead, 3.10.2026), 13 cases, all
red on `4cebfe89`. R4 for a row of four peer grades is read as: the grade the
reader most likely wants is filled — `Again` after a wrong or shown answer,
`Good` after a right one — the others outlined; the lead's reading, **agreed
by the owner on 3.10.2026** („Slažem se sa ocenama kako si predložio"), and
kept to one condition so it is one line to change. Brief
`docs/briefs/BRIEF-EKRANI-FAZA3.md`.

`APP/features/archive/screens/mistake_drill_screen.dart`, onto §4.1: the
game's header (opponent, date, opening) as the panel's chips, the verdict and
the „How well did you recall it?" grades in the panel, so the grades are on
screen after an answer (today below the fold at both sizes). Every move named
in SAN, worked out from the position (§2.4) — a case with a castling move and
a capture. Measured 3.10.2026: the app has no shared UCI → SAN helper, but
three private copies of the inverse (`_sanToUci` in
`local_puzzle_extractor_service.dart`, `uciOfSan` in `move_motif.dart`,
`_uciOfSan` in `endgame_analysis_tree.dart`); grep again before writing, and
put the new one beside `uciOfSan` rather than in the screen.

### Phase 4 — the room `[implementer]`, after a sketch the owner approves

`APP/screens/chess_game_screen.dart` (`ChessGamePage`). The room was laid out
by `docs/PLAN-SESIJA.md` phase 6 on the owner's word, so this phase does not
move its columns. What R4 asks of it: the Board column's coloured slabs (`Set
up position`, `Import PGN`, `Export PGN`, `Save position`, `Save analysis`)
become one quiet list of actions; the Moves column's outlined buttons the
same. **The lead renders the room as it is, draws it, and the owner answers
before this phase is briefed** — the only phase here whose drawing he has not
yet seen.

### Phase 5 — the exercise editor `[implementer]`

`APP/features/exercises/screens/exercise_editor_screen.dart`, as
`SK/compare_editor.png`: the board by the window's height, the task and the
accepted answers in the panel, `Save` the one filled button in the panel,
`Assign to student` a text button beside it where it is offered now. On the
phone, `Save` an ordinary button under the panel.

### Phase 6 — the repertoire tour `[implementer]` — built 3.10.2026

**Done** (worker's `9752f126`): on a window the card — sentence, chips, „Prepare reply" (now a `FilledButton`) — at the top of the right column, the tree under it, the board alone on the left and as tall as the window allows (bounded by the column's `PreparationLayout.minPane`); the strip dense on a window only. Gate `T/repertoire_walkthrough_layout_test.dart`, 3 cases, red before at x = 24. Live check [266.6].

`APP/features/repertoire/screens/repertoire_walkthrough_screen.dart`, as
`SK/compare_walk.png`: the card with what the tour says, its reply chips and
`Next` at the top of the right column, the tree under it. The gate holds §2.3:
at 1536 × 792 every reply chip is on screen. The phone is unchanged.

### Phase 7 — the recording player `[implementer]` — built 3.10.2026

**Done** (worker's `5ea753ac`, the lead's `74b8b8dd`): the bar's words on a window (`Open in Analysis`, `Share…`, `Video` with Download / Export), one ⋮ on a phone; the transcript's actions as text buttons above the sentences, behind a ⋮ on a phone; the deck's filler line gone; the panel's width now what the board leaves (300–390), which a full board at 900 × 700 needed. Four sentences on a 360 × 640 phone cost the sheet a larger share (0.6) and a 32 px pencil target; on a 393 × 852 phone seven fit over a normal board. At grading the two plain words were drawn as teal buttons beside the plain word `Video`: `BarWordButton` beside `BarWordMenu` draws them alike. Seven existing tests rewritten openly; the manual's labels corrected. Gate `T/replay_player_layout_test.dart`, 5 cases. Live check [266.7].

`APP/screens/replay_player_screen.dart`, as `SK/compare_player.png`: the bar's
five icons as words (`BarWordMenu` where a word opens a menu); `Make a
tutorial` and `Transcribe again…` as text buttons above the transcript on a
window and behind ⋮ on a phone; the „Synchronized playback of moves and arrows"
line goes. The gate holds §2.2: on a 360 × 640 phone with the transcript open,
at least four sentences are on screen.

### Phase 8 — Student groups `[implementer]` — built 3.10.2026

**Done** (worker's `25bf33d8`, the lead's `69f63fff`): `New group` in the bar and no floating button; on a window the groups left and the chosen one right (`_GroupDetail`, members on `AdaptiveCardGrid`), the first chosen on opening; on a phone a pushed page with the same detail; the delete dialog's `Delete` a `FilledButton`; the manual's Groups paragraph rewritten. At grading two cases for the pane's own Delete and Rename on a window, which nothing drove — Delete proved red when it deletes another group. Gate `T/groups_screen_layout_test.dart`, 7 cases. Live check [266.8].

`APP/features/groups/screens/groups_screen.dart`, as `SK/compare_groups.png`:
pattern B on a window (groups left, the chosen group's members in columns
right, `Rename` / `Delete group` / `Add students` as text buttons), the list
alone on a phone with a group on its own page; `New group` in the bar on both
(R8). The gate holds §2.1: with more groups than fit, every group's actions
can be hit (`hitTestable`).

### Phase 9 — My games and Import games `[implementer]`

`APP/features/archive/screens/archive_home_screen.dart` and
`archive_import_screen.dart`, as `SK/compare_games.png` and
`SK/compare_import.png`: the players' cards on `AdaptiveCardGrid`, their three
doors as text buttons of one kind, `Import games` in the bar, recent imports a
small table; the import screen one centred column with the result in a card
(„Import completed", the four figures, the skipped reasons, the three doors)
instead of a snackbar.

### Phase 10 — the repertoire comparison `[implementer]`

`APP/features/archive/screens/repertoire_diff_screen.dart`, as
`SK/compare_diff.png`: White / Black and the three figures on one row, the
deviations as a table, the chosen row's position on a board beside it with
`Open in Analysis` and `Games through this position` — both screens that
exist (`openSanGameInAnalysis` / the analysis route, `PositionGamesScreen`).
Every row already carries its FEN; **the gate counts requests** and holds the
pane to none (the Repertoire's pane lesson of 21.9.2026). On a phone a tap
opens the position under the list.

### Phase 11 — My Assignments and a homework's items `[implementer]`

`APP/features/assignments/screens/my_assignments_screen.dart` and
`APP/features/homework/screens/homework_assignment_screen.dart`, as
`SK/compare_myasg.png` and `SK/compare_homework.png`: the progress card as one
row of figures, assignments on `AdaptiveCardGrid` with `Open` / `Done` / `All`
filters (counts from the list itself — one set counted, one set shown), each
card's action beside its figures; a homework's items as one numbered list of
reading width, one line per step, its state and its action beside it, the one
step that can be done now the one filled `Continue`. A trainer's view of the
same list keeps `Unlock for student` on a locked row, as a text button.

### Phase 12 — the homework review `[implementer]`

`APP/features/assignments/screens/assignment_review_screen.dart`, as
`SK/compare_review.png`: pattern B — the items left (thumbnail, title, verdict
chip, comment count), the chosen one right (a large board, the task, what was
played, the solution and the time, its comments and a reply field, `Open in
Analysis`), the assignment's discussion under the list. Both the trainer's and
the student's view (their wording differs today and keeps differing). The
„Mark as met / Mark as not met" buttons of a played game stay with that item.
On a phone the list, and a tap opens the item on its own page.

### Phase 13 — the owner's live pass

Items `[266.x]` in `docs/TODO-provera.md`, one per screen, written as each
phase is built, in the file's five-line form.

## 6. Order and who carries it

0 → 1 first (the owner's word: the puzzle screen starts). 2 and 3 next,
because after 0 and 1 they are the same shape and cheap. Then the three
screens with a fault a user can hit today — 8 (groups), 7 (player), 6 (tour) —
then 5, 9, 10, 11, 12. Phase 4 waits for the owner's answer on its drawing and
can go anywhere after phase 1.

Phases 5–12 touch different files and can run in parallel worktrees once 0 is
merged; 1–3 go one after another, because 1 shapes what 2 and 3 take from
§4.1.

## 7. What this plan does not do

- No screen changes what it does, except where §1 records the owner's word
  (A, B) or §2 names a fault.
- No new server route; phase 10's pane reads what the response already holds.
- The voice is untouched: every sentence said today is said at the same moment
  after this plan.
- The homework overview and the tutorial video stay as they are.
