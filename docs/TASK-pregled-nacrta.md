# TASK — the drafts get a queue, and the spine gets a width

This file plus `docs/brief-pregled-nacrta-2026-09.md` are the only context you
get. **Do not rely on any conversation before them.** Read the brief first; it
holds the API contract, the reasoning and the pass conditions.

Branch: `design/pregled-nacrta`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 3 of `docs/PLAN-REPERTOAR-2.md`: requirements 4 and 5, plus the breadth
dialog from requirement 2. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Every endpoint this batch calls is
already built, merged and frozen — commit `3691e8f`. The exact shapes are in §3
of the brief.

If the job turns out to need a change outside `chess_app/lib/` and
`chess_app/test/`, **write in your report which change and why, then stop.** Do
not widen the scope.

## What you need before starting

* Flutter, and `flutter test` green before you change anything. **Measure the
  count yourself and report it; do not trust a number quoted at you.** It should
  be 1068 passing and 1 skipped.
* **No backend, no database, no credentials.** You do not need them and must not
  ask for them. Build against §3 of the brief and fake the client the way
  `chess_app/test/repertoire_gate_test.dart` already does — `class _FakeApi
  extends RepertoireApiService` over a `MockClient`.
* Every new dialog and banner needs a widget test that pumps at
  `Size(360, 640)`. §5 of the brief says why this is not optional.

## Where things are

| | |
|---|---|
| `chess_app/lib/features/repertoire/services/repertoire_api_service.dart` | the client. Four new methods go here |
| `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart` | the workspace banner, the wizard's host, and `_buildSpine` at line 1985 |
| `chess_app/lib/features/repertoire/screens/repertoire_list_screen.dart` | the card badge and its jump; `_open(item, at:)` at line 67 already exists |
| `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart` | the drill's note |
| `chess_app/lib/features/repertoire/widgets/repertoire_position_ask.dart` | how a position is already put as a question — read before writing the wizard |
| `chess_app/test/repertoire_gate_test.dart` | the fake-API pattern to copy |

## The changes, in this order

### 1. The client methods

Four, on `RepertoireApiService`, against the frozen shapes in §3 of the brief:

* `unconfirmedPositions({color, rootFen, rootPath, gateUci, breadth, minRating, limit})`
* `unconfirmedCounts()`
* `playAlternative({color, fen, uci, san, rejectedUci, minRating, includeDecisions})`
* `setBreadth({id, breadth})`

Plus the model classes they return. Follow the shape of the methods already in
that file — the `({T? result, String? error})` record where the caller needs the
message, a plain nullable where it does not.

**Test first, and separately.** These are testable with `MockClient` alone,
with no widget in sight, and a decoding bug found here is an hour not spent
hunting it through three screens.

### 2. The list-card badge and its jump

`unconfirmedCounts()` is one request for the whole list. Draw a badge on each
card whose colour has drafts, reading `positions` — the number of positions, not
the number of moves. Tapping it opens that repertoire at its first unconfirmed
position.

`_open(item, at: fen)` already exists and already does the right thing about the
breadcrumb and the gate. Use it; read its comment before you do.

**The card count is per colour and the banner's is per walk. They will disagree,
and that is correct** — §2.2 of the brief. Do not "fix" it by making them the
same call.

### 3. The workspace banner on the build screen

One line above the work: how many unconfirmed positions this repertoire's own
walk reaches, from `unconfirmedPositions(...)`, with a button that opens the
wizard. Hidden entirely when `total` is 0 — an empty banner saying "0
nepotvrđenih" is noise on the screen you look at most.

### 4. The wizard

Confirm / play alternative / skip, over the walk-ordered list. **Non-blocking**
— §2.3 of the brief; this is the requirement most likely to be built wrong, and
building it as a modal that must be finished fails the batch.

* **Potvrdi** → `confirmNode(color, fen, uci)`
* **Odigraj drugi potez** → the student plays a move on a board, then
  `playAlternative(...)`. It returns `decisions` — how many of the student's own
  decisions sit under the draft being replaced. **If that is non-zero, ask
  before sending with `includeDecisions: true`**, naming the number. §2.4.
* **Preskoči** → `skipNode(color, fen)`, which cuts the branch.

After each, advance to the next position without re-walking the whole list.

### 5. The drill's note

When the drill has nothing to ask in a colour that holds drafts, say so and
offer the review — one sentence, not a dialog. The drill never asks about
drafts, so "nothing to practise" while forty drafts sit unconfirmed is the app
hiding its own state.

### 6. The breadth dialog

`_buildSpine` (line 1985) currently asks only for a depth. It gains a width:
`main`, `standard`, `broad`, with `standard` preselected.

The choice **persists** — `setBreadth({id, breadth})` — which needs the
repertoire id, and `RepertoireBuildScreen` does not have one. Add
`final int? id;`, **optional**, passed from `_open` in the list screen. Optional
because seven existing test call sites construct this screen without it and
none of them should need editing; where it is null, the width control is
disabled with a reason rather than silently failing to save.

§2.5 of the brief has the Serbian wording for the three widths and why a
one-shot dial was rejected.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Work in the order above — each step compiles and tests green before the next.
3. Reuse what exists. `_open(item, at:)`, `RepertoirePositionAsk`, `AppFeedback`,
   `Breakpoints`, `numberedLine` and the theme are all already written; a second
   copy of any of them fails the batch on review even if the gates pass.
4. If a file this task names does not exist, **stop and say so.** Do not
   substitute the nearest plausible file.
5. `dart format` every Dart file you touch.
6. `flutter analyze` must stay at **29** issues — all `info`, all
   `curly_braces_in_flow_control_structures`, in the six files listed in §6 of
   the brief. It does **not** exit clean and never has. Zero errors, zero
   warnings, no new infos: compare the list, not the exit code.
7. `flutter test`. Report the count and the delta from your own starting number.
8. Leave no scratch files in the tree.

## What must hold

* **User-facing strings stay Serbian.** The users are Serbian children and
  trainers. Code comments and your report are English.
* **Never use `ScaffoldMessenger` directly** — `AppFeedback` only.
  `test/app_feedback_guard_test.dart` fails if a raw call comes back, and the
  reason is in §5 of the brief.
* **Do the thing, then say it.** A message must never be able to take down the
  action it reports on. §5.
* **Colour is never the only carrier of a fact.** The badge carries its meaning
  in a number and a shape, not in being orange.
* **Never claim work was destroyed, or silently destroy it.** The alternative
  path deletes. §2.4 is not optional.

## Your report

Write `report-pregled-nacrta.md` in the worktree root. It must state:

1. `flutter test` count before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after — the count, and whether the set
   of files changed;
3. every file you added user-facing strings to;
4. **how you proved the wizard is non-blocking** — a test that opens it and then
   leaves it, with the build screen still usable. Describing the widget tree is
   not proof;
5. **how you proved the decisions warning fires** — a test where
   `playAlternative` reports `decisions > 0` and the confirmation appears before
   anything is sent with `includeDecisions: true`;
6. **what the card badge and the banner said in your test when they disagreed**,
   and that you did not make them agree;
7. anything the brief got wrong.

**Do not claim a number you did not compute in that run.** A correction is worth
more than a clean report.
