# Brief — Preparation, phase 1: the screen's core

`docs/PLAN-PRIPREMA.md` — read §1 (the request), §2 up to „A recording made in
Preparation", §4's **D3** and **D11** whole, **T1**, §5, and phase 1 under §6.
The owner chose the screen's shape from pictures: `docs/skice/priprema.html`
opened in a browser with `?v=C&w=1536&h=792` is variant C at his window, and
`?v=PU&w=360&h=640` / `?v=PS&w=800&h=360` are the phone. **The sketch is the
shape, not the numbers** — the numbers are `PreparationLayout`'s.

**Work only in this worktree**:
`D:\Projekti\chess_master\.claude\worktrees\priprema-faza-1` (branch
`priprema-faza-1`). Every command runs from its `chess_app/`. Touch nothing in
`D:\Projekti\chess_master` itself, commit nothing, push nothing. `pub get` has
been run here; `linux/`, `macos/` and `windows/` show as modified by it (line
endings) — leave them as they are and do not format them.

Baseline on `master` at `295a2a91`, measured 27.9.2026 in a worktree with
nothing else running: **4197 passed, 1 skipped**; `flutter analyze` the **22**
known infos (all `curly_braces_in_flow_control_structures`: 8 in
`positional_evaluator_service.dart`, 12 in `ai_studio_screen.dart`, 2 in
`matrix_filter_panel.dart`). No server change in this phase — the backend is
not touched.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately: a new rule invented to make a broken fixture
pass is not accepted.

## The gate

Already in this worktree, written by the lead, and **not edited** except to
report a fault in them:

| file | holds | today |
|---|---|---|
| `test/preparation_layout_test.dart` | the layout rule, pure; every expected number a literal | 12 green, 7 mutations caught |
| `test/preparation_screen_test.dart` | the screen: 50 cases | 47 red on the placeholder, each naming what is missing; 3 green, each proved able to fail |

The pass condition is a command:

```
flutter test test/preparation_layout_test.dart test/preparation_screen_test.dart
```

all green, **and** the full suite at **4197 + 62 = 4259 passed, 1 skipped**,
plus the cases you add yourself (say how many, by file) — no existing test is
deleted, skipped or weakened — **and** `flutter analyze` with the same 22
infos and nothing new, no `// ignore` added.

## What exists, and is the lead's

- `lib/features/preparation/services/preparation_layout.dart` — **the rule.
  Do not change its numbers.** If a real widget cannot meet them, stop and
  report which one and by how much.
- `lib/features/preparation/screens/preparation_screen.dart` — a placeholder
  that draws nothing. **Its constructor stays as it is**; you write the rest.

## What is built

### 1. The screen — `lib/features/preparation/screens/preparation_screen.dart`

On `AnalysisNode` (T1). No socket, no request, nothing imported from
`lib/screens/chess_game_screen.dart`. Built from what exists — the list is at
the top of the gate, and **a second copy of any of those is a finding**:

| piece | from |
|---|---|
| the board | `BoardWithCoordinates(size: layout.board)` around `ChessBoardWithOverlay` |
| a move on a position | `playedMove` (`lib/core/services/legal_moves.dart`) — null means the move is refused and the board reloads the position it had |
| the marks | `BoardAnnotationController` and `BoardAnnotationBar` |
| the strip | `MoveNavigationControls(dense: true)` over `AnalysisNodeCursor`, with `onFlipBoard` and `BoardViewMenu` trailing as the room has it |
| the tree | `AnalysisMoveTreeWidget`, with `onPromoteNode`, `onDeleteNode` and `onMoveVariation` given |
| the engine's lines | `StockfishAnalysisWidget`, over `StockfishService` |
| the evaluation bar | `VerticalEvalBarWidget` on a desktop window and a phone on its side, `HorizontalEvalBarWidget` on a phone held upright |
| a phone on its side | `LandscapeBoardLayout` |
| keys from the keyboard | `MoveKeyboardShortcuts`, as the room wraps its body |
| a message | `AppFeedback`, after the thing it reports |

**Three shapes, chosen as the room chooses them**:
`LandscapeBoardLayout.applies(context)` first; else a width of
`Breakpoints.wide` or more is a desktop window; else a phone held upright.

**A desktop window** — `PreparationLayout.desktop(body, scale:)`, where `body`
is what the `Scaffold` gives under its bar (take it from a `LayoutBuilder`, do
not subtract 56 from the window) and `scale` is
`AppSettingsService.instance.boardSizeScale`:

```
 padding 8
 ┌─────┬──────────────────┐ gap 12 ┌──────────────────────────────┐
 │eval │                  │        │ the tree                     │
 │ 22  │   the board      │        │                              │
 │ +8  │   layout.board   │        ├───────────────┬──────────────┤
 │     │                  │        │ the comment   │ the engine's │
 └─────┼──────────────────┤        │               │ lines        │
  gap 4│ the marking bar  │ 56     └───────────────┴──────────────┘
  gap 4│ the move strip   │ 48      side by side when
       └──────────────────┘         layout.commentBesideEngine,
                                    else the comment over the engine
```

- The evaluation bar's 22 + 8 are kept **whether it is drawn or not**: the
  board does not move and does not change size when the engine is switched on.
- The marking bar and the strip are as wide as the board and stand under it,
  each **one row**.
- Nothing on a desktop window is behind a tab.
- What does not fit the pane's height scrolls **inside its own panel**; the
  board's column never scrolls.

**A phone held upright** — `PreparationLayout.phone(body, scale:)`: the board,
the marking bar, the strip, then **pinned** tabs `Tree`, `Comment`, `Engine`,
with the open tab's content under them, scrolling (the studio's phone layout
pins its tabs the same way). The board, the marking bar and the strip are on
screen without scrolling at 360 × 640. With the engine on, the horizontal bar
lies over the board and the board keeps its size.

**A phone on its side** — `LandscapeBoardLayout`, with `boardAside` **always
given** (an empty box of the bar's width while the engine is off), the strip
and the marking bar pinned in the right column, and the same three tabs under
them.

**The tree opens as the graph on a desktop window and as notation on a
phone.** `AnalysisMoveTreeWidget` keeps its view in private state and starts
on the graph; give it one optional parameter for where it starts, defaulted to
what it does today, so Analysis, the repertoire and the studio are unchanged.

**The engine**: off on arrival, both switches. Switching it on attaches to
`StockfishService` as the Analysis screen does; leaving the screen — a route
over it, or `dispose` — switches both off and releases it, by `TickerMode`
exactly as `AnalysisStudioScreen` does (`_onShownChanged`), and it stays off
on return. Engine arrows follow `AppSettingsService.showEngineArrows`. The
engine glue is a third copy of what Analysis and the room each hold
privately; keep it in one small class of its own under
`lib/features/preparation/` so it can be lifted later, and **say so in the
report** — do not refactor the other two.

**An engine's line into the tree** (`onInsertLineAsVariation`): the moves of
`continuationLan`, played one by one with `playedMove` from the move the
cursor stands on. A move the tree already has is walked into, not added
twice. The cursor does not move. Put the pure part beside `AnalysisNode`
(`lib/features/analysis_studio/services/`), with its own small test. Three
sentences, as the gate has them: „Moves added to variation: N.",
„Line does not match current position.", „Line was already in the tree."

**The comment**: a `TextField` keyed `prep-comment`, under „Comment for
1. e4" (`moveNumberLabel` + the move), enabled on a move and disabled on the
starting position, where the label is „Comment (select a move)". It shows the
comment of the move the cursor stands on, and what is typed is that move's.

**`onLoadFenToMainBoard`** from the engine's line dialog loads that position as
a new root, as the room does.

### 2. The marking bar — `lib/widgets/game_screen/board_annotation_bar.dart`

Two optional additions, **both defaulted to what the bar does today**, so the
Tutorial Studio's bar and its tests are untouched:

- `density` — `MarkingDensity` (`preparation_layout.dart`; move the enum into
  the bar's own file if the import direction bothers you, and re-export it
  from the layout — one enum, one home):
  - `regular`: today's bar.
  - `compact`: the same controls as **40 dp icon buttons**, their words in the
    tooltips („Arrow", „Square", „Line", „Undo", „Clear marks"), and the five
    `ArrowColorButton`s.
  - `tight`: as compact, with **one** colour button keyed
    `annotate-color-menu` — the picked colour, with its letter — that opens
    the five, each keyed `annotate-color-<id>` as ever.
- `onUndoPressed` — draws „Undo", keyed `annotate-undo`, **only when given**
  (rule 15). The studio does not give it and gets no button.

One row at every density: **the bar is never taller than 56**.

The screen picks `layout.marks`. „Undo" takes back the last mark of the kind
being drawn (`undoLastSquare` in square mode, `undoLastArrow` otherwise) and,
with none of that kind on the move, the last of the other kind; with none at
all it says „No mark to undo." Walking to another move calls `cancelPending`.
The rules of drawing are the controller's — do not write one in the screen.

### 3. What is deliberately not carried over from the room

**An evaluation is never written into a comment.** The room stamps
„[+0.30 / depth 24]" on an inserted line's first move and offers „Insert
evaluation into comment"; here neither exists, because a comment may become
what a tutorial's voice reads out. The gate holds the first.

**„To main line" and „Delete variation" as buttons** — they are in the tree's
menu, as in Analysis.

### 4. Not in this phase

The Library, „Board ▾", „Save as… ▾", „Record", the bar's other buttons, the
doors into the screen, the room's `isStudio` branches, anything on the server.
The screen is not reachable from the app until phase 4. The bar in this phase
holds the title „Preparation" and ⋮ with „Settings", nothing else.

## Decided by the lead in this brief (the owner may move any of them)

- The strip is dense (40 dp buttons) on a desktop window too: it is what makes
  its row 48.
- The board-size setting applies here as everywhere: it only shrinks.
- On a phone held upright the evaluation bar lies over the board and moves it
  down while it is on; it never changes the board's size.
- „Insert evaluation into comment" and the stamp on an inserted line are not
  carried over (§3 above).

## Method

1. Read the gate's head comment and the layout rule before anything else.
2. `dart format` every Dart file you touch — `pub get` has been run, so the
   formatter has its package config.
3. Run the two gate files often; run the **full suite once at the end, with
   nothing else running**, and compare by name if the count is not 4259 plus
   your own.
   `replay_audio_test`, `opening_book_service_test` and
   `game_tutorial_run_test` fail under load and pass alone — run any failure
   alone before reporting it.
4. Render the screen before calling it done: a widget test that pumps it at
   1536 × 792 and at 360 × 640 and writes a golden-style PNG to your scratch
   directory (not into `test/`), and **look at both pictures**. Say in the
   report what you saw that no test asked about.
5. Grep before writing: `playedMove`, `AnalysisNodeCursor`, `_onShownChanged`,
   `BoardViewMenu`, `MoveKeyboardShortcuts`.

## Report

Numbers and names, not prose about behaviour:

1. **What the brief got wrong** — first, and in full. A constant that does not
   hold, a widget that cannot be one row, a case of the gate that cannot pass.
2. The two gate files: passed / failed, by name where failed.
3. The full suite: passed, skipped, failed by name, and what each failure did
   alone. `flutter analyze`: the summary line, and any entry outside the 22.
4. Every file created or changed, one line each.
5. Every existing test file you changed, and why — a changed assertion is
   quoted before and after.
6. Simplifications you noticed and did **not** make (code that could be
   deleted without costing the reader anything), one line each.
7. The two pictures' paths, and what you saw in them.
