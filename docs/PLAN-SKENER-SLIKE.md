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

### Phase 1 — find and cut out the board [lead] — done 22.9.2026

**Where it runs, decided by measurement.** It runs on the server, in Node, with
no new dependency. `pdfjs-dist`, which the font scanner already uses, returns a
page's images as pixels with no canvas: `getOperatorList` finds each
`paintImageXObject`, and `page.objs` holds the pixels. Measured on the three
books:

| Book | What pdfjs returns | Time per page |
|---|---|---|
| *Back to Basics* | 1-bit images, about 530 × 480 | 15–100 ms |
| Reinfeld | RGB, 350 × 350 | 10–40 ms |
| Silman | the whole page as one 1-bit image, 2007 × 2952 | about 20 ms |

So the font scanner keeps its rule of no Python and nothing new on the server.
Rendering a page is needed only for a board drawn in vectors, and that is out of
scope (§6).

**What it builds.** Everything goes into `chess_backend/services/positionScanner/`:

- `images.mjs` — a page's images as 8-bit grey, with each image's rectangle on
  the page, whatever the pdfjs kind: 1-bit, grey, RGB or RGBA.
- `boards.mjs` — the two finders from phase 0, ported:
  - `findBoard`, the frame inside a diagram image;
  - `boardsOnScan`, the boards on a scanned page: a square outline, largest
    first, whose inside alternates light and dark.

  It also crops a board to 512 × 512 by area averaging.
- `imageDiagrams.mjs` — `findImageDiagrams(filePath, {fromPage, toPage})`
  decides per image:
  - a diagram-shaped image is searched for a frame;
  - a page-sized image is searched as a scan.

  It returns each board with its page, its source (`image` or `scan`) and its
  box, and counts what it refused, **by reason**.

Nothing is reachable from a route yet. Phase 2 is the first phase with a
reading to hand back, and the route and its failure codes change there, once.

**Gate.** It lives in `services/positionScanner/imageDiagrams.test.mjs`, in
`npm test`. Every fixture is drawn in the test with `@napi-rs/canvas` and wrapped
in a PDF built by hand, the way the font scanner's no-text test does. No book is
in the repository.

1. A drawn diagram, with rank numbers beside the board and hatched dark
   squares, has its frame found to within 1 px. A diagram-shaped image with no
   frame is refused.
2. Every pdfjs kind decodes to the same grey: the same picture stored as
   1-bit, as 8-bit grey and as RGB.
3. A scanned page with two boards, a block of text and a plain square (a figure
   that is not a board) gives exactly the two boards:
   - a board whose frame is broken is still found;
   - a board with an inner and an outer frame is cut at the outer one.

   These are the three faults phase 0 met on Silman.
4. End to end through `findImageDiagrams`:
   - a PDF with a diagram image and a scanned page gives three boards, with the
     right pages and sources;
   - a PDF with no images gives none and says so.

**Parity with phase 0, by hand** (the books are not in the repository):
`node services/positionScanner/imageDiagrams.mjs BOOK.pdf` prints the counts.

| Book | Phase 0 found |
|---|---|
| *Back to Basics* | 391 |
| Reinfeld | 1002 |
| Silman | 648 |

For the image books the boxes are compared with phase 0's own, which are in the
same pixel space.

**Done 22.9.2026. The gate has 9 cases, all green.** The draft of this list
became 9 cases because mutation found two holes in it.

Mutations run against the gate:

- **Caught, each by the right case:** 1-bit read with 1 as black; the whole
  image taken when there is no frame; no squareness test in `findBoard`; the
  smallest region first; no overlap check; no checkered test; no page treated
  as a scan; the page transform ignored.
- **Two of them first survived, and both were holes in the fixtures:**
  - The first draft drew the second frame *inside* the board. It touched the
    hatching, so the two frames made one outline, and "smallest first" had no
    order to get wrong. The fixture now draws it *outside* with paper between,
    which is the book's shape.
  - The table fixture's rules were too short to pass the frame-line test, so
    squareness was never asked. Its rules are now tall enough that only the
    shape refuses it.
- **Inert, and recorded rather than chased:**
  - The squareness filter on a scan region. `findBoard` inside the region
    refuses anything that is not a square board anyway, so the filter only
    saves time.
  - A crop that picks one pixel instead of averaging. At about 480–600 px down
    to 512, the two are practically the same.

**Parity with phase 0, on the owner's books:**

| Book | Boards found, Node vs phase 0 | Boxes | Time |
|---|---|---|---|
| *Back to Basics* | 391 vs 391 | identical to the pixel | 4.0 s |
| Reinfeld | 1002 vs 1002 | identical to the pixel | 10.1 s |
| Silman | 648 vs 648 | within 1.7 px | 26.0 s |

Every page gives the same count as phase 0. Silman's boxes differ only because
phase 0 rendered its pages at 200 dpi, while Node reads the scan at its own
300 dpi. That difference is the resolution, and Node's cut is the finer one.

Backend 1561 → **1570** without a database, 1673 → **1682** with one. Both
were measured, the database half on a throwaway cluster.

### Phase 2 — classify, with confidence [lead] — done 22.9.2026

**Measured before designing.**

- **A book cannot be read with another book's templates.** Templates from two
  of the books, reading the third:

  | Book read | Result |
  |---|---|
  | *Back to Basics* | 51 / 52, as well as its own templates did |
  | Reinfeld | whole solution replays on only 126 / 150; 72 boards come out illegal |
  | Silman | **0 / 24** |

  Templates also cannot ship in the repository, because they would be cut from
  the owner's books. **So every book is calibrated from its own boards**: the
  trainer gives the position of a few of them, and the rest are read from
  those.

- **The reader in Node.** A faithful port of phase 0 read Silman's truth set
  at 21/24, in **6.7 s a board**. Too slow for a request, and a porting
  difference as well. Two changes:
  1. **Each class looks for its own shift.** The class mean is searched over
     the full ±10 px on every other pixel. The three best classes then compare
     their examples within ±2 px of that shift.
  2. **At most 6 examples per class**, chosen farthest-first.

  Two ways of aligning that looked cheaper were measured and dropped:

  | Alignment | Silman truth set |
  |---|---|
  | one shift for the whole board | 1 / 6 |
  | one shift per square, taken from the best-fitting class | 20 / 24 |

  With one shift per square, an empty square fits a rim square best by sliding
  its piece out of view.

  **The result matches Python on all three books, at under half a second a
  board:**

  | Book | Node | Python (phase 0) | Time per board |
  |---|---|---|---|
  | Silman | 23 / 24 | 23 / 24 | 0.44 s |
  | *Back to Basics* | 51 / 52 | 51 / 52, the same board and squares | 0.48 s |
  | Reinfeld | 291 / 300 whole solutions | 98.3% | 0.47 s |

**Decisions.**

1. **Nothing from the book is stored, still.** The calibration travels with the
   request: `[{ page, index, fen, ignore? }]`, a board named by its page and its
   place on that page, which stays the same across two uploads. The client
   uploads the PDF again to read, and may keep the calibration for that book
   so the next chapter needs none. A calibration board may lie outside the
   pages being read; those pages are opened too.
2. **The route.** `POST /scans/images`, with the same upload rules, temp file,
   limiter and usage count as `POST /scans`:
   - **Without a calibration**, it answers with the boards found, a preview of
     each (PNG, 256 px), and the three boards it suggests calibrating: the
     busiest, most pieces first.
   - **With a calibration**, it answers the positions: for each board its page,
     its index, `source: 'image'`, the placement read, the squares marked
     uncertain, whether the placement is a legal position, and its preview.
     The calibration boards are echoed as given.
   - **Nothing is ever saved.** Saving stays `POST /scans/confirm`. That route
     needs no change: an image-read position arrives there as a FEN the
     trainer confirmed, with `needsReview` where the trainer left doubt.
3. **Reading runs in a worker thread**, not on the thread that answers
   everybody else. At most **60 boards** a request, about 30 s. Beyond that it
   is refused with the number.
4. **Marks keep phase 0's rule for now** (the 2nd percentile of the
   calibration boards' own gaps). The count of marks per board goes into the
   response, so phase 3 can see what the rule costs.
5. **`POST /scans` says when a book's diagrams are pictures.** The font path's
   `no_text` and `no_diagram_text` failures carry `details.imageDiagrams`, the
   number of boards the image path found on those pages. The client can then
   offer the other door, rather than a dead end.

**Gate.** The fixtures are drawn in the test with geometric pieces, never
letters: a test that draws text reads the machine's fonts (rule 8).

1. **Reader.** Boards drawn from three calibration positions read other drawn
   positions exactly, with each board shifted by up to 6 px and specks added.
   A class the calibration never showed, a white rook on a light square, is
   composed and read. *(As built, see "Done" below: a bound over 16 boards,
   not an exact read of one.)*
2. **Marks.** A teaching cross drawn on an empty square is marked, not read
   quietly as a piece or as empty.
3. **Route, without a calibration.** It gives the boards, their previews and
   three suggestions. It saves no row. The temp file is gone afterwards,
   whatever happened.
4. **Route, with a calibration.**
   - The positions carry `source: 'image'`.
   - A calibration FEN that is not a placement is refused with
     `calibration_invalid`.
   - A calibration board that does not exist is refused with
     `calibration_board_missing`.
   - Too many boards are refused with `too_many_boards` and the number.
5. **The font path points at the image path.** A PDF of image diagrams sent to
   `POST /scans` fails with `no_text` and `details.imageDiagrams` equal to the
   boards on it.

**Done 22.9.2026.** Three pieces:

- `reader.mjs` does the reading;
- `readWorker.mjs` runs it off the main thread;
- `imageRead.mjs` handles the calibration, the previews, the suggestions and
  the answer.

Behind them is `POST /scans/images`. `POST /scans` now counts the pictures when
the font path finds no text.

**The gate as built.** It has 14 cases: the reader's 7, the route's 6, and one
more on the crop. Three differ from the draft above, and why is part of the
result:

1. **"Read exactly, drifting 6 px" became two claims.**
   - On drawn boards, a black bishop on e7 was read as a pawn at every drift,
     even 0. The fixture's bishop is a small filled diamond and its pawn a
     small filled disc, and the calibration showed a black bishop on a dark
     square only once, on the rim.
   - Tuning the shapes until the case passed would have been choosing the
     fixture. So the case asserts what was measured: at least 99% of squares
     right over 16 boards at 3 px, with the composed rook right every time.
   - The promise itself is a separate case: at 6 px, every wrong square is
     marked. That promise is D1.
2. **"Every wrong square is marked" holds up to 6 px, not beyond.** Measured
   over the 16 boards:

   | Drift | Wrong squares | Unmarked |
   |---|---|---|
   | 6 px | 2 | 0 |
   | 8 px | 10 | 4 |
   | 10 px | 21 | 10 |

   Every unmarked miss at 8 px was the same square: a white rook on h1, a
   composed class, drawn half over the frame. Two consequences:
   - A square read *as* a composed class is now always marked. A composed
     template is a guess, and a guess can be confidently wrong. There is a
     case for this rule.
   - A composed class that *loses* can still hide a piece. So the response
     names the composed classes, and **phase 3 asks for one more calibration
     board that shows them.**

   A first version also marked squares where a composed class only came
   second. It put **20 marks on a board** of *Back to Basics*: a composed
   template is mostly its empty square, so it is the runner-up on nearly every
   empty square.
3. **The crop enlarges bilinearly.** A scanned board is smaller than 512
   (Silman's are about 350 px), and enlarging a 1-bit picture in blocks makes
   a line one pixel thick or two depending on where it falls. On the real
   scan, white pawns on light squares read as empty on 4 boards in 24. OpenCV's
   `INTER_AREA`, which phase 0 used, interpolates when enlarging. The new case
   draws two lines that blocks give one column and two; blocks fail it.

   **Phase 1's "inert" survivor was inert only for shrinking.** A mutation
   that survives on one fixture can be load-bearing on data that fixture never
   has (rule 6).

**The whole Node pipeline on the owner's books.** These are Node's own crops,
calibrated with phase 0's labels, and read with the final code:

| Book | Result | Silently wrong | Marks per board | Time per board |
|---|---|---|---|---|
| *Back to Basics* | **51 / 52**, the same board as Python | 0 | 1.5 | 0.41 s |
| Reinfeld | **291 / 300** solutions replay in full | — | — | — |
| Silman | **22 / 24**; both errors marked | 0 | 0.6 | 0.49 s |

The harness that produced these first reported *Back to Basics* at **27/52
with 25 boards silently wrong**. The fault was the harness, not the reader. It
matched phase 0's labels to Node's boards by the box *inside* the image, and a
page with two diagrams has the same box in both. So the calibration was taught
the wrong positions. It now matches by the image's place on the page.

**A number that looks like a disaster is first a question about the
instrument.** The crops were compared pixel for pixel, 0.79 grey levels apart
on average, before anything in the reader was touched.

**Backend 1570 → 1585 without a database.** That is 15: the 14 cases, plus
`test/support/drawnBooks.mjs`, which `node --test` counts as a file of its own.
With a database, 1682 → 1697.

One unexplained failure: a single run with the database reported two
failures. One was the drift case, which had become vacuous once the crop was
fixed. The other was not captured by name, and it has not come back in three
runs since.

### Phase 3 — the screens [lead] — built 22.9.2026, awaiting the owner's live check (TODO-provera 225)

The owner's decisions on the sketch, 22.9.2026 (all three recommendations):

1. **A book's calibration is remembered on the account, not the device.** It
   is kept in a small table:
   - the positions of the calibration boards and where they are in the book;
   - never a picture from it.

   The book is known by the **SHA-256 of the PDF file**, which the app works
   out. This is the lesson of the puzzle sets: data kept per device must either
   say so or stop being per device.
2. **The door opens only by itself.** When the font path fails with `no_text`
   or `no_diagram_text` and `details.imageDiagrams > 0`, the scan screen
   offers "Read the pictures" in place of the refusal. There is no manual
   switch. A book with both a chess font and picture diagrams will not be
   offered this path; that is accepted.
3. **More than 60 boards gets a message, not a split.** The server's own
   sentence: "choose fewer pages".

**The screens.** The sketch the owner accepted has three steps:

1. **The door**, described above.
2. **Teaching the scanner the book.**
   - Three suggested boards, each as a picture beside the trainer's own setup
     in the board editor.
   - "Choose a different board" picks any other one.
   - "Read N boards" is enabled once all three are set up.
3. **Confirming.** Every board is shown as a picture beside what was read.
   - An uncertain square has a **dashed outline and a question mark**, so it
     reads by shape, not only colour (the owner is colourblind).
   - The side to move is one tap, as on the font path's card.
   - A board that is not a position cannot be saved until it is fixed.
   - Tapping a board opens the editor, with its picture beside it.
   - When the answer names composed classes, a note offers "Add a board".
   - Saving goes through `POST /scans/confirm`. `needsReview` is set when the
     side to move was never touched, as the font path does for a side the book
     does not give.

**Phase 3a — the calibration on the account (server).**

- The table `book_calibrations (user_id, book_hash, book_name, boards JSONB,
  updated_at)`, keyed by user and hash, deleted with the user.
- Three routes, each scoped by `user_id` in its `WHERE`:
  - `GET /scans/calibrations/:hash` answers the boards, or 404 with
    `no_calibration`;
  - `PUT` validates through `parseCalibration`, the same reader
    `POST /scans/images` uses (one rule, one home), and upserts;
  - `DELETE` removes one.

Gate: `test/book_calibrations_routes.test.js`, handlers called directly,
asserting on the SQL.
- Every route is behind sign-in.
- A hash that is not 64 hex characters is refused.
- `PUT` with a board that is not a placement is refused, and nothing is
  written.
- `PUT` upserts with the account's id.
- `GET` of another account's hash asks with *this* account's id, and so
  answers 404.
- `DELETE` is scoped by account.
- A real-database case in the database half: two accounts with the same hash
  keep separate rows.

**Phase 3b — the app's side of the wire.**

`ScannerApiService` gets an optional `http.Client`, the pattern of
`PuzzleSetApiService`, and four new calls:
- `scanImages`, without and with a calibration;
- `loadCalibration`, `saveCalibration` and `deleteCalibration`.

`scanFailureMessage` also returns the door: `imageDiagrams` read off the
refusal.

Gate: `MockClient` tests that assert **the request**:
- the multipart fields, including the calibration as JSON;
- the hash in the path;
- a 404 read as "none", not as an error.

**Phase 3c — the door and the calibration screen.**

Gate: widget tests.
- The refusal with `imageDiagrams` shows the door; one without it does not.
- A remembered calibration skips straight to reading.
- "Read N boards" waits for three boards.
- The picture of a board is on screen beside its editor, at 360 dp and at
  1280.

**Phase 3d — the confirmation screen.**

Gate: widget tests.
- An uncertain square is drawn with its outline and question mark: found by
  its key and measured, not just said.
- A board that is not a position has no tick box until it is fixed.
- Saving sends exactly the accepted boards, with `needsReview` where the side
  was never touched.
- The composed-class note appears only when the answer names a composed class.
- Nothing overflows at 360 dp, and the pictures are square (measured, since
  clipping is not overflow).

**The live check is the owner's**, on the three books, with its own item in
`TODO-provera.md`.

**Built 22.9.2026.** The four parts, and what each gate measured:

| Part | Where | Gate |
|---|---|---|
| 3a | `book_calibrations`, `/scans/calibrations/:hash` | 11 cases plus one on a real database; 6 mutations caught, among them the primary key on the hash alone, which only the real database sees |
| 3b | `ScannerApiService` (an `http.Client` seam, `scanImages`, the three calibration calls, `details` on a refusal), `bookHashOf` | 13 cases on the request; 7 mutations caught |
| 3c | the door (`imageDoorFor`, `ImageDiagramsDoor`) on `ScanReviewScreen`; `ImageScanScreen`; `AnalysisBoardSetupDialog.referencePicture` | together with 3d, 13 cases |
| 3d | the confirmation, `ReadBoardView` with a dashed outline and a question mark | 11 mutations caught |

The app goes 3752 → **3778** (a full run).

Found while building, and fixed:

1. **A failed reading would have been remembered.** The calibration was saved
   after the read, whatever came back. A calibration that failed would then
   be offered again on every visit, failing the same way each time. It is now
   saved only after a reading that came back, and the error screen offers "Set
   up the boards again".
2. **The boards the trainer set up could not be saved.** They are positions
   from the book too, confirmed by being set up. The server now reports their
   legality, and the app offers them with the rest, in the book's order.
3. **The seam went round the save.** `confirm()` and the older calls used the
   package's own functions, not the injected client, so a test watched the
   save go past it. Every call now goes through one client. A seam that only
   some calls use lets a test believe it sees every request.
4. **`AppFeedback.dismiss` could still throw.** It animated the message out,
   and the animation asserts that the messenger is still mounted when it ends,
   after the messenger is gone, in a callback no `try` reaches. It now removes
   the message at once. The font scanner had the same fault; no test had ever
   closed it with a message showing. The source guard now also forbids a
   direct `removeCurrentSnackBar`.
5. **The first fixture PNG was not a PNG.** It was written by hand, and Flutter
   could not decode it. It was replaced by one whose chunks and CRCs were
   checked first.
6. **The 360 dp case failed for the wrong reason under a mutation.** A note
   above the boards pushed the measured board below the fold, and a lazy list
   does not build it. The case now scrolls to the board before measuring, and
   the note has its own case at 360 dp.



### Phase 3e — a calibration the trainer steers [lead] — built 23.9.2026, awaiting the owner's live check (TODO-provera 227)

**The request (the owner, 23.9.2026).** The three suggested boards are the
busiest in the range, so they are usually neighbours from one chapter with the
same pieces, while the pieces that are missing sit elsewhere in the book and
are never shown. The trainer should find the boards in the book himself, and
while setting them up should always see **what is still needed — which pieces,
on which squares** — so the process is half guided.

**What "needed" means, from the reader.** `reader.mjs` compares a square only
with examples *of its own colour*, and never with its place on the board. So a
calibration needs **24 classes**: 12 pieces × a light and a dark square (the two
empty classes come with any board). Each class is in one of three states:

| State | Meaning today | Shown as |
|---|---|---|
| **seen** | at least one calibration board has it | ✓, and the count of boards |
| **guessed** | only the other colour was seen; `learn` composes a template, every square read as it is marked | ≈ |
| **unknown** | the piece was never seen on either colour | ○ |

**A hole found while designing this.** An *unknown* piece is worse than a
guessed one, and today nothing says so. `learn` composes a class only from the
same piece on the other colour; a piece seen on neither is simply absent — not
in `composed`, not in the answer, not marked. A black queen in a book whose
calibration never showed one is read as whatever fits best (likely a king), and
it is marked only if its gap happens to fall under the cut — **nothing
guarantees a mark** (read from the code, not yet measured; 3e.0 (b) measures
it). The response must name these (`unseen`), and the
calibration screen must not let a reading start blind to them (decision 1).

**The screen.** One screen replaces the three fixed cards:

1. **"What the scanner still needs"** at the top — the 24 classes as a small
   table, a piece per row, *light* and *dark* as the two columns, each cell
   ✓ / ≈ / ○ by **shape** (the owner is colourblind). Under it one sentence in
   priority order: unknown pieces first ("a black queen, on any square"), then
   guessed classes ("a white rook on a light square"). Worked out in the app
   from the placements already set up (`pieceClassesOf` already exists), so it
   updates the moment a board is confirmed, with no request.
2. **The boards set up so far**, each a card as today, with one line more:
   **"Adds: ♖ light, ♛ dark"** — or "Adds nothing new — remove?", which is the
   owner's complaint answered on the card itself.
3. **"Find a board in the book"** opens a browser of **every board in the
   book**, not only the pages being read, grouped by page, with a page jump.
   Calibration boards may already lie outside the reading range (phase 2,
   decision 1); only the browser was missing.
4. **In the editor**, beside the picture, the same "still needed" line, live:
   as the trainer places pieces it says which missing classes this board will
   add. The editor stays what it is (`referencePicture`); this is one strip.
5. **"Read N boards"** is enabled by decision 1, and its label says what is
   still guessed: "Read 42 boards — 3 kinds still guessed, they will be marked".

**Half guided: the hints (a later part, only if phase 3e.0 measures it
useful).** Once a board or two is set up, the server can read the book's boards
*provisionally* with that partial calibration and say, per board, what it
**probably** shows that is missing. Two signals, both from the reader as it is:

- a square read as a **composed** class → "may show a white rook on a light
  square" — that board is worth opening;
- a square with **unknown ink** — its best distance to every known class far
  above what the calibration's own squares give → "shows a piece the scanner
  does not know yet". This is the only signal that can point at an *unknown*
  piece.

The browser then gets a chip "Might show what is missing" that narrows it to
those boards. The trainer still chooses; nothing is picked for him.

The second signal is also a **safety net** worth having on its own: a square
far from everything known is marked uncertain in the final reading too, so an
unseen piece can no longer pass unmarked even if the trainer overrides
decision 1.

**Phases.**

- **3e.0 — measure [lead].** On the three books, with phase 0's labels:
  (a) how many boards a greedy cover needs for all 24 classes, and which
  classes a whole book never shows (a book with no white queen on a light
  square decides whether "seen on any colour" must be enough); (b) with one
  piece left out of the calibration, whether its squares' best distance
  separates from the calibration's own — the unknown-ink signal, and at what
  cut; (c) the provisional read's cost over a whole book with only the coarse
  stage (`candidates`, class means), since the full read is 0.45 s a board and
  Reinfeld has 300; (d) the browser's size: all of a book's boards as 128 px
  thumbnails, time and bytes.
- **3e.1 — server.** The reading answer names `unseen` pieces beside
  `composed`. A browse mode for `POST /scans/images`: boards and thumbnails of
  a page range, without the 60-board limit (that limit is about reading time,
  not finding), paged by the app. The unknown-ink mark if 3e.0 finds a cut.
  `MAX_CALIBRATION` 8 → 12 if (a) says 8 is too few — reading cost does not
  grow with it (6 examples a class), only `calibrate`'s read-back, 0.45 s a
  board.
- **3e.2 — app.** The coverage model (a pure function of the placements, with
  its own test), the screen above, the browser, the editor's strip, and the
  same screen behind "Improve the calibration" for a book that has one —
  with `calibrationGrownBy` unchanged underneath.
- **3e.3 — hints**, only if 3e.0 (c) and (b) say they are fast and right
  enough.

**Gate (drafted; written in full before each part is briefed).**
- Coverage: a placement set gives the right state for all 24 classes; a
  class seen only on light is *guessed* on dark; a piece seen nowhere is
  *unknown*. Mutation: swapping light and dark in the square colour must go red
  (a8 is light).
- The server names a piece left out of the calibration in `unseen`, and does
  not name a composed one there.
- "Read" is not offered while decision 1's condition is unmet, and is at the
  boundary (the last missing piece set up).
- "Adds nothing new" appears on a board whose classes the others already show,
  and not on the first board.
- The browser reaches a board outside the reading range, and the reading
  request then carries it.
- At 360 dp the table, the sentence and the cards do not overflow; the pictures
  stay square (measured — clipping is not overflow).

**Decisions for the owner.**

1. **When may reading start?** Recommended: every one of the 12 pieces seen at
   least once, on either colour, so nothing is *unknown*; *guessed* classes are
   allowed and marked. With a "This book has no black queen" tick per piece for
   the rare book that really lacks one. The alternative, reading at any time
   with a warning, keeps the hole above open unless the unknown-ink mark lands.
2. **The browser: the whole book or the reading range ± some pages?**
   Recommended: the whole book, paged, because the point is that the missing
   pieces are elsewhere.
3. **Hints:** build them after 3e.0, or leave the trainer with the table alone?
   Recommended: measure first; build only the unknown-ink mark if the
   provisional read is slow.
4. **Keep one suggested first board?** Recommended: no fixed three any more;
   the empty screen offers the busiest board of the book as a starting point,
   and the table takes over after it.

**The owner accepted all four recommendations on 23.9.2026** and asked for
3e.0. Its numbers change two of them — 3 and 4 — so they go back to him
rather than being built as accepted (below).

#### 3e.0 — measured 23.9.2026

The harness (`find_all`, `read_all`, `coverage`, `unseen`, `hints`, in the
session's scratch directory, nothing from the books in the repository) reads
**every board of all three books** with phase 0's calibration and uses those
readings as each book's inventory: 391 boards of *Back to Basics*, 1002 of
Reinfeld, 648 of Silman. The inventory is a reading, not truth (98% of boards
right, §7); every number below that rests on it says so.

**(a) What a book needs, and what the three busiest gave.** Counted over the
boards that are a legal position (387, 998, 620):

| Book | Kinds the whole book shows | Boards that cover all of them (greedy) | Old scheme, per reading window of ≤ 60 boards: kinds the 3 busiest cover / kinds the window's boards show | Windows where a piece was **unknown** |
|---|---|---|---|---|
| *Back to Basics* | 24 / 24 | **3** | 20.1 / 22.4 | 0 / 7 |
| Reinfeld | 24 / 24 | **2** | 21.2 / 24.0 | 0 / 17 |
| Silman | 24 / 24 | **3** | **12.7 / 21.1** | **8 / 11** |

- **The owner's complaint is measured, and it is worst exactly where it
  matters:** on the scan, eight reading windows in eleven were read with at
  least one piece the calibration had never seen, 5.7 kinds a window, while
  three boards chosen anywhere in the book cover everything.
- **Every book shows all 24 kinds**, so no "this book has no …" tick was
  needed on these three. It stays in the design for a book that does lack one.
- **`MAX_CALIBRATION` stays 8**: two or three boards cover a whole book.
- *A mistake in the instrument, caught before it was reported:* the first run
  counted only boards with no mark, and reported that each book **never**
  shows the very kinds its calibration composes (*Back to Basics* four,
  Reinfeld one, Silman two). A composed class is always marked, so a filter on "no mark"
  removes precisely the boards that show it. **A filter on a result must not
  be a function of the thing being counted.**

**(b) A piece the calibration never saw.** For every piece but the kings (a
legal board always has both), a calibration was chosen from boards without
it, greedily covering everything else, and 25 boards with it and 25 without
were read:

| Book | Squares of the unseen piece | Marked by today's rule | Left **unmarked and wrong** |
|---|---|---|---|
| *Back to Basics* | 192 | 192 | 0 |
| Reinfeld | 562 | 562 | 0 |
| Silman | 386 | 354 | **32** (8%), mostly a black pawn read as a black bishop |

On the digital books the gap rule marks all of them, because a calibration
missing a piece is thin and the cut falls high — at a price of many marks on
the other squares (up to 12 a board on *Back to Basics*, 31 on Reinfeld with
no black pawn). On *Back to Basics* only five pieces could be left out: no
board lacks the others. **On the scan the hole is real.** The distance to the nearest example
(`d1`, the share of the square that differs) separates it with **one absolute
cut on all three books**:

| Cut on `d1` | *Back to Basics* unmarked | Reinfeld unmarked | Silman unmarked | New marks per board, Silman |
|---|---|---|---|---|
| none (today) | 0 | 0 | 32 / 386 | — |
| 0.08 | 0 | 0 | 3 | 0.11 |
| **0.10** | 0 | 0 | **4** | **0.02** |

A cut relative to the median `d1` was tried first and fails on digital
renders, whose median is near zero (it added 7–10 marks a board there). The
absolute cut added no mark at all on the two digital books. **So the unknown-ink
mark is worth building on its own — `d1 > 0.10` marks a square — whatever
happens to the hints.**

**(c) Hints: not worth building.** A simulated trainer started from one
board and, after each board, opened the top-hinted one:

- The coarse stage is **not** cheap: 0.35–0.48 s a board on the digital books
  (the search over ±10 px for every class mean is most of a read), so one
  whole-book pass over Reinfeld is about 8 minutes — after every board set up.
- The hints are right only while nearly everything is missing, which the table
  says anyway. In the tail, where they are needed, precision fell to 1–43%,
  and the top hint **added nothing** on *Back to Basics* at steps 3, 4 and 6
  and on Silman at steps 5 and 6. Reinfeld was covered by its second board with
  no help.

The table and the trainer's own eye are the guide; the browser gets no
"might show what is missing" chip.

**(d) The browser.** Finding every board of a whole book: 4.6 s (*Back to
Basics*), 13 s (Reinfeld), 27.5 s (Silman, whole-page scans). Today's 256 px
PNG preview is 50–150 KB a board; a **128 px JPEG at quality 70 is 5–7 KB**
(PNG at 128: 18–30 KB). Reinfeld's 1002 thumbnails are then about 5.5 MB, so
the browser asks for the book in pages of 50 or so and keeps today's 256 px
picture for the editor.

**Decision 4 does not survive either.** The busiest board of the book by
`busy()` — the starting point recommended above — covers 18 kinds of 24 on
*Back to Basics* and 20 on Reinfeld, but **3 on Silman**: on a scan, ink
is not pieces. So the recommendation changes to **no suggested board at all**;
the empty table, which on an empty calibration reads "every piece, on either
colour", is the start.

**What changes for the owner to confirm:**
1. Hints (decision 3): measured, **not built**; the unknown-ink mark
   (`d1 > 0.10`) is built instead, and closes the scan's hole from 32 squares
   to 4.
2. The starting board (decision 4): **none**, because the busiest board is a
   poor start on a scan.
3. Unchanged: reading waits until all 12 pieces are seen (decision 1); the
   browser covers the whole book (decision 2), paged, as 128 px JPEG.

#### Who is to move, and where a language model could help — measured 23.9.2026

The owner asked, the same day, where an LLM API could help, and whether with
who is to move. Today the image path never knows: the trainer taps the side,
and a board left untouched is saved with `needsReview` (D2).

**What each book offers, measured on all its boards:**

| Book | The rules alone (the side not to move is in check) | Text on the diagram's page | Where the side really is |
|---|---|---|---|
| *Back to Basics* | 9 / 391 (2%) | yes, running prose | in the prose around the diagram |
| Reinfeld | 8 / 1002 (1%) | none on the diagram pages | **the book's solutions**: phase 0 read the side for 998 of 1006 |
| Silman | 32 / 648 (5%) | none — whole pages are scans | the first move printed after "Diagram N", **inside the picture** |

- **Reinfeld needs no model.** Its solutions say who moves (`1...Rd1+` is
  Black), the font path already has `solutions.mjs`, and the solution is also
  the strongest check on the board read (D3). Reading solutions on the image
  path is the cheapest large win, and deterministic.
- ***Back to Basics* is where a text model could help.** A plain rule — the
  first move printed after the diagram, which must be legal for the side its
  number names — found a move for 341 boards and a legal one for 272; but on
  the 40 of those whose side phase 0 knows (by replaying the line printed
  before them), it was **wrong on 11 (27%)**. The prose quotes threats and other
  openings: *"In this position Black has the obvious threat of 8...Nxe4"* sits
  under a board with White to move; *"the Queen's Gambit, 1 d4 d5 2 c4"* sits
  under one with Black to move. That is reading comprehension, which a text
  model does and a regular expression does not; DeepSeek is already wired in
  (`services/llm/deepseek.js`). Legality is only a weak check here: in an
  opening position most moves are legal for someone.
- **Silman would need a model that sees.** The side is in printed text that
  is part of the scan. DeepSeek is text-only; the Gemini key is on the free
  tier (20 requests a day — 648 diagrams is a month of it). A vision model
  would also receive **page images of a copyrighted book**, which is the
  owner's call, not a technical one.
- **Not for the pieces.** The template reader reads 98% of boards with its
  errors marked, and a model's dangerous error — a legal-looking wrong board —
  is exactly what D1 exists against. Not for the calibration either: the
  trainer's setup is the truth everything else is measured by.
- **Maybe for phase 4:** a caption such as "White to play and win" or "Mate in
  2" names the exercise's task. English captions are mostly a pattern, not a
  model's job; measure before choosing.

**D2 says the side is never guessed, and a model's answer is a guess.** So a
model's side can only be offered as the pre-set answer on the confirmation
card, with `needsReview` kept unless something checks it — a solution move
that is legal for that side and not the other. Whether a pre-set side the
trainer did not touch may be saved without `needsReview` is the owner's
decision.

**The measurement that would decide it** (not run: it sends book text to
DeepSeek and spends the key, so it waits for the owner's word): the 40
*Back to Basics* boards whose side is known, each with its column of text and
the placement read, asked "who is to move at this diagram, or cannot tell".
Worth building if it is right on nearly all it answers and says "cannot tell"
rather than guess — the 27% the rule gets wrong is the bar.

**The owner, 23.9.2026: not pursued.** "We are complicating it" — the trainer
chooses the calibration boards and sets who is to move on each board himself,
as before. Nothing of this section is built; the side-to-move numbers stay
here as the measurement behind that decision.

#### Built 23.9.2026

The owner's answer settled both changed decisions: no hints, the unknown-ink
mark instead, and no suggested starting board.

- **Server** (backend 1611 → **1617** without a database, 1741 → **1747** with
  one, both full runs; app 3832 → **3848**):
  `reader.mjs` gives every square its `d1` and marks one beyond
  `UNKNOWN_INK = 0.10` (`unsureOf`, the one home of the marking rule), and
  `learn` names `unseen` pieces, which the reading answer carries. A request
  without a calibration is the **book browser**: boards and previews of the
  pages asked for, no 60-board limit (that limit is about reading time), no
  suggestions, and no usage counted. Previews are JPEG at quality 80.
- **App**: `CalibrationCoverage` (a pure function of the placements, with
  `absent` for "No … in this book"), `CoverageTable`, `BookBrowser` (20 pages a
  window, cached as the request itself so two askers share one upload), cards
  with "Adds: …" / "Shows nothing the other boards do not." and "Remove",
  reading gated on `ready`, "Improve the calibration" and "Add a board" going
  back to the table **without deleting** the remembered calibration, and a
  note naming `unseen` pieces. The door says "a few" instead of "three".
- **A rook-endings book** (the owner's question the same day): the "No … in
  this book" buttons first appeared only for four or fewer missing pieces, so
  a book with no queens, bishops or knights — six — could never be read. They
  now appear once one board is set up, however many are missing; a case holds
  it, red on the capped code.
- **Not built:** the live "still needed" strip inside the editor (item 4 of the
  screen above). The editor is the shared `AnalysisBoardSetupDialog`, and the
  card says what the board adds the moment it closes.

**Gate and mutations.** Server: 8 mutations, each red on the right case. The
drawn fixtures' pieces are plain shapes within 0.055 of one another, so no
drawn *piece* crosses the 0.10 line; the rule is held at its boundary through
`unsureOf`, and through a reading by a teaching cross (0.187, ink no
calibration shows) — a survivor (`readBoard` not using `unsureOf`) showed the
second case was needed. App: 14 mutations, each red on the right case. The
gate found one real fault while being written: two remembered boards in one
page window uploaded the book twice.

A flake worth knowing: one route test answered 500 once, because the owner's
nodemon restarted on a saved test file and its startup sweep of the shared
scan temp directory removed the test's upload. The server was right; a test
run and a dev server share `os.tmpdir()`. Mutations then ran in a copy
outside the repository with its own `TMP`.

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
