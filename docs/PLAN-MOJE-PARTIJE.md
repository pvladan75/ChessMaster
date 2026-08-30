# Plan: "Moje partije" — a corpus layer over a player's own games

Proposal, 30.8.2026. Nothing here is built. It came out of one question: a
player hands the app a ten-year Lichess archive — what can be done with it that
cannot be done one game at a time?

Everything below was sized against a real archive of **4073 games** (one Lichess
account, 2016–2026, exported to PGN). The numbers in this document are measured
from that file, not estimated, and they are what decides which of these features
are worth building and which are not.

## The measured baseline

| | |
|---|---|
| Games | 4073, Feb 2016 → Jul 2026 |
| Time control | blitz throughout; 3593 of them 3+2 |
| Rating | 1446 → 1950, peak 2038 |
| Colour split | 2035 White / 2038 Black — 49.9% overall score |
| Length | mean 67 ply, median 62 |
| Reached ≤10 men | 878 games (21.6%) |
| Reached ≤7 men (Syzygy range) | 466 games (11.4%), of which **234 were not wins** (126 losses, 108 draws) |
| Distinct ≤7-men positions in the whole archive | **8673** |
| Lost on time | 221 (won on time: 434) |
| Distinct positions at ply 12 / ply 20 | 2749 / 3869 (most-repeated: 52× / 8×) |

Two of these rows are load-bearing.

**The signal lives between ply 6 and ply 20.** At ply 12 the 4073 games sit on
2749 distinct positions and the most frequent one recurs 52 times; by ply 20
there are 3869 distinct positions and the record-holder recurs 8 times. After
roughly move ten every game is nearly unique and per-position statistics stop
meaning anything. Any "opening report" must be built for that window and must
refuse to report outside it.

**The endgame audit is cheap and the opening report is free.** 8673 tablebase
lookups is twenty-odd minutes of paced traffic; counting move frequencies costs
no engine and no network at all. A whole-archive engine pass is the expensive
one — see *Costs* below.

## What exists today, and where it stops

The pieces are mostly here. What is missing is that every one of them is
**single-game**.

- `features/analysis_studio/services/chess_platform_import_service.dart` fetches
  from Lichess and Chess.com — but with `max = 20`, and
  `widgets/board_setup_dialog.dart` then asks the user to pick **one** of them.
- `features/analysis_studio/widgets/game_review_dialog.dart` walks one game
  through the engine, annotates every move, tags blunders, and extracts them as
  puzzles via `core/services/local_puzzle_extractor_service.dart` — stored
  on-device only.
- `features/analysis_studio/services/opening_judge_service.dart` already gives a
  per-move verdict (theory / playable / mistake / **unknown**) from Lichess
  masters, the rating band, and cloud eval.
- `features/analysis_studio/services/syzygy_tablebase_service.dart` and
  `chess_backend/services/tablebaseService.js` already probe Syzygy; the endgame
  trainer already plays a position out against it.
- SM-2 spaced repetition (`chess_backend/services/spacedRepetitionService.js`),
  the repertoire builder and drill, the tactical motif detector and the
  positional evaluator all exist.

**There is no table for a user's own games.** `blunder_games` is an imported
public dataset, not the user's. That single gap is what stands between the app
and everything below.

## 0. `user_games` — the prerequisite

A per-user archive plus a real import. Lichess `/api/games/user/{name}` streams
the *whole* history and takes `since`, so after the first pull it is
incremental. PGN upload covers players who are not on Lichess.

Small, and everything else is a query over it. Without it, each feature grows
its own copy of the import.

### The schema, frozen 30.8.2026

Three tables in `db.js`, created by `initDB()` like every other table here, plus
`services/gameArchive.js` — pure, no database and no network — which turns one
game's PGN into a row or into a named refusal. `test/game_archive.test.js`
covers it (backend suite: 541 → 556).

**`user_games`.** The columns that carry a point of view are named after the
**subject**, not the owner: `subject`, `subject_is_owner`, `subject_color`,
`subject_score`, `subject_elo`, against `opponent` / `opponent_elo`. Section 6
puts an opponent's archive in this same table, and columns named after the row's
owner would make every aggregation wrong the moment one is pointed at somebody
else — wrong while still returning numbers. The unique key is
`(user_id, source, external_id, subject)`, because two players' archives of the
same game are two points of view rather than a conflict.

Written once at import so nothing recomputes them: `moves` in UCI, `ply_count`,
`min_men` (fewest men the game ever reached) and `tb_entry_ply`. `min_men`
carries a partial index for `min_men <= 7`, which is what makes section 2 an
index lookup over the 11% instead of a replay of everything. `clocks` is
centiseconds per ply and **null when the export carried none** — an array of
nulls would read as "the clocks are known and they are empty".

**`user_game_imports`.** One row per run, with four counters —
`games_read`, `games_stored`, `games_duplicate`, `games_skipped` — and
`skipped_by_reason` as JSONB. Four and not three because re-running an
incremental import is the normal path, and an already-stored game is neither
stored nor skipped. A database constraint holds `read = stored + duplicate +
skipped` at `status = 'done'`, and `createTally().assertBalanced()` throws
before it gets that far. Both exist for the same reason: an importer that drops
games and reports success is this codebase's recurring bug wearing a new hat.

The five named refusals are fixed, and the tally rejects any reason outside
them: `unparsable-pgn`, `not-standard-variant`, `unfinished-game`,
`subject-not-in-game`, `no-moves`.

**`mistake_reviews`.** The parallel SM-2 store decided on 30.8.2026, with
`game_id REFERENCES user_games ON DELETE CASCADE` — the guarantee a nullable
`lesson_id` on `review_items` would have cost. Its SM-2 columns are named
exactly as `review_items`' are, so `schedule()` in `spacedRepetitionService.js`
is shared unchanged and owned by neither. `kind` is `engine` or `tablebase`, and
a check constraint requires a centipawn swing for the first and a *pair* of WDL
verdicts for the second: a tablebase mistake without both is an opinion wearing
the word "fact".

**Run over a real archive on 30.8.2026**, a fresh export of the same account:
4126 games read, 4126 rows produced, none skipped and none duplicate — so the
five refusals were exercised only by the unit tests, not by this file. ECO on
all 4126 (the export carried `opening=true`), clocks on 3632 of them; the rest
predate Lichess recording them. 471 games reached tablebase range. 276,877 plies
in 68 seconds, which says the parse is not what will make an import slow — the
stream is.

**Verified live by the user**, log timestamped 29.8.2026 23:40: `initDB()` ran
against the managed database and reported `user_games`, `user_game_imports` and
`mistake_reviews` after `room_guests`, and the server came up on port 3000. So
the DDL is applied, not merely written — including the two check constraints and
the partial index, which a database is free to reject at creation and this one
did not.

### The importer, written 30.8.2026

`services/gameArchiveImport.js` and `routes/userGames.js`, mounted at `/games`.
`test/game_archive_import.test.js` covers both (backend suite: 556 → 569).

**A whole archive is one request, not thousands.** Lichess streams a player's
entire history down a single response, so the rate limit that matters is not
requests per second — it is that this server has one address for every user of
the app, which is why even the single request goes through the same pacer as the
explorer.

**Four minutes is not a request**, so nothing waits for it. The endpoints:

| | |
|---|---|
| `POST /games/import` `{ username, since? }` | 202 `{ importId, since }`; the run continues after the response |
| `POST /games/import/file` multipart `archive` + `username` | **the primary path**: the player's own export, up to 25 MB, read as a stream and deleted when the run ends |
| `POST /games/import/pgn` `{ pgn, username }` | a paste, bounded by the 2 MB JSON body limit |
| `GET /games/imports` | the last runs, newest first |
| `GET /games/imports/:id` | one run: four counters, `skipped_by_reason`, status, error |
| `GET /games/stats` | games, with clocks, reached tablebase, subjects, oldest, newest, plies |

Four behaviours worth knowing before building against it. A run resumes from
`MAX(played_at)` for that subject, so the second import of an archive pulls only
what is new. A second concurrent run for one user is refused with 409 rather
than doubling every counter. A run left `running` by a restarted process is
reaped after thirty minutes, because otherwise one crash blocks that user
forever. And a run that fails writes its own reason into its row — the route's
response is not where a failure is reported, since by then the client is long
gone.

`subject_is_owner` is fixed at `true` in the route. The table and the importer
both carry somebody else's archive perfectly well — that is what section 6
needs — but whether this app lets one account pull a profile of a named child is
the decision named there, and it should not arrive by way of an unused
parameter.

**Upload is the primary path, decided 30.8.2026 by the project owner**, and the
reasoning generalises: the player exports their own games from Lichess and hands
the app the file. That removes the whole class of risk the pull carries — this
server has one address for every user, so a 429 earned by one import is
everybody's outage — and it works for Chess.com, ChessBase or a tournament PGN
without an integration each. What it costs is the one-tap refresh: a manual file
has no `since`, so a second upload re-reads the whole archive and lands as
duplicates. That is wasteful rather than wrong, and it is the cheaper of the two
failures.

The pull is still there and still tested. Whether it stays is open — it is the
only part of this that can spend an allowance shared by every child in the app.

Measured on the real 8.7 MB export, read as a file stream: 4126 games, 4126 rows,
none skipped, balanced, **40 seconds and a 209 MB peak RSS**. The memory figure
matters more than the time on a 960 MB droplet, and it is the reason the upload
goes to disk and is read back rather than held as one string.

The splitter is the part that could lose data quietly, so it is the part with
the strongest test: the same archive fed one byte at a time and all at once must
produce the same games. Proven by mutation — emitting the buffered tail eagerly
fails five tests, that one included.

## 1. Opening leak report

No engine, no tablebase, no network — pure counting. Group the positions where
**the user** was to move, at plies 8–16, over the whole archive.

On the sample archive, positions with at least 8 games:

| ply | recurring decisions | scoring under 42% |
|---|---|---|
| 8 | 47 | 10 |
| 10 | 43 | 14 |
| 12 | 24 | 6 |

The finding worth showing is not "you score badly here" but "you score badly
here **and you keep choosing the same move**". One ply-10 position: 35 games,
37.1%, the same knight move in 33 of them. One at ply 16: 15 games, 33.3%, the
same recapture all 15 times. That is a habit, not variance, and it is actionable
in a way a per-game blunder list is not.

At line level the same archive shows the Open Sicilian as White at 48.7% over
456 games, against `1.e4 d5 2.exd5 Qxd5` at **36.5%** over 89 — the worst
frequent line by a distance, and invisible without the corpus.

Hang `opening_judge_service.dart` off each flagged node and the report reads:
*"you played X in 33 of 35 games and scored 37%; the judge calls it playable but
second best; here is what the masters play."* The judge's fourth verdict,
`unknown`, must survive into the report — a node nobody has evaluated, shown as
a mistake, is the failure this codebase keeps meeting.

### Built 30.8.2026

`opening_nodes` in `db.js`, `services/openingLeaks.js`, and
`GET /games/openings/leaks`. `test/opening_leaks.test.js` covers it (backend
suite: 570 to 584).

One row per early decision the subject made — the position faced, the move
chosen — written by the importer on the same walk that already computes
`min_men`, so it costs nothing extra. Keyed on `fen_key`, **the same
first-four-FEN-fields key `repertoire_moves` uses**: transpositions are most of
the point, and keying it identically makes section 4 a join rather than a second
convention to keep in step. A test asserts the two keys agree, because two
spellings would not error — they would produce an empty diff, which reads as
"you never left your repertoire".

The window is enforced by the storage: nothing past ply 20 is written, and
asking the report for more is a `RangeError` rather than a quietly narrower
answer. Games whose nodes were never written are counted and returned as
`gamesWithoutNodes`, since an empty report otherwise reads exactly like a player
with no weaknesses; `POST /games/openings/backfill` fills them by replaying the
UCI already on the row.

**Measured on the real 4126-game archive, through the production extractor:**
18934 distinct positions in the window, 298 reached at least 8 times, and
**78 flagged** under 42%. The strongest finding is the shape the plan predicted —
as Black, one position reached 121 times, scored 41.3%, and the same move played
in 92 of them. Two more: 53 games at 38.7% with the same move 52 times, and 48
games at 39.6% with the same move 47 times.

That number also settles the allowance question. Judging is optional
(`&judge=true` with the caller's own `X-Lichess-Token`, which the judge route
already requires) and annotates the dominant move of the top N positions:
**ten requests for a top-10 report, seventy-eight to judge every leak** — about
twelve seconds through the existing pacer. A handful of requests, not a scan, so
no per-user token plumbing is needed to make this affordable.

A missing or refused token does not take the report down with it: the numbers
are computed before anything is asked of Lichess, and each node falls back to
`unknown` on its own. This codebase has twice shipped a bug where the message
about the work killed the work.

## 2. Syzygy endgame audit

Scan every position with ≤7 men and compare the tablebase verdict before and
after the user's move. A win→draw or draw→loss transition is a **fact**, which is
the property `tablebaseService.js` was written to protect: nothing there falls
back to an engine, because a guess dressed as an exact answer is worse than no
answer.

Cost is bounded and known: 8673 distinct positions, deduplicated and cached, at
the 150 ms gap enforced by `chess_backend/services/lichessPacing.js` — about
**22 minutes** for a ten-year archive, once. Yield: 234 candidate games. On the
sample archive the entry material is overwhelmingly rook-and-pawn (`KKPPPRR`
107×, `KKPPPPR` 40×), so the output is in practice a rook-endgame syllabus made
of the player's own positions.

Each found moment then becomes a play-it-out drill against the tablebase, which
the endgame trainer already does. This is a scan and a list, not a new mode.

### Built 30.8.2026

`tablebase_cache` and `endgame_audits` in `db.js`, `services/endgameAudit.js`,
and three routes under `/games/endgame`. Findings are written to
`mistake_reviews` with `kind = 'tablebase'` — the table built for them in
section 0, whose check constraint refuses a row missing either verdict.
`test/endgame_audit.test.js` covers it (backend suite: 584 to 596).

**One probe per position, not two.** The tablebase response carries a category
for every legal move, so the position *before* a move already says what every
move including the played one is worth. The position after is never asked about.

The two perspectives are the thing to get right and the thing the tests are
mostly about: a position's category belongs to the side to move, which is the
player; each move's category belongs to whoever moves next, which is the
opponent. The player's outcome after their own move is therefore the negation of
that move's category.

**Measured on the real archive, without touching the network:** 471 games
reached the tables, and auditing them probes **4255 positions** — only the
player's own moves, only inside the range. About **10.6 minutes** at the
existing 150 ms pacing, comfortably under the 22 minutes this plan estimated.

Two measurements corrected the design:

- **Endgame positions do not repeat inside one archive.** All 4255 probes are
  distinct. The material repeats heavily — 308 signatures, mostly rook and
  pawns — but the exact position does not, so `tablebase_cache` saves a first
  run nothing. What it buys is every run after it: re-auditing is free, and an
  incremental audit after twenty new games probes twenty games' worth. The
  original justification for that table, that different players' rook endings
  collide, was a guess and it was wrong.
- **The five-field cache key costs 83 lookups out of 4255**, under 2%. Keeping
  the halfmove clock — which is what separates a win from a `cursed-win` — is
  therefore almost free, and the correctness argument wins without a trade.

`positions_unknown` is a counter of its own and is never folded into anything
else. A position the tables will not commit to (`unknown`, `maybe-win`,
`maybe-loss`) is not a position the player got right; it is one nobody judged,
and counting it as either would turn this feature's single promise — that a
verdict here is a fact — into a guess.

## 3. The player's own mistakes as a puzzle set, on spaced repetition

`GameReviewDialog` already extracts blunders as puzzles and keeps `fenBefore`
and `moveUci`, so the exercise can start one move *before* the mistake. What is
missing:

- batch (200 games, not one),
- server-side persistence instead of on-device only,
- ranking by **recurrence** — the same motif missed forty times is a weakness;
  missed once is a bad day.

`review_items` gives SM-2 for free, but it is keyed to `saved_lessons`, so this
needs a second item type rather than a new algorithm.

## 4. Repertoire seed and diff

The repertoire builder and drill already exist. The archive makes two things
possible that hand-entry does not: **seed** a repertoire from what the player
actually plays, and then **diff** it — "you left your own repertoire in 118
games; here they are; drill exactly those nodes."

## 5. Weakness profile beyond the opening

Aggregate the detectors that already exist across the corpus: which tactical
motifs are missed versus executed, which positional factors correlate with
losses, score by phase and by game length.

Time trouble is the obvious extra axis and it is **not available from a default
Lichess export** — the sample file carries no `%clk` tags. Re-exporting with
`clocks=true` turns 221 time-forfeit losses from a count into something
analysable.

## 6. Trainer-facing layer

Everything above is single-player; this app is a coaching platform, and the
differentiating version is the one the trainer sees. A coach opens a student's
archive and gets the leak report, the endgame audit, and **homework generated
from that child's own mistakes** — `assignments`, `assignment_items` and
`custom_puzzles` already exist to receive it. The parent report gains a
before/after metric instead of activity counts.

## 7. Opponent preparation

Lichess serves **any** account's games to an unauthenticated caller; there is no
"my games only" restriction, and the app's existing import service already takes
an arbitrary username. Verified live on 30.8.2026 against a public GM account:
HTTP 200, no token.

```
GET https://lichess.org/api/games/user/{username}
    ?max=200&color=white&perfType=blitz&rated=true&opening=true&clocks=true
    &since={epoch_ms}&vs={other_username}
Accept: application/x-chess-pgn        (or application/x-ndjson for JSON)
User-Agent: <required — Lichess serves a fake 404 to unrecognised agents>
```

Three parameters matter for preparation specifically:

- **`vs=`** returns only the games between those two players — a head-to-head
  file in one request.
- **`opening=true`** adds `[ECO]` and `[Opening]` tags, computed by Lichess. No
  local ECO database is needed for classification, and the sample archive lacks
  them only because it was exported without this flag.
- **`color=` / `perfType=` / `rated=`** narrow the pull to the format the match
  will actually be played in.

Rate limits are per-caller, roughly 20 games/second anonymous and 30 with a
token, one stream at a time. That is why this must go through the existing pacer
rather than a bare `http.get`: the backend has one address for every user in the
app, so one greedy pull is everybody's outage.

Chess.com is already implemented in the same service through the public
`/pub/player/{name}/games/archives` endpoint, which is likewise open for any
player.

What preparation then produces is the leak report from section 1, run over the
opponent instead of the user: what they play against `1.e4`, where their score
collapses, which structures they avoid. The analysis code is the same; only the
subject changes. Worth building **after** section 1 exists, not before — it is
the same feature pointed elsewhere.

One judgement call belongs to the product, not to the code: this is an ordinary
and legitimate use of public data, and it is also a feature that lets an adult
compile a profile of a named child. Restricting it to opponents in an
already-accepted `trainer_students` edge, or to accounts above some rating, is a
decision somebody has to make rather than a default to accept.

## 8. Division of labour

Agreed 30.8.2026. Two agents, following the dynamic that has worked so far:
**Claude** as architect for the backend, the schema and security; **Gemini** as
executor for the UI, self-contained client logic and widget tests.

The line is not "server versus client". It is **what a wrong answer costs**:
anything that is a *guarantee* — a count that must be true, an access right, a
paced request, a number the user will believe — is written once, on the backend.
Anything that *shows* it is Gemini's. That is why two items below moved sides
from the first draft of this split: a counter computed in the UI can only count
what reached it, and a ranking computed on the client can only rank what it was
sent.

The `#` column is this document's own section numbers (0–6), not a separate
list.

| # | Claude | Gemini |
|---|---|---|
| 0 | `user_games` schema; Lichess import as a single stream; count in / out / **skipped, with reasons**, persisted | Import screen, progress, and the display of those three counts |
| 1 | Aggregation over plies 6–20, minimum-games and score thresholds, `opening_judge_service` integration (network-paced, so backend) | The report screen: table, board preview per flagged node, sorting, drill-down |
| 2 | ≤7-men filter, paced Syzygy probes, transition detection, **shared position-keyed cache**, results written to the database | Wiring the produced list into the existing endgame trainer; the rook-endgame syllabus screen |
| 3 | New `review_items` item type (schema decision, see below), server-side persistence, batch extraction, **recurrence ranking** | Solver UI starting one move before the mistake (`fenBefore` / `moveUci` already exist for this); review-session screen |
| 4 | Repertoire **seed** from played moves and the **diff** against the saved tree — both are the same aggregation as item 1 | The screen reporting which games left the repertoire, and handing those positions to the existing drill |
| 5 | Access rights through `trainerOwnsStudent` / `acceptedTrainersOf` **and nowhere else**; homework generation into `assignments` / `assignment_items` | Homework and before/after metrics in the trainer panel |
| 6 | Query-builder parameters (`vs=`, `opening=true`) through the pacer; the privacy decision; **server-side check that the AI output contains no numeral absent from its input** | Re-using the item-1 report for an opponent; the AI explanation's presentation |

Six corrections folded in, with their reasons, because the reasons are what will
not survive in a chat log:

1. **The import is one stream, not many requests.** The often-quoted "20–30 per
   second" is Lichess's *games streamed* per second on the export endpoint
   (20 anonymous, 30 with a token), not a permitted request rate. The limit that
   actually bites is a 429 that blocks **the address** for a minute — and up to
   an hour for whoever keeps knocking — which is what `lichessPacing.js` and its
   150 ms gap exist for. So the strict-pacing emphasis belongs on item 2 (8673
   probes), not on item 0, and no new number gets invented anywhere.
2. **The import counter is a backend guarantee.** This is the codebase's
   recurring bug — a step that skips silently and reports success — so the count
   is produced and stored where the skipping happens. The UI shows it.
3. **Counting move frequencies *is* the aggregation query.** Splitting "the
   counting algorithm" from "the aggregation" would produce two implementations
   of one computation, and they would disagree without saying so.
4. **Recurrence ranking is a query over the archive**, so it cannot live on the
   client.
5. **`review_items` needs a decision, not an extension.** It is keyed
   `(user_id, lesson_id, position)` with `REFERENCES saved_lessons ON DELETE
   CASCADE`. A second item type means either a nullable `lesson_id` plus
   `item_type` / `source_id` — weakening the foreign key that currently
   guarantees cleanup — or a parallel table. Decide before either side writes
   against it.
6. **A prompt is not a guardrail.** "The model may only restate computed
   numbers" is a request; the enforcement is structural — pass the numbers as
   data and reject any output carrying a numeral that is not in the input, or
   template the numbers outside the model entirely.

Two smaller notes. Nothing needs to be parametrised for *unauthenticated* access
to Lichess: the client never authenticates there today and does not need to.
And the repertoire **seed** was missing from the first draft of the split — it
is the more valuable half of item 4, since it is what spares a player from
hand-entering a thousand games of their own opening.

**The freeze point.** Items 1–6 are all queries over item 0's table. Parallel
work on item 0 is fine — schema and import against import UI — but nothing else
starts until **the schema is frozen and a seeded fixture database exists**.
Without that, Gemini builds against a shape that then moves.

**Tests belong to whoever wrote the layer**: Gemini owns the widget tests,
Claude owns `node --test`. A test written by the other side against an assumed
shape is how this repository once had a green suite over a `server.js` that did
not parse. Whatever lands updates the counts in `CLAUDE.md`, or the next session
cannot tell a shrinking suite from a passing one.

## Costs and limits

| Work | Volume | Feasible where |
|---|---|---|
| Opening leak report | 0 network, 0 engine | anywhere, instantly |
| Syzygy audit | 8673 paced requests | server, ~22 min, cached |
| Full engine pass | ~273k positions (~136k for the user's own moves only), ~7–8 h at depth 14 single-threaded | desktop batch, overnight |
| Cloud-eval for the same | ~273k requests | **never** — one IP, every user behind it |

The droplet has 960 MB and is already sharing itself with everything else;
whole-archive engine work does not belong there.

## Risks

- **The recurring bug is waiting here.** A bulk importer that silently skips 300
  unparseable games and reports success is exactly the failure this codebase
  keeps meeting. Count in, count out, count skipped, and say so.
- **Reporting past ply 20** means reporting noise as insight. The window is a
  rule, not a tuning parameter.
- **A 4073-game archive is an adult power feature.** If it also lands for minors
  it is another dataset under the same consent regime — and the standing rule is
  that exposure falls by holding less. Lichess archives are public either way,
  which argues for storing derived analysis rather than mirroring PGNs; that is
  an open decision, not a settled one.
- **Never let the AI layer produce its own numbers.** `ai/explain-position`
  already exists and is quota-gated; a narrative over the computed report is
  cheap to add, and must be fed only what was measured.

## Suggested order

1. `user_games` store, and a real (incremental, whole-archive) import.
2. Opening leak report — no engine, largest finding per unit of work.
3. Syzygy endgame audit — exact, cheap, reuses the endgame trainer whole.
4. Own-mistake puzzle set with SM-2.
5. Repertoire seed and diff.
6. Trainer-facing report and generated homework.
7. Opponent preparation, and only then an AI narrative on top.
