# Brief — Preparation, phase 2: material in, material out

`docs/PLAN-PRIPREMA.md` — read §4's **D1**, **D11** and **D13** whole, §5, and
phases 1 and 2 under §6, the first with what grading changed. Phase 1 is on
`master`: `lib/features/preparation/` is the screen's core, and the app cannot
reach it yet. This phase gives it its doors for material — the Library, what
puts something on the board, what keeps what is on it. The sketches are
`docs/skice/priprema.html`: `?v=C&w=1536&h=792&s=menu` and `&s=lib` are this
phase at the owner's window.

**Work only in this worktree**:
`D:\Projekti\chess_master\.claude\worktrees\priprema-faza-2` (branch
`priprema-faza-2`). Every command runs from its `chess_app/`. Touch nothing in
`D:\Projekti\chess_master` itself, commit nothing, push nothing. `pub get` has
been run here.

Baseline on `master` at `22eb1de3`, measured 27.9.2026 in a worktree with
nothing else running: **4266 passed, 1 skipped**; `flutter analyze` the **22**
known infos (all `curly_braces_in_flow_control_structures`). No server change
in this phase.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately. **And when a test's own timing or helper is
what stands in your way, say that — do not change what the screen does for a
person in order to fit it.** Phase 1's worker did, said so, and it was
reverted.

## The gate

`test/preparation_material_test.dart`, 24 cases, already in this worktree and
**not edited** except to report a fault in it. Its head comment is the frozen
contract: the five seams, every key, every sentence, what goes on the board by
what an entry is, what „Save as…" keeps. Today all 24 are red, each because a
door it looks for is not there.

**This gate has been compiled and watched going red; it has not been watched
going green.** Where a case cannot pass — a dialog that does not expose what
the case reads, a finder that matches two things — that is a fault of the gate
and the report's first section.

The pass condition:

```
flutter test test/preparation_material_test.dart test/preparation_screen_test.dart test/preparation_layout_test.dart
```

all green, **and** the full suite at **4266 + 24 = 4290 passed, 1 skipped**
plus the cases you add yourself (say how many, by file), no existing test
deleted, skipped or weakened, **and** `flutter analyze` with the same 22 infos
and nothing new, no `// ignore` added.

## What exists, and is the lead's

The screen's constructor already has the five seams, unused:
`positionLibrary`, `lessonApi`, `scannerApi`, `exerciseApi`,
`onOpenInAnalysis`. It stays as it is.

## What is built

Everything below is a door to something that exists. **A second copy of any of
it is a finding.** Read the room's own doors first — they are the behaviour
being moved: `lib/screens/chess_game_screen.dart`, `_putOnBoard` (`:1496`),
`saveCurrentPosition` (`:1785`), `_loadPgnText` to `_loadSinglePgnGame`
(`:2219–2310`), `_showBoardSetupDialog`, `_showSaveDialog`,
`_exportPreparationPgn`, `_savePreparationAnalysis`, `_goToCourseStep`. Do not
import that file and do not change it.

### 1. The bar

On a desktop window and on a phone held on its side: „Library"
(`prep-library`), „Board" (`prep-board-menu`), „Save as…" (`prep-save-menu`),
then ⋮ (`prep-more`) with „Settings". On a phone held upright: the title and ⋮,
which holds both menus' nine items under their two headings — „Put on the
board", „Keep what is on the board" — and „Settings"; the Library is the
fourth tab.

At 900 wide the three buttons and the title are whole. Measure the buttons'
natural widths before deciding their labels; if they do not fit, the labels
shorten to „Board" and „Save", never the title.

### 2. The Library's drawer

`prep-library-drawer`: over the board's side of the screen, from the left,
under the bar, 380 wide, with a scrim over the rest; it moves and resizes
nothing. Inside, the app's one `LibraryList` with the chips All, Tutorials,
Analyses, Exercises, Positions, `actionsFor` not given. While the Library
cannot be read: „The library could not be loaded." and „Try again", as the
room has them. It shuts when a row has been put on the board, and on
„Library" pressed again.

On a phone the same list is the fourth tab's content.

### 3. From the Library onto the board (D1)

| the entry | what goes on the board | read through |
|---|---|---|
| a tutorial | its parts, one at a time, **each with its line** | `LessonApiService.fetchRow`, then `readStepTree(fen:, pgn:)` for the part |
| an analysis | its **whole tree**, as it was saved | `AnalysisPersistenceService.instance.loadAnalysis` |
| an exercise, a position, a scan | **the position alone** — whatever line the entry carries is not loaded | the entry's `fen` |
| any of them with `needsReview` | nothing, until `settledFen` has an answer | `side_to_move_gate.dart` |

A new board is a new root: the cursor on it, no last move, no marks of the
old one, a half-drawn arrow forgotten, the engine asked about the new
position. **One function puts a board on the screen**, whoever asks — the
Library, „Board", an engine line's „load this position" — so that phase 3 has
one place to stamp a recording's `init`.

A part whose line does not replay (`rejectedMoves > 0`) goes up as far as it
replays and says how many moves were not read.

### 4. A tutorial is walked from the bar (D13)

While a tutorial is on the board the bar's subtitle is
`prep-part-label` — „Part 1 of 2 · The centre" (`shownPartTitle` names a part
that has no title of its own) — between `prep-part-prev` and `prep-part-next`,
with `prep-part-close`. **It costs the board nothing**: the board is the rect
it was. On a phone held upright it is a row under the bar; the board moves
down and keeps its size. Closing leaves the board as it stands. Putting
anything else on the board closes it.

### 5. „Board"

| item | does |
|---|---|
| „Set up position…" | `AnalysisBoardSetupDialog(initialFen: <the position on the board>)`, without `onPgnLoaded` |
| „Paste FEN…" | a dialog titled „Paste a position (FEN)", a field keyed `prep-fen-field`, „Cancel" and „Load"; trimmed; refused with `fenIllegalReason`'s own sentence, the dialog staying open |
| „Import PGN…" | `PgnImportDialog`; one game through `readAnalysisPgn` (`analysis_studio/services/pgn_import.dart`), several through `GameSelectorDialog`; the room's three sentences for a text that is not a game |
| „Starting position" | a new board on the standard start |

### 6. „Save as…" (D13)

| item | keeps | through |
|---|---|---|
| „Position" | the position of the move the cursor stands on, **and no line** | `SavePositionDialog`, then `LessonApiService.save(fen:)` with no `pgn` |
| „Exercise…" | — | the app's `MakeExerciseSheet`, handed a `MoveTree` read from the screen's own PGN (`PgnExporterService` writes, `MoveTree.parsePgn` reads) with `current` on the same move; refused with the count when a move did not replay. Lift the sheet's opening out of `MakeExerciseButton` into one function both call |
| „Analysis" | the whole tree | `promptSaveAnalysisDialog` |
| „PGN" | the whole tree as text | `exportPgnDialog`, header `Event "Preparation"`, file `preparation-YYYY-MM-DD.pgn` |
| „Open in Analysis" | — | `onOpenInAnalysis(copyTree(root))`; when not given, push `AnalysisStudioScreen(initialTree:)` |

A board with nothing on it — the standard start, no move, no mark — is not
kept as an analysis: „There is nothing on this board to keep yet." A board
with no moves has no PGN: „There are no moves on this board to export yet."

**Do the thing, then say it**, through `AppFeedback`.

### 7. The engine's dials

Phase 1 left them out and the room has them: `analysisDepth`, `analysisLines`
and their two `onChanged`, `onOpenSettings` on Windows, `onForceRestart`.
Wire them as the room does (`_buildStockfishAnalysisWidget`, `:748`), through
`PreparationEngine`. Write the cases yourself, against a `PreparationEngine`
that remembers what it was asked (`_AskedEngine` in the screen's gate is the
pattern): a changed depth and a changed number of lines each ask the engine
again, with the new value.

### 8. Not in this phase

Recording, the doors into the screen, the room's `isStudio` branches, anything
on the server, row actions in the drawer.

## Method

1. Read the gate's head comment and the room's doors before anything else.
2. **Measure before you lay out**: the natural size of every widget you reuse
   in a fixed place — phase 1's one failure was a card that is 516 px
   whatever it is given.
3. `dart format` every Dart file you touch.
4. Run the three gate files often; run the **full suite once at the end, with
   nothing else running**, and compare by name if the count is off.
   `replay_audio_test`, `opening_book_service_test` and
   `game_tutorial_run_test` fail under load and pass alone.
5. Render the screen before calling it done — the drawer open and each menu
   open at 1536 × 792, and the phone's ⋮ — with Roboto and the icon font
   loaded, to your scratch directory, not into `test/`. **Look at them**, and
   say what you saw that no test asked about.

## Report

Numbers and names, not prose about behaviour:

1. **What the brief or the gate got wrong** — first, and in full.
2. The three gate files: passed / failed, by name where failed.
3. The full suite: passed, skipped, failed by name, and what each failure did
   alone. `flutter analyze`: the summary line, and any entry outside the 22.
4. Every file created or changed, one line each.
5. Every existing test file you changed, and why — a changed assertion is
   quoted before and after.
6. Every place where you changed what the screen does for a person because of
   a test's timing, a helper or a fake — or „none".
7. Simplifications you noticed and did **not** make, one line each.
8. The pictures' paths, and what you saw in them.
