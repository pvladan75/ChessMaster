"""Does each part stand on the game, and is each question's answer the best move?

    python check_positions.py out/B-api-deepseek-flash-...
    python check_positions.py out/B-... --engine          # also Stockfish, depth 22

Written on 13.9.2026, after the first vendor trial showed what the grader cannot
see. `grade_tutorial.dart` asks whether the app would take a file: every FEN
loads, every line replays from it. A FEN that is the game's position with the
rook on a1 quietly missing loads and replays perfectly, so it grades CLEAN — and
five of those came back in one afternoon, plus two whose move number was off by
one, which the child reads as „4… Be7" where the game says „3… Be7".

Two questions, then, and neither is the grader's:

 * **Is this part's position one the game or its review actually reached?** Every
   position of the reviewed PGN is collected, variations included — a part that
   stands on a better-move line is teaching, not invention. When a part matches
   none, the nearest position is found and the squares that differ are named, so
   „dropped a rook" and „invented a board" read differently.
 * **With `--engine`, is each `ask_move` answer Stockfish's first choice, and by
   how much?** The bar this experiment set is first choice *by a clear margin*,
   and the margin is printed rather than judged here — a margin is a number, and
   the threshold is a decision for the person reading it.

Exit code 0 when every part is exactly a position of the game, 1 otherwise.
"""

import argparse
import json
import os
import subprocess
import sys

import chess
import chess.pgn

HERE = os.path.dirname(os.path.abspath(__file__))
FIELDS = ['board', 'side', 'castling', 'en passant', 'halfmove', 'fullmove']
MATE = 100000


def positions_of(pgn_path):
    """Every position the reviewed PGN reaches, keyed by board + side to move.

    The value is every (full FEN, where) that reached it, not the first: a
    position can repeat, and a threefold draw is one board with three move
    numbers. Keeping only the first reported a part standing on the third
    occurrence as having the wrong counters - a false alarm about the very fault
    this check exists for.
    """
    with open(pgn_path, encoding='utf-8') as fh:
        game = chess.pgn.read_game(fh)
    found = {}

    def note(board, where):
        key = ' '.join(board.fen().split()[:2])
        found.setdefault(key, []).append((board.fen(), where))

    def walk(node, where):
        note(node.board(), where)
        for i, child in enumerate(node.variations):
            walk(child, where if i == 0 else 'review variation')

    walk(game, 'game')
    return found


def pieces(fen):
    board = chess.Board(fen.split()[0] + ' w - - 0 1')
    return {sq: board.piece_at(sq).symbol() for sq in chess.SQUARES
            if board.piece_at(sq)}


def nearest(fen, known):
    """The known position with the fewest squares differing, and those squares."""
    model = pieces(fen)
    best = None
    for occurrences in known.values():
        real_fen, where = occurrences[0]
        real = pieces(real_fen)
        diff = sorted(chess.square_name(s) for s in set(model) | set(real)
                      if model.get(s) != real.get(s))
        if best is None or len(diff) < len(best[1]):
            best = (real_fen, diff, model, real, where)
    return best


def engine_ranking(fen, answer):
    """(rank of [answer] or None, its score, the best other score), side to move's view."""
    out = subprocess.run(
        [sys.executable, os.path.join(HERE, 'analyze.py'), 'fen', fen,
         '--depth', '22', '--multipv', '4'],
        capture_output=True, text=True, encoding='utf-8', errors='replace')
    data = json.loads(out.stdout)
    if not data.get('ok', True):
        return None, None, None, data
    white = fen.split()[1] == 'w'

    def score(line):
        if line.get('mate_in') is not None:
            m = line['mate_in']
            value = (MATE - abs(m)) * (1 if m > 0 else -1)
        else:
            value = line['cp_white']
        return value if white else -value

    lines = data['lines']
    rank = next((l['rank'] for l in lines if l['moves'] and l['moves'][0] == answer),
                None)
    mine = next((score(l) for l in lines if l['moves'] and l['moves'][0] == answer),
                None)
    others = [score(l) for l in lines if not l['moves'] or l['moves'][0] != answer]
    return rank, mine, (max(others) if others else None), data


def shown(value):
    if value is None:
        return '?'
    if abs(value) > MATE / 2:
        distance = MATE - abs(value)
        return ('mates in %d' if value > 0 else 'is mated in %d') % distance
    return '%+.2f' % (value / 100.0)


def margin(mine, other):
    """In pawns; a mate has no margin in pawns, so the two scores speak for it."""
    if mine is None or other is None:
        return '?'
    if abs(mine) > MATE / 2 or abs(other) > MATE / 2:
        return 'n/a, a mate is involved'
    return '%+.2f' % ((mine - other) / 100.0)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('run_dir')
    parser.add_argument('--game', help="defaults to the run's meta.json")
    parser.add_argument('--engine', action='store_true',
                        help='rank every ask_move answer with Stockfish, depth 22')
    cfg = parser.parse_args()

    run_dir = os.path.abspath(cfg.run_dir)
    game = cfg.game
    if not game:
        with open(os.path.join(run_dir, 'meta.json'), encoding='utf-8') as fh:
            game = json.load(fh)['game']
    known = positions_of(os.path.join(HERE, 'input', '%s_reviewed.pgn' % game))
    with open(os.path.join(run_dir, 'tutorial.json'), encoding='utf-8') as fh:
        parts = json.load(fh).get('positionList') or []

    print('%s  (%s, %d positions in its review)' % (os.path.basename(run_dir),
                                                    game, len(known)))
    all_exact = True
    for i, part in enumerate(parts, 1):
        fen = part.get('fen') or ''
        kind = part.get('kind') or 'show'
        try:
            chess.Board(fen)
            legal = ''
        except ValueError as exc:
            legal = '  [python-chess cannot read it: %s]' % exc
        hit = known.get(' '.join(fen.split()[:2])) if not legal else None

        if hit:
            def differing(real):
                return [FIELDS[n] for n, (a, b) in
                        enumerate(zip(fen.split(), real[0].split())) if a != b]
            # The occurrence this part matches best, and the game over a variation.
            real = min(hit, key=lambda r: (len(differing(r)), r[1] != 'game'))
            diff = differing(real)
            if diff:
                all_exact = False
                verdict = '%s, but %s differ (model: %s, %s: %s)' % (
                    real[1], ' and '.join(diff),
                    ' '.join(fen.split()[4:]), real[1], ' '.join(real[0].split()[4:]))
            else:
                verdict = 'exact, %s' % real[1]
        else:
            all_exact = False
            if legal:
                verdict = 'UNREADABLE' + legal
            else:
                real_fen, squares, model, real, where = nearest(fen, known)
                if not squares:
                    # Every piece where a real position has it, and still not
                    # that position: the side to move, the castling rights or
                    # the en passant square is what is wrong. „Differs on 0
                    # squares" said nothing, and it is the one case where the
                    # board a child sees is right and the move they must find
                    # belongs to the other side.
                    fields = [FIELDS[n] for n in (1, 2, 3)
                              if fen.split()[n:n + 1] != real_fen.split()[n:n + 1]]
                    names = ' and '.join(
                        'side to move' if f == 'side' else f for f in fields)
                    verdict = ('NOT IN THE GAME: the pieces stand as in a %s '
                               'position, but the %s %s (model: %s, real: %s)' % (
                                   where, names or 'counters',
                                   'differs' if len(fields) == 1 else 'differ',
                                   ' '.join(fen.split()[1:4]),
                                   ' '.join(real_fen.split()[1:4])))
                else:
                    verdict = ('NOT IN THE GAME: nearest %s position differs on '
                               '%d square(s) — %s' % (
                                   where, len(squares),
                                   ', '.join('%s model %s / real %s' % (
                                       s, model.get(chess.parse_square(s), '-'),
                                       real.get(chess.parse_square(s), '-'))
                                       for s in squares)))
        print('  part %2d  %-10s %s' % (i, kind, verdict))

        if cfg.engine and kind == 'ask_move' and not legal:
            answer = part.get('solutionSan')
            rank, mine, other, data = engine_ranking(fen, answer)
            if rank is None and mine is None and other is None:
                print('           engine: could not analyse (%s)' % data.get('error'))
            else:
                print('           engine: %s is %s, %s against the best other '
                      '%s (margin %s, side to move\'s view)' % (
                          answer, '#%d of 4' % rank if rank else 'NOT IN THE TOP 4',
                          shown(mine), shown(other), margin(mine, other)))
    sys.exit(0 if all_exact else 1)


if __name__ == '__main__':
    main()
