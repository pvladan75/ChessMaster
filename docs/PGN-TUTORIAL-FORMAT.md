# Writing a tutorial outside the app

Written 9.9.2026 to make large tutorials cheaply for testing the video renderer;
rewritten 11.9.2026, after twenty-seven tutorials were generated from the first
version of it and **thirteen of them had a fault in them**. Every rule below was
measured against the app's own reader (`MoveTree.parsePgn` → `LessonStepLine` →
`readStepTree`) and the server's own validator (`services/lessonSteps.js`), not
read off the PGN standard.

There is one file format — the body of `POST /lessons/save` — and two ways in:

| | Imported in the app | POSTed with curl |
|---|---|---|
| Where | Library → Interactive tutorials → **Import from a file** | `POST /lessons/save` |
| Checks the line | **yes**, per part, before anything is written | **no** — the server has no PGN reader |
| Good for | everything a person does | load tests, forty-part films |

**Import it in the app.** The server stores a `pgn` as opaque text: a line that
does not replay is written without complaint and shows up months later as a
child getting a shorter lesson than the file holds. The import reads every line
through the same parser the child's screen uses and says which part is wrong
before anything is saved.

---

# 1. The prompt

Copy the whole block. It is written to be pasted into a generator with nothing
else; every rule it needs is inside it, because the model will not see this
document.

```text
Write a chess tutorial as a single JSON object. Output ONLY the JSON — no prose,
no explanation, no code fence.

SHAPE

{
  "title": "<the tutorial's name, under 200 characters>",
  "description": "<one sentence about what it teaches>",
  "tags": ["<one or two words the trainer will filter by, e.g. endgame>"],
  "positionList": [ <step>, <step>, ... ]
}

A step is one of two kinds.

A demonstration — a position and a line of moves with a sentence on each move:

{
  "title": "Deo <n>",
  "fen": "<full FEN, six fields>",
  "kind": "show",
  "pgn": "<annotated PGN as one JSON string, newlines escaped as \n>"
}

A question — a position, a task, and the answer. IT HAS NO MOVES:

{
  "title": "Deo <n>",
  "fen": "<full FEN, six fields>",
  "kind": "ask_move",
  "instruction": "<what the student has to do, one sentence>",
  "solutionSan": "<the single correct move in SAN>",
  "pgn": ""
}

A multiple-choice question — a position, a task, and two to four answers, of
which at least one is marked correct. IT ALSO HAS NO MOVES:

{
  "title": "Deo <n>",
  "fen": "<full FEN, six fields>",
  "kind": "ask_choice",
  "instruction": "<the question, one sentence>",
  "choices": [
    {"text": "<an answer in words>", "correct": true},
    {"text": "<another answer>", "correct": false}
  ],
  "pgn": ""
}

Optional on any step: "blackOrientation": true draws the board from Black's
side. Leave it out and the app decides from whose turn it is.

HARD RULES. Each of these makes the tutorial be refused or silently broken.

1. THE FEN MUST BE A REAL POSITION. Six fields. Piece letters are only
   K Q R B N P k q r b n p — a letter like "c" in the board field makes the
   whole tutorial be refused. Exactly one king of each colour, no pawn on the
   first or the eighth rank, and the side that is NOT to move must not be in
   check. Build the FEN by playing the moves out from a position you are sure
   of; do not write one from a mental picture of the board.

2. EVERY MOVE MUST BE LEGAL FROM THAT FEN. Replay the whole line before you
   answer. A move that cannot be played is skipped, and the student gets a
   lesson with holes in it. If you are not certain of a long line, write a
   SHORT one: four correct moves are worth more than twelve invented ones.

3. NOTHING MAY BE GLUED TO A MOVE. No !, ?, !?, ?!, +-, -+, =, N, ∞.
        WRONG: Kb6+-      WRONG: Be8!+-      WRONG: Rh2!=
        RIGHT: Kb6        RIGHT: Be8         RIGHT: Rh2
   Put the assessment in the sentence: "White is winning now."

4. WRITE + ONLY WHEN THE MOVE REALLY GIVES CHECK, AND # ONLY WHEN IT IS REALLY
   MATE. A + on a move that gives no check is refused exactly like an illegal
   move. If you are not certain, write neither: Bd6 is always safe, Bd6+ is
   not.

5. MOVES ARE ENGLISH SAN: N B R Q K, O-O, O-O-O, exd5, e8=Q. Never the piece
   letters of another language (S, L, T, D, C, A, F...).

6. NO VARIATIONS. Do not use parentheses anywhere. One main line per step.

7. A { } COMMENT BELONGS TO THE MOVE BEFORE IT. A comment written before move 1
   belongs to the starting position, and that is where the opening sentence of
   the step goes. Never nest comments.

8. ARROWS AND SQUARES GO INSIDE THE BRACES, AFTER THE WORDS.
        WRONG: 1. h4 [%cal Gh2h4] { White starts the attack. }
        RIGHT: 1. h4 { White starts the attack. [%cal Gh2h4] }
   An annotation outside the braces is read as a move and destroys the line.
   At most one [%cal ...] and one [%csl ...] per comment, several of each
   comma-separated inside: [%cal Ge2e4,Rd8h4] [%csl Rf7,Gd5].
   An arrow is colour + from-square + to-square, five characters: Ge2e4.
   A square is colour + square, three characters: Rf7.
   Colours are G green, R red, B blue, O orange, P purple.
   Square brackets are for these two tags and nothing else: never write [ or ]
   in the words of a comment.

9. A QUESTION CARRIES NO MOVES. A step with "kind": "ask_move" or
   "kind": "ask_choice" must have "pgn": "". The app draws the line for the
   student with a "Next move" button, so a question that carries its own answer
   shows it, and the app refuses to save it. Put the answer in the NEXT step,
   as a "show" step on the same FEN.

10. "solutionSan" MUST BE LEGAL IN THAT STEP'S OWN FEN, PLAYED BY THE SIDE THAT
    IS TO MOVE THERE. If the answer is a black move, the FEN must say "b".
    Replay it before you answer.

11. "choices" IS TWO TO FOUR ANSWERS AND AT LEAST ONE OF THEM HAS
    "correct": true. One answer, five answers, or none marked correct is
    refused. Only "ask_choice" has choices; no other kind may carry them.

12. NEVER WRITE AN "id" FIELD ON A STEP. The server mints those.

13. Every "pgn" of a demonstration ends with a space and a *.

SENTENCES

Write a sentence on almost every move. Each one is read aloud to a child and
drawn under the board: full sentences in plain words, 40 to 140 characters,
no move notation inside the words unless you mean it to be spoken — "Bd5" is
read out as "bishop d five".

A tutorial is 4 to 10 steps. A demonstration is 3 to 8 moves. Prefer more short
steps to one long line: a wrong move ruins the step it is in, not the tutorial.

BEFORE YOU ANSWER — do this silently, and output nothing about it:

  a. Replay every "pgn" from its step's "fen", move by move. Delete or correct
     any move that does not play, and shorten the line if you are unsure.
  b. Check every + and every # against the position. Remove the ones you cannot
     prove.
  c. Check every "solutionSan" the same way, including whose turn it is.
  d. Read every question step and confirm its "pgn" is "".
  e. Count the answers of every "ask_choice" and confirm one is correct.
  f. Search your own output for [%cal and [%csl and confirm each one is inside
     a { } comment.
  g. Confirm the JSON parses and no step has an "id".

Topic: <what the tutorial should teach>
Level: <who it is for>
Language of the sentences: <any language; the narration voice is chosen later>
```

Everything after `Topic:` is yours to fill in. Any language works for the
sentences — the film's voice is chosen at export — but the **moves are always
English SAN**, because that is what the PGN standard stores and what this app
writes.

---

# 2. A worked example, verified

Read through `readTutorialJson` on 11.9.2026: three parts, **no problems**.

```json
{
  "title": "The weak square f7",
  "description": "Why every beginner game is decided on one square.",
  "tags": ["opening", "beginner"],
  "positionList": [
    {
      "title": "Deo 1",
      "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
      "kind": "show",
      "pgn": "{ We start from the opening position. Watch the two squares in the middle: whoever controls them decides where the pieces will go. [%csl Ge4,Gd4] }\n1. e4 { The king pawn takes a central square and opens lines for the bishop and the queen at once. [%cal Ge2e4] }\ne5 { Black answers in the same way and claims an equal share of the centre. }\n2. Nf3 { The knight develops and attacks the pawn on e5 straight away. [%cal Gf3e5] [%csl Re5] }\nNc6 { Black defends the pawn and brings a piece towards the middle of the board. }\n3. Bc4 { The bishop takes the long diagonal and looks straight at f7, the weakest square in the black camp because only the king defends it. [%cal Gc4f7] [%csl Rf7] }\n*"
    },
    {
      "title": "Deo 2",
      "fen": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 3",
      "kind": "ask_move",
      "blackOrientation": true,
      "instruction": "Black to move. Develop a piece and attack the pawn on e4 at the same time.",
      "solutionSan": "Nf6",
      "pgn": ""
    },
    {
      "title": "Deo 3",
      "fen": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 3",
      "kind": "show",
      "blackOrientation": true,
      "pgn": "{ Here is the answer, and what White tries next. [%csl Rf7] }\n3... Nf6 { The knight develops and attacks the pawn on e4, so White has no time for slow plans. [%cal Gf6e4] }\n4. Ng5 { White attacks f7 with a second piece. Two attackers against one defender is the arithmetic that wins material. [%cal Gg5f7,Gc4f7] [%csl Rf7] }\nd5 { The only move. Black blocks the diagonal by hitting back in the centre, and the game goes on. [%cal Gd5c4] }\n*"
    }
  ]
}
```

Steps 2 and 3 are the shape rule 9 asks for: the question stands on a position,
and the line that answers it is the part after it, on the same position. That is
also what the studio's own „Traži potez na tabli" produces, so an imported
tutorial and one written by hand come out the same shape.

---

# 3. The mistakes that were actually made

Twenty-seven tutorials, generated 10.9.2026 from the previous version of this
document. Thirteen had at least one of these. They are ordered by how often.

| Fault | Example, as written | What the app does |
|---|---|---|
| A glyph glued to a move | `Kb6+-`, `Be8!+-`, `Rh2!=` | the move is not played; the rest of the line follows from the wrong position |
| `+` on a move that gives no check | `Bd6+` where d6 does not attack the king | the same — refused like an illegal move |
| A question carrying its own answer | `"kind": "ask_move"` with a `pgn` | the child sees the answer under „Sledeći potez"; the studio refuses to save it |
| `solutionSan` illegal in its own FEN | `Rxe1#` with the FEN saying `w` | the whole tutorial is refused, 422 |
| A line that does not replay | 12 of 17 moves impossible | stored as it is; the child gets what survived |
| `[%cal]` outside the braces | `1. h4 [%cal Gh2h4] { … }` | every annotation is read as a move — 20 rejected moves in one step |
| A piece that does not exist | `2c2n2` in the board field | the whole tutorial is refused |

Two of them are worth a sentence each, because they are not obvious.

**The check mark is part of the move.** Two chess libraries disagree here: the
one used to *write* these files accepts `Bd6+` on a move that gives no check,
and the one the app *reads* them with does not. A file can therefore replay
perfectly wherever it was generated and lose four moves in the app. That is why
rule 4 says to write neither mark when in doubt: a move with no suffix is always
accepted, and the app draws the check on the board anyway.

**The side to move is half of the question.** Three of the four files that could
not be saved at all asked for a black move from a position whose FEN said White
to move. Nothing about the sentence or the instruction gives this away; only
replaying the answer does.

---

# 4. What the app says, and what it means

The import reports per part, and it separates two things.

**Refused — nothing is written until it is fixed:**

| The sentence | The cause |
|---|---|
| „the starting position cannot be read — …" | the `fen` is not a position |
| „the solution … cannot be played in this position" | `solutionSan`, rule 10 |
| „it asks for a move and gives no solution" | `ask_move` with no `solutionSan` |
| „a multiple-choice question needs between two and four answers" | `choices` |
| „none of the offered answers is marked as the correct one" | no `correct: true` |
| „… is not a kind of step" | `kind` is not `show`, `ask_move` or `ask_choice` |

**Damaged — it would be stored, and it would be wrong:**

| The sentence | The cause |
|---|---|
| „the line has N moves that cannot be played …" | rules 2, 3, 4, 8 |
| „it asks for a move and carries the line that answers it" | rule 9 |

A damaged file can still be opened in the studio and fixed there, which is what
the single-file import is for. A refused one cannot be saved at all.

---

# 5. The fields, and what the server does with each

Per step, from `buildLessonStep`:

| Field | Rule |
|---|---|
| `fen` | **required**, validated by `chess.js`, refused with 422 if unloadable |
| `title` | ≤ 200 characters, defaults to „Position" |
| `pgn` | ≤ 100000 characters, stored opaquely, **not validated by the server** |
| `kind` | `show`, `ask_move` or `ask_choice`; absent means `show`; an unknown value is refused rather than downgraded |
| `instruction` | ≤ 500 characters — the task, drawn on the last beat of a question |
| `blackOrientation` | boolean, and **absent is a third answer**: leave it out and the viewer works the side out from whose turn it is |
| `id` | `[A-Za-z0-9_-]{1,16}`. **Never write one.** It names a schedule row and a recorded answer, so two tutorials carrying one id is a child's progress appearing in the wrong copy. The import drops it; a curl POST does not |
| `solutionSan` | only for `ask_move`, and validated against that step's `fen` |
| `acceptedSans` | up to 6 further correct moves, `ask_move` only |
| `choices` | 2–4 of `{text, correct}`, `ask_choice` only, at least one `correct` |

On the tutorial itself: `title` (required), `description`, and `tags` — the
labels the trainer filters the saved list by, and the reason to write one or two
even for a test file.

A `pgn` written for JSON needs no `[FEN]` header of its own: the step's `fen` is
passed to the parser and wins over any header in the text.

## Why the PGN rules are what they are

| Rule | The reason in the code |
|---|---|
| Legal moves only | `parsePgn` **skips** a move it cannot play and counts it in `rejectedMoves`. Deliberate — a line must never come back silently shorter without somebody being told |
| No variations | Parentheses parse and are stored, but a fork **stops** the narrated walk and the film: `beatsOf` and `tutorialVideoOf` follow first children, and the child gets a branch chooser instead of the rest of the lesson |
| A comment binds backwards | The parser attaches a comment to the node it is standing on, which is the move just played. Before move 1 that is the root — the only place a note about a still position can live, and the exporter writes it ahead of move one so „look at d5" can travel |
| One `[%cal]`, one `[%csl]` | `parsePgnArrows` and `parsePgnSquares` use `firstMatch`, so a second group of the same kind is ignored — and `cleanPgnComment` strips every group from the words, so it vanishes rather than being read aloud |
| 5 and 3 characters | A token of any other length is skipped rather than guessed at |
| Colour letters | `ArrowColor.all` is `R O G B P`. An unknown letter draws grey |
| No brackets in the words | Whatever is not `[%cal]`/`[%csl]` survives into the caption and is spoken |
| `*` at the end | A marker glued to the last move (`Nxb4*`) is handled, but a space in front of it is the shape the app's own exporter writes |

---

# 6. The other route: one part pasted as PGN

For a single part, with the app itself in the loop: Windows build → **Studio za
tutorijal** → „PGN" tab → paste → **Apply**. A text whose `[FEN]` differs from
the part's position raises a dialog; answer **Use that position**.

The paste takes headers, and only `[FEN]` is read:

```
[Event "Tutorial"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]

{ A sentence about the starting position. [%csl Ge4,Gd4] }
1. e4 { A sentence about this move. [%cal Ge2e4] }
e5 { A sentence about this move. }
*
```

Every rule in section 1 that is about the PGN string applies here too. A paste
makes a **demonstration** and nothing else: the kind, the task, the offered
answers and the recorded solution are fields of the step rather than of the
line, and only the studio writes them. Headers must be on their own lines —
`parsePgn` strips them line by line, and one sharing a line with a move is not
stripped.

Comments may span lines — the parser splits on whitespace — so a wrapped answer
from a generator is fine.

Unlike the server, „Apply" **refuses** a text that does not replay, and says how
many moves it could not play. It is the cheapest way to check one line.

Orientation is not in a PGN. A part read back adopts „Black to move means Black
at the bottom"; turn it in the studio, or write `blackOrientation` in the JSON.

---

# 7. Posting the file instead of importing it

For a load test, where nobody is going to read the tutorial (PowerShell 7):

```powershell
$api = 'http://localhost:3000'
$login = Invoke-RestMethod "$api/login" -Method Post -ContentType 'application/json' -Body (@{ email='<you>'; password='<pw>' } | ConvertTo-Json)
$body = Get-Content .\tutorial.json -Raw
Invoke-RestMethod "$api/lessons/save" -Method Post -ContentType 'application/json' -Headers @{ Authorization = "Bearer $($login.token)" } -Body $body
```

It then appears under „Sačuvani tutorijali", opens in the studio, and exports to
video like any other. **Nothing checks the lines on this path** — the server has
no PGN reader — and an `id` written into a step is stored as it stands, so this
is for files you do not intend a child to see.

---

# 8. Sizing a film

Without narration `dwellSecondsFor` decides: **12 characters a second, minimum
2 s, maximum 12 s per beat.** A beat is the starting position plus every move of
the main line, so a comment of 144 characters or more holds the screen for the
full 12 s and anything longer is free.

    film seconds ≈ (1 + moves) × dwell
    50 moves at 12 s ≈ 10 minutes

The renderer draws **4 frames a second when there is a caption band** (1 fps
without one, and without one when the export sheet's „Comments beside the
board" is off), so a ten-minute captioned film is about 2400 drawn PNGs. Duration
is clamped to 3600 s, and a render whose estimate will not fit is refused before
it starts drawing.

**With narration the app's timestamps are replaced** by the voice's own
durations (`narrationPlan` / `retimeEvents`): each beat runs `ceil(spoken +
breath)` whole seconds, and a clip longer than 60 s is dropped rather than
trimmed. So narration makes a film longer than the estimate above and adds one
TTS call per sentence — which is what actually loads the render queue.

For a concurrency test the useful shape is several films each long enough to
still be rendering when the next request arrives — a minute or two of captioned
film — rather than one enormous one.

# 9. Translating a tutorial

    cd tools/tutorial_translate
    python translate.py run D:/chess/tutorijal/fixed D:/chess/tutorijal/sr --language "Serbian (Latin script)"

One tutorial file or a folder of them in, one translated file per tutorial out,
plus `REPORT.txt` and a `_work/` folder. The translated files are imported like
any other (section 4): „Import from a file", and the labels field there can mark
the whole set, e.g. `sr`. `--tag sr` writes that label into the files instead.

**The model never sees a move.** `translate.py` pulls every piece of prose out
of the tutorial into a flat list of `{id, text}` — the title, the description,
each part's title, instruction and answers, and the words of each `{ }` comment
with its `[%cal]`/`[%csl]` taken out — and sends only that to `agy`, with
`prompt.md` in front of it. The translations are written back into the same
places. Moves, arrows, positions and which answer is right never leave the
script, and after writing it proves it: each part's `pgn` with the comments
removed must be byte-identical to the source's, and every field that is not
prose must be equal. Nothing in the script parses a move; the app has one PGN
reader and this is not a second one.

**Every string is checked before anything is written**: every id back once and
none invented; the chess notation identical token for token (`Lc4` for `Bc4`
fails, so does `Bxf7 +`, so does a dropped `6...`); no `{`, `}` or `[%` inside a
comment; no Cyrillic in a Latin-script language. A rejected string is sent back
once with its reason. If it fails again the tutorial is **not written** and the
report names the id — fix `_work/<name>.tr.json` by hand and run `merge` with
the same arguments, which uses the strings already there and calls nothing.
Unchanged strings and strings much shorter or longer than their source are
reported as warnings, which is what a skipped sentence or an added explanation
look like.

`run` skips a tutorial already in the output folder, so an interrupted batch is
resumed by running it again; `--redo` starts over. `--model` picks one of
`agy models`; the default is `gemini-3.8-flash-high`.

**What was measured, 11.9.2026.** The extraction and the write-back were run
over all 27 files in `fixed/` with each tutorial's own text as its
„translation": 703 strings, 1134 notation tokens, no false alarm, and the
proof passes on every part — the only byte that moves is a space between two
commands in one comment. Ten kinds of fault were injected and all ten were
caught with the right reason. One real run —
`adv_endgame_tarrasch_rule_active_rook.json` into Serbian — passed every check
first time and reads **clean** through the app's own `readTutorialJson`, four
parts of four. Its Serbian was good; its two slips („lekcija" for tutorial, and
„Crni" capitalised mid-sentence) are why the glossary in `prompt.md` has those
two lines.

Three things that are true and not the script's to fix:

- **The app reads a tutorial aloud in English only.** `SpeechService.
  preferredLanguages` is `['en']` since the English pivot, and it deliberately
  asks for no other. It does not know what language a sentence is in, so a
  Serbian tutorial's ▶ in the app is **read by an English voice** — the
  wrong-language reading that rule was written to prevent, arriving by another
  door. An exported film is different: the export sheet chooses its own voice,
  and Azure has Serbian in both scripts.
- **A tutorial written in the studio has no file.** There is an import and no
  export, so the batch runs on files written outside the app, like the 27.
- **The old `gemini` CLI no longer signs in** (Google moved individual accounts
  to Antigravity), and the backend's `GEMINI_API_KEY` is on the free tier —
  twenty requests a day, shared with the app's AI comments. `agy` uses the
  Antigravity account and neither of those.
