"""Clean duplicates out of already-mined endgame files, and seed the game index.

Two jobs, both retroactive fixes for the same oversight in endgame_miner.py:
it deduplicated on the full FEN and never noticed it had seen a game before.

  1. Drop positions that are the same exercise. The old key was the whole FEN,
     which includes the halfmove and fullmove counters, so the same board
     arriving from a different game at a different move number was kept twice.

  2. Build the <out>.games index the miner now keeps, by re-reading the PGN
     databases each type has already finished. Without this seed, a resumed run
     would happily re-analyse every game in the finished databases the moment a
     later database repeated one.

Run with --apply to write. Without it, it only reports.
"""

import argparse
import glob
import hashlib
import json
import os
import sys
from collections import Counter, defaultdict

import chess
import chess.pgn

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from endgame_miner import forced_mate_within


def position_key(fen):
    return " ".join(fen.split()[:4])


def game_fingerprint(moves):
    return hashlib.blake2b(
        " ".join(m.uci() for m in moves).encode("ascii"), digest_size=8).hexdigest()


def game_identity(entry):
    return (entry.get("white"), entry.get("black"),
            entry.get("date"), entry.get("result"))


def dedupe(entries, per_game, max_pieces, mate_in):
    """Keep the first of each position, and at most `per_game` from one game.

    Also drops what the miner now rejects but did not when these files were
    written: positions too crowded to be an endgame, and positions with a
    forced mate, which belong in the mate database rather than here.
    """
    kept, seen_positions, per_game_count = [], set(), Counter()
    dropped = Counter()
    for entry in entries:
        board = chess.Board(entry["fen"])
        if max_pieces and len(board.piece_map()) > max_pieces:
            dropped["pretrpana_pozicija"] += 1
            continue
        if mate_in and forced_mate_within(board, mate_in):
            dropped["forsiran_mat"] += 1
            continue
        key = position_key(entry["fen"])
        if key in seen_positions:
            dropped["ista_pozicija"] += 1
            continue
        identity = game_identity(entry)
        if per_game_count[identity] >= per_game:
            dropped["previse_iz_iste_partije"] += 1
            continue
        seen_positions.add(key)
        per_game_count[identity] += 1
        kept.append(entry)
    return kept, dropped


def fingerprints_of(pgn_path):
    prints = set()
    with open(pgn_path, "r", encoding="utf-8", errors="replace") as f:
        while True:
            game = chess.pgn.read_game(f)
            if game is None:
                break
            prints.add(game_fingerprint(list(game.mainline_moves())))
    return prints


def main():
    p = argparse.ArgumentParser(description="Ciscenje duplikata iz izrudarenih fajlova.")
    p.add_argument("--dir", default=r"D:\chess_base\_mining")
    p.add_argument("--base-dir", default=r"D:\chess_base")
    p.add_argument("--per-game", type=int, default=2)
    p.add_argument("--max-pieces", type=int, default=16,
                   help="Izbaci pozicije sa vise figura; 0 = ne diraj")
    p.add_argument("--reject-mate-in", type=int, default=2,
                   help="Izbaci pozicije sa forsiranim matom; 0 = ne diraj")
    p.add_argument("--apply", action="store_true", help="Bez ovoga samo izvestava")
    cfg = p.parse_args()

    if not os.path.isdir(cfg.dir):
        sys.exit("Folder ne postoji: " + cfg.dir)

    files = sorted(glob.glob(os.path.join(cfg.dir, "*.json")))
    if not files:
        sys.exit("Nema JSON fajlova u " + cfg.dir)

    for path in files:
        name = os.path.basename(path)
        with open(path, "r", encoding="utf-8") as f:
            entries = json.load(f)
        kept, dropped = dedupe(entries, cfg.per_game, cfg.max_pieces, cfg.reject_mate_in)

        detail = ", ".join("{} {}".format(v, k) for k, v in dropped.most_common()) or "nista"
        print("{:<34} {:5} -> {:5}   ({})".format(name, len(entries), len(kept), detail))

        if cfg.apply and len(kept) != len(entries):
            with open(path, "w", encoding="utf-8") as f:
                json.dump(kept, f, indent=4, ensure_ascii=False)

        # Seed the game index from the databases this type already finished.
        done_path = path + ".done"
        if not os.path.exists(done_path):
            continue
        with open(done_path, "r", encoding="utf-8") as f:
            done = json.load(f)
        prints = set()
        for db in done:
            pgn_path = os.path.join(cfg.base_dir, db)
            if not os.path.exists(pgn_path):
                sys.exit("Baza iz .done ne postoji: " + pgn_path)
            prints |= fingerprints_of(pgn_path)
        print("{:<34} partija u indeksu iz {} obradjenih baza: {}".format(
            "", len(done), len(prints)))
        if cfg.apply:
            with open(path + ".games", "w", encoding="utf-8") as f:
                json.dump(sorted(prints), f)

    if not cfg.apply:
        print("\nProbni prolaz. Dodajte --apply da se izmene upisu.")


if __name__ == "__main__":
    main()
