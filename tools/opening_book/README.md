# The local opening database

Everything the app says about what was played in a position comes from a SQLite
file on the server, not from the Lichess explorer: the opening panel, the
judge's „this is theory", the repertoire's replies, and the walk a tutorial
makes through a game's opening. `docs/PLAN-SKELET.md` decision D5 moved the
last of those; `docs/PLAN-OTVARANJA-LOKALNO.md` moved the rest, on 15.9.2026.
This folder is how that file is made and how the server is held to it.

**One file, and no rating bands.** A student learns the sound move whatever
their own rating, so the book is games in which both players are 2200+ and
there is no filter to choose anything else.

| | |
|---|---|
| `extract_stats.py` | reads a PGN file and writes the database |
| `export_polyglot.py` | writes the server's Polyglot table and the keys its test checks against |

Neither is part of the app or the server; both are run by hand.

## The server's database

Built from the Lumbras GigaBase OTB file (`LumbrasGigaBase_OTB_Complete.pgn`,
8.6 GB, 10,355,488 games), in two commands:

```
python tools/opening_book/extract_stats.py --file <path>/LumbrasGigaBase_OTB_Complete.pgn \
  --elo-rule min --max-ply 50 --db <path>/LumbrasGigaBase_OTB_Complete_stats_min2200_ply50.sqlite
python tools/opening_book/extract_stats.py --prune \
  --db <path>/LumbrasGigaBase_OTB_Complete_stats_min2200_ply50.sqlite
```

| setting | value | why |
|---|---|---|
| rating | both players 2200+ (`--elo-rule min`) | the Lichess masters rule. An average of 2200 let in uneven pairings, and its draw rate ran 6.5 points below Lichess's; both players brought it to 2.9 |
| correspondence games | left out | the OTB file contains 363,646 of them, played with an engine |
| plies | the first 50 | at 30 the book ended mid-theory in **every** main line measured — eight openings all stopped at exactly ply 30 with 117 to 750 games still in the position |
| single-game rows | deleted (`--prune`) | a move played by one game is not a statistic. 85.1% of the rows in the 30-ply file, and 87.3% of its positions |

The 30-ply file it replaces: 2,567,674 games, 24,143,897 (position, move) rows,
512 MB, 653 s on six workers.

The file is not in the repository — it is copied to the server by hand and
`MASTERS_BOOK_PATH` points at it (`chess_backend/.env.example`,
`docs/TODO-objavljivanje.md`).

The table is `position_stats (zobrist, move, w, b, d)`: the Polyglot hash of the
position as a signed 64-bit integer, the move packed as
`from | to << 6 | promotion << 12`, and White wins, Black wins and draws. A
pruned file carries `position_totals (zobrist, w, b, d)` beside it.

## Why a pruned file keeps a second table

The count a position was reached is what the panel prints and what a tutorial
says out loud — „698 master games reached this position and none played it".
Computing it from the rows that survive pruning is 2.2% low on average over the
whole file, and **80%** low for the worst single position. So `--prune` writes
the real per-position totals **before** it deletes anything, and only for
positions that keep at least one move — so „no row" still means „not in the
book" and nothing has to guess which kind of silence it is looking at.

**A pruned file cannot be extended.** Adding games to totals whose single-game
rows are already gone is quietly wrong, so the script refuses and says to build
a new one.

`--max-elo` bounds the same rating `--elo-rule` reads, for a banded book. It is
unused: the app has one book and no rating filter. The measurements behind that
decision are in `docs/PLAN-OTVARANJA-LOKALNO.md`.

## Holding the two ends together

The server computes the key of a FEN in JavaScript
(`chess_backend/services/openingBook.js`), and a key that differs by one bit
finds nothing — which looks exactly like a game that left the book on its first
move. So:

```
python tools/opening_book/export_polyglot.py            # write the table and the keys
python tools/opening_book/export_polyglot.py --check    # exit 1 when they are stale
```

writes python-chess's own Polyglot constants into
`chess_backend/services/polyglotRandom.js` and python-chess's keys for 753
positions into `chess_backend/test/fixtures/polyglot_keys.json`, which
`test/polyglot_keys.test.js` reads back.

## Checking a database before trusting it

- `--verify-hash 20000` compares the extraction's incremental hash with
  python-chess on every ply of the first 20,000 games.
- `--probe "<FEN>" --db <file>` prints what the database holds for a position,
  reading the stored totals when the file has been pruned.
- `--max-mb 200` builds a trial database from the start of the file.

The owner's first copy of the script, outside the repository, named its progress
columns in Serbian (`partije`, `uzete`, `preskocene`). A database that copy
started cannot be resumed by this one; finished databases are unaffected, since
the server reads only `position_stats`.
