# The Analysis bar: four words in the order the work goes

Written 30.9.2026. The owner sent a screenshot of the Analysis screen and
asked for its bar to be regrouped, „nešto slično kao što smo uradili u
Preparation ekranu". Built the same day, by the lead, in one phase.

## 1. What was there

Twelve icons, no words, five colours that meant nothing, in the order they had
been added (`_toolbarActions`, measured on his screenshot at 48 px each,
576 px in all):

| # | Icon's tooltip | What it is |
|---|---|---|
| 1 | Board view | how the board looks |
| 2 | Setup Position / PGN | puts something on the board — one dialog, five tabs |
| 3 | Review entire game | the engine, over a game |
| 4 | Study this position | the engine, over a position |
| 5 | Extend branch | the engine, over a line |
| 6 | Use in a tutorial | out, into teaching material |
| 7 | Scan a book | leaves the screen; acts on nothing here |
| 8 | Export PGN | out |
| 9 | Saved analyses | in **and** out, in one dialog |
| 10 | Panels | what the screen shows |
| 11 | Settings | the rail's gear, a second time |
| 12 | Engine Logs | a diagnostic, in the corner |

On a phone: the first three and ⋮ with the other nine as one flat list.

## 2. The model

```
  Board          Engine          Save as…        Tutorial         ▦           ⋮
  puts           works on        keeps what      makes teaching   what the    the rest
  something      what is on      is on the       material of it   screen
  on the board   the board       board                            shows
```

„Board" and „Save as…" are Preparation's two words (`PLAN-PRIPREMA.md`, D11)
and mean what they mean there. On a phone the same groups are four buttons:
`Board view`, `Board`, `Engine`, ⋮ — and ⋮ holds the „Save as…" rows under
Preparation's own heading, „Keep what is on the board", the tutorial door and
Settings.

## 3. Decisions

All the owner's, 30.9.2026: „Slažem se sa ostalim predlozima", to the four put
to him with two sketches, and two of his own.

**D1. „Save as…" has Position and Exercise… here too.** The same label opens
the same list on both screens. The two are one implementation
(`features/library/widgets/keep_board.dart`), which Preparation now calls as
well.

**D2. „Scan a book" leaves this screen.** It has had its own card on Teach
since 22.9.2026 and does not act on this board. `onOpenScanner` is gone from
the screen and from the Analyse tab.

**D3. The engine's three jobs are one menu**, each row with a line saying what
it covers — the whole game, this position, this line. Three words of their own
would have saved a click and taken 710 px of the bar against 354.

**D4. „Tutorial" is its own word.** In a window the sheet's six rows hang
under it as a menu; on a phone the sheet itself opens from ⋮. One list of rows
(`teachRowGroups`), one switch behind both (`_onTeachRow`).

**D5. „Engine Logs" is removed** — „koristili smo ga dok smo rešavali problem
korišćenja engine-a". The dialog, and with it the 5000-line buffer in
`AppLogger` that nothing else read.

**D6. The lead's, stated so they can be overruled.**

- „Starting position" asks before it replaces anything. Inside the setup
  dialog the same button takes a second press to apply; as a row it is one
  tap.
- The panels' four checkboxes are rows of the board view menu, not a sheet
  behind an icon of their own: one menu says what the screen shows.
- ⋮ in a window holds „Settings" and nothing else, as in Preparation.
- „Extend branch" is „Extend this line" in the menu and in its dialog's title.
- A guest who picks Position, Exercise… or Analysis is told
  „Saving requires a signed-in account." and nothing opens.
- A word of the bar is a target 40 px tall. A `PopupMenuButton` is as big as
  its child, and a bare word is as tall as its letters.

## 4. The gate

`chess_app/test/analysis_bar_test.dart`, 30 cases, written before the bar and
red on `master` at `acc192c2` in all 30. Eighteen mutations, each red on the
right case; one survived first — see `docs/LESSONS.md`.

`move_tree_semantics_orphan_test.dart` opens each of the six menus with the
semantics spy on (six cases).

Rewritten openly, each with the supersession written above it:
`analysis_panels_test.dart` (was `analysis_panels_sheet_test.dart`),
`analysis_teach_door_test.dart`, `position_study_door_test.dart`.

## 5. Not in this plan

- The Library as a drawer on this screen, as Preparation has it.
- The screen's body. On the owner's screenshot the engine's panel is under the
  fold of the right column; in Preparation nothing is behind a scroll.
- The words of Preparation's own bar are targets as tall as their letters
  (D6, last point). Not touched here.

## 6. The live pass

`docs/TODO-provera.md`, [256.1]–[256.7], under Analyse — Analysis.
