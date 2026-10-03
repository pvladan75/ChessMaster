# Engine, tablebase and openings where tutorials are written

Item 3 of the owner's list of 2.10.2026 (`docs/STANJE-RADA.md`, „Govor iz
spojenih klipova — plan, i vlasnikov spisak"): *„Motor, tablebase i otvaranja
u ekranu za tutorijal."* The session's one-line recommendation then: the same
panels Analysis draws, switched on from one place, off by default, never
written into a part on their own; Preparation first, then the studio.

Written 3.10.2026. Nothing in code. Phase 0, the drawing, is done
(`docs/skice/paneli/compare_panels.png`); the decisions below carry a
recommendation each. **The owner's answer, 3.10.2026: D1–D9 as recommended,
A for the studio.**

`APP` = `chess_app/lib`, `T` = `chess_app/test`.

## 1. What there is today (measured 3.10.2026)

**Analysis** has all three, each its own panel in the right column:

- the engine — `StockfishAnalysisWidget` (`APP/widgets/stockfish_analysis_widget.dart`),
  presentation only, fed by the screen's own glue around `StockfishService`
  (`_initEngine`, `_attachEngine`, `_triggerEngineAnalysis` in
  `analysis_studio_screen.dart`); off on arrival, switched off when the screen
  is left (`TickerMode`), silent while the game review holds the engine;
- the tablebase — `SyzygyPanelWidget`, fed by `SyzygyTablebaseService`
  (`GET /api/tablebase`, Lichess as the fallback), mate distances through
  `APP/core/services/mate_distance.dart`;
- the opening explorer — `OpeningExplorerPanelWidget`, fed by
  `OpeningExplorerService` (our server's `/opening-explorer`, an account
  needed), with the opening's name from the local `OpeningBookService`.

The two look-ups are fetched inline by the screen on every position change,
each behind a request id that drops a stale answer — **and fetched whether
their panel is shown or not**. A move tapped in either is played on the board
(`_playUciMove`). Which panels are shown is chosen in the board view menu (▦),
whose rows live in `APP/features/analysis_studio/widgets/analysis_panels.dart`,
remembered in `app_hidden_panels`; `T/analysis_panels_test.dart` holds that only
Analysis reads them and only that file writes them.

**Preparation** has the engine and nothing else. Its glue is
`PreparationEngine` (`APP/features/preparation/services/preparation_engine.dart`),
which calls itself „a third copy" of Analysis's and the room's; a fourth
attacher is the puzzle screen. The engine panel sits beside the comment under
the tree (D11 of `PLAN-PRIPREMA.md`), off on arrival; the evaluation bar has a
slot reserved beside the board so that switching it on never changes the
board's size. On a phone the engine is one of four tabs.

**A fault found while reading, measured.** `PreparationScreen` attaches its
engine only from `_onShownChanged`, which runs when the screen's `TickerMode`
*changes* — and on arrival it does not change. A spy engine counted **0
attaches** on arrival, both as the first screen and pushed over another. With
no subscriber the service's answer callbacks are `null`, so a trainer who
opens Preparation and switches the engine on should see no lines until they
leave the screen and come back. No test sees it: every Preparation test uses
an engine that overrides `triggerAnalysis`. To be confirmed on the device in
phase 1; fixed there either way.

**The tutorial studio** has none of the three. Its class comment says so on
purpose (it was not to be „a twelfth action in the Analysis Studio"). Its
board position is `TutorialDraftController.cursor.fen`; a move is played
through `playMove`, which may **open a new part** (a second move inside a
part) or be **held back** while the PGN tab holds unapplied text
(`PLAN-MAPA-DELOVA.md`). It has no board view menu (▦). On a window: the map
of parts (380), the board (616 at 1536 × 792), the authoring pane (460) with
the tabs Flow · Tree · PGN. On a phone: the board, a row of moves and the tabs
Line · Parts.

**A second fault, found while drawing, measured.** At 1536 × 792 in Roboto the
studio's board column is 32 px taller than its space: the board is
`maxHeight − 120` (616), and the marks row and the strip under it need more
than 120, so the strip ends 20 px below the window and is a scroll away. Phase
4 fixes it — the board about 584 — before anything is added beside it.

## 2. Decisions

**D1 — Where the panels are switched on: rows of the board view menu (▦), the
same three rows and words as Analysis** (`Engine analysis panel`, `Opening
Explorer`, `Tablebase (Syzygy)`). The 2.10 one-liner said „one word in the
bar"; since `PLAN-ANALIZA-TRAKA.md` (30.9.2026) Analysis says what the screen
shows in ▦, and its bar word `Engine` is a menu of jobs (review, study, extend)
— a bar word `Engine` that ticked panels here would be one word for two things
(R6 of `PLAN-EKRANI.md`). The studio gets the ▦ it lacks, with arrows and board
size as Preparation's has.

**D2 — Remembered per screen; what each starts with.** Each screen remembers
its own rows. Preparation starts with the engine panel shown (as today) and the
two look-ups hidden; the studio starts with all three hidden. The engine
itself is **off on arrival everywhere**, whatever is shown — the rule of
Analysis and Preparation since 18.9.

**D3 — Nothing is written into the work on its own.** No evaluation, line,
book move or tablebase verdict is put into a comment, a beat, a narration or
the tree by a panel. A move tapped in a panel is a move the trainer played: in
the studio it goes through `playMove`, so the part rules hold — a second move
in a part opens a part, and it is held back while the PGN tab has unapplied
text, with the same words.

**D4 — The engine's line actions in the studio: read only.** Preparation
offers „insert this line as a variation" and „load this position"; in the
studio a whole line inserted at once would open parts the trainer did not
play one by one. Recommendation: the studio's engine panel opens a line to
read (as Analysis does) and plays nothing but what is tapped in the
explorer and the tablebase. Can be widened later on the owner's word.

**D5 — The board keeps its size.** Whatever is switched on, the board does not
grow or shrink (Preparation's rule, `preparation_layout.dart`). The studio
reserves the evaluation bar's slot beside the board as Preparation does
(30 px). With the strip back on the screen (the board about 584, see §1) the map
still stands beside the board at 1536 × 792: 1040 − 584 − 30 = 426 ≥ 392.

**D6 — Where the panels stand in the studio on a window: to be chosen from
the drawing.** Not an end drawer as in the room: a drawer is modal and blocks
the board, and here the board is played while the panels are read.
**A** (recommended) — a fourth tab, `Engine`, beside Flow · Tree · PGN, holding
the shown panels stacked; it appears when a row of ▦ is ticked. Costs no
height in a pane that is already full at 792. **B** — the shown panels above
the tabs, the tabs under them; the tree and the panels at once, each shorter.

**D7 — On a phone.** Preparation: the look-ups under the engine in its
existing `Engine` tab, when ticked. The studio: a third tab, `Engine`, beside
Line · Parts, the same content.

**D8 — One home for each piece of code.**
- `PreparationEngine` moves to `APP/core/services/board_engine.dart` as
  `BoardEngine`, with the attach-on-arrival fix, and the studio uses it — the
  third copy becomes the one the next screen takes, instead of a fifth.
  Analysis's, the room's and the puzzle screen's glue are **not** moved in this
  plan; they are named for the owner's simplification batch.
- `PositionLookups` (`APP/core/services/position_lookups.dart`) — the tablebase
  and the explorer fetched for one FEN, each behind its request id, **only
  while its panel is shown**, and the opening's name. Analysis moves onto it
  in the same phase and its inline copy is deleted; Preparation and the studio
  use it.
- `analysis_panels.dart` stays the one home of the rows, given a scope
  (`analysis`, `preparation`, `studio`) and a key per scope;
  `T/analysis_panels_test.dart` is widened openly to the new readers.

**D9 — Guests and the recording.** The explorer needs an account and says so
in its panel, as on Analysis. In a Preparation take nothing of the panels is
recorded: the film draws the marks the trainer drew, never the engine's
arrows; this plan does not change the recorder.

## 3. Phases

**Phase 0 — the drawing** `[lead]` — done 3.10.2026. Preparation and the studio rendered as
they are at 1536 × 792 and 360 × 640, and after: Preparation with the two
look-ups beside the engine; the studio as D6 A and B. Sent to the owner as
PNGs; he answers D1–D9 from them.

**Phase 1 — Preparation's engine attaches on arrival, as `BoardEngine`**
`[lead]` — built 3.10.2026. `PreparationEngine` moved to
`APP/core/services/board_engine.dart` as `BoardEngine`; the screen attaches it
in `didChangeDependencies` when it is shown. Gate
`T/board_engine_attach_test.dart`, 3 cases, red on master with 0 attaches,
red again with the one new line removed. Live check [267.1]. Gate: a spy counts one attach on arrival, as the first screen
and pushed over another (red today: 0); the screen still detaches when covered
and attaches when shown again; Preparation's own tests unchanged. Live: lines
appear the first time the switch is turned on.

**Phase 2 — `PositionLookups`, and Analysis onto it** `[implementer]` — built
3.10.2026 (worker's `8f88cb93`; the lead's gate fixes `d624a0fb` — Analysis's
board is `SkinnedChessBoard`, played by taps, and the app writes the en passant
square after every double push — both faults the worker stopped on). Gate
`T/position_lookups_test.dart` (8) and `T/analysis_lookups_test.dart` (4);
mutations: six of seven caught, the seventh inert (a second dispose guard
behind the first). Full suite 5746. With it, before phases 3–5, the lead's
`writingPanels` / `writingPanelShown` in `analysis_panels.dart` and
`isPanelShownIn` / `setPanelShownIn` in `AppSettingsService` — the rows and
memory both screens use (`T/writing_panels_test.dart`, 4).
 Gate,
with fake clients: a stale answer is dropped; a hidden panel asks nothing; the
two look-ups for one FEN go out once; a guest's explorer says why. Analysis's
own tests unchanged and green; a request count on Analysis with the two
panels hidden falls to zero (today it is not).

**Phase 3 — Preparation's look-ups** `[implementer]` — built 3.10.2026 (worker's `361c1697`). Gate `T/preparation_panels_test.dart`, 8 cases; mutations: five of five caught, each by its own case (the explorer always asked, no look-up after a move, no ▦ rows, the engine drawn when unticked, the explorer playing nothing). Live [267.2]–[267.4]. ▦ rows by D1/D2, the
panels by the drawing, a tapped move played as the trainer's, the phone's
`Engine` tab by D7. `preparation_screen_test`'s „no server" group is rewritten
openly: zero requests at 1536 × 792 **while the look-ups are hidden**, which
is the rule it protected. The board's size is the same with every panel on
and off.

**Phase 4 — the studio on a window** `[implementer]` — built 3.10.2026 with phase 5 (worker's `2253901a`; the lead's gate fix `15b03245` — the phone cases reset the platform override in `addTearDown`, which runs after the framework's check of its debug variables, and the worker stopped on it). The board is `min(W − 526, H − 152)` of the body: the 120 under it was a guess, the two rows measure 56 + 72, so at 1536 × 792 the board is 584 (was 616) and the strip ends at 780 (was 812); 30 px beside it are the evaluation bar's, drawn or not; the map keeps its column from W = 1502. Gate `T/studio_panels_test.dart`, 8 cases; mutations: eight of eight caught, each by its own case (the strip's rows at 0, the tab always, the explorer always asked, no attach on arrival, a panel move that bypasses `_onMove`, no ▦ rows, no phone tab, the look-ups not following the cursor). The held-back move has no case of its own: it is `_onMove`'s, and the bypass mutation shows the panels go through it. Live [267.5]–[267.7]. First the strip back on
the screen at 1536 × 792 (§1, red today by 20 px); then ▦ in its strip, the
evaluation slot (D5), the panels by D6, moves through `playMove` (D3), the
engine read-only (D4). Gate: the board's size with every row on and off, the
map still beside the board at 1536 × 792, a tapped book move that would open a
part opens one, a tapped move held back while the PGN tab has text, nothing
asked while the rows are off.

**Phase 5 — the studio on a phone** `[implementer]` — built 3.10.2026 with phase 4. The `Engine` tab by D7; the portrait strip now takes the full width, which at six buttons had wrapped to two rows under the small board.

**Phase 6 — the owner's live pass.**

Out of scope: moving Analysis's, the room's and the puzzle screen's engine glue
onto `BoardEngine` (a simplification for the owner's batch); any change to what
Analysis shows.
