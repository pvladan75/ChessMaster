# The order of variations — in every move tree, and between a tutorial's branches

Written 26.9.2026 by the lead, on the owner's word. **D1–D6 answered by the
owner the same day: all as recommended. D7 not answered yet** (it is the „leave
it as it is" option, and no phase below touches the PGN tab). Follows
`docs/PLAN-MAPA-DELOVA.md`, whose phases 0–5 are on `master`.

## 1. The request

The owner, 26.9.2026, after the map of parts and its question „which way does
a line go":

> Mi smo imali do sad opciju da se linija predstavi kao glavna ili sporedna,
> ali nismo imali opciju za više sporednih da im menjamo važnost, redosled…
> To bi moglo da se uradi i na nekom opštijem mestu, da važi u čitavoj
> aplikaciji. Dakle, sporedne grane se upisuju po vremenskoj odrednici (kada
> su formirane), sad samo treba da možemo da menjamo njihov redosled.

and, on how it should be reached:

> neka ostane korisniku mogućnost da pomera delove gore dole (strelice u
> zaglavlju dela), a da se promena redosleda grana dešava u stablu poteza
> (grafičkom ili pgn ili u oba, vidi možda desni klik na desktop, a šta za
> android, to ne znam, ispitaj mogućnosti).

His first idea — every new board and everything after it as **one PGN** that
is edited and split back into parts — was weighed the same day and is **not**
in this plan (§7): the join is lossy.

## 2. What exists, measured 26.9.2026

**A tree keeps its variations in the order they were made, and one thing can
change that order.** `AnalysisNode.children` is appended to as moves are played;
`promoteToMainLine` moves a child to index 0 (`APP/features/analysis_studio/models/analysis_node.dart:141`).
Nothing else reorders.

**One tree widget, three screens.** `AnalysisMoveTreeWidget`
(`…/widgets/move_tree_widget.dart`) is drawn by Analysis, the repertoire and the
tutorial studio's „Tree" tab. It has two views behind a toggle: **Visual**, the
graph (`visual_move_tree_widget.dart`), and **PGN**, the notation. The graph's
default layout is **vertical** — the main line down the left, variations side
by side to its right; a toggle turns it horizontal, variations stacked below.

**Both views open a menu by the same two gestures**: a long press (touch) and a
right click (desktop) — `onLongPress` / `onSecondaryTap` in both files. Both open
a **bottom sheet**, on the desktop too, where a menu at the pointer is what every
program does. The sheet holds „Promote to Main Line", „Delete this variation"
(or the caller's label) and one optional extra.

**The menu exists twice and has already drifted.** The notation's copy draws an
item only when its callback was given — written after the 7.9.2026 live finding
of a „Delete" that did nothing (rule 15). The graph's copy draws „Promote to
Main Line" and „Delete" **always**. Today every caller passes both, so nothing
is dead yet; the next caller that does not would get the 7.9 fault back.

**The PGN writer follows the order.** `PgnExporterService` writes the first
child as the main line and the rest as variations in list order, so a reorder
reaches the notation view, the PGN tab and every export with no change there.

**The repertoire's tree is not the repertoire.** It is rebuilt from the server;
„Promote to Main Line" calls `_makePrimary`, a server write. The order of the
other moves is not stored anywhere, so a reorder drawn there would be undone by
the next load.

**A tutorial has no variations left to reorder in its Tree tab.** Since
`PLAN-MAPA-DELOVA` a part is one line; its branches are other parts, and the
Tree tab shows only the open part — a chain. The order of branches **is** the
order of the parts in the film; the ↑ ↓ in the part's header move one part, and
the owner wants them kept as they are. (Parts saved before 26.9.2026 may still
fork inside, D4 of that plan; their Tree tab still shows the fork.)

**On a phone the tutorial studio has no Tree tab** — `Line` and `Parts` only,
deliberately (`[179.2]`). Analysis draws the tree on a phone, portrait and
landscape.

**Where a return hangs** — decided on the owner's word the same day and built
on branch `mapa-delova-povratak-na-potez`: a part that goes back hangs from
**the move it names** („back to after 5. c3" hangs from 5. c3), not from the
last part that showed the position; and a line that enters a part ends in an
arrowhead. Map files 48/48, three mutations red. Phase 0 finishes it. This plan
stands on it: with it, the parts that leave one move are exactly the variations
at that move.

## 3. The model on one page

```
  a GAME TREE                          a TUTORIAL
  ───────────                          ──────────
  a move and its children              a move and the parts that leave it
  children[0] = the main line          the part the move is in goes on first
  children[1..] = variations           the parts that hang from the move
  order = the list                     order = the film
                  ╲                   ╱
                   one command, two homes:
           „Move variation earlier" / „Move variation later"
```

**A branch of a tutorial** is a part that hangs from a move and every part that
hangs from it, directly or through others. Moving a branch moves all of them,
in the order they had; parts that belong to neither of the two branches keep
their places. That is the owner's „da se prebace i svi nastavci".

## 4. Decisions — D1–D6 answered 26.9.2026: all as recommended; D7 open

**D1. Where the command lives.** In the move tree's menu, in both of its views
(one menu, so both views get it together). On a phone's tutorial studio, which
has no tree, on a map row's long press — the same command on the same branch.
The ↑ ↓ in a part's header stay as they are: one part, one step (the owner).

**D2. What it is called: „Move variation earlier" / „Move variation later".**
Not „up/down": the graph's default is vertical, variations side by side, so „up"
would be wrong on the first thing a reader sees. Not „Promote / Demote
variation" (ChessBase, Lichess): beside our „Promote to Main Line" it reads as
the same command. „Earlier" is literally true everywhere: written earlier in the
PGN, drawn nearer the main line, shown earlier in the film. „Variation" is the
glossary's word.

**D3. On the desktop, right click opens a menu at the pointer**; a long press on
touch keeps the bottom sheet. One list of items, two presentations — and the
two drifted copies of §2 become one.

**D4. Nothing passes the main line.** „Earlier" stops at the first variation;
only „Promote to Main Line" changes which line is main. In a tutorial the part
the move belongs to always goes on first, and a branch cannot move before it —
it would open before its position was ever shown.

**D5. Not in the repertoire.** Its order is not stored, so the items are not
drawn there. If wanted, it needs a server column — its own decision.

**D6. The tutorial's Tree tab shows the open part's whole family.** Every part
connected to the open one by hanging, joined into one tree **for display only**:
copies, each node remembering its part and beat. Tapping a node opens that part
there. Nothing is merged into the draft and nothing is stored, so no sentence is
lost — the reason the one-PGN idea is not in this plan. „Promote to Main Line" is
offered only on a variation inside one part (a tutorial saved before 26.9.2026);
between parts, order is the only thing to change.

**D7. The PGN tab of the tutorial is unchanged** — the open part as text, one
line. The tree widget's own PGN view does get the command (D1).

## 5. Where it is reached, platform by platform

| | Analysis | Tutorial, wide window | Tutorial, phone | Repertoire |
|---|---|---|---|---|
| Windows | right click on a move, either view → menu at the pointer | the same, in the Tree tab | — | not drawn (D5) |
| Android | long press on a move, either view → bottom sheet | the same (tablet) | long press on a map row → bottom sheet | not drawn |

Ways considered for Android and not taken: dragging a branch in the graph (a
drag there already pans and zooms, and a long press already opens the menu);
a separate „reorder mode" with handles (a second way to do one thing).

## 6. Phases, each with its gate

Baseline to re-measure in phase 0: app **4101** + the variant's two new cases,
backend **1747 / 1905**, `analyze` **22**.

### Phase 0 — where a return hangs, and arrowheads [lead] — done 26.9.2026

Full run **4103** passed, 1 skipped (4101 + the fan out of one move in
`tutorial_part_map_test` + the arrowhead in `tutorial_parts_map_screen_test`);
`analyze` the same 22. Three tests that pinned the old rule rewritten openly
(§3's sources and lanes, and what the rows' painters are given); three
mutations — the old rule, no arrowheads, arrowheads on leaving lines too — each
red on the right case. The arrowhead is asserted as a painted path, the only one
the gutter's painter draws. Rendered and sent to the owner for „proba 2", the
sketch, and a second move played inside a part.


Built; measure it whole, write it down, merge. The words: a note under §3 of
`PLAN-MAPA-DELOVA.md` (its table's sources and lanes are superseded), the manual
and `UPUTSTVO-STUDIO.md` (a line ends in an arrowhead at the part it leads to,
and a return leaves the move it names), a new live item — `[247.3]` is not
reworded, because the QA tool matches items by text.

- **Gate:** the full run; the map files' cases as they stand on the branch.

### Phase 1 — variations in any tree [implementer]

- `AnalysisNode.moveVariation(child, {required bool earlier})`, pure: never past
  index 0 (D4), ids and subtrees untouched.
- One menu definition used by both views, items drawn only where they do
  something — „earlier" not on the first variation or the main line, „later"
  not on the last; the graph's always-drawn items fixed with it.
- Desktop: secondary tap → menu at the pointer (D3); touch: long press → sheet.
- Analysis wires it and saves the draft, as promote does; the tutorial's Tree
  tab wires it for variations inside one part; the repertoire passes nothing.
- **Gate:** pure cases for order, bounds and the main line; the menu opened by
  a secondary tap on Windows and by a long press on Android, in both views, with
  exactly the items that apply; after the command the PGN export writes the
  variations in the new order; an Analysis saved and reopened keeps it; the
  graph's menu without a callback draws no dead item (red on master).
  Mutations: past the main line; „earlier" offered on the first; the order not
  saved; the graph's menu back to always-drawn.

### Phase 2 — a tutorial's branches [implementer; the rule is the lead's]

- `moveBranch(draft, part, {required bool earlier})`, pure, on `partMapOf`:
  siblings are the parts that hang from the same beat; a branch is §3's set;
  the two branches' parts are re-sequenced into the positions they held, and
  every other part keeps its place.
- `tutorialTreeOf(draft)`: the open part's family as one tree of copies with a
  node → (part, beat) map (D6). The Tree tab draws it; tap opens; the menu
  offers the command on a node that starts a branch.
- The phone: a map row's long press offers the same command.
- **Gate** (on the sketch, with phase 0's rule): the three branches that leave
  16... Nc4 are {2, 3, 4}, {5} and {6, 7}; „later" on 17. Be3 gives
  1, 2, 3, 4, 6, 7, 5, 8; „earlier" on it gives 1, 5, 2, 3, 4, 6, 7, 8, where
  part 5 now continues part 1 and part 2 goes back — **the film is the proof**:
  every move filmed once, every sentence where it was; a branch is never offered
  a place before the part its move belongs to; the Tree tab of any part shows
  the whole family and a tap opens the right part at the right beat; the phone
  at 360 × 640 reaches the command from a row. Mutations: one part moved
  instead of the branch; the order of a branch's own parts changed; a part of
  neither branch moved; the command offered before the owner part.

### Phase 3 — the words [lead]

The manual, `UPUTSTVO-STUDIO.md`, the glossary (the label pair, if D2 is
answered so), `STANJE-RADA.md`, live items.

### Phase 4 — the owner's live pass [owner]

## 7. Not in this plan

- **A tutorial, or a family of parts, as one editable PGN.** Two sentences often
  stand on one position — a part that only adds a sentence to where the one
  before it ended (part 2 of the sketch), and a return's opening sentence beside
  the earlier part's own sentence on that move. A tree node holds one comment,
  so the join glues them (as `pgn_tutorial_export.dart` already does) and the
  split cannot give them back. Doing it right needs a comment before a
  variation's first move in the app's one reader (rule 13) — its own plan.
  D2 of `PLAN-MAPA-DELOVA` also shows the side lines of a fork before the line
  going on, so in such a PGN the main line would be the one shown last.
- Dragging branches in the graph; a keyboard shortcut for the command.
- The repertoire's order (D5).
