# Brief: the drafts get a queue, and the spine gets a width

Written 3.9.2026. Pairs with [TASK-pregled-nacrta.md](TASK-pregled-nacrta.md),
which holds the scope and the method. This file holds the *why* and the API
contract.

This is Phase 3 of [PLAN-REPERTOAR-2.md](PLAN-REPERTOAR-2.md) — requirements 4
and 5, plus the breadth dialog from requirement 2. Phases 0 and 1 are merged in
commit `3691e8f`; the backend is frozen and this batch must not touch it.

## 1. Why this job exists

A repertoire is built by answering questions one position at a time. That was too
slow — twelve questions before an opening looked like anything — so the **spine**
was added: press "Napravi kičmu" and the server writes the most-played move for
both sides, N moves deep, in one go.

Those written moves are `source = 'auto'` — **drafts**. That is what makes the
spine safe: a draft is drawn on the tree, walked through, and **never asked about
by the drill**. Agreeing to one is meant to be an act.

The act exists. `confirmNode` and `confirmLine` have been in the API since the
spine was. **The queue for it does not.** Confirming has been reachable only one
position at a time, from whichever board happened to be on screen, so the honest
answer to "what have I still not agreed to?" was: open the tree and read it.

The consequence is worse than untidy. The drill refuses to ask about drafts, so a
student who has built a forty-move spine and nothing else opens the drill and is
told there is nothing to practise — while forty positions sit there waiting for a
yes. The app is hiding its own state from the person who created it.

Phase 1 built the reads. This batch is the screen.

The **breadth dialog** rides along because it is the other half of the same
complaint: the spine writes a single trunk, top-1 for both sides, and there was
no way to ask for anything else.

## 2. What to build

### 2.1 The client, first and on its own

Four methods and their models, on `RepertoireApiService`. Test them with
`MockClient` before any widget exists — a decoding bug found at this layer is an
hour not spent hunting it through three screens. §3 has the shapes.

Watch `share`, and anything else that arrives as a string where you expect a
number. This API sends some numerics as JSON strings; a fake you write yourself
will happily hand back an `int` and hide it. Decode defensively and say in your
report which fields you found needed it.

### 2.2 The card badge, and the number that is allowed to disagree

The list screen draws every repertoire at once. `unconfirmedCounts()` is **one
request for the whole list**, per colour, no walk — because walking per card
would make the most-opened screen in the app the slowest one.

The build screen's banner is a **walk**: gate-aware, breadth-aware, from this
repertoire's own root.

**These two numbers will differ, and neither is wrong.** The card says how many
drafts this colour holds; the banner says how many this repertoire's walk
reaches. A draft under a cut branch, or behind a different gate, is in the first
and not the second. Two repertoires of the same colour share the card's number
because moves are stored per colour, not per repertoire.

Do not reconcile them. The screen with room for a sentence is the one that gets
the exact number, and that is the banner. If this looks like a bug to you, it is
the design — say so in your report if you disagree, but build it this way.

### 2.3 The wizard, and why non-blocking is the requirement

Confirm / play alternative / skip, walked in the order the positions come back —
which is walk order, forwards down the line the student will actually play, not
"most reached first".

**Non-blocking means the review can be left at any point and the build screen is
still there underneath, usable, with whatever was confirmed already saved.**

This is the requirement most likely to be built wrong, because the obvious
implementation is a modal `showDialog` loop that owns the screen until the list
is exhausted. That is precisely what must not happen: a student with three
hundred drafts would face a wall they cannot put down, and the feature that was
meant to unblock them becomes the new block. Each answer is committed on its own
as it is given.

Read `repertoire_position_ask.dart` before you write this. The app already has a
way of putting a position as a question, and a second one that looks almost the
same is worse than either.

### 2.4 The alternative, which deletes — and must say so first

"Odigraj drugi potez" is the third answer, and the only one in this batch that
destroys anything.

`POST /repertoire/alternative` writes the student's move in place of the rejected
draft and, in the same transaction, sweeps what that draft was **the only way
to**. Not the subtree — the store is a graph keyed by position, so a position
under the rejected move may also stand on a line that is still played. The server
computes the difference; you do not.

Drafts under it go without asking. **Decisions do not.** The response carries
`decisions` — how many moves the student made *themselves* sit under the draft
being replaced — and by default they are left standing and merely counted.

So: **if `decisions > 0`, ask before sending again with `includeDecisions:
true`, and name the number in the question.** Serbian, and specific — "Ispod tog
nacrta su 3 vaše odluke. Obrisati i njih?" — never a generic "Da li ste
sigurni?".

The reason this is a rule and not a nicety: losing an evening's work to a changed
second move, with no sentence about it, is the kind of thing that happens once
and ends trust in a feature. The server was built to make the warning possible;
throwing the number away in the client wastes the whole design.

A first call with `includeDecisions: false` is safe and is how you get the count.
Making that call, showing the number, and calling again on a yes is the intended
flow — not a workaround.

### 2.5 The breadth dialog

`_buildSpine` in the build screen (line 1985) opens a `SimpleDialog` asking only
how deep. It gains how **wide**:

| value | Serbian label | what it walks |
|---|---|---|
| `main` | „Samo glavna linija" | the single most-played reply |
| `standard` | „Standardno (80%)" | the stored cut — today's behaviour |
| `broad` | „Široko (95%)" | down to 95% of the games played here |

`standard` is preselected and means exactly what every existing repertoire
already does, so nothing built before this moves.

**It persists.** A one-shot dial was rejected on purpose: the tree and the
coverage map would revert to 80% the next session with nothing on screen saying
why they had shrunk. `PUT /repertoire/breadth` stores it on the repertoire row,
and every walk reads it from there.

That needs the repertoire id, and `RepertoireBuildScreen` does not currently have
one. Add `final int? id;` — **optional**, defaulted to null — and pass it from
`_open` in the list screen, where `item.id` is in hand. Optional is not laziness:
seven test files construct this screen without an id, and a required parameter
would edit all seven for no reason. Where it is null, disable the width control
and say why; do not let it look saved when it cannot be.

Nothing is written to `opening_replies` — that column is shared by every user of
this server, and widening it for one person widens it for everyone. Narrowing
hides positions and widening brings them straight back; no move is ever touched.

### 2.6 The drill's note

When the drill has nothing due in a colour whose `unconfirmedCounts()` is
non-zero, one sentence saying so with a way into the review. Not a dialog, not a
redirect — the student may have opened the drill on purpose.

## 3. The API, exactly

All five endpoints are merged and frozen. Base path `/repertoire`, all
authenticated. **Responses are raw JSON with no envelope.** An error is HTTP 400
or 500 with `{"error": "<Serbian sentence>"}` — a 400 sentence is meant to be
shown to the reader.

| Endpoint | Sends | Gets back |
|---|---|---|
| `GET /repertoire/unconfirmed` | query: `color`, `rootFen`, `rootPath` (space-joined SAN), `gateUci`, `breadth`, `minRating`, `limit` | the walk, below |
| `GET /repertoire/unconfirmed/count` | nothing | both colours, below |
| `POST /repertoire/alternative` | `{color, fen, uci, san, rejectedUci, minRating, includeDecisions}` | the result, below |
| `PUT /repertoire/breadth` | `{id, breadth}` | `{"id": 3, "breadth": "broad"}` |
| `POST /repertoire/node/confirm` | `{color, fen, uci}` | already wrapped by `confirmNode(...)` — reuse it |
| `POST /repertoire/node/skip` | `{color, fen}` | already wrapped — reuse it |

`GET /repertoire/unconfirmed`:

```json
{
  "root": { "fen": "<FEN>", "path": ["e4", "c5"] },
  "positions": [
    {
      "fen": "<FEN>",
      "fenKey": "<first four FEN fields>",
      "path": ["e4", "c5", "Nf3", "d6"],
      "ply": 4,
      "moves": [ { "uci": "d2d4", "san": "d4", "role": "primary" } ]
    }
  ],
  "total": 37,
  "truncated": false
}
```

* `positions` is **walk-ordered** and capped by `limit` (default 200, max 500).
* `total` is how many there are, **not** how many were sent. A banner that
  counted the page it was given would say "12" forever on a repertoire with three
  hundred drafts.
* `truncated` means the walk hit its node or depth ceiling — the repertoire is
  bigger than what was walked. Say so; do not present a truncated walk as a
  complete one.
* `path` is from the repertoire's **root**, and `root.path` is how the root was
  reached. The breadcrumb is the two joined.
* A position is in this list only when it holds moves and **none of them is the
  student's**. A draft sitting beside a decision is scaffolding under a decision,
  not a question, and is deliberately absent.
* Cut branches are absent, and so is anything behind them.

`GET /repertoire/unconfirmed/count`:

```json
{ "w": { "positions": 12, "moves": 19 },
  "b": { "positions": 0,  "moves": 0 } }
```

Both colours always, with zeros where there is nothing — a missing key and a zero
read the same on a badge and differently in code. **The badge shows
`positions`.** `moves` is the larger number and would overstate the work.

`POST /repertoire/alternative`:

```json
{
  "played":    { "uci": "e2e4", "san": "e4", "role": "primary", "source": "chosen" },
  "rejected":  "d2d4",
  "orphans":   6,
  "removed":   9,
  "decisions": 3,
  "drafts":    9
}
```

* `orphans` — positions the rejected draft was the only way to.
* `removed` — moves actually deleted in this call.
* `decisions` — the student's own decisions found under it. **Left standing
  unless `includeDecisions: true` was sent, and reported either way.** This is
  the number §2.4 is about.
* The played move always comes back as `primary`.
* 400 with a sentence when the rejected move is not in the repertoire, is not a
  draft (it is a decision — a different act, with a different confirmation in
  front of it), or is the same move as the one played. Show the sentence.

Type traps a self-written fake will not catch: `share` and similar ratio fields
arrive as **strings** on some rows; ids are numbers; `viaUci`, `viaSan`,
`gateUci` and `breadth` are all nullable. Decode defensively.

If you believe you need an endpoint that is not on this list, **stop and say so
in the report** rather than inventing one. Backend work is out of bounds for this
batch, so a missing shape is a finding, not a task.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `RepertoireApiService` | the client. `confirmNode`, `confirmLine`, `orphansOfRemoving`, `prune`, `buildSpine` are already there; follow their shape |
| `_open(item, {at})` (`repertoire_list_screen.dart:67`) | the jump. Already handles the breadcrumb and gate correctly when landing somewhere that is not the root — read its comment |
| `RepertoirePositionAsk` | how a position is already put as a question |
| `numberedLine` (`features/repertoire/line_text.dart`) | numbers a line the way a book does. Shared by both repertoire screens |
| `AppFeedback` | the only way to show a message. See §5 |
| `Breakpoints.isWide(context)` (840 dp) | the app-wide "is there room for two columns". Do not add another threshold |
| `AppText`, `AppSpacing`, `AppRadii`, `context.colors` | the theme. Hardcoded colours and spacings fail review |
| `test/repertoire_gate_test.dart` | `class _FakeApi extends RepertoireApiService` over `MockClient`. Copy it |

Friction worth knowing: `RepertoireApiService` is subclassed by a fake in each of
the eight repertoire test files. Adding methods to the real service does not break
them — Dart only requires overrides for what a test actually calls — but if you
change an **existing** signature you will break several at once. That is the
design working; if it happens, you have probably changed something you did not
need to.

## 5. Rules that bite

**Do the thing, then say it.** A message must never be able to take down the
action it reports on. This has happened twice here: playback that never started
because a failing audio call sat in front of the timer, and a recording that
would not stop for a child whose parent had refused it, because `showSnackBar`
threw first. Commit the confirmation, *then* announce it. In this batch that
means: send `confirmNode`, then update the banner — never a message in front of
the write.

**Never call `ScaffoldMessenger` directly.** All 82 raw calls in `lib/` were
moved onto `AppFeedback` on 25.8.2026, and `test/app_feedback_guard_test.dart`
fails if one comes back. `AppFeedback` cannot throw; that is its entire job.

**A release build paints no overflow warning.** In debug a too-wide `Row` gets
the yellow-and-black stripes and an assertion. In release it is simply clipped —
the row looks shorter than it is and anything past the edge is unreachable. The
notifications dialog shipped with a fixed content width of 360 on a 360 dp phone
and nobody saw it until they looked at a phone. Your breadth dialog has three
options with Serbian labels, and the card's `trailing:` is **already** a `Row`
with two buttons before your badge joins it. **Use `Wrap` where a row can grow,
take widths from `MediaQuery` rather than hardcoding them**, and pump every new
dialog and banner at `Size(360, 640)` — in a test build the overflow *does*
throw, which is what makes that size a gate.

**Colour is never the only carrier of a fact.** The project owner is colourblind.
His sign-off on a screen proves luminance and shape, never hue. The badge must
read as "12" plus a shape, not as "the orange one". Do not argue that a hue shift
reads anyway; it does not, for the person who has to use this.

**`flutter analyze` does not exit clean and has not for a long time.** 29 issues,
every one `info`, every one `curly_braces_in_flow_control_structures`. A red exit
code is the normal state, so the exit code tells you nothing — compare the list.

**User-facing strings stay Serbian.** Comments and your report are English.

## 6. How this will be judged

Gates, each an exit code rather than a sentence:

* `git diff --name-only` must not match `chess_backend/` — a hard boundary;
* `flutter analyze` still exactly the 29 known infos, **list compared, not
  counted**, in `positional_evaluator_service.dart` (8),
  `tactical_motif_detector.dart` (3), `game_analysis_walker_service.dart` (3),
  `review_api_service.dart` (1), `ai_studio_screen.dart` (12) and
  `matrix_filter_panel.dart` (2);
* `flutter test` at or above **1068 passing, 1 skipped** — measured by you before
  you start and again at the end. A suite that quietly stops running half of
  itself still exits 0, so the count is the signal;
* `dart format --set-exit-if-changed`;
* `test/app_feedback_guard_test.dart` green;
* a widget test at `Size(360, 640)` for the wizard, the banner and the breadth
  dialog.

Then the four questions the work has to answer, phrased so you can check them
yourself:

1. **Can the review be abandoned halfway?** A test that confirms two of five
   positions, leaves, and finds the build screen usable with both confirmations
   saved. A description of the widget tree is not proof.
2. **Does the decisions warning fire before anything is lost?** A test where the
   first call reports `decisions: 3` and nothing is sent with
   `includeDecisions: true` until the reader says yes.
3. **Does the banner disappear at zero?** Not "0 nepotvrđenih" — gone.
4. **Does a truncated walk say so?** Feed `truncated: true` and read the sentence.

## 7. Not in scope

* **Anything under `chess_backend/`.** Every shape you need is in §3. A missing
  one is a finding for your report, not a task.
* **Requirements 8 and 9** — "Izdvoji u novo otvaranje" and the combined drill.
  They are Phase 4, they have their own brief, and building them here collides
  with another worker.
* **Requirements 1 and 7** — the last-move highlight and the ECO banner. Phase 2,
  running in parallel against the same screens. Do not add a board highlight or
  an opening name; you will collide at the merge.
* **The tree panel and the coverage map.** They already read breadth from the
  walk. Changing how they draw is a different job.
* **The 29 known analyze infos.** Clearing them is a fine standalone chore and
  would fail this batch's gate, which compares the list.
* Any bug you find that this brief did not name. Report it, do not fix it, and
  **do not claim to have fixed it.**
