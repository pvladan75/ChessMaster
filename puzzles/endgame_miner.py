"""Mine teachable endgame positions out of PGN databases.

The predecessor of this script (zavrsnice.py) accepted any position that matched
a material pattern and gave the side to move at least +2.00. That is not the
same thing as an exercise. It let through two kinds of junk:

  * positions whose best move simply wins a hanging piece, after which the
    position is no longer the endgame type it was filed under, and
  * positions where the side to move is winning and a dozen moves keep the win,
    so there is nothing to find.

Measured on the existing RookPawnVsRook.json output, the median gap between the
best and the second-best move was 11 centipawns, and a 6-ply search already
found the "solution" in 68% of them.

So this script filters on the properties that make a position worth setting as
homework, and reports why everything else was rejected.
"""

import argparse
import json
import os
import random
import sys
import hashlib
import threading
import time
import traceback
import zlib
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

import chess
import chess.engine
import chess.pgn
import chess.syzygy

# Defaults; override with --base-dir / --stockfish or the environment.
DEFAULT_BASE_DIR = os.environ.get("CHESS_BASE_DIR", r"D:\chess_base")
DEFAULT_STOCKFISH = os.environ.get(
    "STOCKFISH_PATH",
    r"D:\stockfish\stockfish-windows-x86-64-avx2\stockfish\stockfish-windows-x86-64-avx2.exe",
)

PIECE_VALUE = {
    chess.PAWN: 1,
    chess.KNIGHT: 3,
    chess.BISHOP: 3,
    chess.ROOK: 5,
    chess.QUEEN: 9,
    chess.KING: 99,
}

ENDGAME_TYPES = {
    "1": ("PawnEnding", "Ciste pesacke zavrsnice (K+P vs K+P)"),
    "2": ("RookPawnVsRook", "Top i pesak protiv Topa (T+P vs T)"),
    "3": ("BishopVsKnight", "Lovac protiv Skakaca (L vs S + pesaci)"),
    "4": ("QueenVsRook", "Kraljica protiv Topa (D vs T)"),
    "5": ("RookBishopVsRook", "Top i Lovac protiv Topa (T+L vs T)"),
    "6": ("DoubleBishopVsBishopKnight", "Par Lovaca protiv Lovca i Skakaca (LL vs LS)"),
    "7": ("OppositeBishops", "Raznobojni lovci (L vs L suprotnih boja + pesaci)"),
}


# --------------------------------------------------------------------------
# Position classification
# --------------------------------------------------------------------------

def piece_counts(board):
    return {
        color: {pt: len(board.pieces(pt, color)) for pt in chess.PIECE_TYPES}
        for color in (chess.WHITE, chess.BLACK)
    }


def is_light_square(square):
    # zavrsnice.py called chess.square_light_dark(), which does not exist in
    # python-chess. The OppositeBishops option therefore raised AttributeError
    # inside a bare `except Exception`, printed one line and produced an empty
    # result file that looked like "no positions found".
    return bool(chess.BB_LIGHT_SQUARES & chess.BB_SQUARES[square])


def is_target_endgame(board, target_type):
    c = piece_counts(board)
    w_all = sum(c[chess.WHITE][pt]
                for pt in (chess.BISHOP, chess.KNIGHT, chess.ROOK, chess.QUEEN))
    b_all = sum(c[chess.BLACK][pt]
                for pt in (chess.BISHOP, chess.KNIGHT, chess.ROOK, chess.QUEEN))
    W, B = c[chess.WHITE], c[chess.BLACK]

    if target_type == "PawnEnding":
        return w_all + b_all == 0 and W[chess.PAWN] + B[chess.PAWN] > 0

    if target_type == "RookPawnVsRook":
        a = (W[chess.ROOK] == 1 and W[chess.PAWN] == 1 and w_all == 1
             and B[chess.ROOK] == 1 and B[chess.PAWN] == 0 and b_all == 1)
        b = (B[chess.ROOK] == 1 and B[chess.PAWN] == 1 and b_all == 1
             and W[chess.ROOK] == 1 and W[chess.PAWN] == 0 and w_all == 1)
        return a or b

    if target_type == "BishopVsKnight":
        return ((W[chess.BISHOP] == 1 and w_all == 1
                 and B[chess.KNIGHT] == 1 and b_all == 1)
                or (W[chess.KNIGHT] == 1 and w_all == 1
                    and B[chess.BISHOP] == 1 and b_all == 1))

    if target_type == "QueenVsRook":
        return ((W[chess.QUEEN] == 1 and w_all == 1
                 and B[chess.ROOK] == 1 and b_all == 1)
                or (B[chess.QUEEN] == 1 and b_all == 1
                    and W[chess.ROOK] == 1 and w_all == 1))

    if target_type == "RookBishopVsRook":
        return ((W[chess.ROOK] == 1 and W[chess.BISHOP] == 1 and w_all == 2
                 and B[chess.ROOK] == 1 and b_all == 1)
                or (B[chess.ROOK] == 1 and B[chess.BISHOP] == 1 and b_all == 2
                    and W[chess.ROOK] == 1 and w_all == 1))

    if target_type == "DoubleBishopVsBishopKnight":
        return ((W[chess.BISHOP] == 2 and w_all == 2
                 and B[chess.BISHOP] == 1 and B[chess.KNIGHT] == 1 and b_all == 2)
                or (B[chess.BISHOP] == 2 and b_all == 2
                    and W[chess.BISHOP] == 1 and W[chess.KNIGHT] == 1 and w_all == 2))

    if target_type == "OppositeBishops":
        if W[chess.BISHOP] == 1 and B[chess.BISHOP] == 1 and w_all == 1 and b_all == 1:
            w_sq = next(iter(board.pieces(chess.BISHOP, chess.WHITE)))
            b_sq = next(iter(board.pieces(chess.BISHOP, chess.BLACK)))
            return is_light_square(w_sq) != is_light_square(b_sq)
        return False

    raise ValueError("Nepoznat tip zavrsnice: " + target_type)


# --------------------------------------------------------------------------
# Filters
# --------------------------------------------------------------------------

def wins_material_outright(board):
    """True if the side to move can just take a piece.

    This is the Rxb8 case: a rook standing undefended on an open file. It costs
    nothing to detect and it removes the largest single class of false
    exercises before the engine is ever started.
    """
    for move in board.legal_moves:
        if not board.is_capture(move) or board.is_en_passant(move):
            continue
        victim = board.piece_at(move.to_square)
        if victim is None or victim.piece_type == chess.PAWN:
            continue
        if not board.attackers(not board.turn, move.to_square):
            return True
        attacker = board.piece_at(move.from_square)
        if PIECE_VALUE[attacker.piece_type] < PIECE_VALUE[victim.piece_type]:
            return True
    return False


def forced_mate_within(board, moves_deep):
    """Can the side to move force mate in `moves_deep` moves or fewer?

    A mate is not endgame technique, and the project keeps mate puzzles in their
    own database. Measured on 1079 mined positions, rejecting mate in one costs
    0.2% of the harvest and mate in two costs nothing further - there was not a
    single one, because a position with a forced mate usually has more winning
    moves than --max-solutions allows, or the shallow search sees it.

    Cheap enough to run on every candidate: 0.1 ms at depth one, 0.9 ms at two.
    """
    def mates(b, plies):
        if plies <= 0:
            return False
        # list(), not the generator: legal_moves reads the board lazily, and the
        # loop pushes and pops inside it.
        for move in list(b.legal_moves):
            b.push(move)
            try:
                if b.is_checkmate():
                    return True
                if plies > 1 and not b.is_stalemate():
                    replies = list(b.legal_moves)
                    if all(_defence_fails(b, r, plies) for r in replies):
                        return True
            finally:
                b.pop()
        return False

    def _defence_fails(b, reply, plies):
        b.push(reply)
        try:
            return mates(b, plies - 2)
        finally:
            b.pop()

    return mates(board, moves_deep * 2 - 1)


def pawn_count(board):
    return len(board.pieces(chess.PAWN, chess.WHITE)) + \
        len(board.pieces(chess.PAWN, chess.BLACK))


def type_survives(board, pv, target_type, plies):
    """Does the position still belong to its endgame type after the main line?

    A promotion or a mate ends the exercise legitimately, so a break at or after
    one of those is not held against the position — otherwise every Lucena
    finish, whose whole point is to queen, would be thrown away.
    """
    test = board.copy()
    for move in pv[:plies]:
        promoting = move.promotion is not None
        test.push(move)
        if promoting or test.is_checkmate():
            return True
        if not is_target_endgame(test, target_type):
            return False
    return True


def score_for_side_to_move(score_obj, white_to_move):
    value = score_obj.white().score(mate_score=10000)
    if value is None:
        return 0
    return value if white_to_move else -value


def count_above(values, threshold):
    """How many of the leading moves reach `threshold`. Values are descending.

    Moves are grouped by result — wins, holds, everything else — rather than by
    distance in centipawns from the best one. Two reasons, both from
    8/4k3/8/1p2Pp2/p7/P1K1P3/1P6/8 w - - 1 42:

    Kd3 and e4 both win there and the other seven legal moves draw or lose. That
    is a good position to set, and comparing the best move against the second
    best throws it away, because those two are three centipawns apart.

    And by depth 26 Kd3 is a forced mate while e4 is "only" +83. In centipawns
    they are thousands apart; as results they are the same move twice. A
    tolerance in centipawns splits them, a threshold does not.
    """
    k = 0
    while k < len(values) and values[k] >= threshold:
        k += 1
    return k


def rate_difficulty(board, pv, solutions, shallow_solutions, shallow_best):
    """1..10, from how badly a shallow search misjudges the position."""
    difficulty = 5
    if shallow_solutions != solutions:
        difficulty += 2
    if shallow_best not in solutions:
        difficulty += 1
    # Several moves that all win is easier than one, not harder.
    difficulty -= len(solutions) - 1
    if board.gives_check(pv[0]):
        difficulty -= 1
    if len(pv) >= 10:
        difficulty += 1
    return max(1, min(10, difficulty))


# --------------------------------------------------------------------------
# Candidate evaluation
# --------------------------------------------------------------------------

def analyse_moves(board, engine, depth, cfg, movetime=None):
    """Top moves and their scores, from `engine`.

    A depth limit alone has no upper bound on cost. Measured on
    8/5k2/5p1p/4K3/8/8/5P1P/8 w - - 0 54 — six pieces, six legal moves — depth 6
    took 0.14s, depth 20 took 1.04s, and depth 26 had not returned after a
    minute. Pawn endings are where the search runs away, and they are the type
    most worth mining, so every call carries a clock as well as a depth.
    """
    width = min(board.legal_moves.count(), cfg.multipv)
    limit = (chess.engine.Limit(depth=depth, time=movetime) if movetime
             else chess.engine.Limit(depth=depth))
    info = engine.analyse(board, limit, multipv=width)
    values = [score_for_side_to_move(i["score"], board.turn) for i in info]
    return info, values


def find_cliff(values, threshold, cfg):
    """(k, drop) — how many leading moves reach `threshold`, and how far the
    first move below them falls. Returns (k, None) when the window shows no
    cliff, i.e. every move examined reached the threshold."""
    k = count_above(values, threshold)
    drop = values[k - 1] - values[k] if 0 < k < len(values) else None
    return k, drop



def classify_position(values, cfg):
    """('win'|'draw', threshold) or (None, rejection reason).

    A position is an exercise when a small, identifiable group of moves reaches
    the result and everything else falls off a cliff below them. Which result —
    winning a won position, or holding a drawn one — is the mode.
    """
    for mode, threshold, floor in (
            ("win", cfg.min_eval, None),
            ("draw", -cfg.draw_band, cfg.draw_band)):
        if cfg.mode not in (mode, "any"):
            continue
        # 'draw' means the position is held, not won; a won position is a win.
        if floor is not None and values[0] > floor:
            continue
        k, drop = find_cliff(values, threshold, cfg)
        if k == 0:
            continue
        if k > cfg.max_solutions:
            return None, "previse_jednako_dobrih_poteza"
        if drop is None:
            return None, "nema_provalije_u_prozoru"
        if drop < cfg.min_gap:
            return None, "provalija_preplitka"
        if mode == "win" and cfg.max_eval and values[0] > cfg.max_eval:
            return None, "van_opsega_ocene"
        return mode, threshold
    return None, "nijedan_potez_ne_dostize_prag"


# --------------------------------------------------------------------------
# Syzygy
# --------------------------------------------------------------------------
#
# For four and five pieces the engine is guessing at something that is already
# known. Stockfish called one pawn ending +5.72 at depth 18 and +7.61 at depth
# 25; a tablebase has no depth and no opinion, it has the result. Which is
# exactly what the cliff criterion was approximating all along: how many moves
# hold the result, and how many throw it away.
#
# So where the tables cover the position, "wins" stops being "at least +1.50
# according to a search that ran for three seconds" and becomes win.

WDL_WIN = 2
WDL_CURSED_WIN = 1
WDL_DRAW = 0


def open_tablebase(path):
    if not path:
        return None
    if not os.path.isdir(path):
        sys.exit("Syzygy folder ne postoji: {}\n"
                 "Prosledite --syzygy ili postavite SYZYGY_PATH.".format(path))
    return chess.syzygy.open_tablebase(path)


def probe_wdl(tb, board, cfg):
    """Result for the side to move, or a loud death.

    A silent fall back to the engine when a table is missing would be the worst
    of both: half the run exact, half of it guessed, and nothing in the output
    saying which half. Missing files are a setup mistake and should stop the run
    in the first seconds rather than skew a dataset six hours later.
    """
    wdl = tb.get_wdl(board)
    if wdl is None:
        sys.exit("Syzygy: nema tabele za poziciju sa {} figura ({}).\n"
                 "Folder: {}\nSpustite --syzygy-max-pieces ili dopunite tabele."
                 .format(len(board.piece_map()), board.fen(), cfg.syzygy))
    return wdl


def tablebase_results(board, tb, cfg):
    """{move: result for the mover, after that move}."""
    results = {}
    for move in board.legal_moves:
        board.push(move)
        try:
            results[move] = -probe_wdl(tb, board, cfg)
        finally:
            board.pop()
    return results


def tablebase_line(board, tb, cfg, plies):
    """Best play for both sides, from the tables.

    The winning side takes the shortest road and the losing side the longest,
    so the line reads like a game rather than like a resignation.
    """
    line = []
    walker = board.copy()
    for _ in range(plies):
        if walker.is_game_over() or len(walker.piece_map()) > cfg.syzygy_max_pieces:
            break
        results = tablebase_results(walker, tb, cfg)
        if not results:
            break
        best = max(results.values())
        candidates = [m for m, v in results.items() if v == best]

        def distance(move):
            walker.push(move)
            try:
                dtz = tb.get_dtz(walker)
            finally:
                walker.pop()
            return abs(dtz) if dtz is not None else 0

        move = (max(candidates, key=distance) if best < WDL_DRAW
                else min(candidates, key=distance))
        line.append(move)
        walker.push(move)
    return line


def classify_with_tablebase(results, cfg):
    """('win'|'draw', keepers) or (None, rejection reason)."""
    win_at = WDL_CURSED_WIN if cfg.allow_cursed else WDL_WIN
    best = max(results.values())
    for mode, reaches in (("win", win_at), ("draw", WDL_DRAW)):
        if cfg.mode not in (mode, "any"):
            continue
        if mode == "win" and best < win_at:
            continue
        # 'draw' means held, not won; a won position is a win.
        if mode == "draw" and best != WDL_DRAW:
            continue
        keepers = frozenset(m for m, v in results.items() if v >= reaches)
        if len(keepers) > cfg.max_solutions:
            return None, "previse_jednako_dobrih_poteza"
        if len(keepers) == len(results):
            return None, "svaki_potez_drzi_rezultat"
        return mode, keepers
    return None, "nijedan_potez_ne_dostize_prag"


def evaluate_with_tablebase(board, engines, tb, target_type, cfg, shared):
    _, shallow_engine = engines
    shared.bump("iz_tablica")
    results = tablebase_results(board, tb, cfg)
    if not results:
        shared.bump("nema_poteza")
        return None

    mode, keepers = classify_with_tablebase(results, cfg)
    if mode is None:
        shared.bump(keepers)  # keepers carries the rejection reason here
        return None

    best = min(keepers, key=lambda m: (not board.is_capture(m), m.uci()))
    victim = board.piece_at(best.to_square)
    if len(keepers) == 1 and board.is_capture(best) and (
            cfg.no_captures or (victim and victim.piece_type != chess.PAWN)):
        shared.bump("najbolji_potez_je_uzimanje")
        return None

    line = tablebase_line(board, tb, cfg, cfg.solution_plies)
    if not type_survives(board, line, target_type, cfg.persist_plies):
        shared.bump("zavrsnica_se_raspada")
        return None

    # Same obviousness rule as the engine branch: does a shallow search pick out
    # the same set of moves? It is measured against the truth here rather than
    # against a deeper guess, which is the whole point of having the tables.
    # The threshold has to follow the mode. Asking which moves the shallow
    # search thinks *win* is meaningless in a drawn position — it answers "none"
    # every time, the sets never match, and the filter silently stops existing.
    shallow_threshold = cfg.min_eval if mode == "win" else -cfg.draw_band
    shallow_info, shallow_values = analyse_moves(
        board, shallow_engine, cfg.shallow_depth, cfg)
    shallow_k, _ = find_cliff(shallow_values, shallow_threshold, cfg)
    shallow_solutions = frozenset(i["pv"][0] for i in shallow_info[:shallow_k])
    shallow_best = shallow_info[0]["pv"][0]
    if cfg.reject_obvious and shallow_solutions == keepers:
        shared.bump("ocigledno_na_maloj_dubini")
        return None

    dtz = tb.get_dtz(board)
    difficulty = 5 - (len(keepers) - 1)
    if shallow_best not in keepers:
        difficulty += 2
    if dtz is not None and abs(dtz) >= 30:
        difficulty += 1
    if dtz is not None and abs(dtz) >= 60:
        difficulty += 1
    if board.gives_check(best):
        difficulty -= 1

    san_board = board.copy()
    solution_san = []
    for move in line:
        solution_san.append(san_board.san(move))
        san_board.push(move)

    return {
        "fen": board.fen(),
        "source": "syzygy",
        "wdl": max(results.values()),
        "dtz": dtz,
        "eval": None,
        "cliff": None,
        "mode": mode,
        "difficulty": max(1, min(10, difficulty)),
        "winning_moves": [m.uci() for m in keepers],
        "winning_moves_san": sorted(board.san(m) for m in keepers),
        "solution": [m.uci() for m in line],
        "solution_san": solution_san,
        "depth": None,
        "verified_depth": None,
    }


class EnginePair:
    """The two engine processes, restartable.

    A pass over the whole collection runs for hours, and an engine that dies or
    answers something unexpected once should not cost the other five hours. The
    first crash in this project's history did exactly that: it killed the run at
    the tenth database of seven types, and a re-run over the same file did not
    reproduce it, so nothing was learned from the loss either.

    Unpacks like the tuple it replaces, so `deep, shallow = engines` still works.
    """

    def __init__(self, cfg):
        self.cfg = cfg
        self.failures = 0
        self.deep = self.shallow = None
        self.start()

    def start(self):
        # Hand Stockfish the tables too. The routing in evaluate_candidate is
        # decided once, by the piece count of the starting position, and never
        # switches - but a six-piece ending whose main line trades down to five
        # was being judged by a search that could not see the tables it was
        # walking into. With SyzygyPath set, the engine probes them itself at
        # the point the line crosses the boundary.
        options = {"Threads": self.cfg.threads, "Hash": self.cfg.hash}
        if self.cfg.syzygy:
            options["SyzygyPath"] = self.cfg.syzygy
        self.deep = chess.engine.SimpleEngine.popen_uci(self.cfg.stockfish)
        self.deep.configure(options)
        # Separate process, deliberately small: it must stay ignorant of what
        # the deep engine has found, and a 6-ply search needs neither threads
        # nor hash.
        self.shallow = chess.engine.SimpleEngine.popen_uci(self.cfg.stockfish)
        self.shallow.configure({"Threads": 1, "Hash": 16})

    def restart(self):
        for engine in (self.deep, self.shallow):
            try:
                engine.quit()
            except Exception:
                pass
        self.start()

    def quit(self):
        for engine in (self.deep, self.shallow):
            try:
                engine.quit()
            except Exception:
                pass

    def __iter__(self):
        return iter((self.deep, self.shallow))


def evaluate_candidate(board, engines, tb, target_type, cfg, shared):
    """Return a puzzle dict, or None with the rejection reason counted."""
    if cfg.reject_hanging and wins_material_outright(board):
        shared.bump("figura_visi")
        return None
    if cfg.reject_mate_in and forced_mate_within(board, cfg.reject_mate_in):
        shared.bump("forsiran_mat")
        return None
    try:
        if tb is not None and len(board.piece_map()) <= cfg.syzygy_max_pieces:
            return evaluate_with_tablebase(board, engines, tb, target_type, cfg, shared)
        return evaluate_with_engine(board, engines, target_type, cfg, shared)
    except (chess.engine.EngineError, chess.engine.EngineTerminatedError,
            KeyError, IndexError) as exc:
        # Loud, with the position, and then on with the run. Silence here would
        # be the usual mistake; so would dying and taking the afternoon's work
        # with it. Repeated failures still stop everything, because at some
        # point it is not a hiccup.
        engines.failures += 1
        shared.bump("greska_motora")
        print("\n[GRESKA {}/{}] {}: {}\n  FEN: {}".format(
            engines.failures, cfg.max_failures, type(exc).__name__, exc, board.fen()),
            file=sys.stderr, flush=True)
        traceback.print_exc()
        if engines.failures > cfg.max_failures:
            raise
        if isinstance(exc, (chess.engine.EngineError,
                            chess.engine.EngineTerminatedError)):
            engines.restart()
        return None


def evaluate_with_engine(board, engines, target_type, cfg, shared):
    deep_engine, shallow_engine = engines
    shared.bump("iz_motora")

    # The shallow search runs in its own engine process, which never sees a deep
    # search and so cannot read one out of its hash. With a single shared engine
    # a 6-ply search of an already-analysed position reported a 3459-centipawn
    # cliff where a cold table finds nothing at all — every measurement of
    # "would a shallow search see this?" was quietly meaningless. Clearing the
    # hash between calls also works, but throws away the deep engine's table on
    # every candidate.
    shallow_info, shallow_values = analyse_moves(
        board, shallow_engine, cfg.shallow_depth, cfg)

    info, values = analyse_moves(board, deep_engine, cfg.depth, cfg, cfg.movetime)
    best = info[0]["pv"][0]
    top = values[0]

    mode, threshold = classify_position(values, cfg)
    if mode is None:
        shared.bump(threshold)  # threshold carries the rejection reason here
        return None
    k, drop = find_cliff(values, threshold, cfg)
    solutions = frozenset(i["pv"][0] for i in info[:k])

    victim = board.piece_at(best.to_square)
    if board.is_capture(best) and (cfg.no_captures
                                   or (victim and victim.piece_type != chess.PAWN)):
        shared.bump("najbolji_potez_je_uzimanje")
        return None

    if not type_survives(board, info[0]["pv"], target_type, cfg.persist_plies):
        shared.bump("zavrsnica_se_raspada")
        return None

    # The obviousness test compares which moves each search believes win, not
    # merely which move it puts first. In the position above a 6-ply search also
    # plays Kd3 first — but it believes Kb4 wins too, and Kb4 draws. Asking only
    # "same first move?" would have thrown that position away.
    shallow_k, shallow_drop = find_cliff(shallow_values, threshold, cfg)
    shallow_solutions = frozenset(i["pv"][0] for i in shallow_info[:shallow_k])
    shallow_best = shallow_info[0]["pv"][0]
    if cfg.reject_obvious and shallow_solutions == solutions \
            and shallow_drop is not None and shallow_drop >= cfg.min_gap:
        shared.bump("ocigledno_na_maloj_dubini")
        return None

    # Only survivors are worth a deep re-check, and in pawn endings they need
    # one: the same position ran 791 / 1120 / 8308 centipawns at depths 18 / 20
    # / 26. A cliff seen at 20 can be an artefact of the horizon.
    verified_depth = None
    if cfg.verify_depth > cfg.depth:
        info, values = analyse_moves(board, deep_engine, cfg.verify_depth, cfg,
                                     cfg.verify_time)
        deep_mode, deep_threshold = classify_position(values, cfg)
        if deep_mode != mode:
            shared.bump("palo_na_dubljoj_proveri")
            return None
        k, drop = find_cliff(values, deep_threshold, cfg)
        top = values[0]
        solutions = frozenset(i["pv"][0] for i in info[:k])
        verified_depth = cfg.verify_depth

    line = info[0]["pv"][:cfg.solution_plies]
    san_board = board.copy()
    solution_san = []
    for move in line:
        solution_san.append(san_board.san(move))
        san_board.push(move)

    return {
        "fen": board.fen(),
        "source": "engine",
        "eval": top,
        "cliff": drop,
        "mode": mode,
        "difficulty": rate_difficulty(board, info[0]["pv"], solutions,
                                      shallow_solutions, shallow_best),
        # Every move that wins, not just the engine's favourite: the app has to
        # accept any of them, and a "play it out against the engine" drill needs
        # to know how wide the door is.
        "winning_moves": [m.uci() for m in solutions],
        "winning_moves_san": sorted(board.san(m) for m in solutions),
        "solution": [m.uci() for m in line],
        "solution_san": solution_san,
        "depth": cfg.depth,
        "verified_depth": verified_depth,
    }


# --------------------------------------------------------------------------
# PGN scanning
# --------------------------------------------------------------------------

def position_key(fen):
    """A position's identity as an exercise: everything but the move counters.

    Two databases that both contain Nakamura-Carlsen produce the same position
    with the same halfmove and fullmove numbers, so a plain FEN caught those.
    But the same position also arrives from unrelated games at a different move
    number, and as an exercise that is the same board twice. Four such pairs
    were already sitting in RookPawnVsRook.json.
    """
    return " ".join(fen.split()[:4])


def game_fingerprint(moves):
    """Identity of a game, taken from its moves rather than its headers.

    Header keys do not work here. Keeping Event in the key found 4743 games
    shared between databases; dropping it found only 4429, because the looser
    key merged distinct games instead. Neither is trustworthy: names are spelled
    differently by different sources, and a match can hold two games with
    identical headers. The moves are the game.

    Costs nothing extra - the game is parsed anyway, and what this saves is the
    engine time, which is the part that matters.
    """
    return hashlib.blake2b(
        " ".join(m.uci() for m in moves).encode("ascii"), digest_size=8).hexdigest()


class Shared:
    """Everything the workers touch together, behind one lock.

    Games are mined in parallel but a game is mined whole by one worker, because
    --per-game and --min-accept-gap both depend on which earlier position in
    that same game was accepted. So the only contention is on these three, and
    each claim is a set lookup - short enough that one lock costs nothing.

    Claiming is deliberately test-and-set rather than test-then-set: two workers
    reaching the same position at the same moment must not both be told it is
    new, or the duplicate lands in the output.
    """

    def __init__(self, known_fens, seen_games, stats):
        self.lock = threading.Lock()
        self.known_fens = known_fens
        self.seen_games = seen_games
        self.stats = stats

    def claim_game(self, fingerprint):
        with self.lock:
            if fingerprint in self.seen_games:
                self.stats["partija_vec_obradjena"] += 1
                return False
            self.seen_games.add(fingerprint)
            return True

    def claim_position(self, pos_key):
        with self.lock:
            if pos_key in self.known_fens:
                self.stats["vec_u_bazi"] += 1
                return False
            return True

    def keep_position(self, pos_key):
        with self.lock:
            self.known_fens.add(pos_key)

    def bump(self, name):
        with self.lock:
            self.stats[name] += 1

    def count(self, name):
        with self.lock:
            return self.stats.get(name, 0)


class Throttle:
    """How many games may be mined at once, adjusted while the run goes on.

    A fixed number is wrong because the work changes shape. Where the tablebase
    answers, a candidate costs a disk lookup and a 6-ply search, and most of the
    time goes on parsing and pushing moves - Python, holding the GIL, where
    extra threads only contend. Measured on RookPawnVsRook: 9s with one worker,
    30s with six, same 11 positions. Where the engine answers, a candidate costs
    seconds of search with the GIL released, and six workers ran 4.9 times the
    throughput of one.

    Rather than guess the mix per type, this climbs: every so often it compares
    the rate since the last checkpoint against the rate before, and keeps moving
    in whichever direction helped. It needs no model of the work and it also
    reacts to whatever else the machine is doing.
    """

    def __init__(self, start, maximum, tune_every):
        self.limit = max(1, min(start, maximum))
        self.maximum = maximum
        self.tune_every = tune_every
        self.in_flight = 0
        self.cond = threading.Condition()

        self.done_since = 0
        self.mark = time.time()
        # Levels to try, as (workers, threads each). Threads move opposite to
        # workers so the machine stays roughly fully used either way: one worker
        # on twelve threads and six on two both ask for the same cores. Holding
        # threads fixed at two was the flaw in the first attempt - one worker
        # then used two cores out of sixteen and still won the measurement,
        # which said more about the other levels being oversubscribed than
        # about one worker being right.
        cores = os.cpu_count() or 4
        self.plan = []
        for workers in (1, 2, 4, 6, 8):
            if workers > maximum:
                break
            self.plan.append((workers, max(1, cores // workers)))
        if not self.plan:
            self.plan = [(maximum, max(1, cores // maximum))]
        self.plan_index = 0
        self.measured = {}
        self.settled = False
        self.threads = self.plan[0][1]
        self.generation = 0
        self.limit = self.plan[0][0]

    def acquire(self):
        with self.cond:
            while self.in_flight >= self.limit:
                self.cond.wait()
            self.in_flight += 1

    def release(self):
        with self.cond:
            self.in_flight -= 1
            self.cond.notify()

    def tick(self):
        """One candidate analysed. This, not one game, is the unit of work.

        Measuring games per second does not work: most games hold no position of
        the wanted type and cost a millisecond, so the rate tracks how many
        candidate-bearing games happened to fall in the window and says nothing
        about concurrency. A first attempt at hill-climbing on that signal swung
        between 3 and 8 workers sixty times in sixteen seconds, reading rates
        from 13 to 490 a second, all of it noise.
        """
        with self.cond:
            if self.settled:
                return
            self.done_since += 1
            if self.done_since < self.tune_every:
                return
            elapsed = max(1e-6, time.time() - self.mark)
            rate = self.done_since / elapsed
            self.measured[(self.limit, self.threads)] = rate
            print("[podesavanje] {} radnika x {} niti: {:.2f} kandidata/s".format(
                self.limit, self.threads, rate), flush=True)

            self.done_since = 0
            self.plan_index += 1
            if self.plan_index < len(self.plan):
                self.limit, self.threads = self.plan[self.plan_index]
                self.generation += 1
            else:
                # Everything tried once; take the best and stop measuring. A
                # standing control loop would keep paying for exploration and
                # keep reacting to noise, and the mix within one type does not
                # move enough to be worth that.
                # Candidate cost varies by more than an order of magnitude -
                # one finishes at depth 20 in a second, the next runs into the
                # ten-second verify cap - so two levels within a fifth of each
                # other have not really been told apart. On a near tie take the
                # fewer workers: less memory, less contention, and a smaller
                # blast radius if the measurement was luck.
                top = max(self.measured.values())
                close = [k for k, v in self.measured.items() if v >= top * 0.8]
                best = min(close)
                self.limit, self.threads = best
                self.generation += 1
                self.settled = True
                print("[podesavanje] ostajem na {} radnika x {} niti "
                      "({:.2f} kandidata/s)".format(
                          best[0], best[1], self.measured[best]), flush=True)
            self.mark = time.time()
            self.cond.notify_all()


class WorkerPool:
    """One engine pair and one tablebase handle per thread.

    Engines cannot be shared: a UCI process handles one search at a time. The
    tablebase is opened per worker too - the handles memory-map the same files,
    so the operating system keeps a single copy in RAM regardless.
    """

    def __init__(self, cfg):
        self.cfg = cfg
        self.local = threading.local()
        self.all = []
        self.lock = threading.Lock()

    def resources(self, threads=None, generation=0):
        if not hasattr(self.local, "engines"):
            engines = EnginePair(self.cfg)
            tb = open_tablebase(self.cfg.syzygy)
            self.local.engines = engines
            self.local.tb = tb
            self.local.generation = -1
            with self.lock:
                self.all.append((engines, tb))
        # Each worker retunes its own engine, on its own thread, between
        # searches. Reaching across threads into an engine that may be mid
        # search would be the other way to do it, and the wrong one.
        if threads and self.local.generation != generation:
            try:
                self.local.engines.deep.configure({"Threads": threads})
            except chess.engine.EngineError:
                pass
            self.local.generation = generation
        return self.local.engines, self.local.tb

    def failures(self):
        with self.lock:
            return sum(e.failures for e, _ in self.all)

    def quit(self):
        with self.lock:
            for engines, tb in self.all:
                engines.quit()
                if tb:
                    tb.close()
            self.all = []


def visiting_order(db_name, total_games):
    """A stable shuffle of the game indices for one database.

    Seeded from the name with crc32 rather than hash(), because hash() on
    strings is salted per process and the order has to be the same next month
    as it is today - otherwise raising the target would revisit games already
    mined and skip ones never looked at.
    """
    order = list(range(total_games))
    random.Random(zlib.crc32(db_name.encode("utf-8"))).shuffle(order)
    return order


def count_games(pgn_path):
    # skip_game jumps over the movetext without building a Game, which is much
    # cheaper than read_headers: 7484 games in 0.11s against several seconds.
    total = 0
    with open(pgn_path, "r", encoding="utf-8", errors="replace") as f:
        while chess.pgn.skip_game(f):
            total += 1
    return total


def scan_pgn(pgn_path, pool, pool_exec, throttle, target_type, cfg, shared, visited,
             quota=0, total_games=None):
    """Mine one database, stopping at `quota` accepted positions (0 = no limit).

    Games are visited in a fixed pseudo-random order rather than from the front.
    Taking the first N would fill the quota out of Alekhine's early career and
    never reach his late games, and the same bias applies inside every file.

    `visited` carries the indices already looked at, and survives between runs.
    That is what makes the target raisable later: asking for more positions of a
    type resumes with games this database has not been through yet, instead of
    re-analysing the ones it has. The order is seeded from the database name, so
    the continuation follows the same sequence it would have followed anyway.
    """
    db_name = os.path.basename(pgn_path)
    if total_games is None:
        total_games = count_games(pgn_path)
    total_games = max(1, total_games)
    found = []
    start = time.time()
    interactive = sys.stdout.isatty()

    order = visiting_order(db_name, total_games)
    fresh_indices = [i for i in order if i not in visited]
    if quota:
        # Generous budget: most games hold no position of the wanted type at all.
        budget = max(200, quota * 40)
        fresh_indices = fresh_indices[:budget]
    wanted = set(fresh_indices)

    print("\nCitam PGN bazu: {} (partija: {}, vec obidjeno: {}, gledam: {}{})".format(
        db_name, total_games, len(visited), len(wanted),
        ", kvota {}".format(quota) if quota else ""))
    if not wanted:
        print("Nema neobidjenih partija u ovoj bazi.")
        return found

    step = max(1, len(wanted) // 20)
    seen_now = 0

    def handle(game):
        throttle.acquire()
        try:
            engines, tb = pool.resources(throttle.threads, throttle.generation)
            return mine_game(game, engines, tb, target_type, cfg, shared, db_name,
                             throttle)
        finally:
            throttle.release()

    # The main thread reads the file and the workers mine. Reading stays single
    # threaded because a PGN is a stream with no index; a game is mined whole by
    # one worker because --per-game and --min-accept-gap look back at what that
    # same game already yielded.
    #
    # The executor is created once for the whole run and passed in, never per
    # database. Each new pool spawns new threads, and engines live in
    # thread-local storage, so a fresh pool per database built a fresh set of
    # engines and left the previous set running: eight databases in, the machine
    # was carrying 128 Stockfish processes and 3.7 GB instead of 16 processes.
    pending = []

    def drain(limit):
        nonlocal pending
        while len(pending) > limit:
            done_future = pending.pop(0)
            found.extend(done_future.result())

    with open(pgn_path, "r", encoding="utf-8", errors="replace") as pgn_file:
        for index in range(total_games):
            if quota and len(found) >= quota:
                break
            if index not in wanted:
                if not chess.pgn.skip_game(pgn_file):
                    break
                continue
            game = chess.pgn.read_game(pgn_file)
            if game is None:
                break
            visited.add(index)
            seen_now += 1

            pending.append(pool_exec.submit(handle, game))
            # Keep only a shallow queue: deep enough that no worker idles,
            # shallow enough that the quota is noticed within a game or two
            # instead of after the whole file has been read ahead.
            drain(throttle.maximum * 2)

            # Carriage-return progress is unreadable once stdout is a file,
            # and a long run is exactly the case someone redirects to a log.
            if seen_now % step == 0:
                elapsed = time.time() - start
                share = seen_now / len(wanted)
                eta = (elapsed / share - elapsed) if share > 0.02 else 0
                print("[{}] {:<22} {:5.1f}% | Prihvaceno: {:4} | ETA: {}   ".format(
                    time.strftime("%H:%M:%S"), db_name, share * 100, len(found),
                    time.strftime("%H:%M:%S", time.gmtime(max(0, eta)))),
                    end="\r" if interactive else "\n", flush=True)

    drain(0)

    print("\nZavrseno {}: prihvaceno {} (obidjeno ukupno {}/{})".format(
        db_name, len(found), len(visited), total_games))
    return found


def mine_game(game, engines, tb, target_type, cfg, shared, db_name, throttle):
    found = []
    moves = list(game.mainline_moves())
    if not shared.claim_game(game_fingerprint(moves)):
        return found

    meta = {
        "white": game.headers.get("White", "Unknown"),
        "black": game.headers.get("Black", "Unknown"),
        "date": game.headers.get("Date", "????.??.??"),
        "result": game.headers.get("Result", "*"),
        "database": db_name,
        "type": target_type,
    }

    board = game.board()
    taken_here = 0
    # Two different spacings, because they do two different jobs.
    # last_seen_ply throttles cost: it is how often a position is handed
    # to the engine at all. last_taken_ply protects the dataset: two
    # accepted positions one ply apart are the same exercise twice.
    last_seen_ply = -999
    last_taken_ply = -999
    for ply, move in enumerate(moves):
        board.push(move)
        if taken_here >= cfg.per_game:
            break
        if ply - last_seen_ply < cfg.min_ply_gap:
            continue
        if ply - last_taken_ply < cfg.min_accept_gap:
            continue
        if board.is_game_over():
            continue
        if not is_target_endgame(board, target_type):
            continue
        # Most types constrain the pieces and say nothing about pawns, so
        # "opposite bishops" was matching a position with thirteen pawns on the
        # board - a middlegame that happens to have only bishops left, not a
        # lesson about opposite bishops. It is also permanently out of reach of
        # any tablebase.
        # Density, not pawn count. The two are the same measure shifted by the
        # type's fixed piece count - PawnEnding has two pieces before any pawn,
        # DoubleBishopVsBishopKnight has six - so one pawn cap treats the types
        # unequally. Capping total pieces asks the question that matters: does
        # this look like an endgame at all. Measured over 1119 mined positions,
        # <=16 drops 16 of them, all genuine middlegames; a cap of 6 pawns would
        # have dropped 357, most of them real material.
        if cfg.max_pieces and len(board.piece_map()) > cfg.max_pieces:
            shared.bump("pretrpana_pozicija")
            continue
        if cfg.max_pawns and pawn_count(board) > cfg.max_pawns:
            shared.bump("previse_pesaka")
            continue
        pos_key = position_key(board.fen())
        if not shared.claim_position(pos_key):
            continue

        shared.bump("kandidata")
        last_seen_ply = ply
        puzzle = evaluate_candidate(board, engines, tb, target_type, cfg, shared)
        throttle.tick()
        if puzzle:
            puzzle.update(meta)
            puzzle["ply"] = ply + 1
            found.append(puzzle)
            shared.keep_position(pos_key)
            taken_here += 1
            last_taken_ply = ply

    return found


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def build_parser():
    p = argparse.ArgumentParser(description="Izdvajanje zavrsnica iz PGN baza.")
    p.add_argument("--base-dir", default=DEFAULT_BASE_DIR)
    p.add_argument("--stockfish", default=DEFAULT_STOCKFISH)
    p.add_argument("--syzygy", default=os.environ.get("SYZYGY_PATH"),
                   help="Folder sa .rtbw/.rtbz tablicama; bez njega se koristi motor")
    p.add_argument("--syzygy-max-pieces", type=int, default=5,
                   help="Do koliko figura se veruje tablicama (4 ako imate samo cetvorke)")
    p.add_argument("--allow-cursed", action="store_true",
                   help="Racunaj i dobitke koje pravilo od 50 poteza kvari")
    p.add_argument("--type", dest="endgame_type")
    p.add_argument("--pgn", nargs="*", help="Imena PGN fajlova; izostavljeno = svi")
    p.add_argument("--out", help="Izlazni JSON; podrazumevano <base-dir>/<type>.json")

    p.add_argument("--mode", choices=["win", "draw", "any"], default="win",
                   help="win = konverzija prednosti, draw = odbrana remija")
    p.add_argument("--depth", type=int, default=20)
    p.add_argument("--shallow-depth", type=int, default=6)
    p.add_argument("--verify-depth", type=int, default=24,
                   help="Dublja provera samo za pozicije koje su prosle; 0 = bez nje")
    p.add_argument("--movetime", type=float, default=3.0,
                   help="Sekundi po dubokoj analizi; 0 = bez ogranicenja vremena")
    p.add_argument("--verify-time", type=float, default=10.0,
                   help="Sekundi po dubljoj proveri; 0 = bez ogranicenja vremena")
    p.add_argument("--multipv", type=int, default=6,
                   help="Koliko poteza se poredi da bi se videla provalija")
    # Measured on 24 pawn endings: one worker on 12 threads managed 0.34
    # positions a second, six workers on 2 threads managed 1.68 - almost linear.
    # With a movetime cap, extra threads in one search buy depth, not
    # throughput; extra workers buy throughput. Hence small workers, many of
    # them.
    p.add_argument("--workers", type=int, default=0,
                   help="Fiksan broj uporednih radnika; 0 = podesava se sam")
    p.add_argument("--max-workers", type=int,
                   default=max(1, min(8, (os.cpu_count() or 4) // 2)),
                   help="Gornja granica za samopodesavanje")
    p.add_argument("--tune-every", type=int, default=60,
                   help="Na koliko analiziranih kandidata se meri brzina pri "
                        "samopodesavanju")
    p.add_argument("--threads", type=int, default=2, help="Niti po radniku")
    p.add_argument("--hash", type=int, default=128, help="MB po radniku")

    p.add_argument("--min-eval", type=int, default=150)
    # No upper bound by default. A pawn ending that is won by force is worth
    # +80, not +2, and capping the evaluation threw out exactly the positions
    # worth playing out against the engine. Material grabs are already handled
    # by the hanging-piece and capture filters.
    p.add_argument("--max-eval", type=int, default=0, help="0 = bez gornje granice")
    p.add_argument("--draw-band", type=int, default=60)
    p.add_argument("--min-gap", type=int, default=150,
                   help="Koliko mora da padne prvi odbaceni potez ispod dobitnih")
    p.add_argument("--max-solutions", type=int, default=3,
                   help="Najvise dobitnih poteza da bi pozicija jos bila zadatak")
    p.add_argument("--persist-plies", type=int, default=4)
    p.add_argument("--solution-plies", type=int, default=8)
    p.add_argument("--per-game", type=int, default=2)
    p.add_argument("--min-ply-gap", type=int, default=1,
                   help="Najmanji razmak izmedju pozicija koje se salju motoru; "
                        "podici na 4-6 da bi prolaz bio brzi, uz manju pokrivenost")
    p.add_argument("--min-accept-gap", type=int, default=8,
                   help="Najmanji razmak izmedju dve prihvacene pozicije iz iste partije")
    p.add_argument("--max-games", type=int, default=0, help="0 = bez ogranicenja")
    p.add_argument("--target", type=int, default=0,
                   help="Koliko pozicija ukupno za ovaj tip; 0 = bez granice. "
                        "Deli se po bazama srazmerno broju partija u njima")

    p.add_argument("--allow-hanging", dest="reject_hanging", action="store_false")
    p.add_argument("--allow-obvious", dest="reject_obvious", action="store_false")
    p.add_argument("--max-failures", type=int, default=20,
                   help="Koliko gresaka motora se toleriše pre prekida")
    p.add_argument("--rescan", action="store_true",
                   help="Ponovo obradi i baze upisane u <out>.done")
    p.add_argument("--max-pieces", type=int, default=16,
                   help="Najvise figura ukupno; sluzi da motor ne trosi vreme "
                        "na srednjisnjicu. Pravi izbor gustine ide u upitu")
    p.add_argument("--max-pawns", type=int, default=0,
                   help="Najvise pesaka ukupno; 0 = bez granice (podrazumevano, "
                        "jer prag pesaka nejednako pogadja razlicite tipove)")
    p.add_argument("--reject-mate-in", type=int, default=2,
                   help="Odbaci pozicije sa forsiranim matom u toliko poteza; "
                        "0 = ne odbacuj")
    p.add_argument("--no-captures", action="store_true",
                   help="Odbaci i uzimanja pesaka, ne samo figura")
    return p


def choose_interactively(pgn_files):
    print("\n--- IZBOR TIPA ZAVRSNICE ---")
    for key in sorted(ENDGAME_TYPES):
        print("{}. {}".format(key, ENDGAME_TYPES[key][1]))
    choice = input("\nIzaberite broj zavrsnice: ").strip()
    if choice not in ENDGAME_TYPES:
        sys.exit("Neispravan izbor.")
    target_type = ENDGAME_TYPES[choice][0]

    print("\n--- IZBOR BAZA ---")
    for i, name in enumerate(pgn_files):
        print("{}. {}".format(i + 1, name))
    selection = input("\nBrojevi baza (npr. 1,2) ili 'sve': ").strip().lower()
    if selection == "sve":
        return target_type, pgn_files
    indices = [int(x) - 1 for x in selection.split(",") if x.strip().isdigit()]
    chosen = [pgn_files[i] for i in indices if 0 <= i < len(pgn_files)]
    if not chosen:
        sys.exit("Nijedna baza nije izabrana.")
    return target_type, chosen


def main():
    cfg = build_parser().parse_args()

    # Fail loudly. A missing engine or data directory must stop the run, not
    # quietly produce an empty result file two hours later.
    if not os.path.isdir(cfg.base_dir):
        sys.exit("Folder sa bazama ne postoji: {}\n"
                 "Prosledite --base-dir ili postavite CHESS_BASE_DIR.".format(cfg.base_dir))
    if not os.path.isfile(cfg.stockfish):
        sys.exit("Stockfish nije pronadjen: {}\n"
                 "Prosledite --stockfish ili postavite STOCKFISH_PATH.".format(cfg.stockfish))

    pgn_files = sorted(f for f in os.listdir(cfg.base_dir) if f.endswith(".pgn"))
    if not pgn_files:
        sys.exit("Nema PGN fajlova u " + cfg.base_dir)

    if cfg.endgame_type:
        valid = set(name for name, _ in ENDGAME_TYPES.values())
        if cfg.endgame_type not in valid:
            sys.exit("Nepoznat tip: {}. Dostupno: {}".format(
                cfg.endgame_type, ", ".join(sorted(valid))))
        target_type = cfg.endgame_type
        selected = cfg.pgn or pgn_files
        missing = [f for f in selected if f not in pgn_files]
        if missing:
            sys.exit("Nema ovih PGN fajlova u {}: {}".format(cfg.base_dir, ", ".join(missing)))
    else:
        target_type, selected = choose_interactively(pgn_files)

    out_path = cfg.out or os.path.join(cfg.base_dir, target_type + ".json")
    results = []
    if os.path.exists(out_path):
        with open(out_path, "r", encoding="utf-8") as f:
            results = json.load(f)
        print("Ucitano {} postojecih pozicija iz {}".format(
            len(results), os.path.basename(out_path)))
    known_fens = set(position_key(p["fen"]) for p in results)

    stats = Counter()
    pool = WorkerPool(cfg)
    throttle = Throttle(1, cfg.max_workers, cfg.tune_every)
    if cfg.workers:
        throttle.limit = cfg.workers
        throttle.threads = cfg.threads
        throttle.settled = True
    if cfg.syzygy:
        if not os.path.isdir(cfg.syzygy):
            sys.exit("Syzygy folder ne postoji: " + cfg.syzygy)
        print("Syzygy: {} (do {} figura)".format(cfg.syzygy, cfg.syzygy_max_pieces))
    print("Stockfish: {}, {} niti i {} MB po radniku | dubina {} | rezim {}".format(
        "fiksno {} radnika".format(cfg.workers) if cfg.workers
        else "samopodesavanje 1-{} radnika".format(cfg.max_workers),
        cfg.threads, cfg.hash, cfg.depth, cfg.mode))

    # Which databases are finished, at file granularity. Re-running only skips
    # positions already accepted, so without this a run interrupted at hour six
    # would re-analyse every rejected candidate from the first five. Cheap to
    # keep, and it makes a long pass restartable.
    done_path = out_path + ".done"
    done = set()
    if os.path.exists(done_path) and not cfg.rescan:
        with open(done_path, "r", encoding="utf-8") as f:
            done = set(json.load(f))
        if done:
            print("Vec obradjeno baza: {} (--rescan da se ponove)".format(len(done)))

    # Games already scanned, by move fingerprint. Has to outlive the process for
    # the same reason .done does: a database finished before the interruption
    # may hold a game that a later database repeats, and without this the second
    # copy would be analysed again after every restart.
    games_path = out_path + ".games"
    seen_games = set()
    if os.path.exists(games_path) and not cfg.rescan:
        with open(games_path, "r", encoding="utf-8") as f:
            seen_games = set(json.load(f))
        if seen_games:
            print("Vec vidjeno partija: {}".format(len(seen_games)))

    # Which game indices each database has been through. This is what lets the
    # target be raised later: the next run picks up games this type has never
    # looked at, instead of grinding through the ones it already mined.
    visited_path = out_path + ".visited"
    visited = {}
    if os.path.exists(visited_path) and not cfg.rescan:
        with open(visited_path, "r", encoding="utf-8") as f:
            visited = {k: set(v) for k, v in json.load(f).items()}

    # Each database's share of the target is its share of the games, not an
    # equal slice: a 7484-game database and a 250-game one should not be asked
    # for the same number of positions. Counting is cheap - skip_game runs at
    # roughly 70000 games a second.
    shared = Shared(known_fens, seen_games, stats)

    sizes = {}
    if cfg.target:
        print("Brojim partije po bazama...", flush=True)
        for name in selected:
            sizes[name] = count_games(os.path.join(cfg.base_dir, name))
        print("Cilj {} pozicija iz {} partija u {} baza".format(
            cfg.target, sum(sizes.values()), len(selected)))

    pool_exec = ThreadPoolExecutor(max_workers=throttle.maximum)
    reached = False
    try:
        # Sweeps, not one pass. Each database is asked for its share and looks
        # at a bounded slice of its games, so one pass around the collection can
        # come back short of the target while thousands of games sit unread.
        # Going round again picks those up, because .visited remembers which
        # ones have been through. It stops when the target is met or when a
        # whole sweep turns up no game nobody had seen - that is the collection
        # exhausted, and the honest answer is the number it found.
        sweep = 0
        while not reached:
            sweep += 1
            visited_before = sum(len(v) for v in visited.values())
            if sweep > 1:
                print("\n===== krug {}: jos {} pozicija do cilja =====".format(
                    sweep, cfg.target - len(results)))

            for index, name in enumerate(selected):
                if name in done:
                    continue

                quota = 0
                if cfg.target:
                    # Recomputed each time, so a database that cannot fill its
                    # share passes the remainder on to the ones after it instead
                    # of leaving the target short.
                    left = cfg.target - len(results)
                    if left <= 0:
                        print("Cilj dostignut, preostale baze se preskacu.")
                        reached = True
                        break
                    games_left = sum(sizes[n] for n in selected[index:]
                                     if n not in done)
                    quota = max(1, round(left * sizes[name] / max(1, games_left)))

                been = visited.setdefault(name, set())
                fresh = scan_pgn(os.path.join(cfg.base_dir, name), pool, pool_exec,
                                 throttle, target_type, cfg, shared, been,
                                 quota=quota, total_games=sizes.get(name))
                results.extend(fresh)

                # Marked finished only when every game in it has been looked at.
                # Under a target a database usually stops early, and calling that
                # "done" would lock it out of a later run with a bigger target -
                # exactly the material you would then be reaching for.
                total_here = sizes.get(name) or count_games(os.path.join(cfg.base_dir, name))
                sizes[name] = total_here
                if len(been) >= total_here:
                    done.add(name)
                with open(done_path, "w", encoding="utf-8") as f:
                    json.dump(sorted(done), f)
                with open(games_path, "w", encoding="utf-8") as f:
                    json.dump(sorted(seen_games), f)
                with open(visited_path, "w", encoding="utf-8") as f:
                    json.dump({k: sorted(v) for k, v in visited.items()}, f)
                # Written after every database, not once at the end: a run over the
                # whole collection takes hours and an interruption must not throw
                # away everything found so far.
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(results, f, indent=4, ensure_ascii=False)
                print("Sacuvano: {} ukupno u {}".format(len(results), out_path))

            if cfg.target and len(results) >= cfg.target:
                reached = True
                break
            if not cfg.target:
                reached = True
                break
            visited_now = sum(len(v) for v in visited.values())
            if visited_now == visited_before:
                print("\nZbirka je iscrpljena: nema vise partija koje ovaj tip "
                      "nije video. Nadjeno {} od trazenih {}.".format(
                          len(results), cfg.target))
                break
    except KeyboardInterrupt:
        print("\nPrekinuto - sacuvano je sve do poslednje zavrsene baze.")
    finally:
        pool_exec.shutdown(wait=True)
        pool.quit()

    # Routing counters are not rejection reasons and must not be listed as if
    # they were: "iz_motora 123 100.0%" in a rejection table reads like every
    # candidate was thrown out by the engine.
    routing = ("kandidata", "iz_motora", "iz_tablica", "vec_u_bazi",
               "partija_vec_obradjena")
    candidates = stats.get("kandidata", 0)
    print("\n--- STATISTIKA ODBACIVANJA ---")
    for reason, count in stats.most_common():
        if reason in routing:
            continue
        share = "{:.1f}%".format(count / candidates * 100) if candidates else "-"
        print("{:32} {:7}  {}".format(reason, count, share))
    # How much of the collection this type has actually been through. Without
    # it there is no way to tell whether a thin harvest means the material is
    # exhausted or merely that the target was reached after two databases.
    if visited:
        print("\n--- POKRIVENOST ---")
        total_seen = total_all = 0
        rows = []
        for name in sorted(visited):
            size = sizes.get(name) or count_games(os.path.join(cfg.base_dir, name))
            been = len(visited[name])
            total_seen += been
            total_all += size
            rows.append((name, been, size))
        for name, been, size in rows:
            print("{:<28} {:6}/{:6}  {:5.1f}%".format(
                name, been, size, been / max(1, size) * 100))
        for name in selected:
            if name not in visited:
                size = sizes.get(name)
                print("{:<28} {:>13}   {:5.1f}%".format(
                    name, "0/{}".format(size) if size else "netaknuto", 0.0))
                total_all += size or 0
        print("{:<28} {:6}/{:6}  {:5.1f}%".format(
            "UKUPNO", total_seen, total_all, total_seen / max(1, total_all) * 100))
        if total_seen < total_all:
            print("Za vise pozicija ovog tipa: podignite --target, "
                  "obidju se partije koje jos nisu gledane.")

    print("\n--- OBRADA ---")
    print("{:32} {:7}".format("kandidata ukupno", candidates))
    print("{:32} {:7}".format("resavano iz tablica", stats.get("iz_tablica", 0)))
    print("{:32} {:7}".format("resavano motorom", stats.get("iz_motora", 0)))
    print("{:32} {:7}".format("pozicija vec u bazi", stats.get("vec_u_bazi", 0)))
    print("{:32} {:7}".format("partija preskoceno kao duple",
                              stats.get("partija_vec_obradjena", 0)))


if __name__ == "__main__":
    main()
