# Can a language model write a tutorial from one of my games?

The experiment behind question 3 of `D:\chess\tutorijal\pgn_tutorial_question.txt`,
built 12.9.2026, before any of it is implemented in the app. One game, three
arms, and a grader that is the app's own reader rather than an opinion.

Nothing here is part of the app or the server. It is run by hand, like
`tools/tutorial_translate/`.

## The question it answers

Not „can a model annotate a game" — it can, and so can the app's own „Review
entire game", for free and without a model. The question is whether it can
**choose**: which four to ten moments of a twenty-seven-move game are worth a
child's attention, and what each one teaches. That is the part a motif detector
cannot do, and the only part worth paying a model for.

## The three arms

| | What the model is given | Engine |
|---|---|---|
| **A** | the game, moves only | none |
| **B** | the game after „Review entire game" — motifs, `??`, better-move lines | none |
| **C** | the same reviewed game | Stockfish, 40 searches |

Everything else is identical: one `brief.md` for all three, one output contract,
one grader. So a difference between two arms is about the input and not about
the wording of the task.

**Arm B is the one that had to be run through the app first**, and it is the
reason this is not purely a scripted experiment: `tactical_motif_detector.dart`
and `positional_evaluator_service.dart` live inside the Flutter client and can
be reached from nowhere else. „Give the model the motif detector" *means* „run
Review entire game and hand over the PGN it wrote".

Arms A and B are given a **budget of zero engine calls, not the absence of the
tool**. A refusal is logged, so „did it reach for an engine it did not have" is
a question the run can answer afterwards.

## Running it

```bash
cd tools/game_annotate
python make_inputs.py "D:/chess/tutorijal/pgn_tutorial_question.txt" --name pvladan_2026-09-12
python run_arm.py A
python run_arm.py B
python run_arm.py C --max-calls 40
```

`make_inputs.py` writes two files into `input/` — the reviewed game exactly as
it came, and the same game with the comments, glyphs and variations taken out —
and refuses if the two do not hold the same moves.

`run_arm.py` builds the prompt, runs `agy`, and keeps everything a run produced
under `out/<arm>-<stamp>/`: `prompt.md` as it was sent, `reply.txt`,
`tutorial.json`, `engine_calls.jsonl` and `meta.json`. `--dry-run` writes the
prompt and stops, which is also how you get a prompt to paste into a web UI or
an API for the online arm.

Tool calls are auto-approved so the run does not stop at a prompt nobody is
watching; `--no-yolo` turns that off.

Then grade:

```bash
cd chess_app
dart run tool/grade_tutorial.dart ../tools/game_annotate/out/A-20260912-221216
```

## What the model may see

Each arm runs in an **empty temporary directory outside this folder**, holding
nothing but the game, and with no `--add-dir`. Everything is copied back into
`out/<arm>-<stamp>/` when it finishes.

That is not tidiness, it is the experiment. The first run of all three arms, on
12.9.2026, was thrown away: `run_arm.py` passed `--add-dir` on this folder, so
the model's workspace was the experiment itself. Both B and C read this README —
they came back writing about „Arm A / Arm B / Arm C" and about `analyze.py`,
words that appear in neither of their prompts — and C followed the path in it to
`pgn_tutorial_question.txt` and answered the trainer's four questions unasked.
Worse, **arm A's finished `tutorial.json` was sitting in a sibling directory ten
seconds before arm B started**, and B came back with the same title, the same
seven positions and the same arrow commands as A, differing only in wording.
That looked like a finding — „the motifs changed nothing" — and it cannot be
told apart from copying.

Two rules came out of it, and the second is the one that generalises.

**An arm must not be able to reach another arm's answer.** This is the
experiment's version of a fault this repository already knows: a shared fixture
and a singleton slot is a test reading the test before it.

**A model reads what is in front of it, and a README describing the hypothesis
is in front of it.** `tools/tutorial_translate/translate.py` had already reached
this conclusion and says so in a comment - an empty working directory, „so the
agent has nothing in its workspace to read instead of the items it was handed".
That comment was there to be read before this was built, and was not.

The brief now also asks the model to declare anything it read outside its
working directory. That is a check that can fail, which the silence before it
was not.

## The grader

`chess_app/tool/grade_tutorial.dart` calls `readTutorialJson` — the same
function the app's „Import from a file" door calls, which reads every line
through `LessonStepLine`, the child's own parser. Exit code 0 clean, 1 storable
but damaged, 2 refused.

It was proved before it was used: the worked example in
`docs/PGN-TUTORIAL-FORMAT.md` grades CLEAN, and four deliberate faults — a move
that cannot be played, a question carrying its own answer, a FEN with a `c` in
the board field, and prose instead of JSON — come back DAMAGED, DAMAGED,
REFUSED, REFUSED. A grader that has never been watched failing is not a grader.

## The engine wrapper

`analyze.py` is what arm C calls. Two commands:

```bash
python analyze.py fen "<FEN>" --depth 18 --multipv 3
python analyze.py line --fen "<FEN>" --moves "Nxf3 Bxf3 Bxf3" --eval-each
```

Three things about it are deliberate.

**It is stricter about SAN than python-chess is.** python-chess accepts `Bd6+`
on a move that gives no check; `MoveTree.parsePgn` refuses it, and the format
contract's rule 4 says so. A tool that blessed a move the app will later drop
would teach the model the exact fault the experiment is measuring. It reports
the move's real SAN instead.

**Every evaluation is from White's point of view** and says so in words, because
a score reported from the side to move is the easiest number in chess to quote
backwards.

**The budget is a file.** Every call appends a line to
`out/_budget/<session>.jsonl`; only calls that actually ran a search are
charged, so checking one's own work with `line --no-eval` is free. An experiment
whose cost nobody wrote down cannot be priced later.

## What three games said, 12.9.2026

Three games, nine runs, `gemini-3.8-flash-high`, one run per arm per game. The
games were chosen to differ: a sharp win as White decided by a double attack; a
quiet French Advance drawn by perpetual check; a Philidor where White sacrifices
on f7 on move eight, it is unsound, and the game ends in mate thirty-five moves
later. The review tagged ten, ten and eighteen blunders respectively.

**All nine graded CLEAN on the first attempt** — every FEN legal, every line
replaying through `LessonStepLine`, no question carrying its own answer. Whatever
else is uncertain, the format contract is not the hard part.

The measurement that separated them is the one the grader cannot make: for every
`ask_move`, is the answer actually the best move? Each was checked at depth 22,
multipv 4.

| | arm A (plain) | arm B (reviewed) | arm C (reviewed + engine) |
|---|---|---|---|
| sharp win | „the *only* defensive move" → `Rae8`, **3rd of 4** | `Nc7` **#1**, +3.02 against +2.21 | `Nc7` **#1** |
| quiet draw | „block the check" → `Rd2`, **+2.56 against +3.63** | `c4` **#1**; `Bc6+` **#1**, +0.33 against +7.93 | `c4` **#1** |
| lost sacrifice | `O-O`, **3rd of 4** | `Nxf3` **#1**, −2.55 against −4.03 | `Rxb2+` **#1, mate in nine** |

**The annotated arms' answers are the engine's first choice by a clear margin in
every game; the unaided arm's answer is never first.** Three for three, on games
sharing nothing but the format.

Three things keep that from being a law. It is one run per arm per game with one
model. The third game is the weakest case for it: arm A picked the *right
moment* unaided — the move-eight sacrifice, the most instructive point in the
game — and its accepted list holds `h3`, which is the engine's best; the four
candidates there sit within a third of a pawn, so the teaching is sound whichever
is named. And arms B and C diverged for the first time on that game, where on the
other two they had chosen the identical position.

**The engine's role came out smaller than expected.** On the first two games arm
C's searches bought verification rather than different content — it checked
claims and corrected its own certainty („`15. Nd5` is one of three moves of equal
value, not forced"). Only on the third did it find something arm B did not, and
there it found a mate. Arm B is the cost-effective configuration; the engine
earns its place as a check on a *question* — is this answer uniquely best, and
what else must be accepted — rather than as a second author.

**And one fault was made by the brief itself.** After game one, where no arm
filled `acceptedSans` and one asked a question whose answer was merely legal, the
brief was told to fill it. By game three two arms did — with moves that do not
answer their own question: „find the move that brings the king to safety"
accepting a developing move, „find the winning rook invasion" accepting a queen
move. Both lists are defensible as other good moves and indefensible as answers
to the sentence the child reads. The rule now says so. Third time in this
experiment that a fix aimed at one fault produced a subtler one a layer above it,
which is the argument for measuring every arm rather than reading it.

## Which model, and what it costs — 13.9.2026

The three-game result above was produced by `gemini-3.8-flash-high` through
`agy`. The question that followed was whether a much cheaper model could do the
same work, since a price table put a factor of twenty between the top and the
bottom of the range. `run_api.py` exists to ask it: the Lite models are not in
the CLI's list at all, so only the API can be asked.

Arm B, game one, every run through the same API channel:

| model | thinking | verdict |
|---|---|---|
| `gemini-3.5-flash` | default, 9,640 thought tokens | **CLEAN** |
| `gemini-3.5-flash-lite` | its own default — **none** | DAMAGED, 16 unplayable moves in 5 parts |
| `gemini-3.5-flash-lite` | 12,337 thought tokens | DAMAGED, 2 unplayable moves |
| `gemini-3.1-flash-lite` | none | REFUSED, illegal `solutionSan` + 22 unplayable |
| `gemini-3.1-flash-lite` | 12,115 thought tokens | REFUSED, the same two faults |
| `gemini-2.5-flash-lite` | — | the account cannot reach it: „no longer available to new users" |

**The channel is exonerated by the first row.** Same prompt, same transport,
same game: a non-Lite model returns something the app would accept. So the Lite
verdicts are about the model.

**And the price table was measuring the wrong thing.** Those figures assume a
short answer. The cheap runs *are* cheap — zero thinking tokens, four seconds —
and they fail. The runs that come close spend about twelve thousand thinking
tokens, billed as output, which is **more** than the model that passes spends.
The saving disappears exactly where it would have had to exist. When a task
needs deliberation, compare models at the token counts they actually use, not
at the ones a table assumes.

That ended Gemini as a paid option here, for a reason outside the models:
Google Cloud refuses this account's payment profile — the same wall that left
`chess_backend/tts/google.js` written and unreachable on 9.9.2026. The free tier
is ~20 calls a day and has no Batch, so the cheaper column of any such table is
unreachable too. `agy` is unaffected, being a subscription rather than metered,
and `tools/tutorial_translate/` goes on using it.

`run_api.py` takes `--model`, and the grader, the engine check and the inputs
know nothing about any provider — so pointing this at a different vendor is a
transport, not a rewrite.

## What to look at in the results

The grader answers „would the app take it". These are the questions it does not
answer, and they are the ones worth reading the three `tutorial.json` files for:

 * **Did it choose, or did it transcribe?** Parts, and what each one is about.
 * **Is every sentence true of the position?** The grader proves the moves
   replay; it cannot prove a sentence. This is the one thing that still needs a
   human, and it is why the reply asks the model which claims it was least sure
   of.
 * **Did the motifs help or drown it?** A against B. The reviewed input is 11 KB
   against 478 bytes — twenty-three times the text for the same game.
 * **Did the engine change what it taught, or only what it asserted?** B against
   C, and `engine_calls.jsonl` beside it.
