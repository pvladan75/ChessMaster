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

## Trying another vendor

`run_api.py --provider` knows four: `gemini` (its own request shape), and
`groq`, `deepseek` and `openai-compatible`, which are all the OpenAI chat shape
and so are one transport rather than three. Azure OpenAI and OpenRouter fit the
last one with `--base-url`.

```bash
python run_api.py B --provider deepseek --model deepseek-reasoner
python run_api.py B --provider groq --model <the model's own id>
python run_api.py B --provider openai-compatible --base-url https://… --model …
```

**Status, 13.9.2026.** Gemini is dropped as a metered API (Google Cloud refuses
this account's payment profile — see `docs/STANJE-RADA.md`). DeepSeek has been
run on all three games and does not clear the bar; the results are in
„DeepSeek, 13.9.2026" below.

**DeepSeek** needs one line in `chess_backend/.env`:

```
DEEPSEEK_API_KEY=sk-…
```

**Azure OpenAI** needs two, because Azure addresses a *deployment* you created
rather than a model id, and authenticates with its own header:

```
AZURE_OPENAI_KEY=…
AZURE_OPENAI_ENDPOINT=https://<resource-name>.openai.azure.com
```

Requests go to the v1 path, `/openai/v1/chat/completions`, which is what Azure
documents for its GPT-5 and GPT-6 reasoning models and which takes no API
version. Setting `AZURE_OPENAI_API_VERSION` switches to the older dated path.
`--model` is the **deployment name**, not the model id: `python run_api.py B
--provider azure --model gpt-5.6-terra --reasoning-effort medium`. Those models
refuse `max_tokens` and a custom `temperature`; both are survived by the retry
below and written into `meta.json`.

**Qwen** (Qwen Cloud / Alibaba Cloud Model Studio) needs a key, and an address
only when the key is not an international one:

```
DASHSCOPE_API_KEY=sk-…
DASHSCOPE_BASE_URL=https://<workspace>.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1
```

Without the second line the address is `https://dashscope-intl.aliyuncs.com/
compatible-mode/v1`, the one Qwen Cloud's own model page uses. A key is bound
to the region it was made in, so a 401 from a key made elsewhere means „set the
address the console shows", not „the key is wrong". Qwen Cloud lists
`qwen3.8-flash` at 131K output tokens with thinking and 2M tokens a minute, so
`--max-tokens 64000` fits.

The 3.8 models think by default. `--thinking-mode disabled` sends
`enable_thinking: false`, and `--thinking <n>` sends `thinking_budget`:
`python run_api.py B --provider qwen --model qwen3.8-max --max-tokens 64000`.

Two refusals are survived rather than reported, because both are about the
request's shape and not about the work: a reasoning model that cannot be asked
for JSON at all, and a newer model that wants `max_completion_tokens` where the
older ones want `max_tokens`. Each retry is written into `meta.json` as
`request_adjusted`, so „it needed one" stays visible instead of becoming folklore.

The key is read from the environment, or from `chess_backend/.env`, under
`GEMINI_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`, `AZURE_OPENAI_KEY` or
`LLM_API_KEY`. **None of these belong in `.env.example`** — that file is the
server's contract and the deploy script hands its keys to the droplet; these
are read by a tool that runs on a developer's machine. It is
never printed and never written into a run's folder — this repository is
public, and a failing run is exactly the thing somebody pastes into a chat
window, which is why the error messages carry neither the URL nor the header.

**The bar a new model has to clear is already set**, and it is not „did it
answer": the grader must say CLEAN, and every `ask_move` it writes must survive
`analyze.py fen --multipv 4` as the engine's own first choice by a clear
margin. Three games are in `input/`, the brief is fixed, and the arms mean the
same thing whoever answers them — so a vendor trial is three commands, a grading
run and `check_positions.py --engine` on each run, not a new experiment. The
last one is not optional: the grader alone passed boards with a rook missing.

Two things to expect from the Gemini measurements above. A *distilled* or
otherwise small model is likely to fail the way the Lites did, with moves that
cannot be played; and a model that reasons will spend far more tokens than a
vendor's headline price per game assumes, because this task needs the thinking.
Read `meta.json`'s token counts rather than the price page: `thoughts` is kept
apart from `answer` for exactly that reason.

## DeepSeek, 13.9.2026

Five dollars topped up — the free grant reported for new accounts did not apply.
The account lists two models, `deepseek-flash` and `deepseek-v4-pro`, and not
`deepseek-reasoner`. Both think unless told not to. Twelve calls, eleven of them
billed, cost about $0.35.

**Thinking is spent out of `max_tokens`.** Both models used all 16,384 tokens
thinking and wrote no answer; flash did the same at 64,000. `--max-tokens`
exists for that, and `reasoning.txt` now keeps what a run was thinking.
`--thinking-mode disabled` answers in six seconds and is REFUSED — an unplayable
solution and nineteen moves that do not replay, the Lite result again.
`--reasoning-effort low` is what made flash stop at all, and it still thinks
45–60k tokens, most of them a FEN written out after every move of the game.

Arm B, each run through `grade_tutorial.dart` and `check_positions.py --engine`:

| | sharp win | quiet draw | lost sacrifice |
|---|---|---|---|
| `deepseek-flash`, effort low | CLEAN; `Nd5` **#2**, 0.03 behind `g3`; one move number wrong | DAMAGED; the a1 rook and a c4 pawn missing from three parts, the question among them | DAMAGED; a queen missing, a queen and a rook shifted, in three parts; `Qg5#` is mate |
| `deepseek-v4-pro` | run 1 REFUSED — nine squares on rank 8, the c4 bishop missing; run 2 CLEAN, `Rb8` #1 by only 0.18, and the sentence names the square | **CLEAN**, every position exact, `d4` **#1 by 0.49** | DAMAGED; Black's e7 bishop written as White's in five of six parts, both questions among them |
| `gemini-3.8-flash-high`, above | `Nc7` #1, +3.02 against +2.21 | `c4` #1 | `Nxf3` #1 |

**No DeepSeek configuration clears the bar.** Of seven runs one is clean with a
sound question — pro on the French.

**What fails is the board, not the chess.** Every wrong position is a real
position of the game with one to three squares wrong: a rook dropped, a pawn
dropped, a piece's colour flipped. Where the board survives, the questions are
good — flash's `d4` in the French is the engine's best by half a pawn on the
real position, and its `Nxe5?? Bxd1` choice in game one is sound. A model that
has to write a FEN has to play the game out in its head, and this one cannot do
it reliably for forty moves. The fault is in the contract as much as in the
model: nothing the brief asks for needs the model to *write* a position it could
*name* — „after 15. Nd5" — and have the reader build. That is a proposal, not a
change made here.

**Tokens, not the price page.** Pro spent 20–38k output tokens a game (about
$0.04–0.08 off-peak), flash at low effort 46–62k (about $0.03–0.04).
`gemini-3.5-flash`, which passed, thought 9,640.

**The runs could have overwritten each other.** A run's folder was named by
arm, model and second, not by game, so two games started together on one model
would have shared a folder and one answer would have been graded as the other.
The game is in the name now, and an existing folder is refused.

### `check_positions.py`

```bash
python check_positions.py out/<run> --engine
```

The grader asks whether the app would take a file, and a board with a rook
missing loads and replays perfectly. This asks the two questions the grader
cannot: is each part's FEN a position the reviewed PGN actually reaches —
variations included, since a part on a better-move line is teaching — and if
not, which squares differ from the nearest one; and with `--engine`, where each
`ask_move` answer ranks at depth 22 and by how much. The margin is printed, not
judged.

It was proved against the findings made by hand on five runs before it was
believed, and those found two faults in it. A position that repeats — a
threefold draw is one board at three move numbers — was compared with its first
occurrence only, so a part on the third was reported with wrong counters: a false
alarm about the very fault it exists for. And a mate in one against a mate in
twenty-one printed as „mate against mate".

**Read the position line before the engine line.** The engine ranks whatever
board it is given, so a score under a part that is not the game's is a score for
a board the child should never have been shown.

## Azure OpenAI and Qwen, 13.9.2026 — and the end of the vendor trial

The owner's rule for this round was set before it started: try Qwen, and if that
does not work, stop. Nothing did. Game one only, arm B, every run through the
grader and `check_positions.py --engine`:

| model | verdict | what went wrong |
|---|---|---|
| `gpt-5.4-mini` (Azure, Data Zone EU), effort medium | DAMAGED | six of seven parts off the game by 2–7 squares — captured pieces left standing |
| `qwen3.8-flash` | DAMAGED | all ten parts off the game by 3–15 squares, further off with every part; 88k thinking tokens, 22 minutes |
| `qwen3.8-2.4t-a95b` | REFUSED | an unplayable solution; all ten parts off the game, one of them only by the side to move; 75k thinking tokens, 30 minutes |
| `qwen3.8-max` | no answer | the stream was closed at 899 s during its final checks — 139k characters of reasoning, none of it repeated |

**Every failure in this whole trial is the same failure.** Gemini Lite, both
DeepSeek models, `gpt-5.4-mini` and three Qwen models: none of them chose badly
or reasoned badly so much as lost the board. Asked to write a FEN forty plies
into a game, a model has to play the game out in its head, and only
`gemini-3.8-flash-high` and `gemini-3.5-flash` did that reliably. That is an
argument about the contract, not about the vendors — the proposal it points to
is arm D, below in `docs/STANJE-RADA.md`: hand the model the moments with their
positions already computed, and let it choose and explain.

Things worth knowing about the channels, because they cost a morning:

 * **Azure** would not deploy anything on a Free Trial subscription — „no
   quota" in every region. After the upgrade, Global Standard still had none
   for the GPT-5.6 models or `gpt-5.4-mini`; **Data Zone Standard** had quota for
   `gpt-5.4-mini` only. The Azure reasoning models refuse `max_tokens`, and the
   retry to `max_completion_tokens` handled it.
 * **Qwen** thinking requests sent without streaming **never answered**: two
   runs waited fourteen minutes and the console's usage page still said 0 tokens.
   `--stream` fixed it, and prints progress. Qwen does not hold a request to
   `max_tokens` — flash thought 88k tokens under a 64k ceiling. And a stream the
   server simply closes used to be recorded as a finished run with no answer;
   `send_stream` reports it as a fault now.
 * The free quota („Free quota only", per model) covered all of it.

**One fault in the experiment itself, found during this round.** Game one's
reviewed input carried 1,679 characters of the owner's Serbian questions after
the game: `make_inputs.py` looked for the result token on a line of its own and
the app writes it after the last comment. Every game-one arm-B prompt had it,
Gemini's included, so the comparison stayed fair — but it cost thinking, and
`qwen3.8-max` spent some of its reasoning deciding not to answer the questions.
The input was regenerated after the runs above; `make_inputs.py` now finds the
end of the movetext outside comments and variations, and refuses a game that
does not end in a result.

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
