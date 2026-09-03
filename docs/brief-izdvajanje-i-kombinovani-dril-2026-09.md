# Brief: a branch becomes its own opening, and two openings drill as one

Written 3.9.2026. Pairs with
[TASK-izdvajanje-i-kombinovani-dril.md](TASK-izdvajanje-i-kombinovani-dril.md),
which holds the scope and the method. This file holds the *why* and the API
contract.

This is Phase 4 of [PLAN-REPERTOAR-2.md](PLAN-REPERTOAR-2.md) — requirements 8
and 9, the last two of nine. Phases 0 to 3 are merged; the backend is frozen and
this batch must not touch it.

## 1. Why this job exists

Two complaints, both about the repertoire being one shape when the person using
it wants another.

**A repertoire outgrows its root.** You start "Sicilijanka, crni" from move one,
build for a week, and the Smith-Morra part is now forty positions deep with its
own character. It is an opening. But it lives as a branch inside something
larger, so the tree draws it four plies down and every drill session that wants
it has to walk past everything else. There is no way to say "this part is its
own thing now".

**A session is one opening at a time.** Everything under the drill takes a
single `(rootFen, gateUci)`. Somebody with three openings for White sits down
for twenty minutes and has to run three sessions, each with its own root, each
re-asking which branch to practise. The schedule already knows all their
positions; only the screen insists on one door at a time.

Neither needs backend work. `POST /repertoire` has taken `viaUci` since the gate
existed, and phase 1 added `ids` to `/drill/branches` and `/drill/line` along
with a per-branch tag saying which repertoire each came from. **The client is
what has not caught up** — `DrillBranch` currently throws six fields away, and
neither drill method can send `ids` at all.

## 2. What to build

### 2.1 A fork copies nothing — read this before writing step 2

The obvious implementation of "izdvoji u novo otvaranje" is to copy the moves
under the position into a new repertoire. **That is wrong here, and it is wrong
in a way no test you write will show you.**

Moves are not stored per repertoire. `repertoire_moves` is keyed by
`(user_id, color, fen_key)` — the graph belongs to the *colour*, not to the
opening — and a `repertoires` row is a **door into that graph**: a root
position, optionally a gate, and a name. That is the whole of it. Two
repertoires sharing a position share the move, because it is one move.

So a fork creates a row and nothing else. The forty positions under the
Smith-Morra are *already* reachable from the new root the instant it exists; no
move is written, copied, moved or deleted. Copying them would write a second set
of rows for positions that already have them, and `addMove` would either collide
or quietly turn drafts into decisions.

This is also why the fork is cheap and safe: it adds a door and takes nothing
away. The original repertoire still reaches everything it did — which is correct
and must not be presented as a problem to solve.

If you find yourself calling `keepMove`, `confirmNode` or anything else that
writes a move while implementing the fork, stop: you have misread this section.

### 2.2 The prefilled name, and its fallback

`OpeningBookService.instance.lookupByFen(fen)` returns an `OpeningBookEntry`
with `.eco` and `.name`, or **null** — for two different reasons it cannot tell
apart: the dataset has no name for that position, or the service has not loaded
yet. Both are common and neither is an error.

So: prefill the name field with `'<eco> · <name>'` when the lookup answers, and
leave it **empty with the field focused** when it does not. Do not invent a name
from the SAN path, and do not block on loading. The reader can always type one;
an empty field is honest and a wrong guess is not.

The name is editable in every case. A prefill is a convenience, not a decision.

Note the same trap phase 2 hit: `OpeningBookService` loads through `compute()`,
which **never completes inside `testWidgets`**. Take the lookup as an injectable
parameter on your dialog, defaulting to the real service, exactly as
`OpeningBanner` does — otherwise the prefill is untestable and will rot.

### 2.3 The gate, which already exists

`showGatePicker(context, rootFen:, kept:, current:)` returns a `String?` UCI. It
lists the legal moves at a position, marks the ones already kept, and is what
the list screen's "kroz koji potez" flow already uses.

A fork needs it because the position you fork from usually already holds a move:
without a gate, the new repertoire and the old one are two doors onto the same
position with nothing distinguishing them, which is the exact confusion the gate
was built for (after 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5, one repertoire plays 4.b4 and
the other 4.0-0). Offer it, let it be skipped, and pass `viaUci: null` when it
is.

### 2.4 One schedule, shared — and the sentence that says so

`repertoire_reviews` is keyed `(colour, position)` and stays that way. A position
two openings both reach is **one item with one due date, answered once**.

This is a deliberate decision, not a limitation to work around: per-repertoire
schedules would put the same board up twice in one sitting and call the second
time practice. But it is surprising if nobody says it, because the reader has
just ticked two openings and may reasonably expect two queues.

So where the multi-select is made, one sentence, readable without scrolling —
something close to:

> „Pozicija koju oba otvaranja dostižu pita se jednom."

Wording is yours; the fact is not optional.

### 2.5 Two rows, not one

Two openings can start with the same two moves. The branch list must show them
as two rows — a Sicilian repertoire and an Open Sicilian repertoire that both
open `e4 c5` are two different bodies of work.

Phase 1 gives every branch a unique `id` for exactly this, precisely because
`key` collapses them: `key` is the two opening moves in UCI (`"e2e4-c7c5"`), so
two repertoires that both begin `1.e4 c5` produce the *same* key, while `id`
prefixes it with the repertoire — `"3:e2e4-c7c5"` and `"7:e2e4-c7c5"`.

**Key your list rows by `id`.** Using `key` produces a list that silently drops
one of the two, and the count at the bottom will look right while a whole
opening is missing.

## 3. The API, exactly

**No route changes.** All of this is merged and frozen. Base path `/repertoire`,
all authenticated, responses are raw JSON with no envelope; an error is HTTP 400
or 500 with `{"error": "<Serbian sentence>"}` and a 400 sentence is meant to be
shown.

**Every URL is built as `'$backendUrl/repertoire/...'`.** There are ~41 calls in
that file doing this. §5 says why this sentence is here.

| Endpoint | Sends | Gets back |
|---|---|---|
| `POST /repertoire` | `{name, color, rootFen, rootPath, viaUci}` | the created `RepertoireSummary` |
| `GET /repertoire/drill/branches` | `ids` **or** `rootFen`+`gateUci`, plus `color`, `minRating` | `{branches: [...]}` |
| `GET /repertoire/drill/line` | the same, plus the existing line parameters | the drill line |

`create()` already exists at line 1478 and already sends `viaUci`. **Do not
change its signature.**

`ids` is a comma-joined list of repertoire ids: `?ids=3,7`. When you send it:

* **omit `rootFen`, `rootPath` and `gateUci`** — the server reads each door's
  root, gate and breadth from its own row, which is why they are not three
  parallel query parameters;
* `color` may still be sent and **must agree** with the rows. The server refuses
  a contradiction rather than silently preferring one; show its sentence.

A branch now comes back as:

```json
{
  "id": "3:e2e4-c7c5",
  "key": "e2e4-c7c5",
  "repertoire": { "id": 3, "name": "Sicilijanka, crni" },
  "root": { "fen": "<FEN>", "path": ["e4", "c5"] },
  "gateUci": "g1f3",
  "breadth": "standard",
  "fen": "<FEN>",
  "path": ["e4", "c5"],
  "san": "e4 c5",
  "share": 0.42,
  "positions": 18,
  "due": 4,
  "known": 9,
  "dueKeys": ["<fen key>", "..."]
}
```

Type traps, and a fake you write yourself will not catch any of them:

* **`repertoire` is null** when the caller asked by root rather than by `ids` —
  which is every existing call. Render the row without a tag, not with "null".
* `gateUci` is nullable. `breadth` is one of `main` / `standard` / `broad`.
* `id` is a **string** — the repertoire's id and the branch key joined with a
  colon, `"3:e2e4-c7c5"`. `repertoire.id` is an **int**. They are neither the
  same field nor the same type, and `id` is the one the rows are keyed by.
* `key` is the branch's two opening moves in **UCI**, `"e2e4-c7c5"` — not a FEN
  and not SAN. `san` is the readable pair, `"e4 c5"`.
* `share` is coerced to a number by the server for branches specifically, so it
  arrives as a number here. Elsewhere in this API ratio fields do arrive as
  strings; do not carry an assumption from this endpoint to another.
* `root.path` is a list of SAN strings and may be empty for a repertoire built
  from a pasted position.

If you believe you need an endpoint that is not on this list, **stop and say so
in the report** rather than inventing one.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `showGatePicker` (`widgets/repertoire_gate_picker.dart:70`) | the gate sheet, with `gateOptionsFor` behind it |
| `create()` (`repertoire_api_service.dart:1478`) | already sends `viaUci`; do not change it |
| `_pickBranch` (`repertoire_drill_screen.dart:300`) | the sheet that gains checkboxes |
| `_drill` (`repertoire_list_screen.dart:480`) | how the drill screen is pushed today |
| `OpeningBanner` (`widgets/opening_banner.dart`) | the injectable-lookup pattern to copy for the prefill |
| `AppFeedback` | the only way to show a message |
| `Breakpoints.isWide(context)` (840 dp) | do not add another threshold |
| `AppText`, `AppSpacing`, `AppRadii`, `context.colors` | the theme. Hardcoded values fail the scale gate |
| `test/repertoire_gate_test.dart` | `_FakeApi extends RepertoireApiService` over `MockClient` |

Friction worth knowing: `RepertoireDrillScreen` and `RepertoireBuildScreen` are
each constructed by several test files. Adding an **optional** parameter breaks
none of them; changing an existing one breaks many at once. Keep `ids` optional
and nullable.

## 5. Rules that bite

**Every request URL goes through `$backendUrl`.** Last round shipped four
endpoints written as `Uri.parse('/repertoire/unconfirmed')`. All four would have
failed on the first tap on a real device, and **every test stayed green**,
because these tests drive the service through `MockClient`, which answers
whatever it is handed and never looks at the URL. `test/repertoire_api_urls_test.dart`
now reads every route out of the source and will fail you for this; it exists
because no widget test can see it.

**Two APIs are deprecated and will fail the analyze gate.** They cost a round
last time, twelve new infos between them:

* `Color.withOpacity(x)` → `Color.withValues(alpha: x)`.
* `RadioListTile`'s per-tile `groupValue` / `onChanged` → a `RadioGroup`
  ancestor. `RadioGroup` takes a **non-nullable** callback, so a disabled state
  is an `AbsorbPointer`, not a null `onChanged`.

`flutter analyze` compares a **list**, not an exit code — it has reported 29
infos for a long time and a red exit is its normal state. A thirtieth fails you.

**A release build paints no overflow warning.** In debug a too-wide `Row` gets
the yellow-and-black stripes and an assertion; in release it is simply clipped,
so the row looks shorter than it is and anything past the edge is unreachable.
Three of these shipped before anyone looked at a phone. This batch adds a
checkbox and a repertoire name to a branch row that already carries a SAN label
and three counts, and a selection bar to a list screen whose cards already end
in two buttons and a badge. **Use `Wrap` where a row can grow, take widths from
`MediaQuery`, and pump every new sheet and bar at `Size(360, 640)`** — in a test
build the overflow *does* throw, which is what makes that size a gate.

**Colour is never the only carrier of a fact.** The project owner is colourblind;
his sign-off proves luminance and shape, never hue. A selected card is selected
by a **checkbox**, not by being tinted. If you add a tint as well, fine — but the
checkbox is what carries it.

**Never call `ScaffoldMessenger` directly.** All 82 raw calls in `lib/` were
moved onto `AppFeedback` on 25.8.2026 and a guard test fails if one comes back.
A message must never be able to take down the action it reports on: twice in this
project a `showSnackBar` threw before the work it was announcing. **Do the thing,
then say it.**

**`dart format`, last.** Both previous batches failed this gate, both because it
was run early or not at all. It is the final step, after the tests are green.

**User-facing strings stay Serbian.** Comments and your report are English.

## 6. How this will be judged

Gates, each an exit code rather than a sentence:

* `git diff --name-only` must not match `chess_backend/`;
* `flutter analyze` still exactly the 29 known infos, **list compared, not
  counted**, in `positional_evaluator_service.dart` (8),
  `tactical_motif_detector.dart` (3), `game_analysis_walker_service.dart` (3),
  `review_api_service.dart` (1), `ai_studio_screen.dart` (12) and
  `matrix_filter_panel.dart` (2);
* `flutter test` at or above **1079 passing, 1 skipped** — measured by you before
  you start and again at the end;
* `dart format --set-exit-if-changed`;
* `test/app_feedback_guard_test.dart` green;
* `test/repertoire_api_urls_test.dart` green — every route absolute;
* a widget test at `Size(360, 640)` for the fork dialog, the selection bar and
  the branch sheet.

Then the four questions the work has to answer, phrased so you can check them
yourself:

1. **Does a fork write any move?** A test where the fake API records every call
   and only `create` was made. §2.1 — this is the one that is wrong invisibly.
2. **Does a combined request actually send `ids`?** Assert on the URL your fake
   received, and that `rootFen` is absent from it.
3. **Are two openings that open alike two rows?** Feed two branches with the same
   `key` and different `id`, and count the rows.
4. **Does the prefill survive a lookup that answers null?** An empty, editable,
   focused field — not the word "null", and not a hang.

## 7. Not in scope

* **Anything under `chess_backend/`.** Every shape you need is in §3.
* **Copying, moving or deleting moves.** §2.1. A fork is a row.
* **Deleting the original repertoire after a fork**, or offering to. It still
  reaches everything it did, which is correct.
* **Per-repertoire schedules.** §2.4 — one shared schedule is the decision.
* **`create()`'s signature**, and the `breadth` parameter the endpoint also
  accepts. A forked repertoire takes the default; changing it afterwards is the
  width dialog's job and already built.
* **The 29 known analyze infos.** Clearing them is a fine standalone chore and
  would fail this batch's gate, which compares the list.
* Any bug you find that this brief did not name. Report it, do not fix it, and
  **do not claim to have fixed it.**
