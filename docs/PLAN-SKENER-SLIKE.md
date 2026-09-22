# Plan: reading diagrams that are pictures

Written 22.9.2026 at the owner's request, after the owner brought back an idea first
discussed with Gemini: find the board on the page, cut it into 64 squares,
classify each square with a small neural network, and write the FEN. Nothing in
this plan is in code. **Phase 0 is a measurement, and nothing after it gets built
unless its numbers say so** (§5).

`PLAN-ZAVRSNICA.md` froze new capabilities on 8.9.2026, and this plan adds one.
The owner asked for it, so it is written down; the freeze is the owner's to
lift, and phase 0 gives that decision something to stand on.

## 1. The request

The owner, 22.9.2026 (paraphrased from Serbian): *should we let the scanner read
books that have no chess font — scanned pages, or diagrams that are images?*

The pitch the owner forwarded has two halves:

1. **Text:** OCR the moves, then recover a misread piece letter from context and
   legality (a knight read as `H` becomes `N`), and map the piece letters of
   each language (S/N, L/B, D/Q, T/R) to SAN.
2. **Diagrams:** detect the board, split it 8 × 8, classify each square with a
   CNN (empty, or one of twelve pieces), write the FEN, and check that the FEN is
   legal.

It calls the result "100% reliable". It is not, and §3 says why.

## 2. What exists, measured

- **The scanner reads a font, not a picture** (`chess_backend/services/
  positionScanner/`, README in Serbian). Eight rows of glyphs in one column
  make a diagram. Glyph maps are chosen by alphabet, and there are two of them.
  An unknown glyph is an error, **never an empty square**.
- **Every position is checked against the book's own solution move.** On the
  first book, 4436 of 4437 moves were legal in the position read. This is a
  much stronger check than "both kings are on the board", because a misread
  piece usually makes the book's move illegal. §3 builds on it.
- **Castling and en passant are never guessed.** They are set only when the
  solution move proves them, and the fix is recorded in `repairs`.
- **The owner's four books, measured 5.9.2026** (`STANJE-RADA.md`, „Skener kaže
  koji je od tri problema"):

  | Book | What it is | Which path could read it |
  |---|---|---|
  | Reinfeld, the book of 1001 sacrifices | 252 pages, no text, one image per page, **92 dpi** | image path; the resolution is the question |
  | *Complete Book of Chess Strategy* | 388 pages, no text, one image per page, 400 dpi | image path |
  | *Back to Basics: Openings* | OCR text exists; 433 diagrams are images | image path; **the best candidate**, since its text could give the solution check |
  | *Grandmaster Codex* | LaTeX text, boards drawn as **vector paths** | neither; see §6 |

  `classifyUnreadable` (`diagrams.mjs`) already tells these apart: `no_text`,
  `no_diagram_text` or `unknown_font`.
- **The door:** until 22.9.2026 the only way in was the Analysis bar. Since that
  day there is also a „Scan a book" card on Teach (`teach_tab.dart`).

## 3. Where the pitch is wrong, and what follows from it

1. **A classifier is probabilistic.** Missing kings are not the dangerous error.
   The dangerous one is a bishop read as a pawn, which gives a **legal position
   that looks right**. That is exactly why the font scanner was written to fail
   loudly (decision of 4.9.2026, `STANJE-RADA.md`). So:
   **D1: the image path is separate.** It is marked on every result, carries a
   confidence for each square, and saves nothing until a person has confirmed
   the board. It is never a silent fallback behind the font path.
2. **The picture does not contain the whole FEN.** Side to move, castling, en
   passant, and whether the diagram is printed from Black's side all come from
   the caption or the solution, not from the board.
   **D2: none of these is guessed.** The confirmation screen asks who is on the
   move. Castling and en passant follow the font path's rule: set only when the
   solution proves them, otherwise off.
3. **Fixing OCR'd moves by legality is the same hazard in text.** "Pick the
   legal move that fits best" turns a misread into a plausible move nobody
   checked. The server also has no PGN parser and must not grow one (rule 13 of
   `CLAUDE.md`), so python-chess on the server is out.
   **D3: text-move recovery is out of this plan.** When a solution move can be
   read, it is used the way the font path uses it: **a check, never a repair**.
   If the move is not legal in the classified position, the board is flagged
   for confirmation and nothing is changed.
4. **Legality alone catches too little.** The number that decides everything is
   the share of boards that are wrong *and* pass every check. §5 measures it
   directly.

What works in our favour: the app has several piece sets and the database holds
thousands of known FENs. **Unlimited labelled training diagrams can be
generated**, with print-like damage added (blur, noise, low resolution, yellowed
paper, a slight skew). Only the test set needs labelling by hand.

## 4. Phases

Each phase is briefed only after the one before it closes. Who carries a phase
is written beside it when it is briefed.

### Phase 0 — measure, no app or server code [lead]

Everything lives in `tools/diagram_vision/`, the same kind of hand-run tooling
as `tools/tutorial_translate/`. Nothing goes into `chess_app/` or
`chess_backend/`.

1. **Test set:** about 50 diagrams from *Back to Basics* and 30 from Reinfeld,
   taken from pages spread across each book, not one chapter. Each board's
   placement is labelled by hand in the app's position editor. Record for each
   board whether its solution can be read from the text.
2. **Detection:** out of all the diagrams on those pages, how many are found,
   how many are missed, and how many false boards are "found".
3. **Two classifiers, measured on the same test set:**
   - **(a)** an existing open-source board recogniser. Survey the candidates
     first. None is assumed to fit: most are trained on screenshots of online
     boards, not on print.
   - **(b)** a small classifier trained only on synthetic diagrams (§3).
4. **The numbers**, for each classifier and each book:
   - share of squares read correctly;
   - share of boards read with **no error at all**;
   - **silently wrong:** share of boards that are wrong but legal, and, where a
     solution is readable, where the solution is also legal. This is the number
     §5 turns on.
   - how well the per-square confidence points at the wrong squares: of all the
     wrong squares, how many are among those marked uncertain.
5. Write the numbers in §7 of this file, whichever way they come out.

**Gate (the owner's decision, not a test):** proposed thresholds, for the
owner to accept or change:

- **Build** if, on *Back to Basics*, at least **90% of boards come out
  error-free**, and at most **1% of boards are silently wrong** once uncertain
  squares are marked. At that rate the confirmation screen means fixing a square
  or two, not setting the board up again.
- Otherwise **stop**, and record why.

Reinfeld is reported separately. 92 dpi may simply be too little, and a "no"
there says nothing about the plan as a whole.

### Phase 1 — find and cut out the board

Only after phase 0 says go. Where it runs is decided by phase 0's findings:

- a Node server with `onnxruntime-node`;
- a Python sidecar;
- on the device.

Rendering PDF pages to images needs a canvas, which is a native dependency and a
change to `deploy/`. That cost is counted before the choice. The server's upload
limits stay as they are (25 MB, 20 scans per 15 minutes per account).

### Phase 2 — classify, with confidence

- The output carries `source: 'image'` and a confidence for each square.
- The font path's result shape is extended, not forked. A reader that does not
  know `source` must not take an image result as a font result (rule 11:
  absence is a third answer).
- There is a new failure code beside `no_text`, `no_diagram_text` and
  `unknown_font`, and `scanFailureMessage` gets its sentence.

### Phase 3 — the confirmation screen

- The classified board, with uncertain squares marked by **shape**, not only by
  colour. The owner is colourblind, so a live check by the owner proves
  shape and brightness, never hue.
- The question of who is on the move.
- The solution check's verdict, when the solution could be read.
- Nothing is saved until it is confirmed. A correction is made on the board, in
  the editor the app already has.

### Phase 4 — into exercises

The confirmed positions go into the existing flow: the saved scans, then
„Make exercise" (phase 14 of `PLAN-EXERCISE.md`). No new way to save.

### Phase 5 — the owner's live pass

## 5. What decides it

One number: **silently wrong boards after confirmation marks.** A scanner that
is often unsure is annoying. One that is sometimes wrong without saying so
teaches a student a position that was never in the book, and that is the thing
this project has refused since 4.9.2026.

## 6. Not in this plan

- **Photographs from a camera.** Perspective, light and a bent page make this a
  different problem. The manual says plainly that the scanner is not a camera,
  and this plan does not change that.
- **Text OCR of move notation**, with or without recovery by legality (D3).
- **Vector-drawn boards** (*Grandmaster Codex*: 177 paths and 71 fills inside
  one 288 × 288 square). These can probably be read **exactly** from the
  drawing, with no probability involved, so they deserve a small look of their
  own. It would be a deterministic path, closer to the font scanner than to
  this plan.
- **Solving your own exercises for practice** (item 5 of the owner's questions
  of 20.9.2026 in `STANJE-RADA.md`). Without it, a scanned exercise can reach
  only a student. It is a separate plan, and arguably the one that makes this
  one worth doing.

## 7. Measurements

*Empty until phase 0 runs.*
