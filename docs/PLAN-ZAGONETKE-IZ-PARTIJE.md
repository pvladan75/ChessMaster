# Puzzles from a game: before the mistake, one clear answer, and why

Written 23.9.2026 by the lead (Opus), from the owner's request of the same day.
**Nothing in code.** Each phase names who builds it and the gate that decides
it is done.

Every brief handed to a worker carries this sentence, in its method section:
*If you believe a test in the gate is wrong, stop and say so in the report — do
not work around it.*

Baseline to re-measure before phase 1, in a worktree: app **3908** (1 skipped),
backend **1684** without a database / **1820** with (derived, not measured
since 3h), `flutter analyze` the same 26 infos. Every phase ends with its
arithmetic in `docs/LESSONS.md` and the block in `CLAUDE.md` updated.

## 1. The request

The owner, 23.9.2026, paraphrased from Serbian, on the puzzles „Review entire
game" extracts with Blunder Alert and „Extract puzzles" on:

1. A puzzle needs **both**: one good move, or one move much better than every
   other — **and** the player played something else.
2. The puzzle starts **before** the mistake, not after it. The student is told
   that a mistake was made in this position and asked for the best move. Only
   after the student has moved is it shown what the player played and what
   should have been played — **on the board, with the line behind the best
   move**, as the automatic tutorial does. A puzzle must teach; the student must
   not be left not knowing why a move is good.
3. „Much better" is judged by what the difference means: **+19 against +14 is
   no difference at all.**

Decisions of the same day (asked, answered):

| | |
|---|---|
| The explanation | written by a **language model**, once, when the puzzle is kept, and stored with it |
| What the reveal shows | **both lines**: the one behind the best move, and the one that punishes the game's move |
| Puzzles already kept from reviews | **deleted** — they start after the mistake and hold none of the new data; counted first, deleted on the owner's yes |
| Blunder Alert's Both / White / Black | **applies to puzzles too** (today it is ignored for them) |
| Comments in the reviewed PGN | **the language model writes them too**, after the engine (the owner, the same day) — see §3a |
| What counts as a mistake (24.9.2026) | **not one fixed threshold**: the opening is judged by the masters book, and after it `A` is measured against the player's own average loss in that game — §3 and „The opening". The fixed `A` = `B` = 15 chosen the same morning is withdrawn. **The relative part is superseded the same day** by Fable's row below: `A` is the floor the depth allows |
| Automatic tutorials (24.9.2026) | **the same rule** — phase 1b, after the review has it |
| The lead's review of the system, measured on phase 0's data (24.9.2026) | **accepted by the owner**: an average that one blunder or a long decided finish cannot move (now in §7, with `k`), the only moves a player found as moments of their own, nothing trivial taught as a find, one puzzle for a chance missed several times, the clock as a fact, the tablebase with seven men or fewer (§3); two more measurements (phase 0); three options left open (§7) |
| Fable's review, `docs/REVIEW-ZAGONETKE-FABLE.md` (24.9.2026, graded by the lead) | **`k` dropped for now**: `A` is the floor the depth allows, and the relative formula waits in §7 for a sample of weaker players; **a missed forced mate in five or fewer is a mistake** whatever the chances; **the second line is stored** and shown when the solver plays it, any other move told it has no line; **the technical findings adopted** — the deepening triggered by disagreement, `B` ≥ 10 with the same best move at both depths, a minimum count for „in the book", `A_gross` on the deepened value, the claim check's third mode, an unjudged position counted, one number for „decided", the times labelled |
| An analysis already made (24.9.2026) | **one store of the engine's answers, by position**, shared by the review, the puzzles, the tutorials and the player's own tree: what it already knows deeply enough is not searched again (§3, „The engine's answers are kept") — the owner, on a game already analysed at depth 30 with two or three lines. An analysis read from a PGN file is an option in §7 |
| Quotas and prices | **not decided, and not to be decided by this plan**: nothing about plans or accounts has been worked out yet, and the owner's own usage-and-cost tracking is agreed but not built. This plan counts, and leaves every limit in the one table that already holds the others |

## 2. What exists, and what the puzzle path ignores

Measured by reading the code on 23.9.2026.

- **The tutorial generator already does most of this**
  (`tutorial_studio/services/game_tutorial/`): it asks its question on the
  position *before* the mistake (`skeleton_moments.dart:593`), shows the played
  move as an arrow and plays the best line as a sideline
  (`skeleton_moments.dart:645-672`), sizes that line with `answerPlyCount`
  (4 plies, longer while the side to move is still down material, capped at
  8), asks the engine for 4 lines a position (`kFactsMultiPv`), and even
  computes `best_stands_out` — which **nothing reads**. It does not play the
  refutation of the played move; `blunder_walk_screen.dart` does, from the
  tablebase only.
- **The puzzle path** (`local_puzzle_extractor_service.dart`,
  `keep_puzzles_panel.dart`): one engine line a position (`multiPV: 1` in the
  review's walk), a single criterion — the mover lost *threshold* pawns
  (default 2.0) — a mate counted as 100 minus its distance, so a slower mate is
  a two-pawn „blunder"; the position after the mistake; the side filter and
  Blunder Alert's „already decided" rule ignored; one answer move stored.
- **The exercise** (`custom_puzzles`, `services/exerciseAuthoring.js`): no
  field for the game's move, a line or an explanation. `solution` is limited to
  one step.
- **The solve screen** (`custom_puzzle_solver_screen.dart`, own exercises and
  homework alike) shows „Correct" / „Not quite" and, when wrong, the solution in
  text. `arrows: const []`.
- **No winning-chance scale exists anywhere** in the app or the server.

## 3. The criteria

### Winning chances, one home

`W(cp) = 50 + 50 · (2 / (1 + e^(−0.00368208 · cp)) − 1)`, in percent, from
the side to move — the curve Lichess fits to its games. A mate for that side is
100, against it 0, **whatever the distance**: a slower mate is not a mistake.

What it does to the owner's example and its neighbours:

| | W | W | gap |
|---|---|---|---|
| +19 against +14 | 99.91 | 99.43 | **0.5** |
| +5 against +2 | 86.31 | 67.62 | 18.7 |
| +3 against 0 | 75.11 | 50.00 | 25.1 |
| +1 against −1 | 59.10 | 40.90 | 18.2 |

One function, in one file, with its own test; the review, the extractor and the
tests all call it (rule 12).

### A moment becomes a puzzle when, in the position before the move

0. **The game has left the book** — see „The opening" below. A move the
   masters play is never a mistake and never a puzzle.
1. **The player erred:** `W(best) − W(played) ≥ A`, where `A` is the floor the
   engine's depth allows — see „What the depth allows" below — **or the player
   left a forced mate in five moves or fewer** („A missed mate" below).
2. **One move stands out:** `W(best) − W(second best) ≥ B`, `B` **at least
   10**, and **the best move is the same at the walk's depth and at the
   confirming depth** (below 10, or with the best move changing between the two,
   the answer is still moving — phase 0: 0 of 86 puzzles at `B` 10 changed it,
   2 of 127 at `B` 5). The second best is the engine's second line in the same
   search. A position with **one legal move** is not a puzzle — there is
   nothing to find.
3. The played move is not the best (follows from 1).
4. The side is the one chosen in Blunder Alert's Both / White / Black.

`A` and `B` are **not guessed**: phase 0 measures them on the owner's games.
Starting points to measure around: `A` 15–25, `B` 10–20.

Ranking stays „worst first" but by `W(best) − W(played)`, and *Max puzzles*
still caps the count.

### What the depth allows

The owner's thesis of 24.9.2026 was that `A` must not be fixed, because what a
mistake is depends on who played. Phase 0 measured it (numbers there): the
owner's Lichess blitz at about 1900 loses **4.0** chances a move, club players
at 1500–1800 in classical games **2.9**, grandmasters **1.15**; a fixed 15 is
the worst 7% of the owner's moves and the worst 1% of a grandmaster's.

The first answer was a relative threshold, `A = max(A_floor, k · the player's
average loss in that game)`. **Fable's review measured it inert, and the lead
re-derived it** (`docs/REVIEW-ZAGONETKE-FABLE.md`, F2): on the puzzles it moves
the count by 0 to 4 of 33 on every set, because `B` does the cutting; on the
marks it only **raises** the bar, and only in a player's worst games (at `k` 3
the owner's threshold reaches 22, so a loss of 20 goes unmarked there); and for
grandmasters `k · average` never passes 10, so the floor decides every one of
their games. What does depend on the player is **how small a loss the engine
can still vouch for** — and that is the depth, not `k`. **The owner, 24.9.2026:
`k` is dropped for now**, and waits in §7 for a sample of weaker players.

So `A` is **the floor the depth allows**: the smallest loss the confirming
search can tell from its own noise. It is measured, not chosen by taste —
depth 16 against 20 differs by a median 2.1 and a 90th percentile 5.2, and the
grandmasters' deepening shows the spread growing with the loss itself
(phase 0).

**The deepening triggers on disagreement** (the owner, 24.9.2026, on a
near-perfect game; the trigger from Fable's F3). After the walk:

1. **candidates from `A − 5`** at the walk's depth, not from `A`: two of 35
   grandmaster moves that lost 5–10 at depth 16 lost 15 or more at 24;
2. each candidate gets the confirming search already planned (two lines, and
   the played move alone);
3. it is **deepened when the two values disagree** — when the walk's and the
   confirming search's losses differ by more than the floor, or fall on two
   sides of `A` or `B` — **at every size of loss**: the large losses move most
   (the grandmasters' losses of 15 or more moved by 10 between depths 20 and 24
   at the 90th percentile), and the sharp positions are the puzzles;
4. a candidate is settled when **the two deepest depths reached** agree; the
   positions closest to the threshold are deepened first, so a limited budget
   is spent where it decides;
5. the deepening stops when everything is settled or a **time budget** for the
   review is spent — what is left unsettled is not marked, and the dialog says
   how many. The depth and the nodes of every settling search are recorded.

Deep searches run only on those few positions, never on the game. A game in
which nothing survives is **said to be clean** („no mistake found at depth
N") — the bar is never lowered until something turns up: a puzzle made of
engine noise tells the student that a good move was a mistake.

**A position the engine did not answer is not a clean one** (Fable, F6): the
walk today turns a search that passes its 12 seconds into nothing
(`game_analysis_walker_service.dart:95`). Such a position is retried once at a
lower depth, counted if it still fails, and a game with one is never „said to
be clean" — the dialog names the count beside the unsettled ones.

`B` — one move stands out — is about the **position**, not the player, and
stays one fixed number of at least 10; phase 0 says whether that holds at every
level, and the owner's examples page decides between 10 and 15.

The same `A` decides which moments get words (§3a): what counts as a mistake
is one rule for the comments and the puzzles alike — **and for the review's
own `??` and „Better move" marking** (`annotateNodeChain`, today a pawn
threshold from Blunder Alert's dialog, with a larger swing once the game is
decided): the owner, 24.9.2026. A move marked `??` is exactly a move the
words may comment on and a puzzle may be made from; the pawn threshold leaves
the dialog, and the „already decided" rule goes with it, since chances already
shrink a loss in a decided game.

### The opening: the book decides

The owner, 24.9.2026: the opening is judged by the statistics the server
holds, with a shallow engine beside them for gross errors — and the book's
facts serve the comments too.

It exists, in the tutorial generator: `POST /opening-explorer/masters-walk`
(a local SQLite book of over-the-board games, both players 2200+, the first 50
plies) through `walkMastersBook` (`masters_walk.dart`), and `applyMastersBook`
(`game_facts.dart`), which marks `book` on every move the masters played,
`left_book` on the first they did not, and up to three alternatives with their
counts. **The review uses those two, not a second copy** (rule 12).

1. **While the game is in the book, no move is a mistake** — even where the
   engine prefers another by a little: that is where it disagrees with theory
   and where a fixed threshold is noisiest.
2. **The first move out of the book** is judged by the engine as any other
   move; when it is a mistake, the masters' moves are the better choice the
   words may name.
3. **Beside the book, the engine still looks, shallowly**: „a master played
   it" in a position the book knows from a game or two is not proof, and „no
   master played it" is not a mistake — a 2200+ book does not know half of what
   is common in blitz at 1900. A book move that loses at least `A_gross` is
   marked all the same — judged on the **deepened** value, never on the walk's
   alone, since an opening evaluation at the walk's depth is the least settled
   of the game (Fable, F8). `A_gross` = **20** (phase 0; the owner, 24.9.2026).
4. **„In the book" needs a count**: a move is theory when the book lists it
   **with at least `g` games or a share of at least `s`** — the built file keeps
   every move played twice by a 2200+ player, ever, and `applyMastersBook`
   keeps `games` and `share` and reads neither. `g` and `s` are measured in
   phase 0.
5. **The book's facts go to the model**: the opening's name, the move with
   which the game left theory, what the masters play there and how often. The
   claim check admits them as facts.

A book that does not answer (guest, no file, timeout) is said, and the review
falls back to the engine alone — never a silent one (`walkMastersBook`
returns a reason, not an exception).

### With seven men or fewer, the tablebase decides

The review never asks a tablebase today (read 24.9.2026: no mention in
`game_analysis_walker_service.dart`, `game_review_dialog.dart` or
`local_puzzle_extractor_service.dart`), and with seven men or fewer the
engine's number is an estimate of something known exactly. There:

- a **mistake** is a move that makes the result worse (win → draw, draw →
  loss), whatever the engine's number says;
- an **only move** is the one move that keeps the result — `B` there is not a
  gap in chances but „no other move keeps it";
- a slower win is not a mistake, as a slower mate is not.

Asked through the tablebase code the app or the server already has
(`syzygy_tablebase_service.dart`, `services/tablebaseService.js`) — one of them,
not a third. A tablebase that does not answer leaves the engine's judgement and
says so. Measured small (phase 0): 106 such positions in 4 of the owner's 20
games, 4 losses of 15 or more and 1 puzzle among them, none in the club and
grandmaster sets — correctness where it applies, not volume.

### A missed mate

On winning chances a forced mate is 100 and a crushing position about 95, so
leaving a mate for a „good enough" move loses 5 to 15 — under any `A`. In one
of the owner's 20 games three short mates were missed (Fable, F1, re-derived):
a mate in 3 left for a move at 86 chances (a loss of 13.6), a mate in 4 (14.8),
a mate in 2 (37.9, with a second mating move beside it). None became a puzzle,
and the first two were not even marked. **The owner, 24.9.2026:**

- a **forced mate in five moves or fewer** that the player did not play is a
  mistake **whatever the chances say** — marked, commented, and a puzzle when
  criterion 2 holds as below. A longer mate left in a won ending is not (the
  club set's missed mates were in 7–19, all in endings already won);
- where the best move mates and so does another, `B` is measured against the
  **best non-mating move**, and **every first move that forces the mate is a
  correct answer** — listed in the exercise's `accept`, which is a list already
  (`exercise.js:143-149`). The judge's „a different mate is still a mate"
  (`customPuzzleJudge.js:86-90`) covers only a move that mates at once; a mate
  in two to five needs the list. Finding the second non-mating move takes one
  `multiPV: 3` search on that position alone.

A slower mate is still not a mistake: a mate in 3 played where a mate in 2
stood is a mate.

### One number for „decided"

A position is **decided** when `W(best)` is 97 or more, or 3 or less — one
constant, one home (rule 12; Fable, F11). The only moves below leave decided
positions out; nothing else in this plan needs the word.

### The only moves a player found

A near-perfect game has few mistakes, and lowering the bar would teach engine
noise. It still has **critical positions**: one move at least `B` better than
every other, and the player found it. Measured at depth 16 (phase 0), after
the book, outside decided positions and leaving out the trivial ones below:
**2.2 a game** in the owner's, **2.4** in the club set's, **2.6** in the
grandmasters' — in 17 of 20, 10 of 12 and 16 of 20 games. For grandmasters
that is ten times the mistake puzzles (0.25 a game), and it is what a master
game teaches: the move that holds, and why nothing else does.

- They are **moments of their own**: the words may give them a sentence (§3a),
  the tutorial may ask them (phase 1b), and they may be kept as puzzles with an
  instruction of their own — „The player found the only good move here. Find
  it." — never „a mistake was made".
- In the keep panel they are **listed apart from the mistakes and not ticked
  by default**: a review of one's own game is first about what went wrong.
  (A proposed default; the owner's live pass may move it.)
- A gap of `B` is far above the engine's noise, but the count was measured at
  depth 16; phase 0 confirms it at 20.

### Nothing trivial is taught as a find

A **recapture** on the square the previous move landed on, a move **out of
check**, or a position with **three legal moves or fewer** has an answer that
needs no finding. Measured: 54–56% of the only moves in all three sets, and 8
of the owner's 33 puzzles at `A` 15, `B` 15 (5 recaptures, 3 out of check).

- Never an only-move moment.
- Among mistakes, **ranked last**, so *Max puzzles* drops them first. The words
  may still say that a recapture was missed.

### A chance missed several times is one puzzle

Candidates by the same player in the same game within **4 plies** of each
other are the same chance missed again. Measured: 6 of the owner's 33 puzzles
(blitz), none in the two classical sets. They become **one puzzle — the first
of them**, where the chance appeared — and its words say how many moves it
stayed on the board.

### The clock is a fact, not a filter

Where the game has clocks (`[%clk]` in the PGN; `user_games.clocks` for the
archive), a moment's facts carry **the time the player had left and the time
the move took**, and the words may say so („played at once, with twelve
seconds left"). No mistake is dropped for time trouble: of the owner's puzzles
19% were made with under a tenth of the base time left against 12% of all
moves, and 26% in a second or less against 28% — not a distortion worth a
filter, but a reason the model should be allowed to name.

### The engine's answers are kept

The owner, 24.9.2026: a game already analysed — at depth 30, say, with two or
three lines — should not be searched again. Everything this rule reads of a
position is in such an analysis: `W(best)` and `W(second)` are its first two
lines; `W(played)` is the played move's own line when it is among them, and
otherwise the next position's best line turned round (as phase 0's walk does
it); the best, second and refutation lines are its PVs; a mate is kept as a
mate with its distance. Depth 30 is deeper than any depth the deepening
reaches, so such an answer is **settled** — what it cannot do is agree with a
second depth, and it does not have to.

Half of this exists. The tutorial keeps the engine's answers on the device
(`game_tutorial_io/facts_store.dart`): four lines a position, in a file per
game, keyed by the game, the depth and **the engine binary** — phase 0 of
`PLAN-SKELET.md` showed the answers are a function of exactly the binary. The
review does not read it, and runs a walk of its own with one line.

So there is **one store of the engine's answers, by position**, and every
reader asks it first:

- **the key is the position** (the first four FEN fields, as `fen_key`), and
  an entry says **which engine** (the binary, as today), **what depth** and
  **how many lines** it holds, with each line's value (a mate as a mate) and its
  PV;
- **an answer serves a question when its depth is at least the one asked and
  it holds at least as many lines**: a depth-30 answer with three lines serves
  the review's walk, the confirming search and the deepening at once; a
  depth-18 answer with four lines serves the walk, and the confirming search
  runs only where it needs more depth;
- a deeper answer **replaces** a shallower one for the same engine; an answer
  by another engine binary is kept apart and never mixed into the same
  judgement;
- its readers: the review's walk and its candidate searches, the puzzles'
  lines, the tutorial (whose per-game store becomes this one), the player's own
  tree (`PLAN-MOJE-PARTIJE.md` §9), and the Analysis panel, which **writes** what
  it has searched to the same depth with its lines when the player stops on a
  position long enough;
- **it is a cache and is treated as one**, as the tutorial's already is: a file
  that cannot be read is an empty store, not an error; clearing it costs time,
  never a result;
- one limit said plainly: the FEN does not hold the game's history, so a
  position inside a repetition, or near the fifty-move limit, is searched in
  its game and not taken from the store.

The review then says how much it searched: „23 positions from earlier
analysis, 41 searched".

**Sharpened the same day by Fable, and measured:**

- **The saving is within a game, not across games.** The middlegame never
  repeats; the opening does, but the book judges it and it is the cheapest part
  of the walk. On the owner's desktop the tutorial's store holds 13 games, 740
  positions, and only 18 of them appear in more than one game; of the 1493
  positions of phase 0's 20 games it holds 49, all in the opening (ply 12 at
  most, a median of 3). So the win is the review, the deepening, the puzzles
  and the tutorial **of one game** reading each other's answers — and each
  reader asks for what it needs: the review never walks at the tutorial's four
  lines just to feed it.
- **More than the last depth is kept.** A search reports its lines at every
  depth on its way (phase 0's measurement of that). The store keeps the last
  few, so „the two deepest depths agree" comes from the cache, and a depth-30
  answer from the Analysis panel carries its own history. Beside the depth an
  entry records **the lines asked, the threads, the nodes, and whether the hash
  was fresh** — a warm four-thread search and a fresh one differed by up to 3.7
  at the same depth in the grandmaster set.
- **The whole line is kept, and each reader cuts it.** Today a line is stored
  cut to six plies (`game_facts.dart:90`, `kFactsLineLength`) while the answer
  may run to eight (`maxAnswerPlies`); the engine hands back the whole PV at no
  cost. The owner, 24.9.2026: the lengths go up — the reveal shows **up to 12
  plies**, still stopping earlier where `answerPlyCount` says the point is
  made; the tutorial takes the same numbers in phase 1b, whose fixtures are
  regenerated anyway. Not unlimited: the tail of an engine line is its least
  searched part.
- **The store belongs to the account.** It lives in the app's support folder,
  and the fault fixed on 22.9.2026 was exactly a new account offered the last
  one's analysis. A position is not personal, but a position from a private
  game names the game. So the store is fenced by the same
  `AccountLocalState.epoch` as the drafts and wiped with them — a new account on
  the same device searches again.
- **The depth a review states is its smallest.** With answers of different
  depths, „no mistake found at depth N" says the **minimum** depth over the
  judged positions, and the same game reviewed on two devices may differ when
  one has a deeper store — the dialog says so rather than hide it. An answer is
  used only when it is **complete**: every line asked for, at the depth
  claimed, as `searchProblem` in `game_facts.dart` already demands.

## 3a. The words for a whole review

The owner, 23.9.2026: the language model should also write the comments that
„Review entire game" puts into the PGN after the engine's walk.

- **Only the moments that matter** get words: the mistakes and missed chances
  the criteria of §3 find, with `A` alone (a mistake need not have one clear
  answer to deserve a sentence), and the only moves the player found (§3) —
  not every move. Where the game has clocks, the time left and spent are among
  a moment's facts. A sentence on a quiet move
  says nothing and is where a model invents most.
- **One request per review**, on the tutorial's path: the engine writes the
  facts, the model only the words, and the tutorial's claim check refuses a
  sentence that names a move or a size the facts do not hold. **Today it
  refuses an invented move only inside a question** (`skeleton_assembly.dart:
  202-226`, Fable F4), and a review's words and a puzzle's explanation are not
  questions: the one check gets a **third mode**, in which every move the text
  names must be in the moment's lines — the best line, the game's move and its
  refutation, the second line. The per-move
  „Generate AI comment" (Gemini, one request and one quota unit per move, a
  key with about 20 requests a day) is not used for this. **No Gemini** in this
  plan at all — the owner, 23.9.2026; DeepSeek, as the tutorials.
- **The facts include the motifs.** As the tutorial sends them: the tactical
  and the positional sentence the detectors write for the position after a
  move (`motifs_after_played`, „on the board after it: …"), and the engine's
  evaluation as words (`evaluation_words.dart`), never as bare numbers. The
  claim check admits those sentences as facts the model may repeat.
- **The words go into the PGN**: on the game's move, on the „Better move" line
  Blunder Alert already inserts, and on the refutation line. A comment the
  owner wrote is **never overwritten**.
- **The puzzle explanations of §4 come from the same request** — the puzzle
  moments are a subset of the commented ones. A review costs one request,
  whether it keeps puzzles or not.
- **The engine's analysis is written whatever the model does.** A model that
  does not answer, or whose words the check refuses, leaves the PGN with the
  engine's lines and the dialog saying that no comments were written.
- A checkbox in the Review dialog, **„Comment key moments with AI", off by
  default**: a request that costs money is never made without a tick.

### Counting, without deciding

Built exactly as the tutorial's words are metered, so any later decision is a
change of numbers in one table and not of code:

- its **own** entitlement and counter, `ai_review_words`, one per review the
  model wrote for — never borrowed from `ai_tutorials` or `ai_comments`, so it
  can be priced, bundled with them or given away later without untangling;
- its **own** token counter, `ai_review_tokens`, every attempt counted, refused
  ones included, because the provider bills the attempt;
- the provider and the model named in the log line of every call, with its
  tokens — what the owner's cost tracking will need when it is built;
- its limits as **placeholders** in `QUOTAS`, beside the tutorial's and marked
  the same way. What the free plan gets is the one number that has to be
  written down; until it is decided it is the tutorial's (none), and the
  owner's own account is whatever tier it is tested on today.

## 4. What a puzzle holds

Stored with the exercise, in a new column `custom_puzzles.review JSONB`,
written once at keep time:

| field | |
|---|---|
| `played` | the game's move, SAN |
| `best_line` | the line behind the best move, SAN list, first move = the answer |
| `refutation_line` | the line after the game's move, SAN list, first move = the punishment |
| `second_line` | the engine's second line from the confirming search, SAN list, cut the same way — the move a solver is most likely to play instead (Fable, F5: in 20 of the owner's 33 puzzles it is not the game's move) |
| `words` | the language model's explanation, or absent (see phase 3) |
| `chances` | `W(best)`, `W(played)`, `W(second)` — what the words may say about size |

Lines are **SAN lists, not PGN**: the server has no PGN parser and must not grow
one (rule 13); `chess.js` replays a SAN list. Both lines are cut by the
tutorial's `answerPlyCount` — **lifted out to one shared home**, not copied.
**The writer reads its own work back**: the app replays both lines from the
position before it sends them, and the server replays them again before it
stores them; a line that does not replay is refused, loudly.

The instruction shown **before** solving must not give the answer away: „A
mistake was made in this position. Find the best move." The game's move is not
named until the student has moved. A mate puzzle's `accept` holds every first
move that forces the mate (§3, „A missed mate").

## 5. Phases

### Phase 0 — measure the thresholds [lead]

On 20 of the owner's own games (`D:\chess\lichess_pvladan_2026-08-29.pgn`, the owner's Lichess account), at the review's depth: every move
with its `W(best)`, `W(played)`, `W(second)` from a `multiPV: 2` search. Print
the moments that would become puzzles at a grid of `A` × `B`, the owner looks
at a sample of each, and chooses. Also measured: how many puzzles a game yields,
and what the extra search costs in seconds.

Two engine facts to check before trusting any number (from the code): the
native engine starts at `MultiPV 3` while the service believes it is at 1, so
`setMultiPV(1)` can be a no-op; and the returned lines are not sorted by
`multipv`. Sort by it; a search that returns fewer than two lines in a
position with two legal moves is **refused**, not read as „only move".

Gate: a table in this plan and the owner's choice of `A` and `B`.

**Measured 24.9.2026** — 20 games, 1493 moves, Stockfish 19. A walk at depth 16
(`multiPV: 2`, 981 s), then every move that lost ≥ 10 searched again at depth 20
(two lines, and the played move alone by `searchmoves`): 158 candidates, 632 s.
Puzzles in the 20 games at depth 20 (today's two-pawn rule marks 147):

| A \ B | 0 | 5 | 10 | 15 | 20 | 25 |
|---|---|---|---|---|---|---|
| 10 | 148 | 82 | 56 | 34 | 26 | 17 |
| 15 | 112 | 69 | 49 | **33** | 26 | 17 |
| 20 | 94 | 58 | 41 | 29 | 26 | 17 |
| 25 | 79 | 48 | 33 | 26 | 23 | 17 |
| 30 | 61 | 37 | 25 | 19 | 16 | 14 |

- `B` is the condition that cuts: at `A` 15 it takes 112 moments to 33.
- Depth 16 against 20 on `W(best) − W(played)`: median difference 2.1, 90th
  percentile 5.2 — finding candidates at the review's depth is safe.
- Two lines at depth 20 cost about 3.3 s a position (one engine, 4 threads) —
  **not re-derivable from the files**, which hold no per-position times for that
  search (Fable, F9); what the files hold is the deepening's: two lines and the
  played move, **four engines of four threads at once on 16 logical CPUs**, p50
  2.9 / 11.8 / 32.7 s at depth 16 / 20 / 24. Either way the second search runs
  on candidates only, as phase 1 says. Every time figure in this plan says how
  many engines ran beside it, and the time budget is set from **one game
  reviewed end to end on an idle desktop and on the phone**. The app's default
  review depth is **20** (`app_settings_service.dart:35`), not the 16 the walks
  used.
- No candidate lacked the played move's value or a second line.

The owner first chose `A` = 15, `B` = 15 (33 puzzles in 20 games, 17 of the 20
giving one to five), then **withdrew it the same day**: a fixed threshold means
„a mistake by the owner's standard", not by the player's. Measured next, the
same way, on 20 grandmaster games from the Lumbras base (both players 2550+,
classical, over the board, since 2000):

| | the owner (Lichess blitz, ~1900) | club (classical, 1500–1800) | grandmasters (classical, ~2630) |
|---|---|---|---|
| ACPL per player-game, median (loss capped at 1000 cp) | 65 | 51 | 16 |
| chances lost per move, per player-game, median | **4.0** | **2.9** | **1.15** |
| the same, p10 – p90 | 2.4 – 6.3 | 1.8 – 5.2 | 0.3 – 2.3 |
| moves losing ≥ 10 / ≥ 15 | 10.6% / 7.2% | 9.1% / 5.6% | 2.5% / 1.3% |
| the worst 5% / 2% of moves lose at least | 24.3 / 37.9 | 17.1 / 27.1 | 5.9 / 11.6 |
| puzzles at `A` 15, `B` 15 | 33 in 17 of 20 games | 20 in 9 of 12 games | 5 in 3 of 20 games |

The grandmasters' grid at depth 20 (45 candidates, 233 s):

| A \ B | 0 | 5 | 10 | 15 | 20 | 25 |
|---|---|---|---|---|---|---|
| 10 | 37 | 21 | 10 | 5 | 2 | 2 |
| 15 | 29 | 16 | 9 | 5 | 2 | 2 |
| 20 | 14 | 7 | 6 | 4 | 2 | 2 |
| 25 | 8 | 5 | 5 | 3 | 2 | 2 |
| 30 | 6 | 4 | 4 | 2 | 1 | 1 |

**The book** (`services/openingBook.js` read directly, the book the server
serves; a move is in it when the file lists it for the position, and the game
leaves it at the first move it does not):

| | the owner | club | grandmasters |
|---|---|---|---|
| plies in the book, median (min – max) | 8 (5 – 16) | 10 (3 – 18) | 24 (9 – 35) |
| book moves | 199 | 133 | 472 |
| a book move's loss at depth 16: median / p98 / max | 0.55 / 7.5 / 13.2 | 0.37 / 4.8 / 6.1 | 0.0 / 3.7 / 6.8 |
| book moves losing ≥ 10 / ≥ 15 | 3 / 0 | 0 / 0 | 0 / 0 |
| the first move out of the book, median loss | 4.1 | 4.0 | 1.0 |

No book move of 52 games loses 15. The three above 10 are the owner's — 1.g4
(223 master games), a Nc6 (13) and an e5 (7) — theory a relative `A` could
otherwise have marked. **`A_gross` = 20, the owner's choice of 24.9.2026**: a
safety net for a line the masters played once or twice, which in these games
never fires.

The two sets differ in time control as well as in level, so a third set sits
between them: club games from the same base, both players 1500–1800,
classical — 20 drawn, **12 measured**: they are long (up to 154 plies) and the
walk was stopped on the owner's word after 39 minutes, with 1109 plies done —
so the 12 are the ones that finished first under four workers, **the shorter
games by construction** (Fable).

The club set's grid at depth 20 (101 candidates, 416 s):

| A \ B | 0 | 5 | 10 | 15 | 20 | 25 |
|---|---|---|---|---|---|---|
| 10 | 93 | 55 | 36 | 21 | 10 | 7 |
| 15 | 66 | 42 | 28 | 20 | 10 | 7 |
| 20 | 48 | 32 | 22 | 17 | 9 | 7 |
| 25 | 34 | 26 | 20 | 15 | 8 | 7 |
| 30 | 21 | 17 | 14 | 10 | 7 | 7 |

**What the club set says**: players rated 1500–1800 over the board, in
classical games, play **more accurately than the owner at about 1900 in
Lichess blitz** — ACPL 51 against 65, 2.9 chances a move against 4.0. The time
control moves accuracy as much as the rating does. So `A` is taken from the
game itself and never from a rating: a rating does not know whether the game
was blitz or classical, or a good day or a bad one.

**Outside the plan, measured 24.9.2026** on the same walks (depth 16), the
lead's review of the system (`outside.mjs`, beside the phase's other scripts):

| | the owner | club | grandmasters |
|---|---|---|---|
| average loss a move after the book, per player-game (median) | 4.4 | 3.3 | 1.4 |
| … leaving out the single worst move | 3.2 | 2.4 | 0.9 |
| … in live positions only (`10 ≤ W(best) ≤ 90`) | 5.3 | 4.0 | 1.5 |
| player-games where the worst move carries > 25% of the average | 48% | 42% | 63% |
| player-games where the live-only average differs by > 25% | 43% | 50% | 28% |
| puzzles at `A` 15, `B` 15 within 4 plies of another by the same player | 6 of 33 | 0 of 20 | 0 of 5 |
| … whose answer is a recapture / out of check / ≤ 3 legal moves | 8 of 33 | 1 of 20 | 1 of 5 |
| only moves found (gap ≥ 15, played), all | 107 | 76 | 124 |
| … trivial (recapture / out of check / ≤ 3 legal moves) | 60 | 41 | 70 |
| … neither trivial nor in a decided position, a game | 2.2 (17 of 20 games) | 2.4 (10 of 12) | 2.6 (16 of 20) |
| positions with seven men or fewer | 106 in 4 games | 44 in 6 | 61 in 2 |
| … moves there losing ≥ 15 / puzzles | 4 / 1 | 0 / 0 | 0 / 0 |

The owner's clocks (18 of the 20 games carry them): under a tenth of the base
time left before 12% of all moves, 15% of the moves losing 15 or more, 19% of
the puzzles; a move made in a second or less 28%, 16% and 26%. And the
owner's Lichess export carries no `%eval` — Lichess's own analyses are not in
it.

**Still to measure, and the gate of this phase**: on all
three, what the floor gives at each depth (puzzles a game, and the examples
page for the owner to look at), whether one `B` of at least 10 serves all
three, **the book's minimum count** — how many of the 52 games' book moves are
listed with fewer than `g` games or a share under `s`, and whether the owner's
three book moves above 10 are among them; and the deepening — the
moves that lost 2 or more at depth 16 (a sample from each set: 120 that lost
under 15 and 30 that lost more; the grandmasters have only 23 above 15), searched fresh at 16,
20 and 24: the spread between depths as a function of the loss (the floor at
each depth), how many small losses survive, and the seconds a review would
add. Three more, from the lead's review:

- **what every search already says on its way**: the engine reports its best
  line at every depth before the last (`info depth N`), and today everything
  but the last is thrown away. Recorded, it answers two questions at no extra
  search — whether the loss over the walk's own last few depths predicts the
  deeper value (so a candidate could be settled without a new search, which
  would make the deepening cheap), and **the depth at which the best move
  appears and stays**, a difficulty for every puzzle (found at depth 4: an easy
  tactic; at 18: a hard one);
- **repeatability**: the same position searched twice with four threads, and
  with one thread and a node limit instead of a depth; and the walk's depth-16
  value against a fresh depth-16 search of the same position (the deepening
  run records both) — the part of the noise that is not depth, and whether the
  same game reviewed twice would be marked the same;
- the only moves found (§3), counted at depth 16, **confirmed at 20**.

The owner chooses `A` (the floor), `B` (10 or 15), the book's minimum and the
time budget from those (`A_gross` is chosen, above; `k` is dropped for now).

### Phase 1 — the criteria in the app [implementer]

- `winningChances` (one home) and its test at the table's points.
- The store of §3, „The engine's answers are kept": one home, by position, with
  engine, depth and lines; the review's walk and candidate searches ask it
  first and write to it; the dialog says how many positions came from it.
- The book: the review asks `walkMastersBook` once for the game and marks the
  moves with `applyMastersBook` — both lifted to where the review and the
  tutorial import them, not copied. A book that does not answer is a reason the
  dialog shows.
- `A` as the floor the depth allows (§3, „What the depth allows"); a forced
  mate in five or fewer left by the player is a mistake whatever the chances,
  its `B` against the best non-mating move, and every mating first move
  accepted; `B` at least 10 and the same best move at both depths; one constant
  for „decided".
- „In the book" with the minimum count; `A_gross` on the deepened value.
- A search the engine did not answer: retried once lower, then counted; a game
  with one is never clean.
- The tablebase with seven men or fewer (§3): a mistake worsens the result, an
  only move keeps it, a slower win is not a mistake; one that does not answer
  leaves the engine and says so.
- The only moves found (§3) as moments of their own; the trivial ones (a
  recapture, out of check, three legal moves or fewer) never, and ranked last
  among mistakes; candidates of one player within 4 plies made one puzzle, the
  first; the clock's time left and spent among a moment's facts.
- The deepening of §3: candidates from `A − 5`; deepened when the walk and the
  confirming search disagree, at any size of loss, the closest to the
  threshold first; settled when the two deepest depths agree or the budget is
  spent; the dialog says how many were left unsettled, and a clean game is
  said to be clean.
- `annotateNodeChain` marks `??` and „Better move" by the same rule (criterion
  1 and the book), not by pawns; the dialog's pawn threshold is removed (its
  only readers, 24.9.2026: `game_review_dialog.dart` — the slider „Blunder
  threshold: N pawns" and the two calls it feeds — and
  `local_puzzle_extractor_service.dart`; no test and nothing under `site/`
  quotes the label), and
  every test that held the old threshold is rewritten openly, not deleted.
- The extractor: candidates from the walk by criterion 1, then **one
  `multiPV: 2` search per candidate position** only (not every position — the
  walk stays as it is), criterion 2, the side filter, the ranking.
- The three lines built (best and second: the candidate search's two PVs;
  refutation: the played move's own search) and cut by the shared
  `answerPlyCount`.
- `LocalPuzzle` holds the position **before** the mistake as its puzzle.
- `answerPlyCount`'s cap and the stored line's length raised as §3 says (the
  store keeps the whole PV; the reveal cuts at 12).

Gate: pure tests on built moments — the owner's example (+19/+14) is **not** a
puzzle, a slower mate is not, a mate in 3 left for a move at 86 chances is a
mistake and a mate in 18 left in a won ending is not, a mate in 2 with two
mating moves is a puzzle and either mate is right, a book move is not unless its
deepened loss reaches `A_gross`, a move the book lists once is not theory, a
recorded pair with different best moves at the two depths is not a puzzle
whatever its gap, a candidate whose walk and confirming values disagree is
deepened even at a loss of 40 and one whose two deepest depths agree is
settled, a fake analyzer that times out on one position leaves a count of 1
and a game that is not clean, a position the store holds at depth 30 with two
lines is not searched again and one it holds at depth 12 is, an answer by
another engine binary is never read, an incomplete answer is never read, a
torn store file is an empty store, a store written before a sign-out is not
read after it, a review whose positions came from depths 30 and 20 says 20,
a stored line is the whole PV and the reveal cuts it at 12, a book that did not answer leaves the engine's judgement and says so, a move is
marked `??` exactly when it passes criterion 1 (one function decides both), a position with one clearly best move that the
player missed is, one where two moves are equal is not, the side filter holds,
a search with one line in a two-move position is refused; one blunder does not
a recapture is never an only move and is the first
mistake *Max puzzles* drops; two candidates three plies apart by one player
are one puzzle, the first; in a seven-man position a slower tablebase win is
not a mistake and a win given away for a draw is, however small the engine's
number. Every rule by mutation.

### Phase 1b — the tutorial on the same rule [lead, then implementer]

The owner, 24.9.2026: automatic tutorial generation adopts the rule of §3.
Today it keeps a moment when the move cost `minCost` pawns (1.0 by default,
the trainer's slider), the eight most expensive by pawns, asks a question when
at most three moves are within 0.3 pawns of the best, lets a book move become
a moment, and has one fixed depth. Measured on phase 0's walks (depth 16,
mates left out, so a floor): of the moments a tutorial would keep, **13 of 138**
in the owner's games and **15 of 70** in the grandmasters' are moves after
which the chances barely changed (under 5) — the +19 against +14 of §1, ranked
high because a decided position makes a big pawn cost mean nothing.

- **A moment is a move that passes criterion 1 and the book** — the same
  function as the review's, imported, not copied (`heavyIndices` calls it), and
  ranked by chances lost. The deepening of §3 applies to its candidates, and a
  clean game is said to be clean.
- **The only moves a player found are moments too** (§3) — for a master game
  the main source, 2.6 a game against 0.25 mistakes — asked with the
  tutorial's own question, the trivial ones never.
- **The question keeps accepting several answers**: up to three moves still
  count as correct, but „near the best" is measured in chances, not 0.3 pawns.
  No `B` here — a tutorial may accept alternatives, a puzzle may not.
- **The trainer's slider** is in chances lost, starting at `A` (the floor),
  and still shows how many moments it gives while it is dragged
  (`mistakeCount`, the one count).
- `best_stands_out`, computed and never read, is either read by this rule or
  deleted — not left.
- **The harness moves with it**: `tools/game_annotate/make_facts.py` and
  `skeleton.py` learn the same rule, and the fixtures under
  `test/fixtures/game_tutorial/` are regenerated by `export_fixtures.py`. The
  parity tests going red on the old fixtures is the expected red, not a reason
  to loosen them; every changed fixture is diffed and the moments that left or
  came are listed in `LESSONS.md`.
- **The tutorial's per-game store becomes the store of §3**: its answers kept
  by position, so a game reviewed first builds its tutorial with the engine
  only where the tutorial needs more (four lines where the review kept two),
  and the reverse. The byte-identical facts of `PLAN-SKELET.md` phase 0 still
  hold, because the key still names the binary.
- Tutorials already made are stored lessons and are not touched.

Gate: the parity tests green on regenerated fixtures, with a case per rule —
a +19/+14 move is not a moment, a book move is not unless it loses `A_gross`,
two moves near the best in chances are both accepted, the slider's count and
the moments it gives are the same number; every rule by mutation, on both
sides of the harness.

### Phase 2 — the stored review [lead]

Schema is the lead's: `custom_puzzles.review JSONB`, the writer
(`exerciseAuthoring.js`) replays both lines from `fen` with `chess.js` and
checks that `best_line[0]` is the solution's move; the one reader
(`services/exercise.js`) hands `review` to the owner of the exercise **and to a
student only after that student's attempt** — the attempt's response carries
it, never `GET` before solving. Homework the same.

Gate: route cases on the real-database half — a line that does not replay is
refused, a `review` never reaches a student before the attempt, one that is
kept round-trips byte for byte.

### Phase 3 — the words for a review [lead, then implementer]

§3a. A server route beside `routes/gameTutorialWords.js` (DeepSeek), taking the
facts of every moment worth words — the position, the game's move and its
line, the best move and its line, the chances in words
(`evaluation_words.dart`'s levels, sent as words), material won or lost along
each line, the motif the detector names — and answering one text per moment.
The tutorial's **claim check** (`claimsFor`) is shared, not copied: a sentence
that names a move not in the facts, or a size the chances do not support, is
refused rather than written. Metering as in §3a.

In the app: the checkbox, the words written into the PGN (never over a comment
already there), and each kept puzzle's `words` taken from its moment.

When the model does not answer, the review still writes the engine's analysis
and the puzzles are still kept, **and both say that no words were written** —
never an empty space that looks like one.

Gate: the claim check by mutation, in its third mode too — a text naming only
the moment's line moves is accepted, one naming a move outside them is
refused, the question mode still refuses the answer; a fake model that invents
a move is refused;
the two counters counted on a refused attempt as on an accepted one; an existing
comment survives a review; with the box unticked no request is made (asserted
on the client seam, rule 7).

### Phase 4 — keeping [implementer]

`puzzleExerciseDraft` sends the position before the mistake, the instruction of
§4, the answer, `review`; „Keep N as exercises" asks for the words as it keeps.
The panel lists each puzzle as it will be solved: the position before, „a
mistake was made here", and only in the panel's own detail the move played.

Gate: the draft's request asserted on the client seam (rule 7); a puzzle whose
line does not replay cannot be ticked.

### Phase 5 — the reveal [implementer]

On the solve screen, own exercises and homework alike, after the verdict —
right or wrong:

- the explanation;
- „What was played": the game's move as an arrow, then its refutation played
  out move by move;
- „What was best": the best move as an arrow, then its line;
- **the solver's own move**: when it is the engine's second line, that line,
  labelled as what it is („holds less: …", from `W(second)`); when it is
  neither the best, nor the game's move, nor the second, the sentence „no line
  for this move" — **never another move's refutation shown under the solver's
  move**.

The label over the game's move follows `W(played)` (Fable, F10): where the
game's move still left the player better (10 of the owner's 33 puzzles), its
line is „how the advantage went", not „its refutation".

The board steps through a line as the lesson viewer does, back and forward,
and returns to the puzzle's position. A puzzle with no `review` (every
non-game exercise) shows what it shows today.

Gate: widget tests at 360 x 640 and 1280 x 800 — nothing of the review before
the move; every line plays to its last move and back; the second move played
shows the second line, a third move shows the sentence and never the game's
refutation; a text that must be read
is measured (`didExceedMaxLines`), not only „fits".

### Phase 6 — the old puzzles [lead]

Count the `origin = 'mistakes'` rows, report, delete on the owner's yes.

### Phase 7 — the owner's live pass

A TODO-provera item: review one of the owner's games, keep two puzzles, solve one
right and one wrong, both lines, the words.

## 6. Not in this plan

- Puzzles of more than one move („find the next three"). The exercise model
  holds one move since `PLAN-EXERCISE.md` §10; the line after it is shown, not
  asked.
- The rest of the tutorial generator. It shares `answerPlyCount`, the claim
  check and, from phase 1b, the rule of what a mistake is; its words, parts
  and narration are untouched.
- A puzzle rating or spaced repetition for these puzzles — they join the
  existing queue as exercises.

## 7. Weighed on 24.9.2026, not decided

From the lead's review of the system and Fable's; none is in any phase until
the owner says so.

- **The relative `A`**, `A = max(floor, k · the player's own average)` — dropped
  for now (§3). If it comes back: measured first on a sample of weaker players
  (1200–1500, over the board, from the same base; about 40 minutes of walk),
  where it might act; its average taken over live positions without the
  player's worst move, as measured in phase 0 („Outside the plan"); and the
  review showing each player the threshold it used, through the one function
  that decides („average loss 3.6; marked from 11").

- **A larger sample.** Four parameters from 52 games, and one player's own —
  thin. Lichess's open database holds hundreds of thousands of games a month
  with Lichess's own evaluations, clocks and ratings; the puzzle import already
  streams those files (`zlib.zstd*`). It would test the floor, `B` and a returning `k` across
  rating and time control without our engine. Cost: a download of several GB.
- **Calibration from use.** An „unclear" / „unfair" / „too easy" tap after a
  puzzle,
  storing the puzzle's own numbers (loss, gap, depth, difficulty): the owner's
  solving would then set `A` and `B` better than any page of examples.
- **The player's own repertoire as a third voice in the opening.** After the
  masters' book and the engine: „here you left your own repertoire" — a join
  on `fen_key`, which `repertoire_moves` and `opening_nodes` already share.
- **An analysis read from a PGN file.** Today the app drops `[%eval]` when it
  reads a PGN (`move_tree.dart`), on purpose. Lichess writes one number a move:
  no second line and no depth — enough for the `??` marks and the words, not for
  a puzzle's `B`, which would still need its candidate search. ChessBase and
  Fritz write analyses as variations with comments in formats of their own.
  And a file that says „depth 30" cannot be checked. If it is ever read, it is
  labelled „from the file, depth unknown" and never stands in for a puzzle's
  confirming search.
- **Weighed and not changed: the curve itself.** `W` is Lichess's curve for
  its own players; a +3 converts more surely for a grandmaster than at 1200.
  Calibrating it by level is second order once `A` is taken from the player's
  own game, and a second curve is a second thing to keep true.
