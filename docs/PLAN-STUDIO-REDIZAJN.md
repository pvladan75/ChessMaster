# Plan: one room for writing a tutorial

Written 6.9.2026 by the lead, after the owner tested the studio built by phases
4a–4c of `docs/PLAN-TUTORIJAL.md`. It supersedes nothing in that plan: the step
model, the viewer, the backend and the vocabulary all stay exactly as they are.
What it replaces is the **authoring surface** — two screens become one.

Read `docs/PLAN-TUTORIJAL.md` first; this file assumes its decisions 1–5 and its
frozen contracts C1–C4 and does not restate them.

## 1. What is actually wrong, in the code

The four complaints are real and three of them have a single cause. Named
precisely, so a batch fixes the fault rather than the symptom:

**1.1 Entering from the Analysis Studio inherits stale state.** Not a feeling —
a line. `TutorialStudioScreen._restoreDraft()`
(`tutorial_studio_screen.dart:150`) loads the one stored draft slot
**unconditionally**, and the handover overrides only the *tree*: the title and
every committed example come back whatever the trainer asked for. There is one
slot, it has no identity, and nothing asks the trainer whether they wanted it.
So „Kreiraj interaktivni tutorijal" on a fresh line opens last week's tutorial
with a new board in front of it.

**1.2 Two screens, and they do not share a single line of code.** They do not
even share a model:

| | `TutorialStudioScreen` (613 lines) | `LessonStepEditorPanel` (694 lines) |
|---|---|---|
| holds | `AnalysisNode` tree + `List<TutorialExample>` | `List<Map<String, dynamic>>` of raw step JSON |
| board | full, with arrows and drawing wired | 300 px still board, `arrows: const []` |
| line | a real tree, navigable | none — it cannot see or edit a `pgn` |
| writes | `POST /lessons/save`, once, at the end | `PUT /lessons/:id`, per press |
| can add sections | yes | yes (batch 55) |
| can reopen a section's tree | **no** | **no** |

The last row is the actual wall. `_commitExample`
(`tutorial_studio_screen.dart:400`) flattens a finished example to `fen` +
`pgn` and drops the tree. Nothing in the app reads a `pgn` back into an
`AnalysisNode`, so a committed example can never be reopened — which is
precisely why a second screen had to exist, and why that screen cannot show the
line. **Eliminating the second screen is therefore not a UI task. It is one
missing converter.**

**1.3 No sense of chronology.** The studio shows the author a *tree* and the
child experiences a *walk*. Both are true; only one of them is what is being
written.

**1.4 The tree panel is cramped and technical.** Downstream of 1.3 — the tree is
in the only slot there is, so it has to be both the navigation control and the
overview, and it is a poor overview.

## 2. The root cause, in one sentence

**A finished section loses its tree, so authoring and editing cannot be the same
screen, and the author is shown the writer's data structure instead of the
reader's experience.**

Everything below follows from fixing those two halves: keep the tree, and
project it as a walk.

## 3. Decisions to freeze

**All of them were approved by the owner on 6.9.2026, D6, D7 and D9 explicitly.
They are frozen; a batch does not reopen one.**

### D1 — a section keeps its tree; `pgn` becomes derived

`TutorialExample` becomes `TutorialSection` and holds `AnalysisNode root`
instead of `String pgn`. The `pgn` is computed at save time by
`StudioLessonStep.from(section.root)`, which is already the one place where
`fen` and `pgn` are made to answer for the same node, and which already reads
its own work back through `LessonStepLine` and refuses a line that does not
replay. Nothing about the wire format changes.

*Why not keep both:* two representations of one line is the exact fault this
codebase has paid for twice (`AnalysisNode` vs `MoveTree` arrows; two PGN
parsers). The tree is the writable one; the PGN is the export.

### D2 — reopening reads through `LessonStepLine`, never through `_importPgn`

The converter is `MoveTree → AnalysisNode`, roughly twenty-five lines, because
the two node types are already near-isomorphic (`san`, `fen`, `comment`,
`arrows`, `squares`, `children`).

**`AnalysisStudioScreen._importPgn` must not be reused and must not be copied.**
It goes through `chess.load_pgn` and `getHistory()`, which keeps the main line
only and throws away every comment, every `[%cal]`, every `[%csl]` and every
variation. A trainer reopening a tutorial through it would silently lose the
words and the arrows they wrote — the recurring bug of this repository, in its
most expensive form yet.

`LessonStepLine.read(fen:, pgn:)` already returns the `MoveTree` (contract C2
added the field) with comments, arrows, squares and sidelines intact, and it
already counts `rejectedMoves`. It is the reader the child uses. Using the same
one on the author's side means a section that reopens wrong is a section the
child was already getting wrong.

### D3 — a section carries its server `id` round trip

`TutorialSection` gains `String? stepId`, and `toJson()` emits `'id': stepId`
when it is not null. This is the single most dangerous line in the whole
redesign and it must be written first, with its test.

`assignment_items.step_key` and `review_items.step_key` name a step by that id
and **nothing joins on it**. A studio that saves an edited tutorial without
carrying ids orphans every child's schedule and every recorded answer, with no
error anywhere. The backend's 409 guard (`routes/lessons.js:118-129`) fires only
when the stored and sent lists are the same length — so the moment the trainer
adds or removes a section, which is the whole point of this screen, **the guard
cannot fire and the app is the only thing there.** Same position batch 55 was in;
same conclusion.

### D4 — the draft slot has an identity, and restore is offered, never silent

`TutorialDraftService` stores `lessonId` (null for a tutorial that has never
been saved) beside the draft. The screen is opened with an explicit intent:

```dart
sealed class TutorialEntry {
  const factory TutorialEntry.blank(String title)                = _Blank;
  const factory TutorialEntry.saved(Map<String, dynamic> lesson)  = _Saved;
  const factory TutorialEntry.fromAnalysis(TutorialHandover h)    = _FromAnalysis;
}
```

* `blank` — the stored draft is **not** loaded. If one exists and is not empty,
  a dialog says so by name („Imate nezavršen tutorijal „X" — nastavi ili
  odbaci?"). Silence is what makes it feel haunted.
* `saved` — the draft is hydrated from the lesson. A stored draft is restored
  only when its `lessonId` matches; anything else is a different tutorial.
* `fromAnalysis` — the handover **appends a section** to the open draft, or
  starts a blank one, and the Studio asks which. It stops being a way to *open*
  the screen and becomes a way to *send a line into* it, which is what the door
  was always for.

That is complaint 1.1, closed at its cause.

### D5 — the timeline is a projection, computed by one pure function

```dart
/// The beats of the line the author is standing on, in the order the child
/// meets them.
List<TutorialBeat> beatsOf(AnalysisNode root, AnalysisNode current);
```

No widget needed to test it, which is what makes the gate cheap and the panel
replaceable. The panel renders beats; it owns no model.

### D6 — the timeline replaces the tree *as the default view*, not as the only one

Bottom-right becomes a two-tab panel: **„Tok"** (the timeline, default) and
**„Stablo"** (`AnalysisMoveTreeWidget`, unchanged). Two views of one
`AnalysisNode`, so they cannot disagree.

*Why not delete the tree:* a fork is a tree-shaped thing, promoting a sideline
to the main line is a tree operation, and the existing widget already does both
and is tested. Removing a working control while introducing an unproven one puts
two risks in one batch.

**Approved 6.9.2026: both tabs stay**, „Tok" as the default and „Stablo" as the
alternative for a tutorial with real branching.

### D7 — one noun for one thing: „deo"

The trainer's UI currently says „Primer N" in the studio and „Korak N" in the
editor for the same object, and the owner's sketch says „sekcija". Three words,
one row in `position_list`. Recommendation: **„Deo"** in every authoring
surface, „korak" retired from the trainer's screens (it stays in code, on the
wire and in the database — the word changes for the reader, never for the
schema, exactly as `PLAN-TUTORIJAL.md` froze it).

Goes in `docs/TABELA-TUTORIJAL.md` as new rows and is enforced by
`test/tutorial_vocabulary_test.dart`, which is the file that keeps this kind of
change from coming back one careless string at a time.

**Approved 6.9.2026.** It lands with the screen in P5, not before: P1 and P2 are
model work, and moving a user-facing string inside them would have destroyed the
one proof that the flow survived — `tutorial_authoring_test.dart` reads those
strings.

### D8 — `LessonStepEditorPanel` is unlinked on Windows, kept on Android

The studio is Windows-only by decision 5 of `PLAN-TUTORIJAL.md`. The old panel
is reachable from the library list and from the room on **every** platform, so
deleting it removes tutorial editing from Android altogether — a capability
loss nobody asked for, dressed up as tidying.

So: on Windows, „Uredi" opens the studio and the panel is never drawn; on
Android it stays, frozen, no new features. The double work the owner met is a
desktop problem and it disappears completely on the desktop.

Deleting it outright is a clean follow-up once the owner decides that authoring
is desktop-only — one line in one predicate, which is why that predicate has
exactly one home.

### D9 — Is „+ Dodaj deo" still anchored to the end of the previous line?

Today the next example starts on the position the last line ended at, because
that is what makes show → ask one board with no reset in the viewer
(`_nextStepContinuesHere`). With sections that can be reordered and reopened,
that rule can no longer be an invisible side effect of the button.

Recommendation: the button offers both, with the anchored one first —
„Nastavi odavde (dete ne vidi novu tablu)" / „Nova pozicija". And the section
list draws a small join mark between two sections that stand on one position, so
the author can *see* which of their sections the child will experience as one
continuous board.

**Approved 6.9.2026**, exactly as recommended: „Nastavi odavde (dete ne vidi novu
tablu)" first and default, „Nova pozicija" beside it, and the join mark in the
list. `TutorialDraft.addSection(continueFromEnd:)` already takes both answers
(P1); the two buttons are P5.

## 4. The data model

One file, `lib/features/tutorial_studio/models/tutorial_draft.dart`, rewritten.

```dart
/// One part of a tutorial. Exactly one `position_list` entry, and exactly one
/// row in the top-right panel.
class TutorialSection {
  final String localId;      // stable key for the list and the controllers;
                             // never sent, never confused with stepId
  String? stepId;            // the server's id. Null until saved. D3.
  String title;              // „Deo 1", or whatever the trainer typed

  AnalysisNode root;         // the tree. D1.
  AnalysisNode cursor;       // where the author is standing inside this section
  bool blackOrientation;

  LessonStepKind kind;
  String? instruction;
  List<TutorialChoice> choices;   // {text, correct} — the server's own shape
  String? solutionSan;
}

class TutorialDraft {
  int? lessonId;             // null = never saved. D4.
  String title;
  List<TutorialSection> sections;
  int selected;
  bool dirty;
}
```

`TutorialChoice` replaces the `List<String> choices` + `int? correctChoice`
pair. That pair exists because contract C4 froze the student's shape and the
author's was bolted on afterwards; one list of `{text, correct}` is the server's
own shape and removes the index arithmetic that `_choiceControllers` currently
does by hand on every delete.

### The controller

```dart
class TutorialDraftController extends ChangeNotifier {
  TutorialDraft get draft;
  TutorialSection get section;          // the selected one

  // sections
  void addSection({required bool continueFromEnd});
  void removeSection(int i);
  void moveSection(int from, int to);
  void cloneSection(int i);
  void select(int i);

  // the line of the selected section
  void playMove(String from, String to, String promotion);
  void jumpTo(AnalysisNode node);
  void setComment(String text);         // on the node, not on the section
  void toggleArrow(String from, String to, String colour);
  void toggleSquare(String square, String colour);
  void clearMarks();

  // the question of the selected section
  void setKind(LessonStepKind k);       // may refuse — see §7
  void setInstruction(String text);

  Future<String?> commit(LessonApiService api);   // POST or PUT. §6.
}
```

Plain `ChangeNotifier`, no DI package — this project does not use one, and a
`ChangeNotifier` behind an `AnimatedBuilder` is the smallest thing that lets
three panels read and write one draft. **The point of the seam is that most of
the gate runs with no widget tree at all**: build a two-section tutorial, assert
the `positionList`, never pump a frame.

**Rule, from the `_kindEpoch` bug (`lesson_step_editor_panel.dart:47`): the
draft is the single source of truth and text controllers are rebuilt from it.**
Every editing field lives under
`KeyedSubtree(key: ValueKey('${section.localId}/${node.id}'))`, so changing the
selection tears the fields down and builds them from the model again. A
`DropdownButtonFormField` that keeps a value the model refused is how a trainer
comes to believe they asked a question they did not ask.

## 5. The screen

```
TutorialStudioScreen
└ Scaffold
  ├ AppBar ─ „Studio za tutorijal" · [naziv tutorijala] · ● nesačuvano
  │          actions: [Unos pozicije] [Pregledaj kao učenik] [Sačuvaj]
  └ AnimatedBuilder(controller)
    └ LayoutBuilder                       // < Breakpoints.wide → §5.4
      └ Row
        ├ Expanded(flex: 3)  _BoardPane
        │   ├ BoardWithCoordinates → ChessBoardWithOverlay
        │   │     arrows:  section.cursor.arrows
        │   │     squares: section.cursor.squares
        │   │     isDrawingMode: _drawMode != null
        │   ├ _AnnotationBar   ← ✏ strelica · ▣ polje · 🎨 boja · ✕ obriši
        │   └ MoveNavigationControls(cursor: AnalysisNodeCursor(...))
        └ SizedBox(width: 460)  _AuthoringPane
          ├ Expanded(flex: 2)  _SectionsPanel     „Delovi tutorijala"
          │   ├ toolbar: [+ Dodaj deo] [▲] [▼] [⧉] [🗑]
          │   └ ListView of _SectionTile
          │        „1. Uvod"  ·  kind chip  ·  ⛓ join mark (D9)
          ├ Divider (draggable)
          └ Expanded(flex: 3)  _TimelinePanel     „Deo 2 — tok"
              ├ TabBar: [Tok] [Stablo]            ← D6
              ├ Tok    → ListView of _BeatCard    ← §5.2
              └ Stablo → AnalysisMoveTreeWidget(unchanged)
```

### 5.1 Why these proportions

A 1920 px window leaves the board ~600 px at flex 3 against a fixed 460 px
column — a real demonstration board, which is the thing the trainer looks at
most. The right column is **fixed**, not proportional: text fields that grow
with the window are harder to read, not easier, and a fixed column means the
board is the only thing that changes size.

The sections panel is deliberately the *smaller* half. It is a table of
contents; the work happens in the timeline.

### 5.2 What a beat is

Derived from the viewer's own narration loop
(`lesson_viewer_screen.dart:403-473`), which is the definition of what the child
experiences. At node N the viewer draws N's marks, speaks N's comment, and
*then* plays the move to N's child.

**So the sketch's order needs one correction, and it matters: the arrow is not
after the move, it is shown together with the sentence, before the move that
leaves the position.** A panel that drew it the other way would be teaching the
author something false about their own tutorial.

One beat = one node:

```
┌ 3 ─ posle 2...Nf6 ─────────────────────────────────┐
│ 🗣  „Vidi kako crni napada pešaka na e4…"       ✎  │
│ ✏   →e4 crvena · ▣ d5 zelena                   +✕ │
│ ♙   pa se igra:  3.Nc3                          →  │
└────────────────────────────────────────────────────┘
```

* the beat's header is the move that **arrived** at this position, so the row
  reads as a place;
* 🗣 is `node.comment`, edited in place;
* ✏ is `node.arrows` + `node.squares`, added by pressing `+` and then drawing on
  the board — **the row is the target, the board is the tool**, which is why the
  drawing controls sit under the board and not in this panel;
* ♙ is the move out of this node. At a fork it is a row of chips
  („3.Nc3" / „3.Bc4"), the shown line in bold, and pressing one re-projects the
  timeline down that branch — the author's mirror of the branch sheet the child
  already gets;
* the last beat carries no move, and under it sits the **question card**: kind,
  „Zadatak za učenika", the offered answers or the recorded correct move.

Clicking any beat calls `jumpTo` and the board follows. That is the whole
contract of the panel.

### 5.3 Where the existing widgets are reused, verbatim

`BoardWithCoordinates`, `ChessBoardWithOverlay`, `AnalysisNodeCursor`,
`MoveNavigationControls`, `MoveKeyboardShortcuts`, `AnalysisMoveTreeWidget`,
`AnalysisBoardSetupDialog`, `StudioLessonStep`, `LessonStepLine`, `playedMove`,
`LessonViewerScreen` + `PreviewAssignmentApiService` (for „Pregledaj kao
učenik", which today is buried in the panel being retired and is the fastest
answer to „does this feel right").

**A copy of any of that plumbing in the new screen is a finding, not a detail.**
`test/tutorial_studio_test.dart` already fails on a second board, tree or cursor
and that test stays.

The one genuinely new mechanism is arrow and square drawing on this screen. The
room already has the interaction (`chess_game_screen.dart:713-752`:
tap-tap-to-draw, redraw-to-erase, colour from a selector) and it is private.
**Extract it once**, as `BoardAnnotationController` in
`lib/widgets/game_screen/`, and have both screens drive it — a sixth private
copy of a helper is how `playedMove` came to be needed in the first place.

### 5.4 Narrow windows

Below `Breakpoints.wide` the screen stays as it is today: board on top, the
authoring column under it, scrolled. It is Windows-only and a narrow Windows
window is a resized one, not a phone — it must not be broken, it does not have
to be good. No `Row` may exceed the width: a release build clips in silence.

## 6. Saving

```
draft.lessonId == null  →  POST /lessons/save   →  201, body = the row
draft.lessonId != null  →  PUT  /lessons/:id    →  200, body = the row
```

Both routes already answer with `RETURNING *`, so the response carries
`position_list` **with the ids the server minted**. `LessonApiService.save` and
`.update` currently throw that body away and answer `String?`.

*Change:* both gain a result type carrying `id` and the stored steps, with the
error still in the server's own words. `clone` already sets `cloneError` for
exactly this reason, so the precedent is in the file.

*Why it matters:* after the first save the draft must learn `lessonId` and every
`stepId`, or the trainer's second press of „Sačuvaj" creates a **second
tutorial**, and their third creates a third. That is the difference between one
save button and one save button that works twice.

## 7. What must not be lost

Retiring `LessonStepEditorPanel` retires things that were paid for. Each one is
a line in the gate:

1. **The answer-leak refusal.** „`ask_move` + a line = the child can page to the
   answer with „Sledeći potez"" — `_leaksAnswer`, `_chooseKind`,
   `_buildAnswerLeakWarning`. This is the single refusal the app makes on its
   own, because the server stores `pgn` as opaque text and has no PGN reader.
   It must exist in the new screen **before** the old one is unlinked, in all
   three of its parts: the question when the kind is chosen, the banner on a
   tutorial that is already in that state, and the refusal at save.
2. **Reopening an old tutorial finds old faults.** Tutorials already saved may
   carry the leak. The hydration path must run `_leaksAnswer` over every section
   as it loads and mark the offenders in the section list.
3. **The dropdown that reverts.** `_kindEpoch` — §4's rebuild rule.
4. **The last section cannot be removed.** `PUT` writes `position_list = NULL`
   for an empty list; a tutorial emptied here loses its steps with nothing left
   to join on and complain.
5. **A new section carries no `id`** and inherits only the position it was added
   from.
6. **`ask_choice` needs two to four answers, exactly one correct** — refused in
   the app, in its own sentence, before anything is sent. Left open by batch 54
   and it belongs here.

## 8. Phases

Backend: **untouched**. Viewer: **untouched**. Android: **untouched**. Every
task file says so.

Baselines to *measure*, not to quote: 1436 app tests with 1 skipped, 956 on the
backend with `.env` moved aside, `flutter analyze` 29 infos and no errors or
warnings — and nothing newly suppressed.

| # | what | who | why there |
|---|---|---|---|
| **P0** | This document's decisions frozen; the gate for P1–P2 written and proved by mutation | lead | a batch with no gate written for it grades itself |
| **P1** | `MoveTree → AnalysisNode` converter; `TutorialSection` with a tree; `TutorialChoice`; `stepId` round trip | **lead** | D2 and D3 are the two places a trainer's work or a child's schedule can be destroyed silently. No UI. ~250 lines, headless tests |
| **P2** | Hydration: `TutorialDraft.fromLesson()`, and the round-trip test | **lead** | the whole safety story is one assertion: load a saved tutorial, change nothing, save — `positionList` byte-identical, **ids included** |
| **P3** | `LessonApiService` write results (§6); the draft slot gains identity; `TutorialEntry`; the „unfinished draft" prompt | worker, mechanical | closes 1.1. Bounded, list-shaped brief — the `flash-high` comparison batch |
| **P4** | Biblioteka card: „Novi tutorijal" / „Otvori sačuvani tutorijal", both behind `isTutorialStudioAvailable`; the Analysis door demoted to „send this line into the studio" | worker, mechanical | pure UI, no model |
| **P5** | The split-view shell: board pane, sections panel with add/remove/reorder/clone, the tree tab where it is today | worker, high-reasoning | layout; reuses batch 55's semantics wholesale |
| **P6** | The timeline: `beatsOf`, `_BeatCard`, fork chips, inline editing of comment and question | **lead writes `beatsOf` + its gate; worker builds the panel** | the pure function is the contract; the widget is replaceable |
| **P7** | `BoardAnnotationController` extracted from the room; the annotation bar; marks written onto the node | worker | one extraction, two call sites |
| **P8** | The four refusals of §7 live in the studio; „Pregledaj kao učenik"; `LessonStepEditorPanel` unlinked on Windows (D8) | **lead** | nothing is unlinked until its refusals are proved somewhere else |
| **P9** | Docs: `STANJE-RADA.md`, `TODO-provera.md` live-check items, `CLAUDE.md` counts, `TABELA-TUTORIJAL.md` rows for D7 | lead | as part of the work, not afterwards |

**Order.** P1 → P2 are serial and are the lead's. P3 and P4 can run in parallel
with each other and with P5 once P2 lands. P6 needs P5. P7 is independent of
everything after P1 and can run any time. P8 is last by definition.

**P1 and P2 are the batch that matters.** After them, „one screen" is a layout
job. Before them, it is impossible.

### The gate, in outline

Written before P1 starts, proved by mutation:

1. a section built in the studio, saved, reloaded and reopened comes back with
   **its comments, its arrows, its squares and its sidelines** — mutation:
   route the reopen through `chess.load_pgn` and watch it go red;
2. a saved tutorial loaded and re-saved unchanged produces a byte-identical
   `positionList`, **ids included** — mutation: drop `'id'` from `toJson`;
3. adding a section in the middle keeps every other section's id;
4. `beatsOf` on a line with a fork returns the beats of the line being stood on,
   and names the branches at the fork;
5. an `ask_move` section carrying a line is refused at save, flagged in the
   panel, and flagged on load — three separate assertions;
6. the last section cannot be removed;
7. a second „Sačuvaj" updates rather than creating a second tutorial;
8. no board, tree-widget or cursor code copied into the new panels
   (`tutorial_studio_test.dart`'s existing check, extended to the new files);
9. `test/lesson_editor_test.dart`, `test/lesson_answer_stays_hidden_test.dart`,
   `test/lesson_step_order_test.dart`, `test/tutorial_authoring_test.dart` and
   `test/lesson_viewer_line_test.dart` pass **unedited**.

Point 9 is the real gate. The others can be satisfied by a rewrite that breaks
the flow; only that one says the flow survived.

### P0–P2 — done 6.9.2026, by the lead

The gate was written first, in `docs/gates/`, and moved to
`chess_app/test/tutorial_section_test.dart` when the work landed — the staging
copy is deleted rather than kept, the way the vocabulary, branching, authoring
and step-order gates were handled, so there is never a second copy to keep in
step. Twenty-two
tests, none of which builds a widget: the model is the contract, and a gate that
has to pump frames to read it is a gate that gets edited the first time the
layout moves.

**Proved by seven mutations, all seven caught** — sidelines dropped on read (the
`_importPgn` shape), the step id stopped travelling, `acceptedSans` dropped, an
untouched line re-exported anyway, a clone sharing its tree instead of copying
it, the last section made removable, and the trainer's sentences dropped on read.

What landed: `lib/features/tutorial_studio/services/step_tree.dart` (the
converter, `treeSignature`, `copyTree`, `endOfMainLine`), a rewritten
`tutorial_draft.dart` (`TutorialChoice`, `TutorialSection`, `TutorialDraft` with
`lessonId`, `selected`, and add / remove / move / clone), a
`TutorialDraftService` that stores one object instead of a draft beside a working
tree, and the screen translated onto the new model with **not one user-facing
string moved**.

Four things the work settled that the plan had left to be discovered:

1. **A byte-identical round trip is impossible if the `pgn` is always
   re-exported.** `PgnExporterService` stamps a fresh `[Date]` header on every
   call. So an untouched section is written back as the exact text it was read
   from, and the cache is invalidated by comparing [treeSignature] against the
   tree itself rather than by a flag somebody has to remember to set. A flag is
   the version of this that fails silently.
2. **`acceptedSans` had to join the model.** The server stores the other moves
   that are also right, and nothing in the app carried them — so a round trip
   would have deleted them the first time a trainer renamed a tutorial. Found by
   writing the byte-identical test, which is exactly what it is for.
3. **`pgn` is omitted rather than sent as `''`.** The two are the same thing to
   `buildLessonStep`, which reads `if (pgn) entry.pgn = pgn` — but only absence
   lets a step that was stored without a line come back without one. This
   sharpens batch 54's correction rather than reversing it.
4. **The authoring gate needed one edit, and it is a widening — declared here
   because „passes unedited" was the lead's own bar.** Its source-reading test
   asserted that `tutorial_studio_screen.dart` mentions `StudioLessonStep`; P1
   moved that call one layer down into `TutorialSection`, where the fen/pgn
   pairing now lives. The test reads the whole feature directory instead, and
   asks about **imports** rather than identifiers — a bare `contains` over a
   directory also matches a doc comment, so a comment explaining why the
   exporter is *not* called here would have failed it. Every other assertion in
   that file, and every one of its 47 tests, is unchanged and green.

`test/tutorial_studio_test.dart` also changed, in one group of four tests: they
construct the model directly, and the constructor is what P1 replaced. **Their
assertions are byte-for-byte the ones they had** — what moved is the call, not
the wire shape they pin.

**Measured on `master`, with nothing else running: 1458 app tests, 1 skipped,
all green** (1436 before, so the 22 are the gate and nothing regressed);
`flutter analyze` still 29 infos, no errors, no warnings, and **nothing newly
suppressed**; the backend untouched at 956. Measure the suite alone —
`test/opening_book_service_test.dart` takes ~20 s to load the ECO dataset and
times out under parallel load, which cost two false failures here.

*Still open before P3:* `LessonApiService.save` and `.update` still throw the
saved row away, so nothing yet learns `lessonId` or the server's step ids. Until
that lands, `TutorialDraft.lessonId` is written by `fromLesson` and read by
nobody, and the screen still only ever creates.

## 9. What this plan does not do

* It does not touch `chess_backend/`. Nothing here needs it.
* It does not touch `LessonViewerScreen`. The child's screen is finished.
* It does not add drag-and-drop reordering. Up/down was chosen in batch 55 for a
  reason that still holds; drag is a separate, later decision.
* It does not make the studio available on Android, and it does not remove
  anything from Android.
* It does not rename a column, an API field or a Dart identifier. D7 is a word
  the reader sees.
