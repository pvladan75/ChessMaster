"""Phase 0 of docs/PLAN-SKENER-SLIKE.md: read a board image square by square
with templates learned from a few boards of the same book, and measure it.

A book draws every piece the same way on every page, so the image path's
counterpart to the font scanner's glyph map is a set of templates per book.
Each square is compared with the mean image of every class (13 contents x
light/dark square) seen in the training boards; the nearest class wins, and
the gap to the second nearest is the square's confidence.

    python classify.py OUT_DIR [--train K] [--seed S] [--sheet]

OUT_DIR is the one extract.py and labels.py wrote. The labelled boards are
split at random: K for templates, the rest measured. The numbers printed are
the ones §4 of the plan asks for.
"""
import argparse
import json
import os
import random

import chess
import cv2
import numpy as np

CELL = 64          # extract.py writes 512 x 512 boards
INSET = 6          # keep grid lines and neighbours out of a square


# The three settings measured in docs/PLAN-SKENER-SLIKE.md §7. The defaults
# are the ones that held on all three books; the variables exist so the
# measurement can be repeated with any of them off.
SHIFT = int(os.environ.get('DV_SHIFT', 10))    # how far a square may sit off the grid
BINARIZE = os.environ.get('DV_BIN', '1') == '1'  # ink or paper, per board (Otsu)
NEAREST = os.environ.get('DV_NN', '1') == '1'    # nearest example, not class mean


def squares(img, pad=0):
    """The 64 squares of a board image, a8 first, lightly blurred.

    Compared at full size: the outline is all that tells a white piece on a
    light square from the empty square, and shrinking a square loses it —
    measured on Reinfeld, where a white rook on a light square read as empty
    and was not marked. `pad` widens each crop so a template can slide."""
    if BINARIZE:
        _, img = cv2.threshold(img, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    img = cv2.GaussianBlur(img, (3, 3), 0).astype(np.float32) / 255.0
    img = cv2.copyMakeBorder(img, SHIFT, SHIFT, SHIFT, SHIFT,
                             cv2.BORDER_REPLICATE)
    out = []
    for r in range(8):
        for c in range(8):
            y, x = r * CELL + SHIFT, c * CELL + SHIFT
            out.append(img[y + INSET - pad:y + CELL - INSET + pad,
                           x + INSET - pad:x + CELL - INSET + pad])
    return out


def truth(fen):
    """What should be on each square, a8 first: a piece letter or '.'."""
    board = chess.Board(fen)
    out = []
    for rank in range(7, -1, -1):
        for file in range(8):
            p = board.piece_at(chess.square(file, rank))
            out.append(p.symbol() if p else '.')
    return out


def dark(i):
    r, c = divmod(i, 8)
    return (r + c) % 2 == 1


def train(boards, root):
    sums = {}
    for e in boards:
        vecs = squares(cv2.imread(os.path.join(root, e['file']), 0))
        # Squares a label leaves out of training: a teaching mark drawn on
        # them (a dashed line, a cross) is neither a piece nor an empty square.
        skip = {chess.parse_square(q) for q in e.get('ignore', [])}
        for i, (v, t) in enumerate(zip(vecs, truth(e['fen']))):
            if chess.square(i % 8, 7 - i // 8) in skip:
                continue
            key = (t, dark(i))
            s = sums.setdefault(key, [np.zeros_like(v), 0])
            s[0] += v
            s[1] += 1
    templates = {k: s / n for k, (s, n) in sums.items()}
    compose_missing(templates)
    if NEAREST:
        # Every training square is its own template; a class keeps the best.
        EXAMPLES.clear()
        for e in boards:
            vecs = squares(cv2.imread(os.path.join(root, e['file']), 0))
            skip = {chess.parse_square(q) for q in e.get('ignore', [])}
            for i, (v, t) in enumerate(zip(vecs, truth(e['fen']))):
                if chess.square(i % 8, 7 - i // 8) not in skip:
                    EXAMPLES.append(((t, dark(i)), v))
        for k in COMPOSED:
            piece, colour = k.split('/')
            EXAMPLES.append(((piece, colour == 'dark'),
                             templates[(piece, colour == 'dark')]))
    return templates


EXAMPLES = []


# Classes put together rather than seen, by the last train() call; printed,
# because a composed template is a guess about the book's drawing.
COMPOSED = []


def compose_missing(templates):
    """Fill a class the training boards never showed — a white rook on a
    light square, say — from the same piece on the other colour.

    A diagram draws a piece over its square: inside the piece's outline the
    square does not show. So where the seen template differs from its own
    empty square, the piece is drawn; everywhere else the missing colour's
    empty square is. Without this, an unseen class can never be read and
    comes out as the nearest seen one (measured: a white rook on a light
    square read as an empty square on Reinfeld, 25 of 26 classes seen)."""
    COMPOSED.clear()
    for piece in 'PNBRQKpnbrqk':
        for is_dark in (False, True):
            if (piece, is_dark) in templates:
                continue
            seen = templates.get((piece, not is_dark))
            empty_seen = templates.get(('.', not is_dark))
            empty_want = templates.get(('.', is_dark))
            if seen is None or empty_seen is None or empty_want is None:
                continue
            drawn = np.abs(seen - empty_seen) > 0.15
            templates[(piece, is_dark)] = np.where(drawn, seen, empty_want)
            COMPOSED.append(piece + ('/dark' if is_dark else '/light'))


def read(img, templates):
    """Each square's best class, and the gap to the second best (0..).

    The distance to a class is the mean squared difference at the best of the
    shifts up to SHIFT pixels either way."""
    out = []
    for i, v in enumerate(squares(img, pad=SHIFT)):
        best_of = {}
        for k, m in (EXAMPLES if NEAREST else templates.items()):
            if k[1] != dark(i):
                continue
            res = cv2.matchTemplate(v, m, cv2.TM_SQDIFF)
            dist = float(res.min()) / m.size
            if dist < best_of.get(k[0], 1e9):
                best_of[k[0]] = dist
        d = sorted((dist, piece) for piece, dist in best_of.items())
        best = d[0]
        second = next(x for x in d[1:] if x[1] != best[1])
        out.append((best[1], second[0] - best[0]))
    return out


def placement(cells):
    rows = []
    for r in range(8):
        row, empty = '', 0
        for c in range(8):
            p = cells[r * 8 + c]
            if p == '.':
                empty += 1
            else:
                row += (str(empty) if empty else '') + p
                empty = 0
        rows.append(row + (str(empty) if empty else ''))
    return '/'.join(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--train', type=int, default=5)
    ap.add_argument('--seed', type=int, default=0)
    ap.add_argument('--uncertain', type=float, default=None,
                    help='gap below which a square is marked uncertain; '
                         'default: the 2nd percentile of training gaps')
    ap.add_argument('--check', action='store_true',
                    help='templates from every labelled board; every other '
                         'board with a solution is read and the solution '
                         'replayed from it (no truth needed)')
    args = ap.parse_args()
    if args.check:
        return check(args)

    index = json.load(open(os.path.join(args.root, 'index.json')))
    # Labels a person looked at and found to describe another position than
    # the one drawn: {file: reason}. They leave the measurement, and the
    # count of them is printed, so the exclusion is never silent.
    over_path = os.path.join(args.root, 'overruled.json')
    overruled = json.load(open(over_path)) if os.path.exists(over_path) else {}
    # A value that is a dict carries the position the picture shows, read by
    # eye: the board stays in the measurement with that label instead.
    for e in index:
        fix = overruled.get(e.get('file'))
        if isinstance(fix, dict):
            e['fen'] = fix['fen']
    labelled = [e for e in index if 'fen' in e
                and not isinstance(overruled.get(e['file']), str)]
    random.Random(args.seed).shuffle(labelled)
    tr, te = labelled[:args.train], labelled[args.train:]
    templates = train(tr, args.root)

    if args.uncertain is None:
        gaps = [g for e in tr
                for _, g in read(cv2.imread(os.path.join(args.root, e['file']), 0),
                                 templates)]
        args.uncertain = float(np.percentile(gaps, 2))

    sq_ok = sq_all = boards_ok = silent = partly = caught_wrong = wrong_sq = marked = 0
    illegal = 0
    report = []
    for e in te:
        cells = read(cv2.imread(os.path.join(args.root, e['file']), 0), templates)
        want = truth(e['fen'])
        got = [c for c, _ in cells]
        errs = [i for i in range(64) if got[i] != want[i]]
        unsure = [i for i, (_, g) in enumerate(cells) if g < args.uncertain]
        sq_ok += 64 - len(errs)
        sq_all += 64
        marked += len(unsure)
        wrong_sq += len(errs)
        caught_wrong += sum(1 for i in errs if i in unsure)
        side = e['fen'].split()[1]
        legal = chess.Board(placement(got) + f' {side} - - 0 1').is_valid()
        if not errs:
            boards_ok += 1
        else:
            if not legal:
                illegal += 1
            elif not set(errs) & set(unsure):
                silent += 1
            elif not set(errs) <= set(unsure):
                partly += 1
        report.append({'file': e['file'], 'page': e['page'], 'errors': [
            (chess.square_name(chess.square(i % 8, 7 - i // 8)), want[i], got[i])
            for i in errs], 'unsure': len(unsure), 'legal': legal})

    n = len(te)
    fixed = sum(isinstance(v, dict) for v in overruled.values())
    print(f'{len(overruled) - fixed} text labels overruled by the picture and '
          f'left out; {fixed} corrected by eye and kept')
    print(f'composed, not seen: {COMPOSED or "none"}')
    print(f'templates from {len(tr)} boards ({len(templates)} of 26 classes), '
          f'measured on {n}; uncertain below gap {args.uncertain:.4f}')
    print(f'  squares right         {sq_ok}/{sq_all} = {sq_ok / sq_all:.2%}')
    print(f'  boards with no error  {boards_ok}/{n} = {boards_ok / n:.1%}')
    print(f'  wrong, illegal        {illegal}')
    print(f'  SILENTLY WRONG        {silent}/{n} = {silent / n:.1%}  '
          f'(wrong, legal, no wrong square marked)')
    print(f'  partly marked         {partly}/{n}  '
          f'(wrong, legal, some wrong square not marked)')
    print(f'  wrong squares marked  {caught_wrong}/{wrong_sq}; '
          f'squares marked per board {marked / n:.1f}')
    json.dump(report, open(os.path.join(args.root, 'report.json'), 'w'), indent=1)


def replays(cells, to_move, solution):
    """How many of the solution's moves replay from the board read."""
    try:
        board = chess.Board(placement(cells) + f' {to_move} - - 0 1')
    except ValueError:
        return 0
    n = 0
    for san in solution:
        try:
            board.push_san(san)
        except ValueError:
            break
        n += 1
    return n


def check(args):
    """The measure for a book with no labels but its solutions: the D3 check,
    run over every board. A board whose whole line replays passed the check;
    that is not proof it was read right, only that nothing the line touches
    was misread."""
    index = json.load(open(os.path.join(args.root, 'index.json')))
    tr = [e for e in index if 'fen' in e]
    # Boards with no solution are read too; for them only legality is asked.
    te = [e for e in index if 'file' in e and 'fen' not in e]
    templates = train(tr, args.root)
    gaps = [g for e in tr for _, g in
            read(cv2.imread(os.path.join(args.root, e['file']), 0), templates)]
    cut = args.uncertain if args.uncertain is not None else float(
        np.percentile(gaps, 2))
    full = first = none = marked_boards = illegal = with_sol = 0
    marked_total = 0
    rows = []
    for e in te:
        cells = read(cv2.imread(os.path.join(args.root, e['file']), 0), templates)
        got = [c for c, _ in cells]
        unsure = [i for i, (_, g) in enumerate(cells) if g < cut]
        try:
            legal = chess.Board(placement(got) + ' w - - 0 1').is_valid() or                 chess.Board(placement(got) + ' b - - 0 1').is_valid()
        except ValueError:
            legal = False
        illegal += not legal
        if 'solution' in e:
            k = replays(got, e['to_move'], e['solution'])
            with_sol += 1
            full += k == len(e['solution'])
            first += k >= 1
            none += k == 0
        else:
            k = None
        marked_total += len(unsure)
        marked_boards += bool(unsure)
        rows.append({'file': e['file'], 'number': e.get('number'),
                     'read': placement(got), 'replayed': k,
                     'of': len(e.get('solution', [])), 'legal': legal,
                     'unsure': [
                         chess.square_name(chess.square(i % 8, 7 - i // 8))
                         for i in unsure]})
    n = len(te)
    print(f'composed, not seen: {COMPOSED or "none"}')
    print(f'templates from {len(tr)} boards ({len(templates)} of 26 classes); '
          f'{n} boards read; uncertain below gap {cut:.4f}')
    print(f'  not a legal position     {illegal}/{n}')
    if with_sol:
        print(f'  whole solution replays   {full}/{with_sol} = {full / with_sol:.1%}')
        print(f'  first move replays       {first}/{with_sol} = {first / with_sol:.1%}')
        print(f'  not even the first move  {none}/{with_sol}')
    print(f'  boards with a mark       {marked_boards}/{n}; '
          f'marks per board {marked_total / n:.2f}')
    json.dump(rows, open(os.path.join(args.root, 'check.json'), 'w'), indent=1)

    # A truth set read by eye, kept apart from the training boards: the only
    # measure of a book with neither labels nor solutions.
    tpath = os.path.join(args.root, 'truth.json')
    if os.path.exists(tpath):
        truth_set = json.load(open(tpath))
        by_file = {r['file']: r for r in rows}
        ok = silent = partly = wrong_sq = marked_wrong = 0
        for f, fen in truth_set.items():
            r = by_file[f]
            want = truth(fen)
            got = truth(r['read'] + ' w - - 0 1')
            errs = {chess.square_name(chess.square(i % 8, 7 - i // 8))
                    for i in range(64) if got[i] != want[i]}
            unsure = set(r['unsure'])
            wrong_sq += len(errs)
            marked_wrong += len(errs & unsure)
            if not errs:
                ok += 1
            elif not r['legal']:
                pass
            elif not errs & unsure:
                silent += 1
            elif not errs <= unsure:
                partly += 1
        m = len(truth_set)
        print(f'  truth set ({m}, by eye): boards with no error {ok}/{m}; '
              f'silently wrong {silent}; partly marked {partly}; '
              f'wrong squares marked {marked_wrong}/{wrong_sq}')


if __name__ == '__main__':
    main()
