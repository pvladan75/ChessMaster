# Plan: rebuilding how a repertoire is built

Written 31.8.2026, after the project owner used the finished trainer for the
first time and reported that building is confusing. The four rules below are
his, agreed in that conversation; the amendments and the layout are the
review of them.

This replaces the *interaction*, not the store. `repertoire_moves`,
`repertoire_skips`, `repertoire_extra_replies`, `opening_replies` and the
derived walk all stay exactly as they are.

---

## Why the current loop is confusing, precisely

Not a matter of taste. Three facts about it, each visible in the screenshots
from that session:

**1. It asks you to build a tree while never showing you the tree.** Every
question is one position with a breadcrumb above it. What you are building has
no picture, so each answer is a decision made blind. The graphical tree exists —
it was added the same day — but it is a *screen*, so seeing it means leaving the
board and coming back.

**2. Getting to a line takes dozens of decisions.** The loop starts at the root
and covers one wave at a time. For anything ten moves deep, that is thirty
questions before it looks like an opening. Nothing is wrong with the questions;
there are simply too many of them before the first reward.

**3. The board sits in the middle of an empty screen.** The board is capped at
420px. On the owner's 1900px window that leaves most of the screen unused, while
the thing he wanted to see was one navigation away.

---

## The four rules

Agreed with the owner, in his words, with the reading each will be built to.

### R1 — Auto-spine builder

Pick a starting position, give a depth *N* (moves for my side), and the system
generates the most frequent spine: Top-1 for both sides, *N* moves deep.

### R2 — Changing my move prunes what was behind the old one

If I change my move at a node, everything generated behind the old choice is
removed, and auto-building can be run again from the new move.

### R3 — The opponent's replies beside the board

A Lichess list of the opponent's most common replies sits next to the board,
each with a button that starts a new branch from that point.

### R4 — Engine on demand only

The engine runs when the user presses a button, and adds an evaluation and a
best line to the node.

---

## Three amendments

These are the parts of the review the owner accepted. Each exists because of
something this project has already got wrong once.

### A1 — An auto move is not a decision, and must never look like one

This is the same failure the archive seed had, and it was deleted on 31.8.2026
for it: the seed wrote moves into the same graph as the student's own choices,
they became indistinguishable, and the drill went on to ask the student to
recall moves they had never chosen — and marked them correct. A spine writes
moves the student did not choose. Better moves, identical failure.

So:

- `repertoire_moves` gains **`source`** — `'chosen'` (default) or `'auto'`.
- The drill **never asks about an `auto` move**: not `nextItem`, not
  `drillStats.positions`, not the line walk's question. They are scaffolding.
- The tree and the map draw them differently, and say how many there are.
- **Confirming is an act.** Walking a line and keeping its moves turns them into
  `chosen`, one node at a time or a whole line at once. That act is what makes
  the spine safe to offer at all.

The spine is a **draft of a repertoire**, and the screen says so in those words.

### A2 — Pruning is by reachability, never by subtree

The store is a graph keyed by position (`fen_key`), not a tree keyed by path.
That is deliberate — it is what makes work deep in the Smith-Morra part of a
later 1.e4 repertoire the moment it reaches the same board — and it means
"everything behind the old move" is **not** a subtree that can be deleted. A
position under the abandoned move may also be reachable through a line that is
still played, and deleting it would silently damage a line nobody touched.

The rule is therefore: delete what becomes **unreachable** from the roots of
every repertoire of that colour. Same intent, computed rather than assumed, out
of the walk that already exists.

And: `auto` moves go silently; if the sweep would remove moves that were
**chosen**, it counts them and asks first. Losing an evening's work to a changed
second move, with no sentence about it, is a thing that happens once and ends
trust in the feature.

### A3 — A panel beside the board must not cost a request per click

One token serves every child using this app, and the panel in R3 follows the
board. So: the list is drawn from `opening_replies` — what has already been
fetched, by anyone — and a Lichess request is spent **only** when the position
has never been opened by anybody. The same discipline the arrows already keep:
a drawing is not worth a request the student did not ask for.

---

## The layout: one screen, and the tree is a panel on it

The owner's objection is that the tree being a separate screen makes it nearly
useless. He is right, and the app has already solved this once: **Analiza has no
separate tree screen.**

`AnalysisMoveTreeWidget` is a panel that already provides four things this needs:
a toggle between PGN text and the graphical tree, a height cap so it can sit
under a board, a fullscreen button, and — in fullscreen — closing on a node tap,
so a jump lands you back at the board. It is composed with `Breakpoints.isWide`
(840dp), which every screen in the app shares.

**Wide (≥840dp).** Two columns: board with the question and controls on the
left, tree filling the rest on the right. This costs nothing — the board is
capped at 420 and that space is already empty. Above roughly 1400dp it becomes
three: board | question and the replies list | tree.

The 420 cap should grow with the window in the same pass. A 420px board in a
1900×1000 window is a phone layout wearing a desktop.

**Narrow (<840dp).** One column, the tree panel under the board, collapsed, with
the fullscreen button for the whole picture — the studio's arrangement. The tree
is a scroll away, never a navigation away.

**Both.** A single always-visible **strip** directly under the board: parent →
current position → its children, each with its mark (★, %, `?`, `…`, `✂`). That
is the part of the tree needed while answering a position, it costs one row, and
it is readable at 360dp where a pan-and-zoom canvas is not. On the phone the
strip *is* the tree; the canvas is one gesture away.

**The tree becomes the navigation.** Tapping a node moves the board and the
question panel follows. "Gradi odavde" and "Vežbaj ovu granu" stop being buttons
— you are already there. The panel's existing context menu maps onto the two
edits: promote → make primary, delete → prune under A2.

**Consequence.** `RepertoireTreeScreen` stops being a screen: it becomes the
converter (repertoire → `AnalysisNode`) plus that panel. Its fullscreen view
survives as the dialog already inside the panel. The thing that could not be
found becomes the thing that cannot be missed.

---

## What changes, concretely

### Database

- `repertoire_moves.source` — `VARCHAR(8) NOT NULL DEFAULT 'chosen'`, checked
  against `('chosen','auto')`. Added with `ADD COLUMN IF NOT EXISTS`; existing
  rows are `chosen`, which is true once the imported-move cleanup has been run.
- `repertoire_notes (user_id, color, fen_key, eval_cp, eval_depth,
  best_line_san, updated_at)` — R4's evaluation, per position. New table because
  there is no per-position table yet; it is also where a comment would go later.

### Routes

| Route | What |
|---|---|
| `POST /repertoire/spine` | R1. `{color, rootFen, rootPath, depth, minRating, minGames}` |
| `POST /repertoire/node/confirm` | A1. one `auto` move becomes `chosen` |
| `POST /repertoire/line/confirm` | A1. a whole line at once |
| `POST /repertoire/node/primary` | exists; gains the A2 sweep |
| `GET /repertoire/book` | A3. stored replies, and whether the position was ever opened |
| `PUT /repertoire/note` | R4. eval and best line for a position |

### The spine, in detail

At each ply: if the position already has a **chosen** move, follow *that* —
never overwrite a decision, which also makes the spine safe to re-run and makes
"continue from here" natural. Otherwise take Top-1 from the book, write it with
`source='auto'`, and store the whole reply list in `opening_replies` on the way
past, since it has to be fetched anyway.

It **stops early** when the line runs thin — below a games floor — and says
where and why. Top-1 at ply 20 is sometimes forty games, and a spine that runs
to the requested depth regardless hands back authoritative-looking noise.

Cost: two requests per move of depth, paced by the limiter the judge already
has, and free on any position anybody has opened before.

### Screens

- `repertoire_build_screen.dart` — takes the tree panel, the two/three column
  layout, the strip, and the replies panel. It becomes the one screen.
- `repertoire_tree_screen.dart` — becomes a widget; the route goes.
- `repertoire_coverage_screen.dart` — unchanged, and gains a count of how much
  of the map is still a draft.
- `repertoire_drill_screen.dart` — unchanged except that its questions come only
  from `chosen` moves.

---

## What is deliberately not changing

- **The store.** Positions keyed by `fen_key`, moves belonging to (user,
  colour), one primary per position. Everything above is built on it.
- **The derived queue.** `GET /repertoire/frontier` stays and stays derived. The
  tree answers "where am I"; the queue answers "what next", which is the one
  question a picture does not answer.
- **The cut** (`repertoire_skips`) and **the hand-picked tail**
  (`repertoire_extra_replies`). Both are decisions, both survive.
- **The drill's schedule.** SM-2 through `spacedRepetitionService`, one
  algorithm, as everywhere else.

---

## Open questions

Three, and they are decisions rather than details.

1. ~~**The rating band.**~~ — decided 31.8.2026 by the owner: **1600 by
   default**, selectable. The ladder is Lichess's own Explorer buckets, and only
   those — `RATING_BUCKETS = [0, 1000, 1200, 1400, 1600, 1800, 2000, 2200,
   2500]`, and the service refuses anything else by name, so 1500 and 2100 were
   not available to offer. In the app: 1400 / 1600 / 1800 / 2000.

   A band is a floor and the answer unions everything above it, so 1600 means
   "1600 and up". That is kept rather than narrowed to a single bucket for a
   reason that is not about taste: `opening_replies` is keyed on the floor and
   **shared between users**, so changing what a floor means without changing the
   key would leave one key holding two different answers.

   **Masters is deliberately not a rung.** It is a different database answering
   a different question — "what is theory" against "what will I meet" — and
   putting it at the top of the ladder would quietly change what the number
   means. It belongs with the spine, as a switch beside the band.
2. **Does the drill ever ask about `auto` moves?** The plan says no. A defensible
   alternative is that it asks, but the first answer is a *choice* rather than a
   test — the position is offered, whatever you play is kept, and it becomes
   `chosen`. That turns the drill into the confirming pass.
3. **What happens to the coverage map when most of a repertoire is a draft?**
   "Spremljeno 80%" where three quarters of it is auto would be the same lie the
   seed told. Simplest answer: the map counts `chosen` only, and reports the
   draft as its own number beside it — the same rule the cut already follows.

---

## Order of work

1. ~~**Layout.**~~ — done 31.8.2026, by the lead after the batch that was
   briefed for it timed out. Two columns rather than three; the strip, the
   navigation and the board cap are all in. See `STANJE-RADA.md`, "Stablo je
   sada pored table".
2. ~~**`source` and confirming.**~~ — done 31.8.2026. The column, every read in
   the drill honouring it, `draft` counted apart from `decided` in the map, and
   both confirm routes. The rating band was decided and wired at the same time.
3. ~~**The spine.**~~ — done 31.8.2026, with the games floor and the
   never-overwrite rule. Synchronous, capped at 12 moves.
4. ~~**Pruning by reachability.**~~ — done 31.8.2026, hung on removing a move
   rather than on promoting one: with `role`, changing the primary leaves the
   old move in place as an alternate and nothing is stranded at all.
5. ~~**The replies panel beside the board.**~~ — done 31.8.2026, out of the
   stored book, so it costs nothing and can simply sit there.
6. **Engine notes on the node.** R4 and `repertoire_notes`.

Steps 1 and 2 are independent of each other and of everything else; 3–6 depend
on 2.
