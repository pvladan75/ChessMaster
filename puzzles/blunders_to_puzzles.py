# -*- coding: utf-8 -*-
"""Turn detected blunders into positions the endgame trainer can serve.

The two halves of the collection are gathered differently and it shows. A mined
position earned its place by measurement - a small group of moves reaches the
result and everything else falls away. A blunder position earned it by evidence:
somebody sat in front of it in a real game and got it wrong. The second is the
stronger credential, and the numbers say so - 97.8% of these pass the miner's
own cheap filters, against 93.5% of the candidates the miner itself saw.

Two filters are still worth keeping, for reasons the miner learned the hard way:

  - at most three moves may hold the result. A position where fifteen moves hold
    is not a puzzle; it is a position where nearly anything works and the player
    found the one thing that did not. About a fifth of blunders are like that.
  - no piece hanging, and no forced mate in two. Those are tactics, and this
    project keeps tactics in their own database.

Difficulty comes from the rating of the player who erred, not from a search.
That is free, it is reproducible, and it says something a heuristic cannot: a
position a 2500 missed is harder than one a 1700 missed. The mined score leans
on a shallow search whose verdict turned out to depend on what ran before it.

Usage:
    python blunders_to_puzzles.py                 # everything found so far
    python blunders_to_puzzles.py --max-holding 1 # only the sharpest
"""

import argparse
import io
import json
import os
import sys

import chess
import chess.syzygy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from endgame_miner import wins_material_outright, forced_mate_within  # noqa: E402

DEFAULT_BASE_DIR = os.environ.get("CHESS_BASE_DIR", r"D:\chess_base")
DEFAULT_IN_DIR = os.path.join(DEFAULT_BASE_DIR, "_blunders")
DEFAULT_OUT_DIR = os.path.join(DEFAULT_BASE_DIR, "_blunder_puzzles")

# Ten is the top of the miner's scale, so the two ladders line up in the same
# column. The bands are the ones a club player would recognise.
def difficulty_from_elo(elo):
    if not elo:
        return 5
    if elo < 1800:
        return 3
    if elo < 2000:
        return 4
    if elo < 2200:
        return 5
    if elo < 2400:
        return 6
    if elo < 2600:
        return 8
    return 9


def read_jsonl(path):
    with io.open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except ValueError:
                # The last line of a run that was interrupted mid-write.
                continue


def convert(record, entry, cfg, seen):
    holding = entry.get("should_play") or []
    if not 1 <= len(holding) <= cfg.max_holding:
        return None, "previse_poteza_drzi" if holding else "nema_poteza"

    fen = entry["fen"]
    key = " ".join(fen.split(" ")[:4])
    if key in seen:
        return None, "duplikat"
    seen.add(key)

    board = chess.Board(fen)
    if cfg.reject_hanging and wins_material_outright(board):
        return None, "figura_visi"
    if cfg.reject_mate_in and forced_mate_within(board, cfg.reject_mate_in):
        return None, "forsiran_mat"

    elo = record["white_elo"] if entry["side"] == "white" else record["black_elo"]

    # Normalised here rather than trusted from the file. calc_key writes white
    # first, so the same ending arrives under two names depending on which side
    # was stronger - KRPvKR and KRvKRP - and a lesson asking for one would get
    # half the material. Doing it here also repairs what earlier runs wrote.
    material = chess.syzygy.normalize_tablename(chess.syzygy.calc_key(board))

    return {
        "fen": fen,
        "source": "blunder",
        "mode": entry["outcome_before"],
        "type": material,
        "material": material,
        "blunder_elo": elo or None,
        "difficulty": difficulty_from_elo(elo),
        "winning_moves": entry.get("should_play_uci") or [],
        "winning_moves_san": sorted(holding),
        # What was played instead. Not a solution, but the thing that makes the
        # position worth showing, and the app can say "here is what happened".
        "played": entry.get("played"),
        "played_uci": entry.get("played_uci"),
        "outcome_after": entry.get("outcome_after"),
        "cause": entry.get("cause"),
        "white": record.get("white"),
        "black": record.get("black"),
        "date": record.get("date"),
        "database": record.get("database"),
    }, None


def build_parser():
    p = argparse.ArgumentParser(
        description="Pretvara nadjene greske u pozicije za trener zavrsnica.")
    p.add_argument("--in-dir", default=DEFAULT_IN_DIR)
    p.add_argument("--out-dir", default=DEFAULT_OUT_DIR)
    p.add_argument("--max-holding", type=int, default=3,
                   help="Najvise koliko poteza sme da drzi rezultat")
    p.add_argument("--min-elo", type=int, default=0,
                   help="Samo greske igraca sa bar toliko rejtinga")
    p.add_argument("--max-pieces", type=int, default=7)
    p.add_argument("--reject-hanging", action="store_true", default=True)
    p.add_argument("--keep-hanging", dest="reject_hanging", action="store_false")
    p.add_argument("--reject-mate-in", type=int, default=2)
    p.add_argument("--fifty-move", action="store_true",
                   help="Ukljuci i greske gde je samo istekao brojac")
    return p


def main():
    cfg = build_parser().parse_args()
    if not os.path.isdir(cfg.in_dir):
        sys.exit("Nema foldera sa greskama: " + cfg.in_dir)
    os.makedirs(cfg.out_dir, exist_ok=True)

    sources = sorted(f for f in os.listdir(cfg.in_dir) if f.endswith(".jsonl"))
    if not sources:
        sys.exit("Nema .jsonl fajlova u " + cfg.in_dir)

    for name in sources:
        seen = set()
        kept = []
        dropped = {}
        games = 0
        for record in read_jsonl(os.path.join(cfg.in_dir, name)):
            games += 1
            for entry in record.get("blunders") or []:
                if entry.get("pieces", 99) > cfg.max_pieces:
                    dropped["previse_figura"] = dropped.get("previse_figura", 0) + 1
                    continue
                if not cfg.fifty_move and entry.get("cause") == "fifty_move":
                    # A different lesson - "why did you have nothing left to
                    # spend" - and it reads as a puzzle without an answer.
                    dropped["istekao_brojac"] = dropped.get("istekao_brojac", 0) + 1
                    continue
                elo = (record["white_elo"] if entry["side"] == "white"
                       else record["black_elo"])
                if cfg.min_elo and (not elo or elo < cfg.min_elo):
                    dropped["nizak_rejting"] = dropped.get("nizak_rejting", 0) + 1
                    continue
                puzzle, why = convert(record, entry, cfg, seen)
                if puzzle is None:
                    dropped[why] = dropped.get(why, 0) + 1
                    continue
                kept.append(puzzle)

        stem = os.path.splitext(name)[0]
        out_path = os.path.join(cfg.out_dir, "Blunders_" + stem + ".json")
        with io.open(out_path, "w", encoding="utf-8") as f:
            json.dump(kept, f, indent=4, ensure_ascii=False)

        print("{}: {} partija -> {} pozicija".format(name, games, len(kept)))
        for why, count in sorted(dropped.items(), key=lambda kv: -kv[1]):
            print("    odbaceno {:<20} {}".format(why, count))
        by_mode = {}
        by_type = {}
        for puzzle in kept:
            by_mode[puzzle["mode"]] = by_mode.get(puzzle["mode"], 0) + 1
            by_type[puzzle["type"]] = by_type.get(puzzle["type"], 0) + 1
        print("    po zadatku: {}".format(by_mode))
        print("    tipova zavrsnica: {}".format(len(by_type)))
        print("    upisano u: {}".format(out_path))


if __name__ == "__main__":
    main()
