# Brief — a fan of unanswered replies is one stop, not four

Phase 4 of `docs/PLAN-TABLA-I-STABLO.md`. Flutter only, in `chess_app/`.
**`chess_backend/` is not touched by this batch at all** — nothing here has a
server side, no endpoint changes, no request is added.

## 1. Why this exists

„Upoznaj repertoar" is a guided reading of a repertoire. It walks the drawing
depth-first and speaks a sentence only where one is earned, because a tour that
narrates every move is a tour nobody finishes. The design budget is written into
`walkthrough_speech.dart` in those words: **at most four spoken sentences in a
twelve-move trunk.**

One shape breaks that budget badly, and the owner reported it on 4.9.2026 and
clarified it at 22:20:

> „Nema potrebe doći u situaciju da na kraju linije imamo poziciju posle
> korisnikovog poteza, a onda 4 poteza protivnika koji započinju nove linije, a
> nemaju odgovor korisnika, i da se sad sve 4 pokazuju. Tu korisnik nema šta da
> zapamti."

At a position the reader's own move leads into, where the opponent has four
replies and **none of them has been answered**, the tour today stops at all four
and speaks at each:

```
„Odavde protivnik ima 4 odgovora: Nf6, e5, c5, d5."   <- the fork, on the move before
„Na Nf6, 23% partija, nemate odgovor."
„Na e5, 21% partija, nemate odgovor."
„Na c5, 19% partija, nemate odgovor."
„Na d5, 12% partija, nemate odgovor."
```

Five spoken sentences at one position, about one fact — and the fork sentence
already named all four. The whole trunk's budget, spent standing still.

## 2. The decision, in the owner's words and taken on 5.9.2026

Do **not** descend into an opponent's move that is a gap **when the position
holds two or more of them**. The fork sentence one move earlier has already
named them.

**Keep a lone gap.** This half is not optional and it is the easy thing to get
wrong: the fork sentence fires only when the position has more than one
opponent reply (`theirs.length > 1` in `walkthroughLine`). With exactly one
unanswered reply there is no fork sentence, so that stop is the **only** place
the hole is said at all. Drop it and the tour goes silent about a hole.

The line then ends on the reader's own move, which is what was asked, and
nothing goes unsaid.

## 3. What a „gap" is, exactly — do not re-decide it

`lookOfRepertoireMove` in
`lib/features/repertoire/widgets/repertoire_tree_panel.dart`:

```dart
MoveTreeNodeLook lookOfRepertoireMove(RepertoireTreeMove move) {
  if (move.state == 'cut') return MoveTreeNodeLook.refused;
  if (move.mine) return MoveTreeNodeLook.authored;
  if (move.state == 'open') return MoveTreeNodeLook.gap;
  return MoveTreeNodeLook.covered;
}
```

**Call that function. Do not write the condition again.** Three hand-written
copies of one condition in this codebase each forgot the same clause, and a test
exists that fails when a fourth appears. A gap is an opponent's move
(`!move.mine`) into a position that is `open`, and it is never a cut one.

## 4. Where the change goes

`lib/features/repertoire/services/walkthrough_order.dart`, in `walkthroughOrder`
— and **only** there. It is a pure function over a `RepertoireTree`, with no
widget, no board and no screen, which is why this batch is small.

Today:

```dart
void visit(RepertoireTreeMove move, List<String> above) {
  final path = [...above, move.san];
  stops.add(WalkthroughStop(move: move, path: path));
  for (final child in _ordered(move.children)) {
    visit(child, path);
  }
}
```

It adds a stop for **every** move it visits, including every leaf. The change is
in what it descends into and what it adds, not in the ordering.

**Do not touch `_ordered`.** The sibling order is settled, tested and the
owner's own rule from phase 3. Changing it is out of scope and fails the batch.

**Do not touch `walkthroughBeats` or `walkthrough_speech.dart`.** The sentence
each stop earns is not this batch's business; this batch only decides which
stops exist. If you believe a sentence is wrong, say so in the report and stop.

## 5. The rule, stated so it can be implemented directly

For any position (any `move` whose `children` are being visited, and the tree
root):

1. Take that position's children that are **not** `cut` — the same live set
   `_ordered` already computes.
2. Count how many of them are gaps, by `lookOfRepertoireMove`.
3. **If two or more are gaps, none of those gap moves becomes a stop, and
   nothing under them is visited.** Non-gap children are visited exactly as
   before.
4. **If exactly one is a gap, it becomes a stop as it does today**, and the walk
   continues into it as before.
5. A move that is not a gap is never affected by this rule.

A gap has no children in practice — the position after it is `open`, so nothing
was built there — but do not rely on that. Skip the move and its subtree
together.

## 6. What must not change

* The **order** of the stops that remain, exactly as `_ordered` produces it.
* `WalkthroughStop`, its fields, `depth`, and `kind`.
* The cut rule: a cut branch is not walked, and is not counted as a gap.
* The tree object itself. `walkthroughOrder` must not mutate what it is handed —
  the same tree is drawn afterwards, in the server's own order, by a screen that
  knows nothing about this function.

## 7. How it will be judged

`test/repertoire_walkthrough_order_test.dart` already exists and its cases must
all still pass unchanged. **A test you had to change is a finding: report it and
stop**, do not edit it to agree with your code.

Add tests for:

1. **A fan is collapsed.** A position after the reader's move with three
   opponent replies, all `state: 'open'`: no stop for any of them, and the last
   stop on that line is the reader's own move.
2. **A lone gap survives.** The same position with exactly one opponent reply,
   `state: 'open'`: that stop is still produced.
3. **A mixed position.** Two opponent replies where one is `open` and one is
   `covered` with a move of the reader's under it: only *one* of them is a gap,
   so rule 4 applies — the gap is kept, and the covered branch is walked as
   before. **Read this case twice.** „Two or more gaps", not „two or more
   replies".
4. **Nothing else moved.** The stop list for a tree with no gaps is identical
   before and after your change.

**Prove tests 1 and 2 by mutation.** Break the rule (drop the `>= 2` condition
so every gap is skipped; then drop the rule entirely) and watch each test fail.
Report which test failed and the message it failed with. A guard nobody has
watched fail is not a guard, and this project has shipped two that did not
guard.

## 8. The rules of this codebase that bite here

* `flutter test` on the branch **before you change anything**. Measure it
  yourself and report it; do not trust a number quoted at you. It should be
  **1212 passing, 1 skipped**. Lower means something is wrong before you start —
  stop and report.
* `flutter analyze` must stay at **29** issues, every one `info`, every one
  `curly_braces_in_flow_control_structures`. **Compare the list, not the exit
  code** — it has exited 1 for a long time and that is the normal state.
* **`dart format` every Dart file you touch, last.**
* Golden tests are skipped unconditionally; `--tags golden` alone still skips
  them and the run exits 0 saying „All tests skipped". Do not grade yourself on
  them.
* If a file this brief names is **not there**, stop and say so. Do not
  substitute the nearest plausible one.
