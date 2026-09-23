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

1. **The player erred:** `W(best) − W(played) ≥ A`.
2. **One move stands out:** `W(best) − W(second best) ≥ B`. The second best is
   the engine's second line in the same search. A position with **one legal
   move** is not a puzzle — there is nothing to find.
3. The played move is not the best (follows from 1).
4. The side is the one chosen in Blunder Alert's Both / White / Black.

`A` and `B` are **not guessed**: phase 0 measures them on the owner's games.
Starting points to measure around: `A` 15–25, `B` 10–20.

Ranking stays „worst first" but by `W(best) − W(played)`, and *Max puzzles*
still caps the count.

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

### Phase 1 — the criteria in the app [implementer]

- `winningChances` (one home) and its test at the table's points.
- The extractor: candidates from the walk by criterion 1, then **one
  `multiPV: 2` search per candidate position** only (not every position — the
  walk stays as it is), criterion 2, the side filter, the ranking.
- Both lines built (best: the candidate search's PV; refutation: the next
  moment's line) and cut by the shared `answerPlyCount`.
- `LocalPuzzle` holds the position **before** the mistake as its puzzle.

Gate: pure tests on built moments — the owner's example (+19/+14) is **not** a
puzzle, a slower mate is not, a position with one clearly best move that the
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
