# TASK — a branch becomes its own opening, and two openings drill as one

This file plus `docs/brief-izdvajanje-i-kombinovani-dril-2026-09.md` are the
only context you get. **Do not rely on any conversation before them.** Read the
brief first; it holds the API contract, the reasoning and the pass conditions.

Branch: `design/izdvajanje-i-kombinovani-dril`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 4 of `docs/PLAN-REPERTOAR-2.md`, requirements 8 and 9, and nothing else.
Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** No new endpoint and no schema change:
everything below is already built, merged and frozen. `POST /repertoire` has
taken `viaUci` since the gate existed, and `/drill/branches` and `/drill/line`
have taken `ids` since phase 1. The client is what has not caught up.

If the job turns out to need a change outside `chess_app/lib/` and
`chess_app/test/`, **write in your report which change and why, then stop.**

## What you need before starting

* Flutter, and `flutter test` green before you change anything. **Measure the
  count yourself and report it; do not trust a number quoted at you.** It should
  be 1079 passing and 1 skipped.
* **No backend, no database, no credentials.** You do not need them and must not
  ask for them. Build against §3 of the brief and fake the client the way
  `chess_app/test/repertoire_gate_test.dart` already does — `class _FakeApi
  extends RepertoireApiService` over a `MockClient`.
* Every new dialog, sheet and selection bar needs a widget test that pumps at
  `Size(360, 640)`. §5 of the brief says why this is not optional.

## Where things are

| | |
|---|---|
| `chess_app/lib/features/repertoire/services/repertoire_api_service.dart` | `create()` at 1478, `drillLine()` at 2011, `drillBranches()` at 2237, `DrillBranch` at 892 |
| `chess_app/lib/features/repertoire/widgets/repertoire_gate_picker.dart` | `showGatePicker` at 70 — reuse it, do not write a second one |
| `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart` | the position action row at 909–929 is where "Izdvoji" belongs |
| `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart` | `_pickBranch` at 300 — the sheet that gains checkboxes |
| `chess_app/lib/features/repertoire/screens/repertoire_list_screen.dart` | `_drill` at 480 — where a combined session is started |
| `chess_app/lib/features/analysis_studio/services/opening_book_service.dart` | `lookupByFen`, for the prefilled name. Read §2.2 of the brief first |
| `chess_app/test/repertoire_gate_test.dart` | the fake-API pattern to copy |

## The files you may add

Exactly these, and no others. The harness allows for them by name; **a file by
another name fails the untracked-tree gate and takes the whole round with it**,
which has already cost this project rounds of agent time.

| path | what |
|---|---|
| `chess_app/lib/features/repertoire/widgets/fork_repertoire_dialog.dart` | step 2 |
| `chess_app/test/repertoire_fork_test.dart` | its test |
| `chess_app/test/repertoire_combined_drill_test.dart` | steps 3–5 |

Everything else is an edit to a file that already exists. If you believe you
need a fourth file, **say so in the report and put the code in one of the
three** — do not add it and hope.

Leave no scratch files: no `.py` helpers, no notes, no `.bak`. Every run so far
has left some behind and every one failed this gate.

## The changes, in this order

### 1. The client catches up with the backend

`DrillBranch` gains the fields phase 1 already returns and this model throws
away: `id`, `key`, `repertoire` (`{id, name}`, nullable), `root`
(`{fen, path}`), `gateUci` and `breadth`. Decode them defensively — §3 lists
which are nullable.

`drillBranches()` and `drillLine()` gain an optional `List<int>? ids`. When it
is given, send `ids` as a comma-joined string and **omit** `rootFen`,
`rootPath` and `gateUci`: the server reads all three from the repertoire rows,
and a `color` sent beside `ids` must still agree with them.

**Every URL goes through `$backendUrl`.** §5 of the brief; this is not a style
note, it is the defect that shipped last round.

**Test these first and on their own**, with `MockClient` and no widget in
sight. A decoding bug found here is an hour not spent hunting it through two
screens.

### 2. "Izdvoji u novo otvaranje"

An action on the build screen's position row (beside the comment and AI
buttons, around line 909) that turns the position on the board into a
repertoire of its own.

It opens a dialog that:

* prefills the **name** from the opening book — §2.2 of the brief has the rule
  and the fallback when the position has no name;
* asks for the **gate** through `showGatePicker`, which already exists and
  already knows how to list the legal first moves of a position;
* creates it with `create(name:, color:, rootFen:, rootPath:, viaUci:)`.

**Nothing is copied and nothing is moved.** §2.1 of the brief explains why —
read it before you write a line of this, because the obvious implementation is
wrong in a way the tests will not show you.

### 3. A combined session is started from the list

The list screen gains a selection mode: long-press a card to enter it,
checkboxes on each card, and a bar saying how many are chosen with a "Vežbaj
izabrane" action. Selecting repertoires of **different colours** is refused with
a sentence — one session asks about one side.

It pushes `RepertoireDrillScreen` with a new `List<int>? ids`, optional, so the
seven existing call sites and every test that constructs that screen keep
working untouched.

### 4. The branch sheet shows which opening each branch is from

`_pickBranch` at 300 already builds a sheet from `drillBranches`. When a
combined session is running it passes `ids`, and each row shows the
`repertoire.name` the branch came from. Two openings that start with the same
two moves are two rows, not one — the server already gives each a unique `id`
for exactly this, so key the rows by `id` and never by `key`.

### 5. Checkboxes, and the sentence about the schedule

The sheet gains multi-select: check several branches, run them as one session.
Where that choice is made, the reader must be able to read **one sentence**
saying that a position two openings both reach is asked **once**, not twice.
§2.4 of the brief has the reason and the Serbian wording.

## Method

1. Read the brief whole. §3 is the contract, §5 is what gets the work rejected.
2. Work in the order above — each step compiles and tests green before the next.
3. Reuse what exists. `showGatePicker`, `AppFeedback`, `Breakpoints`,
   `numberedLine`, `OpeningBookService` and the theme are all already written; a
   second copy of any of them fails the batch on review even if the gates pass.
4. If a file this task names does not exist, **stop and say so.** Do not
   substitute the nearest plausible file.
5. `flutter analyze` must stay at **29** issues — all `info`, all
   `curly_braces_in_flow_control_structures`, in the six files listed in §6 of
   the brief. It does **not** exit clean and never has. Zero errors, zero
   warnings, no new infos: compare the list, not the exit code. §5 names the two
   deprecated APIs that put twelve new infos on this gate last round.
6. `flutter test`. Report the count and the delta from your own starting number.
7. **`dart format` every Dart file you touched — last, after everything else is
   green.** Both previous batches were failed by this, both because it was done
   early or not at all. Nothing is finished until this has been run.
8. Leave no scratch files in the tree.

## What must hold

* **User-facing strings stay Serbian.** The users are Serbian children and
  trainers. Code comments and your report are English.
* **Never use `ScaffoldMessenger` directly** — `AppFeedback` only.
* **Do the thing, then say it.** A message must never be able to take down the
  action it reports on.
* **Colour is never the only carrier of a fact.** A selected card is selected by
  a checkbox, not by being tinted.
* **Every request URL goes through `$backendUrl`.**

## Your report

Write `report-izdvajanje-i-kombinovani-dril.md` in the worktree root, stating:

1. `flutter test` count before and after, **both measured by you in this run**;
2. the `flutter analyze` list before and after — the count, and whether the set
   of files changed;
3. every file you added user-facing strings to;
4. **how you proved a fork copies no moves** — that the new repertoire's row is
   created and no move-writing call is made. Describing the code is not proof;
5. **how you proved a combined request sends `ids` and omits `rootFen`** — the
   URL your fake client actually received, quoted;
6. **how you proved two openings that open alike are two rows**;
7. anything the brief got wrong.

**Do not claim a number you did not compute in that run.** A correction is worth
more than a clean report.
