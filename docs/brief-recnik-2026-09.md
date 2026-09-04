# Brief: the vocabulary sweep

Written 4.9.2026. Pairs with [TASK-recnik.md](TASK-recnik.md), which holds the
scope and the method. This file holds the *why*, the shape of the gate, and the
rules that get the work rejected.

Phase 4 of [PLAN-JEDNOSTAVNOST.md](PLAN-JEDNOSTAVNOST.md). Phases 0, 1 and 2 are
merged; phase 3 is the lead's and does not block this.

**This is the one batch in this project where „a string changed" is the work
rather than the defect.** Everything below exists because of that inversion.

## 1. Why this job exists

The repertoire grew its vocabulary from the inside. *Kičma* is what the code
calls the trunk it writes; *nacrt* is what the column `source = 'auto'` felt
like; *širina* is a database column; *pokrivenost* is what the walk computes.
Every one of them is an accurate name for an implementation, and not one of them
is a word a twelve-year-old would use about their own opening.

The glossary in `PLAN-JEDNOSTAVNOST.md` retires seven of them and says what is
shown instead. This batch is that glossary applied.

**It is not a rename.** Nothing in the code changes name — not a column, not a
route, not a variable. Seven words stop appearing on screen; that is the whole
job.

## 2. Why a table and not a rule

A sweep by word stem is dangerous here, and the two cases that prove it are in
the table's own preamble:

* `'Nacrtaj strelicu'` in `chess_game_screen.dart` matches the stem `nacrt` and
  means *draw an arrow*. A mechanical sweep renames a board control.
* `'pokriveno ${...}%'` in `opening_judge_service.dart` is inside an
  `AppLogger.log` and is not user-facing at all.

So every replacement was decided by hand and written down. `docs/TABELA-RECNIK-2026-09.md`
is the contract: **47 rows the gate can see, 3 it cannot, 2 that must not be
touched.**

The table was re-checked against `master` on 4.9.2026 with the gate's own
`scan_strings`, and it moved twice — five keys had lost a trailing space in
transcription, and seven new literals had arrived with that day's live fixes.
Both would otherwise have surfaced as a red batch that read like your mistake.
`orchestrator/check_table.py` is that check; it is worth running again if this
brief sits unused for a week.

## 2a. How to read a cell — the table is not written in Dart

**The `old` and `new` cells are in the gate's normalised form, not in the text
that is in the file.** `scan_strings` collapses every interpolation in a Dart
string to `${...}` and every bare `$identifier` to `$ident`, and the table is
written in that space because that is the space the gate compares in.

So a cell is a **pattern, not a search string**. Two of the forty-seven, with
what is actually in the file:

| the table says | `repertoire_build_screen.dart` really says |
|---|---|
| `Pokriveno $ident% onoga što ćete sresti; ` | line 1934: `'Pokriveno $covered% onoga što ćete sresti; '` |
| `$ident Ova pozicija je van širine „${...}", pa je ` | line 2338: `'$note Ova pozicija je van širine „${breadthName(_breadth)}", pa je '` |

**16 of the 47 rows carry a placeholder. The other 31 are plain text and can be
copied straight across.** A blind `content.replace(old, new)` over a whole file
does the 31 and silently does nothing for the 16 — no error, no diff, and a
report that says the table was applied. That is precisely the failure this
project keeps paying for: a step that skips, reports success, and is found one
layer later. Here the layer is the strings gate, which will fail those 16 as
"not rewritten" without telling you they were never findable.

### How to work one of the 16

1. Take the **longest run of plain text** in the cell — the part with no
   placeholder. For the first row above that is `% onoga što ćete sresti; `.
2. `grep` for it in the file named by the section. That finds the real line.
3. Change **only the words**. Every `$identifier` and every `${expression}`
   stays exactly as it is, character for character: the placeholder marks where
   an expression sits, and the expression is code that has to keep compiling and
   keep meaning what it meant.
4. The replacement's placeholders appear in the same order as the key's. If they
   do not — a row where the counts differ — that is §4's "a row you cannot
   apply": report it and stop.

Trailing spaces are part of the cell, in the normalised form as much as in the
file.

## 3. How you are judged

### 3.1 The strings gate reads the table

`gate_strings(..., allow_rewritten=table)` no longer asks „is the copy identical
to master". It asks:

* is every `old` **gone** from that file?
* is every `new` **present** in that file?
* did **anything else** in those files change?

All three have to hold. A wording of your own fails the second and third; a row
you skipped fails the first. This is deliberately tighter than a normal batch:
the gate that usually protects the copy is the gate you are steering.

### 3.2 The tests are already written, and you may not touch them

**21 assertions across 6 test files** quote the old wording. The lead has
already rewritten them to the new wording on this branch, so the suite is red
when you start and your job is to make it green without editing a test.

That order is not bureaucracy. An earlier batch in this project was allowed to
write the tests that judged it and produced tests that pumped no panel and
proved nothing. A worker who cannot edit the assertions cannot produce that.

The six files, so you recognise the failures:

| file | assertions |
|---|---|
| `repertoire_build_test.dart` | 8 |
| `repertoire_build_layout_test.dart` | 5 |
| `repertoire_tree_legend_test.dart` | 4 |
| `draft_review_empty_answer_test.dart` | 2 |
| `repertoire_breadth_dialog_test.dart` | 1 |
| `repertoire_coverage_test.dart` | 1 |

Three more mentions are in **comments** — in those files and in
`repertoire_breadth_wire_test.dart` — and they stay exactly as they are. A
comment quoting „Samo glavna linija" is explaining what once went wrong, and it
does not stop being true because a label moved.

### 3.3 The three the gate is blind to

`scan_strings` walks into an interpolation to keep quotes paired and does **not**
record what it finds there. Three of the strings are nested that way, all in
`repertoire_coverage_screen.dart`, and the gate will pass whether or not you
touch them.

They are listed in the table with their line numbers. **Quote all three in your
report as they now read.** An unquoted one is treated as not done.

## 4. What gets the work rejected

* **A wording that is not the table's.** Even a better one. If a replacement
  reads badly in place, that is a report line and a stop, not an edit.
* **Any change under `chess_app/test/`.** §3.2.
* **A renamed identifier.** `_widthNames`, `kBreadthNames`, `breadthName`,
  `_cutHere`, `draft`, `pruned` — all stay. The glossary is about the reader.
* **A comment rewritten to match.** The comments explain the code and use the
  code's words on purpose; several of them explain why a word was retired and
  would become nonsense with the word removed.
* **A file reformatted beyond the lines you edited.**
* **A row applied „close enough".** Byte for byte, trailing spaces included.

## 5. Two rules that bite in Serbian

**Inflection.** Where a replacement sits next to a number, the noun and its
participle move together: „Dodata 1 pozicija", „Dodate 2 pozicije", „Dodato 5
pozicija" — and 11 to 14 go with the five. `serbianCount` in
`lib/core/services/serbian_plural.dart` has the three forms and its own tests.
The table's replacements were written to avoid introducing a new agreement
problem; if one of them does, report the row rather than inventing a fourth
form.

**The retired words are retired everywhere, including inside a sentence.** The
table catches the ones that exist today. If applying a row leaves a retired word
standing in the same sentence — because the sentence was longer than the key —
that is a row the table got wrong: report it, with the whole sentence.

## 6. What this batch is not allowed to fix

You will pass things worth fixing. Leave them and write them down:

* the two false positives in §2 stay exactly as they are;
* `chess_backend/` is out of scope entirely, including the Serbian error
  messages the routes return — those are a separate decision nobody has taken;
* the wording of anything not in the table, however tempting;
* anything on a screen outside the seven files.

## 7. Your report

`report-recnik.md` in the worktree root. §"Your report" of the TASK lists what
it must contain. The two that are usually skipped and matter most here: **the
three interpolated strings quoted in full**, and **any assertion you believe is
wrong, having changed nothing.**
