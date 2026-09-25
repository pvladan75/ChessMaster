# The parts of a tutorial as a map, and a part as one line

Written 25.9.2026 by the lead (Opus), from the owner's request of the same day.
It replaces §8 of `PLAN-TUTORIJAL-VIDEO.md` („the parts drawn as a tree"), whose
five questions are answered in §4 below. **The owner answered §4 the same day:
all as recommended** („sve po preporuci, napiši plan").

Every brief handed to a worker carries this sentence, in its method section:
*If you believe a test in the gate is wrong, stop and say so in the report — do
not work around it.*

Paths: `APP` = `chess_app/lib/`, `BE` = `chess_backend/`, `T` = `chess_app/test/`,
`TS` = `APP/features/tutorial_studio/`.

## 1. The request

The owner, 25.9.2026, translated, with a screenshot of the studio in which he
had played a second move (18... h6 19. Rxe5 beside 18... cxd4) inside one part:

> I played a side line in the same part. I don't know what happens when a user
> does what I did. Maybe we should prevent playing an alternative move in the
> same part? I don't even know whether my part split in two. The overview of
> the parts is weak anyway: you can't see well which part I'm on or how it is
> connected to the others. So I thought we could visualise it — see which part
> continues from which, something like the graphical move tree. The screenshot
> also shows there is room for it on the desktop: there is space around the
> board for the screen to be reorganised. My main complaint is that the
> relations between the parts are not visualised.
>
> Also, the tutorial's name is not shown in full; the fields where text is
> typed are a problem in general.

The sketch he answered is the PNG sent in that conversation: 1536 × 792, his
window in logical pixels (1920 × 1080 at 125 %), with the map left of the
board, the board unchanged, the open part on the right and the title in the
bar. It is not in the repository; §3 describes it.

## 2. What exists, measured 25.9.2026

**A second move inside a part is kept and never filmed.** `playMove`
(`TS/services/tutorial_draft_controller.dart:330`) adds a child at the cursor,
so the part now forks; nothing splits. The save keeps the fork (the part's `pgn`
carries the variation). The film is `filmBeatsOf` (`TS/services/tutorial_video.dart:76`),
which walks each part with `beatsOf(section.root, section.root)` — the first
child at every fork — so the side line and every sentence and arrow on it are
absent from the video, and nothing on the screen says so. Measured with a
throwaway test: a part `1. e4 e5 (1... c5 2. Nf3) 2. Nf3` keeps `c5` in its tree
and in `pgnForSave`, and films as start, e4, e5, Nf3. The code already knew it:
`TS/services/game_tutorial/skeleton_moments.dart:712` makes the second-best
move a part of its own *because* „the film ignores variations".

In the owner's tutorial the film shows 18... cxd4 (the first child, drawn with
the grey main-line fill in „Tree") and not 18... h6 19. Rxe5. The only sign of
which branch is filmed is that fill, a tint (`APP/features/analysis_studio/widgets/visual_move_tree_widget.dart:657-667`)
— hue, which the owner's sign-offs cannot rely on.

**Eight doors write a part, and five of them can bring a fork in:**

| # | door | where | can fork today |
|---|---|---|---|
| 1 | a move on the board | `TutorialDraftController.playMove` | yes |
| 2 | the „PGN" tab's Apply | `_applyPgn` → `replaceLine` (`TS/screens/tutorial_studio_screen.dart:1440`, controller `:400`) | yes, a typed variation |
| 3 | the Analysis handover | `TutorialEntry.fromAnalysis` → `section.root = handover.root`, twice (`tutorial_studio_screen.dart:249`, `:330`) | yes, the whole subtree |
| 4 | an import, opened | `TutorialEntry.imported` → `TutorialDraft.fromLesson` — JSON and PGN files (`TS/widgets/tutorial_library_card.dart:213`), the tutorial from a game (`TS/widgets/game_tutorial_flow.dart:511`) | yes; a PGN import is „one game one part" (`TS/services/pgn_game_import.dart:14`), variations and all |
| 5 | an import, saved without opening | `ImportChoiceSave` → `_saveImported` | yes, straight to the server |
| 6 | Analysis „Add this line to a tutorial…" | `_addToTutorial` → `appendStep` → `POST /lessons/:id/steps` (`APP/features/analysis_studio/screens/analysis_studio_screen.dart:1279`, `BE/routes/lessons.js:296`, one `step`) | yes, the anchor's subtree |
| 7 | Library „Add to tutorial" | `APP/features/library/screens/library_screen.dart:482` | no — a position and a sentence |
| 8 | „Add parts from a tutorial…", clone, „Insert a line here" | `TS/services/tutorial_parts_transfer.dart`, `TutorialSection.copy`, `splitForLine` | copies what the source holds |

The server stores a step's `pgn` as text and has no PGN reader, deliberately
(`CLAUDE.md`, rule 13): it cannot hold this rule, and must not grow a parser to.

**How parts join is already computed, from positions alone.** `partOpeningsOf`
(`tutorial_video.dart:134`) says of each part whether it opens on a new board
(`fresh`), on the position the film is already showing (`continues`), or on one
shown earlier (`returns`, naming the move that last arrived there — „Back to the
position after 18. Rfe1"). It finds the beat it returns to and throws it away.
The contents list has a second, weaker copy of the same question
(`_isJoined` / `_fenKey`, `TS/widgets/tutorial_sections_panel.dart:61`): it knows
„continues" and never „returns".

**Which part is open is hard to see.** A selected row differs by a background one
step lighter, bold text and an accent icon, and the list does not follow the
selection. In the owner's screenshot none of the three visible rows is marked
(sampled: identical background, icon and text colour) and the first carries the
link icon, drawn only from the second part on — the list had scrolled and the
open part was out of view.

**The header fields are narrow at every width.** Title, labels and language share
one row of the fixed 460 px pane (`_headerFields`, `tutorial_studio_screen.dart:1674`),
so the title field is about 155 px wide on any window; the owner's title shows as
„Broken Pawns a". On the phone, labels and language are already behind „More" →
„Details…" (`TS/screens/tutorial_studio_phone_layout.dart:55`).

**The room around the board.** The wide layout is the board pane (`Expanded`)
and the 460 px authoring pane (`tutorial_studio_screen.dart:905`). The board is
`min(width − 508, height − 120)`, so on a landscape window it is limited by
height: on the owner's window (1536 × 736 body) it is 616 and the pane beside it
is 1028, which leaves 412 px unused. `MoveNavigationControls` has a `centerLabel`
the studio passes as null.

## 3. The model on one page

```
  a PART is ONE LINE ─── a fork is two parts, never one
          │
          ▼
  the film: every part in order; a part opens on a new board, continues,
  or goes back to a position shown earlier („Back to the position after …")
          │                                   (partOpeningsOf — one home)
          ▼
  the MAP: rows in film order, lanes for how they join
     ▣  new board        │ continues (solid)        ┆ goes back (dashed)
     ◉  the part you are in, drawn by weight and shape, never by hue
```

The sketch's eight parts, which are also the map's fixture in phase 3:

| part | opens | lane | the row says |
|---|---|---|---|
| 1 | new board | 0 | `1 · new board` |
| 2 | continues 1 | 0 | `2 · continues` |
| 3 (open) | continues 2 | 0 | `3 · continues · you are here` |
| 4 | goes back into the middle of 3 | 1 | `4 · back to after 18. Rfe1` |
| 5 | goes back to the start of 3 | 0 | `5 · back to after 16... Nc4` |
| 6 | goes back to the start of 5 | 0 | `6 · back to after 16... Nc4` |
| 7 | continues 6 | 0 | `7 · continues` |
| 8 | new board | 0 | `8 · new board` |

## 4. Decisions — answered by the owner 25.9.2026: all as recommended

**D1. A second move inside a part starts a new part — right after the open one.**
Playing a move at a position that already continues, where the move is not one
of its continuations, leaves the open part exactly as it was and inserts a new
part after it: it opens on that position and its line is the move. The trainer
stands on the move in the new part, the board unchanged. In the film it is a
return („Back to the position after 18. Rfe1"). Nothing else moves; one undo
takes it back. *Other ways, not taken:* cut the part at the fork as „Insert a
line here" does; refuse the move.

**D2. Every other door splits a fork into parts, in the order „Insert a line
here" makes** — the part up to the fork, then the side line, then the original
continuation going back to the fork (the owner checked that order live on
12.9.2026, `[151.7]` in the archive). With several side lines at one fork, they
follow in the order they stand; each part is split again the same way until no
part forks. *Other way, not taken:* refuse an input with variations.

**D3. The map: rows in film order, lanes on the left** — top to bottom is the
film; the lanes are the tree. *Other way, not taken:* a free canvas like the
move tree, with pan and zoom and the order as a number on each card.

**D4. Nothing is done for tutorials that already fork — withdrawn by the owner.**
Recommended first was a notice on a part that already forks, with a button to
make its side lines parts. **The owner's word of 25.9.2026, after the plan was
committed: „Ne moraš ništa da prilagođavaš već postojećim tutorijalima"** —
nothing is adapted to existing tutorials. A part saved with a fork stays as it
is and films its main line, as it always has; the app is in testing and such a
tutorial may be deleted. So there is no notice, no button and no function for
it, and no test of one.

One follows from these and is the lead's, reversible in one line:

- **The title moves into the bar, labels and language behind „Details…"** — the
  sketch the owner answered. One dialog for both layouts: the phone's
  `_showDetails` moves out of the phone layout and both call it.

**What §8 of `PLAN-TUTORIJAL-VIDEO.md` asked, answered:**

1. *A card or a chain of moves?* A row per part: its number, how it opens, its
   name, its moves on one line. The moves stay in Flow, Tree and PGN.
2. *Where does a return's edge go?* To the part that last showed the position;
   the row names the move („back to after 18. Rfe1"), and that part's Flow
   shows „Part 4 starts here" on that move.
3. *Does the tree replace the list?* Yes: the rows are the list, in film order;
   the order is changed as today (↑ ↓).
4. *Dragging, and a recorded take?* Not in this plan (§7). Any reorder or new
   part already changes the film's signature, and the existing banner („Record
   again" / „Export without your voice") covers it.
5. *A phone at 360 dp?* The same widget in the Parts tab; a 44 px gutter and a
   row fit.

## 5. What goes, and what stays

**Goes:** `_isJoined` and `_fenKey` in the contents panel (the map reads
`partOpeningsOf`); the list rows of `TutorialSectionsPanel` (replaced by the
map); the three header fields on the desktop (title into the bar, the other two
into „Details…").

**Stays:** `filmBeatsOf`, `beatsOf`, the film's signature and the renderer —
unchanged; the film already says what the map draws. `splitForLine` and „Insert
a line here". The Tree tab (a part is a chain now; it still navigates, and still draws the
fork of a part saved before this plan). The stored shape of a step, and the server's ignorance of
PGN.

## 6. Phases, each with its gate

Baseline to re-measure in phase 0, in a worktree: app **4019** (1 skipped),
backend **1743** without a database / **1899** with, `flutter analyze` the same
**22** infos (`CLAUDE.md`, header). Each phase ends with its arithmetic in
`docs/LESSONS.md` and the block in `CLAUDE.md` updated.

### Phase 0 — the baseline and the fixtures [lead] — done 25.9.2026

Measured in a worktree at `3c607c45`, nothing else running: app **4019**
passed, 1 skipped (9 min 39 s); `flutter analyze` **22** infos, every one
`curly_braces_in_flow_control_structures`, no error or warning; backend
**1743** without a `.env` and **1899** against a throwaway cluster. The
fixtures are `T/support/tutorial_part_fixtures.dart`, held by
`T/tutorial_part_fixtures_test.dart` (5 cases, → **4024**), which also pins
§3's entries and labels to `partOpeningsOf` as it stands. Proved by mutation:
the nested side line removed turns the fork-shape and „every branch" cases
red; part 4 started on the wrong position turns the replay and the openings
cases red. The fixture test was red on its own first run for a real reason —
`19. Rfe1` in part 7, where the bishop on c1 leaves only one rook able to
reach e1, so the move is `Re1` and the reader refused it.


- Measure the three counts in a worktree, nothing else running.
- Write the shared fixtures: the owner's 12.9 example
  (`8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1`, `1. Ra1 Kc6 2. Ra6 Bb2 3. c3 Kb5`
  with `2. Ra8 Bb2` from after `Kc6`); the sketch's eight parts on the position
  of the owner's screenshot (`r1b2rk1/p3qppp/2p2n2/2ppP3/2nP1B2/2P3P1/P1Q2PBP/R4RK1 w - - 0 17`,
  lines as in §3 — every move legal, checked by the app's reader when the
  fixture is built); a tree with two forks on its main line, two side lines at
  one of them, and a fork inside a side line.
- **Gate:** the counts written here; the fixtures replay with
  `rejectedMoves == 0`.

### Phase 1 — a part is one line on the board [implementer] — done 25.9.2026

**Built inline by the lead, on branch `mapa-delova-faza-1`.**
`MoveOutcome.branched`, `TutorialDraftController._openPartFrom`, the notice in
`_onMove`. Gate `T/tutorial_one_line_test.dart` **14/14**, red on master for
the right reason (the film lacked `h6`). Full run **4040 passed, 1 skipped**
(4024 + 11 of the gate's first draft + 3 of the refusal below + 2 in the PGN
tab); `analyze` the same 22 infos.

The first full run had three reds, all settled:

1. `tutorial_studio_test` „a second move from the same position is a fork,
   and the strip asks which line" and
2. `tutorial_delete_move_test` „a sideline can be made the line the child
   walks" built their fork **by playing a second move**, which D1 replaces.
   Rewritten openly, the supersession written above each: the fork comes from
   a stored `pgn` with a variation, which the reader still makes (D4), so the
   strip's question and „promote" stay covered. Each is red when the side line
   is taken out of its fixture.
3. `tutorial_pgn_tab_test` „a move played on the board does not wipe unapplied
   text" — **a real finding.** The trainer types in the PGN tab without
   applying and plays `1. d4` where the part plays `1. e4`: D1 opens part 2, the
   field is rebuilt for it, and the text was gone without a word. **The owner's
   decision of 25.9.2026: such a move is held back** — „This move would start
   a new part. Apply or discard the text in the PGN tab first." — because
   carrying the text across would apply it to a part it was not written for.
   `playMove(..., mayOpenPart: false)` answers `MoveOutcome.heldBack` for that
   move and only that one; the panel reports whether it holds unapplied text
   (`onEdited`), and gained a **Discard** button, shown only while there is
   something to discard — without it, „clear the text" had no way to be done
   short of retyping the part. The old case was split in three: a move that
   grows the line keeps the text (its original point), a move that would open a
   part is held back with the board put back, and after Discard the same move
   opens a part. One more case in the gate: an Android tablet turned across the
   breakpoint swaps in the phone layout, which has no PGN tab, and the board
   stays — the panel says „nothing held" as it goes, or every later second move
   would be refused over text that no longer exists.

Mutations of the refusal, each red on the right case: the screen always
passing `mayOpenPart: true`; the controller ignoring the flag; the controller
holding back every move; no report when typing; none after Discard; none on
dispose; the board not put back. **The last one survived at first** — the
case called `onMove` without moving the piece on the board, so a board that
kept the move looked the same as one put back. The case now moves the piece on
the board's own controller first, as a drag does.

**Then every other way out of a part** — the owner's decision of 25.9.2026,
the same evening: the field is rebuilt whenever the open part's line is a
different one, so selecting another part, „New part", „Clone part", deleting
the open part or one before it, „Add parts from a tutorial…", „Insert a line
here", „Position setup" and Undo/Redo are all held back over unapplied text,
through one guard (`_heldForPgn`) — „That would open another part. Apply or
discard the text in the PGN tab first." Moving the open part and tapping it
again leave it open and are not held. Node ids are not stored, so Undo rebuilds
the part too. And **Ctrl+Z in the PGN field** had been the studio's undo — its
shortcuts sit nearer the fields than the text field's — so fixing a typo threw
the whole text away; over unapplied text the studio's shortcut now steps aside
(`_StudioHistoryAction.isEnabled`) and the key reaches the field. Twelve cases
in `tutorial_pgn_tab_test` (→ **4052**, a full run; analyze the same 22);
twelve mutations, one per guard and condition, each red on the right case.

- `playMove`: when the cursor has children and the move is not one of them, D1.
  The new part: root on the cursor's position, carrying its arrows and squares
  but not its sentence (the board reloads at a return, so the marks are drawn
  again — `splitForLine`'s rule for C); the part's orientation; inserted at
  `selected + 1`, selected, cursor on the move. Said after it is done, through
  `AppFeedback`: „18... h6 starts part 4. The film shows it after part 3."
- **Gate** (new file `T/tutorial_one_line_test.dart`, headless where it can be):
  - a second move at 18. Rfe1 leaves part 3's `treeSignature` unchanged,
    inserts exactly one part at `selected + 1` whose root fen is the fork's and
    whose only child is the move; `filmBeatsOf` now contains the move (**the
    film is the proof, not the tree**);
  - the same move as an existing child walks into it; a move at the end of the
    line extends the part; neither makes a part;
  - `partOpeningsOf` calls the new part `returns` with `afterMove` „18. Rfe1";
  - one undo gives back one part and the cursor where it was;
  - the new part carries the fork's arrows and squares and not its sentence;
  - mutations, each red on the right case: the new-part branch removed (the
    film loses the move); inserted at `selected` instead of `+ 1`; the fork's
    comment copied.
- **Phone:** the same controller; one case at 360 × 640 that the move makes a
  part and the Parts tab shows it.

### Phase 2 — every other door splits a fork [implementer; the route is the lead's] — done 26.9.2026

**Built inline by the lead, on branch `mapa-delova-faza-2`.** One function,
`splitAtForks` (`TS/services/section_split.dart`), and one door each:

- **2 and 3** — `openLineAsParts(draft, root)` beside it: the PGN tab's Apply
  (through `replaceLine`, which now answers how many parts it made — „Applied
  as 3 parts: every side line is a part of its own.") and **both** handover
  sites in the studio.
- **4 and 5** — `splitStepAtForks(step)`, called where an import's
  `positionList` is made: `readTutorialJson` (JSON files, and the tutorial
  from a game, which goes through it) and `tutorialFromGame` (PGN games). A
  step that does not fork keeps its text byte for byte; a step the reader
  cannot replay whole is left as it is, since its report already names what is
  wrong and splitting the reader's shorter tree would save it under a clean
  report. Problems are numbered where the parts will stand.
- **6** — `StudioLessonStep.partsFrom(anchor)` and `appendSteps`: one request
  with `steps: [...]`. The route (`BE/routes/lessons.js`) takes `step` or
  `steps`, not both; every step is built before anything is written, and the
  append was already one statement, so no transaction was needed for „whole or
  not at all".

**D2's order needed more than `splitForLine` applied again.** Its new line
holds every side line at the fork as a child, and cutting that part at its
own root puts the side lines after the continuation — reversed. `splitAtForks`
lays them out one part each (`_onePerSideLine`): the first keeps the
position's sentence, every one its marks.

Gate: `T/tutorial_split_at_forks_test.dart` (10), `T/tutorial_fork_doors_test.dart`
(12), `BE/test/lesson_steps_append.test.js` (4 + 2 on a real database).
Mutations: twelve in the app, three in the route, each red on the right case.
Two things the round found in the lead's own gate: no fixture put a sentence
or an arrow on a position with two side lines, so „the sentence once, the
marks on each" had nothing to fail on (a case was added); and a door case
that failed half way left its screen standing, so its neighbour went red
under a mutation that could not touch it — the cases now close through
`addTearDown` and mint their own lesson ids.

The plan's first description, kept for the record:


- One pure function, `splitAtForks(TutorialSection) → List<TutorialSection>`,
  D2's order. For a single fork it must equal `splitForLine` at that fork, and
  the gate holds it to that (one rule, two callers — rule 12).
- Doors 2 and 3: the controller gets one method that replaces the open part with
  a tree (`replaceLine` today) and splits it; the PGN tab and **both** handover
  sites call it.
- Doors 4 and 5: split where an imported tutorial's `position_list` is made, so
  „Open" and „Save" both get it — not in `TutorialDraft.fromLesson`, which also
  reads saved tutorials (D4: those are left as they are).
- Door 6: `POST /lessons/:id/steps` accepts `steps: [...]` beside `step`,
  appended in one transaction, the same checks per step; the app sends the
  split parts. **The route is the lead's** (no schema change, but it writes a
  tutorial's list, and a list written by several requests is left half-written
  by the first one that fails). Written in a worktree — nodemon watches every
  `.js`.
- Doors 7 and 8 unchanged: they copy what their source holds (D4).
- **Gate:** one test per door feeding the fork fixture and asserting no part of
  the result forks and the film contains every move once; the 12.9 example
  through the PGN tab gives the three parts `splitForLine` gives; the
  multi-fork fixture's parts come in D2's order; the route: an array is
  appended whole or not at all (a bad step in the middle leaves the list as it
  was, on the real-database half), and one step still works as before. **Grep
  the doors again before grading** — every `section.root =`, `replaceLine`,
  `fromLesson` and `appendStep` in `APP` — because a door the table missed is
  the ninth-file lesson.

### Phase 3 — the map [implementer] — done 26.9.2026

**Built inline by the lead, on branch `mapa-delova-faza-3`.** `partMapOf`
(`TS/services/tutorial_part_map.dart`) over `partOpeningsOf`, which now keeps
the stop it matched (`from`); `TutorialPartsMap` and `TutorialPartHeader`
(`TS/widgets/tutorial_parts_map.dart`); the chip in Flow (`partsStartingIn`).
The map replaces the rows of the contents panel and of the phone's Parts tab;
`_isJoined` and `_fenKey` are gone. Gate: `T/tutorial_part_map_test.dart` (11)
and `T/tutorial_parts_map_screen_test.dart` (5, the phone case measured in
Roboto). Full run **4091**, 1 skipped; analyze the same 22.

- **The lane rule is simpler than written above.** „No earlier edge uses the
  lane" needs no bookkeeping: an edge runs down its target's lane, so any later
  edge over the same rows passes that target's marker, which already holds the
  lane. The set built for it survived its mutation and was deleted.
- **The phone's Parts tab changed how its actions are reached** — the lead's
  call, reversible: Move up / down, Clone, Rename and Delete act on the open
  part from one row above the map, as on the desktop; they were under every
  row, which breaks every edge that crosses it. „Turn this part" stays on each
  row.
- **„New board" on a blank tutorial says „back to the start of part 1"**, since
  it opens on the opening position part 1 already showed — the film's own
  answer; the old list showed no link there and said nothing.
- **Seen, not only tested** (rendered with Roboto): at 360 × 640 every row
  reads whole. **At the owner's 1536 × 736 the contents panel shows two rows**,
  where the old 48 px rows fitted about three — a row now carries its number,
  its entry, its name and its moves in 68 px. Phase 4's column left of the
  board is the answer; phase 3 alone is a small step back at that window.
- Eleven mutations of the rest, each red on the right case.


- `partMapOf(TutorialDraft)` in `TS/services/`, pure: per part the entry
  (`fresh` / `continues` / `returns`), the part and **beat** it hangs from, the
  label, and its lane. It reads `partOpeningsOf`, which is extended to return
  the stop it matched (today it finds it and discards it) — the film reads
  nothing new.
- Lanes, the rule: a continuation takes its source's lane; a new board and a
  return take the lowest lane free from the source's row to their own, and a
  return into the **middle** of a part (neither its first nor its last beat)
  takes at least its source's lane + 1. That reproduces the sketch.
- `TutorialPartsMap`, the widget: a gutter painted from `partMapOf`, rows of
  number · entry · name · moves, the open row with a 2 px border, a filled ring
  and the words „you are here"; tapping selects; the list scrolls to the open
  part whenever the selection changes. It replaces the rows of
  `TutorialSectionsPanel` everywhere that panel is drawn (the wide pane today,
  the narrow desktop, the phone's Parts tab); the actions move in phase 4.
- Flow: a beat a later part returns to shows „Part N starts here · <move>",
  which opens that part. The part's own header line: „Part 3 of 8 · continues
  from part 2" / „· back to after 18. Rfe1 in part 3" (opens part 3) / „· new
  board".
- **Gate:**
  - `partMapOf` on the eight-part fixture gives exactly §3's table — entries,
    sources, labels, lanes;
  - properties, each a case: no returns → every lane 0; a continuation shares
    its source's lane; no edge passes a row's marker on the lane it uses; a
    return into the middle of a part is never left of it;
  - the two kinds of edge differ in the painter's **data** (dashed or solid)
    and the two markers in shape (square or circle) — asserted on what the
    painter is given, not on pixels;
  - a 30-part tutorial at 840 × 700: selecting part 27 by the strip brings its
    row into view (and the case fails on master, where nothing scrolls);
  - the Flow chip opens the part it names; the header's „in part 3" opens part 3;
  - 360 × 640: no overflow, and the kind line and the move line are not
    clipped — `didExceedMaxLines` where a line must be read, since clipping is
    not overflow;
  - `_isJoined` and `_fenKey` gone (a grep in the gate's report, not a test).

### Phase 4 — the screen and the title [lead writes the gate, implementer builds]

- The map gets a column left of the board **when the board keeps its size**:
  when the board pane minus the board is at least 380 + 16. Otherwise it stays
  where phase 3 put it. The board's own formula is unchanged.
- The right pane on the wide layout: the open part's header (number, how it
  joins, name with rename, ↑ ↓ clone turn delete), then Flow / Tree / PGN,
  taking the rest of the height.
- The strip under the board: `centerLabel` „Part 3 of 8".
- The bar: the tutorial's title, editable in place, replacing „Tutorial
  Studio"; under it „English · tactics, pawn structure · Details…", which opens
  the one Details dialog (moved out of the phone layout, both layouts calling
  it). The desktop's header row goes; the narrow desktop's stacked fields go
  the same way.
- **Gate:** widths **derived from the band**, not round numbers — the owner's
  1536 × 736 body (three columns, board 616, map 380), the smallest width that
  still gets the column and one pixel below it, 1366 × 768 and 900 × 700 (map
  in the pane); the board is the same size with and without the column at each
  of them; a 60-character title fully visible in the bar at 1536, measured with
  the real Windows font (rule 8 — print the family first); the Details dialog
  writes labels and language on both layouts (`tutorial_phone_details_test`
  keeps passing unchanged, which is the check that it is one dialog).
- **Expected churn, named before it happens:** fourteen test files reach the
  panel, the header fields or their keys (`tutorial_authoring`, `_delovi`,
  `_labels`, `_language_studio`, `_phone_details`, `_phone_layout`, `_raspored`,
  `_saved_version`, `_section_titles`, `_studio`, `_tok_edit`, `_tok`,
  `_tri_akcije`, `_undo`); `tutorial_raspored_test`'s 840 dp measurements are
  about a pane this phase rebuilds and are rewritten openly, with the
  supersession written above them. Grep the shared helpers under `T/support/`
  and the keys `tutorial-title`, `tutorial-labels`, `tutorial-language`,
  `sections-half`, `editor-half`, `authoring-pane`, `add-show` — not only the
  widget's name.

### Phase 5 — the words [lead]

- `site/mislisha/manual/write-a-tutorial.html` quotes „Tutorial title" (twice)
  and „New demonstration": rewritten for the bar, the map and D1, and
  `manual_labels_test` run.
- `docs/UPUTSTVO-STUDIO.md` (Serbian), the glossary if a new term is used
  („map" is not — the screen says „Parts"), `STANJE-RADA.md`, and
  `TODO-provera.md` items from `[247.1]` under `Teach` → `Tutorial studio`, in
  the five-line form.

### Phase 6 — the owner's live pass [owner]

The ones that matter most: in a new tutorial on the position of 25.9, 18... h6
played beside 18... cxd4 makes part 4, and the exported film shows 18... h6
19. Rxe5 after „Back to the position after 18. Rfe1";
a PGN with variations imported and filmed; the map on his window and on the
phone; the title whole in the bar.

## 7. Not in this plan

- **Dragging parts in the map.** ↑ ↓ stay the way to reorder.
- **One move tree of the whole tutorial** (every part's moves in one Tree, the
  parts as stretches of it). The map shows the joins; this would show the chess.
  Asked for if missed.
- **Anything for tutorials saved with a fork** — D4, the owner's word.
- **The rule on the server.** It has no PGN reader and must not get one
  (rule 13); the app holds the rule at every door, and the table in §2 is
  re-grepped in phase 2.
- **The per-move main/side fill in Tree** for a colourblind reader: with one
  line per part it only remains on parts saved with a fork before this plan.
