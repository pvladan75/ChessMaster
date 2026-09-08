# Brief — the English pivot, batch 65a: the analysis studio and the scanner

Written 8.9.2026 by the lead, after batches 62–64 landed and after the lead's
own commit `b694d3b`. This brief and `docs/TASK-prevod-analiza.md` are the whole
of the context for this batch.

## Where this sits

Three translation batches are done — the screens and the home tabs, then the
tutorial and the assignments, then the repertoire and the trainers. **488 lines
of Serbian copy are left in `lib/`**, and they are being split in two. This is
the first half: the Analysis screen, the AI-studio hub and the position scanner.
The other half — the games archive, the shared widgets, the services, groups,
the trainer panel, the library and reviews — is briefed after this one lands.

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** Its
two standing rules apply here as everywhere:

* **Tutorial** is what a trainer writes; **Session** is the live meeting in a
  room. Never write „Lesson" on a screen — in code that word already means the
  written artefact.
* **The copy addresses a player, a student and a trainer, never a child.**

## Two files in this area were already translated, and their words are law

`lib/core/services/tactical_motif_detector.dart` and
`positional_evaluator_service.dart` were done by the lead in commit `b694d3b`,
because they are not copy but a Serbian sentence *generator* — a grammatical
gender per piece noun, a nominative and an accusative for each, three plural
forms for a count. Deleting that machinery is a refactor, not a translation.

**They are out of scope and must not be edited.** What matters to you is that
they now emit exactly these words, and two panels in this batch —
`tactical_findings_panel_widget.dart` and `positional_findings_panel_widget.dart`
— label the *same* motifs. A panel that says "Double pawns" over a sentence that
says "Doubled pawns" is the vocabulary coming apart in the one place a user sees
both at once.

| Serbian | English, as already shipped |
|---|---|
| Viljuška | **Fork** |
| Vezivanje | **Pin** |
| Ražanj | **Skewer** |
| Otkriveni napad / šah | **Discovered attack** / **Discovered check** |
| Preopterećenje, preopterećena figura | **Overloaded piece** |
| Skretanje | **Deflection** |
| Dvojni udar | **Double attack** |
| Nebranjena figura | **Undefended piece** |
| Pretnja mata | **Mate threat** |
| Udvojeni pešaci | **Doubled pawns** |
| Izolovani pešak | **Isolated pawn** |
| Zaostali pešak | **Backward pawn** |
| Prolazni pešak | **Passed pawn** |
| Pešačka ostrva | **Pawn islands** |
| Otvorena / poluotvorena linija | **Open** / **half-open file** |
| Kontrola centra | **Centre control** |
| Lovački par | **Bishop pair** |
| Slab kompleks polja | **Colour complex weakness** |
| Uporište | **Outpost** |
| Pešački štit (kralja) | **Pawn shield** |
| Pažnja — / Rešeno — | **Watch out —** / **Resolved —** |

`grep` those two files if you want to see a whole sentence. **Do not change
them.**

## The vocabulary this batch adds

| Serbian | English | Note |
|---|---|---|
| Analiza (ekran) | **Analysis** | The screen's name is settled — see `GLOSSARY-EN.md` |
| motor | **engine** | Never "motor" |
| ocena, eval | **evaluation** | "eval" is fine where the screen is tight |
| dubina | **depth** | |
| linija (motora) | **line** | An engine line, and a line of moves. Both are "line" |
| linija (a–h) | **file** | The d-file, never the d-line. See trap 2 |
| stablo | **tree** | |
| grana | **branch** | "Produži granu" is `Extend the branch` |
| varijanta | **variation** | "Obriši Ovu Varijantu" is `Delete this variation` |
| čvor | **node** | Only in logs and progress counters |
| baza otvaranja | **opening database** | |
| pešak (as a unit of evaluation) | **pawn** | "0.8 pešaka" is `0.8 pawns` |
| presuda, suđenje poteza | **verdict**, **judging a move** | The opening judge panel |
| Nije presuđeno | **No verdict** | |
| Praktična alternativa | **Practical alternative** | |
| vežba (in these screens) | **puzzle** | **See trap 1 — this is not "drill" here** |
| zagonetka | **puzzle** | |
| skup vežbi | **puzzle set** | |
| greška, previd | **mistake**, **blunder** | "Blunder Alert" already reads English; keep it |
| prag greške | **blunder threshold** | |
| automatska analiza | **automatic analysis** | |
| orezivanje, cutoff | **pruning**, **cutoff** | |
| skener, dijagram | **scanner**, **diagram** | The position scanner reads books |
| strana (in a book) | **page** | Never "side". See trap 3 |
| strana na potezu | **side to move** | The other "strana". Read each one |
| rešenje | **solution** | |
| traži pogled | **needs a look** | A scanned position the book did not settle |
| ručno slaganje | **piece placement** | The board-setup tab |
| korisničko ime | **username** | |

If a word here is wrong, say so in the report — do not quietly use a better one.
The manual in Phase 4 is written against these.

## Scope: 29 files, 268 lines

```
  1  features/analysis_studio/services/opening_explorer_service.dart
  1  features/analysis_studio/widgets/opening_explorer_panel_widget.dart
  1  features/analysis_studio/widgets/opening_picker.dart
  1  features/position_scanner/services/side_proposal_runner.dart
  1  widgets/ai_studio/grouped_moves_dialog.dart
  1  widgets/ai_studio/pgn_solution_tree_widget.dart
  2  features/analysis_studio/widgets/visual_move_tree_widget.dart
  2  widgets/ai_studio/studio_info_header.dart
  3  features/analysis_studio/services/auto_tree_generator_service.dart
  3  features/analysis_studio/widgets/move_tree_widget.dart
  3  features/analysis_studio/widgets/quick_extend_dialog.dart
  3  widgets/ai_studio/solution_graph_widget.dart
  4  features/analysis_studio/services/position_info_service.dart
  4  features/analysis_studio/widgets/tactical_findings_panel_widget.dart
  5  features/analysis_studio/widgets/saved_puzzle_sets_dialog.dart
  5  features/position_scanner/services/side_proposal.dart
  6  features/analysis_studio/services/chess_platform_import_service.dart
  6  features/analysis_studio/widgets/auto_analysis_dialog.dart
  7  features/analysis_studio/widgets/positional_findings_panel_widget.dart
  8  features/position_scanner/widgets/assign_positions_dialog.dart
  9  features/position_scanner/services/scanner_api_service.dart
 15  features/analysis_studio/widgets/board_setup_dialog.dart
 15  features/analysis_studio/widgets/game_review_dialog.dart
 19  features/position_scanner/screens/scan_review_screen.dart
 20  features/analysis_studio/widgets/opening_judge_panel_widget.dart
 27  features/analysis_studio/dialogs/analysis_studio_dialogs.dart
 28  widgets/ai_studio/category_selection_hub.dart
 30  features/position_scanner/screens/saved_positions_screen.dart
 38  features/analysis_studio/screens/analysis_studio_screen.dart
```

All under `chess_app/lib/`. Counted by `gate_english_ui` on 8.9.2026: lines
holding at least one Serbian literal. **Smallest first.**

**Do not touch `chess_backend/`.** Not one file. **Do not touch `lib/core/`,
`lib/services/`, `lib/features/archive/`, `lib/features/groups/`,
`lib/features/library/`, `lib/features/reviews/`, `lib/features/trainer_panel/`,
`lib/widgets/` outside `lib/widgets/ai_studio/`, or anything else outside the
list** — that is the next batch.

## The four traps in these files specifically

**1. "Vežba" is a puzzle here, not a drill.** The glossary maps "vežba, dril" to
**drill**, and that is right in the repertoire and the endgame trainer, where you
walk a line. In these screens it is a *position extracted from a blunder*, and
the code has already decided: `extractedPuzzles`, `saved_puzzle_sets_dialog.dart`,
`_maxPuzzles`, `local_puzzle_extractor_service`. So "Sačuvane vežbe" is `Saved
puzzles`, "Izvučeno 7 vežbi" is `7 puzzles extracted`, "Prethodna vežba" is
`Previous puzzle`. A UI word that disagrees with the identifier under it costs a
guess in every bug report.

**2. "Linija" is two different words and they sit next to each other.** In the
opening panels and the positional findings, "${_fileLetter(f)}-linija" is a
**file** (a–h). In the engine panel and the move tree, "linija" is a **line** of
moves. Read which one each string means; a d-line is not a thing.

**3. "Strana" is two different words in the same screen.** In the scanner,
"strana 42" is a **page** of a book and "strana na potezu" is the **side to
move**. `saved_positions_screen.dart` and `scan_review_screen.dart` both use
both, sometimes three lines apart.

**4. `position_info_service.dart` names openings.** "Sicilijanska ili Kraljev
Skakač", "Španska Partija (Ruy Lopez)", "Središnjica / Nepoznato Otvaranje",
"Završnica (5 figura — Syzygy…)". Opening names have settled English forms —
**Sicilian**, **Ruy Lopez**, **Middlegame / Unknown opening**, **Endgame** — and
these are not to be invented. If you are not sure of a name, say so in the
report rather than guessing.

## The rules that bite

**Translate the meaning, not the words.** "Još nema sačuvanih pozicija." is
`No saved positions yet.`

**Tests are part of the string.** Hundreds of tests assert on exact copy with
`find.text`. A string changed without its test turns the suite red, and a test
changed without its string does too — both, in the same edit. `grep` the old
text across `chess_app/test/` before moving on. You may edit any test file. You
may **not** delete a test, weaken an assertion, or relax a matcher to make
something pass. If a test cannot be made green by translating it, stop and say
so — that is a finding, not an obstacle.

**The gate cannot see Serbian in a test.** `gate_english_ui` reads `lib/` and it
matches on `šđčćž`. Five assertions in the lead's own commit had **no diacritic
at all** — `contains('Beli')`, `contains('otvorenu')`, `contains('je otvorena')`
— and only the suite found them. When you translate a string, grep the tests for
the *old Serbian words*, not for accented letters.

**Values are not copy.** API paths, JSON keys, status strings, `'w'`/`'b'`, ECO
codes and anything compared against a server response stay exactly as they are.
The test: would the app still work if the server had never heard of this string?
If yes, it is copy.

**Log lines and comments are not in scope.** The gate skips both. Translating a
`debugPrint` is wasted time and enlarges the diff.

**If a file named above is missing, stop and say so.** Do not substitute the
nearest plausible file.

## What already exists

* `docs/GLOSSARY-EN.md` — the terms, the pair, the register rule.
* `docs/gates/vocabulary_en_test.dart` and `docs/gates/screen_names_en_test.dart`
  — the anchors for the whole pivot. **Not** in `test/` and not to be moved
  there: they go green only when the last batch lands, and a red suite hides the
  next real failure. Run them to see how you are doing. Some assertions name
  files outside this batch and will still fail. Expected.
* `AppFeedback` — every user message goes through it. A raw `ScaffoldMessenger`
  fails a test.

## How this is graded

By machine, after you stop. Your report is evidence to read, not the verdict.

| gate | passes when |
|---|---|
| `english ui` | no Serbian letter left in any string literal in the 29 files |
| `flutter test` | **1772 passing**, 1 skipped |
| `flutter analyze` | 29 infos, no errors, no warnings |
| `dart format` | every file you touched is formatted |
| `strings` | steps aside for these 29 files, grades the rest as usual |
| `contrast`, `idioms`, `scale`, `worktree` | unchanged — this batch moves no widget |

Measure the test count yourself, before and after. Do not trust a number quoted
at you, including the one in this brief.

**Run the whole suite at most once, at the end.** Batch 64 was briefed to run
the tests after each of twenty-six files. Twenty-six suite runs at three minutes
is seventy-eight, which is more than the whole budget before any thinking
happens. That instruction was the lead's and it is withdrawn. Translate the
files, grep the tests, fix what you find by reading, and run the suite once when
you are done.

## What the report must contain

Numbers you computed in this run:

1. Test count **before** and **after**, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every **test file** you edited, and why.
5. Every sentence you had to **rewrite rather than translate** — assembled
   verdicts, plurals, anything that only worked because of Serbian word order.
   This is where the meaning gets lost and it is what the reviewer reads first.
6. Every term in the two tables above that turned out to be wrong or missing,
   and every opening name you were unsure of.
7. **Anything this brief got wrong.**

**Write only what you did.** Two reports in this series had accurate numbers and
one invented section each — buttons that exist nowhere, copy that was never
written. Nothing was built on either, and the gates never read them, but each
cost the reviewer an hour proving it was fiction. A short report that is
entirely true is worth more than a thorough one that is not.

## Out of scope

Everything not in the 29 files: `chess_backend/`, the rest of `lib/`,
`tactical_motif_detector.dart`, `positional_evaluator_service.dart`, the anchors
in `docs/gates/`, the legal texts. Do not commit. Do not branch. Do not
`git add`.
