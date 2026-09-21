# Plan: the lists use the width they are given

Written 20.9.2026 at the owner's request, after item 5 of `zadaci.md` and a
review of `sugestije_objedinjeno_za_agenta.html` (the Gemini pass). The
decisions in §2 were agreed in conversation the same day. Nothing in this plan
is in code yet. The phases in §6 are briefed one at a time, each with its gate.

`PLAN-ZAVRSNICA.md` froze new capabilities on 8.9.2026. This plan adds none: it
changes how existing lists are laid out. No server change, no schema change, no
new route — every phase here is `chess_app/lib` and its tests.

## 1. The request

The owner, 20.9.2026 (paraphrased from Serbian): *the screens where you pick
something are needlessly wide on the desktop — tutorials, homework, exercises,
and more. When I said there is a lot of space on a wide screen, I did not mean
that it should be cut down by capping the item width; I meant that the space
should somehow be **used**.*

That second sentence is the whole plan. It rejects the answer this project had
already half-written twice: §2.4 of the Gemini document ("ograničenje
maksimalne širine kontejnera") and my own earlier answer under item 5 of
`zadaci.md`, which proposed a shared `CenteredPane` holding a cap. Both trade
one kind of waste for another. A 1920 px window capped at 700 shows the same
number of items it showed before; only the line length improves. The item count
on screen — which is what "I have to scroll too much" actually measures — does
not move at all.

## 2. Decisions — owner, 20.9.2026

1. **Do not cap. Spend the width.** A wide window must show *more*, not the
   same amount narrower. Where a pattern cannot show more, it must show
   something useful beside it.
2. **The three Home tabs keep their `maxWidth: 700`.** Dashboard, Friends and
   Teach are card stacks and feeds, not lists of choices; stretching their
   prose across a wide screen is worse, not better. They are **out of scope**
   and must not be touched by any phase here.
   **Reversed by the owner on 21.9.2026** — `PLAN-POCETNI-TABOVI.md` takes the
   cap off Home and Teach, answering the prose worry by keeping every line
   inside one card rather than by a cap.
3. **Pattern B goes all the way.** Master–detail for Repertoire and Library is
   the expensive half and it is wanted: it is what makes the desktop feel like
   a desktop application rather than a stretched phone.
4. **The game picker's search is done first, on its own.** It is the cheapest
   change here and the largest single improvement.
5. **`What to drill` gets columns, not a cap** — the Gemini document's clearest
   miss.

## 3. What exists today, measured 20.9.2026

**The cap already exists, in exactly three places**, and all three stay:
`widgets/home/dashboard_tab.dart:67`, `widgets/home/friends_tab.dart:175`,
`widgets/home/teach_tab.dart:67` — `BoxConstraints(maxWidth: 700)`.

**The list bodies have no width behaviour at all**, and they share one shape —
`ListView` → `Card` → `ListTile`:

| Where | File |
|---|---|
| Library (and the room's column) | `features/library/widgets/library_list.dart:292` |
| Homework templates | `features/homework/screens/homework_list_screen.dart:159` |
| Repertoires | `features/repertoire/screens/repertoire_list_screen.dart:745` |
| What to drill | `features/endgame_trainer/screens/endgame_picker_screen.dart:151` |
| Saved puzzles | `features/analysis_studio/widgets/saved_puzzle_sets_dialog.dart` — `Dialog` at `width: 460` |
| Choose a game | `widgets/game_selector_dialog.dart` — `AlertDialog` at `width: 400, height: 300` |

### 3.1 Why the cap cannot be the fix — the mechanism

`ListTile` has three slots — leading, title/subtitle, trailing — and **none of
them grow with width**. Each keeps its intrinsic size and the *gap* between
them grows. That is precisely where "a title, an ocean, and an icon" comes
from. Capping the container shrinks the ocean; it cannot put a second item in
the row, because `ListTile` has nowhere to put one.

So the fix is not a constraint on the outside. It is: **stop handing a wide
constraint to a widget that has no use for one.**

### 3.2 The vocabulary already exists and the lists never used it

`theme/breakpoints.dart` defines `wide = 840` (M3 expanded), `ultraWide = 1200`
and `compactWidth = 600`, each with its reason written down. Fourteen files use
it. Every one of them is a board, a shell, or a chrome widget. **Not one list
screen has ever asked the question.**

One symptom worth recording, because it shows the cap and the breakpoint
disagreeing about *which* width they mean: `teach_tab` caps its content at 700
**and** switches to two columns at `Breakpoints.isWide`, which reads
`MediaQuery.sizeOf(context).width` — the window, not the capped box. On a 900 px
window it lays two columns inside a 700 px container, 350 px each. Not in scope
to fix (decision 2), but it is the reason no phase here may read the window
width to decide a layout: **every decision in this plan is taken from the
`LayoutBuilder` constraint the widget actually receives.**

## 4. The three patterns

Three layouts, defined once, each list routed to one. Not six per-screen
designs — that would be six independent decisions and six independent test
files, which is what makes this kind of work never finish.

### A — Grid with a maximum tile width

For items that are peers carrying two to four facts. The column count is
**never** written down: `SliverGridDelegateWithMaxCrossAxisExtent` is given a
maximum tile width and works the count out from the constraint it gets.

`maxCrossAxisExtent = 420`. The number is chosen so the grid agrees with the
breakpoint already in the file: at 840 — `Breakpoints.wide`, where this project
already says "there is room for two columns" — 420 gives exactly two.

The framework's count is `(extent / (maxExtent + spacing)).ceil()`, so with
12 px of spacing the bands are 1 column to 432, 2 to 864, 3 to 1296, 4 to 1728,
5 to 2160 — one column at 360, two at 840, three at 1200, five at 1920. Those
four are the sizes phase 2's gate pumps, and they survive the screen padding
being taken off first (1888 at 1920 still gives 5). **The bands move if the
spacing changes**, which is exactly why the gate proves the count from rendered
x-offsets rather than quoting these numbers back.

Two consequences worth stating, because they are why this pattern and not a
column count:

- **The room's left column needs no special case.** `LibraryList` is used by
  both the Library screen and the room (`chess_game_screen.dart`). The room's
  column is narrow, so the same widget gives it one column without being told.
- **The phone is unchanged by construction.** Below 840 every one of these
  lists is a single column, exactly as today.

One home for it: `widgets/adaptive_card_grid.dart`. Not a copy per screen
(rule 12).

**Phase 4 found that this pattern has two halves**, and the file now holds
both. A sliver grid is a sheet of cells of **one** height, which is right for
a library entry and wrong for anything that grows: „What to drill" draws a
family that is a row tall shut and some 800 px tall open. So
`AdaptiveCardColumns` deals the cards into ordinary `Column`s, each taking the
height it needs, and buys one thing the grid cannot — **opening a card moves
nothing outside its own column**. The count still comes from
`AdaptiveCardGrid.columnsFor`, which is the delegate's own arithmetic written
out once so the two halves cannot drift; a case in the grid's test proves them
equal at the band boundaries.

Which half a list gets is decided by one question: **does a card ever change
height while the reader is looking at it?** No → the grid. Yes → the columns.

### B — Master–detail

Where an item has something worth previewing that a row cannot hold. Two
screens only: **Library** and **Repertoire**.

Split at `Breakpoints.wide` (840), matching its documented meaning — two
columns. Below it, nothing changes: the list is the screen and tapping opens
what it opens today.

The detail pane does **not** duplicate what a dialog already builds. For
Library, `features/library/widgets/board_preview_dialog.dart` already draws
exactly the right thing — board, title, task, side to move in words — so its
body is extracted into a panel used by both the dialog and the pane (rule 12).

### C — Dense rows plus search

Where the list is long enough that no layout saves it and the answer is
filtering. **Choose a game** (4126 rows) and, in part, **What to drill**.

## 5. Routing — which list gets which pattern

| List | Pattern | Note |
|---|---|---|
| Library (tutorials, exercises, positions, analyses, recordings, puzzle sets) | A, then B | The grid is phase 3; the detail pane phase 5 |
| Homework templates | A | |
| Saved puzzles | A | Dialog grows with the screen instead of `width: 460` |
| Repertoires | B | Detail pane from `RepertoireSummary` alone — no new request |
| What to drill | A (applied to the checkbox tree) | Families side by side; the catalogue stops being a scroll |
| Choose a game | C | Search first; the dense table second |
| Recordings on Dashboard | — | Inside the 700 cap, which stays (decision 2). The wide home for recordings is the Library's `recordings` chip, which phase 3 grids |

## 6. Phases, each with its gate

Every brief carries: *if you believe a test in the gate is wrong, stop and say
so in the report — do not work around it.*

Standing conditions for every phase below: no file outside `chess_app/lib` and
`chess_app/test`; no new `// ignore`; `dart format` on every Dart file touched;
`flutter analyze` showing the **same 26 infos** and no new one; the app suite
green and its count reported.

| # | Phase | Who | Gate |
|---|---|---|---|
| 0 | **Baseline.** The app suite and the analyze list, measured with nothing else running — `game_tutorial_run_test` alone needed 12 minutes on 18.9.2026, and under load the runner's three-minute per-test timeout reports passing tests as failures. CLAUDE.md quotes 3383 / 1 skipped and 26 infos; both are re-derived here, not repeated | `[verifier]`, **re-measured independently by the lead** | **Measured 20.9.2026, and both numbers match what CLAUDE.md claims.** `flutter test`: **3383 passed, 1 skipped, „All tests passed!"**, 9 min 53 s — the skip is the golden group. `flutter analyze`: **26 issues, every one `info` and every one `curly_braces_in_flow_control_structures`**, exit 1, 33 s — `ai_studio_screen.dart` 12, `positional_evaluator_service.dart` 8, `game_analysis_walker_service.dart` 3, `matrix_filter_panel.dart` 2, `review_api_service.dart` 1 (= 26). The skip is `design_gallery_golden_test.dart`. **The analyze list was produced twice — by the worker and by the lead, separately — and the two agree issue for issue**, which is a stronger baseline than either run alone. The backend was deliberately not measured: no phase here touches it. How the phase ran is recorded in §8.1 |
| 1 | **Built 20.9.2026** by the implementer, graded and taken by the lead: gate byte-identical, nothing outside the two permitted files, no new `ignore`, the report's „what the brief got wrong" empty. App **3383 → 3393**, analyze the same 26 infos with nothing from the changed file. **Six mutations by the lead, each red on the right test — and one of them found a hole in the lead's own gate**: „closes the dialog and then reports it" asserted that both things happened and could not see the **order**, so swapping `Navigator.pop` and the callback left all nine cases green. A pop is only observable when it happens, so a tenth case watches the navigator (`NavigatorObserver`) rather than the tree, and is red under that swap. Brief: `docs/briefs/BRIEF-LISTE-FAZA1-PRETRAGA.md`. **Choose a game gets a search box.** `widgets/game_selector_dialog.dart` is 57 lines: `width: 400, height: 300`, about five rows visible out of 4126, no search, and a raw 60-character slice of PGN as the subtitle. Search by player and by opening moves; the dialog sized from `MediaQuery` rather than a fixed 400 × 300. **Not** the data table yet — that is phase 7 and it is worth less than this | `[implementer]` | `docs/gates/game_selector_search_test.dart` — nine cases, all through the one public widget so that every red is an assertion and not a compile error. Two fixtures: six games for anything that counts rows, 4126 for the title's count and the dialog's size. Red on master: the search field, the narrowing by name and by moves, the Event tag it must **not** read, the „2 of 4126" count, the empty-result sentence, and the list's height. Green and guarding: the unfiltered total, that a choice both closes and reports, no overflow at 360. **A tenth case was added after grading** — the pop happens *before* the callback, watched through a `NavigatorObserver` |
| 2 | **Built 20.9.2026 by the lead, inline — not delegated.** The brief and gate would have cost more than the ~40-line widget (CLAUDE.md: a subagent starts cold, so a small task is cheaper done inline), and a gate naming a widget that does not exist yet can only fail to **compile**, which is not the right red. Instead the widget was written **deliberately wrong** (a fixed count of two) and the test watched to catch it: red at 360, 1200 and 1920 — and **green at 840**, where two happens to be correct. A test at one width would have proved nothing. App **3393 → 3400**, analyze the same 26 infos. Three mutations; the spacing one survived and is recorded in the test as the right answer rather than a hole. **`AdaptiveCardGrid`, the one home.** `widgets/adaptive_card_grid.dart` — a thin wrapper over `SliverGridDelegateWithMaxCrossAxisExtent(420)` with the project's spacing and a documented tile aspect. No screen uses it yet | `[implementer]` | New `test/adaptive_card_grid_test.dart` proving the count from the constraint, not from the window: pumped inside a `SizedBox` of width 360, 840, 1200 and 1920, asserting 1, 2, 3 and 5 columns **by the rendered x-offsets of the children** — not by reading the delegate back, which would only test arithmetic the framework already owns. The 420 constant asserted to be the single source (grep for a second literal) |
| 3a | **Amended the same day after the owner's live look** (→ 3410): with a **single** set the dialog still took the full 640 it was allowed and the grid reserved an empty second column — the card filled 49% of the row, and 29 px of dead air sat between a set and its buttons. The gate had asked whether **two** sets share a row and never what **one** looks like. It now asks both, plus that two still share a row so the fix cannot be „narrow the dialog for good". One set → a 460 dialog filled 100%; the dead air is 4 px. **Built 20.9.2026** by the implementer, graded and taken by the lead: gate byte-identical, nothing outside its three files, no new `ignore`. App **3400 → 3407**, analyze the same 26 infos with none from the changed files. **Four mutations by the lead, each red on the right test — and one corrected this brief**: reverting the width to 460 leaves the phone green, while removing `insetPadding: 16` alone brings the overflow back. So the `Dialog`'s **default insets** broke the phone and the **fixed width** kept a wide window to one column — two independent faults that looked like one, and the gate holds each separately. The worker's one real catch: the gate file was not `dart format` clean, so running the formatter over `test/` would have broken byte-identity — fixed at source. **Split out of phase 3 on 20.9.2026, after measuring the test surface.** The two low-churn targets: `HomeworkListScreen` and `SavedPuzzleSetsDialog`. The homework list is reached by **keys** (`homework-list-row-N`, `-send-`, `-delete-`), not by `ListTile`, so it moves with almost no finder churn; the saved-puzzles dialog has **no tests at all**, so it is purely additive. Writing the gate found a real bug on master: **the saved-puzzles dialog already overflows on a 360 dp phone** (a `RenderFlex` by 1.3 px) — a `Container(width: 460)` inside a `Dialog` whose default insets leave about 280, with the row's delete and „Open" not fitting. Invisible in a release build, which clips instead of warning | `[implementer]` | `docs/gates/lists_grid_3a_test.dart` — seven cases through the real screens, with a `MockClient` for the templates and a seeded `SharedPreferences` for the sets whose JSON comes from the model's own `toJson`. Every layout claim is read from where the cards are painted; **none is a width threshold**, after phase 1 showed one can pass over an unchanged fault. Proved on master: **4 green, 3 red** — templates side by side at 1400, sets side by side at 1400, and the phone overflow. Green and guarding: the phone stays one per line, the three row keys and the delete confirmation, what a row says, and that „Open" still hands over that set's puzzles |
| 3b | **Built 20.9.2026 by the lead, inline — not delegated**, for the same reason as phases 2 and 1b: proving this gate satisfiable meant measuring the card's geometry, and measuring it *is* the implementation. The change is ~50 lines in one file. App **3423 → 3437**, analyze the same 26 infos, none from the four changed files. **`LibraryList`'s rows** — the risky half. `ListView` → `AdaptiveCardGrid`, a row → a `Card` holding the same `ListTile` with its actions under it. `actionsBesideFrom = 480` is **deleted**: a card is never wider than the grid's 420, so that branch could no longer be reached. `cardHeight = 132` is taken from the tallest card this list can draw (a 56 px thumbnail tile plus a line of four buttons), which is what keeps the content at the top rather than spread. **The finder churn was one line**, as predicted: `titlesShown` was scoped to `ListView` and is now scoped to `AdaptiveCardGrid` — no assertion in that file changed. **What the plan's §8 guard missed, and it is the lesson of this phase**: it says to grep the touched test files for `ListTile`, which finds nothing here, because the test that broke reaches rows through the **shared helper** `libraryRow` in `test/support/shelf_over_lessons.dart`. `saved_tutorials_phone_test.dart` asserted the deleted rule by name — „on Windows the rows keep their buttons beside the title", the send button within 24 px of the title's line, measured 68 after the change. Its four phone cases stayed green, so the file still does the job it was written for; the one Windows case was **rewritten, openly**, to the new arrangement (the buttons under the title and inside that entry's own card) with the supersession written above it. Nine mutations by the lead: `maxTileWidth` 420 → 2000, `shrinkWrap` off, the key moved off its `KeyedSubtree`, `MainAxisAlignment.center` and `.end`, a generous `cardHeight` spread with `.spaceBetween` (3a's fault word for word), and the actions put back beside the title — each red on the right case. **Three survived**, all for one reason worth keeping: the tile height is tight to the tallest card, so a bare `Spacer` or a bare `.spaceBetween` has 4 px to spread and spreading them changes nothing a reader would see; and a merely over-generous `cardHeight` breaks no rule this gate states | lead | `docs/gates/library_grid_3b_test.dart` — fourteen cases, **both callers driven for real**: `LibraryScreen` over a `MockClient` and the actual `ChessGamePage` for the room's 300 px column. Proved on master: **12 green, 2 red**, both assertion failures and neither a compile error. Red: cards side by side at 1400, and the rows going through the one grid (rule 12). Green and guarding: one card per line at 360, every `library-row-…` key and the shared `libraryRow` helper, each kind's own actions inside its own card, what a card says, the chips and the search still narrowing it, the empty shelf, the room's column staying one-per-line inside its `SingleChildScrollView`, the board thumbnail at both sizes, and the two taps on one card — the thumbnail previews, the card opens |
| 4 | **Built 20.9.2026 by the lead, inline**, for the same reason as 2, 3b and 1b: the phase's one real question was whether pattern A can hold this list at all, and answering it *is* the implementation. **It cannot, and that is the finding.** `AdaptiveCardGrid` is a sliver delegate with one `mainAxisExtent` — a sheet of equal cells — and a family card is one row tall shut and some 800 open (rook endings come in thirteen shapes). One cell height has exactly two outcomes and both are faults this plan already paid for: the open family overflows its cell, or every shut family is given the open one's height and the window fills with air, which is phase 3a's complaint word for word. So pattern A grew a sibling, `AdaptiveCardColumns` in the same file: the cards are dealt round-robin into ordinary `Column`s, each taking the height its contents need. **The column count is still never written down** — it now comes from `AdaptiveCardGrid.columnsFor`, the formula lifted out of the delegate so the two places that must agree are one fixture's job (rule 12), with a case in the grid's own test reading the delegate's answer off the rendering and holding the helper to it at 431/432/433/863/864 — the band boundaries, and the only widths that caught the „forget the spacing" mutation. The gain over the `ListView` is not only that nothing clips: **opening one family no longer moves the others.** App **3437 → 3445**, analyze the same 26 infos, none from the two changed files. **Seven mutations, each red on the right case, none survived.** The gate was first red for three wrong reasons, all recorded in `LESSONS.md`: a fixture typed `Map<String, Object>` that `whereType<Map<String, dynamic>>` threw away, so the screen drew „unavailable"; a chevron tapped blind, which is a *toggle* and shut the family the case believed it had opened (the screen opens its biggest family by itself); and `find.ancestor(…).first` throwing `Bad state` instead of failing, because a `ListView` builds nothing below the fold. **What to drill, in columns.** The two switches and the level chips stay a full-width header | lead | `test/endgame_picker_layout_test.dart` — seven cases through the real screen, every layout claim read from where the cards are painted and none of them a width threshold. Proved on master: **4 red, 3 green**, all four reds assertions. Red: the families side by side at 1400, the count agreeing with the shared grid, a neighbour staying put when thirteen shapes unfold, and the header staying wider than a column. Green and guarding: one family per line at 360, and `takeException()` null with the tall family open at 1400 × 900, 1400 × 600 and 360 × 640. `endgame_picker_test.dart` green unchanged — every case in it is about totals and requests, none about layout, so a case that breaks there is a real regression |
| 5 | **Built 20.9.2026 by the lead, inline.** App **3463 → 3474**, analyze the same 26 infos, none from the changed files. **Pattern B, Library.** `BoardPreviewDialog`'s body extracted to `BoardPreviewPanel`, used by both. `LibraryList` gains **optional** `selectedId` and `onSelect` — it draws a selection only when given one, so the room's column is untouched (rule 15). `LibraryScreen` splits at 840: list left, panel right. The selection is drawn as an **outline**, not a tint: the owner's sign-off reads luminance and shape, never hue. `selectedId` carries the kind as well as the id (`LibraryList.idOf`, the same string the row's key is built from), because ids come from different tables and a position 12 and a tutorial 12 both exist — a mutation proved that one. **The phase's real find was a bug on master.** The pane makes the shelf narrow, and a narrow shelf overflowed: `AdaptiveCardGrid` had a *maximum* tile width and no *minimum*, so `ceil` split 460 px into two columns of 224 and a `LibraryList` card at 224 overflowed its own height by 48 px. Measured with no pane and no screen involved. **The owner corrected the reach of this the same day**: Windows sets a 900 px minimum window (`windows/runner/win32_window.cpp`, `ptMinTrackSize`), so that band was never reachable — without a pane the shelf at the smallest allowed window is 876 and always had two full columns, and a phone is 360 and always had one. The bug was **dormant**, and the pane woke it (rule 14): at that same smallest window the shelf is 444, which without the rule is two columns of 216 and a clipped card. So `minTileWidth` does not repair the past — it carries phase 5 at its tightest point. Fixed at the root: `minTileWidth = 280`, and `columnsFor` now derives the count from **two** constraints instead of one, with the grid taking that count rather than a delegate's own arithmetic. Seven mutations; six red on the right case, **one survived** — swapping the screen's constraint for `MediaQuery` changes nothing, because `LibraryScreen` is always a whole route, so the rule does not bite there and the gate says so out loud | lead | `test/library_master_detail_test.dart` — nine cases, both callers driven for real. Proved on master: **3 red, 6 green**, all three reds assertions. Red: the board going to the pane rather than a dialog at 1400, which entry the pane draws, and the pane saying what it is for before anything is chosen. Green and guarding: the dialog at 800 exactly as today, the room's column still opening its dialog inside a 1400 window, the thumbnail not opening what it shows, no overflow, the narrow shelf, and the colliding-id pair. The `board_preview_dialog` tests green unchanged — and a mutation that empties the shared panel turns the **dialog's** own case red, which is the proof the extraction is load-bearing rather than a copy |
| 6 | **Built 20.9.2026 by the lead, inline.** App **3474 → 3487**, analyze the same 26 infos, none from the changed files. **The owner's eye caught a clipped rank in the pane the same evening**, and the fix and its sweep are folded in here: the pane's column stretches its children so the buttons fill it, and a `BoardThumbnail` told 360 and handed a tight 396 drew eight ranks into 360 of height — `Center` fixes it, and the „nothing overflows" case was green throughout, because **clipping is not overflow**. Sweeping every board in `lib/` for the same hazard then found a second one **already shipping**: the Library card's leading thumbnail, `56.0 x 48.0` on Windows and macOS against `56.0 x 56.0` on Android, because `ListTile`'s leading slot is `maxHeight = 56 + visualDensity.dy` and `adaptivePlatformDensity` is compact on every desktop. `thumbnailSize = 48` now, and the cases pump **both** platforms, because one alone cannot tell a square board from a lucky density. **Pattern B, Repertoire.** `repertoire_list_screen.dart` splits at 840. **Measured before writing: no new request** — `RepertoireSummary` already carries `rootFen`, `rootPath`, `viaSan`, `color` and `moves`, so the pane draws the root, the line that reached it and the two doors from what the list already holds. The line is numbered (`lineToRoot`), an empty `rootPath` says „From the start" rather than inventing an opening — the card already refuses that — and the board faces the side the repertoire is **for**, because the whole point of one is what *you* would play there. **One behaviour change, and it is the phase's real decision:** on a wide window a row **selects** and the pane carries „Open", where the Library's card went on opening. The rule behind the difference is written into the gate — a Library card has two targets, its board and the rest of it, so the second one could become „show me"; a repertoire row has one, and where there is one target and a pane, the target selects. **That is the thing to look at live (item 209, point 1); it reverts in one line if the owner reads it the other way.** Six mutations, each red on the right case, none survived | lead | `test/repertoire_master_detail_test.dart` — nine cases. Proved on master: **7 red, 2 green**. One of the reds is labelled in the file as red for the **wrong** reason and kept anyway: with no pane the first tap navigates, so „three selections issue no request" cannot fail honestly there — its job is to guard the pane from the day somebody gives it a graph walk, which is exactly what the progress count was deleted for on 16.9.2026. Green and guarding: the row opening at 800, and no overflow. The rest are the pane's own claims — the line, which row it follows, „From the start", the outline on one row only, the board's side, and the empty state. `repertoire_list_card_test.dart` green unchanged |
| 1b | **Built 20.9.2026 by the lead, inline.** `MoveTree.sanTokens` reads the moves out of a body — `{ … }` and `;` comments, `$N` NAGs, variations (innermost first, so nested ones go too), move numbers and the result all out — and **both** the preview and the search go through it, so `1. e4 c5` and `e4 c5` answer the same. The preview is now written out from the moves rather than sliced out of the file. App **3410 → 3423**. Six mutations: two were **invalid** (deleting a line stopped the file compiling, which is not the right red — redone by making the regex unmatchable), three red on the right case, and one **survived** — nothing covered variations, because the dialog's fixtures have none, so the shared helper got its own pure test (`san_tokens_test.dart`, 10 cases) and the mutation is red there. **Found by the owner on 20.9.2026.** In „Choose a game" a row's subtitle reads `1. e4 { [%clk 0:03:00] } 1... c5 …` — the clock comments eat the line, so two moves show where eight would fit, **and the move search is degraded**: typing `e4 c5` matches nothing, because the annotation sits between them in `pgnBody`, which is the string the filter reads. Cause is phase 1's fixture: clean move text, while the owner's 4126 games come from online play and carry `%clk` on every move (rule 6, word for word). **This is not phase 7** — that is the table, and it changes layout, not what a row says or what the search matches. Strip `{ … }` comments and `$N` NAGs before both the preview and the match, borrowing the vocabulary `move_tree.dart` already has rather than writing a second one | `[implementer]` | To be written |
| 7 | **Built 20.9.2026 by the lead, inline, after the owner asked for it** — „the raw text and the cards still bother me in Choose a game, I would like it turned into a real dense table". App **3487 → 3499**, analyze the same 26 infos, none from the changed file. §2.3 of the suggestions document is the shape and §3.3 its phone half, and both are built: above a dialog width of 560 a sticky header over virtualised **38 px** rows with five columns — White · Black · Date · Result · First moves — and below it the same facts on two dense lines. A result filter (All · 1-0 · ½-½ · 0-1) sits under the search and **narrows what the search left** rather than replacing it. The dialog's caps went 640 → 900 wide and 640 → 720 tall, because a table earns the room. **Two things in the mockup were deliberately not built**, and the gate says why: the „Izaberi" action column, because the row is already the target and one action does not want two doors; and the pagination (`1 / 206`), because `ListView.builder` virtualises and paging would put the reader back to hunting a page number. The filter is by **result** rather than the mockup's „wins/losses", which would have to guess which side this account played out of the headers — a result is a fact the file already states. Five mutations, each red on the right case | lead | `test/game_selector_table_test.dart` — nine cases. Proved on master: **7 red, 2 green**, every red an assertion after three of them were re-aimed from `StateError` into claims. The case that carries the phase is not „the headings are on screen" but **a row's cells line up under them**, measured from where they are painted — and it is scoped to one row, because „1-0" is on the screen twice and an unscoped finder would have measured the filter chip against the Result column and called it aligned. **One mutation survived the first round and the fixture was wrong, not the code**: the compose case searched „pvladan", which every game in it matched, so a filter that ignored the search entirely gave the same answer. It searches „Kingston" now, which leaves one drawn game, so asking for 1-0 on top of it must leave nothing. `game_selector_search_test.dart` green unchanged |
| 8 | **Live pass** | owner | `TODO-provera.md`, new items. Each screen looked at on the phone **and** in a 1400 px window. A release build paints no overflow warning — it clips silently — so this pass is the only place a clipped row is caught |

Order: 0 → 1 → 2 → 3, then 4, 5 and 6 in any order; they share only phase 2's
widget. 1 is independent of all of them and is the first thing worth watching.

### 3.3 One thing the phase-1 gate found, before anything was built

`GameSelectorDialog`'s content is `SizedBox(width: 400, height: 300)`. Measured
on master, 20.9.2026: that box asks for 400 and **is given 912** in a 1400 px
window. `AlertDialog` lays title, content and actions out under an
`IntrinsicWidth`, which takes the widest intrinsic — here the title string —
and forces every child to it.

So the dialog's width today is not fixed, it is *accidental*: it follows the
title text and the font that draws it. The **height is the genuinely fixed
dimension**, and 300 is the number that means "five rows out of 4126".

Two things follow. A gate case asserting a width threshold on this dialog would
have passed on master while the fault stood — it did, on the first run, and was
re-aimed. And `board_preview_dialog.dart` already carries this warning in a
comment and already reads its size from `MediaQuery`: the instinct exists in
the codebase and this dialog predates it.

## 7. Excluded, deliberately

1. **The three Home tabs** — owner's decision 2.
2. **The Gemini document's §2.4 max-width cap** — owner's decision 1. It is the
   one pattern in that document which spends no width, and it was assigned to
   the screen with the most to show.
3. **The document's colour palette.** The mockups are hard-coded `#818cf8` on
   `#0f172a`. This app has `context.colors` tokens and an owner whose live
   sign-off reads luminance and shape, never hue. The mockups are read for
   arrangement only.
4. **The Tutorial Studio mockup, the document's whole second half.** It
   redesigns a screen rebuilt over the last week and measured to the pixel —
   the phone studio, the navigation strip folded onto one row, the "add parts"
   door made a 20 × 20 button in the title row *because* three surfaces
   measured full by 2, 19 and 33 px. Adopting its top bar would undo measured
   work to no end. Its one idea worth checking is the horizontal move-pill
   strip, and CLAUDE.md records the phone studio already grew a row of moves on
   18.9.2026 — so **check before building**, it is likely already there.
5. **Any server change.** Every phase is app-only, which is also why none of
   them can be blocked by the owner's nodemon.

## 8. The risk this plan is most likely to be caught by

The layout is the small half. The test surface is the large one: these screens
are found through `find.byType(ListTile)` and `find.text`, and changing the
widget changes the finders — under the standing rule that an assertion of
absence is a claim about the whole screen, and that a finder unique today stops
being unique when the screen grows. Two guards, in every brief from phase 3 on:

- **The brief names which finders may be amended.** Anything else amended shows
  up in grading as a rewritten assertion, which is the failure mode that makes
  a green suite meaningless.
- **After each phase, grep the touched test files for `ListTile`.** A finder
  left behind is a test that now asserts about a widget the screen no longer
  draws.
- **And grep for the shared finders and for the constant being deleted, not
  only for the widget's name.** Phase 3b paid for this: a grep for
  `LibraryList` and `library-row-` found eight files and missed a ninth,
  because `saved_tutorials_phone_test.dart` reaches a row through the helper
  `libraryRow` in `test/support/shelf_over_lessons.dart` and never names the
  widget. It asserted the rule the phase deleted, and only the full suite saw
  it. A shared helper is exactly the place a finder hides.

And the release-build trap: a `Row` wider than its constraint throws in a
*test* build and is silently clipped in a release one. Every layout gate here
pumps at two sizes and asserts `takeException()` is null; phase 8 is what
catches what that cannot.

### 8.1 What phase 0 cost, and the sentence that did not hold

The brief said *stop anything you start in the background before you report*.
The worker started `flutter test` in the background and returned in 54 seconds
with no numbers — then again on its second stop, each time saying it would wait
for a notification. It delivered a full and correct report on its **third**
stop, about 13 minutes of wall clock after it began.

So the work was sound and the reporting was not. Two things follow, and the
second is the one that nearly cost something:

- Between the first empty return and the real report, the obvious move was to
  measure again. The machine said otherwise — one `dart` and eight
  `flutter_tester` processes, so the first run was still going. A second run
  would have produced red that was really contention, the exact failure this
  project already knows about (`opening_book_service_test` beside
  `game_tutorial_run_test`). **Check the machine before starting a second
  run.**
- Reading the worker's own log files mid-run is not the same as reading a
  finished run. The lead read `flutter_analyze_out.log` while it still ended at
  „Analyzing chess_app…" and concluded that analyze had never finished; it had
  simply not finished *yet*. The lead's own analyze run settled it, and the
  worker's later report agreed with it issue for issue. **A truncated log is a
  statement about when you looked, not about what happened.**

What goes into every brief from phase 1 on: **a rule a worker can satisfy by
saying nothing is not a rule.** „Stop your background work" is now a question
the report has to answer — *state that no process of yours is still running,
and say how you confirmed it* — and the brief says to run the suite in the
foreground and wait for it.
