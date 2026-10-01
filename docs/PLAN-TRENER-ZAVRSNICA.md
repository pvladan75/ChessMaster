# The endgame trainer: the answer, Analysis and the way back

Written 1.10.2026 by the lead (Opus), from the owner's request of the same day.
Nothing is built yet.

The owner's answers, the same day („Slažem se sa tvojim preporukama, komituj"):
- D7 is accepted for every pushed door.
- The work this plan stands on is committed (`4f9ef2ea`).

**Fable reviewed this plan on 1.10.2026**, against the code it names. Every
change from that review is marked *(Fable, 1.10.2026)* where it stands and
listed once in §9, with what was checked and found to hold. Phase 0 starts on
the owner's word.

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
- *(Fable, 1.10.2026)* The Analyse tab itself (`APP/widgets/home/analyse_tab.dart`)
  builds the screen with no `initial…`, so D7 leaves the tab exactly as it is.
  The router's `/analysis?fen=` (`AppRoutes.analysisWithFen`) is a sixth door
  that would hand the screen `initialFen` — and nothing calls it; it is dead
  (§7).

**The trainer keeps its selection in itself.**
- The picker replaces itself with
  `/endgames?mode=…&material=…&band=…&oppositeBishops=…`.
- The screen holds those values as its own fields and sends them on every
  `fetchNext`; `includeOnline` it reads from `AppSettingsService` at each
  request *(Fable, 1.10.2026 — it is not a field of the screen)*.
- A retry run holds its queue in the screen (`_retryQueue`, `_retryIndex`).
- *(Fable, 1.10.2026)* The drill keeps **no** move history: `_game` is rebuilt
  from the server's `fen` after every judged move, and `Take back` restores
  `_drillRetryFen`, the one position before the losing move. Phase 5's list of
  the drill's moves is new state, not a reading of something the screen has.
- *(Fable, 1.10.2026)* The keys go through `ActionKeyShortcuts`
  (`APP/widgets/action_key_shortcuts.dart`): a `Shortcuts` over a `Focus`, not
  a global handler. A route pushed on top takes the primary focus with it, and
  popping gives it back, which is what phase 5's case 4 proves from both sides.
- Nothing of this is stored anywhere else, so the way back depends only on the
  screen not being rebuilt.

**Smaller findings**, each a decision in §4:
- The card promises grandmaster games, while `Level` goes down to `Under 1800`.
- `Save for later` says `Saved in "My positions"`, in the trainer and in `Game
  blunders`. That screen no longer exists; the position goes to Library →
  Positions.
- Positions from real mistakes store their Syzygy key as their type. Their chip
  reads „KRPvKR", while the picker says „rook and pawn versus rook".
  *(Fable, 1.10.2026)* `kEndgameTypeNames` has **three** readers, not one: the
  chip (`_chips`), the title of a position kept by `Save for later`
  (`'… — unclear'`), and the bar's title through `widget.type`, which phase 1
  deletes.
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
├── Kd3      the reader's moves (in the order found) ── Kb6  each with the reply it was given, if one came (D8)
├── e4       every other move that holds, in the server's order
└── Rd1      the move played in the game, when the position comes from one
     └── …   the Punish line, when one was played
```

When Analysis is opened from the drill:
- the drill's moves go under its first move;
- Analysis stands where the drill stopped;
- the board faces the reader's side, not the side to move.

*(Fable, 1.10.2026)* Two readings of that picture, so the builder is not written
from the wrong one:
- The game's move is a branch of its own only for a position from a real
  mistake: `played_move` is written by `import_endgames.js` alone, the miner
  never writes it, so a master-game position has `game` and no `played_move`.
  Where one exists it changed the result, which is why D6 can say the Syzygy
  panel shows it losing.
- „The reader's moves" means every move found, `Find the rest` included — each
  is a solve, and under D8 each asks the server for its reply (D8).

## 4. Decisions

Who decided what:
- **The owner, 1.10.2026** („Slažem se sa tvojim predlozima"): D1–D4 and D8–D12,
  as recommended to him in chat. D5 is his own request.
- **The lead**: D6, D13 and D14, stated so they can be overruled.
- **D7** was the lead's recommendation. It changes four doors outside this
  module, so it was put to the owner, who accepted it on 1.10.2026 („Slažem se
  sa tvojim preporukama").
- **Fable, 1.10.2026**: D15, recommended in the review and **accepted by the
  owner the same day** („D15: dodaj i take back potez"); and the amendments to
  D8, marked there.

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
  end`, `Punish`, `Save for later`, `Next`. Not `Find the rest` and not `Show`
  — there is nothing left to find.

It gets no key. The trainer's five keys stay as they are, and tactics has no key
for it either.

*(Fable, 1.10.2026)* Two things the gate needs that were not written down:
- It is offered **while solving only** — not in a drill, where
  `Tablebase findings` is the answer.
- The sentence, so the gate has a literal. In the trainer's own register
  („Correct — win kept." / „Correct — draw held."):
  „These moves keep the win: Rf1+, Ra8, e8=N." / „These moves hold the draw:
  …", and with one move „The only move that keeps the win: Rf1+." / „… holds
  the draw: …". The list is `_allHoldingSan`, which already exists for the
  `Save for later` note; it sorts, so the order is alphabetical, not the
  server's.

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
- *(Fable, 1.10.2026)* Checked: the condition in `initState` is
  `initialFen == null && game == null && tree == null`; the two writers are
  `_saveDraft` (thirteen call sites) and the `flush` in `dispose`. So the shape
  is **one getter, three readers** — restore, `_saveDraft`, the flush — never
  the condition written a second time (rule 12). The Library and Preparation
  doors pass `initialTree`, the three in `open_game_in_analysis.dart` pass
  `initialGame` or `initialTree`; `analysis_bar_test` pumps the screen with
  `initialFen` and asserts nothing about the draft, so it stays green.

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

*(Fable, 1.10.2026)* Amended after reading `judgeMove` and `tablebaseService`:
- **The condition is `puzzle.canBePlayedOut`** — `isExact && pieces <= 7`, the
  getter the drill already uses. `judgeMove` throws `DrillError` above seven
  pieces, so the rule has to be the same one on both ends, and it already has a
  home.
- **Every found move asks**, not only the first: a move found after `Find the
  rest` is a solve like the first, so it is sent the same way and its reply
  lands under it in the tree (§3). One request per found move.
- **The board takes the server's `fen`**, as the drill does (`_game =
  fromFEN(step.fen)`), and keeps `reply.uci` for the tree. The screen replays
  no UCI, so the `'promotion': 'q'` of today has no successor to mutate; where
  the promotion suffix matters is the tree builder (phase 5), which replays the
  UCI.
- **Meanwhile nothing locks.** The verdict sentence is shown at once, the board
  shows the reader's move, and the reply lands when it comes — no „Checking
  tablebases…", because there is nothing to check. Today's reply is instant;
  this one is a round trip to Lichess.
- **A server that says `held: false`** (it judges the move itself, from the
  same tables that wrote `winning_moves`) returns no reply. The screen's verdict
  stands, no reply is played, and the disagreement goes to the log through
  `AppLogger` with the puzzle id, because it is a data fault worth a line and
  not a sentence to the reader.
- **Cost is two probes, not one.** `judgeMove` probes the position before the
  move and the position after it with `mateDistance: true`. At five pieces or
  fewer the first is local (`LOCAL_MAX_MEN = 5`) and the second goes to Lichess;
  at six and seven both go to Lichess. All of them pass `tracked`, so they are
  counted in `Usage this month`. `/play` sits behind `drillLimiter`, sixty a
  minute, which one request per found move does not reach.

**D9. An engine position says so.**
- A chip `Engine estimate` stands where `Exact from tablebases` would.
- A wrong move says „The engine judges that this move drops the win. Try
  another." (for a draw: „…loses the draw…").
- Exact positions keep their sentences.

**D10. „Endgames from real games".**
- The card gets that title and a new first sentence: „Positions from real games,
  played at every level from club players to grandmasters."
- The route's comment changes with it.
- The manual (`site/mislisha/manual/practice.html`) and the landing page
  (`site/mislisha.html`) change in the same phase, because `manual_labels_test`
  holds the manual to the app's labels. *(Fable, 1.10.2026)* **Not**
  `repertoire.html` and not `analysis.html`: both say „master games" about the
  opening book, which is what the book is made of, and neither mentions
  endgames. The same words stand in `mistake_rule.dart` and
  `game_review_judge.dart` for the same reason, and stay.
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
- *(Fable, 1.10.2026)* `labelOf(null)` answers `''`, not null (it falls back to
  `String(key || '')`), so the payload guards: `material == null ? null :
  labelOf(material)`. And the label has to reach **all three** readers of the
  map (§2) — the chip and the `Save for later` title read `materialLabel`; the
  bar's reader goes with `widget.type` in phase 1. The app half of D12 belongs
  to phase 4.

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
- *(Fable, 1.10.2026)* The test seam changes shape with it:
  `debugOpenTreeInAnalysis` is typed `(context, root, standOn)`, and a Dart
  function of three parameters is not assignable where a fourth is declared,
  so the lambda in `T/features/archive/opening_leak_report_screen_test.dart`
  (line 635 on 1.10.2026) is touched — a compile change, no assertion moves.
  Named here so it is not the ninth file.

**D15. A move taken back in the drill stays in the tree, as a side branch.**
*(Fable's recommendation, 1.10.2026; the owner accepted it the same day.)* The
plan as first written dropped it („`Take back` drops the move it takes back").
But `Take back` exists only after a losing move, and the losing move is the one
thing in the drill the reader has a reason to examine with the engine and
Syzygy — it is what the owner asked for. A tree is the structure that holds
both: the taken-back move is a branch of the position it was played from, and
the move played instead continues the line. The builder gains nothing but a
list of (from-FEN, move) pairs instead of a line. `Start over` still clears
everything: it is the reader asking for a clean board, not a take-back.

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

### Phase 0 — the baseline and four counts [lead]

- **A committed tree — done.** The work of 1.10.2026 (the three triage
  findings) touches two of the files this plan does
  (`site/mislisha/manual/practice.html` and `docs/`). It was committed on the
  owner's word as `4f9ef2ea`.
- **Fable's review is in** (§9, 1.10.2026), and D15 is accepted. This phase
  starts on the owner's word.
- Measure the three suite counts in a worktree, with nothing else running.
- Count, read-only, on the database the server uses (psql, or a script that does
  not call `initDB`):
  - servable rows (`cardinality(winning_moves) > 0`), by `source`;
  - those with `material IS NULL`, by `source` — this decides D12;
  - those with `played_move`;
  - *(Fable, 1.10.2026)* the distinct `material` values that `labelOf` cannot
    parse (it then answers the raw key, and the chip would show „KRPPPvKRPP"
    as it shows „KRPvKR" today). A read-only node script over `SELECT DISTINCT
    material` through `endgameCatalog.labelOf`, never through `server.js`.

  The first count sizes D9.
- **Gate:** the numbers, written here.

**Measured 1.10.2026** (the lead, a read-only node script in its own
`BEGIN READ ONLY` transaction, its own pool, `labelOf` required from
`services/endgameCatalog.js`; neither `db.js` nor `server.js` loaded):

| source | rows | servable | `material IS NULL` (servable) | with `played_move` |
|---|---|---|---|---|
| `blunder` | 13501 | 13501 | 0 | 13501 |
| `engine` | 493 | 493 | 493 | 0 |
| `lichess` | 63 | 63 | 63 | 0 |
| `syzygy` | 533 | 533 | 533 | 0 |
| null (the old generator) | 510 | 0 | — | 0 |

- 160 distinct `material` keys; **none** that `labelOf` cannot parse.
- `played_move` is on every blunder row and on nothing else, as §3 read it.
- D9's engine rows, by pieces: 8 → 66, 9 → 68, 10 → 85, 11 → 51, 12 → 80,
  13 → 56, 14 → 47, 15 → 24, 16 → 16 (493).
- **D12: the map stays as a fallback.** All 1089 mined rows (engine, lichess,
  syzygy) have no `material`; their `endgame_type` is always one of the seven
  keys `kEndgameTypeNames` already names, so the fallback names every one.
- Read beside the counts, for §7's open question and not acted on: a row with
  no `material` is reached only when the picker sends no `material` — every
  ending ticked — and the band is `all` or the unrated band (mined rows have no
  `blunder_elo`). So D9's 493 engine positions are reachable today only that
  way, and the picker's „Selected: N" never counts them.
- Baseline, in the worktree with nothing else running: app **5326** (1
  skipped), backend **1979** without a database and **2142** with a throwaway
  cluster (both measured — the 2142 was derived until now), analyze the same
  **22** infos. All as quoted.

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
  positions`; and no „master games" under `EG/` and in
  `APP/widgets/ai_studio/category_selection_hub.dart`, nor in
  `site/mislisha/manual/practice.html` and `site/mislisha.html`. *(Fable,
  1.10.2026: scoped — the words are right where they mean the opening book,
  D10.)*
- *(Fable, 1.10.2026)* The sentence of D11 names the Library's own chip:
  `positions('Positions', …)` in `APP/features/library/widgets/library_list.dart`.
  The new cases assert the sentence through that enum's label, so a renamed
  chip turns the case red instead of leaving a sentence that points nowhere.

### Phase 2 — the server [lead] — built 1.10.2026

Backend 1979 → **1985** without a database (with and without `.env`), 2142 →
**2148** with one: six cases in `test/endgame_payload.test.js` (three per
route), and the `/by-id` case of `puzzle_progress_routes.test.js` given three
assertions, rewritten openly. All three mutations red on their cases. The
first of them — the label from `endgame_type` — **survived** at first,
because the blunder fixture carried the same key in both columns; it now
writes the type the other way round (`KRvKRP`), as an unnormalised key can.

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
  still holds the shared shape. *(Fable, 1.10.2026)* Its fixture row carries
  `solution` and `solution_san` (line 237), so its expectation loses the two
  keys and gains `material_label` — rewritten openly, the fixture row kept as
  it is because the table keeps the columns.
- Mutations, each red:
  - the label taken from `endgame_type` instead of `material`;
  - the field dropped from one route only;
  - *(Fable, 1.10.2026)* the null guard removed — `labelOf(null)` is `''`, and
    the app would draw an empty chip.

### Phase 3 — the draft belongs to the Analyse tab [implementer] — built by the lead, 1.10.2026

Small enough to do inline. `_ownsDraft`, one getter read by restoring,
`_saveDraft` and the `dispose` flush. `T/analysis_draft_owner_test.dart`, ten
cases (the tab's screen, and three per kind of `initial…`): nine red on the
old code; the `_saveDraft` guard off turns exactly the three „after a move"
cases and the three „byte for byte" cases red, the flush guard off exactly the
three „when it is popped" and the three „byte for byte". Of the seven files
the grep named, **one** relied on a pushed screen writing the draft:
`engine_hold_test`'s „a review lands on the live Analysis screen … and goes
into its draft" pumped a screen handed `initialTree`. Split openly in two —
the marks land on a pushed screen and leave the draft alone, and they reach
the draft on the tab's own screen (seeded with the unmarked game). The other
six, run on their own: 53 green.

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
- *(Fable, 1.10.2026)* The guard is one getter read in three places (D7); the
  two mutations above are each one reader of it turned off, not the getter
  itself — the getter removed would turn both cases red and say nothing about
  which reader was missing.

### Phase 4 — the answer: `Show solution`, the reply and the engine's estimate [implementer; gate by the lead]

Covers D3, D8 (the app side), D9 and *(Fable, 1.10.2026)* the app half of
D12. `EndgameSolveSession` gets a fourth status, `revealed`: complete, never
`countsAsSolved`, and `submit` is refused in it.

*(Fable, 1.10.2026)* Read before briefing: the attempt is recorded at the
**first correct move** (`_countedThisPuzzle`), with `hinted: usedHint ||
_readouts > 0`, and `_loadNext` records a skip only while `_countedThisPuzzle`
is false — so `Show solution` sets that flag and the rest of case 3 follows
from code that exists. The button rows are `Wrap`s, so a sixth button
overflows nothing; the gate still looks at 360 × 640, because a `Wrap` that
wraps pushes the board.

**Gate** (new `T/endgame_answer_test.dart`, over a fake `http.Client` (rule 7)
and the attempt log's fake client):
1. `Show solution` is on the screen while solving, and absent after a solve,
   after a shown answer and *(Fable)* while a drill runs. The rest of that
   button row is present, so the absence is checked where the button would be.
2. It names every holding move in SAN, in the sentence D3 gives. The fixture
   has three, one of them an underpromotion. The board refuses a drag
   afterwards. *(Fable)* A second fixture with one move gets the „only move"
   sentence.
3. It records one attempt, `solved: false`.
   - `Next` afterwards records nothing more, not also a skip.
   - After a hint, the record is `hinted: true`.
   - After a wrong move there is still only one record.
4. Exact position (`canBePlayedOut`): a correct answer sends `POST
   /api/puzzles/endgame/play` with the puzzle's FEN and the move. *(Fable,
   1.10.2026, rewritten with D8)*: the verdict sentence is on the screen
   **before** the reply arrives and the board shows the reader's move; when the
   reply arrives the board shows the server's `fen` — the fixture's reply
   underpromotes, so the FEN on the board has the knight. After `Find the
   rest`, a second correct move sends a second request with the same FEN and
   that move.
   - 4b. The server answers `held: false` with no reply: the sentence stays,
     the board stays on the reader's move, and no second verdict is shown.
5. Engine position:
   - a correct answer sends no request;
   - the chip `Engine estimate` is shown, and `Exact from tablebases` is not;
   - a wrong move says „The engine judges that this move drops the win. Try
     another."
6. Exact position: no `Engine estimate`, and a wrong move keeps „That move drops
   the win. Try another."
7. The fake holds a reply back until after `Find the rest`, and once more until
   after `Next`. Neither reply reaches the board.
8. A 503 from `/play`: no reply, and the verdict sentence stays — not the
   drill's „Tablebase is currently unavailable…" either.
9. `EndgameSolveSession`, pure: `reveal()` leads to `revealed`, complete and not
   counted, and `submit` is refused after it.
10. *(Fable, 1.10.2026 — D12's app half)* With `material_label` in the
    payload the chip reads „Rook and pawn versus rook" and the `Save for
    later` title „Rook and pawn versus rook — unclear"; with the field null
    both fall back as D12 says. The wire test's fixture carries the field.

Also:
- Rewritten openly: the two `opponentReply` cases in
  `T/endgame_solve_session_test.dart`.
- Mutations, each red on its own case:

  | Mutation | Case |
  |---|---|
  | the token check on the late reply removed | 7 |
  | the board left on the reader's move when the server's `fen` arrives | 4 |
  | the screen taking its verdict from the server's `held` | 4b |
  | the request sent once per position instead of once per found move | 4 |
  | `Show solution` drawn after a solve | 1 |
  | `solved: true` recorded | 3 |
  | the request sent for an engine position | 5 |
  | the chip drawn for an exact position | 6 |
  | the chip reading `type` instead of `materialLabel` | 10 |

  *(Fable, 1.10.2026)* „The promotion forced to `q`" left this table with D8's
  amendment: the screen replays nothing. It stands in phase 5's table instead,
  against the builder.

### Phase 5 — `Open in Analysis`, and the way back [implementer; gate by the lead]

Covers D1, D2, D5, D6 and D14.
- A pure builder, `EG/services/endgame_analysis_tree.dart`, in the shape of
  `opening_position_tree.dart`: a child that plays the same move is reused,
  never doubled.
- The trainer keeps the drill's moves as it goes. `DrillStep` reads `playedUci`
  and `reply.uci`, which the server already sends *(Fable, 1.10.2026: checked
  in `judgeMove` — both are in the result; `DrillStep` reads neither today, so
  the model gains two fields and `drill_step` gets a case for them)*. `Take
  back` keeps the taken-back move in the list as a dead end (D15); `Start
  over` clears the list.
- *(Fable, 1.10.2026)* The list is **new state** (§2: the drill keeps no
  history). It is a list of (FEN before, UCI played, UCI replied or null), so
  the builder replays each pair on the board it names and never looks a node
  up by FEN — the server's `fen` is chess.js's and the tree's FENs are the
  app's, and across that boundary two strings are one board only by
  placement, side and castling (`CLAUDE.md`, 30.9.2026). The node Analysis
  stands on is the last node the replay produced.
- `openTreeInAnalysis` gains `blackOrientation`, and `AnalysisStudioScreen` an
  `initialBlackOrientation` for a tree.

**Gate, the tree** (new `T/endgame_analysis_tree_test.dart`, pure):
- The root is the puzzle's FEN.
- The children are the reader's moves in the order found, then the other holding
  moves in the server's order, then the game's move.
- *(Fable, 1.10.2026)* Each found move carries the reply it was given, and a
  found move whose reply never came (503, or the server said `held: false`)
  is a leaf. The fixture has two found moves, the first with a reply and the
  second without.
- *(Fable, 1.10.2026)* A game's move that is also a holding move is one node,
  not two — the „reused, never doubled" rule, with a case of its own; and a
  position with `game` and no `played_move` (a master-game row) adds no
  branch.
- The drill line:
  - a drill whose first move holds continues under that branch;
  - one whose first move loses adds a last branch;
  - a Punish line hangs under the game's move.
- The tree stands on the root when opened from solving, and on the last move
  when opened from the drill.
- `Take back` (D15): the taken-back move is a side branch of the position it
  was played from — a leaf, since the server sends no reply to a losing move —
  and the move played instead continues the line. The fixture takes back twice
  from the same position, so the case can tell „kept" from „kept the last one".
  `Start over` leaves no branch.
- *(Fable, 1.10.2026)* A reply that underpromotes is replayed as that piece:
  the node after `e7e8n` has a knight on e8.
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
   Back, N loads the next position (one request). *(Fable, 1.10.2026)* The
   first half holds because `ActionKeyShortcuts` is a `Focus`, not a global
   handler (§2); the second because a popped route hands the focus back to the
   scope below. If the second half is red, the cure is the trainer asking for
   its focus when the pushed route's future completes — not a handler that
   listens through the route above.
5. A drill that was over is still over after Back: its sentence and `Take back`
   are there.
6. Once with the real `AnalysisStudioScreen`, pumped as `T/analysis_bar_test.dart`
   pumps it: its bar has a back arrow, and pressing it returns to the trainer as
   in case 1. *(Fable, 1.10.2026)* And once at **360 × 640**, pushed: the bar
   has never been measured with a back arrow in it — `analysis_bar_test` pumps
   the screen as `home`, where there is none — and the opening report has been
   pushing it since 30.9.2026, so a bar that overflows there is dormant on
   master (rule 14). The case asserts no `RenderFlex` overflow and the bar's
   targets on the screen.

**Mutations**, each red:

| Mutation | Red in |
|---|---|
| the children's order swapped | the tree |
| the reply hung under the root | the tree |
| a comment written on the game's move | the tree |
| standing on the root when opened from the drill | the tree |
| *(Fable)* the reply's promotion suffix dropped — `e7e8n` replayed as a queen | the tree |
| *(Fable)* the game's move added as a second child when it also holds | the tree |
| *(Fable, D15)* the taken-back move dropped from the list — `Take back` written as `removeLast` | the tree |
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
- *(Fable, 1.10.2026)* The router's `/analysis?fen=` door —
  `AppRoutes.analysisWithFen` and the `fen` query the route reads — which
  nothing in `lib/` calls. Listed for the next deletion batch, not deleted
  here: it is outside the module, and the owner batches deletions.
- *(Fable, 1.10.2026)* `Open in Analysis` from `Game blunders` is above; so is
  a reply after a correct answer in the game walk, which has its own screen and
  was not asked about.

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
| [261.12] | *(Fable)* After `Find the rest`, the second move found also gets its reply, and in Analysis each found move has its reply under it. |
| [261.13] | *(Fable)* On the phone: Analysis opened from the trainer, at the narrowest width — the bar's back arrow and its words all there, nothing cut. |
| [261.14] | *(Fable, D15)* A move taken back in the drill is a side branch in Analysis, and the Syzygy panel shows why it lost. |

## 9. Fable's review, 1.10.2026

Read against the code on 1.10.2026, not run. What was checked and holds, so
nobody checks it twice:
- The screen's four unused parameters, the `'custom'` branch, `accepted`,
  `solutionSan`, `import_endgame_puzzles.js` — all as §2 says; no test passes
  the parameters, and `endgame_wire_format_test` sends `maxPieces: 5` at line
  36.
- `openTreeInAnalysis` pushes with `Navigator.of(context).push`; the only
  `context.*` navigation in `AN/` is `context.push(AppRoutes.preferences)`;
  the `AppBar` sets no `leading`; `_loadTree` orients to the side to move at
  the stand-on node.
- `/endgames` is a top-level `GoRoute` (there is no shell route in the
  router — the tabs are widgets of `HomeScreen`), so a route pushed from the
  trainer sits on the root navigator and the system Back pops it.
- Phase 3's seven files are exactly the grep's answer.
- `judgeMove` sends `playedUci` and `reply.uci`; `buildEndgamePayload` is one
  builder and `/by-id` goes through it; `labelOf` is exported.
- `[260.2]` is the last live item, so `[261.1]` is free; `[0l.b240]`,
  `[0l.b242]` and `[0j.b262]` exist.

What the review changed, each marked where it stands:
1. **D8's cost** was one request; it is two probes, at least one to Lichess,
   and one request per found move, not per position. The condition is
   `canBePlayedOut`; the board takes the server's `fen`; a `held: false` is
   logged, never shown.
2. **D10** listed `repertoire.html`, which says „master games" about the
   opening book and must not change; the phase 1 grep gate was scoped the same
   way, because `mistake_rule.dart` would have failed it for the same right
   reason.
3. **D12's app half** had no phase; it is in phase 4, with the map's three
   readers named and the `labelOf(null) == ''` guard.
4. **D14's seam** changes a typedef, which touches the opening report's test
   — the ninth file, named in advance.
5. **D15**: the taken-back drill move stays in the tree as a side branch.
   Recommended in the review; the owner accepted it the same day.
6. **Phase 5** was written as if the drill had a move list; it has none, so
   the list is named as new state, and the builder replays pairs rather than
   matching FENs across the chess.js boundary.
7. **Gates added**: the shown answer's literal sentence; `Show solution`
   absent in a drill; a second found move's request; the server's `fen` on
   the board; `held: false`; the reply's promotion in the tree; a game's move
   that also holds; the pushed bar at 360 wide; D7 as one getter with three
   readers; the null guard on the label.
8. **Phase 0** counts one more thing: `material` keys `labelOf` cannot parse.
9. **§7**: the dead `/analysis?fen=` door, for the deletion batch.

Nothing in this review waits on the owner: D15 was put to him and accepted on
1.10.2026. Phase 0 starts on his word.
