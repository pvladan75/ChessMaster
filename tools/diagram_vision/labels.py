"""Phase 0 of docs/PLAN-SKENER-SLIKE.md: the true position of a diagram, taken
from the book's own text rather than from anyone's eyes.

An opening book prints the line that reaches a diagram just before it
("1 e4 e5 2 Nf3 Nc6 3 d4 exd4 4 Bc4"). Replaying that line with python-chess
gives the position exactly. A diagram gets a label only when one of the last
text blocks before it, in reading order, holds a whole line from move 1 that
replays without one illegal or unreadable move, up to the end of its sentence
or bracket. Anything else is left unlabelled and counted, never guessed.

    python labels.py BOOK.pdf OUT_DIR      # OUT_DIR from extract.py
"""
import json
import os
import re
import sys

import chess
import pymupdf

MOVE_NO = re.compile(r'^\d+\.*$')
SAN = re.compile(
    r'^([KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](=?[QRBN])?|O-O(-O)?)[+#]?$')


def blocks_in_reading_order(page):
    """Text blocks of a two-column page, left column first, top to bottom."""
    mid = page.rect.width / 2
    out = []
    for b in page.get_text('blocks'):
        x0, y0, x1, y1, text = b[:5]
        if b[6] != 0:
            continue
        col = 0 if (x0 + x1) / 2 < mid else 1
        out.append((col, y0, y1, text.strip()))
    return sorted(out, key=lambda t: (t[0], t[1]))


def candidates(text):
    """Every stretch of `text` that starts at move 1, in order; the last one is
    the nearest to the diagram."""
    text = text.replace('\xad\n', '').replace('\n', ' ')
    text = re.sub(r'\.\s*\.\s*\.', '...', text)
    # The OCR reads the digit 1 as l or I at the start of a line ("l...e5",
    # "I e4"). Only there, and the moves after it must still replay, so this
    # cannot invent a label.
    text = re.sub(r'(^|[\s(])[lI](?=\s*\.*\s*[a-hKQRBNO][a-h1-8x-])',
                  r'\g<1>1 ', text)
    return [m.group(1) for m in
            re.finditer(r'(?:^|[\s(])(1\s*\.?\s+[^();:,]*)', text)]


def clean(tok):
    """A token with its move number, dots and annotation marks taken off."""
    tok = re.sub(r'^\d+\.*', '', tok).lstrip('.').rstrip('.')
    tok = re.sub(r'[!?]+$', '', tok)
    return tok.replace('0-0-0', 'O-O-O').replace('0-0', 'O-O')


PROSE = {'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'if', 'in', 'is',
         'it', 'now', 'of', 'on', 'or', 'so', 'the', 'to', 'was', 'we',
         'who', 'with'}


def ending(tok):
    """Whether `tok` is a word a move line can end at."""
    word = tok.strip('.,;:!?"\'')
    if not word:
        return True
    if any(ch.isdigit() for ch in word):
        return False
    return len(word) > 3 or word.lower() in PROSE


def replay(text):
    """The board after `text`, or None if it is not a whole line from move 1.

    The line ends at the first word that is neither a move nor a move number,
    and every move before that must be legal. Move numbers must count up in
    step with the moves, which catches a line that skips or repeats."""
    tokens = text.split()
    if not tokens or not re.match(r'^1\.*$', tokens[0]):
        return None
    board = chess.Board()
    played = 0
    for tok in tokens:
        m = re.match(r'^(\d+)\.*', tok)
        if m:
            if int(m.group(1)) != board.fullmove_number:
                return None
        core = clean(tok)
        if not core:
            continue
        if not SAN.match(core):
            # A line may end only at a real word. A short or digit-bearing
            # token here is a move the OCR mangled ("dS", "NO", "Rbl"), and
            # stopping before it would label the position a move too early —
            # measured: it did, on 7 of the first 73 labels.
            if not ending(core):
                return None
            break
        try:
            board.push_san(core)
        except ValueError:
            return None
        played += 1
    return board if played >= 2 else None


def main(pdf, out_dir):
    doc = pymupdf.open(pdf)
    index = json.load(open(os.path.join(out_dir, 'index.json')))
    boards = [e for e in index if 'file' in e]
    labelled = 0
    reasons = {}
    for e in boards:
        for k in ('fen', 'line', 'label_refused', 'text_before'):
            e.pop(k, None)
        page = doc[e['page']]
        mid = page.rect.width / 2
        x0, y0, x1, y1 = e['rect'][0]
        col = 0 if (x0 + x1) / 2 < mid else 1
        before = [b for b in blocks_in_reading_order(page)
                  if (b[0], b[2]) <= (col, y0 + 1)]
        if not before:
            e['label_refused'] = 'nothing before it on the page'
        else:
            text = '\n'.join(b[3] for b in before[-3:])
            e['text_before'] = text
            board = None
            for cand in reversed(candidates(text)):
                board = replay(cand)
                if board is not None:
                    e['line'] = cand.strip()
                    break
            if board is None:
                e['label_refused'] = 'no whole line before it'
            else:
                e['fen'] = board.fen()
                labelled += 1
        r = e.get('label_refused')
        if r:
            reasons[r] = reasons.get(r, 0) + 1
    json.dump(index, open(os.path.join(out_dir, 'index.json'), 'w'), indent=1)
    print(f'{labelled} of {len(boards)} boards labelled from the text')
    for r, n in reasons.items():
        print(f'  {r}: {n}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
