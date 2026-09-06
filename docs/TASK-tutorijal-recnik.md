# Task: one word for the thing, one word for the room

A bounded job for an outside agent. **This file plus
[brief-tutorijal-recnik-2026-09.md](brief-tutorijal-recnik-2026-09.md) and
[TABELA-TUTORIJAL.md](TABELA-TUTORIJAL.md) are the only context you get** — do
not rely on any conversation before them.

Branch: `batch/tutorijal-recnik`. Commit as
`batch 51 — rečnik: tutorijal i čas`. **Do not commit.** Leave the worktree
dirty; the lead reads the diff.

## What is asked

Flutter only, in `chess_app/lib/`. Apply
[TABELA-TUTORIJAL.md](TABELA-TUTORIJAL.md), which is a frozen table of exact
rows: file, current string, replacement.

1. **Table A** — every listed string becomes the „Tutorijal" wording given.
2. **Table B** — three strings become „Čas". They are the live session in a
   room, and they are the reason this job exists.
3. **Table C** — listed things are **not** touched. Read the reasons; they are
   short and each one is a fault somebody would otherwise introduce.

**Nothing else.** No identifier renamed, no file renamed, no API field renamed,
no class renamed, and **`chess_backend/` is not yours at all** — it is frozen
and the lead has already changed its half.

If the job turns out to need a change outside those tables, **write in your
report which change and why, then stop.** Do not widen the scope.

If a file named in the table is not there, **stop and say so in the report.**
Do not find the nearest plausible file and edit that.

## The one thing that is not mechanical

„Lekcija" is feminine and „Tutorijal" is masculine. Every agreeing word around
the noun changes with it:

* „Ova lekcija nema nijedan korak." → „**Ovaj** tutorijal nema nijedan korak."
* „Lekcija je poslata učeniku." → „Tutorijal je **poslat** učeniku."
* „Lekcija sa varijacijama je uspešno sačuvana!" → „… je uspešno **sačuvan**!"
* „Nemate nijednu sačuvanu lekciju." → „Nemate **nijedan sačuvan** tutorijal."

A find-and-replace produces „Ova tutorijal" and there is a gate test that fails
on exactly that. Every replacement is written out in full in the table — use the
table's wording, do not compose your own. Where the table's wording reads wrong
in its context, **report it; do not improve it.**

## Method

1. `cd chess_app && flutter test` **before changing anything**, and write the
   number down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the list. It does **not** exit clean and
   has not for a long time: 29 issues, all `info`, all
   `curly_braces_in_flow_control_structures`. What must hold is **zero errors,
   zero warnings, and no new infos** — compare the list, not the exit code.
3. Work file by file, in the table's order.
4. `dart format` every file you touch. The formatter reindents aggressively and
   an unformatted file turns the next diff into noise.
5. `flutter test` and `flutter analyze` after. Both numbers go in the report.

## What the report must contain

Write it to `docs/REPORT-batch-51.md`.

* the test count **before and after**, both measured by you in this run;
* the analyzer list before and after — say whether it changed, not just how
  many;
* every file you changed, and the number of rows applied per file;
* every table row you did **not** apply, and why;
* anything the table got wrong: a string that is not there any more, a line
  number that has drifted, a replacement that does not fit its sentence. **A
  correction is worth more to us than a clean report.**
