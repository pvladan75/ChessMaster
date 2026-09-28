# A position becomes a study

The owner, 28.9.2026: Auto Analysis answers „how could this position develop"
with a bare tree. It should read like what a strong player would say about the
position — backed by the engine — with the lines, the comments, and where they
help the arrows and marked squares; and the result should be exportable as a
tutorial. DeepSeek writes the words; **we prepare everything for it**.

## Settled, and not to be reopened

| | |
|---|---|
| Owner, 28.9.2026 | D1: the study **replaces** Auto Analysis — one door, with „Write comments with AI" as a tick, as Review has it |
| Owner, 28.9.2026 | D2: the tree is a **main line and side lines where something is at stake**, under a budget of positions; the four sliders go, the depth stays |
| Owner, 28.9.2026 | D3: Windows and the phone both; searches run one after another on the app's one engine |
| Owner, 28.9.2026 | D4: its own quota (`ai_studies`), never borrowed from the review's or the tutorial's |
| Owner, 28.9.2026 | D5: **Gemini leaves the application entirely**; DeepSeek takes its place at every door |
| Owner, 28.9.2026 | the threat is a fact: what the opponent does if the side to move passes |
| Owner, 28.9.2026 | seven men or fewer: the tablebase is asked, and its answer outranks the engine's number |
| `PLAN-SKELET.md` | the model writes words only; the client never sends a prompt; the server checks shape, the app checks truth |
| `PLAN-MAPA-DELOVA.md` | a tutorial part is one line; a tree becomes parts through `splitAtForks` |
| Owner, 22.9.2026 | motifs are AI-only: the detectors run for an AI feature and draw no panel |

**The name.** „Auto Analysis" becomes **Position Study**; the action is „Study
this position". „Study" is the chess word for exactly this (an annotated look
at one position), it is short enough for a bar, and the glossary's only
„studio" is the Tutorial Studio, which it does not collide with. The owner's
„Deep Position Understanding" says the same thing in three words where a button
has room for two.

## What already exists

| | what it gives | what it lacks |
|---|---|---|
| `AutoTreeGeneratorService` | the engine seam (`PositionAnalyzer`), `EvalCache` around it, cancel | a uniform n^N tree; no facts, no words |
| `QuickExtendDialog` | the engine's best line appended to a branch | the study's main line is this. **It stays**: removing it was flagged to the owner and not asked for, so „Extend branch" and the generator behind it are untouched |
| `mistake_rule.dart` | winning chances, `kMistakeLoss` 10, `kStandsOut` 15, `kTablebaseMen` 7 | — the study imports it, never copies |
| `TacticalMotifDetector`, `PositionalEvaluatorService` | `detect`/`evaluate` for a position, `explainMove` for a move, sentences, `affectedSquares` | nothing about threats, ideas or plans |
| `evaluation_words.dart` | an evaluation as words | — |
| `SyzygyTablebaseService` | the result and every move's category, seven men or fewer, paced | — |
| `claimsFor`, third mode | a move named must be in the item's own lines; a fork, pin, mate or win must be in the facts | — |
| `services/llm/deepseek.js` | one call, JSON asked for, every failure a reason | no plain-text answer (the opponent narrative needs one) |
| `reviewWords.js`, `routes/reviewWords.js` | the whole path: validate, prompt from a template, shape check, quota, token metering | — the study's route is this one's sibling |
| `AnalysisNode.beats`, `ChessArrow`, `SquareMark` | several sentences on one position, each with its own marks; PGN and film read them | — |
| `TutorialHandover.tree` | „New tutorial from this line" already hands a tree to the studio | a door at the end of a study |
| `UciEnginePool`, `tool/game_facts.dart` | a headless run on the downloaded binary | — the pattern for phase 0's tool |

**Gemini has three doors, not two** (measured 28.9.2026):

| door | caller | becomes |
|---|---|---|
| `POST /api/ai/generate-move-comment` | Analysis, „Generate AI comment" | the study's words for one move |
| `POST /api/ai/explain-position` | Repertoire, „AI on position" | the study's words for one position, no tree |
| `GET /games/prep/narrative` | opponent preparation | the same prompt and guard, asked of DeepSeek |

## 1. The shape of a study

A study starts at the node the reader stands on and writes a subtree under it.

```
start ── main line (the engine's best, move by move, until the position is quiet)
  ├── alternative   a second move close to the best: a real choice, shown short
  ├── tempting?     a check, capture or attack a reader would look at, the reply,
  │     ├── the capture it was aiming at, and what punishes it
  │     └── the best defence instead, short
  └── the threat    drawn as an arrow on the start position, never as a line
```

| | rule | constant |
|---|---|---|
| main line | the best move at each node, each node searched again; at least 4 plies, at most 8; never ends while the last move was a capture or a check, or while the mover is down material from the start | `kStudyMinPlies` 4, `kStudyMaxPlies` 8 |
| alternative | at the start only: a candidate that loses fewer than 5 chances against the best; at most 2; four plies of its own line | `kStudyCloseChoice` 5 |
| tempting move | at the start only: a **check, a capture or an attack** that is not the main move or a shown alternative, ranked by what it takes or threatens to take; the three most appealing are searched, and one is shown when it loses at least 5 chances (`?!`, from `kMistakeLoss` `?`) **or when its point fails** — see the greedy line; at most 2 shown | `kStudyTempting` 3 searched |
| the greedy line | after a tempting move and the engine's reply, the capture the move was aiming at is played if it is still there and loses at least `kMistakeLoss` against the best defence; the punishment is the engine's line after it, and the best defence stands beside it as a short side line. The engine alone never shows this line: its own line is the best defence | 2 searches |
| the piece that is offered | **a line is told the way a player would meet it.** When a punishing move puts a piece where it can be taken and the engine's line declines it, the line shown takes the piece and runs until the material is back — 9.Rxa7 Rxa7 10.c7 and the pawn queens — with the engine's own defence (9...Nxc6) beside it, short. Measured: the engine alone shows 9.Rxa7 Nxc6 10.Rxa8+, in which the point of the move never appears | 1 search |
| the trap | **a capture that wins material and loses evaluation** (the owner's definition, 28.9.2026). After each of the first three main-line moves, the most valuable capture of a piece or more that the engine does not play is searched; when it loses at least `kMistakeLoss` it stands beside the main line as `?` with its punishment — the answer to „why not just take it?" | 1 search a node, `kStudyTrapPlies` 3 |
| only move | a main-line move whose second best loses at least `kStandsOut` | — |
| decided | a position already won or lost (`isDecided`) gets no alternatives and no tempting moves: nothing is at stake | — |

**The budget is positions searched, and it is said before the run**: one for the
start (three lines), one for the threat, up to three tempting moves and two
more for each one's greedy line, up to seven further main-line nodes (two
lines each), one for the idea behind the first move — at most 25 searches (`kStudySearchBudget`; the twelve positions of phase 0 needed
6 to 12)
where Auto Analysis at its defaults asked 15 and at its maximum 364.

**The owner's position of 28.9.2026 rewrote three of these rules before any
was built** (`rn2kbnr/pp2pppp/2p5/3PNb2/8/1P4P1/1P1PPP1P/RNB1KB1R b`, the line
7...Be4 8.dxc6 Bxh1 9.Rxa7). Measured at depth 22: 7...Bxb1 is best (+0.14),
7...Be4 second (+0.97), and after 8.dxc6 the engine's line is 8...Nxc6, a pawn
down — 8...Bxh1 is +6.54. The first design missed the line three ways: Be4 is
neither a capture nor a check; it was skipped for being an engine candidate
while losing too little to be a mistake; and the engine never plays the capture
the move was made for. It is the eleventh position of phase 0, and the position after 7...Be4 —
where 8.dxc6 leaves the rook to be taken — the twelfth.

## 2. The facts

Everything the model may say is computed first. **The model is never asked to
look at a board.**

| fact | how | cost |
|---|---|---|
| the evaluation, in words | `wordsFor`, from the start's best line and from the last main-line node | — |
| material | counted; said as „level", „White is a pawn up", „Black has a rook for a bishop and a pawn" | — |
| what stands on the board | `detect` and `evaluate` on the start position, the most significant findings of each side | — |
| **the threat** | the same position with the other side to move (the en passant square cleared); the engine's best move there is the threat **if** its line wins material or mates **and** costs the side to move at least `kMistakeLoss` against simply playing the best move. The cost alone is not a threat: a side that can win a pawn back now loses by passing, and nothing threatens it. Not asked when the side to move is in check | 1 search |
| **the idea** | after the first move of the main line, the mover moves again: what the move prepares. Said as „with the idea of …" when the main line plays it, „which … prevents" when the reply stops it. Not asked when the move gives check | 1 search |
| what each move changes | `explainMove` of both detectors, as the review sends it | — |
| material won over a line | counted over the line | — |
| the only move | the gap to the second line | — |
| why the tempting move fails | the line after it, the material it loses, the detectors' sentence for the first move of the refutation | 1 search each |
| the result, seven men or fewer | the tablebase: win, draw or loss, the moves that keep it, the moves that give it away. Where the tablebase answers, the engine's words are not said | 1 request a node |

**A search that came back short is not a fact** (`searchProblem`): the study
counts it and leaves that branch out, and says so at the end.

**What the facts came to after four rounds against the real engine** (phase 0):

| found by reading the output | rule now |
|---|---|
| 8.Ra4 and 8.Nc3 were „tempting" with a rook hanging | a move that leaves something bigger to be taken is not what a player looks at |
| 7...Bc2 „attacked" a knight the bishop already attacked | an attack is new by the square it aims at, not by the move that takes |
| at depth 20 the engine met 7...Be4 with 8.f3, at 22 with 8.dxc6 — and the trap is behind 8.dxc6 | two replies are searched; a trap is looked for behind each that is as good as the best |
| „Black is a rook up" in the middle of an exchange | the material is said as it stands **and** as it is once the main line's captures are made |
| 8...fxg6 was called a trap that „loses the position" with Black still clearly better | a trap is named by what it costs: it loses the position only when the side that took is worse after it |
| three sentences about three isolated pawns | one sentence a kind of finding, three in all |
| „White's pawns hold more of the centre. White's pawns no longer hold more of the centre." | a pair of sentences that cancel each other is dropped |
| a bishop taken for a knight read as „won a knight and a pawn for a bishop" | a bishop for a knight is level, and said beside the rest |
| 10.fxe4 marked as an only move | a recapture, or a pawn taking a piece for nothing, needs no finding |

## 3. The words

One request per study, `POST /study-words`, the review's route in shape:

```
{ "position": "<FEN>", "side": "White",
  "items": [
    { "id": "s",  "kind": "position", "label": "the position", "lines": {...}, "facts": "...",
      "slots": [ {"id": "s.position", "text": "..."}, {"id": "s.threat", "text": "..."}, {"id": "s.plan", "text": "..."} ] },
    { "id": "m1", "kind": "move", "label": "14. Rd1", ... "slots": [ {"id": "m1.move", "text": "..."} ] },
    { "id": "a1", "kind": "alternative", ... },
    { "id": "t1", "kind": "tempting", ... },
    { "id": "e",  "kind": "outcome", ... } ] }
200 { "slots": { "s.position": "...", ... }, "attempts", "tokens", "model" }
```

- **Not every move gets words.** A main-line move is offered a slot when it is
  the first, an only move, a capture that wins material, or a move the
  detectors have something to say about; the rest are moves on the board.
- **The app checks truth** with `claimsFor`'s third mode: a move named must be
  in the item's lines; a fork, a pin, a mate or a win must be in its facts. A
  refused slot is left empty and counted, never patched. The study adds one
  check of its own: a word of the positional detector's vocabulary — isolated,
  passed pawn, outpost, the bishop pair, an open file, no defender — must be in
  the facts of that slot.
- **The prompt describes only the slots a request offers.** The first run
  described `s.threat` to a position with no threat, and the model wrote one,
  twice; a slot that was not offered is now dropped and named rather than
  asked about again.
- **The one-move and the one-position case are the same request** with one
  item: „Generate AI comment" sends a `move` item, the repertoire's „AI on
  position" a `position` item. One prompt, one check, one quota rule each.

## 4. The marks

Every mark stands in a beat whose sentence names it, so nothing rests on the
colour alone.

| beat | arrows | squares |
|---|---|---|
| the position | — | the squares of the findings said (a weak pawn, an outpost, an open file's head) |
| the threat | the threatened move, red | its target |
| the plan | the first move, green; the idea, blue | — |
| a tempting move | the move itself, orange | — |

## 4a. Phase 0, measured on 28.9.2026

Twelve positions — five from the owner's own games, five from `classics.pgn`,
two of his own asking — at depth 20 on Stockfish 19, the words from both of
the account's models (`tools/position_study/`, `chess_app/tool/position_study.dart`).

| | `deepseek-flash`, effort low | `deepseek-v4-pro` |
|---|---|---|
| slots kept after the app's check, over three runs and two | 99, 103 and 102 of 109 | 106 and 104 of 109 |
| tokens a study | about 4,250 | 6,950 to 8,100 |
| the wait for the words | about 10 s | 37 to 42 s |
| how it writes | explains and connects; recites a line now and then; says more than the facts oftener | short and exact; reads flatter |

The last run of each is on the final code and the final prompt. The engine
asked 108 searches for the twelve positions, nine a position, and needed 4.5
to 64 seconds for one; no search was lost. The
owner read the two reports and chose **`deepseek-v4-pro`** on 28.9.2026 (S4):
the server asks it unless `STUDY_WORDS_MODEL` says otherwise, and the app
waits 230 s for the words where it waited 120, because two attempts of the
slower model are past two minutes.

## 5. Into a tutorial

The done view of a study offers „Open as a tutorial": `TutorialHandover.tree`
from the start node, which `splitAtForks` turns into parts — the main line,
then each alternative and each tempting move as a part of its own — with every
beat, arrow and square carried. No server change: the studio saves it.

## 6. Roadmap

| phase | what | who |
|---|---|---|
| 0 | **measurement**: the facts builder (pure Dart), the prompt and the shape check (Node, no route), a headless run over ten positions from the owner's own games and `classics.pgn`; the sentences read | lead |
| 1 | the server: `POST /study-words`, `ai_studies` and its tokens; the three Gemini doors onto DeepSeek; `geminiService.js`, `@google/genai` and `GEMINI_API_KEY` deleted | lead |
| 2 | the app: the study's runner and dialog in place of Auto Analysis and „Extend branch"; the tree, beats and marks written; „Generate AI comment" and „AI on position" through the study's words | lead |
| 3 | „Open as a tutorial" | lead |
| 4 | the manual under `site/`, the glossary, the live-check items, the numbers in `CLAUDE.md` | lead |

Phase 0's gate is the owner's reading of ten studies. Every later phase's gate
is its tests, each watched red first.

## Decisions for the owner

| | question | recommendation |
|---|---|---|
| S1 ✅ | *Decided 28.9.2026: §5.2 names DeepSeek, in the draft and on the site in both languages, on the owner's word — the new wording has not been before the lawyer.* The privacy policy names Gemini in §5.2 and does not name DeepSeek (`TODO-objavljivanje.md` already lists this). With this plan §5.2 is untrue the day it ships | the text is the owner's and the lawyer's; nothing here rewrites it |
| S2 | How many studies a month a plan includes | the tutorial's numbers: 30 premium, 100 pro, unlimited club |
| S3 | The depth on a phone | the reader's own Analysis depth, as Auto Analysis did; the dialog says how long it will take |
| S4 ✅ | *Decided 28.9.2026: `deepseek-v4-pro`.* Which model writes a study | `deepseek-flash`: a quarter of the wait and better teaching; its three times as many refused sentences cost a comment each, never a wrong one |
| S5 | „Extend branch (engine best line)" is the study's main line without the rest | it could go; nothing removes it until the owner says so |

## Not in this plan

- Side lines deeper than the start position. A study of the position after the
  main line's third move is a second study, started there.
- An opening name or master statistics in the words.
- A translation: a tutorial made from a study is translated by the route that
  translates every tutorial.
