# Brief — Preparation, phase 6: several sentences on one position

`docs/PLAN-PRIPREMA.md` — read §4's **D4**, **D12**, **D13** and **D16**, and
phase 6 under §6 whole: its table of every reader, writer and copier is your
map. The sketch the owner accepted is `docs/skice/taktovi.html` (`?f=desk`,
`?f=more`).

A position may hold several **beats** — a sentence and the marks that stand
while it is said. The owner calls them sentences; the code calls them beats.
Today a position holds one, and a second comment in a PGN silently replaces
the first.

**Work only in this worktree**:
`D:\Projekti\chess_master\.claude\worktrees\priprema-faza-6` (branch
`priprema-faza-6`). App commands run from its `chess_app/`, server commands
from its `chess_backend/`. Touch nothing in `D:\Projekti\chess_master` itself,
commit nothing, push nothing. `pub get` has been run. **Never start the
server** and never `require('./server.js')`; this worktree has no `.env`,
which is the environment CI has.

Baseline on `master` at `9baeeac9`: **4335 passed, 1 skipped**; `flutter
analyze` the **22** known infos (all `curly_braces_in_flow_control_structures`);
backend **1778** without a database. Measured on `2f5753d1` on 27.9.2026; the
one commit since touches only `tools/`, `docs/` and `.env.example`.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately. **And when a test's own timing or helper is
what stands in your way, say that — do not change what a screen does for a
person in order to fit it.**

## What is already in this worktree, and is the lead's

Uncommitted, and **not yours to edit** except to report a fault:

| file | cases | what it holds |
|---|---|---|
| `chess_app/test/core/node_beats_test.dart` | 420 | the model, both PGN writers and the reader, the saved tree's JSON, the copiers, 400 random trees through every door, a source guard |
| `chess_app/test/tutorial_beats_film_test.dart` | 13 | `beatsOf`, the film's stops and events, where a part opens, the map of the parts, a tutorial written out as one game, the film's signature |
| `chess_app/test/sentence_editor_test.dart` | 22 | the editor: the Tutorial Studio, the phone, Preparation's comment box |
| `chess_app/test/preparation_recording_test.dart` | +1 | „another sentence opened is a change of the marks", the last case of group „the timeline" |
| `chess_backend/test/film_beat_event.test.js` | 5 | `applyEvent` for an event of kind `beat` |

**Each file's head comment is its frozen contract** — class and method names,
keys, words on the screen. Read all four heads before writing anything.

What was proved before you got them: the three Dart files fail to compile on
the contract's names and nothing else; every literal in them was taken from a
run on `master`; the random-tree harness passes all 400 seeds on `master` with
one beat to a position; the editor gate's helpers open the studio on a desktop
and a phone, save and read back, and step Preparation, all green on `master`;
the recording case runs on `master` and is red exactly at the missing
`prep-add-sentence`; the server's file is 4 green, 1 red — the one it is for.
**None of it has been watched going green.** Where a case cannot pass, that is
a fault of the gate and the report's first section.

## The pass condition

```
flutter test test/core/node_beats_test.dart test/tutorial_beats_film_test.dart test/sentence_editor_test.dart test/preparation_recording_test.dart
node --test test/film_beat_event.test.js
```

all green, **and** the full app suite at **4335 + 456 = 4791 passed, 1
skipped** plus the cases you add (say how many, by file), **and** `npm test`
in `chess_backend/` at **1778 + 5 = 1783**, **and** `flutter analyze` with the
same 22 infos and nothing new, no `// ignore` added. Run `dart format` on
every Dart file you touch.

No existing test is deleted, skipped or weakened. Where one goes red because a
rule of this phase changed what it held — see „T3" below — rewrite it
**openly**: a comment above it saying which rule superseded what, and the
file and name in the report. Before rewriting one, ask what it was protecting,
and keep that.

## What is built

### 1. The model (`node_beats_test.dart`)

`NodeBeat` beside `ChessArrow` in `lib/move_tree.dart`; `beats` on both
`MoveNode` and `AnalysisNode`, never empty; `comment`, `arrows`, `squares`
read and write **the first**, so every screen that knows nothing of beats
works on the first and cannot flatten the rest. `addBeat({after, keepMarks})`,
`removeBeatAt`, `lastBeat`, `AnalysisNode.rootLike(node, {keepWords})`.

- **T3, changed by this phase**: a reader that knows nothing of beats sees
  the first sentence, not the sentences joined. Say in the report every test
  that held the old reading.
- In a PGN, a node's beats are successive comments on its move; a comment
  that holds only a command (a clock) is not a beat; an **empty beat is not
  written**; the clock is written once. **A tree with one beat to a position
  is written byte for byte as today**, in the PGN, in the saved JSON and in
  both signatures — every stored tutorial and every narration already
  recorded depends on it.
- The source guard names the five places on `master` that build a node from
  another node's marks. Each becomes `copyOf` / `copyTree` / `rootLike`.

### 2. The film (`tutorial_beats_film_test.dart`)

`beatsOf` gives one stop per beat (`at`, `of`, `say`, `currentAt`);
`filmBeatsOf` one stop per beat; `tutorialVideoOf` writes a position's first
beat as the `init` or `move` it is today and every later one as an event of
kind `beat` (`fen`, `text`, `arrows`, `squares`, `orientation`, nothing else);
`partOpeningsOf` opens a part only on a first beat, and a return hangs from
**the first beat of the move it names**; the map of the parts reads the place
on the line. `_joinOnto` (`pgn_tutorial_export.dart`) keeps each part's
sentences as beats of the join, and adds nothing for a wordless first beat
that carries the marks of the beat before it.

### 3. The server (`film_beat_event.test.js`)

One rule in `applyEvent` (`chess_backend/videoRenderer.js`): an event of kind
`beat` leaves the note under the board („Back to the position after …") as it
was. **No other server change.** The narration already reads one clip per
event whatever its kind (`services/tutorialNarration.js`) and the own-voice
upload compares its markers with the events (`services/narrationUpload.js`);
confirm both by a case, not by reading.

### 4. The editor (`sentence_editor_test.dart`, the recording case)

The contract at the gate's head: `TutorialSection.cursorAt`, the controller's
`cursorAt` / `openBeat` / `selectBeat` / `addSentence` / `removeSentence` /
`setComment(…, at:)`, the Flow panel's new parameters and keys, the phone's
and Preparation's keys and words. The rule that matters most: **the board
draws the open sentence's marks and a mark drawn goes to it** — every place
that hands the board `node.arrows` / `node.squares` or draws on them in the
studio (`tutorial_studio_screen.dart` around `:1154`, `:1211`, `:1223`), the
phone layout and Preparation (`preparation_screen.dart` around `:971`–`:993`,
`:1084`, `:1529`) goes through the open beat. In Preparation the recording's
`arrow_drawn` stamps the open beat's marks, and opening another sentence whose
marks differ is an `arrow_drawn`.

Where a position has one sentence, every screen reads word for word as today.
New words are only those in the gate heads.

### 5. The readers the gates do not name

- **The narration screen** (`tutorial_narration_screen.dart`, the board around
  `:508`) draws `node.arrows` for each stop; it must draw the stop's own
  beat's marks, or the trainer records over a second sentence with the first
  one's arrows on the board.
- **The room and Analysis** know nothing of beats and stay that way: they
  show and edit the first, and a PGN they save keeps the rest (the model
  gate's room round trip holds that).
- `tools/tutorial_translate/translate.py` and
  `chess_backend/services/lessonSteps.js` need nothing.

If you find another reader of `comment`, `arrows` or `squares` that a second
sentence would make wrong, fix it by the same rule and name it in the report.
Grep `test/support/` as well as the tests for what you change — a shared
helper is how a ninth test file goes red unseen.

## Cases you add

At least these, each watched red on the wrong code before green:

1. The own-voice film: a tutorial with two sentences on one position takes
   one marker per sentence in the narration screen, and the upload's
   `events` count equals its markers.
2. The narration screen draws, on a later sentence's stop, that sentence's
   marks and not the first's.
3. On the server, a film whose events include a `beat` is narrated one clip
   per event (`tutorialNarration` / `narrationPlan`'s own test file).

## What is not built

- No change to the room's or Analysis's screens.
- No speech to text, no tutorial from a recording (phases 7–8).
- No change to the database or any route.

## The report

1. **What the brief or the gates got wrong**, first, with the case's name and
   what you measured. If nothing: say so.
2. The pass condition's commands, their last lines, as run by you — the two
   gate commands, the full app suite, `npm test`, `flutter analyze`'s summary.
3. Cases you added, by file and name, and for each the wrong code you
   watched it fail on.
4. Every existing test you rewrote, with the rule that superseded it.
5. Every reader, writer and copier you changed that the plan's table does not
   name.
6. Anything you saw that is outside this phase — reported, not fixed.
