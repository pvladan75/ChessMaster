# Narration — a game tutorial told as the story of a fight

Written 14.9.2026, from the owner's live review of „The bishop pair and the open
e-file (whole game)" (saved lesson 57, its PGN in the owner's
`D:\chess\tutorijal\tutorijal_primer`). Measure first, then build: the words
come from a model, and whether a change of prompt reads better can only be
judged by reading what the model writes with it.

## What the owner reported

1. **The same sentence shape on every move.** „Black plays Qc7, the queen from
   d8 to c7." The board is already playing the move while it is read; saying
   it twice (in notation and in words) is what makes the whole tutorial sound
   like a list.
2. **„The board just before these moves, with Black to play. Material is
   level."** — a sentence with no meaning for a listener. It is the model
   rewording `mN.lead.intro`, whose fact is literally „the board before these
   moves (Black to move); material White minus Black is +0 before them and +0
   after them".
3. **The order at a mistake.** Today: lead-in → question → „White had something
   better here; the game went Bd3…" → best line → back to the game. The
   student hears about the best line before seeing what was played. Wanted:
   - at the position where it went wrong: „In this position White played Bd3."
     with the move drawn as a **blue arrow**, not played; then „The best move
     was…" and the part ends;
   - the next part plays the best move and its line;
   - (the next-best move, where there is one);
   - back to that position, and the game move is played.
4. **Narration, not captions.** „Chess is a fight." What is spoken, taken
   together, should read as a story.
5. **The core of a comment is the turning points.** A game has swings, and
   chances that one side hands the other and the other takes or misses. The
   engine's evaluation is how those moments are found; the lines that change
   the situation and were not played are what is shown, with sentences such as
   „This was the last chance White gave Black, and Black did not take it", „The
   first mistake of the game that gives one side a big advantage", „Material
   given for activity" — where the side with less material is equal or better,
   and not because of a mate in three.

6. **The beginning says what is coming, the end says who won** (added while the
   first measurement was running): the first words should foreshadow the game —
   quiet or full of swings, a positional or a tactical fight — and the last
   should say who won, where today it is only „The game ended here." Both are
   computable: the number of story events below, the share of tactical against
   positional motif sentences, and the result (checkmate, the final evaluation,
   or a resignation where the facts carry one). Planned for the second round,
   after the first measurement.

## What is already true, and what is not

- Moments are chosen by **cost alone**, each on its own. Nothing relates one
  mistake to the next, so „a chance given and not taken" cannot be said.
- `decisiveMoment` marks one moment the game turned on (14.9.2026); that is one
  of the story events below, and the rest do not exist yet.
- Move facts are phrased as announcements (`play()` in `skeleton.py`,
  `playMoveOnBoard` in `board_queries.dart`), and the model copies the voice it
  is given. This file's lesson from 14.9.2026 („Ista rečenica se ne kaže
  dvaput") already said so for one slot.
- The whole-game glue between moments is the app's own lexicon („With the best
  move: about even. After this one: Black is slightly better."), which is the
  driest text in the tutorial.

## The story events — computed, never guessed

From the facts rows alone (evaluation before and after each game move, as
`standing` reads it: 0 even, 1 slightly, 2 clearly better, 3 winning, 4 mate):

| event | rule |
|---|---|
| **first big mistake** | the first game move after which the mover's opponent is clearly better or more (≤ −2 for the mover) when the best move kept it above that |
| **chance given** | a move that hands the opponent ≥ 2 they did not have before it |
| **chance taken / missed** | the opponent's reply keeps ≥ 2 (taken) or lets it fall below 2 (missed) |
| **last chance** | the last missed chance of the game |
| **material for activity** | after a move (in the game or in a shown line) the mover has at least 2 points less material and still stands ≥ 0, with no mate in ≤ 3 |

Measured on the ten fixture games before anything was built: one first big
mistake each; 2–7 chances a game, about a third of them missed; material for
activity once among the game moves (g05, 21... Qxe4 Qc3+) and in 29 of 69 best
lines. These are sentences the program writes as facts, so the model can only
narrate them, not invent them.

## The prototype (harness only, behind `SKELETON_STORY=1`)

In `tools/game_annotate/skeleton.py` and a second template
`chess_backend/services/prompts/tutorial_words_story.txt`. The default path, the
app and the server are untouched until the owner has read the result.

1. **The story of the game** — the events above, in game order, as a section of
   the prompt, and each moment's header says which events it is.
2. **The voice** — rules for one continuous story: the board plays each move as
   its slot is read, so a move is never announced or described square by
   square; say what it means (threat, defence, plan, what it gives away); do not
   open two slots with the same words; a move slot may be left empty when the
   move needs no words.
3. **Move facts as data, not as a sentence to copy** — the piece, squares and
   verb stay in the facts (the claim check needs `to`), but the text the model
   sees no longer reads „White plays Qc7: the queen from d8 to c7".
4. **The scene instead of „the board before these moves"** — the lead-in's
   opening slot asks for one sentence of where the fight stands, with the
   evaluation words at that point.
5. **The fork part** (point 3 above): a part with no moves at the moment's
   position, a blue arrow for the move played, and the program's sentence „In
   this position {mover} played {move}. The best move was…". The answer part
   then starts with the best move; `mN.answer.intro` is no longer asked for.
6. **The lexicon rewritten as narration**, the same facts behind each phrase.

## The measurement

- The same ten games, `deepseek-flash` at `reasoning_effort: low` (the server's
  model), run twice: the current prompt and the story prompt. About one US cent
  a run.
- For each run, **what is spoken, in order** — every sentence a listener hears,
  part by part — side by side.
- Counted, not judged: slots that announce their own move, slots opening with
  the same three words as another, empty move slots, the claim check's
  findings, missing slots, answers that do not assemble.
- The owner reads the transcripts and decides what goes into the app.

## What the measurement found — 14–15.9.2026

Ten games, `deepseek-flash` at effort low, the comparison published as a private
artifact for the owner. Totals over the ten whole-game tutorials:

| | today's prompt | story, round 1 | story, round 2 |
|---|---|---|---|
| a slot that announces its own move | 306 | 2 | 2 |
| „the queen from d8 to c7" | 86 | 0 | 0 |
| sentences sharing their first three words | 304 | 191 | 199 |
| words spoken | 7,891 | 7,247 | 7,745 |
| claim-check flags | 4 | 11 | 0 |
| tutorials that assembled | 10 | 10 | 10 |

A second, accidental run of the first two columns gave 256 / 3 announcements and
1 / 11 flags, so the effect is not one run's luck.

Round 1's eleven flags were half the check's fault: it read one slot at a time
while the story carried a pin or a mate over from the slot before. Round 2 reads
the moment so far and ignores a word said not to be there („no mate"); over round
1's own answers that keeps four flags, all real overreach („wins a pawn" where the
facts say nothing of it, a pin named a move early). Round 2 added `story.opening`
and `story.ending` (`game_arc`): the number of turning points and missed chances,
tactical against positional motif sentences, and the result — the board's mate,
or the last evaluation, since every fixture PGN says `[Result "*"]`.

Reading round 2 by hand still finds what no check can: g10's opening says „two
chances each side lets slip" where the facts count two in all, and its ending
says „forced mate" where they say White is winning; g07's ending gives the last
chance to the wrong side. Counts in the arc facts are the next thing to say more
plainly.

**A lesson about running a measurement, not about narration.** DeepSeek spent
most of the evening accepting requests and sending `: keep-alive` for 900 s
without starting them, and the harness recorded each as a finished run with an
empty answer. It fails now: a non-streamed answer with no choices is a fault, and
a streamed run that receives only keep-alive for its timeout stops. A retry that
was meant to be cancelled was not — the process filter matched nothing and nobody
checked — and ran all twenty requests a second time, about 328k tokens. **Check
that a cancel took effect, not only that it was sent.**

## The decision, and the port — 15.9.2026

The owner read the three columns and chose **the story prompt, replacing the old
one completely** — no switch, no choice for the trainer. Ported the way the
skeleton always is:

- `skeleton.py` has one path; `SKELETON_STORY` is gone, and so are the old
  move wording, `mN.answer.intro`, and the old lexicon and recap sentences.
- `chess_backend/services/prompts/tutorial_words.txt` **is** the story prompt;
  the server validates `story`, `arc` and each moment's `events` — all three
  optional, so an app already installed is still served — and offers the two
  `story.*` slots only when the arc was sent.
- The fixtures carry round 2's ten answers (`export_fixtures.py`, `RUNS`).
- The Dart port (`board_queries`, `skeleton_moments`, `skeleton_assembly`,
  `words_request`) is held to them by the existing gate, and
  `game_tutorial_story_test.dart` holds what the gate cannot say: the arrow is
  the move played, the program's part is no slot, the first and last words are
  the story's, the claim check reads the moment, and a silent move is never the
  first move of a best line.

Two things the port found. **The new „resumed" wording collided with the
bridge** — „Back to the game. White played…" opened exactly like „Back to the
game." — and the test written to catch two confusable wordings passed, because
it skipped any pair that was *equal*. It compares by position now. And the arc's
counts are said per side („White missed 1, Black missed 1"), because round 2 read
„2 chances missed" as two each.

Languages other than English (point F of the same report) are next, because the
program's own sentences would otherwise be translated twice.
