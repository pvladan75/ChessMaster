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
import queue
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import chess
import chess.engine
import chess.pgn

import analyze
import probe_masters

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


def set_cost(played, best):
    """What the move played cost against the best move, written onto [played].

    `cost_pawns` is a number of pawns, or the string `mate` when the loss is not
    in pawns at all - and then `cost_mate` says which way.

    Two rules, and both are about one thing: the move played is scored from the
    next position's own search, so its number and the best move's come from two
    different searches and disagree by a hair.

    **A move that is the best move cost nothing**, whatever the two searches
    say. Without this, `11. Qxe2` - rank 1 of 4 - carried a cost of 0.2 pawns,
    and three of the Philidor's eight candidate moments on 13.9.2026 were moves
    where the best move was the move played, one of them the mate that ended the
    game (`43... Qg5# was played and cost mate pawns; the best move was Qg5#`).
    A mate sorts above every real blunder in `skeleton.py`, so noise between two
    searches crowded out three genuine mistakes of 3.4 to 4.4 pawns.

    **A mate that is still a mate cost nothing either.** Mate in 3 where the
    best move mates in 2 is not an infinite loss, and being mated a move later
    is not a loss at all. `mate` is for a mate that appears or disappears - a
    forced mate given up, or one allowed.

    It reads `value_for_mover` and nothing else, so it can be applied to a facts
    file that is already written: `--recost` is that, and it re-analyses
    nothing.
    """
    value, best_value = played['value_for_mover'], best['value_for_mover']
    played.pop('cost_mate', None)
    if played['move'] == best['move'] or best_value <= value:
        played['cost_pawns'] = 0
        return
    side = lambda v: (v > MATE / 2) - (v < -MATE / 2)
    if side(best_value) == side(value):
        played['cost_pawns'] = pawns(best_value - value) if side(value) == 0 else 0
        return
    played['cost_pawns'] = 'mate'
    gave_up, walked_in = best_value > MATE / 2, value < -MATE / 2
    played['cost_mate'] = (
        'gave up a forced mate and allowed one' if gave_up and walked_in
        else 'gave up a forced mate' if gave_up
        else 'allowed a forced mate' if walked_in
        else 'cost a forced mate')


def walk(name):
    """The game as rows, with everything in them that needs no engine."""
    with open(os.path.join(INPUT_DIR, '%s_reviewed.pgn' % name), encoding='utf-8') as fh:
        reviewed = chess.pgn.read_game(fh)
    with open(os.path.join(INPUT_DIR, '%s_plain.pgn' % name), encoding='utf-8') as fh:
        plain = chess.pgn.read_game(fh)

    moves = list(plain.mainline_moves())
    comments = [node.comment.strip() for node in reviewed.mainline()]
    if [n.move for n in reviewed.mainline()] != moves:
        sys.exit('the reviewed and the plain game are not the same game')

    board = plain.board()
    rows, label = [], 'start'
    for index in range(len(moves) + 1):
        row = {'label': label, 'fen': board.fen(),
               'to_move': 'White' if board.turn else 'Black'}
        if board.is_game_over(claim_draw=False):
            row['game_over'] = board.result(claim_draw=False)
            row['candidates'] = []
        if index < len(moves):
            move = moves[index]
            row['played'] = {'move': board.san(move),
                             'label': label_of(board, move)}
            if comments[index]:
                row['motifs_after_played'] = comments[index]
            label = row['played']['label']
            board.push(move)
        rows.append(row)
    return rows


def candidates_of(board, infos):
    """One position's answer, as the facts file keeps it."""
    if isinstance(infos, dict):
        infos = [infos]
    out = []
    for info in infos:
        pv = info.get('pv') or []
        if not pv:
            continue
        white = info['score'].white()
        out.append({
            'move': board.san(pv[0]),
            'eval': analyze.score_text(white),
            'value_for_mover': mover_value(white, board.turn),
            'line': ' '.join(analyze.san_list(board, pv[:6])),
        })
    return out


def analyse_all(fens, depth, multipv, threads, hash_mb, workers):
    """Every position, one single-threaded engine at a time, in `workers` of them.

    **The cores go into positions, not into the search.** Measured on
    13.9.2026, eight positions at depth 20 with multipv 4: one thread 33.8 s,
    four 74.9 s, eight 98.9 s. Lazy SMP buys time-to-depth sublinearly, least of
    all with multipv above one, and this harness searches to a fixed depth on
    purpose - threads help at a fixed time. The same cores spent on whole
    positions are 2.2x, and every number comes out the same. So `threads` stays
    at one and `workers` is what to raise.

    **Every position is searched from an empty table**, which `game=object()`
    is: a new game object makes python-chess send `ucinewgame`. The sequential
    version carried one table across the whole game, so what came back depended
    on the order positions were searched in - fine while there was one order,
    and not a property to keep once there are several. What a facts file holds
    is now a function of the position, the depth and the engine, and of nothing
    else.
    """
    results = [None] * len(fens)
    free, engines = queue.Queue(), []
    done = [0]
    started = time.time()

    def one(job):
        index, fen = job
        sf = free.get()
        try:
            board = chess.Board(fen)
            infos = sf.analyse(board, chess.engine.Limit(depth=depth),
                               multipv=multipv, game=object())
        finally:
            free.put(sf)
        results[index] = candidates_of(board, infos)
        done[0] += 1
        print('  %3d/%d  %.0f s' % (done[0], len(fens), time.time() - started),
              flush=True)

    try:
        for _ in range(workers):
            sf = chess.engine.SimpleEngine.popen_uci(analyze.engine_path())
            sf.configure({'Threads': threads, 'Hash': hash_mb})
            engines.append(sf)
            free.put(sf)
        with ThreadPoolExecutor(max_workers=workers) as pool:
            list(pool.map(one, list(enumerate(fens))))
    finally:
        for sf in engines:
            try:
                sf.quit()
            except Exception:
                pass
    return results


def add_book(name, rows, gap_s, enabled=True):
    """What the masters database says about this game, onto the rows.

    Three things go in, and the third is a removal:

     * `row['book']` on every position master games reached - how many, the
       opening's name, what share of them played the move the trainer played,
       and the three most popular alternatives. **The statistics are written
       into the facts file**, so the network is a build-time dependency and
       never a read-time one.
     * `played['left_book']` on the first move no master game has played. That
       move, and not the position after it, is the one worth a sentence: a
       position can transpose back into the database by another move order, and
       twice in three probed games it did.
     * **and the motif detector goes quiet while the game is still theory**
       (owner, 13.9.2026). Measured before it was believed: nineteen of the
       thirty-two in-book positions of the first three games carried a motif
       comment, and on move two of a Philidor it read "The black pawn on e5 is
       attacked by the white knight on f3 and has no defender", then narrated
       that threat's resolution a move later. In the book what is worth saying
       is what is played here, and how often.

    The engine still runs on every position. Skipping the book was the other
    half of the owner's proposal and the measurement sent it back: it saves
    about twelve seconds of an eighty-second run, and a move can be in the
    database and still lose - the Fried Liver and Legal's mate are in every
    masters database there is.
    """
    if not enabled:
        return 0
    known = probe_masters.book_walk(name, [row['fen'] for row in rows],
                                    gap_s=gap_s)
    if not known:
        return 0
    left = False
    for row in rows:
        data = known.get(row['fen'])
        if data is None:
            break
        here = probe_masters.total_of(data)
        played = row.get('played')
        entry = {'games': here}
        if data.get('opening'):
            entry['opening'] = data['opening'].get('name')
        moves = [{'move': m['san'], 'games': probe_masters.total_of(m),
                  'share': round(probe_masters.total_of(m) / float(here), 4)}
                 for m in data.get('moves') or []]
        if played:
            mine = next((m for m in moves if m['move'] == played['move']), None)
            entry['played'] = mine or {'move': played['move'], 'games': 0,
                                       'share': 0.0}
            if not mine and not left:
                played['left_book'] = True
                left = True
            if mine:
                # Theory, so the detector has nothing to add that the
                # statistics do not say better.
                row.pop('motifs_after_played', None)
        entry['alternatives'] = [m for m in moves
                                 if not played or m['move'] != played['move']][:3]
        row['book'] = entry
    return sum(1 for row in rows if 'book' in row)


def build(name, depth, multipv, margin_pawns, threads, hash_mb, workers,
          book=True, book_gap_s=None):
    started = time.time()
    rows = walk(name)
    in_book = add_book(name, rows, book_gap_s or probe_masters.GAP_S, book)
    todo = [i for i, row in enumerate(rows) if 'candidates' not in row]
    answers = analyse_all([rows[i]['fen'] for i in todo],
                          depth, multipv, threads, hash_mb, workers)
    for i, cands in zip(todo, answers):
        rows[i]['candidates'] = cands

    finish(rows, margin_pawns)

    return {
        'game': name,
        'depth': depth,
        'multipv': multipv,
        'margin_pawns': margin_pawns,
        'engine': os.path.basename(analyze.engine_path()),
        'threads': threads,
        'hash_mb': hash_mb,
        'workers': workers,
        'in_book': in_book,
        'generated': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'seconds': round(time.time() - started),
        'rows': rows,
    }


# The fields `finish` writes. Everything else in a row is the walk's, the
# book's or the engine's.
FINISHED_ROW = ('best_stands_out', 'why', 'margin_pawns')
FINISHED_PLAYED = ('eval', 'value_for_mover', 'rank', 'cost_pawns', 'cost_mate')


def finish(rows, margin_pawns):
    """The arithmetic of `build`, over rows whose candidates are already in.

    Split out on 14.9.2026 so the app's port can be held to it on cases no game
    reaches - a mate among the candidates, a margin of exactly half a pawn -
    through `export_fixtures.py`, which also proves this function gives back the
    ten facts files it was lifted from.
    """
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
            ranks = [c['move'] for c in cands]
            played['rank'] = (ranks.index(played['move']) + 1
                              if played['move'] in ranks else None)
            set_cost(played, cands[0])
    return rows


def recost(name):
    """Re-derive what every move cost, over the facts file already written.

    The owner's rule is that a game once analysed is reused and never analysed
    again for a threshold or a rule that is only read off the numbers. What a
    move cost is such a rule: `value_for_mover` for the best move and for the
    move played are both already in the file, so `set_cost` can run over them
    with no engine at all. Nothing else in the file is touched.
    """
    path = os.path.join(INPUT_DIR, '%s_facts.json' % name)
    with open(path, encoding='utf-8') as fh:
        facts = json.load(fh)
    before = [(r.get('played') or {}).get('cost_pawns') for r in facts['rows']]
    for row in facts['rows']:
        played, cands = row.get('played'), row.get('candidates')
        if played and cands and 'value_for_mover' in played:
            set_cost(played, cands[0])
    after = [(r.get('played') or {}).get('cost_pawns') for r in facts['rows']]
    facts['recosted'] = time.strftime('%Y-%m-%dT%H:%M:%S')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(facts, fh, ensure_ascii=False, indent=1)
    changed = [(facts['rows'][i]['played']['label'], b, a)
               for i, (b, a) in enumerate(zip(before, after)) if b != a]
    print('%s: %d of %d costs changed%s' % (
        name, len(changed), len(before),
        (' - ' + ', '.join('%s %s->%s' % c for c in changed[:12])) if changed else ''))
    return len(changed)


def rebook(name, gap_s=None):
    """Put the masters statistics onto a facts file already written.

    The same rule as `--recost`: a game once analysed is reused, and what is
    only read off the numbers is re-derived without an engine. The motif
    comments are read back out of the reviewed PGN rather than out of the file,
    so the silence rule is applied from scratch every time and running this
    twice says the same thing as running it once.
    """
    path = os.path.join(INPUT_DIR, '%s_facts.json' % name)
    with io.open(path, encoding='utf-8') as fh:
        facts = json.load(fh)
    fresh = {row['label']: row.get('motifs_after_played') for row in walk(name)}
    for row in facts['rows']:
        row.pop('book', None)
        if row.get('played'):
            row['played'].pop('left_book', None)
        comment = fresh.get(row['label'])
        if comment:
            row['motifs_after_played'] = comment
        else:
            row.pop('motifs_after_played', None)
    facts['in_book'] = add_book(name, facts['rows'],
                                gap_s or probe_masters.GAP_S)
    facts['rebooked'] = time.strftime('%Y-%m-%dT%H:%M:%S')
    with io.open(path, 'w', encoding='utf-8') as fh:
        json.dump(facts, fh, ensure_ascii=False, indent=1)
    quiet = sum(1 for r in facts['rows']
                if r.get('book') and not r.get('motifs_after_played'))
    print('%s: %d positions in the masters book, the detector silent on %d of '
          'them' % (name, facts['in_book'], quiet))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('name')
    parser.add_argument('--depth', type=int, default=18)
    parser.add_argument('--multipv', type=int, default=4)
    parser.add_argument('--margin', type=float, default=0.5,
                        help='pawns the best move must lead the second by')
    parser.add_argument('--threads', type=int, default=1,
                        help='threads PER ENGINE; leave it at one and raise '
                             '--workers instead, which is measured and this is '
                             'not')
    parser.add_argument('--workers', type=int,
                        default=min(8, os.cpu_count() or 1),
                        help='positions analysed at the same time, each by its '
                             'own single-threaded engine')
    parser.add_argument('--hash', type=int, default=128)
    parser.add_argument('--no-book', action='store_true',
                        help='do not ask the masters database; the facts then '
                             'carry no statistics and the detector is not '
                             'silenced in the opening')
    parser.add_argument('--rebook', action='store_true',
                        help='put the masters statistics onto the existing '
                             'facts file, with no engine and no re-analysis')
    parser.add_argument('--recost', action='store_true',
                        help='re-derive the costs over the existing facts file, '
                             'with no engine and no re-analysis')
    cfg = parser.parse_args()

    if cfg.rebook:
        rebook(cfg.name)
        return
    if cfg.recost:
        recost(cfg.name)
        return

    facts = build(cfg.name, cfg.depth, cfg.multipv, cfg.margin, cfg.threads,
                  cfg.hash, cfg.workers, book=not cfg.no_book)
    path = os.path.join(INPUT_DIR, '%s_facts.json' % cfg.name)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(facts, fh, ensure_ascii=False, indent=1)
    out = sum(1 for r in facts['rows'] if r.get('best_stands_out'))
    print('%s: %d positions, %d where the best move stands out, %d in the '
          'masters book, %d s -> %s'
          % (cfg.name, len(facts['rows']), out, facts['in_book'],
             facts['seconds'], os.path.relpath(path, HERE)))


if __name__ == '__main__':
    main()
