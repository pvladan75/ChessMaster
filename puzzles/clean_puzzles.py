#!/usr/bin/env python3
"""
clean_puzzles.py - Rigorous Lichess Puzzle Cleaner & Validator using python-chess & Stockfish Engine
------------------------------------------------------------------------------------------------------
Filtering Criteria:
1. Valid FEN position check (chess.Board(fen).is_valid())
2. Move sequence length: 3 <= len(moves) <= 6 (i.e. 1 to 3 player moves to guess)
3. Exclude opening puzzles (themes containing 'opening' or with OpeningTags)
4. Sequence move legality (all UCI moves can be played legally on board)
5. Stockfish MultiPV=2 uniqueness check at depth 16:
   - For every player move (odd indices in moves: index 1, 3, 5...):
     - Run Stockfish MultiPV=2 (depth=16 or time_limit=0.1s)
     - Require PV1 move == expected puzzle move
     - Require score delta (PV1 - PV2) >= 175 centipawns (or PV1 is mate)
6. Stop condition: Target exactly N accepted puzzles (default: 20,000)
7. Save accepted puzzles to puzzles_cleaned.json with full summary statistics.

Supports multiprocessing for fast parallel processing across CPU cores.
"""

import sys
import os
import io
import csv
import json
import time
import argparse
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor, as_completed
import chess
import chess.engine

def find_stockfish(custom_path=None):
    """Auto-detect Stockfish binary location on system."""
    if custom_path and os.path.isfile(custom_path):
        return custom_path

    candidates = [
        r"D:\stockfish\stockfish-windows-x86-64-avx2\stockfish\stockfish-windows-x86-64-avx2.exe",
        r"C:\Program Files\ChessX\data\engines\uci\stockfish_10_x64.exe",
        r"C:\tools\stockfish.exe",
        r"C:\Program Files\Stockfish\stockfish.exe",
        "stockfish",
        "stockfish.exe"
    ]
    for candidate in candidates:
        if os.path.isfile(candidate):
            return candidate
    return None

def process_puzzle_chunk(chunk, stockfish_path, depth=16, delta_min=175, time_limit=0.1):
    """
    Process a chunk of puzzle dicts in a worker process.
    Initializes a Stockfish engine per worker process.
    """
    accepted = []
    stats = {
        'total': len(chunk),
        'invalid_fen': 0,
        'invalid_length': 0,
        'opening_excluded': 0,
        'illegal_move': 0,
        'not_top_pv1': 0,
        'delta_too_low': 0,
        'accepted': 0
    }

    engine = None
    if stockfish_path:
        try:
            engine = chess.engine.SimpleEngine.popen_uci(stockfish_path)
            engine.configure({"MultiPV": 2})
        except Exception:
            engine = None

    for item in chunk:
        puzzle_id = item.get('PuzzleId') or item.get('puzzle_id')
        fen = item.get('FEN') or item.get('fen')
        moves_input = item.get('Moves') or item.get('moves')

        if isinstance(moves_input, list):
            moves_list = moves_input
        elif isinstance(moves_input, str):
            moves_list = moves_input.strip().split()
        else:
            moves_list = []

        # Criterion 1: Valid FEN
        try:
            board = chess.Board(fen)
            if not board.is_valid():
                stats['invalid_fen'] += 1
                continue
        except Exception:
            stats['invalid_fen'] += 1
            continue

        # Criterion 2: Move Length (3 <= len(moves) <= 6)
        if not (3 <= len(moves_list) <= 6):
            stats['invalid_length'] += 1
            continue

        # Criterion 3: Exclude Opening Puzzles
        themes_raw = item.get('Themes') or item.get('themes') or ''
        if isinstance(themes_raw, list):
            themes_list = [t.lower() for t in themes_raw]
        else:
            themes_list = [t.lower() for t in str(themes_raw).strip().split()]

        opening_tags = item.get('OpeningTags') or item.get('opening_tags') or ''

        if 'opening' in themes_list or (opening_tags and str(opening_tags).strip() != ''):
            stats['opening_excluded'] += 1
            continue

        # Criterion 4: Sequence move legality
        temp_board = board.copy()
        legal = True
        for move_uci in moves_list:
            try:
                move = chess.Move.from_uci(move_uci)
                if move in temp_board.legal_moves:
                    temp_board.push(move)
                else:
                    legal = False
                    break
            except Exception:
                legal = False
                break

        if not legal:
            stats['illegal_move'] += 1
            continue

        # Criterion 5: Stockfish MultiPV=2 Uniqueness Check
        if engine is None:
            # If no engine provided, accept based on Criteria 1-4
            accepted.append(item)
            stats['accepted'] += 1
            continue

        eval_passed = True
        sim_board = board.copy()

        for idx, move_uci in enumerate(moves_list):
            if idx % 2 == 1:  # Player move (index 1, 3, 5)
                try:
                    analysis = engine.analyse(
                        sim_board,
                        chess.engine.Limit(depth=depth, time=time_limit),
                        multipv=2
                    )

                    if len(analysis) < 1:
                        eval_passed = False
                        stats['not_top_pv1'] += 1
                        break

                    pv1 = analysis[0]
                    pv1_move = pv1.get("pv", [None])[0]

                    if not pv1_move or pv1_move.uci() != move_uci:
                        eval_passed = False
                        stats['not_top_pv1'] += 1
                        break

                    if len(analysis) >= 2:
                        pv2 = analysis[1]
                        score1 = pv1.get("score")
                        score2 = pv2.get("score")

                        # If PV1 is mate, uniqueness is satisfied
                        if score1 and score1.is_mate():
                            pass
                        elif score1 and score2:
                            cp1 = score1.relative.score(mate_score=10000)
                            cp2 = score2.relative.score(mate_score=10000)

                            if cp1 is not None and cp2 is not None:
                                delta = cp1 - cp2
                                if delta < delta_min:
                                    eval_passed = False
                                    stats['delta_too_low'] += 1
                                    break
                except Exception:
                    eval_passed = False
                    stats['not_top_pv1'] += 1
                    break

            # Play move on simulation board for next iteration
            move_obj = chess.Move.from_uci(move_uci)
            sim_board.push(move_obj)

        if eval_passed:
            accepted.append(item)
            stats['accepted'] += 1

    if engine:
        engine.quit()

    return accepted, stats

def load_puzzles(input_file, max_records=None):
    """Load puzzles from .csv.zst, .csv, or .json file."""
    puzzles = []
    print(f"Učitavam bazu zagonetki iz: {input_file}...")
    start_t = time.time()

    if input_file.endswith('.zst'):
        import zstandard as zstd
        with open(input_file, 'rb') as fh:
            dctx = zstd.ZstdDecompressor()
            with dctx.stream_reader(fh) as reader:
                text_stream = io.TextIOWrapper(reader, encoding='utf-8')
                reader_csv = csv.DictReader(text_stream)
                for row in reader_csv:
                    puzzles.append(row)
                    if max_records and len(puzzles) >= max_records:
                        break
    elif input_file.endswith('.json') or input_file.endswith('.jsonl'):
        with open(input_file, 'r', encoding='utf-8') as fh:
            if input_file.endswith('.jsonl'):
                for line in fh:
                    if line.strip():
                        puzzles.append(json.loads(line))
                        if max_records and len(puzzles) >= max_records:
                            break
            else:
                data = json.load(fh)
                puzzles = data if isinstance(data, list) else [data]
                if max_records:
                    puzzles = puzzles[:max_records]
    else:  # .csv
        with open(input_file, 'r', encoding='utf-8') as fh:
            reader_csv = csv.DictReader(fh)
            for row in reader_csv:
                puzzles.append(row)
                if max_records and len(puzzles) >= max_records:
                    break

    elapsed = time.time() - start_t
    print(f"Učitano {len(puzzles):,} zagonetki za {elapsed:.2f} sekundi.")
    return puzzles

def main():
    parser = argparse.ArgumentParser(description="Clean and validate Lichess puzzles dataset.")
    parser.add_argument("--input", default=r"d:\Projekti\chess_master\puzzles\lichess_db_puzzle.csv.zst", help="Path to input puzzles file (.csv.zst, .csv, .json)")
    parser.add_argument("--output", default=r"d:\Projekti\chess_master\puzzles\puzzles_cleaned.json", help="Path to output cleaned JSON file")
    parser.add_argument("--stockfish", default=None, help="Path to Stockfish executable binary")
    parser.add_argument("--depth", type=int, default=16, help="Stockfish engine analysis depth (default: 16)")
    parser.add_argument("--delta", type=int, default=175, help="Minimum centipawn evaluation delta for PV1 vs PV2 (default: 175)")
    parser.add_argument("--workers", type=int, default=2, help="Number of parallel worker processes (default: 2)")
    parser.add_argument("--target-accepted", type=int, default=20000, help="Target maximum accepted puzzles to collect (default: 20000)")
    parser.add_argument("--max-records", type=int, default=None, help="Optional limit of input records to read")
    parser.add_argument("--chunk-size", type=int, default=200, help="Chunk size per multiprocessing worker task (default: 200)")
    args = parser.parse_args()

    input_file = os.path.abspath(args.input)
    output_file = os.path.abspath(args.output)

    if not os.path.isfile(input_file):
        print(f"Greška: Ulazni fajl '{input_file}' ne postoji!", file=sys.stderr)
        sys.exit(1)

    stockfish_path = find_stockfish(args.stockfish)
    if stockfish_path:
        print(f"Stockfish engine pronađen na: {stockfish_path}")
    else:
        print("UPOZORENJE: Stockfish nije pronađen! Biće primenjeni samo kriterijumi (Validacija FEN-a, dužine, otvaranja i legalnosti).")

    puzzles = load_puzzles(input_file, max_records=args.max_records)
    total_puzzles = len(puzzles)

    if total_puzzles == 0:
        print("Baza je prazna!")
        sys.exit(0)

    chunk_size = args.chunk_size
    chunks = [puzzles[i:i + chunk_size] for i in range(0, total_puzzles, chunk_size)]
    num_workers = min(args.workers or 2, len(chunks))

    print(f"\nZapočinjem filtriranje sa {num_workers} paralelnih procesa (Cilj prihvaćenih: {args.target_accepted:,})...")
    start_time = time.time()

    all_accepted = []
    total_stats = {
        'total': 0,
        'invalid_fen': 0,
        'invalid_length': 0,
        'opening_excluded': 0,
        'illegal_move': 0,
        'not_top_pv1': 0,
        'delta_too_low': 0,
        'accepted': 0
    }

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        futures = [
            executor.submit(
                process_puzzle_chunk,
                chunk,
                stockfish_path,
                args.depth,
                args.delta
            )
            for chunk in chunks
        ]

        for future in as_completed(futures):
            try:
                acc, stats = future.result()
                all_accepted.extend(acc)
                for k in total_stats:
                    total_stats[k] += stats[k]

                processed_count = total_stats['total']
                percent = (processed_count / total_puzzles) * 100
                sys.stdout.write(f"\rNapredak: {processed_count:,}/{total_puzzles:,} ({percent:.1f}%) | Prihvaćeno: {len(all_accepted):,}/{args.target_accepted:,}... ")
                sys.stdout.flush()

                if len(all_accepted) >= args.target_accepted:
                    all_accepted = all_accepted[:args.target_accepted]
                    print(f"\n\n🎯 Dostignut cilj od {args.target_accepted:,} prihvaćenih zagonetki! Prekidam dalju obradu.")
                    for f in futures:
                        f.cancel()
                    executor.shutdown(wait=False, cancel_futures=True)
                    break
            except Exception as e:
                print(f"\nGreška u worker procesu: {e}", file=sys.stderr)

    elapsed_time = time.time() - start_time
    print("\n" + "=" * 60)
    print(" 📊 STATISTIKA FILTRIRANJA LICHESS ZAGONETKI ")
    print("=" * 60)
    print(f" Ukupno analizirano:               {total_stats['total']:,}")
    print(f" Prihvaćeno zagonetki:             {len(all_accepted):,} ({len(all_accepted) / max(1, total_stats['total']) * 100:.2f}%)")
    print(f" Odbijeno - Nelegan FEN:          {total_stats['invalid_fen']:,}")
    print(f" Odbijeno - Pogrešna dužina (3-6): {total_stats['invalid_length']:,}")
    print(f" Odbijeno - Otvaranja (Opening):   {total_stats['opening_excluded']:,}")
    print(f" Odbijeno - Nelegalni potezi:      {total_stats['illegal_move']:,}")
    print(f" Odbijeno - Nije Stockfish PV1:    {total_stats['not_top_pv1']:,}")
    print(f" Odbijeno - Delta < {args.delta} centipawns: {total_stats['delta_too_low']:,}")
    print(f" Ukupno vreme obrade:              {elapsed_time:.2f} s ({total_stats['total'] / max(0.1, elapsed_time):.1f} zagonetki/s)")
    print("=" * 60)

    # Save output to puzzles_cleaned.json
    print(f"\nSnimam očišćenu bazu u '{output_file}'...")
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_accepted, f, indent=2, ensure_ascii=False)

    print(f"Uspešno sačuvano {len(all_accepted):,} zagonetki u '{output_file}'!")

if __name__ == "__main__":
    main()
