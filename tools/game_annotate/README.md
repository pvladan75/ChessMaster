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
python check_positions.py out/<run>
```

The grader asks whether the app would take a file, and a board with a rook
missing loads and replays perfectly. This asks the two questions the grader
cannot: is each part's FEN a position the reviewed PGN actually reaches —
variations included, since a part on a better-move line is teaching — and if
not, which squares differ from the nearest one; and is each `ask_move` answer
the best move of **the analysis that was sent**, with every extra
`acceptedSans` move one the sent numbers put within 0.3 pawns of it.

**It used to run Stockfish again at depth 22, and that was wrong** (owner,
13.9.2026): the analysis we send is the only source of truth, it is our job to
send it deep enough, and a model must take the evaluation it was given and not
change it. Grading against a deeper search marks a model on a fact it was never
told — the French `Ke3` was #2 by 0.04 at depth 22 and #1 by 0.44 at depth 26,
three searches disagreeing about a question the model had answered exactly as
instructed, and the analysis it was handed said +0.53. There is no `--engine`
flag any more, because a flag is an invitation. What is measured is obedience,
not chess.

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

## Arms F, G and H, 13.9.2026 — taking the decisions away from the model

After the vendor trial every remaining failure was a decision a model had made
that a program can make exactly. So three arms took those decisions away, one
layer at a time.

| arm | what the model is given | what the model still decides |
|---|---|---|
| **F** | arm B plus a table of every position; parts name a position by label (`"from": "14... Qc7"`) and the harness fills the FEN | everything but the FENs |
| **G** | the bare game plus `input/<game>_facts.json`: for every position the four best moves at depth 20 with evaluations, the move played and its cost, whether the best move stands out, and the app's motifs; the model must not assess moves | the moments, the lines (copied from the facts), the questions (checked against the facts), the words |
| **H** | a skeleton built by `skeleton.py`: candidate moments where the move played cost ≥ 1.0 pawns, each with its parts, FENs, lines and questions already made (every move within 0.3 of the best is correct, no question when more than 3 are); every text field empty and shown with its facts | which 2–3 of the offered moments, and the words |

`make_facts.py` computes the facts once per game with the same engine settings
the grading uses. **The thresholds belong to the skeleton, not to the analysis**:
a facts file is raw engine output, so X, the 0.3 margin and the ceiling can
change without analysing a game again — the owner's rule, so that games once
analysed are reused.

**F** made every position exact in all five runs on game one and left the
questions wrong: they still trusted the review's single „better move", and
`9... Nxf3+` is fourth of four moves within a tenth of a pawn at depth 22.
`qwen3.7-max` thought eight times less once it no longer rebuilt boards.

**G** gave `deepseek-flash` eight right questions out of eight across the three
games, and two damaged files — both for one letter copied wrong from a line the
facts had right (`Raxb8` written `Rxb8`, `Rd7` written `R3d7`). Three other
models copied FENs instead of naming positions; the harness now accepts a
written FEN only when it is exactly a position of the table. The weaker models'
sentences stayed false with the facts in front of them.

**H**, fifteen runs over three games and five models:

| model | game one | French | Philidor | seconds a game |
|---|---|---|---|---|
| `deepseek-flash` (API) | CLEAN | CLEAN | CLEAN | 24–38 |
| `gpt-5.4-mini` (Azure) | CLEAN, 3 sentences on the wrong move | CLEAN | CLEAN | 17–28 |
| `qwen3.7-max` (Qwen) | CLEAN | CLEAN | CLEAN | 60–67 |
| `gemini-3.8-flash-high` (agy) | CLEAN | CLEAN | CLEAN | 86–120 |
| `gemini-3.1-pro-high` (agy) | CLEAN | CLEAN, 1 unsupported „pin" | CLEAN | 84–126 |
| `qwen3.8-flash` (Qwen) | its JSON broke — `"chosen: ["` inside a tag | — | — | 344 |

Every position exact and every question Stockfish's first choice, with about
ten thousand tokens a game instead of thirty to ninety. `deepseek-flash`'s
sentences, read in full, follow the facts.

Four things worth carrying.

**A single search near the margin is not a verdict.** `Ke3` in the French game
led by 0.53 at depth 20 with four lines, came second by 0.04 at depth 22 with
four, led by 0.25 at depth 22 with five and by 0.44 at depth 26. The question was
right; the grading search was the noise. A borderline question has to be judged
by a deeper search or by two agreeing ones.

**The app's motif detector writes the tutorial's vocabulary.** Four models wrote
„skewer" in the same places because the review says „Skewer: the white knight on
d5 has to move, exposing the white pawn on e4", and „Fork: the white queen on d5
attacks five black pieces" counts three pawns. „Resolved —" came through as
words too. Whatever the facts say, the model says.

**So the vocabulary was cleaned, and the inputs follow it (13.9.2026).** The
detector writes sentences now — no „Watch out —", no „Resolved —", no „ | " —
and stops counting what teaches nothing: a fork lists only what it can win (the
queen above „forks the black rook on a8 and the rook on d7"), a skewer needs a
front piece that must move and a back piece worth winning, a pin needs something
behind worth more than the pinning piece or left loose, the king is never a
„defended piece", and the colour-complex rule points at the squares the pawns do
*not* cover. The three `_reviewed.pgn` files were rewritten with
`REVIEW_COMMENTS_ONLY=1` (`chess_app/tool/review_game.dart`): main-line comments
only, every `??`, `!` line and side-line comment kept — checked move for move
against the old files, because game one's tags came from the trainer's in-app run
and a fresh review would not give them back. The `_facts.json` files were then
rebuilt at the settings they carried (depth 20, multipv 4, margin 0.5, one
thread, 128 MB). **Runs made before this date read the old wording**, so a
comparison across that date compares two vocabularies, not two models.

Later the same day the inputs were rewritten once more, when a finding started
keeping its identity across a move and counting only what it can win
(`docs/STANJE-RADA.md`, „Isti nalaz posle poteza"): 79 main-line comments
changed across the three games, 21% less text, and the tags and lines were
again identical move for move.

**The claim check is judged against the slot's own facts.** It first flagged
„mate" in slots whose facts read „Black mates in 5"; it now backs a word when the
text shown beside that slot contains it, which is the rule the model was given.
It catches a sentence written on the wrong move (`says a piece goes to c4, and
this move goes to c8`), which nothing else did.

**The harness had faults of its own, and each looked like success.** The
question check skipped parts with no label and reported an empty list; two
`make_facts.py` runs started beside a `cd` into `out/` could not find the script
and exited 0 behind a `| grep` (every command now uses absolute paths and
`set -o pipefail`); grading calls were charged to arm C's forty-call engine
budget until the fortieth was refused; and a 503 that cut a run off left a draft
that was graded as the model's answer until `run_arm.py` recorded the CLI's
failure. `review_run.py` prints everything a person still has to read.

```bash
python make_facts.py <game>          # depth 18, 8 positions at a time
python run_api.py H --name <game> --provider deepseek --model deepseek-flash --reasoning-effort low --max-tokens 64000
python run_arm.py H --name <game> --model gemini-3.8-flash-high
python review_run.py out/<run>
python check_positions.py out/<run>
```

## Arm H again, on the cleaned inputs — 13.9.2026, evening

The vocabulary cleanup asked a question it could not answer itself: **did the
sentences get truer?** So arm H was run again on the three regenerated games,
same model and same flags (`deepseek-flash`, `--reasoning-effort low`,
`--max-tokens 64000`), and read against the runs of that afternoon.

| game | grade | positions | question | seconds | prompt chars | tokens |
|---|---|---|---|---|---|---|
| `pvladan_2026-09-12` | CLEAN | all exact | 3 of 3 #1 | 24.2 → **19.3** | 16398 → **12038** | 10120 → **8848** |
| `french_2026-06-19` | CLEAN | all exact | 2 of 3 #1, one borderline | 38.1 → **18.6** | 18615 → **15115** | 13770 → **9312** |
| `philidor_2026-07-03` | CLEAN | all exact | 3 of 3 #1 | 31.0 → **26.8** | 25056 → **21721** | 14182 → **13498** |

The one marked borderline was the French `Ke3`, and **the question it raised was
settled against the harness rather than against the model.** Graded by a fresh
search it was #2 by 0.04 at depth 22 and #1 by 0.44 at depth 26 — three searches,
three answers. The analysis the model was handed says +0.53, and the model
answered exactly what it was handed. The owner drew the line the same evening:
**the analysis we send is the only source of truth**, it is our job to send it
deep enough, and a model must not change the evaluation it was given. So
`check_positions.py` no longer re-searches at all; it asks whether the answer is
the best move of `input/<game>_facts.json`, and under that rule all nine
questions of all three runs are right, `Ke3` included and unremarkable.

**The false sentences are gone, and they were the motif detector's words in the
model's mouth.** Every sentence of all three new runs traces to a fact in its own
slot; the afternoon's runs carried these, all of them repeating the old wording:

 * game one, after 23... Qc6: „Behind the knight sits the white pawn on e4, so
   the knight cannot simply move away" — the old skewer of a knight onto one's
   own pawn. Geometrically true and pedagogically backwards: a knight may move
   and drop a pawn. The new run says what the position holds — „The queen on c4
   pins the c5 pawn to the queen on c6".
 * French, after 31. Rd6: „attacks the bishop on c6, skewering it to the b6 pawn
   behind", and „The skewer is over" a move later — a skewer that wins nothing,
   which is exactly what the new rule refuses. The new run: „the bishop has no
   defender", „the bishop is no longer hanging".
 * French, after 25... Rc2+: „the g2 pawn stands behind the king", carried into
   the question a student reads. Gone; the question now names the fork.
 * Philidor, after 39... Qc2+: „forks four white pieces", and „The rook on e4 is
   also the only defender of the pawn on a4". The new run forks the two it can
   win — „the white king on g2 and the pawn on b2".

**What did not improve is one question's mechanism.** Game one's first question
was „Look for a knight move that attacks two black pieces at the same time" in
the afternoon and „Find the move that uses the pinned pawn on c5 to win
material" now. Nc7 forks the rooks; the pin on c5 is the one motif standing
beside that slot, and the model attached it. Whatever the facts say, the model
says — and that holds for a true fact quoted about the wrong move as well as for
a false one.

**The choice barely moved.** Game one chose the same three moments; the Philidor
chose the same three under new labels (its candidate list changed, below); the
French swapped its third, from 32. Kd4 to 31... Bb5. Two changes sit between the
runs, not one: the brief's audience line became „a student of 13 or older" in the
same commit.

Two faults of the harness came out of the comparison, both in the numbers rather
than in the words, and both are fixed.

**`cost_pawns` is the string `mate`, and it was printed into a sentence.**
`skeleton.py` wrote `it cost %s pawns`, so nine slots of the Philidor prompt said
„it cost mate pawns". The afternoon's run read it as damage and told a student
that grabbing on h7 „cost pawns near the king"; the evening's wrote „That move
allowed mate". The input was broken either way. `cost_text()` is the one place
that turns a cost into words now, and `make_facts.py` says **which** mate it was:
the prompt reads „in the game 24. Qxh7 was played and it allowed a forced mate"
and „24... Nf4+ was played and it gave up a forced mate".

**A move that is the best move cost nothing, whatever two searches say.** The
move played is scored from the next position's own search, so its number and the
best move's come from two searches that disagree by a hair — `11. Qxe2`, rank 1
of 4, carried a cost of 0.2 pawns. `make_facts.py` had the guard only against a
*negative* cost. With a mate on the board the same hair becomes infinite:
`cost_pawns` was `mate` whenever a mate was involved and the best value was
larger by anything at all, one ply of mate distance included, and `_cost_value`
sorts a mate above every real blunder. In the afternoon's Philidor facts that
filled **three of the eight candidate moments with moves where the best move was
the move played** — one of them `43... Qg5#`, the mate that ended the game —
crowding out three genuine mistakes of 3.4 to 4.4 pawns. `set_cost()` now says
zero when the played move is the best move and when a mate is still a mate
(mate in 3 against mate in 2 is not an infinite loss, and being mated a move
later is not a loss at all); `mate` is kept for a forced mate that appears or
disappears.

**The fix was applied to the three games without analysing them again.** What a
move cost is arithmetic over `value_for_mover`, which the facts file already
holds, so `python make_facts.py <game> --recost` re-derives every cost with no
engine — the owner's rule that a game once analysed is reused, honoured exactly.
It zeroed 44 costs of 0.01 to 0.27 pawns across the three games, every one of
them on a move that *was* the best move, and changed no moment list: the noise
that mattered was the mate-sized kind, and the rebuilt facts happened not to
carry any.

## The Gemini leg, on the fixed inputs — 13.9.2026, evening

Both faults above were fixed, the three facts files recosted, and the whole thing
run twice more on identical inputs: `gemini-3.8-flash-high` through `agy`, and
`deepseek-flash` again so the two models are read off the same prompts rather
than across a change.

| | `deepseek-flash` | `gemini-3.8-flash-high` |
|---|---|---|
| grade | CLEAN × 3 | CLEAN × 3 |
| positions | all exact | all exact |
| questions | 9 of 9 the sent best move | 6 of 6 the sent best move |
| moments chosen | 3, 3, 3 | **2, 2, 2** |
| seconds a game | 21, 33, 27 | 142, 81, 125 |

Neither changed the analysis it was given — no answer differs from the facts
file, and no run widened an accepted set. Three things separate them.

**Gemini transcribes where DeepSeek writes.** Nearly every Gemini move sentence
is the slot's own phrasing with the punctuation changed: „Black plays the queen
from d8 to c8", „White plays the rook from g3 to d3", „This is a move of the best
line" — the shape of the fact, twenty times over. DeepSeek varies the verb to the
move („Black swings the rook from d8 to d5", „Black's rook takes on d4 and
attacks the rook on d3"). Both are true; only one sounds like a trainer. That is
the README's own first question — did it choose, or did it transcribe — and it is
the first time a model has answered it badly while getting everything right.

**Gemini takes two moments where the brief allows two or three**, in all three
games, so its tutorials are six parts against nine. Fewer questions for the same
game.

**It is four to six times slower for it**, through `agy` rather than an API,
which is a channel difference as much as a model one.

**The cost fix reached a student's sentence immediately, which is the point of
it.** Gemini's Philidor part one ends „White attacks the bishop on h4, but allows
a forced mate", and its answer part says the game move „gave up a forced mate".
Those are the two new phrases, in the two places they belong, written by a model
that had no way to know they had been broken that morning.

## What the masters database actually covers — 13.9.2026

Before building anything on an opening database, one probe:
`probe_masters.py` walks a game's main line and asks the Lichess masters
explorer how many master games ever reached each position and how many played
the move the trainer played. It stops at the first position no master game
reached, because nothing after such a position can be in the database either —
so a whole game costs about a dozen requests, and all three cost 35.

| game | positions | in the database | engine time it would save |
|---|---|---|---|
| `pvladan_2026-09-12` | 54 | **13 (24%)** | 119 s of 494 |
| `french_2026-06-19` | 79 | **10 (13%)** | 67 s of 532 |
| `philidor_2026-07-03` | 87 | **9 (10%)** | 73 s of 710 |
| | | | **260 s of 1736 — 15%** |

A club player leaves master theory after four to six moves. Three things follow,
and only the first was expected.

**As a way to save engine time this is not worth building.** Fifteen per cent of
an eight-to-twelve minute analysis is a minute or two, and it buys a network
dependency, a token, a rate limit and non-determinism in a file whose whole
purpose is to be a reproducible input. Trigger the engine on „the move played
has fewer than ten master games" instead of on „the position is out of book" and
it saves less still — 11% — because by the time a move is genuinely rare the
position it stands in is already thin.

**As a source of sentences it is worth building, and that is what the numbers
show.** The French leaves theory at `4. c3`, played three times in 251 games;
the Philidor at `5. d4`, zero of 23. That is a real thing to say to a student —
*here you left what masters play* — and nothing in the tutorial can say it
today, because a depth-20 engine reports those moves as costing almost nothing.

**A share alone is not a rule.** `--min-share 0.10` fires at move 2 in two games
of three, because in any position with a dominant main line everything else is
under ten per cent by definition:

```
philidor  4  2. Nf3   289898 here  d6  6450 ( 2.2%)  RARE
```

`2... d6` is the Philidor Defence — the opening the game is named after, with
6450 master games behind it. It is rare only as a share of a position where
`2... Nc6` is played 86% of the time. So the probe takes `--min-games` as well,
and the honest formulation is two signals rather than one threshold:

 * **out of book** — the position has no master games at all. No threshold is
   needed and none should be invented.
 * **a thin move inside the book** — the move has few games *in absolute terms*.
   `openingJudgeService.js` already picked that number and wrote down why:
   `MIN_MASTER_GAMES = 10`, „low on purpose: a sideline played ten times by
   masters is a real line a child may meet".

And the threshold is only ever an engine-budget decision. The sentence — *251
master games reached this position and three of them played c3* — is worth
saying whatever the number is.

**The motif detector should be silent while the game is still in the book**
(owner, 13.9.2026), and the probe is what makes that measurable rather than a
matter of taste. Nineteen of the 32 in-book positions across the three games
carry a motif comment, and they read like this:

```
2. Nf3    The black pawn on e5 is attacked by the white knight on f3
          and has no defender.
2... d6   The black pawn on e5 is no longer hanging.
```

That is the second move of a Philidor. It is true of the squares and false of
the game — e5 is not hanging in any sense a student should learn — and the
detector then narrates the resolution of a threat that never existed. Two moves
earlier it says „White's pawns hold more of the centre" after `1. e4` and
„White's pawns no longer hold more of the centre" after `1... e5`. In the book
the statistics are the whole of what is worth sending: what is played here, how
often, and whether this move is one of them.

**The probe is built so that it cannot get this address blocked.**
`chess_backend/services/lichessPacing.js` already records what that takes — a
429 blocks the *address* for a minute, and knocking during that minute raises it
to an hour — so: one request every 1.2 s where a token allows fifteen a second,
**any answer that is not a 200 stops the probe**, never a retry, and every answer
kept in `out/_masters/<game>.json` so that `--report` can argue about a threshold
with no network at all. The masters endpoint answers **401** to an anonymous
caller, so it uses the server's own `LICHESS_API_TOKEN` — the allowance every
user of the app's opening panel shares, which is the reason for all of the above.

## How long the engine takes, and four ways to make it shorter — 13.9.2026

Analysing one game is 494, 532 and 710 seconds for these three — eight to twelve
minutes, and over 95% of everything the pipeline spends. Four ideas were
measured against that. **Three of them are recorded here because they failed**,
which is the only way to stop them being proposed again in a month.

### A shallow first pass — 1.4×, and it misses things

The idea: depth 12 over every position to find the candidate moments, depth 20
only on those and their lead-ins. Depth 12 really is that cheap — **5, 9 and 13
seconds for a whole game, 64× faster**. It still does not pay.

**The threshold has to be 0.35, not 0.5.** At 0.5 the shallow pass missed two
real moments in the Philidor, one of them badly: `39... Qc2+` costs 3.11 pawns
at depth 20 and depth 12 rates it **0.35**. At 0.35 nothing is missed in any of
the three games, but the flagged set grows to 17, 23 and 30 positions.

**And the lead-ins are the cost.** A moment needs its three lead-in positions
*and the row after it* — what a move cost is read from the next position's own
search — so five rows each, and with that many flagged the windows overlap into
41 to 62 of the 54 to 87 positions. Net: **1.3 to 1.6×**.

Taking the lead-in sentences from the shallow numbers instead reaches 2.0×
(869 s against 1736 s, nothing missed), and pays for it exactly where it hurts:
6 to 14% of move evaluations change category at depth 12, and they cluster in
the sharp positions, which are the lead-ins to the moments.

```
24... Qf6   deep "White is winning"  /  shallow "White is clearly better"
25. Rd7     deep "White is winning"  /  shallow "White is clearly better"
```

Both are lead-in moves of a moment that **both models chose** in game one.

### More engine threads — 3× *slower*

Sixteen logical cores, and `make_facts.py` uses one thread. Raising it is the
obvious free win, and it is not one. Eight middlegame positions, depth 20,
multipv 4, one engine process, nothing else running:

| threads | hash | seconds | a position |
|---|---|---|---|
| 1 | 128 MB | **33.8** | 4.22 s |
| 4 | 512 MB | 74.9 | 9.36 s |
| 8 | 1024 MB | 98.9 | 12.37 s |

Monotonically worse. Lazy SMP buys time-to-depth sublinearly at the best of
times, it buys least of all with `multipv` above one, and the helper threads
fill the shared table with lines the main thread is not going to need. **Threads
help at a fixed time, not at a fixed depth**, and this harness searches to a
fixed depth on purpose. A whole-game run at eight threads was abandoned after
passing 890 wall-seconds against the 494 that one thread takes.

### Positions in parallel, not the search — 2.2×, and it costs nothing

The same cores, spent the other way: one single-threaded engine per position.
Sixteen positions, depth 20, multipv 4, a fresh engine each:

| at a time | seconds | a position |
|---|---|---|
| 1 | 89.0 | 5.57 s |
| 4 | 50.9 | 3.18 s |
| 8 | **40.2** | 2.51 s |
| 12 | 40.7 | 2.54 s |

Flat after eight, which is this machine's physical cores. Every search stays
single-threaded at the same depth, so **every number comes out identical** —
this is wall clock bought with nothing sold. `build()`'s analysis loop is
already embarrassingly parallel: the costs are computed in a second loop, after
every row has its candidates.

### Depth 18 instead of 20 — 3.1×, and nothing that matters changes

The owner's suggestion, and the one that wins.

| | depth 20 | depth 18 | depth 12 |
|---|---|---|---|
| `pvladan_2026-09-12` | 494 s | **125 s** | 5 s |
| `french_2026-06-19` | 532 s | **217 s** | 9 s |
| `philidor_2026-07-03` | 710 s | **210 s** | 13 s |
| total | 1736 s | **552 s (3.1×)** | 27 s (64×) |

Speed is the easy half. What decides it is whether a shallower search changes
what a student is told, and it does not:

 * **Every position where depth 20 says the best move stands out — 54 of them,
   which is exactly the set a question may be asked from — has the same best
   move at depth 18. All 54.** Depth 12 gets 50.
 * **All nine questions the six tutorials actually asked come back with the same
   answer at depth 18.** Depth 12 changes two of them: `Ke3` becomes `Kg3` in
   the French and `Rf8` becomes `Rae8` in game one.
 * The moment *selection* moves on six positions across the three games, and
   every one of them is boundary noise around the 1.0-pawn threshold: 0.91
   against 1.11, 0.9 against 1.14, 1.06 against 0.88. Not one is a moment depth
   18 cannot see.

Depth 18 and parallel positions compound, and neither changes an answer: about
80 seconds a game against nine minutes now. **The two that sound clever — a
shallow first pass and more threads — are the two that cost quality or time.**

### What was adopted, and what it cost — 13.9.2026

Depth 18 is the default now, and the cores go into positions rather than into
the search: `--workers`, eight by default, each running its own single-threaded
engine. The three games were rebuilt at those settings.

| | before | after |
|---|---|---|
| `pvladan_2026-09-12` | 494 s | **49 s** |
| `french_2026-06-19` | 532 s | **80 s** |
| `philidor_2026-07-03` | 710 s | **88 s** |
| total | 1736 s | **217 s — 8×** |

Arm H ran end to end on the rebuilt facts: three CLEAN, every position exact,
every question the best move of the analysis sent.

**Every position is searched from an empty table now**, which is a change worth
naming rather than slipping in with the parallelism. The old build carried one
engine and one transposition table across the whole game, so what came back
depended on the order positions were searched in — fine while there was exactly
one order, and not a property to keep once there are eight. `game=object()` per
call makes python-chess send `ucinewgame`, so a facts file is a function of the
position, the depth and the engine, and of nothing else.

Both halves were measured rather than assumed, on one game at depth 18:

 * **One worker and eight give byte-identical candidates on all 54 positions.**
   That is the claim parallelism has to earn, and it earns it.
 * **53 of 54 positions differ from the old warm-table build**, and the
   differences are what an empty table looks like: `+0.31` against `+0.35`, and
   reorderings among moves within a tenth of a pawn in quiet opening positions.
   Seven of the eight positions where depth 20 says the best move stands out
   still agree; the one that does not is `27. Qxa8+`, where White is between
   seven and nine pawns up and the disagreement is over which of three losing
   defences lasts longest. All three questions this game's tutorials asked are
   unchanged.
 * Clearing the table cost no time at all — 111 s against the warm build's
   125 s on the same game, which is noise. A table full of one position's tree
   was not helping the next position.

**One visible consequence, and it is the position this file has argued about all
evening.** The French `Ke3` led by 0.53 at depth 20 and leads by 0.23 at depth
18, so it no longer *stands out* — the question is still asked and `Ke3` is still
the answer, but the move within a tenth of it is now offered as correct too. That
is the rule working: a student is not marked wrong for a move the analysis cannot
separate.

**And a run now records which analysis it was given.** `skeleton.stamp_of`
writes the game, depth, multipv and generation time into the run's `meta.json`,
and `check_positions.py` compares it with the file on disk:

```
NOT THE ANALYSIS THIS RUN WAS GIVEN - it was built from
  pvladan_2026-09-12 d20 mpv4 2026-09-13T17:09:00
and the file on disk now is
  pvladan_2026-09-12 d18 mpv4 2026-09-13T19:32:37
```

Without it, rebuilding the facts makes every old run read as a model that
changed the answer — the one accusation this harness must never make wrongly,
and the exact trap this rebuild would otherwise have set. Proved by tampering
with a stamp and watching it fire.

## The opening speaks for itself — 13.9.2026

The probe said the masters database is not worth building for the engine time it
saves. It is worth building for the sentence, and this is that. Three changes,
agreed with the owner before a line was written.

**The statistics go into the facts file, and the network is a build-time
dependency only.** `probe_masters.book_walk` is the one place that talks to the
explorer; `make_facts.py` calls it while walking a game, writes what comes back
onto the rows, and the file is self-contained afterwards. A facts file stays
what it became earlier tonight — a function of its inputs — and reading one
never touches a network. `--rebook` puts the statistics onto a file already
analysed, with no engine at all, which is the same rule as `--recost`: a game
once analysed is reused.

A row master games reached carries how many, the opening's name, the share of
them that played the move the trainer played, and the three most popular
alternatives. In words:

```
3. Bc4    48726 master games have reached this position, and 2.1% of them
          played Be7; the other moves played here are Bc5 52%, Nf6 44%,
          d6 1.3%. The opening is the Italian Game
5... O-O  11 master games have reached this position and not one of them
          played Re1; the other moves played here are d4 55%, d3 45%
```

**The engine still runs on every position.** Skipping the book was the other
half of the proposal and the measurement sent it back: it saves about twelve
seconds of an eighty-second run, and a move can be in the database and still
lose — the Fried Liver and Legal's mate are in every masters database there is.

**The motif detector goes quiet while the game is still theory**, and this was
measured before it was believed. Nineteen of the thirty-two in-book positions of
the first three games carried a motif comment, and on move two of a Philidor it
read „The black pawn on e5 is attacked by the white knight on f3 and has no
defender", then narrated that threat's resolution a move later. True of the
squares, false of the game. In the book what is worth saying is what is played
here, and how often. Twelve of thirteen, ten of ten and eight of nine positions
went quiet across the three games.

**„Left the book" is a fact about the move, not about the position.** The
probe caught the reason: in game one `6. Re1` was played by no master game at
all, and the position after it has one — reached by another move order. So
`left_book` is written on the first move nobody has played, which is the move
worth a sentence, and not on the first position nobody has reached.

### The finding that changed the shape

**On the three games the book reached a slot in one of three.** The statistics
belong to the first four to six moves; the moments a tutorial is built from are
in the middlegame, and a moment's lead-in reaches back only three plies. So the
agreed value — name the opening — arrived nowhere in two of three tutorials.

So there is one line about the opening in the prompt's header, beside the game
rather than beside a slot, because it is about the game:

```
The opening is the Italian Game: Hungarian Defense. 6. Re1 left the masters
database: 11 master games had reached that position and not one played it.
```

That is the one addition beyond what was agreed, and the reason is above. It
reached the first tutorial written with it immediately, in the description the
model chose: „Three moments from a **French Defense** game…". CLEAN, every
position exact, every question the best move of the analysis sent.

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
