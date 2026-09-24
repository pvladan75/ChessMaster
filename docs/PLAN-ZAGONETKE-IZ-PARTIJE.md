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
| What counts as a mistake (24.9.2026) | **not one fixed threshold**: the opening is judged by the masters book, and after it `A` is measured against the player's own average loss in that game — §3, „Relative to the player" and „The opening". The fixed `A` = `B` = 15 chosen the same morning is withdrawn |
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
1. **The player erred:** `W(best) − W(played) ≥ A`, where `A` depends on the
   player — see „Relative to the player" below.
2. **One move stands out:** `W(best) − W(second best) ≥ B`. The second best is
   the engine's second line in the same search. A position with **one legal
   move** is not a puzzle — there is nothing to find.
3. The played move is not the best (follows from 1).
4. The side is the one chosen in Blunder Alert's Both / White / Black.

`A` and `B` are **not guessed**: phase 0 measures them on the owner's games.
Starting points to measure around: `A` 15–25, `B` 10–20.

Ranking stays „worst first" but by `W(best) − W(played)`, and *Max puzzles*
still caps the count.

### Relative to the player

The owner, 24.9.2026: `A` must not be fixed, because what a mistake is depends
on who played. Phase 0 measured it (numbers there): the owner's Lichess blitz
at about 1900 loses **4.0** chances a move on average, grandmasters in
classical games **1.15**. A fixed `A` of 15 is the worst 7% of the owner's
moves and the worst 1% of a grandmaster's; a grandmaster's clear mistake, the
worst 5% of their moves, loses about 6 and a fixed 15 does not see it — 5
puzzles in 20 games.

So `A` is taken **from the game itself**, per player:

`A = max(A_floor, k · average loss per move of that player in that game)`

- the average is over that player's moves **after the book** (the book's moves
  are not that player's own judgement), from the review's own walk — no extra
  search;
- `k` says how many times worse than one's own average a move must be;
- `A_floor` keeps a clean game (a grandmaster averaging 0.3) from turning
  engine noise into mistakes.

**The floor is the engine's noise, and depth grows where it has to** (the
owner, 24.9.2026, on a near-perfect game): the parameters do not change while
the walk runs — the game sets them once the walk is done, and in a clean game
the average and with it `A` fall on their own. What stops them is `A_floor`,
and that floor is not a taste but the **noise of the depth** that judged the
loss: depth 16 against 20 differs by a median 2.1 and a 90th percentile 5.2
(phase 0), so at depth 16 a loss of 3 cannot be told from the engine's own
doubt. Hence, after the walk:

1. candidates by the relative `A`, as above;
2. a candidate whose loss stands well above the walk depth's noise is settled
   by the one confirming search already planned;
3. a candidate **near the noise** is searched again, deeper (20, then 24, …),
   and is a mistake only when two consecutive depths agree it lost at least
   `A`; one whose loss vanishes deeper was noise and is not marked;
4. the deepening stops when the loss is stable or a **time budget** for the
   review is spent — the positions left unsettled are not marked, and the
   dialog says how many.

Deep searches run only on those few positions, never on the game. A game in
which nothing survives is **said to be clean** („no mistake found at depth
N") — the bar is never lowered until something turns up: a puzzle made of
engine noise tells the student that a good move was a mistake.

`k` and `A_floor` are measured in phase 0 on three levels, not guessed;
`A_floor` as the noise at each depth, with the time each depth costs. `B` —
one move stands out — is about the **position**, not the player, and stays
one fixed number; phase 0 says whether that holds at every level.

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
   is common in blitz at 1900. A book move that loses at least `A_gross` at the
   shallow depth is marked all the same. `A_gross` is measured in phase 0.
4. **The book's facts go to the model**: the opening's name, the move with
   which the game left theory, what the masters play there and how often. The
   claim check admits them as facts.

A book that does not answer (guest, no file, timeout) is said, and the review
falls back to the engine alone — never a silent one (`walkMastersBook`
returns a reason, not an exception).

## 3a. The words for a whole review

The owner, 23.9.2026: the language model should also write the comments that
„Review entire game" puts into the PGN after the engine's walk.

- **Only the moments that matter** get words: the mistakes and missed chances
  the criteria of §3 find, with `A` alone (a mistake need not have one clear
  answer to deserve a sentence) — not every move. A sentence on a quiet move
  says nothing and is where a model invents most.
- **One request per review**, on the tutorial's path: the engine writes the
  facts, the model only the words, and the tutorial's claim check refuses a
  sentence that names a move or a size the facts do not hold. The per-move
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
named until the student has moved.

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
- Two lines at depth 20 cost about 3.3 s a position (one engine, 4 threads),
  so the second search runs on candidates only, as phase 1 says.
- No candidate lacked the played move's value or a second line.

The owner first chose `A` = 15, `B` = 15 (33 puzzles in 20 games, 17 of the 20
giving one to five), then **withdrew it the same day**: a fixed threshold means
„a mistake by the owner's standard", not by the player's. Measured next, the
same way, on 20 grandmaster games from the Lumbras base (both players 2550+,
classical, over the board, since 2000):

| | the owner (Lichess blitz, ~1900) | grandmasters (classical, ~2630) |
|---|---|---|
| ACPL per player-game, median (loss capped at 1000 cp) | 65 | 16 |
| chances lost per move, all moves | **4.0** | **1.15** |
| the same per player-game, p10 – p90 | 2.4 – 6.3 | 0.3 – 2.3 |
| moves losing ≥ 10 / ≥ 15 | 10.6% / 7.2% | 2.5% / 1.3% |
| the worst 5% / 2% of moves lose at least | 24.3 / 37.9 | 5.9 / 11.6 |
| puzzles at `A` 15, `B` 15 | 33 in 17 games | 5 in 3 games |

The grandmasters' grid at depth 20 (45 candidates, 233 s):

| A \ B | 0 | 5 | 10 | 15 | 20 | 25 |
|---|---|---|---|---|---|---|
| 10 | 37 | 21 | 10 | 5 | 2 | 2 |
| 15 | 29 | 16 | 9 | 5 | 2 | 2 |
| 20 | 14 | 7 | 6 | 4 | 2 | 2 |
| 25 | 8 | 5 | 5 | 3 | 2 | 2 |
| 30 | 6 | 4 | 4 | 2 | 1 | 1 |

The two sets differ in time control as well as in level, so a third set sits
between them: 20 club games from the same base, both players 1500–1800,
classical.

**Still to measure, and the gate of this phase**: the club set; then, on all
three, what `A = max(A_floor, k · average)` gives for a few `k` and `A_floor`
(puzzles a game, and the examples page for the owner to look at), whether one
`B` serves all three, and `A_gross` for a book move — how many book moves each
candidate would mark, with the book asked for the three sets' games; and the
deepening — every move of the three sets that lost 2 or more at depth 16,
searched at 16, 20 and 24: the spread between depths as a function of the loss
(the floor at each depth), how many small losses survive, and the seconds a
review would add. The owner chooses `k`, `A_floor`, `B`, `A_gross` and the
time budget from those.

### Phase 1 — the criteria in the app [implementer]

- `winningChances` (one home) and its test at the table's points.
- The book: the review asks `walkMastersBook` once for the game and marks the
  moves with `applyMastersBook` — both lifted to where the review and the
  tutorial import them, not copied. A book that does not answer is a reason the
  dialog shows.
- Each player's `A` from their own average loss after the book (§3).
- The deepening of §3: a candidate near the noise searched deeper until two
  depths agree or the time budget is spent; the dialog says how many were left
  unsettled, and a clean game is said to be clean.
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
- Both lines built (best: the candidate search's PV; refutation: the next
  moment's line) and cut by the shared `answerPlyCount`.
- `LocalPuzzle` holds the position **before** the mistake as its puzzle.

Gate: pure tests on built moments — the owner's example (+19/+14) is **not** a
puzzle, a slower mate is not, a book move is not unless it loses `A_gross`, the
same loss is a mistake for a player with a low average and not for one with a
high average, `A_floor` holds for a player whose average is near zero, a book
that did not answer leaves the engine's judgement and says so, a move is
marked `??` exactly when it passes criterion 1 (one function decides both), a position with one clearly best move that the
player missed is, one where two moves are equal is not, the side filter holds,
a search with one line in a two-move position is refused. Every rule by
mutation.

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

Gate: the claim check by mutation; a fake model that invents a move is refused;
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
- „What was best": the best move as an arrow, then its line.

The board steps through a line as the lesson viewer does, back and forward,
and returns to the puzzle's position. A puzzle with no `review` (every
non-game exercise) shows what it shows today.

Gate: widget tests at 360 x 640 and 1280 x 800 — nothing of the review before
the move; both lines play to their last move and back; a text that must be read
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
- The tutorial generator itself. It shares `answerPlyCount` and the claim
  check with this plan and is otherwise untouched.
- A puzzle rating or spaced repetition for these puzzles — they join the
  existing queue as exercises.
