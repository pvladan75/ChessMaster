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
