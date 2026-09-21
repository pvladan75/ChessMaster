# Plan: Home, Practise and Teach use the width they are given

Written 21.9.2026 at the owner's request, after `docs/PLAN-LISTE.md` was built
in full and a Gemini pass over the same three tabs
(`sugestije_layout_ostali_tabovi.html`, kept outside the repository). The owner
agreed the three decisions in §2 the same day. The phases in §5 are built one
at a time, each with its gate.

Like `PLAN-LISTE.md`, this plan adds no capability: no server change, no schema
change, no new route. Every phase is `chess_app/lib` and its tests.

## 1. The request

The owner, 21.9.2026 (paraphrased from Serbian): *now redesign the screens of
the Home, Practise and Teach tabs the way we did the others in PLAN-LISTE.*

## 2. Decisions — owner, 21.9.2026

1. **Decision 2 of `PLAN-LISTE.md` is reversed.** Home and Teach lose their
   `maxWidth: 700`. The worry behind that decision — prose stretched across a
   wide screen — is answered by the principle in §3, not by a cap: no text is
   ever wider than one card.
2. **Practise gets one column per game phase** (Opening · Tactics · Endgame and
   technique) where three fit, and keeps **one** limit: three card columns at
   most. This is the single, stated exception to „do not cap": the tab holds
   eight cards, and in three columns all of them are on one screen, so more
   width could show nothing more.
3. **Teach's request form sits beside the people list**, not stretched across
   the full width.

## 3. The principle: sections stack, their contents flow

Each section stays full-width and in the order it has today. What is **inside**
a section flows into as many columns as fit. The column count comes from
`AdaptiveCardGrid.columnsFor` — the rule `PLAN-LISTE.md` already uses — applied
to the constraint the section receives, never to the window.

Three things follow from it by construction:

- **The phone keeps its shape.** Below two columns' width everything is one
  card per line. The order holds too, with one exception written into phase 2:
  on Teach the Library moved up beside what it keeps.
- **No line of prose is wider than a card** (at most
  `AdaptiveCardGrid.maxTileWidth`), which was the reason for the 700 cap.
- **The window-width bug goes away.** `teach_tab.dart` and
  `category_selection_hub.dart` both decide their columns from
  `Breakpoints.isWide`, which reads `MediaQuery` — the window — while the tab
  lays out inside a narrower box (`PLAN-LISTE.md` §3.2). Every decision here is
  taken from a `LayoutBuilder` instead.

The Gemini document proposed a fixed dashboard (three modules, then two, then a
full-width form) and turning each Trainer panel row into a tall card with its
button at the bottom. Neither is taken: a fixed module count is a column count
written down, and a tall card per entry gives back most of what the columns
save. Trainer panel entries stay **dense rows with the action on the right**,
laid out in columns.

## 4. The third half of pattern A

`adaptive_card_grid.dart` has two layouts, chosen by one question — *does a
card change height while the reader looks at it?*

- **`AdaptiveCardGrid`** — a sheet of equal cells of one declared height. Right
  for many cards of known height; fragile for text that wraps (phases 3a and 3b
  of `PLAN-LISTE.md` both paid for a wrong cell height).
- **`AdaptiveCardColumns`** — independent columns. Right for cards that grow;
  cards in one visual row do not line up.

The cards on these tabs are neither: a handful of peers whose heights differ a
little (one card has three buttons, its neighbour one) and do not change. So a
third: **`AdaptiveCardRows`** — the cards are laid out left to right, a row
holds `columnsFor(width)` of them, and **each row is as tall as its tallest
card**, with every card in it stretched to that height. Reading order is row
by row. Same file, same `columnsFor`, no second copy of the arithmetic
(rule 12). It builds every child, so it is for tens of cards, not thousands —
a list that can grow without bound belongs in the grid.

## 5. Phases, each with its gate

Standing conditions for every phase: no file outside `chess_app/lib`,
`chess_app/test` and `docs/`; no new `// ignore`; `dart format` on every Dart
file touched; `flutter analyze` showing the **same 26 infos** and no new one;
the app suite green and its count reported. Every gate is watched red on the
wrong code before it is believed green on the right one.

| # | Phase | Who | Gate |
|---|---|---|---|
| 0 | **Measured 21.9.2026 in a clean worktree of `master`: 3507 passed, 1 skipped; analyze 26 infos, all `curly_braces_in_flow_control_structures`.** The first attempt ran in the working directory while `lib/` was being edited — `flutter test` compiles each file as it reaches it, so the edits leaked into the "baseline"; it was killed and repeated in a worktree. **Measure the baseline where nothing can change under it.** | lead | — |
| 1 | **Built 21.9.2026.** **`AdaptiveCardRows`** in `widgets/adaptive_card_grid.dart`, its own render object (§4). Six mutations — no stretch, column-major order, a fixed count of two, a last row widened to fill, the window instead of the box, the `LayoutBuilder` removed — each red on the right case. The last is the tenth case: the render object answers no intrinsic size, so an intrinsic query must fail loudly through the `LayoutBuilder` rather than get 0 in silence | lead, inline | `test/adaptive_card_rows_test.dart`, ten cases: count read from painted positions at 360/840/1200/1920 and agreeing with `columnsFor` at the band boundaries; every card in a row the same height as the tallest; reading order left to right; one per line at 360 |
| 2 | **Built 21.9.2026.** Proved on master: 6 red, 2 green — four reds are assertions, two are the form's missing key, which says the structure is absent but is not an assertion. Three mutations (form never beside, people not flowing, the tab squeezed back to 700), each red on the right case; a first version of the third did not compile and was redone. Both library cards lost their own bottom gap — a gap inside one card of a row ends it short of its neighbours. **One change the owner did not ask for:** on a phone the Library now sits under Homework, beside what it keeps; it is point 4 of live item 212 and reverts in one line. **Teach.** Cap gone. Tutorials · Homework · Library in one flow, Preparation · New session in a second, the people card split into form │ lists above two columns, its rows flowing | lead, inline | `test/teach_tab_layout_test.dart`, eight cases. Three cards share a row at 1400; one per line at 360; the form beside the list at 1400 and above it at 360; no overflow at 360, 900 and 1920. Existing: `home_tabs_test`, `relationship_request_direction_test`, `parent_consent_test`, `saved_tutorials_phone_test`, the `tutorial_*` files |
| 3 | **Built 21.9.2026.** Proved on master: 3 red, 3 green (one red is the panel flow's missing key, not an assertion — the same shape as phase 2). Five mutations (panel rows in a `Column`, shortcuts in a `Column`, the 700 cap back, the flow reading the window, recordings in a `Column`), each red on the right case; two first versions missed their anchor after `dart format` and are not counted (see `LESSONS.md`). A panel row lost its own bottom margin — the flow's gap is used both ways, so rows are 12 apart instead of 8, on a phone too. Recordings are now bordered cards instead of list rows split by a divider. **Home.** Cap gone. Set for me · Due for review · Join a session in one flow; the Trainer panel's rows flow inside each section; recordings as cards in columns | lead, inline | The shortcut cards share a row at 1400; fourteen review rows take ⌈14 / columns⌉ rows; one per line at 360; no overflow. Existing: `trainer_panel_test`, `home_tabs_test` |
| 4 | **Built 21.9.2026, lead inline.** The gate's widths were corrected before it was written: `columnsFor` gives **three** columns from a card box of 865, so 1000 is a three-column width, not a two; the gate stands at 360 / 700 / 1000 and 1400, one in each band, plus 1920 for the cap. The cap is `maxColumns = 3` and a width **derived** from it (`3 × maxTileWidth + 2 × spacing`), so the count and the cap cannot disagree and no `min(3, …)` is needed. Proved on master: 4 red, 3 green, every red an assertion. Five mutations (the window, no cap, two drawn as three, three drawn as two, a phone drawn as two), each red on the right case. The gap between phase columns is now the grid's 12 instead of 20, because `columnsFor` assumes it. **Practise.** 1 column: today's order; 2: today's split; 3: one per phase; limited to three card widths; decided from the constraint, not the window | lead or `[implementer]` | Column count by phase at 360/1000/1400 read from painted positions; decided from a box, not the window; no overflow. Existing: `training_hub*`, `hub_*` |
| 5 | **Live pass** | owner | New items in `TODO-provera.md`, each tab on the phone and in a 1400 px window |

Order: 0 → 1, then 2, 3, 4 in any order; they share only phase 1's widget.

## 6. Excluded, deliberately

- **Analyse.** The board is the tab; it has its own layout rules.
- **Uniform button styles on the Practise cards** (the Gemini document's §3).
  Cosmetic, and not a layout question.
- **The Practise hero card** („Chess trainer and drills") takes height and says
  little. Flagged to the owner as a candidate for deletion, not acted on.
