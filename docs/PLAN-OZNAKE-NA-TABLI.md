# Marks on the board: the last move under the pieces, a trainer's square framed

Written 12.9.2026, out of four reports from the owner's own testing on that day
(`mislisha-test/qa/stanje.json`, the four newest — filed under *Tactics tailored
to you*, *Find the winning path*, *Practice basic checkmates* and *My games —
import*; the last two are not this plan).

## The decision

The owner, 12.9.2026, after two probe sheets were rendered and read:

1. **No circles, anywhere.** The `[%csl]` ring goes. A trainer's marked square
   becomes a thin frame around the square's own edge, in the colour they picked.
2. **The last move moves under the pieces.** It becomes a layer between the
   squares and the pieces — not a frame, not a wash painted over. The corner
   brackets and the amber band go with it.
3. **The two never compete**, because they are no longer the same kind of thing:
   one is the square's own colour changing underneath, the other is an outline
   on top. Neither needs the other's hue to be readable.

This is the inversion the owner proposed, and it is better than the frame-for-
the-last-move version discussed first. The argument that settled it is in
`probe_layer.png`: under the piece the wash costs the piece nothing, so the
constraint that turned the last-move marker into a frame in the first place
disappears.

## What already exists, and what does not

| Piece | Where | State |
|---|---|---|
| The board, forked so we own it | `widgets/board/skinned_chess_board.dart` | built — squares and pieces are already two layers of one `Stack` |
| Every board in the app | six call sites of `SkinnedChessBoard` | built — the overlay, the analysis studio, the drill screen, the replay player, the engine-line dialog |
| The last move drawn over the pieces | `ChessBoardPainter.paint`, amber band + border + brackets | built — **to be deleted** |
| The `[%csl]` ring | `ChessBoardPainter._paintSquareMark`, three passes | built — **to be replaced by a frame** |
| Last-move squares derivable from the game | `ChessBoardWithOverlay.lastMoveSquares` | built, already called on every move |
| Screens that pass the last move | 5 of 15 that draw `ChessBoardWithOverlay` | **the gap** |
| The film's last move | `videoRenderer.js:642`, `fillRect` under the pieces | **already the layer this plan builds** |
| The film's square mark | `videoRenderer.js:201`, the same three rings | built — **to be replaced by a frame** |
| Contrast model and the measurement helper | `test/support/color_vision.dart` | built, and the whole basis of this plan |

### The film already does it, and that is the strongest argument in this document

`videoRenderer.js` paints the squares, then fills `lastMove.from` and
`lastMove.to` with `rgba(247, 236, 89, 0.45)`, then draws the pieces. That is a
wash between the board and the pieces — exactly what this plan is asking the app
to do — and it has been there since the film was written. So today the app and
its own exported video disagree about what the last move looks like, and neither
end knew about the other.

Two consequences. The renderer's half of this work is a colour change and
nothing else. And the ring must change at **both** ends in one go, or a tutorial
will look one way on screen and another way in the film a child is sent — this
file already records what a rule kept in two places costs.

## The two markers, exactly

### The last move — a layer, black at 22%

Drawn between `_SquaresPainter` and `_pieceGrid`, on both squares of the move.

**Black at 22% alpha, and not navy.** The measurement is in
`probe_layer_protanopia.png`: the black wash is pixel-identical to its own
normal-vision rendering, because it has no hue to lose. It therefore cannot
collide with any of the five colours a trainer can pick, on any of the five
board skins, for any kind of eye — not today and not when a sixth colour or a
sixth skin is added. Navy at 35% also reads, and is the fallback if 22% proves
too quiet on a phone in daylight; that is a live judgement, not a measurement,
so the constant is one value in one place.

It is also the right *weight*. The last move is a fact about the position; a
trainer's mark is a person saying "look here". The quieter of the two should be
the one that is always on.

**No second channel, and this is the one place the 29.8.2026 rule is relaxed on
purpose.** The brackets exist because an amber fill over a piece measured 1.03:1
at worst — it was a hue signal and nothing else. A 22% black wash is a luminance
signal by construction: it darkens whatever it covers by a fixed proportion, on
every skin, for every eye. The old marker needed a second channel because its
first one did not exist. This one's first channel is the only channel it has.

### A trainer's square — a frame, in their colour, with hairlines

Drawn where the ring is drawn now, over the pieces, on the square's own edge:
a dark hairline outside, a light hairline inside, the author's colour between
them. Three strokes, as the ring had three passes, and for the same reason.

**The hairlines are not decoration and `probe_trainer_frames_protanopia.png` is
why.** A plain frame in the palette colour, worst square of any skin, worst eye:

| | worst contrast | where |
|---|---|---|
| G Green | **1.01:1** | Classic, light square, deuteranopia |
| R Red | **1.02:1** | Classic, dark square, deuteranopia |
| O Orange | 1.24:1 | Green, dark square, protanopia |
| P Purple | 1.37:1 | High Contrast, dark square, protanopia |
| B Blue | 2.86:1 | High Contrast, dark square, protanopia |

Three of the five vanish into the square they are drawn on. With the hairlines
every frame reads on every skin — that is the bottom half of every pair in the
sheet. A hairline is a thin wall, not a circle, so this satisfies the decision
rather than arguing with it.

**What the hairlines do not fix, stated rather than hidden:** the five colours
are still not distinguishable *from each other* for a red-green deficiency — red,
orange and green are three olives in that sheet. That is the palette's own
ceiling (`arrow_colors.dart` documents the search that put it at 1.5:1 by
luminance) and it is exactly as true of the ring today. This plan makes "is
there a mark on this square" reliable; it does not make "which colour is it".

## Phase 0 — the layer, and nothing drawn on it yet

**Done 12.9.2026 — 2102 in the app with 1 skipped, analyze at 29 infos and zero
warnings**, both measured on `master` with nothing else running. The baseline
taken before the work was **2095**, so the seven are exactly this phase's gate,
`test/last_move_layer_test.dart`. Seven mutations, all seven caught — but only
after the seventh was written for a survivor, below.

The count in CLAUDE.md said **2079** when this started and the suite was 2095.
Stale by the drift that file warns about; re-derived rather than repeated.

**The lead's own commit, before any widget batch.** `SkinnedChessBoard` gains
two nullable square names and a `Positioned.fill` between the squares painter
and the piece grid. Wrapped in `IgnorePointer` even though a `CustomPaint` with
a default `hitTest` absorbs nothing — the guard costs nothing and the next
person to add a gesture there will not have to rediscover it.

Nothing passes the two names yet, so the app is unchanged and the suite must be
too.

**Gate.** One new test file, `test/last_move_layer_test.dart`, seven tests.

It was planned as a canvas recording, the way `last_move_marker_test.dart` reads
the overlay, and that turned out not to be available: the squares and the wash
are `CustomPaint` siblings but the pieces are a `GridView` of widgets with their
own render objects, so there is no one canvas holding all three to read an order
off. Asserting a child's *index* in the `Stack` would pass for a layer moved
into a different `Stack` entirely.

So it asks the picture. **A pixel of the square changes and a pixel of the piece
does not** — and it is the pair that pins the order, because either alone is
answered by the wrong thing: "the square darkened" is equally true of a wash
painted over everything, and "the piece is untouched" is equally true of a layer
drawing nothing at all.

**Mutation to run, and it is the one that matters:** move the `Positioned.fill`
after `_pieceGrid`. If the gate stays green, the gate is not a gate. It went
red, on the half of the assertion that says the piece is untouched.

### Two things phase 0 cost that the plan had not allowed for

**A pixel test needs its pixels found, not written down.** Which pixels of a
square are rook and which are board is a property of `chess_vectors_flutter`,
and the first version guessed at a corner. Both samples are now located in the
*unmarked* render by matching the skin's own colours exactly, and the test says
so when it cannot find them — so a pixel called "on the piece" is one that was
measured to be the piece.

**`shouldRepaint` returning `false` survived every pixel test in the file**, and
it could not have done otherwise: `RepaintBoundary.toImage()` paints its subtree
whatever the method answers. In the app the wash changes at the same moment the
position does, so the piece grid's own rebuild would hide a stale answer for as
long as the two happen to change together — which is exactly the kind of
dependence that stops being true later. It is asked of the method directly now.
The sibling `_SquaresPainter` has the same untested guard and is private; left
alone, noted here.

**And one line was deleted rather than tested.** `if (from == null && to ==
null) return;` above the loop cannot fail: the loop already skips a null square.
Two guards that prove the same thing prove neither.

## Phase 1 — the last move becomes the layer

**Done 12.9.2026 — 2098 in the app with 1 skipped, analyze at 29 infos and zero
warnings**, measured on `master` with nothing else running. Five mutations, all
five caught, but two survived the first run and the gate written for them is the
part worth keeping.

The arithmetic from phase 0's 2102, since a falling count is what the test gate
exists to stop: **−6** for `last_move_marker_test.dart`, deleted whole; **−3**
for the contrast file's marker group; **+2** for the wash group that replaced
it; **+1** for the bleed test carried over from the deleted file; **+2** for the
new source gate. 2102 − 6 − 3 + 2 + 1 + 2 = **2098**.

`ChessBoardPainter` lost `lastMoveFrom`, `lastMoveTo`, `lastMoveColor`,
`_paintLastMoveBrackets`, `lastMoveMarkerShade` and `lastMoveMarkerLight`. Four
callers moved the two square names onto `SkinnedChessBoard`: the overlay, the
analysis studio (whose whole `if (_lastMoveFrom != null && _lastMoveTo != null)`
layer became redundant and went), the drill screen, and the replay player —
which turned out to pass `lastMoveColor` and **never a square**, so it has drawn
no last move since it was written. It still does not; phase 2 decides whether it
should.

**The ring is untouched.** The plan said this phase would take the two ring
tests out of `board_skin_contrast_test.dart` along with the two bracket ones.
That was wrong: the ring survives until phase 3, and so do its tests.

### The two mutations that survived, and the gate they bought

Deleting the forwarding from **the analysis studio** and from **the drill
screen** left the whole suite green. Neither screen is built in any widget test
— one wants an engine and a session, the other a route with a category on it —
and both are the two that bypass `ChessBoardWithOverlay` entirely, so phase 2's
derivation will never cover them. They would have shipped drawing nothing, which
is the exact fault this plan exists to fix, one commit after fixing it.

`test/last_move_reaches_board_test.dart` asserts the invariant where it can be
asserted: **a screen that declares `_lastMoveFrom` must hand it to a board.**
Five screens do as of today. It is deliberately not "every board gets a last
move" — the replay player and the engine-line dialog pass none on purpose, and a
gate that failed them would be argued with rather than satisfied.

It reads by matching parentheses with strings and line comments blanked first,
never by slicing, and its second test feeds it source written to fool it: the
same call inside a comment, inside a string literal, and a real one with a `)`
in an argument. This repository has paid for a sliced source read twice.

### Two smaller things

**The worst washed-vs-plain contrast is 1.46:1**, on High Contrast's dark square
— against the amber's 1.03:1, and on the same order as the 1.5:1 `ArrowColor`
holds between its own pairs. The contrast test prints it rather than pinning it,
because the alpha is a live judgement and a test that fixed the number would
fail the moment that judgement is acted on.

**An import is not dead because one of its names stopped being used.** Removing
`board_overlay_painter.dart` from `tap_to_move_test.dart` after its
`ChessBoardPainter` assertions moved to `SkinnedChessBoard` broke two unrelated
tests that take `AnimatedMovePiece` from the same file.

## Phase 2 — every board draws it

**Done 12.9.2026 — 2127 in the app with 1 skipped, analyze at 29 infos and zero
warnings**, measured on `master` with nothing else running. From phase 1's 2098:
**+6** for the derivation's gate, **+19** for the pure core of 2b, **+4** for
the four tests 2b added to that gate. Twenty mutations across the three runs.

It took two goes, and the second is the interesting one.

### 2a — the history, which was right and was not enough

`SkinnedChessBoard` works out its own last move when the caller passed neither
square. Derived there rather than in `ChessBoardWithOverlay` — which is what
this plan originally said — for two reasons: that builder already holds the
`game` and already re-runs when it changes, and it is what all six boards in the
app are built from, including the analysis studio and the drill screen, which
never touch the overlay.

`lastMoveSquares` moved off `ChessBoardWithOverlay` and became the top-level
`lastMoveSquaresOf`, because the widget that needs it is imported *by* that
widget and the other direction is a cycle. Four callers followed it.

Six mutations, all six caught, including the pair that matter: the caller's own
squares must win, and they must win **whole** — mixing a caller's `from` with a
derived `to` is two nodes answering for one move.

### 2b — and then the measurement that undid it

Nine of the ten screens this phase exists for drive their board with `loadFen`,
and **`loadFen` empties the history.** The tactics trainer, which is where the
owner's report came from, plays the move on its own `chess.Chess` and then calls
`_boardController.loadFen(game.fen)` to put the board in step. Probed rather
than reasoned about: after the drag the history holds `e2e4`, and after that one
line it holds nothing.

So 2a would have shipped a feature that is still invisible on every screen it
was written for — every layer correct, nothing drawn, which is the exact shape
this plan exists to fix. **The gate did not catch it because the gate's fixture
was `makeMove` and the screens use `loadFen`**: a fixture that did not match the
thing under test, which this file already records twice.

`lib/core/services/move_between_positions.dart` is the answer, landed as its own
core with 19 tests before the widget was touched. Given two positions it asks
**which single legal move gets from one to the other**, by generating the moves
and trying them. The board remembers the position it last drew and asks that
question whenever a new one arrives with no history behind it.

**It searches legal moves instead of diffing the squares, and that is the whole
design.** A square-by-square diff is a second set of chess rules: castling moves
two pieces, en passant empties a square no piece arrived on, promotion changes
what a piece is. Asking `chess.dart` needs no special cases, and the tests for
those four are in the file as the reason.

### Three things worth carrying

**`chess.Chess.fromFEN` does not throw — it answers an empty board.** Handed
`''`, `'not a fen'`, `'////////'`, four ranks or a rank of nine pawns, it
returns a board with no pieces and reports nothing. So the `try`/`catch` the
first version wrapped it in was dead code, and the guard that looked like it
mattered — "did the board take the position I gave it?" — could not be made to
fail either, because an empty board has no king, generates no moves, and so
already answers null. Two guards were deleted and the property they leaned on is
pinned instead, by a test that fails if the engine ever starts answering
something else. One early exit stays, unprovable, and says so in the code.

**A screen that syncs by `loadFen` is now the tested case, not the lucky one.**
Four of the ten tests in `last_move_derived_test.dart` drive the board exactly
as the real screens do, including the opponent's reply — the sentence in the
owner's report — and including a new puzzle being loaded, which is two positions
with no move between them and must mark nothing.

**The mark has to survive a rebuild that changed nothing.** A skin change, a
parent's `setState`, a tab coming back onstage: the position is the same, no
move was played, and recomputing from scratch would answer null and lose the
mark. The board keeps its last answer while the placement is unchanged, and a
mutation deleting that is caught.

### What is still not drawn, deliberately

The replay player and the engine-line dialog navigate **only** by `loadFen`,
between positions that are usually one move apart — so they now draw the move
too, for free. That is a behaviour change nobody asked for and it is the right
one: `replay_player_screen` had been passing `lastMoveColor` and never a square
since it was written, which says what was intended.

`SkinnedChessBoard` is a `StatefulWidget` as of this phase. That is item 7 in
its list of deliberate deviations from the package it forks.

## Phase 3 — the trainer's square becomes a frame, in the app and in the film

**Done 12.9.2026 — 2129 in the app with 1 skipped and 1238 on the backend** with
`.env` moved aside, analyze at 29 infos and zero warnings. From phase 2's 2127
and the backend's 1234: **+2** for the shape asked of the app's canvas, **+4**
for the film's own file. Eight mutations across both ends, all eight caught.

`_paintSquareMark` draws three nested `drawRect` strokes instead of three
circles; `videoRenderer.js` does the same with `strokeRect`. The widths are
0.055, 0.075 and 0.105 of a square's side — the numbers in
`probe_trainer_frames.png`, which is the sheet the decision was made from — with
the author's colour on the outermost band, white inside it and black innermost.

The renderer's last-move colour became the app's: it had been
`rgba(247, 236, 89, 0.45)`, a yellow of its own, since the film was written.

### The two ends are compared, not described

`chess_backend/test/square_mark_frame.test.js` reads the three fractions and the
wash **out of the Dart source** and asserts the film's own constants equal them.
It matches one named constant at a time and fails loudly if it cannot find one,
rather than scanning a region and trusting its shape — a source-reading check
this repository has been bitten by four times.

That is the whole reason the file exists. CLAUDE.md already records a motif
table kept by hand in two places whose sentences drifted apart, and a "neither
Google nor Azure has a Serbian voice" repeated in three files and checked
against one list. A tutorial that looks one way on a trainer's screen and
another way in the film a child is sent is the same fault wearing a picture.

### Three tests that had stopped being about anything

**`board_skin_contrast_test.dart`'s "the ring stays inside its own square" went
on passing while asserting a formula that no longer existed anywhere.** It
reproduced the ring's radius arithmetic — `0.5 - shade / 2 - 0.03` — as a copy
of the code, so when the code went the copy simply carried on agreeing with
itself. What is left there is the part that is about the design (widest first,
and the widest cannot meet itself across the square); where the strokes land is
now asked of the rendering.

**Three tests in `video_renderer.test.js` each carried their own copy of that
same formula**, which is how all three went red together pointing at a number
that had been deleted. They probe one helper now, `onMarkBand`, which takes the
band width from the renderer's own exported constant.

**And the shape itself had no test at all.** The app's marks were asserted by
colour and by reaching the painter, both of which a ring and a frame pass
identically. `square_marks_test.dart` now asks the canvas: no `drawCircle` at
all, exactly three `drawRect`s, each a stroke and never a fill, each inset by
half its own width. The film's half asks a rendered frame whether the **corner**
of the marked square carries ink — the one assertion a ring cannot pass, since a
ring is inscribed and leaves the corners as board.

### What every existing tutorial now looks like

Nothing stored changed. `SquareMark` is a square and a colour letter, and
neither the PGN nor the database ever knew what shape it was drawn as — so every
tutorial already written shows frames from now on, in the studio, in the child's
viewer and in its film. **That is worth the owner looking at one he wrote before
this landed**, which is part C of the live check.

## Phase 4 — selecting a range of squares

**Done 12.9.2026 — 2164 in the app with 1 skipped**, analyze at 29 infos and
zero warnings; the backend is untouched at 1238. From phase 3's 2129: **+24**
for the rule, **+6** for the way in, **+5** for the studio's wiring. Seventeen
mutations, all seventeen caught — four of them only after the wiring got tests
of its own.

`squaresBetween` is the rule, `BoardAnnotationController.tap` takes `asRange`,
and a "Line" button sits in the annotation bar beside Arrow and Square. The
three decisions in the plan all survived being built:

- **a2→c7 is not a line**, and marks only the square just tapped. Inferring a
  rectangle from two corners would surprise anyone who mis-clicked.
- **a range sets rather than toggling each square.** A range over a half-marked
  file would otherwise come out checkerboarded, which is nobody's intention and
  takes another range to undo. Repeating the same range when all of it is
  marked clears it, so one gesture stays reversible by itself — in either
  direction, and whatever colour the squares were drawn in.
- **the button, not only SHIFT.** A phone has no modifier key, so the control is
  in the bar and SHIFT is a shortcut for the same flag: the screen passes
  `asRange: rangeMode || shiftHeld` and there is one code path. The button is
  drawn only in square mode, because an arrow already takes two taps and means
  something else by them.

### Four mutations survived, and it was the same gap as phase 1's

Deleting the whole of the studio's `asRange`, reading only the button, reading
only SHIFT, and dropping the abandoned square — all four left the suite green.
The rule had twenty-four tests and the wiring had none, which is exactly what
phase 1 found when the analysis studio and the drill screen quietly stopped
forwarding. `tutorial_oznake_test.dart` drives the screen and reads the saved
request now, including a **control** case: two taps with neither button nor key
must still be two squares, or a mutation that always asked for a range would
pass the two tests either side of it.

The seventeenth was subtler and is the one worth keeping. "Turning the button
off leaves the half-named square behind" survived even after those, because the
controller **already** drops a pending range on the next ordinary tap — so the
screen's own clearing looked redundant. It is not: off-and-on-again with no tap
between is a path only the screen can see, and without it the next range starts
from a square the trainer abandoned. The test says so; the line stays.

### `HardwareKeyboard`, asked rather than tracked

SHIFT is read at the moment of the tap. A listener of our own would be a second
copy of state Flutter already keeps, and a copy that stays true when the window
loses focus mid-gesture. A test asserts the assumption the whole design rests
on — that with nothing held it answers false, which is every touch device all of
the time.

### Still not decided, and deliberately

Right-click remains bound to copying the FEN on every board
(`chess_board_with_overlay.dart:250`), so the Lichess convention of right-drag
for an arrow and right-click for a square cannot be adopted until somebody
decides where FEN-copying goes. Nothing in this phase touches it.

## What must not break

- **`SquareMark` and the PGN are untouched.** `[%csl Gd5]` stays `[%csl Gd5]`;
  only the drawing changes. A plan that touched the stored form would be a
  migration, and this is not one.
- **The arrow palette is untouched.** No colour value changes, and
  `arrow_color_contrast_test.dart` must stay green with no edit at all. If it
  goes red, something has been changed that this plan did not intend to change.
- **The film and the app must agree at the end.** Both ends of the square mark
  and both ends of the last move, checked against each other, not each against
  its own comment.
- **The counts.** Measured on `master` with nothing else running, before and
  after each phase, and the arithmetic written down. `opening_book_service_test`
  times out when anything heavy runs beside it.

## Live check

`TODO-provera.md` item **153**, in parts, because these are four different
things to look at:

- **A.** The last move is visible in Tactics and in the room, on both squares,
  on the skin the owner actually uses.
- **B.** It is visible but not loud — the piece is not harder to read than before.
- **C.** A tutorial written before this, opened in the studio and in the child's
  viewer: the marked squares are frames, the colours are the ones that were
  picked, and nothing is a circle.
- **D.** The same tutorial exported as a film: the marks and the last move look
  the way they do on screen.

## The probes

`probe_frame.png`, `probe_layer.png`, `probe_trainer_frames.png` and their
`_protanopia` twins were rendered by two throwaway files,
`chess_app/test/zz_frame_probe_test.dart` and `zz_invert_probe_test.dart`, both
deleted at phase 0 — they load Segoe UI from `C:\Windows\Fonts`, would fail on
CI, and would have added three tests to a count this plan asks to be derived.

**The images are in `mislisha-test/qa/probe/`, outside the repository**, which
is public and has never carried a documentation image. Every number they
produced is in this document, which is the part that gets read more than once.
