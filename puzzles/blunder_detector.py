# -*- coding: utf-8 -*-
"""Find the moves that changed the result, in games that reached a tablebase.

A blunder here is not an opinion. Where the tables cover the position the result
is a fact before the move and a fact after it, so "this move threw the win away"
needs no threshold, no depth, and no engine at all. And the proof that the
position was not trivial is that a human sat in front of it and got it wrong.

Every such move gives two exercises: find the move that holds, and punish the
one that did not.

What this deliberately does not call a blunder:

  - a move in an already lost position, where there is nothing left to drop;
  - a move that keeps the win and wastes time. That is real, and it belongs to
    the play-it-out drill, which measures it with DTZ. Counting it here would
    bury the outcome changes under hundreds of slow rook moves.

A win that becomes a cursed win *is* counted, because a cursed win is one only
if the fifty move rule is ignored - the same rule the collection follows
everywhere else.

Working with the big bases

  The gigabase is 8 GB and ~9.7 million games, so it is never read whole. First
  a pass over headers alone, which runs at sixty thousand games a second and
  finishes the file in three minutes, recording where each game sits and what
  the players were rated. After that any rating range is counted instantly and
  the analysis seeks straight to the games that qualify.

  Games are visited in a fixed random order through the whole file, never
  front to back. The file is sorted, and it shows: at the front the median game
  is 25 plies and not one in four hundred reaches six pieces, while at the back
  the median is 118 and a third of them do. A slice taken in one piece measures
  the slice, not the base.

Usage:
    python blunder_detector.py            # asks what to do
    python blunder_detector.py --reindex  # rebuilds the header index first
"""

import argparse
import array
import io
import json
import os
import random
import sys
import time

import chess
import chess.pgn
import chess.syzygy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from endgame_miner import open_tablebase, check_tablebase_coverage  # noqa: E402

DEFAULT_BASE_DIR = os.environ.get("CHESS_BASE_DIR", r"D:\chess_base")
DEFAULT_GIGA_DIR = os.environ.get(
    "CHESS_GIGA_DIR", os.path.join(DEFAULT_BASE_DIR, "lubras_gigabase"))
DEFAULT_OUT_DIR = os.path.join(DEFAULT_BASE_DIR, "_blunders")

WDL_WIN = 2
WDL_CURSED_WIN = 1
WDL_DRAW = 0

# What the three-way verdict is called in the output. Cursed wins and blessed
# losses collapse into 'draw' on purpose: under the fifty move rule that is what
# they are, and the rest of the project already treats them that way.
OUTCOMES = {2: "win", 1: "draw", 0: "draw", -1: "draw", -2: "loss"}
RANK = {"loss": 0, "draw": 1, "win": 2}


# --------------------------------------------------------------------------
# Sources
# --------------------------------------------------------------------------

class Source(object):
    """One base: a single big PGN, or a folder treated as one collection."""

    def __init__(self, key, label, files, folder):
        self.key = key
        self.label = label
        self.files = files
        self.folder = folder

    def path(self, file_id):
        return os.path.join(self.folder, self.files[file_id])

    @property
    def size(self):
        return sum(os.path.getsize(self.path(i)) for i in range(len(self.files)))


def discover_sources(giga_dir, base_dir):
    sources = []
    for key, label, name in (
        ("otb", "Lumbras OTB", "LumbrasGigaBase_OTB_Complete.pgn"),
        ("online", "Lumbras Online", "LumbrasGigaBase_Online_Complete.pgn"),
    ):
        if os.path.isfile(os.path.join(giga_dir, name)):
            sources.append(Source(key, label, [name], giga_dir))

    curated = sorted(f for f in os.listdir(base_dir) if f.endswith(".pgn"))
    if curated:
        sources.append(Source("majstori", "43 majstorske baze", curated, base_dir))
    return sources


# --------------------------------------------------------------------------
# The header index
# --------------------------------------------------------------------------
#
# Four parallel arrays rather than a list of records: array.fromfile reads them
# at C speed, and ten million tuples would not be worth the memory.

class Index(object):
    def __init__(self):
        self.file_id = array.array("H")
        self.offset = array.array("q")
        self.white = array.array("H")
        self.black = array.array("H")

    def __len__(self):
        return len(self.offset)


def index_paths(out_dir, source):
    stem = os.path.join(out_dir, "_index_" + source.key)
    return stem + ".bin", stem + ".json"


def fingerprint_source(source):
    return [[name, os.path.getsize(source.path(i))]
            for i, name in enumerate(source.files)]


def build_index(source, out_dir):
    """One pass over headers alone. Loud about how long it took."""
    index = Index()
    start = time.time()
    for file_id, name in enumerate(source.files):
        path = source.path(file_id)
        print("  popis: {} ...".format(name), flush=True)
        with io.open(path, encoding="utf-8", errors="replace") as f:
            while True:
                where = f.tell()
                try:
                    headers = chess.pgn.read_headers(f)
                except Exception:
                    continue
                if headers is None:
                    break
                index.file_id.append(file_id)
                index.offset.append(where)
                index.white.append(parse_elo(headers.get("WhiteElo")))
                index.black.append(parse_elo(headers.get("BlackElo")))

    bin_path, meta_path = index_paths(out_dir, source)
    with io.open(bin_path, "wb") as f:
        for column in (index.file_id, index.offset, index.white, index.black):
            column.tofile(f)
    meta = {
        "source": source.key,
        "files": fingerprint_source(source),
        "games": len(index),
        "built": time.strftime("%Y-%m-%d %H:%M"),
    }
    with io.open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)

    print("  popisano {} partija za {:.0f}s".format(len(index), time.time() - start))
    return index


def load_index(source, out_dir, reindex=False):
    bin_path, meta_path = index_paths(out_dir, source)
    if reindex or not (os.path.exists(bin_path) and os.path.exists(meta_path)):
        return build_index(source, out_dir)

    with io.open(meta_path, encoding="utf-8") as f:
        meta = json.load(f)
    # A PGN that grew or shrank invalidates every offset in the index. Silently
    # reading the old one would seek into the middle of games and report
    # nonsense, so the mismatch rebuilds rather than warns.
    if meta.get("files") != fingerprint_source(source):
        print("  baza se promenila od popisa - pravim ga ponovo")
        return build_index(source, out_dir)

    n = meta["games"]
    index = Index()
    with io.open(bin_path, "rb") as f:
        index.file_id.fromfile(f, n)
        index.offset.fromfile(f, n)
        index.white.fromfile(f, n)
        index.black.fromfile(f, n)
    return index


def parse_elo(text):
    try:
        value = int(str(text).strip())
    except (TypeError, ValueError):
        return 0
    return value if 0 < value < 65535 else 0


# --------------------------------------------------------------------------
# Which games, and which of them are already done
# --------------------------------------------------------------------------

def done_path(out_dir, source):
    return os.path.join(out_dir, "_done_" + source.key + ".bin")


def load_done(out_dir, source):
    path = done_path(out_dir, source)
    done = array.array("q")
    if os.path.exists(path):
        size = os.path.getsize(path)
        with io.open(path, "rb") as f:
            done.fromfile(f, size // done.itemsize)
    return set(done)


def append_done(out_dir, source, indices):
    if not indices:
        return
    with io.open(done_path(out_dir, source), "ab") as f:
        array.array("q", sorted(indices)).tofile(f)


def eligible(index, rating_range):
    """Games inside the range, and how many were dropped for want of a rating.

    Both players, not one: a range is a statement about the level the game was
    played at, and 2400 against 1600 is not a game at either level.
    """
    picks = []
    no_rating = 0
    for i in range(len(index)):
        w, b = index.white[i], index.black[i]
        rated = bool(w and b)
        if not rated:
            no_rating += 1
        if rating_range is None:
            picks.append(i)
            continue
        if not rated:
            continue
        low, high = rating_range
        if low <= w <= high and low <= b <= high:
            picks.append(i)
    return picks, no_rating


def visiting_order(picks, seed):
    """A fixed random order through the whole file.

    Taking the first N would take them from one place in a sorted file, and in
    this base that is a different game entirely - short games at the front, full
    ones at the back. The seed is fixed so a later, larger run continues the
    same walk instead of reshuffling what was already done.
    """
    order = list(picks)
    random.Random(seed).shuffle(order)
    return order


# --------------------------------------------------------------------------
# The walk
# --------------------------------------------------------------------------

def playable_wdl(tb, board):
    """The result the fifty move rule actually allows, not the abstract one.

    probe_wdl answers as though the counter were at zero, which is the right
    answer to a different question. Real games arrive at endings with the
    counter already high: the first blunder this tool ever found was Lasker
    against Tarrasch in 1908, at ninety-five half-moves, where the win existed
    with exactly five to spare. Five more and the tables would still have called
    it lost while the game was a draw, and the exercise would have asked a child
    to save a position nobody could lose.

    DTZ is the distance to the next zeroing move, and a zeroing move is what
    restarts the count - so the win is reachable exactly when it fits in what is
    left of the hundred.
    """
    wdl = tb.get_wdl(board)
    if wdl is None:
        return None
    if abs(wdl) == 2:
        dtz = tb.get_dtz(board)
        if dtz is not None and abs(dtz) + board.halfmove_clock > 100:
            return WDL_DRAW
    return wdl


def cause_of(tb, fen_before, board_after, before, after):
    """Which of the two mistakes this was.

    'outcome' is the classic: the result changed, and it would have changed
    whatever the counter said. 'fifty_move' is the other one - the win was there
    the whole time and the fifty moves ran out under it. Both are real and both
    are worth practising, but they are not the same exercise: the first asks
    "what holds", the second asks "why did you have nothing left to spend".
    They are marked rather than merged so a lesson can pick one.

    Nine of the first ten found this way were bishop and knight against a bare
    king, which is exactly where a player runs out of moves.
    """
    plain = {2: "win", 1: "draw", 0: "draw", -1: "draw", -2: "loss"}
    was = tb.get_wdl(chess.Board(fen_before))
    now = tb.get_wdl(board_after)
    if was is None or now is None:
        return "outcome"
    if plain[was] != plain[-now]:
        return "outcome"
    return "fifty_move"


def within_tables(board, max_pieces):
    """Whether the tables can answer this position at all.

    Piece count is the obvious half. Castling rights are the half that is easy
    to miss: Syzygy has no notion of them, so a four-piece rook ending where
    neither king has moved is outside the tables even though it looks like the
    simplest position on the board. Rare, but silently probing it would return
    nothing and the walk would read that as "no verdict" forever after.
    """
    return len(board.piece_map()) <= max_pieces and not board.castling_rights


def analyse_game(game, tb, cfg):
    """Every outcome-changing move in one game, with what should have been played.

    One probe per position, not two: the position after a move is the position
    before the next one, so the walk carries the verdict forward.
    """
    board = game.board()
    moves = list(game.mainline_moves())
    if not moves:
        return None, False

    reached = False
    blunders = []
    start_ply = None
    wdl_before = None

    for ply, move in enumerate(moves):
        in_reach = within_tables(board, cfg.max_pieces)
        reached = reached or in_reach
        if in_reach and wdl_before is None:
            wdl_before = playable_wdl(tb, board)

        played_san = board.san(move)
        material = chess.syzygy.calc_key(board) if in_reach else None
        fen_before = board.fen()
        pieces_before = len(board.piece_map())
        clock_before = board.halfmove_clock
        mover = "white" if board.turn == chess.WHITE else "black"

        board.push(move)

        after_in_reach = within_tables(board, cfg.max_pieces)
        wdl_after = playable_wdl(tb, board) if after_in_reach else None

        if in_reach and wdl_before is not None and wdl_after is not None:
            before = OUTCOMES[wdl_before]
            after = OUTCOMES[-wdl_after]
            if before != "loss" and RANK[after] < RANK[before]:
                if start_ply is None:
                    start_ply = ply
                blunders.append({
                    "ply": ply - (start_ply or 0),
                    "ply_in_game": ply,
                    "fen": fen_before,
                    "side": mover,
                    "played": played_san,
                    "played_uci": move.uci(),
                    "outcome_before": before,
                    "outcome_after": after,
                    "cause": cause_of(tb, fen_before, board, before, after),
                    "clock": clock_before,
                    "material": material,
                    "pieces": pieces_before,
                })

        # Carried forward, and the sign is the whole trap. get_wdl always
        # answers for whoever is to move in the position it is handed, so after
        # the push it already speaks for the next mover: carrying it needs no
        # negation. Negating it inverted every second ply, and the first run
        # duly reported that masters lose won positions outright seventy-seven
        # times in eighty - which is what a sign error looks like from outside.
        # Only the reading of the move just played needs flipping, because that
        # one is asked from the opponent's side of the board.
        wdl_before = wdl_after

    if not blunders:
        return None, reached

    # The moves that would have held, worked out only for positions that turned
    # out to matter. Probing every child of every position would be the same
    # answer at forty times the cost.
    for entry in blunders:
        entry["should_play"], entry["should_play_uci"] = holding_moves(
            tb, chess.Board(entry["fen"]), entry["outcome_before"])

    return build_record(game, moves, start_ply, blunders), reached


def holding_moves(tb, board, wanted):
    """Every move that keeps `wanted`, in SAN and UCI."""
    san, uci = [], []
    # list(), not the generator: legal_moves reads the board lazily and this
    # loop pushes and pops inside it. The same mistake is already written up in
    # ZAVRSNICE.md, from the first time it cost an afternoon.
    for move in list(board.legal_moves):
        board.push(move)
        try:
            wdl = playable_wdl(tb, board)
        finally:
            board.pop()
        if wdl is None:
            continue
        if OUTCOMES[-wdl] == wanted:
            san.append(board.san(move))
            uci.append(move.uci())
    return sorted(san), uci


def build_record(game, moves, start_ply, blunders):
    """One record per game, starting where it first went wrong.

    Not from move one. The opening and the middlegame are not the subject here,
    and carrying them would multiply the file for nothing: what the app needs is
    the position the player was looking at when they erred, and the game as it
    actually continued from there.
    """
    board = game.board()
    for move in moves[:start_ply]:
        board.push(move)
    start_fen = board.fen()

    tail_san = []
    for move in moves[start_ply:]:
        tail_san.append(board.san(move))
        board.push(move)

    headers = game.headers
    return {
        "database": None,  # filled by the caller, which knows the file
        "white": headers.get("White", "?"),
        "black": headers.get("Black", "?"),
        "white_elo": parse_elo(headers.get("WhiteElo")),
        "black_elo": parse_elo(headers.get("BlackElo")),
        "date": headers.get("Date", "????.??.??"),
        "event": headers.get("Event", ""),
        "result": headers.get("Result", "*"),
        "start_fen": start_fen,
        "start_ply": start_ply,
        "moves": tail_san,
        "blunders": blunders,
    }


# --------------------------------------------------------------------------
# Asking
# --------------------------------------------------------------------------

def ask_source(sources):
    print("\nKoja baza?")
    for i, source in enumerate(sources, 1):
        print("  [{}] {:<22} {:>6.1f} GB, {} fajl(ova)".format(
            i, source.label, source.size / 1024.0 ** 3, len(source.files)))
    while True:
        answer = input("izbor: ").strip()
        if answer.isdigit() and 1 <= int(answer) <= len(sources):
            return sources[int(answer) - 1]
        print("  unesite broj izmedju 1 i {}".format(len(sources)))


def ask_range():
    """The range, or None for no filter at all.

    None is not the same as 0-65534. Without a filter an unrated game is still
    a game and stays in; with one it cannot be shown to be inside the range, so
    it goes. Collapsing the two silently dropped a quarter of the collection.
    """
    print("")
    print("Rejting: oba igraca moraju biti u opsegu.")
    while True:
        answer = input("  od-do (npr. 1800 2200, Enter = bez filtera): ").strip()
        if not answer:
            return None
        parts = answer.replace("-", " ").split()
        if len(parts) == 2 and all(p.isdigit() for p in parts):
            low, high = int(parts[0]), int(parts[1])
            if low <= high:
                return low, high
        print("  unesite dva broja, manji pa veci")


def ask_count(available, default=1000):
    while True:
        answer = input(
            "  koliko partija da analiziramo sada? (Enter = {}): ".format(default)
        ).strip()
        if not answer:
            return min(default, available)
        if answer.isdigit() and int(answer) > 0:
            return min(int(answer), available)
        print("  unesite ceo broj veci od nule, ili Enter")


# --------------------------------------------------------------------------
# What the collected file holds
# --------------------------------------------------------------------------

def read_records(path):
    if not os.path.exists(path):
        return []
    records = []
    with io.open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except ValueError:
                # A half-written last line is what an interrupted run leaves.
                # Skipping it is right; calling the file corrupt is not.
                continue
    return records


def report_stats(path, top_types=12):
    """How the collected games are spread, which is the part worth watching.

    A game with one blunder is a position; a game with five is a whole ending
    played badly, and that is the one worth walking through with a child. The
    distribution is the difference between those two, and a single total hides
    it.
    """
    records = read_records(path)
    if not records:
        print("Jos nema rezultata u {}".format(path))
        return

    by_count = {}
    by_type = {}
    by_outcome = {}
    total = 0
    for record in records:
        n = len(record.get("blunders") or [])
        by_count[n] = by_count.get(n, 0) + 1
        total += n
        for entry in record.get("blunders") or []:
            key = entry.get("material") or "?"
            by_type[key] = by_type.get(key, 0) + 1
            move = "{} -> {}".format(entry.get("outcome_before"),
                                     entry.get("outcome_after"))
            if entry.get("cause") == "fifty_move":
                move += " (50)"
            by_outcome[move] = by_outcome.get(move, 0) + 1

    print("--- U ZBIRCI: {} partija, {} gresaka ---".format(len(records), total))
    print("")
    print("gresaka po partiji:")
    widest = max(by_count.values())
    for n in sorted(by_count):
        bar = "#" * max(1, int(30.0 * by_count[n] / widest))
        print("  {:>2}: {:>6}  {}".format(n, by_count[n], bar))
    print("  prosek {:.2f} po partiji".format(total / float(len(records))))

    print("")
    print("sta je izgubljeno:   ((50) = istekao brojac, ne promasen potez)")
    for move, count in sorted(by_outcome.items(), key=lambda kv: -kv[1]):
        print("  {:<16} {:>6}".format(move, count))

    print("")
    print("najcesci tipovi zavrsnica:")
    ranked = sorted(by_type.items(), key=lambda kv: -kv[1])
    for key, count in ranked[:top_types]:
        print("  {:<12} {:>6}".format(key, count))
    if len(ranked) > top_types:
        print("  ... i jos {} tipova".format(len(ranked) - top_types))


# --------------------------------------------------------------------------

def build_parser():
    p = argparse.ArgumentParser(
        description="Trazi poteze koji su promenili ishod, iz tablica.")
    p.add_argument("--base-dir", default=DEFAULT_BASE_DIR)
    p.add_argument("--giga-dir", default=DEFAULT_GIGA_DIR)
    p.add_argument("--out-dir", default=DEFAULT_OUT_DIR)
    p.add_argument("--syzygy", default=os.environ.get("SYZYGY_PATH"),
                   help="Folder(i) sa tablicama, razdvojeni znakom '{}'".format(
                       os.pathsep))
    p.add_argument("--max-pieces", type=int, default=6,
                   help="Dokle sezu tablice koje imate")
    p.add_argument("--reindex", action="store_true",
                   help="Napravi popis zaglavlja ponovo")
    p.add_argument("--stats", metavar="BAZA", nargs="?", const="",
                   help="Samo prikazi sta je do sada nadjeno, bez analize")
    return p


def main():
    cfg = build_parser().parse_args()

    # Looking at what is already collected needs neither tables nor an index,
    # so it happens before either is asked for.
    if cfg.stats is not None:
        names = [cfg.stats] if cfg.stats else (
            sorted(f[:-6] for f in os.listdir(cfg.out_dir)
                   if f.endswith(".jsonl"))
            if os.path.isdir(cfg.out_dir) else [])
        if not names:
            sys.exit("Nema nijednog rezultata u " + cfg.out_dir)
        for name in names:
            print("=== {} ===".format(name))
            report_stats(os.path.join(cfg.out_dir, name + ".jsonl"))
            print("")
        return

    if not cfg.syzygy:
        sys.exit("Prosledite --syzygy ili postavite SYZYGY_PATH.")
    os.makedirs(cfg.out_dir, exist_ok=True)

    tb = open_tablebase(cfg.syzygy)
    # The miner's startup check, which reads its own flag name. Same question:
    # do the tables actually reach as far as we are about to claim.
    cfg.syzygy_max_pieces = cfg.max_pieces
    check_tablebase_coverage(tb, cfg)
    print("Syzygy: {} (do {} figura)".format(cfg.syzygy, cfg.max_pieces))

    sources = discover_sources(cfg.giga_dir, cfg.base_dir)
    if not sources:
        sys.exit("Nema nijedne baze u {} ni {}".format(cfg.giga_dir, cfg.base_dir))
    source = ask_source(sources)

    print("\nPopis zaglavlja za {} ...".format(source.label))
    index = load_index(source, cfg.out_dir, cfg.reindex)
    print("  ukupno partija: {}".format(len(index)))

    rating_range = ask_range()
    picks, no_rating = eligible(index, rating_range)
    done = load_done(cfg.out_dir, source)
    order = [i for i in visiting_order(picks, source.key) if i not in done]

    print("")
    if rating_range is None:
        print("  bez filtera rejtinga:  {} partija".format(len(picks)))
        if no_rating:
            print("  od toga bez rejtinga:  {}".format(no_rating))
    else:
        print("  u opsegu {}-{}:      {} partija".format(
            rating_range[0], rating_range[1], len(picks)))
        if no_rating:
            print("  bez rejtinga, ispalo:  {}".format(no_rating))
    print("  vec analizirano:       {}".format(len(picks) - len(order)))
    print("  ostalo:                {}".format(len(order)))
    # Only measurable after the fact; the headers say nothing about it.
    print("  od toga do {} figura stize otprilike desetina".format(cfg.max_pieces))
    if not order:
        sys.exit("\nNema novih partija za ovaj opseg.")

    wanted = ask_count(len(order))
    run(source, index, order[:wanted], tb, cfg)


def run(source, index, chosen, tb, cfg):
    out_path = os.path.join(cfg.out_dir, source.key + ".jsonl")
    start = time.time()
    analysed = 0
    with_blunders = 0
    blunders = 0
    reached = 0
    fresh_done = []

    handles = {}
    try:
        with io.open(out_path, "a", encoding="utf-8") as out:
            for n, i in enumerate(chosen, 1):
                file_id = index.file_id[i]
                if file_id not in handles:
                    handles[file_id] = io.open(
                        source.path(file_id), encoding="utf-8", errors="replace")
                f = handles[file_id]
                f.seek(index.offset[i])
                try:
                    game = chess.pgn.read_game(f)
                except Exception:
                    game = None
                if game is None:
                    continue

                analysed += 1
                record, got_there = analyse_game(game, tb, cfg)
                if got_there:
                    reached += 1
                if record is not None:
                    record["database"] = source.files[file_id]
                    with_blunders += 1
                    blunders += len(record["blunders"])
                    out.write(json.dumps(record, ensure_ascii=False) + "\n")
                fresh_done.append(i)

                if n % 200 == 0:
                    rate = n / (time.time() - start)
                    print("  {}/{}  partija sa greskama: {}  gresaka: {}  ({:.0f}/s)"
                          .format(n, len(chosen), with_blunders, blunders, rate),
                          flush=True)
    finally:
        for f in handles.values():
            f.close()
        append_done(cfg.out_dir, source, fresh_done)

    took = time.time() - start
    print("\nGotovo za {:.0f}s".format(took))
    print("  analizirano partija:   {}".format(analysed))
    print("  stiglo do tablica:     {} ({:.1f}%)".format(
        reached, 100.0 * reached / max(analysed, 1)))
    print("  sa bar jednom greskom: {}".format(with_blunders))
    print("  gresaka ukupno:        {}".format(blunders))
    print("  upisano u:             {}".format(out_path))
    if analysed:
        # The number to plan the next batch with: everything else here is
        # history, this is the rate.
        print("  prinos:                {:.1f} partija sa greskom na 1000"
              .format(1000.0 * with_blunders / analysed))
    print("")
    report_stats(out_path)


if __name__ == "__main__":
    main()
