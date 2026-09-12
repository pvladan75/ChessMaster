# A game becomes a tutorial, and a tutorial becomes a game

Points 1 and 2 of the owner's note of 12.9.2026
(`D:\chess\tutorijal\pgn_tutorial_question.txt`). Written after the
language-model experiment in `tools/game_annotate/`, which was run **before**
any of this, and which decided two things this plan now takes as settled.

## What the experiment settled

Three games, nine runs, all graded CLEAN by the app's own reader; every
`ask_move` then checked against Stockfish at depth 22. The full table is in
`tools/game_annotate/README.md`. Two results matter here.

**Questions must be generated from the reviewed game, not from the bare moves.**
In all three games the arms given „Review entire game" output asked a question
whose answer is the engine's first choice by a clear margin; the arm given only
the moves never once did — it invented questions that look well formed and are
subtly false („the *only* defensive move", answer ranked third). The `??` and
the „Better move" line beside it are what put a question where the lesson
actually is.

**A question whose answer is not uniquely best marks a child wrong for finding
a better move**, and `readTutorialJson` calls that CLEAN every time. It is the
one fault the format contract cannot catch, so whatever generates a question
here has to answer it — see phase 2.

## What already exists, and is not to be rewritten

| | |
|---|---|
| `MoveTree.parsePgn` → `LessonStepLine` → `readStepTree` | the one reader. A second parser is a fault this repository has already paid for |
| `PgnExporterService.exportWithSpans` | the one writer, comments, `[%cal]`, `[%csl]`, variations and now NAGs |
| `splitForQuestion` | „one part becomes demonstration, question, continuation", with the step id kept on the right part |
| `readTutorialJson` | the pre-flight: refused / damaged / clean, per part |
| `TutorialLibraryCard`'s file picker | the door several files come in through |
| `MoveTree.samePosition` | whether two parts join — the viewer's own test |
| „Save as .pgn" | where a PGN leaves the app (12.9.2026) |
| `MoveNode.nag` | the assessment, readable since 12.9.2026 — phase 0, and the prerequisite for phase 2 |

## Phase 0 — the NAG repair ✅ 12.9.2026

Done and merged. Without it a `??` could be written and never read, so every
phase below would have been reading a field that is always null.

## Phase 1 — the reader: a PGN text becomes tutorial parts

A pure function, no widgets, landed as its own commit. The repository's own
lesson: where a batch has a pure core, prove it first and the screen has
nothing left to be wrong about.

```dart
List<String> pgnGamesOf(String text);        // split on the header boundary
ImportedTutorial tutorialFromGame(String pgn, {String? fileName});
```

 * **The split is the one the backend already uses**, `\n\s*\n(?=\[Event )`
   (`services/gameArchiveImport.js`). One copy of a rule, not two.
 * **One game is one part** by default. An annotated game is one continuous
   line, and the viewer already narrates it move by move with each comment as a
   beat; a part per comment is a transcript, not a tutorial.
 * **No `[FEN]` header means the standard opening position** — the rule the app
   already applies to a pasted game.
 * The result is the shape `readTutorialJson` returns, so the existing
   pre-flight, the existing banner and `chess_app/tool/grade_tutorial.dart` all
   work on it unchanged.
 * The title comes from the headers (`White` vs `Black`, `Date`) when they say
   anything, and from the file name when they do not. „Analysis Studio Session"
   is not a title: it is what this app stamps on every export.

**What has to be tested, because it is what goes wrong:** a game whose moves do
not replay from its own header FEN (report, do not store); a file with several
games where one is broken (the others still import); a file that is not a PGN at
all; and `rejectedMoves` reaching the caller rather than being swallowed.

## Phase 2 — questions where the marks are

Reads the tree phase 1 produced. For each move carrying `??` whose parent holds
a sideline whose first move carries `!`:

 * cut with **`splitForQuestion`** at the position before the blunder — the same
   function the studio's „Traži potez na tabli" uses, so a generated tutorial
   and a hand-built one come out the same shape;
 * `solutionSan` is the first move of the „Better move" line, which the review
   pass took from the engine;
 * the continuation follows **the game**, not the better line. The better line
   stays a sideline. A tutorial about your own game that silently continues with
   a game you did not play is a different artefact.

**The open question, and it is the one the experiment ended on:
`acceptedSans`.** The answer is engine-chosen, so it is the best move — but a
second move may be just as good, and then a child playing it is told they are
wrong. Three options, to be decided before this phase is built:

 1. leave it empty and accept the cost (wrong on roughly one question in three,
    judging by the experiment's positions);
 2. fill it from the app's own Stockfish at import time — the engine is already
    there, but it makes importing a file wait on a search per question;
 3. ask only where the review's own eval gap is large (the swing is already in
    the reviewed PGN's tagging threshold), and skip the rest.

Option 3 costs nothing and uses a number that already exists. It is the one to
try first.

**Nothing is generated silently.** The import reports „four questions made from
four blunders" and the trainer opens the tutorial in the studio, where every one
of them can be deleted. A generator that cannot be reviewed before saving is the
shape this repository keeps paying for.

## Phase 3 — the door

 * `.pgn` beside `.json` in the library card's picker, and the same multi-file
   behaviour: several files, one report.
 * One tutorial per game, or all games as parts of one — a choice at import,
   defaulting to one per game.
 * „Turn blunders into questions" — off by default, because a trainer importing
   a game to *show* it should not find questions in it.
 * A single game opens in the studio unsaved, the way a single JSON file does.

## Phase 4 — the other direction

```dart
List<String> pgnGamesOfTutorial(TutorialDraft draft);
```

 * Adjacent parts join into one game when `MoveTree.samePosition(next.fen,
   endOfMainLine(previous))` — the viewer's own test for „this continues", so
   the file is cut where the child's board would have been rebuilt anyway.
 * A break starts a new game with `[SetUp "1"]` and `[FEN]`, which the exporter
   already writes.
 * It leaves through „Save as .pgn", already built.

**Say what is lost, in the dialog, in one sentence.** `kind`, `solutionSan`,
`acceptedSans`, `blackOrientation`, the tutorial's own title, labels and
language have no home in PGN. The JSON of `docs/PGN-TUTORIAL-FORMAT.md` is the
lossless format and already imports; PGN export is for humans and other chess
programs. A trainer who learns that by losing a question learns it too late.

## What this plan does not do

 * **No second parser, anywhere.** Not on the server either: it stores a `pgn`
   as opaque text and has no PGN reader, and giving it one would be two parsers
   disagreeing — which this project has already paid for once.
 * **No engine requirement for importing.** A trainer without Stockfish
   installed must still be able to bring a game in; only the optional question
   generation may ask for it, and only under option 2 above.
 * **No new format.** Everything here lands in `positionList`, which is what the
   server, the studio, the child's viewer and the grader already read.
