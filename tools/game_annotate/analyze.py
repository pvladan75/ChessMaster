"""Stockfish and a legality check, as one command a language model can call.

    python analyze.py fen  "<FEN>" [--depth 18] [--multipv 3]
    python analyze.py line --fen "<FEN>" --moves "Nxf3+ Bxf3 Bxf3" [--eval-each]
    python analyze.py budget

Everything is printed as one JSON object on stdout; anything the model should
not parse goes to stderr. Exit code 0 means the JSON is an answer, 2 that it is
a refusal with a reason, 3 that the call budget is spent.

**Why a wrapper and not raw UCI.** A model driving `position fen ... / go depth`
by hand spends its turns on protocol, and reports evaluations from the side to
move - which is the single easiest number in chess to quote backwards. Here
every score is from White's point of view and says so, and the principal
variation comes back as SAN the way a trainer writes it.

**It is stricter about SAN than python-chess is, on purpose.** python-chess
accepts `Bd6+` on a move that gives no check; `MoveTree.parsePgn` - the app's
one reader - refuses it, and `docs/PGN-TUTORIAL-FORMAT.md` rule 4 says so in as
many words. A tool that blessed a move the app will later drop would teach the
model exactly the fault this experiment exists to measure, so a wrong `+` or `#`
is reported as a fault here, with the move's real SAN beside it.

**The budget is a file, not a flag.** A model that can call an engine will call
it, and an experiment whose cost nobody wrote down cannot be priced. Every call
appends one line to `out/_budget/<session>.jsonl`, and the refusal past the cap
is legible enough for the model to stop rather than retry.
"""

import argparse
import json
import os
import re
import shutil
import sys
import time

try:
    import chess
    import chess.engine
except ImportError:  # pragma: no cover - the message is the whole handling
    sys.exit('python-chess is missing: pip install chess')


HERE = os.path.dirname(os.path.abspath(__file__))
BUDGET_DIR = os.path.join(HERE, 'out', '_budget')

# The app's own download, which is the engine a trainer's analysis runs on.
# Kept in this order so the experiment measures what the product would measure.
ENGINE_GUESSES = [
    os.path.expandvars(r'%APPDATA%\rs.pejovic\Mislisha\engine\stockfish.exe'),
    os.path.expandvars(r'%APPDATA%\com.example\chess_app\engine\stockfish.exe'),
]

DEPTH_MAX = 30
MULTIPV_MAX = 5


# --- The engine ---------------------------------------------------------------

def engine_path(given=None):
    """Where Stockfish is, or a loud failure.

    Deliberately no silent fallback to a weaker reading: a run that quietly
    analysed nothing looks exactly like a run that analysed everything, and this
    repository has already paid for that shape more than once.
    """
    for candidate in [given, os.environ.get('STOCKFISH_PATH')] + ENGINE_GUESSES:
        if candidate and os.path.exists(candidate):
            return candidate
    found = shutil.which('stockfish')
    if found:
        return found
    sys.exit('Stockfish not found. Set STOCKFISH_PATH or pass --engine.')


def analyse(board, *, depth, multipv, movetime, cfg):
    """[multipv] lines from [board], as dictionaries ready to print."""
    if board.is_game_over(claim_draw=False):
        return [], board.result(claim_draw=False)

    limit = (chess.engine.Limit(time=movetime / 1000.0) if movetime
             else chess.engine.Limit(depth=depth))
    with chess.engine.SimpleEngine.popen_uci(engine_path(cfg.engine)) as sf:
        # One thread by default: two runs of one experiment that disagree about
        # the evaluation are two experiments.
        sf.configure({'Threads': cfg.threads, 'Hash': cfg.hash})
        infos = sf.analyse(board, limit, multipv=multipv)

    if isinstance(infos, dict):
        infos = [infos]

    out = []
    for rank, info in enumerate(infos, start=1):
        pv = info.get('pv') or []
        score = info['score'].white()
        out.append({
            'rank': rank,
            'eval': score_text(score),
            'cp_white': score.score(),          # null when it is a mate score
            'mate_in': score.mate(),            # + White mates, - Black mates
            'depth': info.get('depth'),
            'line': board.variation_san(pv) if pv else '',
            'moves': san_list(board, pv),
        })
    return out, None


def score_text(score):
    """`+0.35`, `-1.20`, `#3`, `#-2` - always from White's point of view."""
    if score.mate() is not None:
        return '#%d' % score.mate()
    return '%+.2f' % (score.score() / 100.0)


def san_list(board, pv):
    work = board.copy(stack=False)
    out = []
    for move in pv:
        out.append(work.san(move))
        work.push(move)
    return out


# --- Reading a move the way the app reads it ----------------------------------

GLYPH = re.compile(r'[!?□]+$')
NUMBER = re.compile(r'^\d+\.(\.\.)?')


def read_san(board, token):
    """One SAN token against [board]: the move, or why it is not one.

    The two faults it names are the two the app's reader actually refuses - a
    move that cannot be played, and a `+` or `#` that is not true of the
    position. Glyphs are accepted with a warning rather than refused, because
    the text a model is asked to *read* is often a reviewed game full of `??`
    while the text it is asked to *write* may carry none.
    """
    warnings = []
    clean = NUMBER.sub('', token).strip()
    if GLYPH.search(clean):
        warnings.append('%s carries an assessment glyph; a tutorial line may '
                        'not (format rule 3)' % token)
        clean = GLYPH.sub('', clean)
    if not clean:
        return None, 'not a move: %r' % token, warnings

    try:
        move = board.parse_san(clean)
    except ValueError as exc:
        return None, '%s: %s' % (clean, exc), warnings

    # python-chess is happy with a check mark that is not true; the app is not.
    real = board.san(move)
    if real != clean:
        return move, ('%s is written wrong for this position: it is %s '
                      '(format rule 4)' % (clean, real)), warnings
    return move, None, warnings


def board_of(fen):
    if fen in (None, '', 'startpos'):
        return chess.Board()
    board = chess.Board(fen)
    if not board.is_valid():
        raise ValueError('the FEN is not a possible position (status %d); '
                         'build it by playing the moves out' % board.status())
    return board


# --- The budget ---------------------------------------------------------------

def budget_file(session):
    os.makedirs(BUDGET_DIR, exist_ok=True)
    return os.path.join(BUDGET_DIR, '%s.jsonl' % re.sub(r'\W+', '_', session))


def calls_used(session):
    """How many calls have *run the engine* in this session.

    Every call is written to the log, engine or not, because how the model used
    the tool is half of what the experiment measures. Only the ones that cost
    a search are charged: a legality check is arithmetic, and charging for it
    would push a model that is checking its own work back towards guessing.
    """
    path = budget_file(session)
    if not os.path.exists(path):
        return 0
    used = 0
    with open(path, encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue
            try:
                used += 1 if json.loads(line).get('engine', True) else 0
            except ValueError:
                used += 1
    return used


def log_call(session, entry):
    with open(budget_file(session), 'a', encoding='utf-8') as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + '\n')


# --- Printing -----------------------------------------------------------------

def answer(payload, session, cap):
    payload['calls_used'] = calls_used(session)
    payload['calls_left'] = max(0, cap - payload['calls_used'])
    print(json.dumps(payload, ensure_ascii=False, indent=1))


def refuse(message, code=2):
    print(json.dumps({'ok': False, 'error': message}, ensure_ascii=False, indent=1))
    sys.exit(code)


# --- The commands -------------------------------------------------------------

def cmd_fen(cfg):
    try:
        board = board_of(cfg.fen)
    except ValueError as exc:
        refuse(str(exc))

    started = time.time()
    lines, over = analyse(board, depth=cfg.depth, multipv=cfg.multipv,
                          movetime=cfg.movetime, cfg=cfg)
    elapsed = int((time.time() - started) * 1000)

    payload = {
        'ok': True,
        'fen': board.fen(),
        'side_to_move': 'white' if board.turn else 'black',
        'move_number': board.fullmove_number,
        'in_check': board.is_check(),
        'depth_asked': cfg.depth,
        'lines': lines,
    }
    if over:
        payload['game_over'] = over
    if not cfg.no_legal:
        payload['legal_moves'] = sorted(board.san(m) for m in board.legal_moves)

    log_call(cfg.session, {'at': time.strftime('%Y-%m-%dT%H:%M:%S'), 'cmd': 'fen',
                           'fen': board.fen(), 'depth': cfg.depth,
                           'multipv': cfg.multipv, 'ms': elapsed,
                           'engine': True})
    answer(payload, cfg.session, cfg.max_calls)


def cmd_line(cfg):
    try:
        board = board_of(cfg.fen)
    except ValueError as exc:
        refuse(str(exc))

    start_fen = board.fen()
    played, faults, warnings = [], [], []
    for token in cfg.moves.split():
        if NUMBER.match(token) and not NUMBER.sub('', token).strip():
            continue                      # a bare move number, `9.` or `9...`
        move, fault, warns = read_san(board, token)
        warnings.extend(warns)
        if fault:
            faults.append(fault)
        if move is None:
            played.append({'token': token, 'ok': False, 'why': fault})
            break                         # the rest is from a different game
        played.append({'token': token, 'ok': fault is None,
                       'san': board.san(move),
                       **({'why': fault} if fault else {})})
        board.push(move)
        if cfg.eval_each:
            lines, _ = analyse(board, depth=cfg.depth, multipv=1,
                               movetime=cfg.movetime, cfg=cfg)
            played[-1]['eval'] = lines[0]['eval'] if lines else None
            played[-1]['fen_after'] = board.fen()

    lines, over = ([], None)
    if not cfg.no_eval:
        lines, over = analyse(board, depth=cfg.depth, multipv=cfg.multipv,
                              movetime=cfg.movetime, cfg=cfg)

    payload = {
        'ok': not faults,
        'start_fen': start_fen,
        'moves': played,
        'final_fen': board.fen(),
        'side_to_move': 'white' if board.turn else 'black',
        'lines': lines,
    }
    if faults:
        payload['faults'] = faults
    if warnings:
        payload['warnings'] = sorted(set(warnings))
    if over:
        payload['game_over'] = over

    log_call(cfg.session, {'at': time.strftime('%Y-%m-%dT%H:%M:%S'), 'cmd': 'line',
                           'fen': start_fen, 'moves': cfg.moves,
                           'depth': cfg.depth, 'faults': len(faults),
                           'engine': bool(lines) or cfg.eval_each})
    answer(payload, cfg.session, cfg.max_calls)


def cmd_budget(cfg):
    answer({'ok': True, 'session': cfg.session}, cfg.session, cfg.max_calls)


# --- Entry --------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])

    # On the subcommands rather than in front of them: `analyze.py fen FEN
    # --depth 20` is the order anyone writes by hand, and argparse refuses it
    # when the option lives on the top-level parser. A tool whose correct usage
    # has to be remembered is a tool that spends the model's turns on argparse.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--engine')
    common.add_argument('--session', default=os.environ.get('ANALYZE_SESSION', 'default'))
    common.add_argument('--max-calls', type=int,
                        default=int(os.environ.get('ANALYZE_MAX_CALLS', '40')))
    common.add_argument('--depth', type=int, default=18)
    common.add_argument('--multipv', type=int, default=3)
    common.add_argument('--movetime', type=int, default=0, help='ms; overrides --depth')
    common.add_argument('--threads', type=int, default=1)
    common.add_argument('--hash', type=int, default=128)

    subs = parser.add_subparsers(dest='cmd', required=True)

    one = subs.add_parser('fen', parents=[common], help='analyse one position')
    one.add_argument('fen')
    one.add_argument('--no-legal', action='store_true',
                     help='leave the list of legal moves out of the answer')
    one.set_defaults(run=cmd_fen, no_eval=False, eval_each=False, moves='')

    walk = subs.add_parser('line', parents=[common], help='replay moves from a position and analyse the end')
    walk.add_argument('--fen', default='startpos')
    walk.add_argument('--moves', required=True, help='SAN moves, space separated')
    walk.add_argument('--eval-each', action='store_true')
    walk.add_argument('--no-eval', action='store_true')
    walk.set_defaults(run=cmd_line, no_legal=True)

    left = subs.add_parser('budget', parents=[common], help='how many calls are left')
    left.set_defaults(run=cmd_budget, no_legal=True, no_eval=True,
                      eval_each=False, fen='startpos', moves='')

    cfg = parser.parse_args(argv)
    cfg.depth = max(1, min(cfg.depth, DEPTH_MAX))
    cfg.multipv = max(1, min(cfg.multipv, MULTIPV_MAX))

    if cfg.cmd != 'budget' and calls_used(cfg.session) >= cfg.max_calls:
        refuse('the engine call budget for this session is spent (%d calls). '
               'Write the tutorial with what you already know, or ask the '
               'person running the experiment to raise --max-calls.'
               % cfg.max_calls, code=3)

    cfg.run(cfg)


if __name__ == '__main__':
    main()
