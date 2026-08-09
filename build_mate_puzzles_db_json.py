#!/usr/bin/env python3
"""
Dedicated Clean Mate Puzzles DB JSON Builder (1 - 4462)
======================================================
Extracts EXCLUSIVELY checkmate puzzles (diagrams 1 to 4462) from Polgar's dataset,
assigns correct targetMoves (Mat u 1, 2, 3), generates clean solution trees,
and saves the output to puzzles/mate_puzzles_db.json.

Target Mapping:
  - Diagrams 1 – 306    --> targetMoves: 1 (Mat u 1)
  - Diagrams 307 – 3718  --> targetMoves: 2 (Mat u 2)
  - Diagrams 3719 – 4462 --> targetMoves: 3 (Mat u 3)
"""

import os
import sys
import json
import glob
import re
import argparse
import chess
import chess.engine

STOCKFISH_PATHS = [
    r"D:\stockfish\stockfish-windows-x86-64-avx2\stockfish\stockfish-windows-x86-64-avx2.exe",
    r"C:\tools\stockfish.exe",
    r"C:\Program Files\Stockfish\stockfish.exe",
    "stockfish.exe",
    "stockfish"
]

OUTPUT_FILE = os.path.join("puzzles", "mate_puzzles_db.json")

def find_stockfish():
    for path in STOCKFISH_PATHS:
        if os.path.exists(path):
            return path
    import shutil
    sf = shutil.which("stockfish")
    if sf:
        return sf
    return None

def extract_diagram_number(item):
    for key in ["diagramNumber", "diagram_id", "id"]:
        val = item.get(key)
        if val is not None:
            matches = re.findall(r'\d+', str(val))
            if matches:
                # If ID looks like "23_pdf_2989", select 2989
                if len(matches) >= 2 and matches[0] in ['23', '5234']:
                    return int(matches[-1])
                return int(matches[0])
    return None

def get_target_moves(diag_num):
    if 1 <= diag_num <= 306:
        return 1
    elif 307 <= diag_num <= 3718:
        return 2
    elif 3719 <= diag_num <= 4462:
        return 3
    return None

def get_forced_mate_tree(engine, board, req_n, search_depth, current_k=1):
    """
    Recursively builds nested solution tree for all forced checkmate lines in <= req_n moves.
    Returns: (success: bool, tree: dict or str)
    """
    if board.is_checkmate():
        return True, "CHECKMATE"

    if current_k > req_n:
        return False, None

    remaining_needed = req_n - current_k + 1
    info = engine.analyse(board, chess.engine.Limit(depth=search_depth), multipv=5)
    
    winning_moves = []
    for pv_item in info:
        pv_list = pv_item.get("pv", [])
        if not pv_list:
            continue
        first_move = pv_list[0]
        score = pv_item.get("score")
        
        if score:
            rel_score = score.relative
            if rel_score.is_mate() and rel_score.mate() is not None:
                mate_in = rel_score.mate()
                if mate_in > 0 and mate_in <= remaining_needed:
                    winning_moves.append(first_move)

    if not winning_moves:
        return False, None

    user_tree = {}
    
    for u_move in winning_moves:
        u_uci = u_move.uci()
        board.push(u_move)

        if board.is_checkmate():
            user_tree[u_uci] = "CHECKMATE"
            board.pop()
            continue

        opp_tree = {}
        opp_all_mated = True
        
        for opp_move in board.legal_moves:
            opp_uci = opp_move.uci()
            board.push(opp_move)
            
            sub_ok, sub_tree = get_forced_mate_tree(engine, board, req_n, search_depth, current_k + 1)
            board.pop()
            
            if not sub_ok:
                opp_all_mated = False
                break
            opp_tree[opp_uci] = sub_tree

        board.pop()

        if opp_all_mated:
            user_tree[u_uci] = opp_tree

    if user_tree:
        return True, user_tree
    return False, None

def load_existing_db():
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    return {item["diagramNumber"]: item for item in data if "diagramNumber" in item}
        except Exception as e:
            print(f"⚠️ Nije moguće pročitati postojeći {OUTPUT_FILE}: {e}")
    return {}

def collect_raw_positions():
    """
    Collects raw positions 1..4462 from all available puzzle source JSON files.
    """
    candidate_files = [
        "puzzles/puzzles_23.json",
        "puzzles/winning_chess.json",
        "puzzles/puzzles_cleaned.json",
    ] + glob.glob("puzzles/puzzles_1/*.json")

    collected = {}

    for cfile in candidate_files:
        if not os.path.exists(cfile):
            continue
        try:
            with open(cfile, 'r', encoding='utf-8') as f:
                data = json.load(f)
                positions = data if isinstance(data, list) else data.get("positions", [])
                for item in positions:
                    diag = extract_diagram_number(item)
                    if diag and 1 <= diag <= 4462:
                        if diag not in collected:
                            target_n = get_target_moves(diag)
                            collected[diag] = {
                                "id": f"23_pdf_{diag}",
                                "diagramNumber": diag,
                                "fen": item.get("fen"),
                                "targetMoves": target_n,
                                "solved": item.get("solved", False),
                                "solutions": item.get("solutions", {})
                            }
        except Exception as e:
            print(f"⚠️ Greška pri čitanju {cfile}: {e}")

    return collected

def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

    parser = argparse.ArgumentParser(description="Izgradnja namenskog JSON fajla sa zagonetkama Mat u N (1-4462)")
    parser.add_argument("--depth", type=int, default=None, help="Dubina pretrage za Stockfish engine")
    args = parser.parse_args()

    depth = args.depth
    if depth is None:
        try:
            user_input = input("Unesite dubinu pretrage (Depth) za Stockfish [npr. 16]: ").strip()
            depth = int(user_input) if user_input else 16
        except ValueError:
            depth = 16

    sf_path = find_stockfish()
    if not sf_path:
        print("❌ Stockfish nije pronađen na sistemu! Postavite stockfish u PATH ili D:\\stockfish\\...")
        sys.exit(1)

    print(f"\n========================================================")
    print(f"♟️ IZGRADNJA BAZE ZAGONETKI (Mat u 1, 2, 3 | Opseg: 1 - 4462)")
    print(f"Pronađen Stockfish: {sf_path}")
    print(f"Izabrana dubina (Depth): {depth}")
    print(f"Izlazni fajl: {OUTPUT_FILE}")
    print(f"========================================================\n", flush=True)

    try:
        engine = chess.engine.SimpleEngine.popen_uci(sf_path)
    except Exception as e:
        print(f"❌ Greška pri pokretanju Stockfish engine-a: {e}")
        sys.exit(1)

    existing_db = load_existing_db()
    raw_positions = collect_raw_positions()

    # Merge existing DB records
    all_diagrams = sorted(list(set(list(existing_db.keys()) + list(raw_positions.keys()))))
    
    total = len(all_diagrams)
    print(f"📊 Prikupljeno ukupno {total} zagonetki u opsegu 1 - 4462.\n", flush=True)

    db_map = {}
    for dnum in all_diagrams:
        if dnum in existing_db:
            db_map[dnum] = existing_db[dnum]
        else:
            db_map[dnum] = raw_positions[dnum]

    solved_count = 0
    updated_count = 0

    for idx, dnum in enumerate(all_diagrams):
        item = db_map[dnum]
        
        if item.get("solved") is True and item.get("solutions"):
            solved_count += 1
            continue

        fen = item.get("fen")
        req_n = item.get("targetMoves") or get_target_moves(dnum)

        if not fen or not req_n:
            continue

        board = chess.Board(fen)

        try:
            ok, tree = get_forced_mate_tree(engine, board, req_n, depth)
            if ok and tree:
                item["solved"] = True
                item["solutions"] = tree
                item["targetMoves"] = req_n
                updated_count += 1
                solved_count += 1
                print(f"  ✅ [{idx+1}/{total}] Diagram #{dnum} ({item['id']}) | Nađen mat u {req_n}! (Depth {depth})", flush=True)
            else:
                item["solved"] = False
                item["solutions"] = {}
                print(f"  ⚡ [{idx+1}/{total}] Diagram #{dnum} ({item['id']}) | Nije nađen mat u {req_n} na dubini {depth}.", flush=True)
        except Exception as err:
            print(f"  ⚠️ Greška pri analizi dijagrama #{dnum}: {err}", flush=True)

        # Save progress every 20 positions
        if (idx + 1) % 20 == 0:
            output_list = [db_map[k] for k in sorted(db_map.keys())]
            os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
            with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
                json.dump(output_list, f, indent=2, ensure_ascii=False)

    # Final save
    output_list = [db_map[k] for k in sorted(db_map.keys())]
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(output_list, f, indent=2, ensure_ascii=False)

    engine.quit()

    print(f"\n🎉 Uspešno generisan i sačuvan fajl {OUTPUT_FILE}!")
    print(f"📊 Rezultat: {solved_count}/{total} rešenih zagonetki u bazi.\n", flush=True)

if __name__ == "__main__":
    main()
