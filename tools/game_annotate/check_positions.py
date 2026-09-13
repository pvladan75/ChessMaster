"""Does each part stand on the game, and is each question the analysis we sent?

    python check_positions.py out/B-api-deepseek-flash-...

Written on 13.9.2026, after the first vendor trial showed what the grader cannot
see. `grade_tutorial.dart` asks whether the app would take a file: every FEN
loads, every line replays from it. A FEN that is the game's position with the
rook on a1 quietly missing loads and replays perfectly, so it grades CLEAN - and
five of those came back in one afternoon, plus two whose move number was off by
one, which the student reads as "4... Be7" where the game says "3... Be7".

Two questions, then, and neither is the grader's:

 * **Is this part's position one the game or its review actually reached?** Every
   position of the reviewed PGN is collected, variations included - a part that
   stands on a better-move line is teaching, not invention. When a part matches
   none, the nearest position is found and the squares that differ are named, so
   "dropped a rook" and "invented a board" read differently.
 * **Is each `ask_move` answer the best move of the analysis that was sent?**
   Not of a fresh search: of `input/<game>_facts.json`, the very file the prompt
   was built from.

**The second one used to run Stockfish again at depth 22, and that was wrong.**
The owner settled it on 13.9.2026: the analysis we send is the only source of
truth, it is our job to send it deep enough, and a model must take the
evaluation it was given and not change it. A grader that re-searches deeper is
marking the model against a fact the model was never told - so one French
question was "#2 by 0.04" against depth 22 and "#1 by 0.44" against depth 26,
three separate searches disagreeing about a position the model had answered
exactly as instructed. There is no flag for it any more, because a flag is an
invitation.

So what is measured here is obedience, not chess: the answer must be the sent
best move, and every extra move in `acceptedSans` must be one the sent numbers
put within `skeleton.DEFAULTS['near']` pawns of it. A model that widens the
accepted set has changed the evaluation, which is the one thing it must not do.

Exit code 0 when every part is exactly a position of the game and every question
matches the analysis sent, 1 otherwise.
"""

import argparse
import json
import os
import sys

import chess
import chess.pgn

import skeleton

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


def facts_drift(run_dir, game):
    """Whether the facts file on disk is the one this run was built from.

    A facts file can be rebuilt - at another depth, or simply again - between a
    run and its grading, and then every question would read as the model having
    changed the answer. That is the one accusation this harness must never make
    wrongly, so it says which analysis it is judging against instead.
    """
    path = os.path.join(run_dir, 'meta.json')
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as fh:
        used = ((json.load(fh).get('skeleton') or {}).get('facts'))
    if not used:
        return None
    facts = os.path.join(HERE, 'input', '%s_facts.json' % game)
    if not os.path.exists(facts):
        return None
    with open(facts, encoding='utf-8') as fh:
        now = skeleton.stamp_of(json.load(fh))
    return None if now == used else (used, now)


def facts_rows(game):
    """Every row of the analysis that was sent, keyed by board and side to move."""
    path = os.path.join(HERE, 'input', '%s_facts.json' % game)
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as fh:
        facts = json.load(fh)
    return {' '.join(row['fen'].split()[:2]): row for row in facts['rows']}


def question_verdict(row, answer, accepted):
    """(lines to print, ok) for one question, judged against the sent analysis."""
    cands = row.get('candidates') or []
    if not cands:
        return ['sent analysis: no candidates for this position'], False
    names = [c['move'] for c in cands]
    best = cands[0]
    near = int(round(skeleton.DEFAULTS['near'] * 100))
    allowed = [c['move'] for c in cands
               if best['value_for_mover'] - c['value_for_mover'] <= near]

    lines, ok = [], True
    if answer == best['move']:
        second = cands[1]['value_for_mover'] if len(cands) > 1 else None
        # Every number here is the side to move's, `margin` included. The
        # facts file also carries `eval` as White sees it, and printing the two
        # side by side read as one number contradicting the other.
        lines.append("sent analysis: %s is the best move, %s, %s "
                     "(%s, side to move's view)" % (
                         answer, shown(best['value_for_mover']),
                         margin(best['value_for_mover'], second),
                         'it stands out' if row.get('best_stands_out')
                         else 'it does not stand out'))
    else:
        ok = False
        where = ('#%d of %d' % (names.index(answer) + 1, len(names))
                 if answer in names else 'not among the %d sent' % len(names))
        lines.append('CHANGED THE ANALYSIS: answered %s (%s); the analysis sent '
                     'says %s' % (answer, where, best['move']))
    widened = [m for m in accepted if m not in allowed]
    if widened:
        ok = False
        lines.append('CHANGED THE ANALYSIS: %s accepted as correct, and the '
                     'analysis sent does not put %s within %.2f of the best'
                     % (', '.join(widened), 'them' if len(widened) > 1 else 'it',
                        skeleton.DEFAULTS['near']))
    return lines, ok


def shown(value):
    if value is None:
        return '?'
    if abs(value) > MATE / 2:
        distance = MATE - abs(value)
        return ('mates in %d' if value > 0 else 'is mated in %d') % distance
    return '%+.2f' % (value / 100.0)


def margin(mine, other):
    """How far the best move leads, in pawns; a mate has no margin in pawns."""
    if mine is None or other is None:
        return 'nothing else was sent'
    if abs(mine) > MATE / 2 or abs(other) > MATE / 2:
        return 'ahead of %s, a mate is involved' % shown(other)
    return '%+.2f ahead of the next (%s)' % ((mine - other) / 100.0, shown(other))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('run_dir')
    parser.add_argument('--game', help="defaults to the run's meta.json")
    cfg = parser.parse_args()

    run_dir = os.path.abspath(cfg.run_dir)
    game = cfg.game
    if not game:
        with open(os.path.join(run_dir, 'meta.json'), encoding='utf-8') as fh:
            game = json.load(fh)['game']
    known = positions_of(os.path.join(HERE, 'input', '%s_reviewed.pgn' % game))
    sent = facts_rows(game)
    drifted = facts_drift(run_dir, game)
    tutorial = os.path.join(run_dir, 'tutorial.json')
    if not os.path.exists(tutorial):
        # A run that answered nothing is a result to report, not a traceback.
        print('%s  — no tutorial.json, nothing to check' % os.path.basename(run_dir))
        sys.exit(2)
    with open(tutorial, encoding='utf-8') as fh:
        parts = json.load(fh).get('positionList') or []

    print('%s  (%s, %d positions in its review, %s)' % (
        os.path.basename(run_dir), game, len(known),
        '%d in the analysis sent' % len(sent) if sent
        else 'NO FACTS FILE: no question can be checked'))
    if drifted:
        print('  NOT THE ANALYSIS THIS RUN WAS GIVEN - it was built from'
              '\n    %s\n  and the file on disk now is\n    %s\n'
              '  so a question below that reads as changed may be this, '
              'and not the model.' % drifted)

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
                    # board a student sees is right and the move they must find
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

        if kind == 'ask_move' and not legal:
            answer = part.get('solutionSan')
            accepted = part.get('acceptedSans') or []
            row = sent.get(' '.join(fen.split()[:2])) if sent else None
            if not sent:
                pass
            elif row is None:
                all_exact = False
                print('           NOT IN THE ANALYSIS SENT: this position was '
                      'never analysed, so its answer cannot be judged')
            else:
                lines, ok = question_verdict(row, answer, accepted)
                all_exact = all_exact and ok
                for line in lines:
                    print('           %s' % line)
    sys.exit(0 if all_exact else 1)


if __name__ == '__main__':
    main()
