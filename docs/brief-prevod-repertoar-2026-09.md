# Brief — the English pivot, batch 3 of 4: repertoire and the trainers

Written 8.9.2026 by the lead, after batches 1 and 2 landed. This brief and
`docs/TASK-prevod-repertoar.md` are the whole of the context for this batch.

## Where this sits

Two batches are done: the screens and the home tabs, then the tutorial, the
lessons and the assignments. **972 lines of Serbian copy are left in `lib/`**
and they are being split in two. This is the first half: everything a player
*practises* with — the repertoire, the endgame trainer, the tactics trainer.
The other half is the analysis studio, the shared widgets and what is left
over, and it is briefed after this one lands.

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** Its
two standing rules apply here as everywhere:

* **Tutorial** is what a trainer writes; **Session** is the live meeting in a
  room. Never write „Lesson" on a screen — in code that word already means the
  written artefact.
* **The copy addresses a player, a student and a trainer, never a child.**

## The vocabulary this batch adds

The repertoire has its own settled Serbian wording — plain sentences the owner
approved during the simplicity plan, and they are the reason these screens read
the way they do. **Translate the voice, not only the nouns.** „Spremno je 47%
onoga što ćete sresti" is not „47% is ready of what you will meet"; it is
something like `You are ready for 47% of what you will meet.`

| Serbian | English | Note |
|---|---|---|
| repertoar | **repertoire** | |
| grana | **branch** | One line you are preparing. „Ovu granu više ne spremam" → `I am not preparing this branch any more.` |
| glavna linija | **main line** | |
| sporedna linija | **sideline** | |
| kičma | **spine** | The skeleton of a repertoire — the main line built out first |
| širina | **breadth** | How many replies you prepare against |
| pokrivenost | **coverage** | |
| nepotvrđen potez | **unconfirmed move** | A move the app proposed and you have not accepted |
| u pripremi / spremam | **preparing** / **in preparation** | |
| red (queue) | **queue** | „Vratiće se u red i sutra" → `It will be back in the queue tomorrow.` |
| dril, vežbanje | **drill** | The wire path `/repertoire/drill/...` is a value and stays |
| sparing | **sparring** | |
| Upoznaj repertoar | **Tour your repertoire** | The guided walkthrough screen |
| završnica | **endgame** | |
| remi | **draw** | |
| dobitak | **win** | „zadržite dobitak" → `hold the win` |
| drži / drže | **holds** | „$san ne drži remi" → `$san does not hold the draw.` |
| motiv | **motif** | Tactics |
| zagonetka | **puzzle** | |

If a word here is wrong, say so in the report — do not quietly use a better one.
The manual in Phase 4 is written against these.

## Scope: 26 files, 456 lines

```
  1  features/puzzle_trainer/puzzle_notifier.dart
  1  features/repertoire/widgets/repertoire_position_ask.dart
  1  features/training/widgets/resume_strip.dart
  2  features/repertoire/screens/repertoire_walkthrough_screen.dart
  2  features/repertoire/services/repertoire_api_service.dart
  2  features/repertoire/widgets/unconfirmed_banner.dart
  2  features/tactics_trainer/services/tactics_api_service.dart
  3  features/endgame_trainer/models/endgame_puzzle.dart
  4  features/repertoire/widgets/fork_repertoire_dialog.dart
  4  features/repertoire/widgets/repertoire_gate_picker.dart
  5  features/repertoire/services/walkthrough_speech.dart
  7  features/repertoire/widgets/repertoire_comment_panel.dart
  8  features/endgame_trainer/services/endgame_api_service.dart
  9  features/endgame_trainer/screens/endgame_picker_screen.dart
  9  features/endgame_trainer/services/holding_pattern.dart
 11  features/repertoire/screens/repertoire_coverage_screen.dart
 11  features/repertoire/widgets/repertoire_tree_panel.dart
 12  features/repertoire/screens/repertoire_new_screen.dart
 15  features/repertoire/widgets/breadth_dialog.dart
 16  features/endgame_trainer/models/drill_step.dart
 22  features/tactics_trainer/screens/tactics_trainer_screen.dart
 34  features/endgame_trainer/screens/blunder_walk_screen.dart
 46  features/repertoire/screens/repertoire_list_screen.dart
 64  features/repertoire/screens/repertoire_drill_screen.dart
 77  features/endgame_trainer/screens/endgame_trainer_screen.dart
 88  features/repertoire/screens/repertoire_build_screen.dart
```

All under `chess_app/lib/`. Counted by `gate_english_ui` on 8.9.2026: lines
holding at least one Serbian literal. **Smallest first.**

**Do not touch `chess_backend/`.** Not one file. **Do not touch
`lib/features/analysis_studio/`, `lib/widgets/`, `lib/core/`, `lib/services/`
or anything else outside the list** — that is the next batch.

## The three traps in these files specifically

**1. `walkthrough_speech.dart` is read aloud.** Its strings are spoken by a
text-to-speech voice, not printed. Two consequences: a sentence that looks fine
on a screen can be unreadable aloud, and abbreviations are worse than words.
Write what a person would say.

**2. `holding_pattern.dart` and `drill_step.dart` are models with verdicts in
them.** „Drže rezultat", „Drže samo potezi ${_pieceNames[piece]}" — these are
sentences assembled from pieces, and the assembly is where an English sentence
breaks. Serbian conjugates the verb to the number of moves; English needs
„Only the ${piece} moves hold." or a rewrite. **Rewrite rather than reword.**

**3. Serbian counts in three, English in two.** „Danas ste odvežbali 21
poziciju" against „2 pozicije" against „5 pozicija" — the helpers written for
those forms become two-form English helpers. Do not leave one returning three
different words.

## The rules that bite

**Translate the meaning, not the words.** „Još nema šta da se vežba." is
`Nothing to drill yet.`

**Tests are part of the string.** Hundreds of tests assert on exact copy with
`find.text`. A string changed without its test turns the suite red, and a test
changed without its string does too — both, in the same edit. `grep` the old
text across `chess_app/test/` before moving on. You may edit any test file. You
may **not** delete a test, weaken an assertion, or relax a matcher to make
something pass. If a test cannot be made green by translating it, stop and say
so — that is a finding, not an obstacle.

**Values are not copy.** API paths like `'$backendUrl/repertoire/drill/answer'`,
JSON keys, status strings and anything compared against a server response stay
exactly as they are. The test: would the app still work if the server had never
heard of this string? If yes, it is copy.

**Log lines and comments are not in scope.** The gate skips both.

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
| `english ui` | no Serbian letter left in any string literal in the 26 files |
| `flutter test` | **1774 passing**, 1 skipped |
| `flutter analyze` | 29 infos, no errors, no warnings |
| `dart format` | every file you touched is formatted |
| `strings` | steps aside for these 26 files, grades the rest as usual |
| `contrast`, `idioms`, `scale`, `worktree` | unchanged — this batch moves no widget |

Measure the test count yourself, before and after. Do not trust a number quoted
at you, including the one in this brief.

## What the report must contain

Numbers you computed in this run:

1. Test count **before** and **after**, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every **test file** you edited, and why.
5. Every sentence you had to **rewrite rather than translate** — the assembled
   verdicts, the plurals, anything that only worked because of Serbian word
   order. This is where the meaning gets lost and it is what the reviewer reads
   first.
6. Every term in the table above that turned out to be wrong or missing.
7. **Anything this brief got wrong.**

**Write only what you did.** Both previous reports had accurate numbers and one
invented section — buttons that exist nowhere, and copy saying „Puzzle session"
that was never written. Nothing was built on either, and the gates never read
them, but each cost the reviewer an hour proving it was fiction. A short report
that is entirely true is worth more than a thorough one that is not.

## Out of scope

Everything not in the 26 files: `chess_backend/`, the rest of `lib/`, the
anchors in `docs/gates/`, the legal texts. Do not commit. Do not branch. Do not
`git add`.
