# The endgame trainer: the answer, Analysis and the way back

Written 1.10.2026 by the lead (Opus), from the owner's request of the same day.
Nothing is built yet.

The owner's answers, the same day („Slažem se sa tvojim preporukama, komituj"):
- D7 is accepted for every pushed door.
- The work this plan stands on is committed (`4f9ef2ea`).

**Before phase 0, Fable reviews this plan.** The owner forwards it himself, and
phase 0 starts on his word after the review.

Every brief handed to a worker carries this sentence, in its method section:
*If you believe a test in the gate is wrong, stop and say so in the report — do
not work around it.*

Paths: `APP` = `chess_app/lib/`, `EG` = `APP/features/endgame_trainer/`,
`AN` = `APP/features/analysis_studio/`, `BE` = `chess_backend/`,
`T` = `chess_app/test/`.

## 1. The request

The owner, 1.10.2026, translated. He asked how „Endgames from master games"
works — where the puzzles and their answers come from, how it is played, what
each button does — and for proposals, because he is making the module's final
version:

> I would like the user, after solving — when they see the solution — to be
> able to examine the position themselves with the engine and Syzygy.

The lead answered with an account of the module (§2), three questions with a
recommended answer each, six smaller findings and four pieces of code that
could be deleted. The owner's reply:

> I agree with your proposed answers to the three questions and with the other
> improvements you proposed. Make a plan. I also need to be able to go back
> from Analysis to the puzzle I sent to Analysis, with the choice of endgame
> types I made before Analysis. If that is not a problem.

It is not a problem: D5.

## 2. What exists, read 1.10.2026

Read in the code, not run. The counts are measured in phase 0.

**Two questions on one screen** (`EG/screens/endgame_trainer_screen.dart`, 1693
lines).
- *Solving*: one move is the whole question.
  - Any move in `winning_moves` is right. That list holds every move that keeps
    the result, stored when the position was mined.
  - A wrong move resets the board, and the attempt stops counting as clean.
  - After a correct move the board locks; `Find the rest` and `Show` deal with
    the other holding moves.
- *Play to the end* and *Punish*: every move goes to `POST
  /api/puzzles/endgame/play` (`BE/services/endgameDrill.js`, `judgeMove`). The
  server asks the tablebase and answers with the opponent's reply in Lichess's
  own order (`bestReply`, since 30.9.2026).

**Where the answers come from.**

| Position | Judged by | When | Exact? |
|---|---|---|---|
| up to six pieces, and every real mistake | Syzygy on the owner's machine | at mining time | yes |
| seven pieces | the Lichess tablebase (`puzzles/rejudge_endgames.py`) | re-judged after mining | yes |
| eight or more pieces (`source = 'engine'`) | Stockfish | at mining time | no — an estimate, which the screen states as firmly as a fact |

**No way to the answer.** While solving there is only `Hint` (one square, as
text) and `Skip`. Nothing shows the answer.
- For tablebase positions the answer can be dug out through `Play to the end` →
  `Tablebase findings`.
- For eight or more pieces it cannot be reached at all.
- The tactics trainer has `Show solution`
  (`APP/features/tactics_trainer/screens/tactics_trainer_screen.dart`,
  `_showSolution`).

**Exploring.** Tapping a move in `Tablebase findings` plays it and switches the
drill into `Exploring`: both sides move, nothing is judged, and `Back to
position` returns. It is tablebase only, with no engine and no move list. It is
reachable only from inside the drill, and never for eight or more pieces.

**The reply after a correct answer comes from the stored line**
(`EndgamePuzzle.solution`). If the reader's move is the line's first move, the
line's second move is played.
- For tablebase positions the miner built that line by DTZ (`tablebase_line` in
  `puzzles/endgame_miner.py`): the losing side plays the move with the largest
  DTZ. That is the defence the owner reported on 30.9.2026, and the drill no
  longer plays it.
- The screen also always promotes to a queen, whatever the line says
  (`'promotion': 'q'`).

**Analysis already does what is asked** (`AN/screens/analysis_studio_screen.dart`).
- The Syzygy panel is offered at seven pieces or fewer, unless hidden from the
  board view menu. It lists every move with its result and DTZ, best first, and
  a tap plays the move.
- Stockfish runs behind `Engine`.
- Both sides can move, with take-back and branches, and `Save as…`.

**How other screens open Analysis.** They use one function, `openTreeInAnalysis`
(`AN/services/open_game_in_analysis.dart`), which *pushes* Analysis on top of
the calling screen.
- The opening report has done this since 30.9.2026. Its screen stays underneath
  and comes back as it was left.
- A pushed Analysis has a back arrow in its bar: its `AppBar` sets no `leading`.
- Nothing in it replaces the navigation stack: a grep of `AN/` on 1.10.2026 found
  no `context.go`.

**Its tree carries moves only.** From
`APP/features/archive/services/opening_position_tree.dart`: „Nothing but moves
goes into the tree — no comment and no evaluation, since a tree opened here may
become a tutorial, and a tutorial speaks its comments."

**The device draft.** `AN/services/analysis_draft_service.dart` keeps one slot.
- The Analyse tab restores the slot at start. A screen given `initialFen`,
  `initialGame` or `initialTree` does not restore it (`initState`).
- But every Analysis writes the slot, on each change and in `dispose`.
- So after any pushed Analysis, the next start shows that tree in the Analyse
  tab instead of the tab's own work.
- Doors that push Analysis today: the Library's saved analysis, Preparation's
  copy, the opening report, and the games from the archive and from homework.

**The trainer keeps its selection in itself.**
- The picker replaces itself with
  `/endgames?mode=…&material=…&band=…&oppositeBishops=…`.
- The screen holds those values as its own fields and sends them, with
  `includeOnline`, on every `fetchNext`.
- A retry run holds its queue in the screen (`_retryQueue`, `_retryIndex`).
- Nothing of this is stored anywhere else, so the way back depends only on the
  screen not being rebuilt.

**Smaller findings**, each a decision in §4:
- The card promises grandmaster games, while `Level` goes down to `Under 1800`.
- `Save for later` says `Saved in "My positions"`, in the trainer and in `Game
  blunders`. That screen no longer exists; the position goes to Library →
  Positions.
- Positions from real mistakes store their Syzygy key as their type. Their chip
  reads „KRPvKR", while the picker says „rook and pawn versus rook".
- `holdOutMoves` (`EG/models/drill_step.dart`) is commented „four moves each",
  but counts eight of the reader's moves.

**Unused code**, listed in §5:
- the screen's `fen`, `type`, `maxPieces` and `minPawns`, which the router never
  passes and no test does — and, with `fen`, the `'custom'` branch;
- `EndgameVerdict.accepted`, read by one unit test and by no screen;
- `EndgamePuzzle.solutionSan`, read by nothing;
- `BE/import_endgame_puzzles.js`, which `import_endgames.js` replaced and nothing
  references.

## 3. The model on one page

```
SOLVING ──correct move──► SOLVED ─────────┐
   │                                      │
   └──Show solution──► ANSWER SHOWN ──────┼──► Open in Analysis ──► Analysis, pushed
                                          │         │
PLAY TO THE END / PUNISH ──ends──► OVER ──┘         └── Back ──► the same screen, as it was:
                                                        the position, its state, the
                                                        selection, the retry queue
```

`Open in Analysis` is on the screen whenever the screen has stopped asking a
question: the position is solved, the answer is shown, or the drill is over
(mate, a draw, or a losing move). It is not offered while a question is open,
because an engine beside an open question gives away the answer.

The tree it opens, moves only:

```
the puzzle position          ← Analysis stands here when opened from solving
├── Kd3      the reader's move (in the order found) ── Kb6  the server's reply, if one was played
├── e4       every other move that holds, in the server's order
└── Rd1      the move played in the game, when the position comes from one
     └── …   the Punish line, when one was played
```

When Analysis is opened from the drill:
- the drill's moves go under its first move;
- Analysis stands where the drill stopped;
- the board faces the reader's side, not the side to move.

## 4. Decisions

Who decided what:
- **The owner, 1.10.2026** („Slažem se sa tvojim predlozima"): D1–D4 and D8–D12,
  as recommended to him in chat. D5 is his own request.
- **The lead**: D6, D13 and D14, stated so they can be overruled.
- **D7** was the lead's recommendation. It changes four doors outside this
  module, so it was put to the owner, who accepted it on 1.10.2026 („Slažem se
  sa tvojim preporukama").

**D1. `Open in Analysis` opens the existing Analysis, pushed.** There is no
engine inside the trainer. Analysis already has the Syzygy panel, the engine,
take-back, branches and `Save as…`. A second engine panel would be a second home
for all of that (rule 12), in a screen already 1693 lines long.

**D2. The engine is off when Analysis opens**, by the owner's rule of
17–18.9.2026. The Syzygy panel answers by itself at seven pieces or fewer, and
the engine is one tap away.

**D3. `Show solution` while solving.** It ends the question:
- the attempt is recorded once as not solved, so the position comes back under
  `Retry failed`;
- every holding move is named;
- the board locks;
- the same doors as after a solve are offered: `Open in Analysis`, `Play to the
  end`, `Punish`, `Save for later`, `Next`.

It gets no key. The trainer's five keys stay as they are, and tactics has no key
for it either.

**D4. Exploring inside the drill is deleted.**
- `Tablebase findings` stays, as a list to read. Its rows no longer play
  anything.
- The sentence „Tap a move to play it on the board." goes from both the panel
  and the dialog.
- TODO-provera [0l.b240] and [0l.b242] are superseded, and move to the archive
  with that reason.

**D5. The way back — the owner's request.** Analysis is pushed over the trainer,
so the trainer is never rebuilt.
- Back (the arrow in Analysis's bar, or the system Back on Android) shows the
  same position in the same state: solved, answer shown or drill over, with the
  moves found and the same chips.
- `Next` keeps serving from the same selection: endgame types, level, opposite
  bishops, the online switch and the task. In a retry run it continues the same
  queue from the same place.
- Nothing is saved or restored, which is why it cannot drift.
- The gate proves it, because a later change could break it without a word — a
  `context.go` in Analysis, or a trainer rebuilt from its route.

**D6. The tree carries moves only**, by the opening report's rule (§2). This
departs from what the owner was told in chat, which was a comment on the game's
move. The game's move is the last branch, and the Syzygy panel shows that it
loses. A `?` on it was not taken either, because a NAG is an evaluation in the
same tree.

**D7. The device draft belongs to the Analyse tab.** An Analysis given
`initialFen`, `initialGame` or `initialTree` neither restores the draft (as
today) nor writes it. One condition does both — the one that already guards
restoring.
- The cost: work done in a pushed Analysis is kept only by `Save as…`. Today it
  comes back nowhere except in the Analyse tab after a restart, where it
  replaces what the user had there.
- *Not taken:* changing only the new door, and leaving the other four as they
  are.

**D8. The opponent's reply after a correct answer comes from the server.**
- For a tablebase position with seven pieces or fewer, the screen sends its
  answer to `POST /api/puzzles/endgame/play` and plays the reply that comes
  back. This is the drill's rule, with one home (`bestReply`).
- Positions from real mistakes had no stored line; they now get a reply too.
- An engine position gets no reply.
- The stored line is no longer read. `EndgameVerdict.opponentReply` goes, and
  the server stops sending `solution` and `solution_san`. The columns stay,
  because the miner writes them.
- A reply that arrives after the board has moved on (`Next`, `Find the rest`,
  `Play to the end`) is dropped.
- A server that does not answer costs only the reply; the verdict was already
  given.
- Cost: one tablebase request per solved position. At five pieces or fewer it
  goes to Lichess (`mateDistance`) and is counted in `Usage this month`.

**D9. An engine position says so.**
- A chip `Engine estimate` stands where `Exact from tablebases` would.
- A wrong move says „The engine judges that this move drops the win. Try
  another." (for a draw: „…loses the draw…").
- Exact positions keep their sentences.

**D10. „Endgames from real games".**
- The card gets that title and a new first sentence: „Positions from real games,
  played at every level from club players to grandmasters."
- The route's comment changes with it.
- The manual (`site/mislisha/manual/practice.html`, `repertoire.html`) and the
  landing page (`site/mislisha.html`) change in the same phase, because
  `manual_labels_test` holds the manual to the app's labels.
- TODO-provera items that quote the old title in their path keep it. The QA tool
  matches items by text, and an answered item is never reworded.

**D11. `Save for later` says where the position went**: „Saved to the Library
under Positions, tagged "Unclear"." It says so in the trainer and in `Game
blunders`. [0j.b262] keeps the old sentence; a new item checks the new one.

**D12. One name for an ending.**
- The server sends `material_label`: `labelOf(material)` from
  `BE/services/endgameCatalog.js`, the picker's own words.
- The chip shows it with its first letter capitalised.
- `kEndgameTypeNames` goes if phase 0 finds no servable row without `material`.
  If it finds some, the map stays only as their fallback.

**D13. „Hold the draw for 8 more moves" stays as it is**: eight of the reader's
moves. That is what the screen says and what the code counts. Only the comment
beside `holdOutMoves` is corrected. (This is the lead's choice; the owner asked
nothing here and can say four.)

**D14. `Open in Analysis` from the drill faces the reader's side.**
- Analysis turns a tree to the side to move at the node it stands on
  (`_loadTree`). A drill that ended on the reader's losing move stands on a
  position where the opponent is to move.
- `openTreeInAnalysis` gets an optional `blackOrientation`. The trainer passes
  it from its own board, so a board the reader flipped stays flipped.
- Without the parameter, Analysis behaves as today, so the opening report is
  unchanged.

## 5. What goes, and what stays

**Goes:**
- Exploring: `_exploring`, `_exploreFrom`, `_playFromReadout`,
  `_playExploringMove`, `_stopExploring`, `_readoutMoveWord`, the `Exploring`
  chip, `Back to position` and the rows' `onTap`.
- The stored line on the app side: `EndgamePuzzle.solution` and `solutionSan`,
  `EndgameVerdict.opponentReply` and `accepted`.
- The screen's `fen`, `type`, `maxPieces` and `minPawns`, and the `'custom'`
  branch.
- `fetchNext`'s `type`, `difficulty`, `maxPieces` and `minPawns`, which only those
  screen fields fed.
- `solution` and `solution_san` in `buildEndgamePayload`.
- `BE/import_endgame_puzzles.js`.
- `kEndgameTypeNames`, if D12 allows.

**Stays:**
- `Tablebase findings` (as a list), `Take back`, `Start over`, `Conclude draw`,
  `Punish`, `Find the rest`, `Show` and `Save for later`.
- The keys N, R, H, T and U, with their meanings.
- The database columns `solution` and `solution_san`.
- The server's filters on `/endgame/next` that no client sends any more (§7).

## 6. Phases, each with its gate

Baseline to re-measure in phase 0, in a worktree:
- app **5326** (1 skipped);
- backend **1979** without a database, and **2142** with one (derived);
- `flutter analyze` the same **22** infos (`CLAUDE.md`).

Each phase ends with its arithmetic in `docs/LESSONS.md` and the block in
`CLAUDE.md` updated.

Order:
- 4 before 5, and 5 before 6.
- Phases 1, 2 and 3 can go in any order.
- The app ignoring a field the server still sends is harmless, and so is the
  server dropping a field the old app no longer needs.

### Phase 0 — the baseline and three counts [lead]

- **A committed tree — done.** The work of 1.10.2026 (the three triage
  findings) touches two of the files this plan does
  (`site/mislisha/manual/practice.html` and `docs/`). It was committed on the
  owner's word as `4f9ef2ea`.
- **Fable's review comes first.** The owner forwards the plan himself, and this
  phase starts on his word after the review.
- Measure the three suite counts in a worktree, with nothing else running.
- Count, read-only, on the database the server uses (psql, or a script that does
  not call `initDB`):
  - servable rows (`cardinality(winning_moves) > 0`), by `source`;
  - those with `material IS NULL`, by `source` — this decides D12;
  - those with `played_move`.

  The first count sizes D9.
- **Gate:** the numbers, written here.

### Phase 1 — the ground: unused code and the words [lead]

Covers D10, D11, D13 and the deletions of §5 that need nothing else:
- the screen's four parameters and the `'custom'` branch;
- `fetchNext`'s four parameters;
- `EndgameVerdict.accepted` and `EndgamePuzzle.solutionSan`;
- `BE/import_endgame_puzzles.js`.

**Gate:** the suite is green.
- Rewritten openly, each with a sentence above it:
  - `T/training_hub_test.dart` and `T/training_hub_layout_test.dart` (the
    title);
  - the case in `T/endgame_wire_format_test.dart` that sends `maxPieces: 5`;
  - the `accepted` assertion in `T/endgame_solve_session_test.dart`.
- New: the trainer and the game walk each show the new sentence after `Save for
  later` — two cases, each red on master.
- `manual_labels_test` is green with the manual changed.
- A grep in the report finds, under `APP`: no `'custom'`, no `widget.fen`, no `My
  positions`, and no „master games" outside history comments.

### Phase 2 — the server [lead]

Covers D12's `material_label`, and D8's removal of `solution` and
`solution_san` from `buildEndgamePayload`. There is one builder, so
`/endgame/next` and `/by-id?source=endgame` change together.

The work is done in a worktree, because the owner's nodemon restarts on every
`.js` save. It is copied in on his word, with the server off.

**Gate** (backend, run both with and without `.env`):
- The payload carries `material_label` equal to `labelOf(material)`, for a mined
  row and for a blunder row, and null where `material` is null.
- It carries no `solution` and no `solution_san`.
- The `/by-id?source=endgame` case in `BE/test/puzzle_progress_routes.test.js`
  still holds the shared shape.
- Mutations, each red:
  - the label taken from `endgame_type` instead of `material`;
  - the field dropped from one route only.

### Phase 3 — the draft belongs to the Analyse tab [implementer]

**Before the change:** grep `T` for `AnalysisDraftService` and
`analysis_studio_draft`. These files use it:
- `account_local_state_test`
- `analysis_draft_restore_quiet_test`
- `engine_hold_test`
- `home_tabs_test`
- `left_behind_on_sign_out_test`
- `move_variation_order_test`
- `review_runner_test`

For each, the report says whether it relies on a pushed screen writing the
draft.

**Gate** (new `T/analysis_draft_owner_test.dart`):
- The tab's screen, given no `initial…`, writes the draft after a move.
- A screen given `initialTree`, `initialGame` or `initialFen` writes nothing,
  neither after a move nor when it is popped.
- A draft stored before such a visit is byte for byte the same after it.
- Mutations, each red on its own case:
  - the guard taken off `_saveDraft`;
  - the guard taken off the `dispose` flush.

### Phase 4 — the answer: `Show solution`, the reply and the engine's estimate [implementer; gate by the lead]

Covers D3, D8 (the app side) and D9. `EndgameSolveSession` gets a fourth status,
`revealed`: complete, never `countsAsSolved`, and `submit` is refused in it.

**Gate** (new `T/endgame_answer_test.dart`, over a fake `http.Client` (rule 7)
and the attempt log's fake client):
1. `Show solution` is on the screen while solving, and absent after a solve and
   after a shown answer. The rest of that button row is present, so the absence
   is checked where the button would be.
2. It names every holding move in SAN. The fixture has three, one of them an
   underpromotion. The board refuses a drag afterwards.
3. It records one attempt, `solved: false`.
   - `Next` afterwards records nothing more, not also a skip.
   - After a hint, the record is `hinted: true`.
   - After a wrong move there is still only one record.
4. Exact position: a correct answer sends `POST /api/puzzles/endgame/play` with
   the puzzle's FEN and the move. The board then shows the reply that came back,
   and a reply that underpromotes lands as that piece.
5. Engine position:
   - a correct answer sends no request;
   - the chip `Engine estimate` is shown, and `Exact from tablebases` is not;
   - a wrong move says „The engine judges that this move drops the win. Try
     another."
6. Exact position: no `Engine estimate`, and a wrong move keeps „That move drops
   the win. Try another."
7. The fake holds a reply back until after `Find the rest`, and once more until
   after `Next`. Neither reply reaches the board.
8. A 503 from `/play`: no reply, and the verdict sentence stays.
9. `EndgameSolveSession`, pure: `reveal()` leads to `revealed`, complete and not
   counted, and `submit` is refused after it.

Also:
- Rewritten openly: the two `opponentReply` cases in
  `T/endgame_solve_session_test.dart`.
- Mutations, each red on its own case:

  | Mutation | Case |
  |---|---|
  | the token check on the late reply removed | 7 |
  | the promotion forced to `q` | 4 |
  | `Show solution` drawn after a solve | 1 |
  | `solved: true` recorded | 3 |
  | the request sent for an engine position | 5 |
  | the chip drawn for an exact position | 6 |

### Phase 5 — `Open in Analysis`, and the way back [implementer; gate by the lead]

Covers D1, D2, D5, D6 and D14.
- A pure builder, `EG/services/endgame_analysis_tree.dart`, in the shape of
  `opening_position_tree.dart`: a child that plays the same move is reused,
  never doubled.
- The trainer keeps the drill's moves as it goes. `DrillStep` reads `playedUci`
  and `reply.uci`, which the server already sends. `Take back` drops the move it
  takes back, and `Start over` clears them.
- `openTreeInAnalysis` gains `blackOrientation`, and `AnalysisStudioScreen` an
  `initialBlackOrientation` for a tree.

**Gate, the tree** (new `T/endgame_analysis_tree_test.dart`, pure):
- The root is the puzzle's FEN.
- The children are the reader's moves in the order found, then the other holding
  moves in the server's order, then the game's move.
- The reply sits under the first move found.
- The drill line:
  - a drill whose first move holds continues under that branch;
  - one whose first move loses adds a last branch;
  - a Punish line hangs under the game's move.
- The tree stands on the root when opened from solving, and on the last move
  when opened from the drill.
- After `Take back` the line is one move shorter.
- **No node carries a comment, a NAG, an arrow or a square.**
- Every node's FEN is its parent's after its move.

**Gate, the door** (new `T/endgame_open_in_analysis_test.dart`, through
`debugOpenTreeInAnalysis`, as
`T/features/archive/opening_leak_report_screen_test.dart` does):
- `Open in Analysis` is absent while solving and while a drill is running.
- It is present when the position is solved, when the answer is shown, and when
  the drill is over.
- It hands over the tree the builder makes from what the screen knows.
- From a drill that ended on the reader's losing move, it asks for the reader's
  side.

**Gate, the way back** (same file; a stand-in page is pushed and popped):
1. After Back:
   - the board shows the same FEN;
   - the title and the chips are the same (`Solved: 1/1`, `Find the rest
     (1/3)`);
   - the board is exactly as locked or open as it was.
2. `Next` after Back sends `/api/puzzles/endgame/next` with the same `mode`,
   `material`, `band`, `oppositeBishops` and `includeOnline` as the first
   request, and `excludeId` set to this position. The query maps are compared
   (rule 7).
3. In a retry run, `Next` after Back asks for the queue's next id, not its first
   again.
4. While the stand-in is on top, N does nothing below it (no request). After
   Back, N loads the next position (one request).
5. A drill that was over is still over after Back: its sentence and `Take back`
   are there.
6. Once with the real `AnalysisStudioScreen`, pumped as `T/analysis_bar_test.dart`
   pumps it: its bar has a back arrow, and pressing it returns to the trainer as
   in case 1.

**Mutations**, each red:

| Mutation | Red in |
|---|---|
| the children's order swapped | the tree |
| the reply hung under the root | the tree |
| a comment written on the game's move | the tree |
| standing on the root when opened from the drill | the tree |
| the trainer rebuilt on return — the stand-in opened with `pushReplacement` | the way back, cases 1–3 |
| the orientation not passed | the door |

### Phase 6 — Exploring goes [implementer]

Covers D4.

**Gate:** the case „a move from the finding is played, and the board stays
open" in `T/endgame_trainer_layout_test.dart` is rewritten openly, with the
supersession written above it. The new case checks the rule where its effect
would be drawn: with the findings open beside the board, tapping `Rf1+`
- leaves the board's FEN as it was,
- draws no `Exploring` and no `Back to position`,
- and leaves the board's `isAllowedToMove` as it was.

The rewritten case is red on master. The other findings cases are unchanged and
green.

### Phase 7 — the words [lead]

- The manual (`practice.html`): `Show solution`, `Open in Analysis` and the way
  back, and `Engine estimate`; nothing about tapping a finding.
- `STANJE-RADA.md`.
- The live items (§8).
- The archive for [0l.b240] and [0l.b242].
- `LESSONS.md` and `CLAUDE.md`.
- The keyboard list is unchanged, and is checked to be so.

### Phase 8 — the owner's live pass [owner]

## 7. Not in this plan

- `Open in Analysis` in `Game blunders`, where the game is already a list of
  moves (`openSanGameInAnalysis` exists). Natural, but not asked for.
- Arrows on the trainer's board for a shown answer.
- The server's filters on `/endgame/next` that no client sends after phase 1:
  `type`, `difficulty`, `maxPieces`, `minPawns`, `minElo` and `maxElo`. They are
  for the next deletion batch.
- Rows without `material`, if phase 0 finds any: the picker's catalogue never
  counts them. That is a question of its own.
- Re-mining, and the DTZ order of the stored lines. No screen reads those lines
  after phase 4.

## 8. The live pass

To be added to `docs/TODO-provera.md`, under Practise — Završnice i greške iz
partija, in the five-line form, from [261.1]:

| Item | What to check |
|---|---|
| [261.1] | `Show solution` names the moves and the board locks; `Retry failed` counts the position. |
| [261.2] | The reply after a correct answer in a rook ending is the toughest defence, the same as in `Play to the end`. |
| [261.3] | An engine position (eight or more pieces) shows `Engine estimate` and the engine's wrong-move sentence. |
| [261.4] | `Open in Analysis` after a solve opens the tree (your move first, the others, the game's move); the Syzygy panel shows; the engine stays off until `Engine`. |
| [261.5] | The way back: Back from Analysis shows the same puzzle in the same state, and `Next` stays inside the chosen endgame types and level. On Windows by the arrow; on the phone also by the system Back. |
| [261.6] | From a drill that ended on a losing move, Analysis stands after the mistake and faces your side. |
| [261.7] | After a restart the Analyse tab still shows its own analysis, not the endgame. |
| [261.8] | The rows of `Tablebase findings` no longer play a move. |
| [261.9] | The card's new title and first sentence; the manual. |
| [261.10] | `Save for later` names the Library, in the trainer and in `Game blunders`. |
| [261.11] | A position from a real mistake names its ending in words on the chip. |
