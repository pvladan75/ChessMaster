# PLAN — the board that stays and the tree that does not lose you

Five items collected from the owner's checks of 4.9 and 5.9.2026, recorded in
`STANJE-RADA.md` under „Prijave sa provere 4.9–5.9.2026". This is the order they
should be built in, who builds each, and what each is graded by.

Four of the five are decided. The fifth is two questions rather than one job,
and it is last on purpose.

## The dependency that sets the order

Three of these items touch the same two questions — **what the tree contains**
and **where the viewport is pointing** — and they must not be built in parallel
by different hands:

* Phase 1 changes what the tree *contains* (a move outside the breadth becomes
  visible when you are standing on it).
* Phase 2 changes where the viewport *points* and forbids it changing the zoom.

Phase 2 reads the active node that Phase 1 guarantees exists. Built the other
way round, Phase 2's tests pass against a tree that still drops the position and
falls back to the root, and the bug survives underneath a green suite.

Phase 3 is layout only, in different files, and is safe to run beside Phase 2.

## Phase 1 — the focus contract (lead)

**Decided 5.9.2026.** The silent `?? root` goes; a user standing on a move sees
that move in the tree, even when the breadth would otherwise hide it; nobody is
ever sent back to the start while exploring. „Odigra" means both entry points —
a piece dragged on the board and a move accepted from the list underneath.

**Why the lead keeps it:** breadth is a contract read by the tree, the coverage
map, the drill and the delete sweep. „Show this one anyway" is a change beneath
all of them, and the same class of decision as `coveredReplies` already makes on
the server — a reply leading to a position the student decided is followed at
every breadth. This item is that rule extended to *the position the reader is
standing on*, and it belongs next to the existing one rather than beside it.

**The decision inside it, to be taken before code:** whether the exception lives
on the server (the walk also follows the standing position, like it already
follows decided ones) or in the client (the tree is drawn from the server's
answer plus the standing move injected). Server is the more likely right answer
— one rule, one place, and the picture and the walk keep agreeing — but it
costs a parameter on the tree read and is worth measuring against the client
option before choosing.

**Files:** `services/repertoireLine.js` / `repertoireFrontier.js` if server;
`repertoire_build_screen.dart` (`_activeNode`, the `?? root`) and
`repertoire_tree_panel.dart` if client.

**Gates:** backend tests for the walk if it goes server-side; a widget test that
plays a move outside the current breadth and asserts the tree contains it and
the focus is on it, **proved by mutation** — restore the `?? root` and watch it
go red.

## Phase 2 — the viewport never moves itself (worker)

**Decided 5.9.2026, unconditional:** „aplikacija nikad ne menja sama zum". And
the active node is scrolled to only when it approaches an edge, not centred
after every move.

**Why it suits a worker:** it is one widget
(`visual_move_tree_widget.dart`), the rule is stateable as an exit code, and the
gate *is* the diagnosis — a test that records the transform's scale, changes the
active node, and asserts the scale is identical afterwards catches the change
wherever it comes from. That resolves the open question of where the zoom moves
without anybody having to find it first.

**What the brief must pin down:**

* `_centerOnActive` demonstrably preserves the scale today, so the zoom change
  the owner sees is somewhere else — most likely the canvas growing as nodes are
  added, which makes `InteractiveViewer` clamp differently at the same zoom. The
  brief must say this, and must forbid "fixed" as a report word unless the scale
  test is red before the change and green after.
* "Approaches the edge" needs a number. Propose a margin in logical pixels
  measured against the viewport, not a fraction of the canvas.
* The toolbar's own „Centriraj na aktivni potez" button stays — that is the user
  asking, which is exactly what the rule permits.

**Gates:** scale-unchanged test; a test that an active node well inside the
viewport causes no transform change at all; the existing suite's floor; `dart
format`; `flutter analyze` list unchanged.

## Phase 3 — the board stays, the rest scrolls (worker)

**Decided 5.9.2026.** Board and navigation strip fixed at the top, everything
below them scrolls, and the „N nepotvrđenih u grafu" banner is compressed into
one row in line with its button rather than a card that pushes the board down.

**The substance is not the restructure.** `_buildBoardColumn` becoming
`Column[ fixed header, Expanded(SingleChildScrollView(rest)) ]` is a few lines.
The real work is that `boardSize` is derived from width alone: pin the board on
a 360×640 phone and the scrolling part collapses to nothing, or the board is
clipped. **The height has to enter that calculation**, and that is what the
batch is actually for.

**Gates — all of them are sizes, which is why this is gradeable:**

* At 360×640, 360×740 and a tablet size: the board is fully visible, the
  navigation strip is fully visible, and the region below scrolls.
* Scrolling the lower region leaves the board's screen position unchanged
  (compare its rect before and after a fling).
* No overflow at any of those sizes — in a test build an overflowing `Row` or
  `Column` throws, which is the whole reason these are widget tests.
* The banner occupies one row, and its button is still hittable at 360 dp.

**Files:** `repertoire_build_screen.dart` (`_buildBoardColumn`, the board size
computation), `unconfirmed_banner.dart`. **Not** the tree widget — Phase 2 owns
that file in a parallel worktree.

## Phase 4 — a fan of unanswered replies is one stop, not four (worker)

**Decided 5.9.2026**, on the narrow rule and with the lone-gap exception kept:
do not descend into an opponent's move that is a gap **when the position holds
two or more of them**, because the fork sentence one move earlier has
already named them all; keep a lone gap, because the fork sentence only fires
above one reply and that stop is then the only place the hole is said at all.

Today one such position spends five spoken sentences on one fact, against the
tour's own budget of at most four in a twelve-move trunk.

**Why it suits a worker:** `walkthrough_order.dart` is small, pure,
already has tests, and the rule is two conditions.

**Gates:** a position with three gap replies yields no gap stops and the line
ends on the reader's own move; a position with exactly one gap still yields it;
existing walkthrough tests unchanged.

## Phase 5 — the two that are not decided (lead, blocked)

**Reach probability.** The data exists — every opponent reply carries `share`,
and the probability of arriving is their product along the line, the reader's
own moves entering as 1. What is undecided is that it is a *conditional*
probability: it assumes the opponent stays inside what has been prepared, and
breadth changes it. At „samo glavna linija" the product reads far too high. The
number needs its sentence beside it or it misleads, and where it is shown — the
banner, the card, the walkthrough — is a product decision.

**„Prikaži samo ovu liniju" / „samo od ove pozicije".** Before a filter is
written, check whether this is the repertoire gate under a second name
(`rootFen` + `gateUci`, which „Vežbaj X" already uses). Two different „only this
branch" in one app is exactly the shape that drifts apart later. Note also that
the eval filter deleted on 4.9.2026 argues nothing against this one: that hid
branches on the engine's opinion, this follows the reader's own line.

## Running the worker batches

Harness at `D:\Projekti\mislisha-test\orchestrator`. One worktree per batch, off
a master commit that already contains the brief.

```
python orchestrate.py run docs/TASK-<name>.md ^
  --repo D:\Projekti\mislisha-batch-<x> --agent flutter_feature_builder ^
  --model gemini-3.1-pro-high --yolo --timeout 90 --expect-tests <floor>
```

Rules this project has already paid for, and they apply here:

* **Recompute the test floor** against the worktree's own base commit; a floor
  quoted from an earlier batch is how a suite that shrank looks green.
* **Fill `BATCH_ALLOWANCES` before launching.** A gate that fails work its own
  brief demanded costs a whole round.
* **A timeout is not a result.** Treat one, and a return suspiciously close to
  one, as a hard failure.
* **Grade by machine.** The worker's prose is never the verdict, and every new
  guard — the lead's included — is proved by mutation before it is believed.
* Phases 2 and 3 touch different files and may run in parallel worktrees. They
  must both land before anything else touches the build screen or the tree.
