# The opening database becomes ours

Written 15.9.2026. Phase 2 of `docs/PLAN-SKELET.md` (decision D5) put one
feature — the walk a game tutorial makes through its opening — onto a local
SQLite file instead of the Lichess masters explorer. Everything else in the app
that asks what was played in a position still asks Lichess. This plan finishes
the move: the opening statistics come from one file this project builds, the
Lichess explorer is deleted rather than kept as a fallback, and the personal
token that gates half the repertoire trainer goes with it.

**What is not in scope.** Importing a player's own games from lichess.org
(`archive_api_service.dart`, `gameArchiveImport.js`), the Syzygy tablebase, and
the one-off puzzle importers all talk to Lichess and are not the opening
database. They stay.

## Why it is worth doing

Two reasons, and the second is larger than the first.

**The shared token is one throat.** `openingExplorerService.js` says it in its
own header: every trainer and every student spends one allowance, and a 429
earned by one of them closes the opening book for all. D5 met the same wall from
the other side — Lichess refused the measurement that decided it, twice, with a
429 at 1.2 s spacing.

**The repertoire trainer is off for almost everyone.** `openingJudgeService.js`
demands the *caller's own* Lichess token for all four of its upstream questions
and answers `no-token` without one. The explorer's header already records what
happens when a feature asks a user to create a token and paste it in: "most of
them will simply not do it". So `/opening-judge`, `/opening-judge/replies`,
`repertoireSpine`, the repertoire builder and the favourite-move judgement in
`routes/userGames.js` are, in practice, a feature nobody has. Two of those four
questions are the book; the other two are an evaluation that answers without a
token at all. Once the book is local, the gate has nothing left to protect.

## The decisions (owner, 15.9.2026)

1. **One base: 2200+, and no rating bands.** There is no pedagogical reason to
   build a repertoire out of sub-2200 games. A student learns the sound move
   whatever their own rating, rather than imitating what players at their level
   happen to blunder into. The rating filter is removed from the app, not
   re-sourced.
2. **Depth 50 plies, with single-game rows pruned.** The space the bands would
   have taken goes into depth, so sharp theory (Najdorf, Grünfeld) does not hit
   a wall at move 15. A move played by exactly one game is not statistics.
3. **No personal token anywhere.** `lichess.org/api/cloud-eval` answers
   anonymously (probed 15.9.2026: 200, depth 60), so the judge keeps its
   evaluation and loses its gate. The Lichess/ChessDB source switch goes too:
   the server serves opening theory to every signed-in user from the local file.
4. **The builder is in the repository** — and it already was:
   `tools/opening_book/extract_stats.py` has been tracked since phase 2 of the
   skeleton plan, in English, beside `export_polyglot.py`. The owner's own copy
   in `D:\chess_base` is the Serbian original it was translated from, and the
   two have drifted: the tracked one renamed the progress columns, so a database
   one of them started cannot be resumed by the other. **The tracked one is the
   builder**; `--max-elo` and `--prune` were added to it, and the file this plan
   builds is built by it.

## What was measured, 15.9.2026

Everything below was measured before the plan was written. The extraction
trials ran over the same 300 MB slice of `LumbrasGigaBase_OTB_Complete.pgn`;
the slice extrapolates faithfully, because its ply-30 run reproduces the
production file's size and row count within 2%.

**The production file today.** `LumbrasGigaBase_OTB_Complete_stats_min2200.sqlite`:
512 MB, 24,143,897 rows over 21,152,936 positions, 2,567,674 games of 10,355,488
read, both players 2200+, correspondence excluded, **the first 30 plies**.

**The 30-ply ceiling binds on every main line.** Walking the most-played move
from the start, eight openings all stopped at exactly ply 30 — with 117, 192,
198, 269, 750… games still in the position. The book does not end where theory
ends; it ends where the extraction was cut. `MAX_SPINE_DEPTH` is 12 student
moves, 24 plies *from the repertoire's root*, so a repertoire rooted a few moves
in already runs past the edge.

**What depth costs** (300 MB slice, full-file estimate in the last column):

| extraction | rows in the slice | slice size | whole file, before pruning |
|---|---|---|---|
| 2200+, ply 30 (today's file) | 1,254,189 | 25.3 MB | 512 MB, measured |
| 2200+, ply 40 | 2,150,352 | 43.3 MB | ~880 MB |
| 2200+, ply 60 | 3,785,203 | 76.0 MB | ~1.5 GB |

**What pruning single-game rows does**, measured on the whole production file
rather than on a slice, because a slice overstates it:

| | |
|---|---|
| rows played by exactly one game | 20,553,968 of 24,143,897 — **85.1%** |
| positions that keep no move at all | 18,469,853 of 21,152,936 — **87.3%** |
| games sitting in pruned rows, over surviving positions | **2.20%** on average |
| …for the worst single surviving position | **80%** of its games |

That last row is why `position_totals` exists. The panel prints "N games" and
the tutorial's narration says "698 master games reached this position and none
played it"; computing that number from the surviving rows would under-report it,
usually by nothing and occasionally by four fifths. The true per-position total
is written **before** the delete, and only for positions that keep a move, so
"no row" still means "not in the book".

**Pruning shortens the book in 8 of 13 harness games, and the last plies it
takes were carried by a single game.** Simulated against the ply-30 file:

| game | plies in book, all rows / rows played twice or more | games at the position where the pruned book stops |
|---|---|---|
| g09_caro-kann | 15 / 9 | 1 |
| g03_scandinavian | 13 / 10 | 1 |
| g06_zukertort, pvladan_2026-09-12 | 15 / 13 | 1 |
| french, g01, g02, g08 | −1 ply each | 1 |
| g04, g05, g07, g10, philidor | unchanged | — |

In every game that shortens, the position where the pruned book ends had been
reached by **one** master game. g09 spent six plies in a "book" one game deep.
This is a correction, not a loss — but it is a change to what a new tutorial
says, and P0 checks it rather than discovering it later.

**Why no bands, in numbers.** Banded books *were* measured before the owner
decided against them on pedagogy, and the numbers are kept here so the question
is not reopened from scratch: banding by the weaker player would have given
~1.72M games at 1400–1799 and ~4.29M at 1800–2199, at ~3 GB for the set; the
"Online" base cannot serve amateurs either way (median rating 2589, tenth
percentile 2270 — it is titled online play). 15.4% of OTB games carry no ratings
at all and are in no book, today's file included.

## The data

One file, built from `LumbrasGigaBase_OTB_Complete.pgn`:

```bash
python tools/opening_book/extract_stats.py --file LumbrasGigaBase_OTB_Complete.pgn \
  --min-elo 2200 --elo-rule min --max-ply 50 \
  --db LumbrasGigaBase_OTB_Complete_stats_min2200_ply50.sqlite
python tools/opening_book/extract_stats.py --prune \
  --db LumbrasGigaBase_OTB_Complete_stats_min2200_ply50.sqlite
```

- **Both players 2200+**, not the average of the two. D5's lesson: an average of
  2200 admits a 2500 against a 1900, and those games draw 23.6% of the time
  against 37.8% for the rest.
- **50 plies**, correspondence excluded, games with a `[FEN]` header excluded.
- **Pruned**, which adds `position_totals(zobrist, w, b, d)` — the true counts,
  taken before the delete, for positions that keep at least one move.
- `meta` carries `min_elo`, `elo_rule`, `max_ply` and `pruned`, so a file says
  what it is and the reader can refuse one that is not what it was configured
  as. A pruned file cannot be resumed: adding games to totals whose one-game
  rows are already gone would be quietly wrong, and the script exits saying so.

Extraction is one pass of ~30 minutes at 8 workers; pruning and the vacuum are
minutes. Expected result: under 500 MB.

## Phases

Each phase names its owner. **Lead** is this session; **worker** is a batch
under `docs/TASK-*.md` with a gate written first, in the shape
`skills/worker-batches` prescribes.

### P0 — the data (lead, done 15.9.2026)

- `tools/opening_book/extract_stats.py`: the script, plus `--max-elo` (the same
  rating the `min` rule already reads, bounded above) and `--prune`.
- One extraction at ply 50, then the prune.
- `--verify-hash` before the file is believed — the check the original author
  built for exactly this.
- **The gate:** every position the ply-30 file answers with a move played twice
  or more, the new file answers with the same counts; the thirteen harness games
  leave the book exactly where the simulation above says, and nowhere else.

**What came out.** 2,222 s of extraction at 8 workers, 46 s of pruning.
10,355,488 games read and 2,567,674 taken — the same two numbers as the ply-30
file, chunk for chunk. 69,002,376 rows before the prune, **4,507,012 after**
(93.5% deleted) over 3,552,524 positions, and **145 MB** — not the "under
500 MB" guessed above, which was a guess taken before pruning; the old file's
~21 bytes a row times 4.5 million rows, plus the totals, is that size.
`--verify-hash 20000` agreed with python-chess on 908,577 plies.

**The gate is `tools/opening_book/compare_books.py`**, kept because the next
change to the extraction needs the same four questions, and it passed all of
them. One correction to the gate as written above: "the same counts" cannot
hold, because a deeper extraction also counts games that reach a position only
*after* ply 30. So it asks that no row the old file backs with two games is
missing and none is lower, and prints how many rose: **0 of 3,589,929 missing,
0 lower, 12,039 rose (0.335%, at most +313)**; 0 of 2,683,083 positions without
a total, none fallen. The thirteen harness games stop exactly where the
simulation said, all thirteen.

Before it was run on the real file it was run on the wrong one — the old,
unpruned file passed as "new" — and its first version passed the walk there,
because it read the new file through the same "played twice" filter as the
simulation. It reads every row now, the way the server does, and fails eleven
checks on the wrong file.

`MASTERS_BOOK_PATH` in the development `.env` points at
`LumbrasGigaBase_OTB_Complete_stats_min2200_ply50.sqlite`. `kMastersBookPlies`
in `masters_walk.dart` is 50.

### P1 — `services/openingBook.js` (lead)

`services/mastersBook.js` is renamed and grows two things, keeping everything
else including its
Polyglot key and the tests that pin it to python-chess:

- **`position_totals` is read when it exists**, and the sum of the rows is used
  when it does not, so the file that is live today keeps working unchanged.
  `answer()` reports the true total and how many games are in moves it is not
  showing — a number the panel can print rather than an absence it has to guess.
- **Past the last ply is a third answer.** A position at or beyond the file's
  `max_ply` is `beyondBook`, never zero games: "nobody played this" and "this
  file does not go that far" send a trainer to different places, and the two
  reading the same is this repository's oldest recurring bug.
- The file is checked against its `meta` at open, and a missing file stays what
  it is today — a loud 503 with a reason, never an empty book.

Mutation-proved before anything else reads it.

### P2 — the explorer route (lead, done)

Written by the lead rather than briefed out, on the rule the batch method
states itself: do not run a batch where the specification would be longer than
the implementation. The route is eighty lines and two deletions.


- `GET /opening-explorer` answers from the book, and reports `unlisted` — the
  games in moves the panel is not shown, the pruned rows and the trimmed ones
  together — so the shares under the moves still add up to the count above them.
- `services/openingExplorerService.js` is **deleted**, with its cache, its pacer
  use and its four failure reasons; `opening_explorer_service.test.js` goes with
  it. `lichessPacing.js` stays: the judge's cloud-eval still uses it.
- `POST /opening-explorer/masters-walk` is untouched — the app calls it by that
  name and the game tutorial must not move.
- **`minRating` stops filtering anything.** The parameter stays on the wire
  because `opening_replies` is keyed by it and thirty-odd call sites pass it;
  the server normalises every value to one in a single place, and a test pins
  that two different values give identical answers, so nobody later believes it
  still filters.
- The route keeps `authenticateToken` and its limiter. There is no upstream
  allowance to protect any more, but a public endpoint reading a 500 MB file in
  a loop is a new exposure and this change does not open one.

### P3 — the judge (lead, done 15.9.2026)

Not a worker's: it changes what a student is told.

**What was built**, against the bullets below:

- The judge reads `sharedOpeningBook()` — one instance, shared with the explorer
  route, rather than a second handle onto the file. The band question,
  `ratingBucketsFrom`, `RATING_BUCKETS`, `MIN_BAND_GAMES`, and `band` and
  `minRating` in both payloads are gone, and so is `no-token` from the service,
  both judge routes, the spine route, the leak report's `annotate` and the app.
  `openingMoveNotation.js` is deleted with its test: it converted the Lichess
  explorer's castling, and the book writes castling the way the board does.
- **A position past the book's depth lists nothing**, even where a row exists
  by transposition, and says `beyondBook` — in the verdict's `masters`, in the
  reply list, and as a spine's third stop reason, `beyond-book`, which the
  build screen words apart from "too thin" (and `illegal` apart from both,
  which it had not been).
- **A missing book is a 503 with its reason on every route that reads it**,
  never a verdict from the engine alone: a theory gambit judged that way comes
  back a mistake.
- **Found on the way: the cloud evaluation writes castling as "king takes
  rook"** (`e1h1`), and `sanLine` read it literally, so a line stopped at the
  castling move without a word — "better was O-O" came out as nothing. Read as
  castling now, only where a king stands on the square.
- **`MIN_MASTER_GAMES` stays 10, measured.** Every move Lichess's cached
  masters answers name in the thirteen harness games was counted in the local
  file: median ratio 0.99 per move, 1.00 per position; at ten the local book
  keeps 783 of the 795 moves Lichess called theory and adds 23 of 376, all
  within a few games of the line.
- **`MIN_SPINE_GAMES` stays 100, measured.** It never bound against the band
  counts; against the book the most played line from nine common roots first
  drops under a hundred games 14 to 32 plies in, and four of the nine run the
  full 24 plies of `MAX_SPINE_DEPTH`.
- **The rating is gone from the server, not ignored in one place.** Every
  repertoire service and route stopped taking `minRating`; the four SQL sites
  on `opening_replies` bind `BOOK_BAND` and `BOOK_SOURCE`
  (`services/storedReplies.js`). The app still sends it (P4).

**`opening_replies` was rewritten, not cleared** — a departure from the bullet
below, for a reason measured on the development database: 396 stored
position-and-band sets from one user's 1,251 repertoire moves, and the drill,
the tree and the frontier read nothing else. Cleared, every branch they drew
would vanish until each position was opened in build mode again, with nothing
on screen saying why. So `source` is added (NULL for every old row), readers ask
for `source = 'book'`, and `refreshStoredReplies` rewrites the old rows from the
book once at start-up — deleting only positions the book cannot speak about.
Nothing holds a foreign key to the table: `repertoire_extra_replies` names a
position and a move, not a row.

**And it ran before it was reviewed.** The owner's `npm run dev` watches `.js`
files, so it restarted on the lead's uncommitted edits and ran the migration and
the refresh at 12:36 — while `.env` still named the ply-30, unpruned file. The
development database's replies are therefore that file's, one-game moves
included (298 positions, 1,442 rows). It ran once and unmutated: nothing was
written after 12:37, and the mutation run that followed found no NULL rows to
touch. **Re-run at the owner's request at 13:09 the same day**, against the
ply-50 book: `UPDATE opening_replies SET source = NULL` and a restart. 1,125
rows over 272 positions, every one `source = 'book'`, none NULL, and no stored
reply with fewer than two games — which only the pruned file can produce. The
26 positions that went are ones the pruned book does not cover.

- The masters question reads the local book. **The band question disappears
  entirely** — there is one book, so `bookAt(source:'lichess')`, `band` in the
  payload, `MIN_BAND_GAMES` and the rating buckets are deleted rather than
  redirected.
- The evaluation goes to the server's own request; `no-token` is deleted from
  the verdict vocabulary, from `routes/openingJudge.js`, from `repertoireSpine`,
  and from the app's `hasPersonalToken` gate.
- `MIN_MASTER_GAMES` is re-read against the new counts rather than carried over:
  it was ten against Lichess's masters totals, and both the base and the pruning
  have moved underneath it.
- **`opening_replies` holds rows fetched from Lichess bands** under
  `(fen_key, min_rating, uci)`, and local rows would mix with them invisibly.
  They are cleared once — a cache of an upstream fact, rebuilt on demand — and a
  `source` column is added so the next such swap is visible. Foreign keys from
  `repertoire_extra_replies` are checked before the delete, not after.

### P4 — the app (worker batch, gate by the lead)

The one piece worth a batch: it is bounded, it is specifiable against a frozen
server contract, and it is a sweep across a dozen files rather than a decision.

**The judge's token gate already went with P3**, because a server that no longer
asks for a token behind an app that still refuses without one is a feature
that stays off: `hasPersonalToken`, the `X-Lichess-Token` headers (judge,
replies, spine, leak report), the panel's no-token state and its "Uses your
Lichess token", the band sentence, and the leak report's no-token banner. What
is left for the batch, beyond the bullets below:

- **Owner's decision, 15.9.2026: a guest sees "Sign in to see the opening
  book."** When ChessDB goes, nothing in the app can show a signed-out reader an
  opening book, and the route stays behind sign-in (P2). The judge panel's own
  guest sentence, "Sign in required to judge moves.", stays as it is.
- Every `minRating` the app still sends — `OpeningJudgeService.judge` and
  `replies`, `buildSpine`, and the repertoire API's walks — and the model fields
  that read one back.
- Comments in the repertoire screens and services that still say a build
  "spends a Lichess request" or "the reader's allowance" — about fifteen in
  `repertoire_build_screen.dart` alone.


- The explorer panel loses its rating dropdown and names the position from
  `OpeningBookService.lookupByFen`, the ECO data the app already ships, since
  the book carries no names — the same way the tutorial does.
- `chessdb_service.dart`, the panel's ChessDB branch, `openingDbSource` and the
  Settings switch are deleted. A source-reading gate fails any file that imports
  the retired service.
- The repertoire build screen stops offering a rating band and stops sending
  one.
- Settings copy: the Lichess token field stays, and says what it is still for —
  importing your own games from lichess.org.
- The judge panel's `no-token` state and the repertoire screens' "you need a
  token" messaging go with P3.

### P5 — deploy and docs (lead)

`.env.example`, `deploy/app-setup.sh`, how the file reaches a server that is
still stopped, and what happens when it is absent — which must remain "the panel
says so", not an empty book. `STANJE-RADA.md` and `TODO-provera.md` get their
entries; the live checks are the explorer panel with no token anywhere, a
repertoire built by an account that has never seen lichess.org, and a game
tutorial whose opening sentence still reads.

## What still reaches Lichess when this is done

One request, twice per judged move, cached: `api/cloud-eval`. No token, the same
fixed number for everybody, and the reason a move can be called a mistake at
all. Everything about *what was played* is a file on our own disk.

## Risks

- **The book gets shorter where it was thinnest.** Eight of thirteen harness
  games leave it one to six plies earlier. Every one of those plies rested on a
  single game, so this is the fix and not the cost — but a tutorial made
  tomorrow will not say quite what one made yesterday said.
- **Every threshold tuned against Lichess moves.** `MIN_MASTER_GAMES`,
  `MIN_SPINE_GAMES`, the frontier's minimums. Re-read in P3, not assumed.
- **A `minRating` that no longer filters is a parameter waiting to be believed.**
  One normalising place, one test that two values agree, and the comment that
  says why it is still on the wire.
- **The repertoire concept "which level is this for" disappears from the UI**
  while the column stays in the database. Old rows keep their number and it
  means nothing; the stored replies are cleared so nothing reads a band that no
  longer exists.
