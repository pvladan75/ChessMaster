# Repertoire workstation — second iteration

Nine requirements, agreed 2.9.2026. This file is the contract for the work:
what each one turned out to mean once the code was read, what order it is built
in, and which half is the lead's and which the worker's.

Written in English per `CLAUDE.md`. The user-facing strings named in it stay
Serbian, as everywhere else.

## What the code already does

Read before planning, because three of the nine mean something different once
you have looked.

| # | Requirement | State |
|---|---|---|
| 1 | Last-move highlight | The painter already draws it — a wash **plus black-and-white corner brackets**, so the fact is carried by shape and not only by hue (`board_overlay_painter.dart`). `ChessBoardWithOverlay` does not expose `lastMoveFrom/To`; the Analysis Studio paints its own layer instead. Wiring, not drawing. |
| 2 | Spine breadth | The spine is a **single trunk, top-1 for both sides** (`repertoireSpine.js`). The ≤80% belongs to the *walk*, and comes from `opening_replies.covered`, a column **shared by every user**. Rows past the cut are stored with their `share`, so top-1 and ≤95% are computable at read time without touching the shared flag. |
| 3 | Cut replies leak into the drill | Confirmed. `pickReply` filters on `covered` / extra replies and never reads `repertoire_skips`, so a branch the student cut can still be played *by the drill's opponent*. The line walk is already clean. |
| 4/5 | Global unconfirmed review | `source='auto'`, `confirmNode`, `confirmLine` and the prune engine (`orphansOfRemoving` + `pruneKeys`) all exist. Missing: a walk-ordered "what is still unconfirmed" read, a count, and one transaction for "play an alternative and prune what the rejected draft left". |
| 6 | Honest drill invariant | Half held already: the *question* is gated on `role='primary' AND source='chosen'`. The hole is the **opponent's** move — same function as #3, so one change closes both. |
| 7 | ECO banner | `OpeningBookService.lookupByFen` gives `eco` + `name`. Two traps: deep positions are not in the dataset (carry the last named one forward), and the dataset loads through `compute()`, which **never completes inside `testWidgets`** — the widget must take an injectable lookup. |
| 8 | Fork to a new repertoire | No backend work: `create()` already takes `viaUci`. |
| 9 | Combined drill | Everything below the drill takes a single `(rootFen, gateUci)`. Needs a list of pairs and a merged walk. `nextItem`'s `only` is already a key list, so the scoping itself is free. |

## Decisions taken

**Breadth is a property of the walk, stored on the repertoire.** New column
`repertoires.breadth` (`main` / `standard` / `broad`), chosen in the spine
dialog and changeable afterwards. `standard` keeps `covered = TRUE` exactly as
it is today, so nothing existing moves. The other two are computed from `share`
at read time — never by writing to `opening_replies.covered`, which is shared by
everybody. A one-shot dial was rejected because the tree and the coverage map
would revert to 80% next session with nothing on screen saying so.

**The card's draft count is per colour.** One query for the whole list, and
consistent with the "N poteza u grafu" already on the card, which is also per
colour. The exact, gate-aware number is in the workspace banner, which walks.
Per-card walking was rejected: it makes the most-opened screen the slowest.

**A combined session shares one schedule per position.** `repertoire_reviews`
stays keyed `(colour, position)`, so a position two repertoires both reach is
one item with one due date, answered once. Per-repertoire schedules would ask
the same question twice on the same board.

## Phases

**Phase 0 — lead. The drill tells the truth.** (#3, #6)
`pickReply` reads `repertoire_skips`, and only offers replies whose landing
position holds a `source='chosen'` move; a spar with no qualifying reply ends
cleanly instead of walking off the prepared edge. Both guards proved by
mutation. First, because it changes what the drill is *allowed to say*, and no
UI should be built on top of a drill that lies.

**Phase 1 — lead. The contract.**
Merged and frozen before any batch starts:

* `repertoires.breadth` + breadth threaded through `coveredReplies` and the
  walks that read it;
* `GET /repertoire/unconfirmed` — walk-ordered, gate-aware, each entry with its
  path, and `GET /repertoire/unconfirmed/count` per colour for the card;
* `POST /repertoire/alternative` — write the chosen move and prune the drafts
  the rejected proposal left, in one transaction;
* multi-root parameters on `/drill/line` and `/drill/branches`, branches tagged
  with the repertoire they came from.

**Phase 2 — worker batch A, "tabla i traka".** (#1, #7)
Two optional params on `ChessBoardWithOverlay` forwarded to both painters; the
build and drill screens track from/to; the ECO banner above the board with the
last-named-position rule and an injectable lookup. No new endpoints, one column
of the screen.

**Phase 3 — worker batch B, "pregled nacrta".** (#4, #5, #2's dialog)
The non-blocking wizard (confirm / play alternative / skip), the workspace
banner, the list-card badge with its jump, the drill's note, and the breadth
dialog on "Napravi kičmu". Against Phase 1's frozen shapes.

**Phase 4 — worker batch C, "izdvajanje i kombinovani dril".** (#8, #9)
"Izdvoji u novo otvaranje" — ECO-prefilled name and the gate set, reusing
`showGatePicker`; multi-select checkboxes in the branch sheet, with the sentence
about one shared schedule where it can be read.

**Phase 5 — lead.** Merge, live-check items in `TODO-provera.md`, entry in
`STANJE-RADA.md`.

## The split

| Lead | Worker |
|---|---|
| `db.js` and every migration | Nothing under `chess_backend/` — a hard boundary in the task file |
| `pickReply`, `nextItem`, drill invariants | Widgets, dialogs, sheets, banners |
| Prune, reachability, gate semantics | Board wiring, ECO banner, card badges |
| Endpoints, and their exact shapes in the brief | Screen state and navigation to the next pending node |
| Gates, grading, merge | The report — which is never the verdict |

## Gates, per batch

Every one an exit code, never prose:

* `git diff --name-only` must not match `chess_backend/` — the boundary above,
  enforced rather than asked for;
* `flutter analyze` still exactly the 29 known infos, list compared not counted;
* `flutter test` count before and after, measured by the worker itself;
* `dart format --set-exit-if-changed`;
* `test/app_feedback_guard_test.dart` — no raw `ScaffoldMessenger` comes back;
* a widget test at `Size(360, 640)` for every new dialog or banner, because a
  release build paints no overflow stripes.

## Operational notes

The lead cannot launch the worker: the classifier blocks
`--dangerously-skip-permissions`. The user runs `orchestrate.py` from the
harness (read its `HANDOFF.md` first) against the design worktree, and the brief
must be **committed in that tree's base commit** before the run — a worker that
cannot find a named file substitutes the nearest plausible one and reports
success.

Each batch gets two files, per the method: `docs/TASK-<name>.md` (scope, order,
what the report must contain) and `docs/brief-<name>-<date>.md` (why, the API
shapes exactly, what to reuse, the rules that bite, how it will be judged).
Neither can be written before Phase 1 is merged, or the worker builds against a
shape that then drifts.
