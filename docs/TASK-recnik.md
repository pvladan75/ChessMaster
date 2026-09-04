# TASK — the repertoire says it in the reader's words

This file plus `docs/brief-recnik-2026-09.md` are the only context you get.
**Do not rely on any conversation before them.** Read the brief first; it holds
the reasoning, the exact rules, and the pass conditions.

Branch: `design/recnik`
Commit label: none — **do not commit.** Leave the work in the worktree.

## Scope

Phase 4 of `docs/PLAN-JEDNOSTAVNOST.md`. Flutter only, in `chess_app/`.

**Do not touch `chess_backend/` at all.** Nothing here has a server side. No
column, no route and no JSON key changes; this is what the reader is *shown*.

**This batch is a table, not a judgement.** Every replacement is decided and
written down in `docs/TABELA-RECNIK-2026-09.md`: 47 rows across 7 files, plus 3
strings the gate cannot see, listed separately there. Your job is to apply that
table exactly — not to improve a wording, not to sweep a word the table leaves
alone, not to rename anything in the code.

**A wording of your own fails the batch even if every gate passes.** So does a
row you skipped. The `strings` gate now reads that table directly
(`allow_rewritten`): it checks that each `old` is gone, each `new` is present,
and that **nothing else in those files changed**.

If a row cannot be applied — the string is not where the table says, or applying
it would break a test you may not touch — **write which row and why, then
stop.** Do not improvise a near-miss.

## What you need before starting

* Flutter, and `flutter test` on the branch **before you change anything**.
  **Measure it yourself and report it; do not trust a number quoted at you.**
  It will be **red**, and that is deliberate: the lead has already rewritten the
  21 test assertions to the new wording on this branch. Those failures are your
  worklist. `master` is green and stays green.
* `flutter analyze` must stay at **29** issues, all `info`, all
  `curly_braces_in_flow_control_structures`. Compare the list, not the exit
  code.
* No backend, no database, no credentials, no network.

## The rule that makes this batch different

**You may not touch a single file under `chess_app/test/`.**

The assertions are already written to the new wording. Your pass condition is
that the suite goes green **without a test being edited**, which is the only
honest way round: a worker who may edit the thing that judges the work is a
worker grading their own homework, and that is exactly how an earlier batch in
this project produced tests that pumped no panel.

If you believe an assertion is wrong, say so in your report and stop.

## Where things are

| | |
|---|---|
| `docs/TABELA-RECNIK-2026-09.md` | **the contract.** 47 rows, by file, plus the 3 the gate cannot see |
| `docs/PLAN-JEDNOSTAVNOST.md` | the frozen glossary the table comes from, and why each word was retired |
| `chess_app/lib/features/repertoire/screens/repertoire_build_screen.dart` | the most rows |
| `chess_app/lib/features/repertoire/screens/repertoire_drill_screen.dart` | |
| `chess_app/lib/features/repertoire/screens/repertoire_coverage_screen.dart` | **and the 3 inside interpolations** — see below |
| `chess_app/lib/features/repertoire/screens/repertoire_list_screen.dart` | |
| `chess_app/lib/features/repertoire/widgets/breadth_dialog.dart` | including the three width options |
| `chess_app/lib/features/repertoire/widgets/repertoire_tree_panel.dart` | including `_widthNames` |
| `chess_app/lib/features/repertoire/widgets/unconfirmed_banner.dart` | one row |

## The files you may add

**None.** Every change is an edit to a file that already exists. Leave no
scratch files; an untracked file fails the tree gate and takes the round with
it.

## The changes, in this order

### 1. The 47 rows the gate can see

Apply `docs/TABELA-RECNIK-2026-09.md`, file by file, in the order it lists them.
Byte for byte, **including trailing spaces** — five of those rows exist only
because a trailing space was once dropped in transcription, and the gate
compares exactly.

### 2. The 3 the gate cannot see

`repertoire_coverage_screen.dart`, listed in their own section of the table with
their line numbers. They sit inside `${... ? "..." : ""}` interpolations, where
the scanner walks in to keep quotes paired and records nothing — so the gate
will say nothing about them either way. **Apply them and quote all three in your
report**, with the line as it now reads.

### 3. Nothing else

No comment rewritten, no identifier renamed, no file reformatted beyond the
lines you edited. `_widthNames`, `kBreadthNames`, `breadthName` and every other
symbol keep their names: the glossary is about what the reader is shown, and a
rename would put this batch into files the table does not cover.

## Method

1. Read the brief whole. §4 is what gets the work rejected.
2. Work one file at a time, running `flutter test` after each. The suite goes
   from red to green in steps; a file finished is a group of tests passing.
3. `flutter analyze` — the list, not the exit code.
4. **`dart format` every Dart file you touched — last.** Reformatting a file you
   did not otherwise touch fails the gate.

## What must hold

* **The strings stay Serbian.** Every one of them is read by a child.
* **Serbian inflects.** Where a replacement lands next to a number, the noun and
  its participle change together — `serbianCount` in
  `lib/core/services/serbian_plural.dart` exists for exactly this and has three
  forms. The table's replacements are written to avoid new agreement problems;
  if one of them creates one, **that is a row to report, not to fix.**
* **Never use `ScaffoldMessenger` directly** — `AppFeedback` only. You should
  not be adding a message at all, but a rewritten one must stay where it was.
* Every screen you touch keeps working. This batch changes words, and a word
  that changed shape is still a word: a `find.text` in a test you may not edit
  is the check that it landed.

## Your report

Write `report-recnik.md` in the worktree root, stating:

1. `flutter test` before and after, **both measured by you in this run**, and
   the count of failures you started with;
2. the `flutter analyze` list before and after;
3. **the 3 interpolated strings quoted as they now read**, with line numbers;
4. any row you could not apply, and exactly why;
5. any assertion you believe is wrong — with the reason, and having changed
   nothing;
6. anything the brief or the table got wrong.

**Do not claim a number you did not compute in that run.**
