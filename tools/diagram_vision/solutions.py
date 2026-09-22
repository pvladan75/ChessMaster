"""Phase 0 of docs/PLAN-SKENER-SLIKE.md: a puzzle book's solutions, as the
check the plan relies on (D3): the book's own line must replay from the board
that was read. It is a check, never a repair — nothing here changes a board.

Reads solutions written as "(41) 1.Bg1! (Threatens 2.Bxf6 ...) 1...g6 2.Bxf6!"
and joins them to the boards extract.py cut out, by the number printed on the
diagram's page.

    python solutions.py BOOK.pdf OUT_DIR --from PAGE

Adds to each board in OUT_DIR/index.json: `number`, `to_move` ('w' or 'b')
and `solution` (the main line's moves, comments in brackets dropped).
"""
import argparse
import json
import os
import re

import pymupdf

# An entry starts a line; it may open with prose ("(1) White piles up on the
# pinned piece: 1.Rd1!"), so nothing is assumed about what follows it.
ENTRY = re.compile(r'(?m)^\((\d{1,4})\)\s+')


def strip_brackets(text):
    """The text with every bracketed comment removed, nested ones included."""
    out, depth = [], 0
    for ch in text:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    return ''.join(out)


SAN_RE = (r'(?:[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](?:(?:=|/)?[QRBN])?'
          r'|O-O(?:-O)?)[+#]?[!?]*')
NUMBERED = re.compile(r'\s*(\d+)\.(\.\.)?\s*(' + SAN_RE + r')'
                      r'(?:\s+(' + SAN_RE + r'))?')


def san(tok):
    """A move as python-chess reads it: "e1/Q" is "e1=Q", marks dropped."""
    return re.sub(r'[!?]+$', '', tok.replace('/', '='))


def main_line(body):
    """(side to move, [SAN]) of one solution, or None if it does not start
    with a move.

    Only the moves that follow one another without a break count: numbered
    in order, nothing but a comment in brackets between them. The line ends
    at the first word — "Resigns", "mate", the prose after it — so a move
    quoted in the explanation is never taken for the next one."""
    body = strip_brackets(body)
    first = re.search(r'1\.(\.\.)?\s*[KQRBNa-hO]', body)
    if not first:
        return None
    to_move = 'b' if first.group(1) else 'w'
    moves, pos, expect = [], first.start(), 1
    while True:
        m = NUMBERED.match(body, pos)
        if not m or int(m.group(1)) != expect:
            break
        black_only = bool(m.group(2))
        if black_only and moves and to_move == 'w':
            break
        moves.append(san(m.group(3)))
        if m.group(4) and not black_only:
            moves.append(san(m.group(4)))
        elif not black_only or m.group(4):
            pos = m.end()
            break
        pos = m.end()
        expect += 1
    return to_move, moves


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pdf')
    ap.add_argument('root')
    ap.add_argument('--from', dest='start', type=int, required=True,
                    help='first page of the solutions section (0-based)')
    args = ap.parse_args()

    doc = pymupdf.open(args.pdf)
    text = '\n'.join(doc[i].get_text()
                     for i in range(args.start, doc.page_count))
    text = text.replace('…', '...')
    parts = ENTRY.split(text)
    solutions = {}
    for i in range(1, len(parts) - 1, 2):
        n, body = int(parts[i]), parts[i + 1]
        line = main_line(body)
        if line and n not in solutions:
            solutions[n] = line

    index = json.load(open(os.path.join(args.root, 'index.json')))
    joined = 0
    for e in index:
        if 'file' not in e:
            continue
        # The number is the page's last line; a section heading ("White
        # Moves First") can stand above it.
        lines = [ln.strip() for ln in doc[e['page']].get_text().splitlines()
                 if ln.strip()]
        if not lines or not lines[-1].isdigit():
            continue
        e['number'] = int(lines[-1])
        if e['number'] in solutions:
            e['to_move'], e['solution'] = solutions[e['number']]
            joined += 1
    json.dump(index, open(os.path.join(args.root, 'index.json'), 'w'), indent=1)
    boards = sum(1 for e in index if 'file' in e)
    print(f'{len(solutions)} solutions read; {joined} of {boards} boards '
          f'joined to one')


if __name__ == '__main__':
    main()
