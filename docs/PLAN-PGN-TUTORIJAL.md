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

## Phase 1 — the reader: a PGN text becomes tutorial parts ✅ 12.9.2026

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

## Phase 2 — questions where the marks are ✅ 13.9.2026

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

**The open question was `acceptedSans`, and the owner chose option 3 on
12.9.2026.** The answer is engine-chosen, so it is the best move — but a second
move may be just as good, and then a child playing it is told they are wrong.
The three options were: leave it empty and accept the cost; fill it from the
app's own Stockfish at import time; or ask only where the review's own threshold
already did the filtering.

**Built as chosen, and here is exactly what it buys.** A question is made only
where the review wrote `??`, which means the move lost at least the trainer's
threshold — two pawns by default.

 * It filters **the moment**: every question stands where the game actually
   turned.
 * It does **not** filter **the answer's uniqueness**, and the plan said it
   would. That was wrong, found while building: a reviewed PGN carries no
   evaluations at all. `GameAnalysisWalkerService` deliberately stopped writing
   a number onto the node — „the engine's opinion wearing the reader's
   handwriting" — so the file says a move was a blunder and says nothing about
   whether a second move was as good as the answer. Only option 2 removes that,
   and it makes importing a file wait on a search per question.

So the two mitigations that cost nothing are taken instead: the question
**never claims the answer is the only move** („White played Nd4 here, and it was
a mistake. What should White have played instead?"), and the part right after it
shows the better line, so a child who played something else sees what was meant
rather than only „wrong".

**Both marks are required**: a `??` *and* a sideline whose first move carries
`!`. A `??` on its own is a move somebody disapproved of, and a trainer's own
unmarked variation is a line they were looking at — offering its first move to a
child as the correct answer is the app asserting something nobody said. That
rule was written with the condition in it and proved by a mutation that survived
until a fixture with an unmarked sideline existed.

**A ceiling, `defaultMaxQuestions` = 4.** Every question costs two or three
parts and a tutorial is four to ten; the experiment's third game had eighteen
moves tagged at 0.8 pawns, which without a ceiling is forty parts nobody walks
to the end of.

**Nothing is generated silently.** The import reports „four questions made from
four blunders" and the trainer opens the tutorial in the studio, where every one
of them can be deleted. A generator that cannot be reviewed before saving is the
shape this repository keeps paying for.

## Phase 3 — the door ✅ 13.9.2026

Built, with one thing decided while building and two faults the **existing**
import tests found that the new ones could not.

`maxGamesPerFile` is 50 and the cut is said on the first row — a whole database
is an ordinary thing to pick by mistake, and the owner's own Lichess export
holds 4126 games. The two faults: `questionsAvailableIn` counted the questions a
file *already had*, so a hand-written tutorial with a question in it was offered
„make questions from the mistakes" over a file with no mistakes marked anywhere
and the report behind that dialog never opened; and judging a file by its
content alone read a broken `.json` as a game, which tells a trainer about the
wrong reader. **Not one of the new fixtures had a question in it already, and
not one was a `.json` that failed to parse** — the suite that caught both is the
one that had been there all along.


 * `.pgn` beside `.json` in the library card's picker, and the same multi-file
   behaviour: several files, one report.
 * One tutorial per game, or all games as parts of one — a choice at import,
   defaulting to one per game.
 * „Turn blunders into questions" — off by default, because a trainer importing
   a game to *show* it should not find questions in it.
 * A single game opens in the studio unsaved, the way a single JSON file does.

## Phase 4 — the other direction ✅ 13.9.2026

```dart
List<AnalysisNode> gameTreesOfTutorial(List<TutorialSection> sections);
List<String> pgnGamesOfTutorial(TutorialDraft draft);
String pgnFileOfTutorial(TutorialDraft draft);
```

Built as written. Adjacent parts join into one game when
`MoveTree.samePosition(next.fen, endOfMainLine(previous).fen)` — the viewer's
own test for „this continues", so the file is cut where the child's board would
have been rebuilt anyway; a break starts a new game, and the exporter writes its
`[SetUp "1"]`/`[FEN]` on its own. It leaves through `savePgnFile`, the picker
the Analysis studio's „Save as .pgn" already went through, from a button in the
tutorial studio's own toolbar.

**The loss is said in the dialog before the file is named**, and the sentence is
`pgnExportLoses`: what a part asks, its answer, the moves accepted beside it,
which way round the board is drawn, and the tutorial's title, labels and
language. It does **not** send a trainer to another door — there is no JSON
*export* in this app, only an import — so it says the saved tutorial keeps all
of it, which is true and reachable.

Four things came out of building it.

**A part's `instruction` does travel**, written as the sentence it is on the
position it is asked from. The plan had listed it as lost. A question part is a
position, a sentence and an answer; the answer is the move the tutorial itself
goes on to play, so dropping the sentence too would have made an `ask_move` part
contribute *nothing at all* to the file — a silent loss of the one thing in it a
person wrote.

**An existing source-reading gate caught the new file, and the gate was right.**
`tutorial_authoring_test.dart` fails anything under `lib/features/tutorial_studio/`
that imports `PgnExporterService`, because a step's `fen` and `pgn` must come
from one node through `StudioLessonStep`. The export is a file rather than a
step, so the letter of the rule did not apply — but the fix was to go through
`StudioLessonStep.gameText`, beside `textWithSpans`, which is the class that
exists precisely so the studio never reaches for the exporter itself. **Widening
a gate to admit a special case is how the case after it gets in unasked.**

**The drawings are merged at a join, not appended.** `splitForQuestion` *copies*
the cursor's arrows and squares onto the question it makes, because the board
does not reload across a join and a circle that vanished there would be a
flicker. Both parts therefore carry the same arrow, and joining them back by
concatenation writes it twice — on every question this app has ever cut. The
square is tested as the arrow's twin, since a pair fixed by halves is how the
rank numbers spent two days invisible after the file letters were put right.

**The join is the real FEN, en passant square and all.** The first fixture wrote
the position after `1. e4 e5` with `-` in that field, and the two parts did not
join — correctly: `MoveTree.samePosition` compares it, the viewer compares it,
and `addSection(continueFromEnd: true)` writes the square. A fixture that types
a FEN by hand is a fixture that can disagree with every reader in the app.

Sixteen mutations, all sixteen caught; one reported „NOT APPLIED" first and was
re-run rather than counted.

## What this plan does not do

 * **No second parser, anywhere.** Not on the server either: it stores a `pgn`
   as opaque text and has no PGN reader, and giving it one would be two parsers
   disagreeing — which this project has already paid for once.
 * **No engine requirement for importing.** A trainer without Stockfish
   installed must still be able to bring a game in; only the optional question
   generation may ask for it, and only under option 2 above.
 * **No new format.** Everything here lands in `positionList`, which is what the
   server, the studio, the child's viewer and the grader already read.
