# Brief: the order a repertoire is read in

Phase 3 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`, written 4.9.2026.

## 1. Why this job exists

The owner built a repertoire and could no longer read it:

> Kada gleda u stablo, teško je povezati celinu: „Šta ja zapravo igram u kojoj
> situaciji i šta me sve čeka?"

Phase 2 made the *picture* legible — a move of his, an answered reply and a hole
are now three different shapes. This phase is the other half: an opening is
learned as a **story**, not as a diagram. This line, to its end; then back to
the last fork and out along the next one.

Your job is the story's running order, and nothing else. No screen, no voice, no
board — those are phases 4 and 5, and they are briefed against what you write
here. This is the part that is hard to get right and easy to test, which is
exactly why it is a batch of its own.

## 2. What already exists — read these before writing anything

| Where | What it gives you |
|---|---|
| `lib/features/repertoire/services/repertoire_api_service.dart` | `RepertoireTree` and `RepertoireTreeMove` — the shape you read. **Frozen.** |
| `lib/features/repertoire/widgets/repertoire_tree_panel.dart` | `lookOfRepertoireMove(move)` → `MoveTreeNodeLook` — which of the four a move is. **Use it; do not rewrite it.** |
| `lib/features/analysis_studio/widgets/visual_move_tree_widget.dart` | `MoveTreeNodeLook { authored, covered, gap, refused }` |

`RepertoireTreeMove`, exactly:

```dart
final String uci;      // 'e2e4'
final String san;      // 'e4'
final String fen;      // the position this move leads to
final bool mine;       // whose move it is
final String? role;    // mine only: 'primary' | 'alternate'  (isPrimary)
final double share;    // theirs only: 0..1, how often it is played
final String state;    // '' | 'open' | 'unopened' | 'cut' | 'decided'
final List<RepertoireTreeMove> children;
```

`state` describes **the position the move leads to**, so it reads differently on
the two kinds of card. On a move of theirs, `open` means the reader has no
answer there — that is a hole.

## 3. The contract

Write exactly this. Phase 4 is briefed against it.

```dart
/// One move, visited once, in the order a tour reads it.
class WalkthroughStop {
  const WalkthroughStop({
    required this.move,
    required this.path,
  });

  /// The move being visited.
  final RepertoireTreeMove move;

  /// The SAN moves from the root down to and including [move].
  /// The tour's "where am I", and what phase 4 puts under the board.
  final List<String> path;

  /// How deep this stop is. Always `path.length`.
  int get depth => path.length;

  /// Which of the four this is, from `lookOfRepertoireMove`.
  MoveTreeNodeLook get kind => lookOfRepertoireMove(move);
}

/// Every move in the drawing, in the order the tour visits them.
List<WalkthroughStop> walkthroughOrder(RepertoireTree tree);
```

### The ordering rule

Depth-first from the root. At every position, the moves under it are visited in
this order:

1. **The reader's own moves** (`mine == true`) come before the opponent's at the
   same position. In practice a position holds one kind or the other, so this
   rule almost never fires — write it anyway, because "almost never" is not
   "never", and the alternative is an order that depends on what the server
   happened to send.
2. **Among the reader's own moves:** `isPrimary` first, then the rest in the
   order the server sent them. Not by share — one of their own moves has none,
   and which of them they play is a decision rather than a frequency.
3. **Among the opponent's replies**, in this order:
   1. a reply **whose subtree contains at least one move of the reader's own**
      comes before one that contains none;
   2. then by `share`, descending;
   3. then in the order the server sent them.

**Rule 3.1 is the point of this batch, and the owner decided it explicitly.**
Since the walk began following a reply that leads into the reader's own work at
every breadth, a branch holding most of what they built can sit behind a rarely
played reply — on the owner's „Druga", all twenty-one drafts do. Ordered purely
by `share`, the tour would spend its opening minutes on book lines the reader
never built and reach their own work after they had stopped watching. In his
words:

> It is a walkthrough of my repertoire, so the user's actual work must never be
> buried beneath untouched book lines.

### Cut branches are not visited

A move whose `state` is `cut` is skipped, **and so is everything under it**. The
tour is "what I play and what awaits me"; a refused branch is the one thing on
the drawing that is neither. It stays in the picture, drawn dimmed — that is
phase 2's job and not yours.

### The root

`tree.rootPath` is where the repertoire starts (`['e4','e6','d4','d5','e5']`).
Stops are numbered from the root of the *drawing*, so `path` for a first-level
child is a one-element list, **not** `rootPath` plus that move. Phase 4 joins
them when it needs the whole line.

## 4. The rule that bites: do not write a `stopKindOf`

`docs/PLAN-UPOZNAJ-REPERTOAR.md` names a `stopKindOf` function. **It already
exists** under a different name — `lookOfRepertoireMove`, written in phase 2 —
and it answers with the same four values. A second copy is not a tidy
convenience: on this codebase three hand-written copies of one subquery each
forgot the same condition, and a source-reading test exists purely to stop a
fourth. Import the existing one.

If it is missing, or does not compile, **stop and say so in your report.** Do
not write a replacement, and do not substitute a similar-looking function from
somewhere else: a worker that cannot find a named thing and quietly picks the
nearest one is how work nobody asked for gets reported as done.

## 5. What gets the work rejected

* A second `stopKindOf`, by any name. §4.
* A change to `RepertoireTree` or `RepertoireTreeMove`.
* Sorting the tree in place, or any mutation of the input. The same tree is
  drawn afterwards, in the server's order, by a screen you are not touching.
* Any user-facing string. This batch has no UI.
* A test you had to edit to make pass. Report it instead.
* A file reformatted beyond the lines you edited.

## 6. Worked examples — these are your tests

### 6.1 The trunk, and the fork below it

```
root
├── e4 (mine, primary)
│   ├── e5  (theirs, share .55) → Nf3 (mine, primary)
│   └── c5  (theirs, share .31, state 'open')
```

Order: `[e4]`, `[e4, e5]`, `[e4, e5, Nf3]`, `[e4, c5]`.

Depth-first: the main line is walked **to its end** before the tour comes back
for `c5`. A breadth-first order would read the two replies together and never
tell a story.

### 6.2 The rule the owner decided

```
root
├── d4 (mine, primary)
│   ├── Nf6 (theirs, share .60)          <- nothing of mine below it
│   └── d5  (theirs, share .22)
│       └── c4 (mine, primary)           <- my work lives here
```

Order: `[d4]`, `[d4, d5]`, `[d4, d5, c4]`, `[d4, Nf6]`.

`d5` is visited first **although `Nf6` is played nearly three times as often**,
because the reader has built something under `d5` and nothing under `Nf6`. If
your implementation returns `Nf6` first, it is sorting by share alone and has
missed the whole batch.

### 6.3 A cut branch, and the tree you print in your report

```
root
├── e4 (mine, primary)
│   ├── e5 (theirs, share .55)
│   │   └── Nf3 (mine, primary)
│   │       └── Nc6 (theirs, share .40, state 'open')
│   ├── c6 (theirs, share .30, state 'cut')
│   │   └── d4 (mine, primary)           <- under a cut: never visited
│   └── c5 (theirs, share .28)
│       └── Nf3 (mine, alternate)
```

Order: `[e4]`, `[e4, e5]`, `[e4, e5, Nf3]`, `[e4, e5, Nf3, Nc6]`, `[e4, c5]`,
`[e4, c5, Nf3]`.

Six stops. `c6` and the `d4` beneath it appear nowhere, and `c5` is visited
although `c6` is played more often — because `c6` is not visited at all.

**Print this list, as your function actually returns it, in your report.**

### 6.4 Degenerate trees

* An empty tree returns an empty list — not null, and it does not throw.
* A tree whose every child is `cut` returns an empty list.
* A move with `share == 0` sorts last among its siblings, not first.

## 7. How you are judged

By machine, not by prose:

* `flutter test` — 1155 before, 1155 plus your own tests after, none failing;
* `flutter analyze` — the same 29 `info` issues, list compared, not the exit
  code;
* `dart format` — clean on every file you touched;
* the worktree — no file you were not asked to add;
* the strings scanner — **zero** user-facing strings added.

And one thing only you can supply: §6.3's list, printed as your function
returns it. A description of the order is not the order.

## 8. Out of scope, however tempting

* The screen. Phase 4.
* Narration, and any sentence a reader would see or hear. Phase 5, and it has a
  budget you would have no way of knowing about.
* "Show me only the holes." One order exists; a filter over it is a later
  decision, not a second function.
* Anything that reads or writes the server.
