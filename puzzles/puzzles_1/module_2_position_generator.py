import chess
import chess.engine
import random
import json
import os

# 1. KONFIGURACIJA
STOCKFISH_PATH = r"D:\stockfish\stockfish-windows-x86-64-avx2\stockfish\stockfish-windows-x86-64-avx2.exe"

PIECE_MAP = {
    'Q': chess.QUEEN, 'R': chess.ROOK, 'B': chess.BISHOP,
    'N': chess.KNIGHT, 'P': chess.PAWN
}

def get_user_input():
    """Prikuplja sve potrebne informacije od korisnika."""
    print("--- Generator Šahovskih Zagonetki v7.0 ---")
    
    white_pieces_str = input("Unesi bele figure (bez kralja, npr. QN): ").upper()
    black_pieces_str = input("Unesi crne figure (bez kralja, npr. r): ").upper()
    num_positions = int(input("Koliko pozicija želiš da generišeš? "))
    min_eval_cp = int(input("Unesi MINIMALNU prednost za belog (u centipešacima, npr. 300): "))
    min_mate_length_filter = int(input("Ignoriši pozicije ako je mat u manje od koliko poteza? (npr. 5): "))
    analysis_time = float(input("Vreme analize po poziciji (u sekundama, npr. 1.0): "))

    white_pieces = [PIECE_MAP[p] for p in white_pieces_str if p in PIECE_MAP]
    black_pieces = [PIECE_MAP[p] for p in black_pieces_str if p in PIECE_MAP]

    return (white_pieces, black_pieces, num_positions, analysis_time, 
            min_eval_cp, min_mate_length_filter,
            white_pieces_str, black_pieces_str)

def check_bishops_on_same_color(board: chess.Board, color: chess.Color) -> bool:
    """Proverava da li su svi lovci jedne boje na poljima iste boje."""
    bishops = board.pieces(chess.BISHOP, color)
    if len(bishops) < 2:
        return False
    
    # --- ФИНАЛНА ИСПРАВКА ЈЕ ОВДЕ ---
    # Ručno izračunavamo boju polja. Boja zavisi od parnosti zbira rank-a i file-a.
    # Ovo je univerzalno i ne zavisi od verzije biblioteke.
    square_colors = {(chess.square_file(sq) + chess.square_rank(sq)) % 2 for sq in bishops}
    return len(square_colors) == 1

def generate_and_evaluate_positions(params):
    """Glavna funkcija koja generiše, validira i evaluira pozicije."""
    (white_pieces, black_pieces, num_positions, time_limit, 
     min_eval, min_mate_filter,
     white_str, black_str) = params

    if not os.path.exists(STOCKFISH_PATH):
        print(f"GREŠKA: Stockfish nije pronađen na putanji: {STOCKFISH_PATH}")
        return []

    found_positions = []
    engine = chess.engine.SimpleEngine.popen_uci(STOCKFISH_PATH)
    attempts = 0

    while len(found_positions) < num_positions:
        attempts += 1
        if attempts % 1000 == 0:
            print(f"Pokušaj broj {attempts}...")
            
        board = chess.Board(None)
        squares = list(chess.SQUARES)
        random.shuffle(squares)
        
        try:
            board.set_piece_at(squares.pop(), chess.Piece(chess.KING, chess.WHITE))
            board.set_piece_at(squares.pop(), chess.Piece(chess.KING, chess.BLACK))
            for piece_type in white_pieces:
                board.set_piece_at(squares.pop(), chess.Piece(piece_type, chess.WHITE))
            for piece_type in black_pieces:
                board.set_piece_at(squares.pop(), chess.Piece(piece_type, chess.BLACK))
        except IndexError:
            continue

        if not board.is_valid(): continue
        
        if check_bishops_on_same_color(board, chess.WHITE) or \
           check_bishops_on_same_color(board, chess.BLACK):
            continue
        
        board.turn = chess.WHITE
        board.turn = chess.BLACK
        if board.is_check():
            board.turn = chess.WHITE
            continue
        board.turn = chess.WHITE
        
        info = engine.analyse(board, chess.engine.Limit(time=time_limit))
        score = info["score"].white()
        
        position_ok = False
        eval_value = None

        if score.is_mate():
            if score.mate() > 0 and score.mate() >= min_mate_filter:
                position_ok = True
                eval_value = f"Mate in {score.mate()}"
        else:
            if score.score() >= min_eval:
                position_ok = True
                eval_value = score.score()

        if position_ok:
            fen = board.fen()
            found_positions.append({
                "id": len(found_positions) + 1,
                "fen": fen,
                "evaluation": str(eval_value)
            })
            print(f"Pronađena pozicija {len(found_positions)}/{num_positions} sa evaluacijom {eval_value}...")
            print(board)
            print("-" * 20)
            
    engine.quit()
    return found_positions

def save_to_json(positions, params):
    """Čuva listu pozicija u JSON fajl."""
    (white_pieces, black_pieces, num_positions, time_limit, 
     min_eval, min_mate_filter,
     white_str, black_str) = params
     
    if not positions:
        print("Nije pronađena nijedna pozicija. Fajl neće biti kreiran.")
        return

    w_pieces_filename = "".join(sorted(white_str))
    b_pieces_filename = "".join(sorted(black_str))
    filename = f"puzzles_min_eval_{min_eval}_min_mate_{min_mate_filter}_W_{w_pieces_filename}_B_{b_pieces_filename}.json"
    
    with open(filename, 'w') as f:
        json.dump(positions, f, indent=4)
        
    print(f"\nUspešno sačuvano {len(positions)} pozicija u fajl: {filename}")


if __name__ == "__main__":
    user_params = get_user_input()
    generated_positions = generate_and_evaluate_positions(user_params)
    save_to_json(generated_positions, user_params)