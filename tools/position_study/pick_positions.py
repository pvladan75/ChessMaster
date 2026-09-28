"""Picks the positions a study is measured on — phase 0 of
docs/PLAN-STUDIJA-POZICIJE.md.

    python pick_positions.py <own games .pgn> <classics .pgn> > positions.json

Ten positions, five from each file, by a fixed seed so the same ten come back:
four at set move numbers from four different games (the opening's end, two
middlegames, a late middlegame) and one ending with seven men or fewer. Only
the position, the moves that reached it and the move number are written —
never a header: the owner's games name people.
"""
import json
import random
import sys

import chess
import chess.pgn

MOVES = [11, 17, 23, 30]          # the full move whose position is taken
SEED = 2026


def games_of(path, want, rng):
    offsets = []
    with open(path, encoding='utf-8', errors='replace') as f:
        while True:
            at = f.tell()
            headers = chess.pgn.read_headers(f)
            if headers is None:
                break
            if headers.get('Variant', 'Standard') not in ('Standard', 'From Position'):
                continue
            if headers.get('Variant') == 'From Position' or 'FEN' in headers:
                continue
            offsets.append(at)
        rng.shuffle(offsets)
        for at in offsets:
            f.seek(at)
            game = chess.pgn.read_game(f)
            if game is None or game.errors:
                continue
            moves = list(game.mainline_moves())
            if want(moves):
                yield moves


def position_at(moves, fullmove, white_to_move):
    board = chess.Board()
    path = []
    for move in moves:
        if board.fullmove_number == fullmove and board.turn == white_to_move:
            break
        path.append(move.uci())
        board.push(move)
    return board, path


def first_with_men(moves, most, least_plies_left=6):
    board = chess.Board()
    path = []
    for k, move in enumerate(moves):
        men = chess.popcount(board.occupied)
        if men <= most and len(moves) - k >= least_plies_left \
                and board.pawns and not board.is_check():
            return board, path
        path.append(move.uci())
        board.push(move)
    return None, None


def pick(path, source, rng):
    out = []
    long_games = games_of(path, lambda m: len(m) >= 70, rng)
    for k, fullmove in enumerate(MOVES):
        moves = next(long_games)
        board, line = position_at(moves, fullmove, white_to_move=(k % 2 == 0))
        out.append((board, line, f'move {fullmove}'))
    for moves in games_of(path, lambda m: len(m) >= 80, rng):
        board, line = first_with_men(moves, 7)
        if board is not None:
            out.append((board, line, 'ending, seven men or fewer'))
            break
    return [
        {
            'id': f'{source}{n + 1}',
            'source': source,
            'what': what,
            'fen': board.fen(en_passant='fen'),
            'moves': ' '.join(line),
        }
        for n, (board, line, what) in enumerate(out)
    ]


def main():
    own, classics = sys.argv[1], sys.argv[2]
    rng = random.Random(SEED)
    positions = pick(own, 'own', rng) + pick(classics, 'classic', rng)
    json.dump(positions, sys.stdout, indent=1)
    sys.stdout.write('\n')


if __name__ == '__main__':
    main()
