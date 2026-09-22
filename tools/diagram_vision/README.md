# diagram_vision — phase 0 of `docs/PLAN-SKENER-SLIKE.md`

Hand-run measurement tooling for reading chess diagrams that are pictures. It is
not part of the app or the server. The numbers it produced are in §7 of the plan.

**Nothing from a book is ever committed.** Every output directory (board crops,
`index.json`, labels, reports) goes in a scratch directory outside the repository.

Needs Python 3 with `pymupdf`, `opencv-python`, `numpy` and `chess`. There is no
neural network and no GPU.

## Steps

```bash
# 1. Cut the boards out.
python extract.py BOOK.pdf OUT                 # diagrams are images of their own
python extract.py BOOK.pdf OUT --scan          # whole pages scanned

# 2. Labels, where the book gives them.
python labels.py BOOK.pdf OUT                  # opening book: the line printed before a diagram
python solutions.py BOOK.pdf OUT --from PAGE   # puzzle book: the solutions, used as a check

# 3. Read and measure.
python classify.py OUT --train K --seed S      # labelled book: K boards train, the rest measured
python classify.py OUT --check                 # labels by eye as templates; check by solution
                                               # and by OUT/truth.json if present
```

## Files a person writes into OUT

| File | What it holds |
|---|---|
| `overruled.json` | `{file: reason}` for a label whose position differs from the picture: the board leaves the measurement. `{file: {"fen": …}}` corrects the label by eye and keeps the board in. |
| `truth.json` | `{file: fen}` read by eye, kept apart from the training boards. |
| `fen` / `ignore` in `index.json` | Training boards labelled by eye; `ignore` lists squares with a teaching mark (a dashed line, a cross) to keep out of training. |

## How it reads

- There are templates per book, taken from a few boards labelled by eye. This
  is the image path's counterpart to the font scanner's glyph map.
- A class the training boards never showed is composed from the same piece on
  the other square colour.
- Each square is binarised and matched against every training example, sliding
  up to 10 px. The nearest example wins, and the gap to the second-nearest
  class is the square's confidence.
- `DV_SHIFT`, `DV_BIN` and `DV_NN` switch those settings, so the measurement in
  §7 can be repeated with any of them off.
