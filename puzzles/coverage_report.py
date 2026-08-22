"""How much of each PGN database each endgame type has been through.

Reads the <Type>.json.visited sidecars the miner keeps and prints a database by
type matrix. The point is to answer one question before raising a target: is a
thin harvest a sign that the material is exhausted, or only that the run stopped
early? A type sitting at 12% of a database has plenty left; one at 100% has not.
"""

import argparse
import glob
import json
import os
import sys

import chess.pgn


def count_games(pgn_path):
    total = 0
    with open(pgn_path, "r", encoding="utf-8", errors="replace") as f:
        while chess.pgn.skip_game(f):
            total += 1
    return total


def main():
    p = argparse.ArgumentParser(description="Pokrivenost po bazi i po tipu zavrsnice.")
    p.add_argument("--dir", default=r"D:\chess_base\_mining")
    p.add_argument("--base-dir", default=r"D:\chess_base")
    cfg = p.parse_args()

    if not os.path.isdir(cfg.dir):
        sys.exit("Folder ne postoji: " + cfg.dir)

    visited = {}
    for path in sorted(glob.glob(os.path.join(cfg.dir, "*.json.done"))):
        type_name = os.path.basename(path)[:-len(".json.done")]
        visited.setdefault(type_name, {})
    for path in sorted(glob.glob(os.path.join(cfg.dir, "*.json.visited"))):
        type_name = os.path.basename(path)[:-len(".json.visited")]
        with open(path, "r", encoding="utf-8") as f:
            visited.setdefault(type_name, {}).update(
                {db: len(v) for db, v in json.load(f).items()})
    if not visited:
        sys.exit("Nema zabelezenog rudarenja u {}.".format(cfg.dir))

    counts = {}
    for name in sorted(os.path.basename(p) for p in
                       glob.glob(os.path.join(cfg.base_dir, "*.pgn"))):
        counts[name] = count_games(os.path.join(cfg.base_dir, name))

    # A database finished before .visited existed has no indices recorded, but
    # .done says it was swept whole. Counting it as zero would read as "plenty
    # of material left here" when there is none - the opposite of what this
    # report is for.
    for type_name in list(visited):
        done_path = os.path.join(cfg.dir, type_name + ".json.done")
        if not os.path.exists(done_path):
            continue
        with open(done_path, "r", encoding="utf-8") as f:
            for db in json.load(f):
                visited[type_name][db] = count_games(
                    os.path.join(cfg.base_dir, db))

    types = sorted(visited)
    found = {}
    for type_name in types:
        json_path = os.path.join(cfg.dir, type_name + ".json")
        if os.path.exists(json_path):
            with open(json_path, "r", encoding="utf-8") as f:
                found[type_name] = len(json.load(f))
        else:
            found[type_name] = 0

    width = max(len(n) for n in counts) + 2
    header = "{:<{w}}{:>8}".format("baza", "partija", w=width)
    for type_name in types:
        header += "{:>13}".format(type_name[:12])
    print(header)
    print("-" * len(header))

    totals = {t: 0 for t in types}
    grand = 0
    for db, size in counts.items():
        grand += size
        row = "{:<{w}}{:>8}".format(db, size, w=width)
        for type_name in types:
            been = visited[type_name].get(db, 0)
            totals[type_name] += been
            row += "{:>12.1f}%".format(been / max(1, size) * 100)
        print(row)

    print("-" * len(header))
    row = "{:<{w}}{:>8}".format("UKUPNO", grand, w=width)
    for type_name in types:
        row += "{:>12.1f}%".format(totals[type_name] / max(1, grand) * 100)
    print(row)
    row = "{:<{w}}{:>8}".format("nadjeno pozicija", "", w=width)
    for type_name in types:
        row += "{:>13}".format(found[type_name])
    print(row)

    print("\nPreostalo neobidjeno:")
    for type_name in types:
        left = grand - totals[type_name]
        if left <= 0:
            print("  {:<28} iscrpljeno".format(type_name))
            continue
        # Straight-line estimate. Yield is not uniform across a collection, so
        # this says "about", not "exactly".
        rate = found[type_name] / max(1, totals[type_name])
        print("  {:<28} jos {:6} partija, po dosadasnjem prinosu jos oko {} pozicija"
              .format(type_name, left, int(left * rate)))


if __name__ == "__main__":
    main()
