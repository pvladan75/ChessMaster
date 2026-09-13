# Brief — the skeleton in Dart, batch 70

Written 13.9.2026 by the lead. This brief and `docs/TASK-skelet.md` are the whole
of the context for this batch.

## Where this sits

A trainer's game is going to become a tutorial on their own machine
(`docs/PLAN-SKELET.md`). A chess engine analyses every position; a program
builds everything a tutorial is made of from that analysis — which moments to
offer, each moment's parts, every position, every move, every question and its
correct answers; a language model is asked only for the words; and the program
checks those words and assembles two tutorials from them, one of the key
moments and one of the whole game.

**That program already exists and is proven, in Python**:
`tools/game_annotate/skeleton.py`. Thirteen real games have been through it,
every position was exact, every question's answer was the analysis's best move,
and about two hundred of the sentences it produced were read by a person and
found true. It is the reference implementation of this batch. **Your job is to
make the app do exactly what it does** — not better, not tidier, not differently
where the Python looks odd. Where it looks odd, it was usually made that way by
a measurement, and its comments say which.

## What is already done, and must not be written again

| | |
|---|---|
| `tools/game_annotate/skeleton.py` | the reference. Read it whole before writing anything |
| `chess_app/test/fixtures/game_tutorial/g01…g10_*.json` | ten games: the facts, the model's real answer, and what the harness makes of them — `moments`, `report`, `tutorial`, `tutorialGame` (and `prompt`, which you do **not** port) |
| `chess_app/test/fixtures/game_tutorial/answer_cases.json` | five bad answers on g01, and the report and tutorials the harness made of each |
| `chess_app/lib/features/tutorial_studio/services/game_tutorial/evaluation_words.dart` | `wordsFor`, `standing`, `evaluationLevels` — ported by the lead and held to the harness by `test/game_tutorial_evaluation_words_test.dart`, ten mutations caught |
| `StudioLessonStep.from(root)` | the app's one writer of a part's `pgn`, from a chain of `AnalysisNode`s |
| `LessonStepLine.read(fen:, pgn:)` | the child's reader, which is what the gate compares a `pgn` through |

**The fixtures were written by the harness, not by hand.**
`tools/game_annotate/export_fixtures.py --check` fails the day they stop matching
`skeleton.py`. So a disagreement between your Dart and a fixture is a
disagreement with the reference, and the answer is in `skeleton.py` — never in
the fixture. **Do not edit a fixture, the gate, the harness or
`evaluation_words.dart`.** If you are certain one of them is wrong, stop and say
so in the report.

## The contract

It is in the header of `docs/gates/game_tutorial_skeleton_test.dart`, and the
header is the specification: the three frozen files and their signatures, how a
part's `pgn` is written and compared, eleven places where Python and Dart
disagree, and what must not be touched. Read all of it before writing a line.

One file beyond the three is allowed: `board_queries.dart`, in the same folder,
for the board questions python-chess answers and `package:chess` does not. It
is optional. A fifth file is not allowed.

## The part that is not a translation: `play()`

`skeleton.play` describes one move from facts python-chess computes, and three
of them have no method in `package:chess` 0.7.0:

* **`board.attacks(square)`** — the squares attacked by the piece standing on
  `square`: a slider stops at, and includes, the first occupied square in each
  direction; a pawn attacks only its two capture diagonals; a king and a knight
  their usual squares. Occupancy of the target does not matter — it is geometry.
  `package:chess` has `attacked(color, square)`, which is the opposite question
  (is this square attacked by that side) and is **not** a substitute.
* **`board.is_pinned(color, square)`** — true when the piece of `color` on
  `square` is pinned to **its own king** by an enemy rook, bishop or queen
  (an absolute pin). No king, no pin.
* **`board.is_en_passant(move)`**.

**The order is output.** `play()` walks `board.attacks(...)` and `chess.SQUARES`
in python-chess's square order — `a1, b1 … h1, a2 … h8` — and joins what it finds
into the sentence. `package:chess` numbers its internal board from **a8**. A port
that iterates its own order writes the same squares in a different sequence, and
the slot texts are compared character for character.

`tactical_motif_detector.dart` has a private `_isAbsolutelyPinned`. Lift it or
write your own; the gate decides whether it answers what python-chess answered,
on several hundred slot texts across ten games.

## Where the output goes, and why it is shaped like this

`assembleSkeleton` returns what the harness wrote into a run folder:
`meta['skeleton']` as `report`, and `tutorial.json` / `tutorial-game.json` as
maps in the shape `readTutorialJson` already opens in the studio. A later phase
wires it to the engine, the server and a button; **nothing in this batch touches
a screen, the network or the engine**, which is what lets it be judged on data
alone.

**The sentences are English.** The persona you run under says user-facing
strings are Serbian; that rule is out of date for this app, which went English
on 8.9.2026, and it does not apply here at all — every sentence in this batch is
copied from the harness, and the gate compares it character for character.

## How it will be judged

By machine, and not by the report:

* the gate, copied into `chess_app/test/`: 39 tests;
* `flutter test` — 2368 passing and 1 skipped before, **at least 2407** after, and
  nothing that was green going red;
* `flutter analyze` — 26 infos, all `curly_braces_in_flow_control_structures`,
  the **same list**, nothing new suppressed;
* `dart format` on every file touched;
* a tree gate that fails any file not named in the task.

Then the lead reads the diff and runs mutations against your code: breaks a sort
tie, a rounding, the square order, a claim rule, and expects a named test to go
red for each.

## Out of scope

The prompt (`prompt()`, `PROMPT`, `book_summary` as used by the prompt) — it
moves to the server in phase 3. The facts builder (`make_facts.py`) — phase 2.
Any widget, service, API call, engine call or `dart:io` in `lib/`.
