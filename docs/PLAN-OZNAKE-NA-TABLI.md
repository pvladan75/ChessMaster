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

`ChessBoardPainter` loses `lastMoveFrom`, `lastMoveTo`, `lastMoveColor`,
`_paintLastMoveBrackets`, `lastMoveMarkerShade` and `lastMoveMarkerLight`.
`ChessBoardWithOverlay` forwards the two square names into `SkinnedChessBoard`
instead of into the painter.

**Tests that change, and they change because the behaviour changed, not because
they were wrong.** `last_move_marker_test.dart` is six tests about a marker that
will not exist; it is rewritten against the layer, keeping every question it
asks — both squares get the mark, no move means no mark, the mark stays inside
its own square — and dropping the two that are about the brackets' colours.
`board_skin_contrast_test.dart` loses the two bracket tests and the two ring
tests, and gains one: the wash darkens every square of every skin by a
measurable amount, for every kind of eye.

**Do not delete a test and call the count "expected".** The arithmetic goes in
the commit message, test by test, the way every count in CLAUDE.md is derived.

## Phase 2 — every board draws it

Today 5 of the 15 screens that build `ChessBoardWithOverlay` pass the last move.
These ten do not, and the two at the top are the two the owner reported:

`tactics_trainer_screen` · `chess_game_screen` (the room) ·
`endgame_trainer_screen` · `blunder_walk_screen` · `mistake_drill_screen` ·
`review_session_screen` · `lesson_viewer_screen` ·
`custom_puzzle_solver_screen` · `repertoire_new_screen` ·
`lesson_step_editor_panel`

**It must not be ten more call sites.** `ChessBoardWithOverlay` derives the
squares from its own controller through `lastMoveSquares` when the caller passed
none, and a caller that wants none says so explicitly. Ten screens that each
have to remember to pass a parameter is how this ended up 5-of-15 in the first
place, and this file already records three other features that were complete at
every layer and reachable from nowhere.

**One judgement to make while building it:** a screen that loads a position from
a FEN has an empty history, so nothing is drawn — correct, and it is what the
puzzle screens do on their first frame. But a puzzle where the *opponent replies*
does have a history, and that reply is the whole reason report #3 exists. Both
cases need a test.

**Gate.** One test per screen is too many; one test that walks a representative
three — a puzzle screen, the room, a viewer — plus one that asserts the
derivation happens at all, plus one that asserts an explicit opt-out wins.

**Mutation:** delete the derivation fallback. Every screen that never passed the
parameter goes back to drawing nothing, and if the suite stays green the gate is
testing the five screens that already worked.

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
