# Plan: the tutorial as text, and the text as a surface

Written 7.9.2026 by the lead, after the owner's live pass over
`docs/PLAN-STUDIO-REDIZAJN` and two requests made during it: a text view of a
part in which comments, arrows and coloured squares are visible and editable in
place, and a right-click menu on a move in that text offering the same three
things — or the board, by drawing, which already works.

It adds one surface to the studio and changes no model. Read
`docs/PLAN-STUDIO-REDIZAJN.md` first; this file assumes its D1–D9 and does not
restate them.

## 1. Why this is worth building

**Two problems, and the second one is the larger.**

**1.1 Some edits are text edits.** Deleting one arrow today means finding the
move, entering drawing mode, and redrawing the same two squares to toggle it
off. In text it is deleting eleven characters. The same goes for moving a
sentence from one move to the next, fixing a typo in the middle of a long
annotation, or seeing at a glance everything a part carries.

**1.2 There is no door for an annotated line produced anywhere else.** The app
has exactly one PGN import — `AnalysisStudioScreen._importPgn` — and it goes
through `chess.load_pgn` and `getHistory()`, which keeps the main line and
throws away **every comment, every `[%cal]`, every `[%csl]` and every
variation**. `step_tree.dart` says in its own header that it must never be used
for this.

So a trainer who has an annotated game — from a book, from an engine, from the
markdown a language model wrote out of a PDF (7.9.2026, `D:\chess books`) —
cannot get it into a tutorial except by replaying it move by move and retyping
the words. **This plan is that door**, and it costs almost nothing extra: the
same text field that lets you delete an arrow lets you paste a whole annotated
line.

## 2. What already exists — the reason this is small

Both directions are built, merged and tested.

* **Out:** `PgnExporterService.exportToPgn(root)` writes the headers, the note
  about the starting position ahead of move one, `[%cal]` and `[%csl]` on every
  node that carries them, and the variations as `( … )`. A part that does not
  start from the initial position gets `[SetUp "1"]` and `[FEN …]`, so the text
  carries its own position.
* **In:** `LessonStepLine.read(fen:, pgn:)` — **the one reader, the child's** —
  returns the tree with comments, marks and sidelines intact, and
  `rejectedMoves`, the count of move tokens that could not be played from the
  position the walk had reached. `readStepTree` crosses from `MoveNode` to
  `AnalysisNode` and parses nothing a second time.
* **The round trip is gated.** P2's byte-identical test, and the rule that an
  untouched part is written back as the exact text it was read from.
* **The refusal exists.** `StudioLessonStep.from` reads its own work back
  through the reader before saving and refuses a line that does not replay.

Nothing in this plan needs a new parser, a new writer or a new model field.

## 3. Decisions to freeze

### D1 — standard tags, and no dialect of our own

The text says `{ komentar [%cal Gd2d5][%csl Rd5] }`, which is what Lichess,
ChessBase and SCID write and read. The owner's sketch used `(strelica d2d5)` and
`(oznaka_polja d5)`; those are rejected, for three reasons that all point the
same way: a text nobody else can read cannot be pasted anywhere, a PGN from a
book or from Lichess would arrive without its arrows, and we would be writing a
**second parser and a second writer** — the fault this repository has already
paid for twice.

What the reader is owed instead is a **legend**, one line above the field, in
Serbian: what `[%cal]` and `[%csl]` mean and which letter is which colour
(`G` zelena, `R` crvena, `B` plava, `O` narandžasta, `Y` žuta — from
`ArrowColor.all`, never typed out a second time).

### D2 — one cursor, three surfaces

„Tok", „Stablo" and the new text tab are three views of the **same**
`AnalysisNode` and the same cursor. Putting the caret inside a move's text
selects that move: the board goes to that position, the timeline's current beat
moves with it, and drawing on the board writes onto that node.

That is the whole reason this is a tab and not a second editor. The retired
`LessonStepEditorPanel` was a second *model*; this is a second *rendering*.

### D3 — the text is applied, not parsed as it is typed

Half a written move is not a valid PGN, and a live parse would empty the tree
while the trainer types. The field has two states and says which it is in:

* **clean** — the text is exactly what the tree exports. The right-click menu
  works, the caret moves the cursor, and any edit made through the menu or the
  board rewrites the text from the tree.
* **dirty** — the trainer has typed. „Primeni" parses through the one reader;
  the menu is disabled until then, with a sentence saying so.

### D4 — the question stays out of the text

`kind`, „Zadatak za učenika" and the offered answers are step fields, not PGN.
Writing them into the comment would put lesson state inside prose that a child
reads, and the answer-leak refusal — the single refusal this app makes on its
own — would have to be measured over that prose. The text edits the **line**;
the question card stays the question card.

### D5 — the spans come from the writer, never from re-tokenising

The right-click menu has to answer „which move is the caret in". That mapping
comes from `PgnExporterService`, which writes into a `StringBuffer` node by node
and therefore knows exactly where each node's text begins and ends: an optional
collector records `(start, end, nodeId)` as it writes.

**It must not come from re-tokenising the edited text.** `MoveTree.parsePgn`
rewrites its input before splitting it (`cleaned.replaceAll('(', ' ( ')` and
friends), so offsets into the cleaned string do not point at the trainer's text
— and teaching the one parser to carry offsets is a change to the one parser,
for a menu. D3's clean/dirty rule is what makes D5 enough: the menu is offered
only when the text on screen is the text the writer just wrote.

### D6 — a refusal says how many moves and from where

`MoveTree.parsePgn` skips a move it cannot play **without a word**; that is why
`rejectedMoves` exists and why nothing here may ignore it. „Primeni" refuses a
text with `rejectedMoves > 0` and says the count.

The likeliest cause is not a typo: it is a pasted game that starts from the
initial position dropped into a part that stands on move twelve, where **every**
move is rejected. So when the pasted text carries its own `[FEN]`, the trainer
is asked, once, whether that position becomes this part's starting position —
asked, never assumed, because assuming it silently moves the board a child will
open on.

### D7 — the menu is three actions, and the board is the other way to two of them

Right-click on a move offers exactly:

1. **Dodaj strelicu** — pick a colour, then draw it on the board; the arrow
   lands on the move that was clicked.
2. **Označi polje** — the same for a square.
3. **Dodaj komentar** — a small field for that move's `{ … }`.

The first two are the drawing that already exists (`BoardAnnotationController`,
P7): the menu selects the node and turns the mode on, and the trainer draws.
**No second way of drawing is written.** Adding a mark by typing the tag is
still possible, because it is text.

## 4. The screen

```
authoring pane, lower half
├ tabs: [Tok] [Stablo] [PGN]                     ← the third is new
└ PGN
  ├ legenda:  [%cal Gd2d5] strelica · [%csl Rd5] polje · G zelena, R crvena…
  ├ TextField (multiline, monospace, the part's text)
  │    right-click → Dodaj strelicu · Označi polje · Dodaj komentar
  └ [Primeni]     ● izmenjeno / ✓ primenjeno
```

The tab's name is **„PGN"** rather than „Tekst": the trainer this is for uses
the word, and it says what the field will refuse. It goes in
`docs/TABELA-TUTORIJAL.md` with „Tok" and „Stablo" and is enforced by
`tutorial_vocabulary_test.dart`.

## 5. What must not be lost

Each one is a line in a gate.

1. **The reader is `LessonStepLine`.** Nothing here parses a PGN a second way.
   `_importPgn` is not reused and not copied — the rule `step_tree.dart` already
   carries.
2. **A part that is only a sentence still round-trips.** The note on the root
   travels ahead of move one, and applying a text that has only a comment must
   not empty the part.
3. **The pristine cache is invalidated on apply.** An untouched part is written
   back as the exact stored text; a part whose text was applied is not untouched
   any more, and `treeSignature` is what says so.
4. **Step ids survive.** Applying a text replaces a part's *tree*, never its
   identity: `stepId` is what `assignment_items` and `review_items` name a step
   by, and nothing joins on it.
5. **The answer-leak refusal still fires.** Pasting a line into a part that asks
   for a move is exactly how a question comes to carry its own answer, and P8a's
   refusal must see it — `hasLine` asks the tree, so it does.
6. **Nothing is auto-applied on tab change.** Leaving the tab with unapplied
   text keeps the text and says so; it does not quietly parse or quietly drop.

## 6. Phases

| | what | who | why there |
|---|---|---|---|
| **T1** | `exportWithSpans`: `(start, end, nodeId, kind)` per move and per comment. Headless tests | **lead**, done 7.9.2026 (`e45f004`) | fifteen tests, five mutations; `exportToPgn` delegates, so the old output is unchanged by construction |
| **T2** | The „PGN" tab: text, legend, clean/dirty, „Primeni" through `LessonStepLine`, the refusals of §5 | worker | one widget, one wiring; the reader already exists |
| **T3** | The caret is the cursor (D2), both ways | worker | small, but only sensible once T2 exists |
| **T4** | The right-click menu (D7), drawing through `BoardAnnotationController` | worker | needs T1 and T3 |
| **T5** | The `[FEN]` question (D6) and „paste a whole game" as its own live check | **lead** | it is the one branch that moves the board a child opens on |
| **T6** | Docs: `TABELA-TUTORIJAL.md`, `STANJE-RADA.md`, `TODO-provera.md` | lead | as part of the work |

**T1 first and alone.** It is the pure core — the same shape as `beatsOf` before
the timeline — and a batch that has it has nothing left to decide about where a
caret is.

**T2 is worth doing even if nothing after it is.** The tab alone closes 1.2, the
missing door, which is the half of this plan that changes what the product can
do rather than how comfortable it is.

## 7. The gate, in outline

Every one of these asserts on the **model or the request**, never on the text
being on screen:

* a part exported, edited by hand (a comment added, an arrow deleted) and
  applied comes back as a tree with exactly that change — read through
  `LessonStepLine`, asked which move carries what;
* an applied text with an unplayable move is refused, with the count, and the
  tree is **unchanged**;
* a pasted game whose `[FEN]` differs asks before moving the part's position,
  and answering „no" changes nothing;
* a part that is only a sentence survives export → apply untouched;
* `stepId` and the part's title survive an apply;
* the caret in a move selects it: the board's FEN and the timeline's current
  beat both move (asserted on the board and the panel, not on the text);
* an arrow drawn on the board after a right-click lands on the clicked move —
  asserted in the saved `pgn`;
* the menu is unavailable while the text is dirty;
* leaving the tab with dirty text loses nothing.

## 8. What this plan does not do

* It does not touch `MoveTree.parsePgn`. One parser, and it stays as it is.
* It does not add a field to a step, to the wire or to the database.
* It does not put the question, the offered answers or the kind into the text.
* It does not give the **student** a text view. What a child gets is the board
  and the sentence; the PGN is the trainer's tool.
* It does not replace „Tok" or „Stablo". Three views of one tree, and the
  timeline stays the default, because it is the only one that shows what the
  child will experience.
