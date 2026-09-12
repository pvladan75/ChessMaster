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

`_paintSquareMark` becomes `_paintSquareFrame`; the three ring constants become
three stroke widths. `videoRenderer.js` `drawSquareMark` does the same, with the
same proportions, and the two are checked against each other rather than each
against its own idea of the shape.

**The renderer's last-move colour changes to match the app's** — `rgba(247, 236,
89, 0.45)` becomes the app's constant. Nothing else in the film changes: it
already paints it in the right place.

**Gate, app side:** the frame reaches the canvas on both squares, sits inside
its own square, and is drawn *over* the pieces (the opposite of phase 0's
assertion, and for the opposite reason — an annotation about a piece drawn
beneath it is an annotation about nothing).

**Gate, film side:** a rendered frame is read back pixel by pixel, which is what
`videoRenderer`'s tests already do. Ask the question the file-letter test learned
to ask: is there ink on this square's edge that is not the colour of this square
— with the board empty, so a piece standing there cannot answer for the frame.

**The one thing that must not be forgotten:** the child's viewer
(`lesson_viewer_screen`) draws `[%csl]` too. Every tutorial already written
carries rings that will become frames. Nothing stored changes — `SquareMark` is
a square and a colour letter, and neither the PGN nor the database knows what
shape it is drawn as — but the change is visible in every tutorial at once, and
the owner should see one he wrote before this is called done.

## Phase 4 — selecting a range of squares

Separate from the three above, and it should land after them: it is an authoring
convenience, and the other three are what a child sees.

`BoardAnnotationController` gains a range entry point beside `tap`. The rule:

- **a2 → a7** marks the file between them; **a2 → e2** the rank; **a2 → d5** the
  diagonal.
- **a2 → c7 is none of the three**, and marks only the square clicked. Inferring
  a rectangle would surprise anyone who mis-clicked, and a rectangle is a
  different feature that can be asked for later.
- **A range sets, it does not toggle each square.** A range over a half-marked
  file would otherwise come out checkerboarded. Repeating the same range when
  every square in it is already marked clears it — one rule, reversible.

**SHIFT is desktop-only, and Android is a real target.** A phone has no modifier
key, so a SHIFT-only design ships this to half the users. The interaction is a
**range toggle in the annotation bar** that makes the next two taps a range —
identical on both platforms — with SHIFT as the desktop shortcut for the same
thing. One button, one code path, no keyboard required.

**And a conflict to resolve before any mouse-native drawing is designed:**
right-click is already bound on every board — `onSecondaryTap` copies the FEN
(`chess_board_with_overlay.dart:250`). The Lichess convention of right-drag for
an arrow and right-click for a square cannot be adopted without deciding where
FEN-copying goes. That decision is not made here.

**Gate.** The controller is pure and has no widget in it, so this is a plain
test file: the three collinear cases, the non-collinear refusal, set-not-toggle,
and the clear-on-repeat. Mutations: delete the collinearity check (a2 → c7 must
not fill anything); delete the clear-on-repeat; make the range toggle each
square.

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
