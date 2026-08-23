"""Ask what is wanted of each endgame type, then mine it.

The runner script carried one target for everything, which is the wrong shape:
pawn endings and opposite-coloured bishops are not needed in equal numbers, and
what is worth asking for depends on how much of the collection a type has
already been through. So this shows the state first - found so far, share of the
games looked at, what the yield so far suggests is left - and asks per type.

Raising a number later is the normal case, not a special one. The miner records
which games each type has visited, so a second session with a bigger number
picks up games that type has never seen rather than redoing the ones it has.
"""

import glob
import json
import os
import subprocess
import sys

import chess.pgn

MINER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "endgame_miner.py")
BASE_DIR = os.environ.get("CHESS_BASE_DIR", r"D:\chess_base")
OUT_DIR = os.path.join(BASE_DIR, "_mining")
# Both sets, joined the way SyzygyPath wants them. Six-piece endings are then
# judged from the tables instead of estimated by the engine.
SYZYGY = os.environ.get("SYZYGY_PATH",
                        os.pathsep.join((r"D:\syzygy\3-4-5", r"D:\syzygy\6")))

TYPES = [
    "PawnEnding",
    "RookPawnVsRook",
    "QueenVsRook",
    "BishopVsKnight",
    "RookBishopVsRook",
    "OppositeBishops",
    "DoubleBishopVsBishopKnight",
]


def count_games(pgn_path):
    total = 0
    with open(pgn_path, "r", encoding="utf-8", errors="replace") as f:
        while chess.pgn.skip_game(f):
            total += 1
    return total


def load(path, default):
    if not os.path.exists(path):
        return default
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def state_of(type_name, sizes, total_games):
    """(found, games seen, estimate of what is left) for one type."""
    out = os.path.join(OUT_DIR, type_name + ".json")
    found = len(load(out, []))
    visited = load(out + ".visited", {})
    seen = sum(len(v) for v in visited.values())
    # A database finished before .visited existed counts as fully seen.
    for db in load(out + ".done", []):
        if db not in visited:
            seen += sizes.get(db, 0)
    left_games = max(0, total_games - seen)
    rate = found / seen if seen else 0
    return found, seen, left_games, int(left_games * rate)


def ask_target(type_name, found, seen, total_games, left_games, estimate):
    share = seen / total_games * 100 if total_games else 0
    print("\n{}".format(type_name))
    print("  nadjeno do sada:   {}".format(found))
    print("  pregledano partija: {} od {} ({:.1f}%)".format(seen, total_games, share))
    if left_games == 0:
        print("  zbirka je za ovaj tip iscrpljena")
    else:
        print("  neobidjeno:        {} partija, po dosadasnjem prinosu jos oko {}"
              .format(left_games, estimate))
    while True:
        answer = input("  koliko ukupno zelite? (Enter = preskoci): ").strip()
        if not answer:
            return None
        if answer.isdigit() and int(answer) > 0:
            wanted = int(answer)
            if wanted <= found:
                print("  vec ima {} - unesite veci broj ili Enter za preskok"
                      .format(found))
                continue
            return wanted
        print("  unesite ceo broj veci od nule, ili Enter")


def main():
    if not os.path.isfile(MINER):
        sys.exit("Nema rudara: " + MINER)
    if not os.path.isdir(BASE_DIR):
        sys.exit("Nema foldera sa bazama: " + BASE_DIR)
    os.makedirs(OUT_DIR, exist_ok=True)

    print("Brojim partije po bazama...", flush=True)
    sizes = {}
    for path in sorted(glob.glob(os.path.join(BASE_DIR, "*.pgn"))):
        sizes[os.path.basename(path)] = count_games(path)
    total_games = sum(sizes.values())
    print("{} partija u {} baza".format(total_games, len(sizes)))

    plan = []
    for type_name in TYPES:
        found, seen, left_games, estimate = state_of(type_name, sizes, total_games)
        if left_games == 0 and found:
            print("\n{}\n  iscrpljeno, {} pozicija".format(type_name, found))
            continue
        wanted = ask_target(type_name, found, seen, total_games,
                            left_games, estimate)
        if wanted:
            plan.append((type_name, wanted))

    if not plan:
        print("\nNista nije izabrano.")
        return

    print("\n--- PLAN ---")
    for type_name, wanted in plan:
        print("  {:<28} do {}".format(type_name, wanted))
    if input("\nPokrenuti? (da/ne): ").strip().lower() not in ("da", "d", "y", "yes"):
        print("Otkazano.")
        return

    for type_name, wanted in plan:
        print("\n" + "#" * 60)
        print("# {} : cilj {}".format(type_name, wanted))
        print("#" * 60, flush=True)
        command = [sys.executable, MINER, "--type", type_name, "--mode", "any",
                   "--target", str(wanted),
                   "--out", os.path.join(OUT_DIR, type_name + ".json")]
        # A folder that is not there is named out loud. Dropping it silently
        # would move a whole run onto the engine without saying so.
        folders = [d for d in SYZYGY.split(os.pathsep) if d]
        for gone in [d for d in folders if not os.path.isdir(d)]:
            print("Nema Syzygy foldera, preskacem ga: " + gone)
        present = [d for d in folders if os.path.isdir(d)]
        if present:
            command += ["--syzygy", os.pathsep.join(present)]
        code = subprocess.call(command)
        if code != 0:
            sys.exit("\n{} nije uspeo (izlazni kod {}). Prekidam.".format(
                type_name, code))

    print("\n--- REZULTAT ---")
    for type_name, wanted in plan:
        found, seen, left_games, estimate = state_of(type_name, sizes, total_games)
        share = seen / total_games * 100 if total_games else 0
        note = "cilj dostignut" if found >= wanted else "zbirka iscrpljena"
        print("{:<28} {:5} pozicija (trazeno {}), pregledano {:.1f}% partija - {}"
              .format(type_name, found, wanted, share, note))


if __name__ == "__main__":
    main()
