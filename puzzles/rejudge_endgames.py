# -*- coding: utf-8 -*-
"""Re-judge mined endgames that the engine only estimated.

Positions with six pieces or fewer are settled by the local tables, seven by the
Lichess tablebase API. Everything from eight up stays exactly as the engine left
it and is not touched.

The verdict is not re-implemented here. `evaluate_with_tablebase` from the miner
is called unchanged, so a position re-judged today is accepted on exactly the
criterion that accepted the rest of the collection; the only thing that differs
is which object answers `get_wdl`. That also means a position can now be
*rejected* - the engine's cliff and the tables' outcome grouping are not the
same question, and where they disagree the tables are right.

Dry run by default. Nothing is written until --apply, and nothing is ever
deleted from disk: rejected positions are dropped from the rewritten file and
listed on screen, and the file before it is left beside it as .bak.

Usage:
    python rejudge_endgames.py                  # report only
    python rejudge_endgames.py --apply          # rewrite the JSON files
"""
import argparse
import io
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter

import chess

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import endgame_miner as miner

LICHESS_URL = "https://tablebase.lichess.ovh/standard"

# The service's words for the same five outcomes the tables carry. Anything
# outside this map - "unknown", "maybe-win", "maybe-loss" - is a position the
# service will not commit to, and guessing on its behalf is the one thing this
# whole tool exists to stop.
CATEGORY_WDL = {
    "win": 2,
    "cursed-win": 1,
    "draw": 0,
    "blessed-loss": -1,
    "loss": -2,
}


class LichessTablebase:
    """The seven-piece half of the judge, over the network.

    One request answers a whole position: the response carries a category for
    every legal move, read from the point of view of whoever is to move after
    it - the same convention `tablebase_results` already uses. So each response
    also fills the cache for every child, and a run costs one request per node
    visited rather than one per move considered.
    """

    def __init__(self, delay=0.5, timeout=20.0, retries=3):
        self.delay = delay
        self.timeout = timeout
        self.retries = retries
        self.outcome = {}
        self.primed = set()
        self.requests = 0
        self.last_call = 0.0

    def _get(self, fen):
        url = LICHESS_URL + "?" + urllib.parse.urlencode({"fen": fen})
        wait = self.delay - (time.time() - self.last_call)
        if wait > 0:
            time.sleep(wait)
        last_error = None
        for attempt in range(self.retries):
            try:
                request = urllib.request.Request(
                    url, headers={"User-Agent": "chess-coach endgame rejudge"})
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    body = response.read().decode("utf-8")
                self.last_call = time.time()
                self.requests += 1
                return json.loads(body)
            except (urllib.error.URLError, ValueError) as exc:
                last_error = exc
                time.sleep(2.0 * (attempt + 1))
        # Loud, and it takes the run with it. A network hiccup that silently
        # left a position judged by the engine would be indistinguishable in
        # the output from one the tables agreed with.
        sys.exit("Lichess API ne odgovara posle {} pokusaja: {}\n  FEN: {}".format(
            self.retries, last_error, fen))

    def _load(self, board):
        """One request: this position's outcome, and every child's with it."""
        fen = board.fen()
        data = self._get(fen)
        self.outcome[fen] = {"category": data.get("category"),
                             "dtz": data.get("dtz")}
        for entry in data.get("moves", []):
            move = chess.Move.from_uci(entry["uci"])
            board.push(move)
            try:
                self.outcome.setdefault(board.fen(), {
                    "category": entry.get("category"),
                    "dtz": entry.get("dtz"),
                })
            finally:
                board.pop()
        self.primed.add(fen)

    def prime(self, board):
        """Make sure this position's children are in hand before they are asked
        for one by one. `tablebase_results` calls it; see the note there.

        Knowing a position's own outcome is not the same as having its children
        - a child learned from its parent's response carries a verdict and no
        move list - so the two are tracked separately. Conflating them would
        quietly put the traffic back where it was.
        """
        if board.fen() not in self.primed:
            self._load(board)

    def _entry(self, board):
        fen = board.fen()
        if fen not in self.outcome:
            self._load(board)
        return self.outcome[fen]

    def get_wdl(self, board):
        category = self._entry(board).get("category")
        if category not in CATEGORY_WDL:
            sys.exit("Lichess API: kategorija '{}' nije ishod.\n  FEN: {}".format(
                category, board.fen()))
        return CATEGORY_WDL[category]

    def get_dtz(self, board):
        return self._entry(board).get("dtz")

    def close(self):
        pass


class HybridTablebase:
    """Local tables up to `max_local` pieces, the API above it.

    The boundary is crossed inside a single position: a seven-piece ending whose
    solution line starts with a capture is six pieces one ply later, and from
    there the local tables answer. Routing per position rather than once per
    puzzle is what makes that work.
    """

    def __init__(self, local, api, max_local):
        self.local = local
        self.api = api
        self.max_local = max_local

    def _pick(self, board):
        if len(board.piece_map()) <= self.max_local:
            return self.local
        return self.api

    def prime(self, board):
        source = self._pick(board)
        primer = getattr(source, "prime", None)
        if primer is not None:
            primer(board)

    def get_wdl(self, board):
        source = self._pick(board)
        # None here reaches probe_wdl, which stops the run and names the
        # position. That is deliberate: there is no third route.
        return source.get_wdl(board) if source is not None else None

    def get_dtz(self, board):
        source = self._pick(board)
        return source.get_dtz(board) if source is not None else None

    def close(self):
        for source in (self.local, self.api):
            if source is not None:
                source.close()


class Tally:
    """Stands in for the miner's Shared, which carries a whole run's state."""

    def __init__(self):
        self.counts = Counter()

    def bump(self, name):
        self.counts[name] += 1


def piece_count(fen):
    return sum(1 for c in fen.split(" ")[0] if c.isalpha())


def build_config(args):
    """The miner's own defaults, so the criterion cannot drift apart."""
    cfg = miner.build_parser().parse_args([])
    cfg.syzygy = args.syzygy
    cfg.stockfish = args.stockfish
    cfg.mode = "any"
    # The line walk stops when a position outgrows this, so it has to name the
    # far edge of the judge, not the local half of it.
    cfg.syzygy_max_pieces = args.max_pieces
    # Re-judging settles the outcome. It does not get to re-open whether a
    # position is too easy, for two reasons. The position already passed that
    # test when it was mined; and the test is not reproducible - the same file
    # rejected three positions run on its own and one run after five hundred
    # others, because the shallow engine carries its transposition table from
    # one position to the next. Deleting material on a verdict that depends on
    # what was analysed before it would be the worst kind of loss: quiet, and
    # different every time. Measured over the whole collection, every single
    # rejection came from this test and not one from a disagreement about the
    # outcome, so switching it off costs nothing and saves 252 positions.
    cfg.reject_obvious = False
    return cfg


def rejudge_file(path, engines, tb, cfg, args):
    with io.open(path, encoding="utf-8") as f:
        records = json.load(f)

    kept, dropped, changed, untouched = [], [], [], 0
    tally = Tally()

    for record in records:
        pieces = piece_count(record["fen"])
        if pieces > args.max_pieces:
            kept.append(record)
            untouched += 1
            continue

        board = chess.Board(record["fen"])
        before = Counter(tally.counts)
        verdict = miner.evaluate_with_tablebase(
            board, engines, tb, record["type"], cfg, tally)

        if verdict is None:
            reason = [k for k, v in (tally.counts - before).items()
                      if k != "iz_tablica"]
            dropped.append((record, reason[0] if reason else "nepoznato", pieces))
            continue

        merged = dict(record)
        merged.update(verdict)
        merged["source"] = "syzygy" if pieces <= args.local_max_pieces else "lichess"
        # The move list is a set; serialising it in whatever order the frozenset
        # iterated makes every re-import look like a change. Sorted, it matches
        # winning_moves_san and the hint that shows winningMoves.first stops
        # depending on the run that wrote the file.
        merged["winning_moves"] = sorted(verdict["winning_moves"])
        # These belong to the engine's answer and would now be describing a
        # verdict they had no part in.
        for stale in ("eval", "cliff", "depth", "verified_depth"):
            merged.pop(stale, None)

        was = set(record.get("winning_moves") or [])
        now = set(verdict["winning_moves"])

        # Difficulty leans on shallow_best, which comes from the same shallow
        # search whose verdict is not reproducible - so recomputing it for a
        # position whose outcome did not move replaces a score with an equally
        # arbitrary one. Where the verdict is unchanged, so is the rating.
        if was == now and record.get("source") == merged["source"] \
                and record.get("difficulty") is not None:
            merged["difficulty"] = record["difficulty"]
        if was != now or record.get("mode") != verdict["mode"]:
            changed.append((record, merged, pieces))
        kept.append(merged)

    # Rewrite whenever anything was re-judged, not only when a verdict moved.
    # A position whose outcome the tables confirm still stops being an estimate:
    # its source becomes the table or the API, and the engine's eval, cliff and
    # depth go, because they describe an answer they had no part in.
    if args.apply and (len(kept) - untouched or dropped):
        shutil.copy2(path, path + ".bak")
        with io.open(path, "w", encoding="utf-8") as f:
            # Same shape the miner writes, so the next mining run does not
            # reformat the whole file on its first save.
            json.dump(kept, f, indent=4, ensure_ascii=False)

    return kept, changed, dropped, untouched, tally


def main():
    p = argparse.ArgumentParser(
        description="Ponovno sudjenje zavrsnica iz tablica i sa Lichess API-ja.")
    p.add_argument("--in", dest="indir",
                   default=os.path.join(miner.DEFAULT_BASE_DIR, "_mining"),
                   help="Folder ili jedan .json fajl")
    p.add_argument("--syzygy", default=os.environ.get("SYZYGY_PATH"),
                   help="Folder(i) sa tablicama, razdvojeni znakom '{}'".format(
                       os.pathsep))
    p.add_argument("--stockfish", default=miner.DEFAULT_STOCKFISH)
    p.add_argument("--local-max-pieces", type=int, default=6,
                   help="Do koliko figura sudi lokalna tablica")
    p.add_argument("--max-pieces", type=int, default=7,
                   help="Do koliko figura se uopste sudi; iznad ostaje motor")
    p.add_argument("--delay", type=float, default=0.5,
                   help="Sekundi izmedju zahteva ka Lichess-u")
    p.add_argument("--apply", action="store_true",
                   help="Upisi izmene; bez ovoga se samo izvestava")
    args = p.parse_args()

    if not args.syzygy:
        sys.exit("Prosledite --syzygy ili postavite SYZYGY_PATH.")

    cfg = build_config(args)
    local = miner.open_tablebase(args.syzygy)
    miner.check_tablebase_coverage(local, type("C", (), {
        "syzygy_max_pieces": args.local_max_pieces, "syzygy": args.syzygy})())

    api = LichessTablebase(delay=args.delay) if args.max_pieces > args.local_max_pieces else None
    tb = HybridTablebase(local, api, args.local_max_pieces)
    engines = miner.EnginePair(cfg)

    if os.path.isdir(args.indir):
        paths = [os.path.join(args.indir, n) for n in sorted(os.listdir(args.indir))
                 if n.endswith(".json")]
    else:
        paths = [args.indir]
    if not paths:
        sys.exit("Nema .json fajlova u " + args.indir)

    print("Sudi: do {} figura lokalno, {} preko Lichess API-ja, iznad ostaje motor".format(
        args.local_max_pieces, args.max_pieces))
    print("Rezim: {}\n".format("UPIS" if args.apply else "samo izvestaj"))

    totals = Counter()
    try:
        for path in paths:
            kept, changed, dropped, untouched, tally = rejudge_file(
                path, engines, tb, cfg, args)
            name = os.path.basename(path)
            touched = len(kept) - untouched + len(dropped)
            if not touched:
                print("{:<32} nema pozicija do {} figura".format(name, args.max_pieces))
                continue
            print("{:<32} presudjeno {:>4} | potvrdjeno {:>4} | promenjeno {:>3} | ispalo {:>3}".format(
                name, touched, touched - len(changed) - len(dropped),
                len(changed), len(dropped)))
            for record, merged, pieces in changed:
                print("   {} figura  {}".format(pieces, record["fen"]))
                print("      bilo: {} ({})".format(
                    ", ".join(record.get("winning_moves_san") or []), record.get("mode")))
                print("      sada: {} ({})".format(
                    ", ".join(merged["winning_moves_san"]), merged["mode"]))
            for record, reason, pieces in dropped:
                print("   ISPADA {} figura  {}  [{}]".format(
                    pieces, record["fen"], reason))
            totals["presudjeno"] += touched
            totals["promenjeno"] += len(changed)
            totals["ispalo"] += len(dropped)
    finally:
        engines.quit()
        tb.close()

    print("\nUkupno: presudjeno {}, promenjeno {}, ispalo {}".format(
        totals["presudjeno"], totals["promenjeno"], totals["ispalo"]))
    if api is not None:
        print("Zahteva ka Lichess-u: {}".format(api.requests))
    if not args.apply and (totals["promenjeno"] or totals["ispalo"]):
        print("\nNista nije upisano. Ponovite sa --apply.")


if __name__ == "__main__":
    main()
