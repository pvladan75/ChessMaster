# Review of `PLAN-ZAGONETKE-IZ-PARTIJE.md` — an independent second opinion

Written 24.9.2026 by Fable 5.1, at the owner's request, without the lead. Read
in the order the brief asked: `CLAUDE.md`, then §1, §2 and phase 0 of the plan,
then my own list of concerns (kept in my scratchpad, not in the repository),
then the rest of the plan, `PLAN-MOJE-PARTIJE.md` §1 and §9, and the code only
where a finding needed it. No engine was run. Every number below was
re-derived from phase 0's files by three scripts of my own (`rederive.mjs`,
`rederive2.mjs`, `deep_gm.mjs`, in my scratchpad); where I quote the plan
instead, I say so. No game link, player or account name appears here.

## 1. What I reviewed

- `git log -1 --oneline`: `0c009b6 docs: puzzle plan - A_gross 20, and tutorials on the same rule`
- `git status`: **both plans changed and uncommitted** (`M docs/PLAN-MOJE-PARTIJE.md`,
  `M docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`). I reviewed the working copy.
- Data: `d16.json` / `cand20.json` (the owner, 20 games, 1493 plies, 158
  candidates), `club_d16.json` / `club_cand20.json` (12 games, 1109 plies, 101
  candidates), `gm_d16.json` / `gm_cand20.json` (20 games, 1783 plies, 45
  candidates), and **`gm_deep.json`, complete** (143 positions at 16 / 20 / 24,
  finished 10:50). `mine_deep.json` was at 20 of 150 when I looked and the club
  deepening had not started; neither is used.

## 2. Verdict

The core is right and should be built as written: winning chances as the one
scale, the puzzle set before the mistake, `B` as the cut that makes a puzzle
answerable, the book for the opening, the tablebase with seven men, a review
that says how much it could not settle. The measurement is honest about its
own size, and the grids reconcile with the files to the last puzzle.

Four things I would change before phase 1. **The relative `A` is measured
inert on the puzzles** — on all three sets it moves the count by 0 to 4 of 33
— and where it does move something it is the review's `??` marks in the
player's worst games, which is the opposite of what a reader expects; its
stated motivation (a grandmaster's 6-point mistakes) is something no floor of
10 can see, only depth can. **Three missed short mates in the owner's own 20
games yield no puzzle** under the rules, though the judge already accepts any
mate. **The claim check does not refuse an invented move outside a question**,
and the puzzle's words are not a question. **The reveal cannot explain the
solver's own wrong move** in 20 of the owner's 33 puzzles, although the most
likely wrong move is the second line the candidate search already found.

And one measurement fact the plan should carry: in the grandmaster deepening
the loss still moves by up to 10 points between depths 20 and 24 in exactly the
positions that matter, and five of the walk's 23 marks at 15 vanish in a fresh
search at the same depth. The noise is a property of the position, not of the
depth, and the deepening's trigger should be disagreement, not nearness to a
floor.

## 3. Findings, ranked by how much they change what the user gets

### F1. A missed short mate is invisible or excluded — **new**

**Claim.** `W(mate) = 100` and `W(+800) ≈ 95`, so leaving a forced mate for a
crushing move loses 5–15 chances and never reaches `A`; and where two moves
mate, `W(second) = 100` and `B` is 0. Both rules exclude the archetypal puzzle.

**Evidence** (`rederive2.mjs`, item 3): the owner's games hold three mates in
five or fewer that were not played, all in one game — mate in 3 (played a move
at W 86.4, loss 13.6; second line W 87.4, so `B` fails too), mate in 4 (W 85.2,
loss 14.8; the second line also mates), mate in 2 (W 62.1, loss 37.9; the second
line also mates). Under §3 none is a puzzle and the first two are not even
marked. Club and grandmaster sets: none in five or fewer (the club set's eight
missed mates are in 7–19, in won endings, and should stay unmarked). The judge
already holds the rule this needs: `customPuzzleJudge.js:86-90` — a different
mate is still a mate.

**What goes wrong.** A review of the owner's game shows no `??` on a missed
mate in two, and the puzzle that every coach would make from it is never
offered. Phase 1b makes it worse: the tutorial today prices a missed mate as
`cost_pawns = 'mate'` (`game_facts.dart:291`, `costValue` → 10⁹), so it is
always a moment; on the chances rule it becomes a loss of 5–15 and drops out.
The parity fixtures will show those moments leaving, and that red is the
signal, not a fixture to regenerate.

**Change.** (i) A forced mate in at most `M` plies that the player did not play
is a moment whatever the loss; `M` about 5 (the owner's are 2–4; the club set's
7–19 are not puzzles). (ii) When the best move mates, `B` is measured against
the best **non-mating** move and the answer set is "any mate", as the judge
already has it; the exercise's `solution[0].accept` is a list today
(`exercise.js:143-149`).

**Gate.** Fixtures from the walk: the mate-in-2 with two mating moves is a
puzzle and either mate is right; the mate in 18 left for a mate in 20 is not a
moment; a mate in 3 left for a W 86 move is marked. By mutation on `M` and on
the non-mating second.

**Cost.** Nil for the count; where the top two lines both mate, one `multiPV: 3`
search on that position alone (2 of 1493 plies here) to find the non-mating
gap.

### F2. The relative `A` — **in the plan, but I disagree**

**Claim.** `A = max(A_floor, k · average)` does not change the puzzles on any
measured set, changes only the marks, and only downward in the player's worst
games; and the plan's reason for it — a grandmaster's mistakes that a fixed 15
does not see — is not something the formula can deliver, since the floor sits
above them.

**Evidence.** Puzzles at `B` 15, depth 20 (`rederive.mjs`, item k; the average
as the plan defines it in `rederive2.mjs`, item 1 — live positions, more than
one legal move, the worst move left out, "after the book" approximated by
ply > 16 since no book was loaded):

| | fixed `A` 15 | `k` 2, floor 10 | `k` 3, floor 10 | `k` 4, floor 10 |
|---|---|---|---|---|
| the owner | 33 | 34 | 33 | 29 |
| club | 20 | 21 | 21 | 20 |
| grandmasters | 5 | 5 | 5 | 5 |

The review's marks (criterion 1 alone, depth 16, `rederive2.mjs`, item 1):

| | fixed 15 | `k` 3, floor 10 | `k` 3, floor 15 | `k` 4, floor 15 | `A` across player-games at `k` 3 |
|---|---|---|---|---|---|
| the owner | 107 | 129 | 101 | 89 | 10.0 – 29.0 |
| club | 62 | 82 | 58 | 45 | 10.0 – 23.9 |
| grandmasters | 23 | 45 | 23 | 23 | 10.0 – 10.0 |

The median of the plan's own average is 3.6 / 2.8 / 0.9. At `k` 3 the floor
decides in half of the owner's games, in most club games and in every
grandmaster game (their `k · average` never exceeds 10.0). The formula's whole
effect is a higher bar in bad games: in the owner's worst games `A` is 19–29
and moves losing 15–25 are not marked. The grandmaster's "clear mistake" of
about 6 (the plan's number) is under every floor the plan considers; what
would see it is depth 24, where the noise may allow a floor near 5 — and
that is the deepening, not `k`.

**What goes wrong.** A reader sees a move losing 20 without a mark in one game
and a move losing 12 marked in the next, and cannot see why — the number that
decided it is nowhere on the screen. A weaker player (an average of 8 gives
`A` 24 at `k` 3) gets the fewest lessons from the game with the most to teach,
while *Max puzzles* with "worst first" already caps the count. The phase 1
gate's case "the same loss is a mistake for a low average and not for a high
one" tests a branch that no measured game reaches on the puzzle side. And §9 of
`PLAN-MOJE-PARTIJE.md` already uses "the floor and the deepening" for a habit,
not `k` — two rules for one idea.

**Change.** Ship `A = A_floor` with the floor from the deepening and *Max
puzzles* as the cap; keep the formula in the plan as an option to be measured
on a weaker sample before it is built (`sample.mjs` already takes an Elo band —
a 1200–1500 over-the-board band, 12 games, is about 40 minutes of walk). If it
is kept, the review dialog shows the standard it used per player ("average loss
3.6; marked from 11"), through the same function that decides.

**Gate.** The number shown equals the number used (one function, asserted on
the dialog); if the formula is dropped, the two cases that hold it are
rewritten openly, not deleted.

**Cost.** Negative: one parameter, one per-game statistic and its three
exclusions, and the "after the book" dependency go away.

### F3. The noise is per position, and the deepening should trigger on disagreement — **in the plan, partly; I disagree on the trigger**

**Claim.** §3 says the floor is "the noise of the depth" and quotes one number
(median 2.1, p90 5.2). The completed grandmaster deepening says the spread
depends on the loss and on the position far more than on the depth, and that
two agreeing depths are not final.

**Evidence** (`deep_gm.mjs`, 143 positions searched fresh at 16, 20 and 24):

| fresh depth-16 loss | n | 16 → 24, p10 / p50 / p90 | 20 → 24, \|p90\| | at 24: ≥ 15 | at 24: < 5 |
|---|---|---|---|---|---|
| [0, 5) | 72 | −2.1 / −0.2 / +2.6 | 2.8 | 0 | 63 |
| [5, 10) | 35 | −3.2 / −0.1 / +4.4 | 3.8 | **2** | 9 |
| [10, 15) | 13 | −2.6 / +2.7 / +9.9 | 8.4 | 6 | 1 |
| [15, ∞) | 18 | −7.3 / +3.5 / +14.6 | **10.0** | 16 | 1 |

- Repeatability: the walk's depth-16 value (hash kept within the game) against
  a fresh depth-16 search of the same position — |diff| p50 1.1, p90 3.7, max
  8.8; **5 of the walk's 23 losses ≥ 15 are under 15 when searched fresh**,
  none the other way. A mark at one depth is not repeatable at the margin.
- "Two consecutive depths agree on ≥ 15" and depth 24 says under 15: 2 of 18.
- Two of 35 moves in the [5, 10) band are ≥ 15 at depth 24 — candidates the
  plan's rule (≥ 10 at the walk's depth) never examines. The owner's [5, 10)
  band holds 154 moves, the club's 77, the grandmasters' 64 (`rederive.mjs`,
  item c).
- The gap holds better than the loss: of 6 positions with `B` ≥ 15 at depth
  20, none changed its best move at 24 and one fell under 10.
- The cost: two lines plus the played move, four engines at once — p50 2.9 s at
  16, 11.8 s at 20, **32.7 s at 24 (p90 94 s, max 505 s)**.

**What goes wrong.** A candidate far above the floor is "settled by the one
confirming search" (§3, item 2) — but the ≥ 15 band is where 20 → 24 moves by
10 at p90; the sharp positions are the unsettled ones, and they are the puzzles.
Meanwhile a quiet loss of 8 at depth 16 that is 16 at depth 24 is never seen.

**Change.** Deepen on **disagreement** — when the walk's value and the
confirming depth-20 value differ by more than the floor, or straddle `A` or
`B` — at every size of loss; take candidates from `A − 5` at the walk's depth,
not from `A`; order the deepening by closeness to the threshold so the budget
is spent where it decides; and require agreement of the two **deepest**
depths reached, not any two. Record `nodes` beside the depth for repeatability.
Keep the budget and the "N unsettled" sentence exactly as planned.

**Gate.** Pure tests on recorded values: a candidate whose 16 and 20 disagree
by more than the floor is deepened even at a loss of 40; one whose 20 and 24
agree is settled; the budget stops it and the count says so.

**Cost.** Engine time on the desktop: the owner's 20 games have 54 candidates
with a depth-20 loss in [10, 20) (`rederive2.mjs`, item 6); at a median of
about 10 s each on one idle engine that is about 30 s a game, with a long
tail. On a phone several times that — the budget is the product decision.

### F4. The claim check refuses an invented move only inside a question — **new**

**Claim.** §3a and phase 3 say the shared check "refuses a sentence that names
a move ... the facts do not hold". It does so only when `facts['question']` is
true, and then it refuses **every** move but the answer.

**Evidence.** `skeleton_assembly.dart:202-226`: the SAN regex and "names ..., a
move that is not the answer" sit inside `if (question)`. Outside a question the
check catches a printed evaluation, "wins" without gain, mate / fork / pin /
skewer / discovery / trap without the fact, and a wrong target square — not a
move name. A puzzle's explanation is shown after the reveal, names the answer,
the game's move and both lines, and is stored once, forever (§4).

**What goes wrong.** "Nf5 was threatening mate" with no Nf5 in either line is
kept with the puzzle. The phase 3 gate "a fake model that invents a move is
refused" goes red on the shared check as it stands, and the cheap way to make
it green is a copy.

**Change.** A third mode of the same function: every SAN in the text must be in
`best_line ∪ refutation_line ∪ {played}` (and, per F5, the second line). The
regex exists; the mode is a parameter.

**Gate.** A text naming only line moves is accepted; one naming a move outside
the lines is refused; the question mode still refuses the answer; by mutation
on the set membership.

**Cost.** Small.

### F5. The reveal cannot explain the solver's own move — **new**

**Claim.** §4 stores the best line and the game's move's line. The solver who
plays a third move — most likely the engine's second line — is shown a
refutation of a move they did not play.

**Evidence** (`rederive2.mjs`, item 5): in 20 of the owner's 33 puzzles the
game's move is **not** the second line, and the second line is a median 9.5
chances better than the game's move; across all 158 candidates 142 have a
third-or-worse move played. The second line's value and PV are in the
candidate search that decides `B` and are dropped. §4 keeps `W(second)` but
not its line.

**What goes wrong.** "Not quite", then "what was played" and "what was best" —
neither is the student's move. A puzzle must teach why *their* move is worse;
today's screen (`custom_puzzle_solver_screen.dart:521-522`) shows the solution
as text.

**Change.** Store `second_line` (a SAN list cut like the others) and show it
when the solver's move is the second move, labelled honestly ("holds less
because …", from W(second)); for any other move, say "no line for this move"
rather than borrow one — or, on the desktop, one search at the review's depth
at reveal time, budgeted.

**Gate.** Widget tests: the second move played shows the second line; a third
move shows the honest sentence and never the game's refutation under the
student's move; both at 360 × 640.

**Cost.** One more SAN list per puzzle; the optional search is the only engine
cost.

### F6. A search that times out is a silent gap — **new**

**Claim.** The plan refuses a two-line answer that comes back with one line. It
says nothing about an answer that does not come back at all, and the walker
today turns that into nothing.

**Evidence.** `game_analysis_walker_service.dart:95`: `timeout: 12 s`, and the
`catch` sets `eval = null, line = null` — the position is neither a mistake
nor in the average nor counted. In phase 0's walks, positions over 12 s at
depth 16 with two lines: 31 of the owner's, 86 of the club's, 52 of the
grandmasters' (`rederive2.mjs`, item 7; under four-engine contention, so
inflated — but a phone at the app's default depth 20 with two lines will pass
12 s in ordinary middlegames). The grandmaster deepening's slowest depth-16
search took 30 s.

**What goes wrong.** A review on a phone says "clean" about positions it never
judged — the oldest bug in this repository, in a new coat. The average behind
the relative `A`, if kept, is computed over the positions that happened to be
fast.

**Change.** The walk counts positions it could not judge and the dialog says so
beside the deepening's "unsettled"; a game with unjudged positions is never
"said to be clean"; a timeout in the walk is retried once at a lower depth
before it is given up, and is recorded with the depth it reached.

**Gate.** A fake analyzer that times out on one position: the count is 1, the
game is not clean, the position carries no mark. By mutation on the count.

**Cost.** Small.

### F7. `B` at least 10, and the same best move at both depths — **new, cheap**

**Claim.** A gap of 10 at depth 20 is where the answer stops moving; below it,
it does. A guard that costs nothing makes that a rule.

**Evidence** (`rederive2.mjs`, item 2; `rederive.mjs`, item e): the best move at
depth 20 differs from the walk's in 25 of the owner's 158 candidates, 13 of the
club's 101, 3 of the grandmasters' 45 — and in **0 of the 86** puzzles at `A` 15
/ `B` 10 across the three sets; at `B` 5 it differs in 2 of 127. The plan's
grid diagonal (`B = A`) reconciles with the files: 56 / 33 / 26, 36 / 20 / 9,
10 / 5 / 2.

**Change.** A puzzle whose best move at the walk's depth is not the best move
at the confirming depth is refused, whatever the gap — both values exist. `B`'s
lower bound is 10; the owner's examples page decides between 10 and 15.

**Gate.** A recorded pair with different best moves and a gap of 20 is not a
puzzle.

**Cost.** Nil.

### F8. The book: a count, and `A_gross` only on a deepened value — **in the plan, partly**

**Claim.** §3 already says "a master played it in a game or two is not proof"
and answers with `A_gross`. Two small things sharpen it.

**Evidence.** `openingBook.js:26-33`: a built file may have every single-game
row deleted, so "in the book" means played at least twice by 2200+ players,
ever; `applyMastersBook` keeps `games` and `share` per move
(`game_facts.dart:203-247`) and uses neither for `left_book`. The three owner
moves above 10 are at depth 16, where an opening evaluation is the least
settled of the game (1.g4 at 13.2, the plan's number).

**Change.** "In the book" = listed **and** at least `g` games or share `s` (to
measure: does any of the 52 games' book moves fall under it, and do the three
above 10). `A_gross` fires only on the deepened value, never on the walk's.

**Gate.** A move listed once with a walk loss of 25 and a deepened loss of 12
is not marked; the same at a deepened 22 is.

**Cost.** Nil.

### F9. Say how many engines ran beside every seconds figure — **measurement**

The walk's 981 s is wall time with **four engines of four threads on 16
logical CPUs**: the sum of the per-position times in `d16.json` is 3725 s
(`rederive.mjs`, item a), a median of 1.36 s a position under that load. The
club walk's per-position median is 1.72 s, its p90 8.95 s. The plan's "3.3 s a
position at depth 20, one engine" is consistent with the deepening's 11.8 s
median under four-way contention, but `cand20.json` carries no times, so I
could not check it. The app runs one engine, and its default review depth is
**20**, not 16 (`app_settings_service.dart:35`); the plan should say which the
owner's settings hold. One measured run on an idle desktop and one on the
phone, of one game end to end, is the number the time budget needs.

### F10. The words where the mistake did not lose — **new, low**

Of the owner's 33 puzzles, 10 leave the mover at W(played) ≥ 50 and 9 start
from W(best) ≥ 90 (`rederive2.mjs`, item 5): a win let go, not a loss. The
evaluation words already have levels; the reveal's fixed labels do not. "Its
refutation played out" is wrong where nothing is refuted — the line after the
game's move is then "how the advantage went". The label follows W(played).

### F11. Two numbers for "decided" — **new, low**

The only-move rule leaves out positions with W(best) ≥ 97 or ≤ 3 (`outside.mjs`);
the average uses 10 ≤ W(best) ≤ 90. One idea, two numbers (rule 12). Pick one.
My only-move counts without the book are 107 / 76 / 134; the plan's 124 for the
grandmasters excludes book positions — reconciled, not a discrepancy.

## 4. Decisions already taken

- **`A_gross` = 20** — agree; it never fires in 52 games, so its gate is
  synthetic, which is fine for a safety net. Fire it on the deepened value (F8).
- **The book's rule** — agree; add a minimum count (F8). "The first move out
  of the book judged like any other" is right; its puzzle's answer is "the
  theory move", and the words should say so with the count.
- **One fixed `B`** — agree that `B` is about the position. Lower bound 10, the
  same-best-move guard beside it (F7). Nothing in the data separates 10 from
  15; the examples page does.
- **The relative `A`'s formula** — disagree (F2). If kept anyway: the statistic
  is dominated by its tail (the plain mean 4.0, without the worst 3.1, trimmed
  by 10 % 1.7, median 0.6 — `rederive.mjs`, item k), so `k` means something
  different for each choice; say which, and show the number.
- **The only moves' default in the keep panel** (listed apart, unticked) —
  agree. For the player who found the move it is praise; as a puzzle it serves
  a different solver.
- **The deepening** — agree with the budget and the "N unsettled" sentence;
  disagree with the trigger and the candidate floor (F3).
- **"Nothing trivial", "one puzzle within 4 plies", "the clock is a fact"** —
  agree; the 6 / 0 / 0 near-duplicates reconcile.
- **Deleting the old puzzles, the side filter, both lines on the reveal, the
  words once at keep time, no Gemini** — nothing to change.
- **§7, "a larger sample"** — yes, but the cheaper version first: a weaker
  over-the-board band from the base the lead already samples, 40 minutes of
  walk, before a several-GB download. **"Calibration from use"** — yes, and
  add "too easy" to "unclear / unfair". **"The curve"** — agree it stays; it is
  a convention the owner calibrates through the examples, and the plan should
  say so in one line.

## 5. The measurement itself

- **Sizes.** 20 + 12 + 20 games; puzzles at `A` 15 / `B` 15 are 33 / 20 / 5;
  grid cells at `B` ≥ 20 hold 2–26. Nothing here supports a percentage to a
  decimal; the owner's examples page is the right gate and the plan says so.
- **Confounds.** Time control against level is named and the club set answers
  it in direction (51 against 65 ACPL on 24 and 40 player-games). The club set
  is the 12 games that finished first under four workers with the walk stopped
  at 39 minutes — the shorter ones by construction; say so. The owner's set is
  evenly spaced through the export with a 40-ply minimum (`measure.mjs`). No
  set below 1500 exists, which is where the relative `A` would act (F2).
- **Depth and threads.** Four threads per engine, four engines: not repeatable
  by design, and the walk keeps the hash within a game while the candidate and
  deepening searches clear it (`ucinewgame`), so "walk 16" and "fresh 16" are
  two instruments — measured at |diff| p90 3.7 on the grandmaster set, 5 of 23
  marks flipping (F3). The walk's own asymmetry, visible as negative losses
  where the played move was outside the top two, is small: 3–5 % of those
  rows, |p90| 0.6 / 2.1 / 0.8 (`rederive.mjs`, item b).
- **What the numbers support.** `B` as the cut, a floor of 10–15 at depth 16–20,
  the book's harmlessness (no book move loses 15 in 52 games), the near-
  duplicate and trivial rules, the only moves as a source for strong players:
  supported. The relative `A`: not supported by any measured set (F2). "Depth
  16 is safe for finding candidates": supported for `A` 15 with candidates from
  10 (7 rise, 2 fall, per set), **not** for a floor of 10 with candidates from
  10, and not in the [5, 10) band at depth 24 (F3).
- **Deepening 16 → 20 by set** (`rederive.mjs`, item d): the loss grows slightly
  with depth (p50 +1.5 / +0.6 / +1.5), the spread is widest on the grandmasters
  (|diff| p90 6.6 against 5.2 and 4.4): the quiet positions are the least
  settled, and they belong to the players with the fewest puzzles.

## 6. What only the owner can decide

1. Is a mistake in a bad game less of a mistake? The relative `A` says yes,
   and that is its only effect on the data (F2).
2. Is a puzzle's answer one move or one set? Any mate is already a set
   (F1), and the exercise store holds a list (`accept`).
3. A left mate in at most how many moves counts whatever the chances say —
   2, 5, 8? The owner's are 2–4; the club set's 7–19 are endings.
4. Should the review say, per player, the threshold it used?
5. The phone: a shallower review with a wider floor, or a longer one? The
   budget decides which positions stay unsettled (F3, F6).
6. Which depth does the owner's review actually run at — the app's default 20
   or the measured 16?
7. Should the solver's own wrong move be searched on the device at reveal
   time, or only named as unexplained (F5)?
8. A 1200–1500 sample before `k` is built, or `k` dropped until one exists?

## 7. What I did not verify

- The owner's and the club's deepening (not complete when I looked).
- The book's per-move counts for these games (no book loaded; "after the
  book" in my relative-`A` numbers is ply > 16 — the puzzle counts do not
  depend on it, the mark counts barely).
- The clocks (quoted from the plan and `outside.mjs`, not re-run).
- "3.3 s a position, one engine" (no per-position times in `cand20.json`).
- Lichess's coefficient in `W` (quoted).
- The tablebase code, the keep panel, the Python harness beyond its headers,
  and `masters_walk.dart` beyond its contract.
- Whether `analysisDepth` in the owner's settings is 16 or 20.
- Nothing in `lib/` or `chess_backend/` was run; the three scripts read JSON
  and `chess.js` only.

---

## The lead's grading (Opus, 24.9.2026)

Graded by machine, not by the report: every data claim re-derived by a script
of the lead's own (`grade_fable.mjs`, beside phase 0's files), with the real
masters book where the review approximated it by ply > 16; every code claim
read at the cited line.

| | claim | re-derived | verdict |
|---|---|---|---|
| F1 | three short mates missed in one of the owner's games, none reach a puzzle | 3 (mate in 3 lost 13.6, mate in 4 lost 14.8, mate in 2 lost 37.9 with a second mate); a fourth row is a mate in 1 answered by another mate, loss 0 | **holds**. One qualification: the judge's „a different mate is still a mate" covers only a move that mates at once; for a mate in 2–5 the other forcing first moves have to be listed in `accept` |
| F2 | the relative `A` barely moves the puzzles, moves only the marks | puzzles at `B` 15: owner 33 / 34 / 34 / 29 (fixed 15, `k` 2 / 3 / 4 with floor 10), club 20 / 21 / 20 / 18, grandmasters 5 in every column; marks owner 107 against 131 at `k` 3; grandmasters' `k · average` never above 10.0 | **holds** |
| F3 | the loss moves most where it is large; 5 of 23 walk marks vanish in a fresh search | the band table matches (one band 77 positions, not 72); walk against fresh depth 16 p90 3.6, 5 of 23 flip, none the other way; times 2.9 / 11.8 / 32.7 s at 16 / 20 / 24 under four engines | **holds** |
| F4 | the claim check refuses an invented move only inside a question | `skeleton_assembly.dart:202-226`: the move regex sits inside `if (question)` | **holds** |
| F5 | the game's move is not the second line in 20 of the owner's 33 puzzles | 20 of 33 (club 15 of 20, grandmasters 4 of 5) | **holds** |
| F6 | a search that times out becomes nothing | `game_analysis_walker_service.dart:95`: `timeout: 12 s`, and the `catch` sets both to null | **holds** |
| F7 | the best move changes between the walk and depth 20 in 25 / 13 / 3 candidates, in 0 of 86 puzzles at `A` 15 / `B` 10, 2 of 127 at `B` 5 | identical | **holds** |
| F9 | the app's default depth is 20 | `app_settings_service.dart:35` | **holds**. The plan's „3.3 s a position at depth 20, one engine" has no per-position times behind it in the files; it is re-measured on an idle machine, not carried |

The lead's view, finding by finding:

- **Adopt, technical, no owner decision needed**: F3 (deepen on disagreement,
  candidates from `A − 5`, agreement of the two deepest depths), F4 (a third
  mode of the one claim check), F6 (count what could not be judged; a game with
  such positions is never „clean"), F7 (`B` ≥ 10 and the same best move at both
  depths), F8 (a minimum count for „in the book", `A_gross` on the deepened
  value), F9 (every time figure says how many engines ran; one idle run), F10
  (the reveal's label follows `W(played)`), F11 (one number for „decided").
  Also the note on the club sample: the 12 games that finished first are the
  shorter ones by construction.
- **Adopt, with a number the owner sets**: F1 (a missed forced mate is a
  moment whatever the chances say — up to how many moves?), F5 (the second
  line stored and shown when the solver plays it; a third move said to be
  unexplained, or searched at reveal time on the desktop).
- **The owner's decision, and the lead now agrees with the review**: F2. The
  owner's thesis — a mistake depends on who played — is right, and the data
  says the part of it that works is the **floor and the depth**, not `k`: on
  the puzzles `B` does the cutting, and on the marks `k` only raises the bar in
  a player's worst games. The lead's recommendation is `A` = the floor from the
  deepening, *Max puzzles* as the cap, and `k` kept as a §7 option until a
  weaker sample (1200–1500, over the board, about 40 minutes of walk) shows
  what it would do there.

Nothing is written into the plan from this review until the owner has read it.
