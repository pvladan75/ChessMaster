# The local masters database

A tutorial made from a game says what master games played in its opening
(`docs/PLAN-SKELET.md`, phase 2). Those statistics come from a SQLite file on
the server, not from the Lichess masters explorer — decision D5 of that plan,
with the measurement that decided it. This folder is how that file is made and
how the server is held to it.

| | |
|---|---|
| `extract_stats.py` | reads a PGN file and writes the database |
| `export_polyglot.py` | writes the server's Polyglot table and the keys its test checks against |

Neither is part of the app or the server; both are run by hand.

## The server's database

Built on 14.9.2026 from the Lumbras GigaBase OTB file
(`LumbrasGigaBase_OTB_Complete.pgn`, 8.6 GB, 10,355,488 games):

```
python tools/opening_book/extract_stats.py --file <path>/LumbrasGigaBase_OTB_Complete.pgn --elo-rule min
```

| setting | value | why |
|---|---|---|
| rating | both players 2200+ (`--elo-rule min`) | the Lichess masters rule. An average of 2200 let in uneven pairings, and its draw rate ran 6.5 points below Lichess's; both players brought it to 2.9 |
| correspondence games | left out | the OTB file contains 363,646 of them, played with an engine |
| plies | the first 30 | an opening; a game still in the book after move 15 leaves it early |

The result: 2,567,674 games, 24,143,897 (position, move) rows, 512 MB, 653 s on
six workers. `PRAGMA quick_check` ok. The file is not in the repository — it is
copied to the server by hand and `MASTERS_BOOK_PATH` points at it
(`chess_backend/.env.example`, `docs/TODO-objavljivanje.md`).

The table is `position_stats (zobrist, move, w, b, d)`: the Polyglot hash of the
position as a signed 64-bit integer, the move packed as
`from | to << 6 | promotion << 12`, and White wins, Black wins and draws.

## Holding the two ends together

The server computes the key of a FEN in JavaScript
(`chess_backend/services/mastersBook.js`), and a key that differs by one bit
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
- `--probe "<FEN>" --db <file>` prints what the database holds for a position.
- `--max-mb 200` builds a trial database from the start of the file.

The owner's first copy of the script, outside the repository, named its progress
columns in Serbian (`partije`, `uzete`, `preskocene`). A database that copy
started cannot be resumed by this one; finished databases are unaffected, since
the server reads only `position_stats`.
