"""The server's half of the local opening database: Polyglot's keys, in JavaScript.

    python tools/opening_book/export_polyglot.py            # write both files
    python tools/opening_book/export_polyglot.py --check    # exit 1 if they are stale

Phase 2 of `docs/PLAN-SKELET.md`, decision D5: the masters statistics come from
a SQLite file keyed by the Polyglot Zobrist hash of each position, which
python-chess computed when the file was built. The server has to compute the
same 64 bits for a FEN, or every lookup finds nothing - and finds nothing
**silently**, which reads exactly like a game that left the book on move one.

So nothing here is written by hand:

 * `chess_backend/services/polyglotRandom.js` is python-chess's own
   `POLYGLOT_RANDOM_ARRAY`, the 781 constants of the Polyglot book format;
 * `chess_backend/test/fixtures/polyglot_keys.json` is python-chess's
   `zobrist_hash` for every position of the ten harness games and for the cases
   those games may not reach - en passant with and without a pawn to take,
   every combination of castling rights, promotions - which the server's test
   reads back.
"""

import argparse
import glob
import io
import json
import os
import sys

import chess
import chess.pgn
import chess.polyglot

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TABLE = os.path.join(REPO, 'chess_backend', 'services', 'polyglotRandom.js')
KEYS = os.path.join(REPO, 'chess_backend', 'test', 'fixtures', 'polyglot_keys.json')
GAMES = os.path.join(REPO, 'tools', 'game_annotate', 'input')


def table_text():
    values = chess.polyglot.POLYGLOT_RANDOM_ARRAY
    assert len(values) == 781, len(values)
    rows = ',\n'.join('  0x%016xn' % v for v in values)
    return (
        '// Polyglot\'s 781 random numbers, as python-chess holds them.\n'
        '// Written by tools/opening_book/export_polyglot.py - do not edit by hand.\n'
        '//\n'
        '// 768 for a piece on a square, 4 for castling rights, 8 for an en passant\n'
        '// file, 1 for White to move. See services/openingBook.js for how they\n'
        '// combine, and test/polyglot_keys.test.js for the proof they are right.\n'
        '\n'
        'module.exports = Object.freeze([\n%s,\n]);\n' % rows)


def signed(key):
    return key - (1 << 64) if key >= (1 << 63) else key


EDGES = [
    # En passant: the square counts only when a pawn of the side to move can
    # reach it, whatever the FEN says.
    'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
    'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2',
    'rnbqkbnr/pppp1ppp/8/8/3pP3/8/PPP2PPP/RNBQKBNR b KQkq e3 0 3',
    'rnbqkbnr/pppp1ppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
    'rnbqkbnr/pppppp1p/8/8/5Pp1/8/PPPPP1PP/RNBQKBNR b KQkq f3 0 3',
    'rnbqkbnr/pppppp1p/8/8/Pp6/8/1PPPPPPP/RNBQKBNR b KQkq a3 0 3',
    # Castling rights, one at a time and none.
    'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
    'r3k2r/8/8/8/8/8/8/R3K2R w Kq - 0 1',
    'r3k2r/8/8/8/8/8/8/R3K2R b Qk - 0 1',
    'r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1',
    # Every piece on the board, both sides to move, a promoted queen.
    '4k3/1P6/8/8/8/8/6p1/4K3 w - - 0 1',
    'Q3k3/8/8/8/8/8/8/4K2q b - - 0 1',
    '8/8/8/8/8/8/8/K6k w - - 0 1',
]


def keys_data():
    fens = []
    for path in sorted(glob.glob(os.path.join(GAMES, 'g*_plain.pgn'))):
        game = chess.pgn.read_game(io.open(path, encoding='utf-8'))
        board = game.board()
        fens.append(board.fen())
        for move in game.mainline_moves():
            board.push(move)
            fens.append(board.fen())
    # The chess package in the app and chess.js on the server write an en
    # passant square after every double push; python-chess only when a capture
    # is legal. The key must not depend on which of them wrote the FEN, and the
    # EDGES above include squares written with no pawn able to take.
    unique = list(dict.fromkeys(fens + EDGES))
    cases = [{'fen': fen, 'key': str(signed(chess.polyglot.zobrist_hash(chess.Board(fen))))}
             for fen in unique]
    return {
        'about': 'Written by tools/opening_book/export_polyglot.py from python-chess. '
                 'Do not edit by hand.',
        'cases': cases,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true')
    check = parser.parse_args().check
    outputs = {TABLE: table_text(),
               KEYS: json.dumps(keys_data(), indent=1, ensure_ascii=False) + '\n'}
    stale = 0
    for path, text in outputs.items():
        if check:
            current = io.open(path, encoding='utf-8').read() if os.path.exists(path) else None
            if current != text:
                print('STALE: %s' % os.path.relpath(path, REPO))
                stale += 1
            else:
                print('current: %s' % os.path.relpath(path, REPO))
        else:
            with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(text)
            print('written: %s (%d KB)' % (os.path.relpath(path, REPO), len(text) // 1024))
    sys.exit(1 if stale else 0)


if __name__ == '__main__':
    main()
