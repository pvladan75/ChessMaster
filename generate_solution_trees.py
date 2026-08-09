#!/usr/bin/env python3
"""
Standalone Solution Tree Generator for Chess Puzzles
===================================================
Enriches puzzle JSON files with nested solution trees for all forced checkmate lines.

Usage:
    python generate_solution_trees.py
    python generate_solution_trees.py --depth 16 --file puzzles/puzzles_23.json
"""

import os
import sys
import json
import glob
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

def find_stockfish():
    for path in STOCKFISH_PATHS:
        if os.path.exists(path):
            return path
    import shutil
    sf = shutil.which("stockfish")
    if sf:
        return sf
    return None

def parse_mate_n(eval_str, default=2):
    if not eval_str:
        return default
    s = str(eval_str).upper()
    if 'M' in s:
        import re
        m = re.search(r'\d+', s)
        if m:
            return int(m.group(0))
    return default

def get_forced_mate_tree(engine, board, req_n, search_depth, current_k=1):
    """
    Recursively builds nested solution tree for all forced checkmate lines in <= req_n moves.
    Returns: (success: bool, tree: dict or list)
    """
    if board.is_checkmate():
        return True, []

    if current_k > req_n:
        return False, None

    # Step 1: User's turn to move - find winning candidate moves with forced mate in <= (req_n - current_k + 1)
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

        # Opponent's turn - test all legal opponent replies
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

def process_puzzle_file(file_path, search_depth, engine):
    print(f"\n📁 Obrađuje se fajl: {file_path}")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ Greška pri čitanju {file_path}: {e}")
        return

    is_list = isinstance(data, list)
    positions = data if is_list else data.get("positions", [])

    total = len(positions)
    solved_count = 0
    updated_count = 0

    print(f"📊 Ukupno pozicija u fajlu: {total}")

    for idx, item in enumerate(positions):
        if item.get("solved") is True and item.get("solutions"):
            solved_count += 1
            continue

        fen = item.get("fen")
        if not fen:
            continue

        req_n = parse_mate_n(item.get("eval") or item.get("evaluation"), default=item.get("targetMoves", 2))
        board = chess.Board(fen)

        try:
            ok, tree = get_forced_mate_tree(engine, board, req_n, search_depth)
            if ok and tree:
                item["solved"] = True
                item["solutions"] = tree
                item["targetMoves"] = req_n
                updated_count += 1
                solved_count += 1
                print(f"  ✅ [{idx+1}/{total}] ID: {item.get('diagram_id', item.get('id', idx))} | Nađen mat u {req_n} poteza! (Depth {search_depth})", flush=True)
            else:
                item["solved"] = False
                print(f"  ⚡ [{idx+1}/{total}] ID: {item.get('diagram_id', item.get('id', idx))} | Nije nađen mat u {req_n} na dubini {search_depth}.", flush=True)
        except Exception as err:
            print(f"  ⚠️ Greška pri analizi {fen}: {err}")

        # Save progress every 20 puzzles
        if (idx + 1) % 20 == 0:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

    # Final save
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"🎉 Završeno čuvanje {file_path}! Ukupno rešeno: {solved_count}/{total} (Novo ažurirano: {updated_count})\n")

def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

    parser = argparse.ArgumentParser(description="Generisanje stabala rešenja za šahovske zagonetke")
    parser.add_argument("--depth", type=int, default=None, help="Dubina pretrage za Stockfish engine")
    parser.add_argument("--file", type=str, default=None, help="Putanja do specifičnog JSON fajla zagonetki")
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
    print(f"♟️ STABLO REŠENJA GENERATOR - STOCKFISH ENGINE")
    print(f"Pronađen Stockfish: {sf_path}")
    print(f"Izabrana dubina (Depth): {depth}")
    print(f"========================================================\n")

    try:
        engine = chess.engine.SimpleEngine.popen_uci(sf_path)
    except Exception as e:
        print(f"❌ Greška pri pokretanju Stockfish engine-a: {e}")
        sys.exit(1)

    target_files = []
    if args.file:
        target_files.append(args.file)
    else:
        # Default puzzle JSON files
        candidate_files = [
            "puzzles/puzzles_23.json",
            "puzzles/winning_chess.json",
            "puzzles/puzzles_cleaned.json",
        ] + glob.glob("puzzles/puzzles_1/*.json")

        for f in candidate_files:
            if os.path.exists(f):
                target_files.append(f)

    if not target_files:
        print("⚠️ Nije pronađen nijedan JSON fajl sa zagonetkama.")
        engine.quit()
        return

    for json_file in target_files:
        process_puzzle_file(json_file, depth, engine)

    engine.quit()
    print("✨ Svi fajlovi su uspešno obrađeni i obogaćeni stablima rešenja!")

if __name__ == "__main__":
    main()
