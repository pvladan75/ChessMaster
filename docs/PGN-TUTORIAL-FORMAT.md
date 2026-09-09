# Generating a tutorial for testing: PGN to paste, or JSON to POST

Written 9.9.2026, to make large tutorials cheaply for testing the video
renderer and the render queue. Every rule below was measured against the app's
own reader (`MoveTree.parsePgn` → `LessonStepLine` → `readStepTree`) and the
server's own validator (`services/lessonSteps.js`) on that date, not read off
the PGN standard.

Two routes, and they answer different questions:

| | PGN paste | JSON POST |
|---|---|---|
| Makes | **one part** per paste | a **whole tutorial** in one request |
| Goes through | the studio's „PGN" tab, `LessonStepLine` | `POST /lessons/save`, `buildLessonSteps` |
| Validates the line | yes — refuses a text that does not replay | **no** — the server has no PGN reader |
| Can set kind, task, answers | no | yes |
| Good for | writing a real tutorial, checking the parser | 40-part films, concurrent-render tests |

Use JSON for load testing. Use PGN when you want the app itself in the loop.

---

# A. PGN to paste

## What one paste is

One PGN text is one part — one „Deo", one `position_list` entry, one
`LessonStep`. There is no import that splits a text into several parts.

1. Windows build → **Studio za tutorijal** → new tutorial („Deo 1" opens on the
   standard position).
2. „PGN" tab → paste → **Apply**.
3. For the next part: „Delovi tutorijala" → **New demonstration** → **New
   board** → „PGN" tab → paste → **Apply**.
4. **Sačuvaj tutorijal.**

A text whose `[FEN]` differs from the part's position raises a dialog — answer
**Use that position**. One click per part, and it is the only interaction the
paste needs.

## The prompt

```text
Write a chess tutorial as annotated PGN. Output ONLY the PGN text, nothing else.

Format, exactly:

[Event "Tutorial"]
[SetUp "1"]
[FEN "<starting position of the lesson, full FEN with all six fields>"]

{ A sentence about the starting position, before move 1. [%csl Ge4,Gd4] }
1. e4 { A sentence about this move. [%cal Ge2e4] }
e5 { A sentence about this move. }
2. Nf3 { A sentence. [%cal Gf3e5] [%csl Re5] }
*

Rules:

1. Moves are English SAN: N B R Q K, O-O, O-O-O, exd5, e8=Q, +, #. Never use
   the piece letters of another language (S, L, T, D...).
2. Every move must be legal from the [FEN] you wrote. Replay the whole line
   before answering: one illegal move makes the entire text unusable.
3. NO variations. Do not use parentheses at all. One main line only.
4. A comment { } belongs to the move immediately before it. A comment placed
   before move 1 belongs to the starting position, and that is where the
   lesson's opening sentence goes.
5. At most one [%cal ...] and one [%csl ...] per comment, both inside the same
   braces, after the words. Several arrows or squares are comma-separated:
   [%cal Ge2e4,Rd8h4] [%csl Rf7,Gd5].
6. Colours are single letters: G green, R red, B blue, O orange, P purple.
   An arrow is colour + from + to (5 characters: Ge2e4).
   A square is colour + square (3 characters: Rf7).
7. Never nest a { } comment, and never write square brackets in the words of a
   comment: [ ] is only for [%cal] and [%csl].
8. Write a sentence on almost every move. Each sentence is read aloud to a
   child and drawn under the board, so use full sentences in plain words, 40
   to 140 characters. Avoid move notation inside the words unless you mean it
   to be spoken: "Bd5" is read out as "bishop d five".
9. Close with a single * on its own line.
10. Write no other headers. [Event], [SetUp] and [FEN] only.

Topic: <what the lesson should teach>
Length: <how many moves>
```

Add the side the board is written from, the child's level, or the language of
the sentences — any language works, the narration voice is chosen at export.

## Why each rule is there

| Rule | The reason in the code |
|---|---|
| Headers on their own lines | `parsePgn` strips headers line by line with `^\s*\[[^%][^\]]*\]\s*$`. A header sharing a line with a move is not stripped. `[%cal]` survives because of the `[^%]`. |
| Only `[FEN]` matters | `fenHeaderOf` reads it and everything else is discarded. `[SetUp "1"]` is convention; nothing reads it. No `[FEN]` means the standard opening position. |
| Legal moves only | `parsePgn` **skips** a move it cannot play, counting it in `rejectedMoves`; „Apply" then refuses the whole text. Deliberate — a line must never come back silently shorter. |
| No variations | Parentheses parse and are stored, but a fork **stops** the narrated walk and the film: `beatsOf` and `tutorialVideoOf` follow first children, and the child gets a branch chooser. In a render test that is a film that ends early. |
| A comment binds backwards | The parser attaches a comment to the node it is standing on, which is the move just played. Before move 1 that is the root — the only place a note about a still position can live. |
| One `[%cal]`, one `[%csl]` | `parsePgnArrows` and `parsePgnSquares` use `firstMatch`, so a second group of the same kind is ignored — and `cleanPgnComment` strips every group from the words, so it vanishes rather than showing up in the sentence. |
| 5 and 3 characters | A token of any other length is skipped rather than guessed at. |
| Colour letters | `ArrowColor.all` is `R O G B P`. An unknown letter draws grey (`ArrowColor.fallback`). |
| No brackets in words | Whatever is not `[%cal]`/`[%csl]` survives into the caption and is read aloud. |
| `*` on its own line | A marker glued to the last move (`Nxb4*`) is handled now, but a space in front of it is the shape the exporter writes. |

## Worked example, measured

Read through `readStepTree` on 9.9.2026: **0 rejected moves**, 6 and 4 beats,
10 events, **111 seconds** of silent film.

```
[Event "Tutorial"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]

{ We start from the initial position. Watch the two central squares: whoever controls them decides where the pieces will go later in the game. [%csl Ge4,Gd4] }
1. e4 { The king pawn takes one central square and opens lines for the bishop and the queen at the same time. That is why it is the most popular first move in chess. [%cal Ge2e4] }
e5 { Black answers symmetrically and claims an equal share of the centre. Now both sides have one pawn on the fourth rank and the fight is about who develops faster. [%cal Ge7e5] }
2. Nf3 { The knight develops and attacks the pawn on e5 immediately. A developing move that also contains a threat is worth two ordinary moves. [%cal Gf3e5] [%csl Re5] }
Nc6 { Black defends the pawn and develops a piece towards the centre. Notice that both players are bringing knights out before bishops. }
3. Bc4 { The bishop takes the long diagonal and looks straight at f7, the weakest square in Black's camp because only the king defends it. [%cal Gc4f7] [%csl Rf7] }
*
```

Second part, pasted into a part added with „New demonstration" → „New board",
answering **Use that position**:

```
[SetUp "1"]
[FEN "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 3"]

{ Here is the same position again, but now it is Black to move and we look at the mistake that decides thousands of beginner games. [%csl Rf7] }
3... Nf6 { The best answer: Black develops and attacks the pawn on e4, so White has no time for slow plans. [%cal Gf6e4] }
4. Ng5 { White attacks f7 with a second piece. Two attackers against one defender is the arithmetic that wins material. [%cal Gg5f7,Gc4f7] [%csl Rf7] }
d5 { The only move. Black blocks the bishop's diagonal by counterattacking in the centre, and the game continues with a fight rather than a loss. [%cal Gd5c4] }
*
```

Comments may span lines — the parser splits on whitespace — so a wrapped answer
from an LLM is fine.

## What a paste cannot carry

It makes a **demonstration** (`show`). The kind, the task sentence, the offered
answers and the recorded solution are fields of the step rather than of the
line, and only the studio writes them. That is also why a paste is safe: the
studio refuses to save a question that carries a line, because the line would
show the child the answer.

Orientation is not in the PGN either. A part read back adopts „Black to move
means Black at the bottom"; turn it in the studio if the lesson needs it.

---

# B. JSON to POST — the fast path for load tests

`POST /lessons/save` takes the whole tutorial in one body. The server validates
every FEN through `chess.js` and refuses the request if one is unloadable, but
it has **no PGN reader**: a `pgn` that does not replay from its step's `fen` is
stored without complaint and shows up only when the app reads it back. So the
FEN and the line must agree, and the way to check is to open the tutorial in
the studio once.

## The request

```json
{
  "title": "Render test 01",
  "description": "generated",
  "positionList": [
    {
      "title": "Deo 1",
      "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
      "kind": "show",
      "pgn": "{ A sentence about the starting position. [%csl Ge4,Gd4] }\n1. e4 { A sentence about this move. [%cal Ge2e4] }\ne5 { A sentence. }\n*"
    },
    {
      "title": "Deo 2",
      "fen": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 3",
      "kind": "show",
      "blackOrientation": true,
      "pgn": "{ Another sentence. [%csl Rf7] }\n3... Nf6 { A sentence. [%cal Gf6e4] }\n*"
    }
  ]
}
```

Per step, what `buildLessonStep` accepts and what it does with it:

| Field | Rule |
|---|---|
| `fen` | **required**, validated by `chess.js`, refused with 422 if unloadable |
| `title` | ≤ 200 chars, defaults to „Position" |
| `pgn` | ≤ 100000 chars, stored opaquely, **not validated** |
| `kind` | `show`, `ask_move` or `ask_choice`; absent means `show`; an unknown value is refused rather than downgraded |
| `instruction` | ≤ 500 chars — the task, drawn on the last beat of a question part |
| `blackOrientation` | boolean, and **absent is a third answer**: leave it out and the viewer works the side out from whose turn it is |
| `id` | `[A-Za-z0-9_-]{1,16}`; omit it and the server mints one. Never reuse an id across two tutorials — it names a schedule row and a recorded answer |
| `solutionSan`, `acceptedSans` (≤ 6), `choices` (2–4, `{text, correct}`) | only for the question kinds; `ask_move` has its solution validated against the FEN |

A `pgn` written for JSON does not need its own `[FEN]` header: the step's `fen`
is passed to the parser explicitly and wins over any header in the text. All the
PGN grammar rules from part A still apply to the string.

## The prompt

```text
Output ONLY a JSON object, no prose, no code fence. Shape:

{
  "title": "<tutorial name>",
  "description": "generated",
  "positionList": [ <step>, <step>, ... ]
}

A step is:

{
  "title": "Deo <n>",
  "fen": "<full FEN, six fields>",
  "kind": "show",
  "pgn": "<annotated PGN as a single JSON string, newlines escaped as \\n>"
}

Rules for the pgn string:

1. No headers at all — no [Event], no [FEN]. The step's own "fen" field is the
   starting position, and every move must be legal from it.
2. Moves in English SAN. No variations, no parentheses.
3. A { } comment belongs to the move before it; a comment written before move 1
   belongs to the starting position.
4. At most one [%cal ...] and one [%csl ...] per comment, comma-separated
   inside: [%cal Ge2e4,Rd8h4] [%csl Rf7]. Arrow = colour + from + to (Ge2e4),
   square = colour + square (Rf7), colours G R B O P.
5. A sentence on almost every move, 40 to 140 characters, plain words, spoken
   aloud to a child.
6. End with a space and a *.

Produce <N> steps of <M> moves each. Each step starts from a position that
follows on from the previous step, or from a fresh one — say which in the
first sentence either way.
```

## Posting it (PowerShell 7)

```powershell
$api = 'http://localhost:3000'
$login = Invoke-RestMethod "$api/login" -Method Post -ContentType 'application/json' -Body (@{ email='<you>'; password='<pw>' } | ConvertTo-Json)
$body = Get-Content .\tutorial.json -Raw
Invoke-RestMethod "$api/lessons/save" -Method Post -ContentType 'application/json' -Headers @{ Authorization = "Bearer $($login.token)" } -Body $body
```

It then appears under „Sačuvani tutorijali", opens in the studio, and exports to
video like any other.

---

# Sizing a film

Without narration `dwellSecondsFor` decides: **12 characters a second, minimum
2 s, maximum 12 s per beat.** A beat is the starting position plus every move of
the main line, so a comment of 144 characters or more holds the screen for the
full 12 s and anything longer is free.

    film seconds ≈ (1 + moves) × dwell
    50 moves at 12 s ≈ 10 minutes

The renderer draws **4 frames per second when there is a caption band** (1 fps
without one), so a ten-minute captioned film is about 2400 drawn PNGs. Duration
is clamped to 3600 s.

**With narration the app's timestamps are replaced** by the voice's own
durations (`narrationPlan` / `retimeEvents`): each beat runs `ceil(spoken +
breath)` whole seconds, and a clip longer than 60 s is dropped rather than
trimmed. So narration makes the film longer than the estimate above and adds one
TTS call per sentence — which is what actually loads the queue.

Two ceilings the render sits inside: nginx closes a proxied request after
**300 s** (`deploy/app-setup.sh`) and the app's HTTP timeout is five minutes.
`RENDER_CONCURRENCY` films are drawn at a time, `RENDER_QUEUE_MAX` may wait, and
a fuller queue is refused at once with a 429 rather than left to die on the wire.

**For the concurrency test** the useful shape is several films each long enough
to still be rendering when the next request arrives — a minute or two of
captioned film — rather than one enormous one. A film whose render plus queue
wait exceeds 300 s is testing nginx, not the queue.
