"""The facts a model is given in arm G, computed once per game.

    python make_facts.py pvladan_2026-09-12
    python make_facts.py french_2026-06-19 --depth 20 --margin 0.5

Written on 13.9.2026, when the owner drew the line this arm is built on: „LLM
ne sme da procenjuje poteze" — a model must not assess moves. Every error left
after arm F had given it the positions came from a model assessing: a single
„better move" from a depth-14 review trusted as the best when it was fourth, a
trade described as winning a piece, a pawn push said to attack a bishop that
nothing attacked. So the assessing moves here, and the model is left with what
it is for: choosing the moments and saying them to a student.

For every position of the game's main line it writes:

 * the label (`start`, or the move that led to it, `14... Qc7`) and the FEN;
 * the four best moves at the given depth, each with its evaluation from
   White's side and a short line;
 * the move played, its evaluation, its rank among the four when it is one of
   them, and what it cost the side that played it against the best move;
 * whether the best move **stands out**: at least [margin] pawns ahead of the
   second from the mover's side, or a mate the second move does not have. This
   is the one question a model is never trusted to answer, because it decides
   whether a student can be marked wrong;
 * the review's comment on the move played — the app's own motif detector —
   which describes the board rather than judging it.

**One engine process for the whole game, one thread, a fixed hash.** The same
settings `analyze.py` and `check_positions.py` use, so the facts a model reads
and the grading of what it wrote cannot disagree about the engine. The move
played is evaluated from the search of the position after it, which is the next
row's own search, so no position is searched twice.

The result is `input/<game>_facts.json`, and its settings travel inside it.
"""

import argparse
import io
import json
import os
import sys
import time

import chess
import chess.engine
import chess.pgn

import analyze

HERE = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR = os.path.join(HERE, 'input')
MATE = 100000


def label_of(board, move):
    return (('%d. ' if board.turn else '%d... ') % board.fullmove_number
            + board.san(move))


def mover_value(score_white, white_to_move):
    """A White-relative `PovScore.white()` as one number from the mover's side."""
    if score_white.mate() is not None:
        m = score_white.mate()
        value = (MATE - abs(m)) * (1 if m > 0 else -1)
    else:
        value = score_white.score()
    return value if white_to_move else -value


def pawns(value):
    if value is None:
        return None
    if abs(value) > MATE / 2:
        return 'mate'
    return round(value / 100.0, 2)


def build(name, depth, multipv, margin_pawns, threads, hash_mb):
    with open(os.path.join(INPUT_DIR, '%s_reviewed.pgn' % name), encoding='utf-8') as fh:
        reviewed = chess.pgn.read_game(fh)
    with open(os.path.join(INPUT_DIR, '%s_plain.pgn' % name), encoding='utf-8') as fh:
        plain = chess.pgn.read_game(fh)

    moves = list(plain.mainline_moves())
    comments = [node.comment.strip() for node in reviewed.mainline()]
    if [n.move for n in reviewed.mainline()] != moves:
        sys.exit('the reviewed and the plain game are not the same game')

    board = plain.board()
    rows = []
    label = 'start'
    started = time.time()
    with chess.engine.SimpleEngine.popen_uci(analyze.engine_path()) as sf:
        sf.configure({'Threads': threads, 'Hash': hash_mb})
        for index in range(len(moves) + 1):
            row = {'label': label, 'fen': board.fen(),
                   'to_move': 'White' if board.turn else 'Black'}
            if board.is_game_over(claim_draw=False):
                row['game_over'] = board.result(claim_draw=False)
                row['candidates'] = []
            else:
                infos = sf.analyse(board, chess.engine.Limit(depth=depth),
                                   multipv=multipv)
                if isinstance(infos, dict):
                    infos = [infos]
                row['candidates'] = []
                for info in infos:
                    pv = info.get('pv') or []
                    if not pv:
                        continue
                    white = info['score'].white()
                    row['candidates'].append({
                        'move': board.san(pv[0]),
                        'eval': analyze.score_text(white),
                        'value_for_mover': mover_value(white, board.turn),
                        'line': ' '.join(analyze.san_list(board, pv[:6])),
                    })
            if index < len(moves):
                move = moves[index]
                row['played'] = {'move': board.san(move),
                                 'label': label_of(board, move)}
                if comments[index]:
                    row['motifs_after_played'] = comments[index]
                label = row['played']['label']
                board.push(move)
            rows.append(row)
            print('  %3d/%d  %-14s %.0f s' % (index, len(moves), row['label'],
                                              time.time() - started), flush=True)

    margin = int(round(margin_pawns * 100))
    for index, row in enumerate(rows):
        cands = row['candidates']
        if cands:
            best = cands[0]['value_for_mover']
            if len(cands) == 1:
                row['best_stands_out'] = False
                row['why'] = 'only one legal move'
            else:
                second = cands[1]['value_for_mover']
                best_mate, second_mate = abs(best) > MATE / 2, abs(second) > MATE / 2
                if best_mate and best > 0 and not (second_mate and second > 0):
                    row['best_stands_out'] = True
                    row['margin_pawns'] = 'mate'
                elif best_mate or second_mate:
                    row['best_stands_out'] = False
                    row['margin_pawns'] = 'mate'
                else:
                    row['margin_pawns'] = pawns(best - second)
                    row['best_stands_out'] = (best - second) >= margin

        played = row.get('played')
        if played and cands:
            after = rows[index + 1]
            if after.get('candidates'):
                # The next position's best line, from the side that has just
                # moved: the evaluation of the move actually played.
                value = -after['candidates'][0]['value_for_mover']
                played['eval'] = after['candidates'][0]['eval']
            elif after.get('game_over') in ('1-0', '0-1'):
                value = MATE
                played['eval'] = 'checkmate'
            else:
                value = 0
                played['eval'] = 'draw'
            played['value_for_mover'] = value
            # Never below zero. The move played is scored from the next
            # position's own search, which can come back a hair above the best
            # move's score from this one; „cost -0.46" is noise between two
            # searches, and a model reading it would take it for a meaning.
            played['cost_pawns'] = pawns(max(0, cands[0]['value_for_mover'] - value)) \
                if abs(value) < MATE / 2 and abs(cands[0]['value_for_mover']) < MATE / 2 \
                else ('mate' if cands[0]['value_for_mover'] > value else 0)
            ranks = [c['move'] for c in cands]
            played['rank'] = ranks.index(played['move']) + 1 if played['move'] in ranks else None

    return {
        'game': name,
        'depth': depth,
        'multipv': multipv,
        'margin_pawns': margin_pawns,
        'engine': os.path.basename(analyze.engine_path()),
        'threads': threads,
        'hash_mb': hash_mb,
        'generated': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'seconds': round(time.time() - started),
        'rows': rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('name')
    parser.add_argument('--depth', type=int, default=20)
    parser.add_argument('--multipv', type=int, default=4)
    parser.add_argument('--margin', type=float, default=0.5,
                        help='pawns the best move must lead the second by')
    parser.add_argument('--threads', type=int, default=1)
    parser.add_argument('--hash', type=int, default=128)
    cfg = parser.parse_args()

    facts = build(cfg.name, cfg.depth, cfg.multipv, cfg.margin, cfg.threads, cfg.hash)
    path = os.path.join(INPUT_DIR, '%s_facts.json' % cfg.name)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(facts, fh, ensure_ascii=False, indent=1)
    out = sum(1 for r in facts['rows'] if r.get('best_stands_out'))
    print('%s: %d positions, %d where the best move stands out, %d s -> %s'
          % (cfg.name, len(facts['rows']), out, facts['seconds'],
             os.path.relpath(path, HERE)))


if __name__ == '__main__':
    main()
