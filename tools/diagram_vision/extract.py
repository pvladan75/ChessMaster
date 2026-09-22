"""Phase 0 of docs/PLAN-SKENER-SLIKE.md: cut diagram images out of a PDF and
find the 8 x 8 grid inside each one.

A diagram image usually carries more than the board: rank numbers down the
left, sometimes file letters under it. The grid is the largest near-square
dark frame in the image; everything outside it is thrown away.

    python extract.py BOOK.pdf OUT_DIR
    python extract.py BOOK.pdf OUT_DIR --scan [--pages 40-120]

The first form is for a PDF whose diagrams are images of their own. `--scan`
is for a book scanned whole-page: each page is rendered and its boards are
found by shape — a square outline whose inside alternates light and dark in
an 8 x 8 pattern.

Writes OUT_DIR/<page>_<xref>.png (the board only, resized to 512 x 512) and
OUT_DIR/index.json with the page, the image's rectangle on the page, and why
an image was refused. Nothing from a book is ever committed: OUT_DIR belongs
in a scratch directory.
"""
import json
import os
import sys

import cv2
import numpy as np
import pymupdf

BOARD = 512


def find_board(gray):
    """The board's square inside a diagram image, or None.

    Dark squares are hatched or grey, so the frame is found from long straight
    runs of ink: a row or column counts as a frame line when most of it is
    dark. The board is the box between the outermost such lines, and it must
    be close to square.
    """
    ink = gray < 128
    h, w = ink.shape
    rows = np.where(ink.mean(axis=1) > 0.6)[0]
    cols = np.where(ink.mean(axis=0) > 0.6)[0]
    if len(rows) < 2 or len(cols) < 2:
        return None
    top, bottom = rows.min(), rows.max()
    left, right = cols.min(), cols.max()
    bh, bw = bottom - top, right - left
    if bh < 0.5 * h or bw < 0.5 * w:
        return None
    if abs(bh - bw) > 0.06 * max(bh, bw):
        return None
    return int(top), int(bottom), int(left), int(right)


SCAN_DPI = 200


def checkered(gray):
    """Whether a square crop alternates light and dark as a board does.

    The mean of each of the 64 cells, split by colour: every light cell must
    be lighter than the darkest dark one on average, and the two means must
    differ clearly. Pieces sit on some cells, so medians are compared."""
    h = gray.shape[0] // 8
    cells = np.array([[gray[r * h + h // 4:(r + 1) * h - h // 4,
                            c * h + h // 4:(c + 1) * h - h // 4].mean()
                       for c in range(8)] for r in range(8)])
    light = np.array([cells[r, c] for r in range(8) for c in range(8)
                      if (r + c) % 2 == 0])
    dark_ = np.array([cells[r, c] for r in range(8) for c in range(8)
                      if (r + c) % 2 == 1])
    return np.median(light) - np.median(dark_) > 25


def boards_on_page(gray):
    """Boxes (top, bottom, left, right) of the boards on a rendered page."""
    w = gray.shape[1]
    ink = (gray < 150).astype(np.uint8)
    contours, _ = cv2.findContours(ink, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    # Largest first, so where a board has an inner and an outer frame the
    # outer one wins (measured: keeping the inner one cut the h-file short).
    # No test on the outline being closed: a scanned frame is sometimes
    # broken, and the checkered test below is the stronger one.
    rects = sorted((cv2.boundingRect(c) for c in contours),
                   key=lambda r: -r[2] * r[3])
    found = []
    for x, y, cw, ch in rects:
        if cw < 0.15 * w or cw > 0.9 * w or abs(cw - ch) > 0.05 * cw:
            continue
        crop = gray[y:y + ch, x:x + cw]
        if not checkered(crop):
            continue
        box = find_board(crop)
        if box is None:
            continue
        t, b, l, r = box
        box = (y + t, y + b, x + l, x + r)
        if any(box[0] < f[1] and f[0] < box[1] and box[2] < f[3]
               and f[2] < box[3] for f in found):
            continue
        found.append(box)
    return found


def scan_pages(doc, out_dir, first, last):
    index = []
    for pno in range(first, last + 1):
        pix = doc[pno].get_pixmap(dpi=SCAN_DPI, colorspace=pymupdf.csGRAY,
                                  alpha=False)
        gray = np.frombuffer(pix.samples, np.uint8).reshape(
            pix.height, pix.stride)[:, :pix.width]
        for k, (t, b, l, r) in enumerate(boards_on_page(gray)):
            board = cv2.resize(gray[t:b + 1, l:r + 1], (BOARD, BOARD),
                               interpolation=cv2.INTER_AREA)
            name = f'{pno:04d}_{k}.png'
            cv2.imwrite(os.path.join(out_dir, name), board)
            index.append({'page': pno, 'file': name, 'box': [t, b, l, r],
                          'dpi': SCAN_DPI})
    return index


def main(pdf, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    doc = pymupdf.open(pdf)
    index = []
    for pno in range(doc.page_count):
        page = doc[pno]
        for im in page.get_images():
            xref, w, h = im[0], im[2], im[3]
            rects = page.get_image_rects(xref)
            entry = {'page': pno, 'xref': xref, 'size': [w, h],
                     'rect': [list(r) for r in rects]}
            if not (200 <= w <= 2000 and 0.8 <= w / h <= 1.25):
                entry['refused'] = 'not diagram-shaped'
                index.append(entry)
                continue
            pix = pymupdf.Pixmap(doc, xref)
            if pix.n - pix.alpha > 1:
                pix = pymupdf.Pixmap(pymupdf.csGRAY, pix)
            gray = np.frombuffer(pix.samples, dtype=np.uint8).reshape(
                pix.height, pix.width, pix.n)[:, :, 0]
            box = find_board(gray)
            if box is None:
                entry['refused'] = 'no frame'
                index.append(entry)
                continue
            t, b, l, r = box
            board = cv2.resize(gray[t:b + 1, l:r + 1], (BOARD, BOARD),
                               interpolation=cv2.INTER_AREA)
            name = f'{pno:04d}_{xref}.png'
            cv2.imwrite(os.path.join(out_dir, name), board)
            entry['file'] = name
            entry['box'] = list(box)
            index.append(entry)
    with open(os.path.join(out_dir, 'index.json'), 'w') as f:
        json.dump(index, f, indent=1)
    kept = sum(1 for e in index if 'file' in e)
    print(f'{kept} boards, {len(index) - kept} images refused')
    for reason in sorted({e.get("refused") for e in index} - {None}):
        print(f'  {reason}: {sum(1 for e in index if e.get("refused") == reason)}')


if __name__ == '__main__':
    if '--scan' in sys.argv:
        pages = sys.argv[sys.argv.index('--pages') + 1] if '--pages' in sys.argv else None
        doc = pymupdf.open(sys.argv[1])
        first, last = (map(int, pages.split('-')) if pages
                       else (0, doc.page_count - 1))
        os.makedirs(sys.argv[2], exist_ok=True)
        index = scan_pages(doc, sys.argv[2], first, last)
        with open(os.path.join(sys.argv[2], 'index.json'), 'w') as f:
            json.dump(index, f, indent=1)
        print(f'{len(index)} boards on pages {first}-{last}')
    else:
        main(sys.argv[1], sys.argv[2])
