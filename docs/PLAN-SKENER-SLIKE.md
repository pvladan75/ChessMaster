# Plan: reading diagrams that are pictures

Written 22.9.2026 at the owner's request, after the owner brought back an idea first
discussed with Gemini: find the board on the page, cut it into 64 squares,
classify each square with a small neural network, and write the FEN. Nothing in
this plan is in the app or the server. **Phase 0 is a measurement, and nothing
after it gets built unless its numbers say so** (§5). Phase 0 ran on 22.9.2026;
its numbers and the decision they leave the owner are in §7.

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

### Phase 0 — measure, no app or server code [lead] — done 22.9.2026, §7

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

Phase 0 ran on 22.9.2026, lead, with the tooling in `tools/diagram_vision/`
(its README says how to repeat each number). The three books are the owner's.
Nothing from them is in the repository.

### The owner's decisions on it, 22.9.2026

1. **Phase 1 goes ahead now.** No 300-board truth set first: the owner takes
   Reinfeld's 98.3% and *Back to Basics*' 98.1% as confidence enough, knowing
   that the 1% ceiling is not proven at this size. Marks and confirmation (D1)
   stay mandatory, and they are what stands behind that choice.
2. **The freeze is lifted for this plan**: it is recorded in
   `PLAN-ZAVRSNICA.md` among the additions after the freeze.
3. **The third font map** (`DiagramTTFritz`, §7.4) goes to the backlog.

### Result, against the gate in §4

| Book | What it is | Truth | Boards with no error | Silently wrong |
|---|---|---|---|---|
| *Back to Basics: Openings* | one image per diagram; hatched squares, a scan | the line printed before the diagram, replayed (§7.1) | **51 / 52** (3326 / 3328 squares) | **0**; both wrong squares marked |
| Reinfeld, 1001 sacrifices, 21st-century edition | 350 px digital renders, one per page | the book's solutions, as the D3 check | whole solution replays on **978 / 995**; 16 random passing boards read square by square by eye, none wrong | none found |
| Silman, *Complete Endgame Course* | whole pages scanned at 300 dpi, no text layer | 24 random boards read by eye, kept out of training | **23 / 24** | **0**; the one wrong square marked |

**The first threshold passes.** The gate asks for 90% of boards with no error on
*Back to Basics*; the measurement is 98.1%.

**The second threshold cannot be shown at this size, either way.** The gate
asks for at most 1% silently wrong. No silently wrong board was seen in the 76
boards with a known truth (52 + 24). But zero in 76 only bounds the true rate
below about 4% (the rule of three, 95%). Showing 1% needs about 300 truth boards
with none silently wrong. Before phase 1, **the owner decides** whether to
build on this, or to build a larger truth set first. The cheapest source of one
is the Reinfeld book, whose 16 checked boards took minutes to read.

### What reads them — no neural network

Every book is read with **templates taken from 3 to 8 of its own boards,
labelled by eye** — here by the lead; every label and truth set in this
section was read by the lead, not the owner, and that is its main weakness (*Back to Basics* 5, Reinfeld 3, Silman 8). This is the image
path's counterpart to the font scanner's glyph map, chosen per book:

- A class the labelled boards never showed is composed from the same piece on
  the other square colour.
- Each square is binarised, then compared with every training square, sliding
  up to 10 px. The nearest one wins.

**The same setting held on all three books.** It was chosen on Silman's truth
set, then run unchanged on the other two, which moved not at all (51/52, 978/995).

**For phase 3 this is a design, not only a result.** The first boards a trainer
confirms from a new book can *be* that book's templates. The confirmation
screen is the training.

How each change moved the numbers, since two of the three were not obvious
beforehand:

| Change | *Back to Basics* | Reinfeld (whole line replays) | Silman truth set |
|---|---|---|---|
| mean template per class, square shrunk to 24 px | 67–92% by split | 46.6% | 5 / 24 |
| solution parser read only the moves that follow one another | — | 68.1% | — |
| unseen classes composed | — | 75.9% | — |
| full size, template slides 4 px | 98.1% | 98.3% | 5 / 24 |
| slides 10 px, binarised, nearest example | 98.1% | 98.3% | **23 / 24** |

**Shrinking the square was the costly mistake.** The only thing that tells a
white piece on a light square from the empty square is a thin outline, and
shrinking erased it. A white rook on a light square read as empty, and was not
marked.

**A scan needs the wide slide.** Silman's squares sit several pixels off a
regular grid, so the slide alone moved it from 5 to 15.

### 7.1 Labels from the text are not truth

*Back to Basics* labels come from replaying the line printed just before a
diagram. Even with every move required to replay, **9 of 66 labels described
another position than the picture.** In most cases the diagram shows the
position a few moves later, where the next heading continues. One more label
was corrected by eye and kept.

The first version of the labeller was worse. It stopped at the first move the
OCR had mangled ("dS", "NO") and labelled the position from before it. That is
the "line cut short" hazard §3 warns about, found in the phase's own tool.

**This supports D3:** text is a check on a reading, never the reading.

### 7.2 Detection

| Book | Diagrams cut out |
|---|---|
| *Back to Basics* | 391 boards from 433 images: 40 refused as not diagram-shaped (rules, logos), 2 refused for having no frame (not inspected). Of 24 random crops, all were whole boards. |
| Reinfeld | 1002 from 1006; the 4 refused are the cover and the logos. |
| Silman | Pages rendered and searched for a square outline whose inside alternates light and dark: **648 boards in 543 pages in 24 s**. Of 32 random finds, all 32 are boards cut correctly. Recall cannot be counted without text, but pages 40–55, read by eye, lost none. |

### 7.3 What still goes wrong

- **The edge ranks of a scan.** Silman gives 24 of 640 boards that are not
  legal positions. Of 8 looked at:
  - 3 are teaching diagrams that are not positions (no kings, or crosses and
    two white kings). Flagging them is right.
  - 5 are misreads, all on rank 1 or 8: a black king read as a pawn, as a
    queen, or as a white king; a rook on g8 read as a pawn.
  - **Every wrong square on them was marked.**
- **Teaching marks** (crosses, dashed lines) read as pieces, always marked. A
  trainer confirming the board removes them, which is what D1 requires.
- **Marks are not calibrated.** Between 1.1 (Reinfeld) and 11 (*Back to
  Basics*, depending on the split) uncertain squares per board. The truth sets
  hold only 3 wrong squares in all, too few to calibrate a threshold on. This
  belongs to phase 3's screen. A threshold tuned on three errors would be a
  number without a measurement behind it.
- **The Reinfeld failures that were inspected are the book's text, not the
  reading.** 8 of the 17 boards whose solution does not replay were looked at
  square by square, and none was misread. Examples:
  - 41's "1.Bg1" cannot be played on the board the diagram draws;
  - 42 moves its king onto its own rook;
  - promotions written `e1/Q`.

### 7.4 The font path, in passing

- The six small endgame PDFs in the owner's second folder are set in
  `DiagramTTFritz`. The font scanner has no map for it: "Nijedna mapa fonta ne
  objašnjava dijagrame". That is a third map, made with `derive.mjs` and
  `identify.mjs`, and not part of this plan.
- `completechesscoursexcerpt.pdf` (`LinaresDiagram`) already reads with the
  Tactics Course map: 7 diagrams.
