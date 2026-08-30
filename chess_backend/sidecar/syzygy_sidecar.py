#!/usr/bin/env python3
"""syzygy_sidecar.py — local Syzygy tables, speaking Lichess's dialect.

Node has no Syzygy reader, which is why `tablebaseService.js` asks over the
network. This serves the same shape from tables on local disk, so the backend
needs one environment variable and no code change.

**It answers only what it can prove, and says so when it cannot.** A position
outside the tables, a missing table file, or a verdict the fifty-move rule could
overturn all come back as HTTP 404 with `covered: false`, and the caller falls
back to Lichess. That refusal is the whole design: the endgame feature's single
promise is that "you lost the win" is a fact rather than an opinion, and a
sidecar that guessed would break that promise more quietly than anything else in
this codebase could.

Run:

    python syzygy_sidecar.py --path /path/to/syzygy --port 7001

or set SYZYGY_PATH. It refuses to start when no tables are found — a sidecar
that runs and covers nothing is indistinguishable from one that is working, and
the backend would fall back to Lichess for every position while looking fine.

No third-party web framework on purpose: `python-chess` is already a dependency
of `puzzles/`, and the standard library serves one JSON route perfectly well.
"""

import argparse
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

import chess
import chess.syzygy

# Lichess's five words for an outcome, keyed by python-chess's WDL value. These
# are exactly the five `tablebaseService.js` accepts; anything else it treats as
# a position nobody judged, which is what we must never fabricate.
WDL_WORDS = {
    2: "win",
    1: "cursed-win",
    0: "draw",
    -1: "blessed-loss",
    -2: "loss",
}

# The tables have nothing to say about castling: Syzygy positions assume the
# right is gone. Rare this deep into a game, and declined rather than guessed.
UNCOVERED = "uncovered"


class Tables:
    """The open tablebase, and the questions it will and will not answer.

    `python-chess` is not documented as thread-safe for concurrent probes, and
    ThreadingHTTPServer will hand us concurrent requests, so every probe takes
    the lock. Probes are microseconds against a memory-mapped file; the lock is
    not the cost, the disk is.
    """

    def __init__(self, paths, max_men):
        # More than one directory because a full set is usually stored split —
        # 3-4-5 is under a gigabyte and 6 is a hundred and fifty, so they rarely
        # live on the same disk, let alone in the same folder.
        self._tb = chess.syzygy.open_tablebase(paths[0])
        for extra in paths[1:]:
            self._tb.add_directory(extra)
        self._lock = threading.Lock()
        self.paths = paths
        self.max_men = max_men

    def probe(self, board):
        """(wdl, dtz) or None when the tables will not commit.

        None means "ask somebody else", never "draw".
        """
        if board.castling_rights:
            return None
        if chess.popcount(board.occupied) > self.max_men:
            return None
        with self._lock:
            try:
                wdl = self._tb.probe_wdl(board)
                dtz = self._tb.probe_dtz(board)
            except (KeyError, chess.syzygy.MissingTableError, ValueError):
                # A table we do not have on disk. Declining is the only honest
                # answer; returning a draw here would be a fabricated fact.
                return None
        if wdl not in WDL_WORDS:
            return None
        return wdl, dtz


def fifty_move_safe(board, wdl, dtz):
    """Whether the halfmove clock can be ignored for this verdict.

    Syzygy's WDL already encodes `cursed-win` and `blessed-loss` — wins that the
    fifty-move rule takes away when counted from a zeroed clock. What it does
    not know is the clock this particular position actually carries. Lichess
    does, and answers `maybe-win` / `maybe-loss` when the two interact.

    Rather than reimplement that and risk two different verdicts for one FEN
    depending on which server answered, this declines whenever the clock could
    plausibly change the outcome. A drawn position is never at risk; a decisive
    one is safe only if it finishes inside the remaining moves.
    """
    if wdl == 0:
        return True
    if dtz is None:
        return False
    return board.halfmove_clock + abs(dtz) <= 100


def describe(tables, board):
    """The Lichess-shaped answer for one position, or None to decline."""
    # Terminal positions first: the tables are not consulted and do not need to
    # be. Lichess reports these the same way.
    if board.is_checkmate():
        return {
            "category": "loss", "dtz": 0, "checkmate": True, "stalemate": False,
            "insufficient_material": board.is_insufficient_material(), "moves": [],
        }
    if board.is_stalemate() or board.is_insufficient_material():
        return {
            "category": "draw", "dtz": 0, "checkmate": False,
            "stalemate": board.is_stalemate(),
            "insufficient_material": board.is_insufficient_material(), "moves": [],
        }

    here = tables.probe(board)
    if here is None or not fifty_move_safe(board, here[0], here[1]):
        return None
    wdl, dtz = here

    # Every legal move, each carrying the verdict for whoever moves next — which
    # is the opponent, and is exactly how Lichess reports it. One position
    # therefore answers a whole node, which is what makes a drill one request
    # per move rather than one per candidate.
    moves = []
    for move in board.legal_moves:
        san = board.san(move)
        zeroing = board.is_zeroing(move)
        board.push(move)
        try:
            if board.is_checkmate():
                child = (-2, 0)
            elif board.is_stalemate() or board.is_insufficient_material():
                child = (0, 0)
            else:
                probed = tables.probe(board)
                if probed is None or not fifty_move_safe(board, probed[0], probed[1]):
                    # One unjudgeable reply makes the whole node unjudgeable:
                    # `bestReply` in tablebaseService reads every move, so a
                    # partial answer would break there rather than here.
                    return None
                child = probed
        finally:
            board.pop()
        moves.append({
            "uci": move.uci(),
            "san": san,
            "category": WDL_WORDS[child[0]],
            "dtz": child[1],
            "zeroing": zeroing,
        })

    return {
        "category": WDL_WORDS[wdl],
        "dtz": dtz,
        "checkmate": False,
        "stalemate": False,
        "insufficient_material": False,
        "moves": moves,
    }


class Handler(BaseHTTPRequestHandler):
    tables = None
    served = 0
    declined = 0

    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        # One line per probe would drown the console during an audit that walks
        # thousands of positions. /health reports the counts instead.
        pass

    def _json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            return self._json(200, {
                "ok": True,
                "maxMen": Handler.tables.max_men,
                "served": Handler.served,
                "declined": Handler.declined,
            })

        if parsed.path not in ("/standard", "/"):
            return self._json(404, {"error": "not found"})

        fen = (parse_qs(parsed.query).get("fen") or [""])[0].strip()
        if not fen:
            return self._json(400, {"error": "fen is required"})

        try:
            board = chess.Board(fen.replace("_", " "))
        except ValueError as exc:
            return self._json(400, {"error": "bad fen: %s" % exc})

        answer = describe(Handler.tables, board)
        if answer is None:
            Handler.declined += 1
            # 404 rather than a body saying "unknown". The caller must be able
            # to tell "I cannot answer this" from "I answered, and the answer is
            # that nobody knows" — they lead to different places.
            return self._json(404, {"covered": False, "reason": UNCOVERED})

        Handler.served += 1
        return self._json(200, answer)


def count_tables(path):
    return sum(1 for name in os.listdir(path) if name.endswith(".rtbw"))


def max_men_in(path):
    """The largest table present, read from the file names.

    Reported rather than assumed, because a directory holding only 3-4-5 and one
    holding 3-4-5-6 behave very differently and nothing else would say which
    this is.
    """
    best = 0
    for name in os.listdir(path):
        if not name.endswith(".rtbw"):
            continue
        stem = name[:-5]
        men = sum(1 for ch in stem if ch.isalpha() and ch != "v")
        best = max(best, men)
    return best


def main():
    ap = argparse.ArgumentParser(description="Local Syzygy tables over HTTP.")
    # Repeatable, and also accepts one os.pathsep-separated value so SYZYGY_PATH
    # can name a split set the way PATH names one.
    ap.add_argument("--path", action="append", default=None)
    ap.add_argument("--port", type=int,
                    default=int(os.environ.get("SYZYGY_SIDECAR_PORT", "7001")))
    # Loopback by default. These tables answer anybody who can reach the port,
    # and there is no reason for that to be the network.
    ap.add_argument("--host", default="127.0.0.1")
    args = ap.parse_args()

    raw = args.path or [p for p in (os.environ.get("SYZYGY_PATH") or "").split(os.pathsep) if p]
    if not raw:
        sys.exit("Prosledite --path (može više puta) ili postavite SYZYGY_PATH.")

    paths = []
    for p in raw:
        if not os.path.isdir(p):
            sys.exit("Nema direktorijuma sa tablicama: %s" % p)
        paths.append(p)

    tables = sum(count_tables(p) for p in paths)
    if tables == 0:
        # Loud, on purpose. A sidecar that starts and covers nothing looks
        # exactly like one that is working: the backend falls back to Lichess
        # for every position and reports success the whole time.
        sys.exit("U %s nema nijedne .rtbw tablice — odbijam da startujem."
                 % os.pathsep.join(paths))

    men = max(max_men_in(p) for p in paths)
    Handler.tables = Tables(paths, men)

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print("Syzygy sidecar: %d tablica, do %d figura, na http://%s:%d/standard"
          % (tables, men, args.host, args.port), flush=True)
    print("Pozicije koje ne pokriva vraća kao 404 — pozivalac pita Lichess.",
          flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nZaustavljeno.", flush=True)


if __name__ == "__main__":
    main()
