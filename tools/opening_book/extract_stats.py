"""Opening statistics from a large PGN file, into a SQLite database.

    python extract_stats.py --file LumbrasGigaBase_OTB_Complete.pgn --elo-rule min
    python extract_stats.py --file ... --min-elo 2400 --with-corr
    python extract_stats.py --file ... --max-mb 200          (a trial on the start of the file)
    python extract_stats.py --probe "<FEN>" --db <database>.sqlite
    python extract_stats.py --verify-hash 20000 --file ...

For every position (Polyglot Zobrist hash) and every move played in it: how many
games White won, Black won, and how many were drawn. Only the first --max-ply
plies of each game.

This is how the server's masters database is built - `docs/PLAN-SKELET.md`,
decision D5, and `tools/opening_book/README.md` for the exact command. The
server reads it in `chess_backend/services/mastersBook.js`, which computes the
same key for a FEN (`export_polyglot.py` holds the two ends together).

Written by the owner on 13.9.2026 as a test of whether the data can be pulled
out at all, rewritten the next day before it was run again. What changed, and
why:

* **The hash is incremental**, move by move, rather than `zobrist_hash` over the
  whole board - that was half the time. `--verify-hash` compares it with
  python-chess on every ply; it agreed on 908,577 plies, and two mutations
  (castling, en passant) were caught by it.
* **Its own move reader** instead of `chess.pgn.read_game`: headers are read with
  a regular expression, and a game the filter refuses is never parsed. The move
  reader drops variations, which the first version walked as if they had been
  played and counted against the ply limit.
* **One (position, move) at most once per game.** Statistics count games; a
  game that repeats a position and move (Kd3 Qe4+ twice) is one game.
* **Several processes** (by default half the logical processors). The file is
  cut into chunks at game boundaries; a chunk and its "done" mark are written in
  **one transaction**, so an interruption (Ctrl+C, a flat battery) loses only
  the chunks in flight, and resuming never counts a game twice.
* **Three columns (w, b, d)** instead of one packed integer - no silent overflow,
  and SQLite stores 0 and 1 in no bytes at all, so it is not larger.
* **WAL with synchronous=NORMAL** instead of synchronous=OFF, which a power cut in
  the middle of a commit can corrupt.
* **Correspondence games are skipped** (Mode "Correspondence", an Event with
  "corr", source IECG/ICCF): the OTB file contains them, and they are played
  with an engine. --with-corr keeps them. Games with a [FEN] header are skipped:
  they do not start from the initial position.
* **The settings are written into the database**, and resuming with different
  settings is refused, so two statistics never mix in one file.

Proved against the first version game by game on 85,846 games before it was
trusted: every difference was one of the two faults above, and the database
equals the sum of its games row for row.
"""

import argparse
import multiprocessing as mp
import os
import re
import signal
import sqlite3
import sys
import time

import chess
import chess.polyglot

R = chess.polyglot.POLYGLOT_RANDOM_ARRAY
PAWN, ROOK, KING = chess.PAWN, chess.ROOK, chess.KING

GAME_SPLIT = re.compile(rb'\r?\n\r?\n(?=\[Event )')
HEAD_SPLIT = re.compile(rb'\r?\n\r?\n')
TAG = re.compile(rb'^\[(\w+) "([^"]*)"\]', re.M)
NOISE = re.compile(rb'\{[^}]*\}|;[^\n]*|\$\d+|\d+\.(?:\.\.)?|1-0|0-1|1/2-1/2|\*')
VARIATION = re.compile(rb'\([^()]*\)')
RESULT = {b'1-0': 0, b'0-1': 1, b'1/2-1/2': 2}


# --- The hash --------------------------------------------------------------------

def pk(color, piece_type, square):
    return R[64 * ((piece_type - 1) * 2 + int(color)) + square]


def board_part(board):
    h = 0
    for square, piece in board.piece_map().items():
        h ^= pk(piece.color, piece.piece_type, square)
    return h


def rest_part(board):
    """Castling, en passant and the side to move - recomputed every time."""
    h = 0
    cr = board.clean_castling_rights()
    if cr & chess.BB_H1: h ^= R[768]
    if cr & chess.BB_A1: h ^= R[769]
    if cr & chess.BB_H8: h ^= R[770]
    if cr & chess.BB_A8: h ^= R[771]
    ep = board.ep_square
    if ep is not None:
        # Polyglot: only if a pawn of the side to move stands beside; legality
        # is not asked.
        if board.turn == chess.WHITE:
            mask = chess.shift_down(chess.BB_SQUARES[ep])
        else:
            mask = chess.shift_up(chess.BB_SQUARES[ep])
        mask = chess.shift_left(mask) | chess.shift_right(mask)
        if mask & board.occupied_co[board.turn] & board.pawns:
            h ^= R[772 + chess.square_file(ep)]
    if board.turn == chess.WHITE:
        h ^= R[780]
    return h


def board_part_after(board, move, h):
    """[h] after [move], while [board] is still before it."""
    us, frm, to = board.turn, move.from_square, move.to_square
    pt = board.piece_type_at(frm)
    h ^= pk(us, pt, frm)
    if pt == PAWN and to == board.ep_square and (to - frm) % 8 != 0 \
            and board.piece_type_at(to) is None:
        h ^= pk(not us, PAWN, to - 8 if us else to + 8)
    else:
        captured = board.piece_type_at(to)
        if captured:
            h ^= pk(not us, captured, to)
    h ^= pk(us, move.promotion or pt, to)
    if pt == KING and abs(to - frm) == 2:
        if to > frm:
            h ^= pk(us, ROOK, frm + 3) ^ pk(us, ROOK, frm + 1)
        else:
            h ^= pk(us, ROOK, frm - 4) ^ pk(us, ROOK, frm - 1)
    return h


def signed(key):
    return key - (1 << 64) if key >= (1 << 63) else key


# --- One game and one chunk ---------------------------------------------------------

def moves_of(movetext, max_ply):
    text = NOISE.sub(b' ', movetext)
    while b'(' in text:
        stripped = VARIATION.sub(b' ', text)
        if stripped == text:
            break
        text = stripped
    return [t.rstrip(b'!?').decode('ascii', 'ignore') for t in text.split()[:max_ply]]


def verdict(tags, cfg):
    """(None, result) when a game is taken, (reason, None) when it is not."""
    result = RESULT.get(tags.get(b'Result'))
    if result is None:
        return 'no_result', None
    try:
        we, be = int(tags[b'WhiteElo']), int(tags[b'BlackElo'])
    except (KeyError, ValueError):
        return 'no_rating', None
    level = (we + be) / 2 if cfg['elo_rule'] == 'avg' else min(we, be)
    if level < cfg['min_elo']:
        return 'below_rating', None
    if not cfg['with_corr']:
        event = tags.get(b'Event', b'').lower()
        if (tags.get(b'Mode') == b'Correspondence' or b'corr' in event
                or tags.get(b'Source') in (b'IECG', b'ICCF')):
            return 'correspondence', None
    if b'FEN' in tags or b'SetUp' in tags:
        return 'fen', None
    return None, result


def game_keys(game, cfg):
    """(skip reason, result, keys, an illegal move?) for one game.

    A key is (position hash, move), **at most once per game**: the statistics
    count games, so a game that repeats a position and move must not count
    twice. The first version counted it twice.
    """
    parts = HEAD_SPLIT.split(game.strip(), 1)
    tags = dict(TAG.findall(parts[0]))
    why, result = verdict(tags, cfg)
    if why:
        return why, None, [], False
    board = chess.Board()
    h = board_part(board)
    keys, seen = [], set()
    for san in moves_of(parts[1] if len(parts) > 1 else b'', cfg['max_ply']):
        try:
            move = board.parse_san(san)
        except ValueError:
            return None, result, keys, True
        key = (signed(h ^ rest_part(board)),
               move.from_square | (move.to_square << 6) | ((move.promotion or 0) << 12))
        if key not in seen:
            seen.add(key)
            keys.append(key)
        h = board_part_after(board, move, h)
        board.push(move)
    return None, result, keys, False


def process_chunk(job):
    chunk_id, path, start, end, cfg = job
    with open(path, 'rb') as fh:
        fh.seek(start)
        data = fh.read(end - start)
    if start == 0 and data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    stats = {}
    counts = {'games': 0, 'taken': 0, 'illegal_move': 0, 'no_result': 0,
              'no_rating': 0, 'below_rating': 0, 'correspondence': 0, 'fen': 0}
    for game in GAME_SPLIT.split(data):
        if not game.strip():
            continue
        counts['games'] += 1
        why, result, keys, illegal = game_keys(game, cfg)
        if why:
            counts[why] += 1
            continue
        counts['taken'] += 1
        if illegal:
            counts['illegal_move'] += 1
        for key in keys:
            cell = stats.get(key)
            if cell is None:
                cell = stats[key] = [0, 0, 0]
            cell[result] += 1
    rows = [(z, m, c[0], c[1], c[2]) for (z, m), c in stats.items()]
    return chunk_id, rows, counts


# --- The chunk plan and the database -----------------------------------------------

def plan_chunks(path, limit_bytes, chunk_bytes):
    size = int(min(os.path.getsize(path), limit_bytes or float('inf')))
    starts = [0]
    with open(path, 'rb') as fh:
        pos = chunk_bytes
        while pos < size:
            fh.seek(pos)
            window = fh.read(1 << 20)
            at = window.find(b'\n[Event ')
            if at < 0:
                pos += 1 << 20
                continue
            boundary = pos + at + 1
            if boundary >= size:
                break
            starts.append(boundary)
            pos = boundary + chunk_bytes
        if limit_bytes and size < os.path.getsize(path):
            # A trial ends on a game boundary, not in the middle of a game.
            fh.seek(size)
            at = fh.read(1 << 20).find(b'\n[Event ')
            size = size + at + 1 if at >= 0 else os.path.getsize(path)
    ends = starts[1:] + [size]
    return list(zip(starts, ends))


def open_db(db_path, cfg, chunks, file_name):
    conn = sqlite3.connect(db_path)
    conn.execute('PRAGMA journal_mode = WAL')
    conn.execute('PRAGMA synchronous = NORMAL')
    conn.execute('PRAGMA cache_size = -400000')
    conn.execute('PRAGMA temp_store = MEMORY')
    conn.execute('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)')
    conn.execute('''CREATE TABLE IF NOT EXISTS chunks (
        id INTEGER PRIMARY KEY, start INTEGER, end INTEGER, done INTEGER DEFAULT 0,
        games INTEGER, taken INTEGER, skipped TEXT)''')
    conn.execute('''CREATE TABLE IF NOT EXISTS position_stats (
        zobrist INTEGER, move INTEGER, w INTEGER, b INTEGER, d INTEGER,
        PRIMARY KEY (zobrist, move)) WITHOUT ROWID''')
    wanted = {'file': file_name, 'min_elo': str(cfg['min_elo']), 'elo_rule': cfg['elo_rule'],
              'with_corr': str(cfg['with_corr']), 'max_ply': str(cfg['max_ply']),
              'chunks': str(len(chunks))}
    have = dict(conn.execute('SELECT key, value FROM meta'))
    if have and have != wanted:
        diff = {k: (have.get(k), v) for k, v in wanted.items() if have.get(k) != v}
        sys.exit('The database %s was built with other settings: %s\n'
                 'Delete it or use the same settings.' % (db_path, diff))
    if not have:
        conn.executemany('INSERT INTO meta VALUES (?, ?)', wanted.items())
        conn.executemany('INSERT INTO chunks (id, start, end) VALUES (?, ?, ?)',
                         [(i, s, e) for i, (s, e) in enumerate(chunks)])
        conn.commit()
    return conn


def ignore_sigint():
    signal.signal(signal.SIGINT, signal.SIG_IGN)


# --- Commands ----------------------------------------------------------------------

def run(cfg):
    path = cfg['file']
    base = os.path.splitext(os.path.basename(path))[0]
    db_path = cfg['db'] or os.path.join(
        os.path.dirname(os.path.abspath(path)),
        '%s_stats_%s%s%s%s.sqlite' % (base, cfg['elo_rule'], cfg['min_elo'],
                                     '_corr' if cfg['with_corr'] else '',
                                     '_trial%dmb' % cfg['max_mb'] if cfg['max_mb'] else ''))
    chunks = plan_chunks(path, cfg['max_mb'] * (1 << 20) if cfg['max_mb'] else 0,
                         cfg['chunk_mb'] * (1 << 20))
    conn = open_db(db_path, cfg, chunks, os.path.basename(path))
    pending = [(i, s, e) for i, s, e in conn.execute(
        'SELECT id, start, end FROM chunks WHERE done = 0 ORDER BY id')]
    total_bytes = conn.execute('SELECT SUM(end - start) FROM chunks').fetchone()[0]
    done_bytes = total_bytes - sum(e - s for _, s, e in pending)

    print('File: %s\nDatabase: %s' % (path, db_path))
    print('Filter: %s Elo >= %d, %s, first %d plies; %d workers, %d chunks (%d left)'
          % ('average' if cfg['elo_rule'] == 'avg' else 'both players', cfg['min_elo'],
             'with correspondence' if cfg['with_corr'] else 'no correspondence',
             cfg['max_ply'], cfg['workers'], len(chunks), len(pending)))
    if not pending:
        print('Everything is already done.')
        return db_path

    started, session_bytes, kept = time.time(), 0, 0
    sizes = {i: e - s for i, s, e in pending}
    upsert = '''INSERT INTO position_stats (zobrist, move, w, b, d) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(zobrist, move) DO UPDATE SET
                w = w + excluded.w, b = b + excluded.b, d = d + excluded.d'''
    pool = mp.Pool(cfg['workers'], initializer=ignore_sigint)
    try:
        jobs = [(i, path, s, e, cfg) for i, s, e in pending]
        for chunk_id, rows, counts in pool.imap_unordered(process_chunk, jobs):
            conn.executemany(upsert, rows)
            skipped = ', '.join('%s %d' % (k, v) for k, v in counts.items()
                                if k not in ('games', 'taken') and v)
            conn.execute('UPDATE chunks SET done = 1, games = ?, taken = ?, skipped = ? '
                         'WHERE id = ?', (counts['games'], counts['taken'], skipped, chunk_id))
            conn.commit()
            session_bytes += sizes[chunk_id]
            kept += counts['taken']
            elapsed = time.time() - started
            rate = session_bytes / elapsed
            left = total_bytes - done_bytes - session_bytes
            sys.stdout.write('\r%5.1f%% | %s games taken this run | %.1f MB/s | ETA %s | database %.0f MB   ' % (
                100.0 * (done_bytes + session_bytes) / total_bytes, format(kept, ','),
                rate / (1 << 20), time.strftime('%H:%M:%S', time.gmtime(left / rate)) if rate else '?',
                os.path.getsize(db_path) / (1 << 20)))
            sys.stdout.flush()
        pool.close()
    except KeyboardInterrupt:
        print('\n\nInterrupted. Finished chunks are already written; running again resumes from the rest.')
        pool.terminate()
        conn.close()
        sys.exit(1)
    finally:
        pool.join()

    games, taken = conn.execute('SELECT SUM(games), SUM(taken) FROM chunks').fetchone()
    conn.execute('PRAGMA wal_checkpoint(TRUNCATE)')
    conn.close()
    print('\n\nDone in %.0f s. Read %s games, %s in the statistics.' % (
        time.time() - started, format(games, ','), format(taken, ',')))
    return db_path


def probe(db_path, fen):
    board = chess.Board(fen)
    conn = sqlite3.connect('file:%s?mode=ro' % db_path, uri=True)
    key = signed(chess.polyglot.zobrist_hash(board))
    rows = []
    for m, w, b, d in conn.execute('SELECT move, w, b, d FROM position_stats WHERE zobrist = ?', (key,)):
        move = chess.Move(m & 63, (m >> 6) & 63, ((m >> 12) & 7) or None)
        rows.append((board.san(move) if board.is_legal(move) else move.uci(), w, b, d))
    rows.sort(key=lambda r: -sum(r[1:]))
    total = sum(sum(r[1:]) for r in rows)
    print('%s: %s games' % (fen, format(total, ',')))
    for san, w, b, d in rows:
        n = w + b + d
        print('  %-7s %9s %5.1f%%   White %4.1f  draw %4.1f  Black %4.1f' % (
            san, format(n, ','), 100.0 * n / total, 100.0 * w / n, 100.0 * d / n, 100.0 * b / n))


def verify_hash(path, games_wanted):
    """The incremental hash against python-chess, on every ply."""
    with open(path, 'rb') as fh:
        data = fh.read(64 << 20)
    checked = games = 0
    for game in GAME_SPLIT.split(data):
        parts = HEAD_SPLIT.split(game.strip(), 1)
        if len(parts) < 2 or b'[FEN ' in parts[0]:
            continue
        board = chess.Board()
        h = board_part(board)
        for san in moves_of(parts[1], 200):
            try:
                move = board.parse_san(san)
            except ValueError:
                break
            if (h ^ rest_part(board)) != chess.polyglot.zobrist_hash(board):
                sys.exit('DIFFERENT after %d checks: %s before %s' % (checked, board.fen(), san))
            checked += 1
            h = board_part_after(board, move, h)
            board.push(move)
        games += 1
        if games >= games_wanted:
            break
    print('The hash agrees with python-chess on %s plies in %s games.' % (
        format(checked, ','), format(games, ',')))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--file', help='the PGN file to read')
    parser.add_argument('--db', help='the database to write (default: beside the PGN)')
    parser.add_argument('--min-elo', type=int, default=2200)
    parser.add_argument('--elo-rule', choices=['avg', 'min'], default='avg',
                        help='avg: the average of the two ratings; min: both players at or above it. '
                             'The server\'s database uses min.')
    parser.add_argument('--with-corr', action='store_true', help='keep correspondence games')
    parser.add_argument('--max-ply', type=int, default=30)
    parser.add_argument('--workers', type=int, default=max(1, (os.cpu_count() or 2) // 2))
    parser.add_argument('--chunk-mb', type=int, default=32)
    parser.add_argument('--max-mb', type=int, default=0, help='a trial on the start of the file')
    parser.add_argument('--probe', metavar='FEN')
    parser.add_argument('--verify-hash', type=int, metavar='GAMES')
    cfg = vars(parser.parse_args())

    if cfg['probe']:
        if not cfg['db']:
            sys.exit('--probe needs --db')
        probe(cfg['db'], cfg['probe'])
        return
    if not cfg['file']:
        sys.exit('--file is required: the PGN file to read.')
    if cfg['verify_hash']:
        verify_hash(cfg['file'], cfg['verify_hash'])
        return
    run(cfg)


if __name__ == '__main__':
    main()
