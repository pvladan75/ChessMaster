"""Holds a newly built opening book to the one it replaces, before it is believed.

    python compare_books.py --old <ply30>.sqlite --new <ply50>.sqlite
    python compare_books.py --old ... --new ... --games-only     (skip the row pass)

Phase 0 of `docs/PLAN-OTVARANJA-LOKALNO.md`. A rebuilt file that is quietly
wrong looks exactly like a correct one — a book is a table of numbers, and a
wrong number is still a number — so four questions are asked of it, and the
script exits 1 when any answer is not the expected one:

1. **What it says it is.** Its `meta` names the same PGN, the same rating rule
   and floor, no correspondence games, the depth it was asked for, and that it
   was pruned. No chunk is left unread.

2. **The same games went in.** The old and new files cut the PGN into the same
   chunks, so every chunk must have read the same number of games and taken the
   same number: the rating filter does not depend on depth. A difference here is
   a different reader, not a deeper one.

3. **Every row the old file backs with two games or more is still there, with
   no count lower.** Not "the same counts": a deeper extraction also counts a
   game that reaches a position only *after* the old file's last ply — a
   transposition deep in a game — so a count may rise. It may never fall, and a
   row may never vanish. How many rose, and by how much at most, is printed,
   because a large share would mean something other than transpositions.
   The same is asked of the per-position totals the prune kept.

4. **The harness games leave the book where the simulation said.** Each of the
   thirteen games in `tools/game_annotate/input/` is walked through the old file
   twice — every row, and rows played twice or more, which is what pruning keeps
   — and once through the new file. The new file must agree with the second
   walk. The numbers the plan printed are checked as well, so a walk that
   changed its own definition cannot pass by agreeing with itself.

The old file was built by the Serbian original of `extract_stats.py`, whose
`chunks` columns are `partije` and `uzete`; both spellings are read.
"""

import argparse
import glob
import io
import os
import sqlite3
import sys

import chess
import chess.pgn
import chess.polyglot

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(os.path.dirname(HERE), 'game_annotate', 'input')

# `docs/PLAN-OTVARANJA-LOKALNO.md`, "Pruning shortens the book in 8 of 13 harness
# games": positions in book through the ply-30 file, all rows / rows played twice
# or more. Only the games the table names by number; the rest shortened by one
# ply or not at all, and question 4 compares those against the walk itself.
PLAN_SAYS = {
    'g09_caro-kann-defense': (15, 9),
    'g03_scandinavian-defense': (13, 10),
    'g06_zukertort-opening': (15, 13),
    'pvladan_2026-09-12': (15, 13),
}
SHORTER_BY_ONE = ['french_2026-06-19', 'g01_scandinavian-defense',
                  'g02_french-defense', 'g08_nimzowitsch-defense']
UNCHANGED = ['g04_saragossa-opening', 'g05_french-defense', 'g07_english-opening',
             'g10_english-opening', 'philidor_2026-07-03']


def signed(key):
    return key - (1 << 64) if key >= (1 << 63) else key


def open_ro(path):
    if not os.path.exists(path):
        sys.exit('No such file: %s' % path)
    return sqlite3.connect('file:%s?mode=ro' % path, uri=True)


def chunk_columns(conn):
    names = [row[1] for row in conn.execute('PRAGMA table_info(chunks)')]
    games = 'games' if 'games' in names else 'partije'
    taken = 'taken' if 'taken' in names else 'uzete'
    return games, taken


class Report:
    def __init__(self):
        self.failures = []

    def check(self, ok, what):
        print('  %s  %s' % ('ok  ' if ok else 'FAIL', what))
        if not ok:
            self.failures.append(what)


def question_meta(new, old, max_ply, report):
    print('\n1. What the new file says it is')
    have = dict(new.execute('SELECT key, value FROM meta'))
    was = dict(old.execute('SELECT key, value FROM meta'))
    for key in ('file', 'min_elo', 'elo_rule', 'with_corr', 'chunks'):
        report.check(have.get(key) == was.get(key),
                     '%s = %r (old file: %r)' % (key, have.get(key), was.get(key)))
    report.check(have.get('max_elo') in (None, '', '0'), 'no rating ceiling: %r' % have.get('max_elo'))
    report.check(have.get('max_ply') == str(max_ply), 'max_ply = %r' % have.get('max_ply'))
    report.check(have.get('pruned') == '1', 'pruned = %r' % have.get('pruned'))
    left = new.execute('SELECT COUNT(*) FROM chunks WHERE done = 0').fetchone()[0]
    report.check(left == 0, 'unread chunks: %d' % left)
    has_totals = new.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' "
                             "AND name = 'position_totals'").fetchone()
    report.check(bool(has_totals), 'position_totals exists')


def question_games(new, old, report):
    print('\n2. The same games went in')
    ng, nt = chunk_columns(new)
    og, ot = chunk_columns(old)
    theirs = {i: (g, t) for i, g, t in old.execute('SELECT id, %s, %s FROM chunks' % (og, ot))}
    ours = {i: (g, t) for i, g, t in new.execute('SELECT id, %s, %s FROM chunks' % (ng, nt))}
    differing = [i for i in ours if ours[i] != theirs.get(i)]
    report.check(set(ours) == set(theirs), '%d chunks in both' % len(ours))
    report.check(not differing, 'chunks reading different games: %s' % (differing[:10] or 'none'))
    read = sum(g for g, _ in ours.values())
    kept = sum(t for _, t in ours.values())
    print('        read %s games, took %s (old file: %s, %s)' % (
        format(read, ','), format(kept, ','),
        format(sum(g for g, _ in theirs.values()), ','),
        format(sum(t for _, t in theirs.values()), ',')))


def question_rows(new_path, old_path, report):
    print('\n3. Every row the old file backs with two games or more')
    conn = sqlite3.connect('file::memory:', uri=True)
    conn.execute("ATTACH DATABASE 'file:%s?mode=ro' AS old" % old_path.replace("'", "''"))
    conn.execute("ATTACH DATABASE 'file:%s?mode=ro' AS new" % new_path.replace("'", "''"))
    (rows, missing, lower, rose, most) = conn.execute('''
        SELECT COUNT(*),
               SUM(n.zobrist IS NULL),
               SUM(n.zobrist IS NOT NULL AND (n.w < o.w OR n.b < o.b OR n.d < o.d)),
               SUM(n.zobrist IS NOT NULL AND (n.w + n.b + n.d) > (o.w + o.b + o.d)),
               MAX((n.w + n.b + n.d) - (o.w + o.b + o.d))
          FROM old.position_stats o
          LEFT JOIN new.position_stats n ON n.zobrist = o.zobrist AND n.move = o.move
         WHERE o.w + o.b + o.d > 1''').fetchone()
    report.check(missing == 0, 'rows missing from the new file: %s of %s' % (
        format(missing, ','), format(rows, ',')))
    report.check(lower == 0, 'rows with a lower count: %s' % format(lower, ','))
    share = 100.0 * rose / rows if rows else 0.0
    print('        rows whose count rose (games reaching them past ply 30): %s, %.3f%%, '
          'at most +%s' % (format(rose, ','), share, most or 0))
    report.check(share < 1.0, 'under 1%% of rows rose (%.3f%%)' % share)

    (positions, gone, less, grew) = conn.execute('''
        WITH was AS (
          SELECT zobrist, SUM(w) w, SUM(b) b, SUM(d) d FROM old.position_stats
           GROUP BY zobrist HAVING SUM(w + b + d > 1) > 0)
        SELECT COUNT(*),
               SUM(t.zobrist IS NULL),
               SUM(t.zobrist IS NOT NULL AND (t.w < was.w OR t.b < was.b OR t.d < was.d)),
               SUM(t.zobrist IS NOT NULL AND (t.w + t.b + t.d) > (was.w + was.b + was.d))
          FROM was LEFT JOIN new.position_totals t ON t.zobrist = was.zobrist''').fetchone()
    report.check(gone == 0, 'positions without a total in the new file: %s of %s' % (
        format(gone, ','), format(positions, ',')))
    report.check(less == 0, 'positions whose total fell: %s' % format(less, ','))
    print('        positions whose total rose: %s' % format(grew, ','))

    # A total must be at least what its surviving rows add up to; a total below
    # them is a prune that counted after the delete.
    below = conn.execute('''
        SELECT COUNT(*) FROM (
          SELECT s.zobrist, SUM(s.w + s.b + s.d) listed FROM new.position_stats s
           GROUP BY s.zobrist) r
          JOIN new.position_totals t ON t.zobrist = r.zobrist
         WHERE t.w + t.b + t.d < r.listed''').fetchone()[0]
    report.check(below == 0, 'totals smaller than their own rows: %s' % format(below, ','))
    orphans = conn.execute('''
        SELECT COUNT(*) FROM new.position_totals t
         WHERE NOT EXISTS (SELECT 1 FROM new.position_stats s WHERE s.zobrist = t.zobrist)
    ''').fetchone()[0]
    report.check(orphans == 0, 'totals for positions with no move left: %s' % format(orphans, ','))


def positions_of(pgn_path):
    game = chess.pgn.read_game(io.open(pgn_path, encoding='utf-8'))
    board = game.board()
    boards = [board.copy()]
    for move in game.mainline_moves():
        board.push(move)
        boards.append(board.copy())
    return boards


def walked(conn, boards, rule, max_ply=None):
    """How many of [boards] the book answers, from the first, before one it does not."""
    n = 0
    for ply, board in enumerate(boards):
        if max_ply is not None and ply >= max_ply:
            break
        key = signed(chess.polyglot.zobrist_hash(board))
        rows = conn.execute('SELECT w + b + d FROM position_stats WHERE zobrist = ?', (key,)).fetchall()
        if not any(rule(count) for (count,) in rows):
            break
        n += 1
    return n


def question_walks(new, old, max_ply, report):
    print('\n4. The harness games leave the book where the simulation said')
    names = sorted(os.path.basename(p)[:-len('_plain.pgn')]
                   for p in glob.glob(os.path.join(GAMES, '*_plain.pgn')))
    report.check(len(names) == 13, 'thirteen harness games (found %d)' % len(names))
    print('        %-28s %s' % ('game', 'old all / old twice+ / new'))
    for name in names:
        boards = positions_of(os.path.join(GAMES, name + '_plain.pgn'))
        every = walked(old, boards, lambda c: c > 0, max_ply=30)
        twice = walked(old, boards, lambda c: c > 1, max_ply=30)
        # Every row, the way the server reads it. Filtering to two games here
        # would let an unpruned file walk exactly like a pruned one — which the
        # first version of this check did.
        now = walked(new, boards, lambda c: c > 0, max_ply=max_ply)
        print('        %-28s %2d / %2d / %2d' % (name, every, twice, now))
        report.check(now == twice, '%s: the new file stops where pruning the old one did' % name)
        if name in PLAN_SAYS:
            report.check((every, twice) == PLAN_SAYS[name],
                         '%s: the plan printed %d / %d' % ((name,) + PLAN_SAYS[name]))
        elif name in SHORTER_BY_ONE:
            report.check(every - twice == 1, '%s: the plan said one ply shorter' % name)
        elif name in UNCHANGED:
            report.check(every == twice, '%s: the plan said unchanged' % name)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--old', required=True, help='the file being replaced')
    parser.add_argument('--new', required=True, help='the file being checked')
    parser.add_argument('--max-ply', type=int, default=50, help='the depth the new file was built to')
    parser.add_argument('--games-only', action='store_true', help='skip question 3, the long one')
    args = parser.parse_args()

    report = Report()
    new, old = open_ro(args.new), open_ro(args.old)
    question_meta(new, old, args.max_ply, report)
    question_games(new, old, report)
    if not args.games_only:
        question_rows(args.new, args.old, report)
    question_walks(new, old, args.max_ply, report)

    if report.failures:
        print('\n%d check(s) failed:' % len(report.failures))
        for what in report.failures:
            print('  - %s' % what)
        sys.exit(1)
    print('\nEvery check passed.')


if __name__ == '__main__':
    main()
