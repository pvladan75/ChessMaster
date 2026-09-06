# Brief: Tutorijal and Čas

Companion to [TASK-tutorijal-recnik.md](TASK-tutorijal-recnik.md). That file is
the instruction; this one is why the job exists and what will judge it.

## Why

The app is a chess coaching platform for Serbian children and their trainers.
Two completely different things are called „lekcija" today:

* **the artefact** a trainer writes and assigns — a series of positions with
  lines, comments and questions, which a child opens alone at home;
* **the live session** in a room, with a trainer, a shared board and voice,
  happening right now.

So „Poziv na lekciju" (a room opening this minute) and „Zadaj lekciju"
(homework for Thursday) read to a child as the same event. The owner froze the
split on 6.9.2026: the artefact is a **Tutorijal**, the live session is a
**Čas**. A third word — „kurs" — names the artefact in nine more places and goes
the same way, because a glossary that leaves it standing has not finished the
job.

The users are children. This is not a cosmetic rename.

## The contract

[TABELA-TUTORIJAL.md](TABELA-TUTORIJAL.md), and nothing else. It has five
tables:

| table | what |
|---|---|
| A | app strings that become „Tutorijal" — about 50 rows |
| B | three strings that become „Čas" |
| C | what is **not** touched, with the reason for each |
| D | backend strings — **already done by the lead**, not yours |
| E | (folded into A) the „kurs" rows |

The judgement happened before the batch on purpose. The last vocabulary sweep on
this project worked for exactly that reason: a sweep that decides as it goes
decides differently in the fortieth file than in the first.

## Rules that bite on this codebase

* **The repository is public.** Never put secrets, IP addresses, email
  addresses or account identifiers into docs, comments or code.
* **User-facing strings stay Serbian.** They always were; this job changes which
  Serbian words, not the language. Code comments and your report are English.
* **`flutter analyze` does not exit clean** — 29 `info`-level issues,
  all `curly_braces_in_flow_control_structures`, in six files. Do not fix them,
  do not treat the red exit code as your failure. Compare the list.
* **Run `dart format` on any Dart file you edit.** CI does not enforce it.
* Do not touch `chess_backend/`, `docs/` (except your report), `deploy/` or
  `puzzles/`.

## Baselines, to measure yourself

`cd chess_app && flutter test` reads **1372 passing, 1 skipped** on the commit
you were given. The one skip is a golden-screenshot group, skipped
unconditionally in `dart_test.yaml`; leave it alone.

Your change should move neither number. If the count drops, find out why before
carrying on — a suite that quietly stops running half of itself is the thing
these numbers exist to catch.

## How it will be judged

By machine, against `docs/gates/tutorial_vocabulary_test.dart`, which the lead
copies into `chess_app/test/` and runs on your tree. It fails if:

1. **any Dart string literal under `lib/` still contains `lekcij` or `kurs`**,
   in any case, outside the allowances in Table C. Comment lines are skipped;
   string literals are not.
2. **any replacement from Tables A–B is missing.** It checks per file, with the
   gender-agreement wordings spelled out.
3. **the gender agreement is wrong** — „Ova tutorijal", „tutorijal je poslata"
   and six more phrasings a find-and-replace produces.
4. **anything outside the table was renamed** — `TutorialViewerScreen`,
   `tutorial_api_service.dart`, `'tutorijal_kurs'` and the like.

It has already been run against the current tree and it is red in the two ways
it should be: 50 leftover strings, and every replacement missing. When you are
done it must be green in all five tests.

Your report is not the verdict. The gate is.

## What is out of scope, said once

* Renaming identifiers, files, classes, API fields or database columns.
* The tag value `'lekcija_kurs'` — it is stored data, and rewriting it splits
  one label into two that never match. A migration is a separate, lead-owned
  job.
* Log lines (`AppLogger.log`). They are read by us, not by a child, and leaving
  them keeps the diff exactly the size of what a reader sees.
* `PLAN-INTERAKTIVNA-LEKCIJA.md` mentioned in doc comments. It is a file name,
  and that file still has that name.
* Anything in `chess_backend/`. The lead has already changed the server's
  twelve user-facing strings so the two halves cannot disagree in front of a
  child.
