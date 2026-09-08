# Task — batch 64, second round: the tests that still read Serbian

**This file is the only context you get.** The brief it continues is
`docs/brief-prevod-repertoar-2026-09.md`, and `docs/GLOSSARY-EN.md` is still the
contract — read both — but the job below is all that is left.

Branch: `batch/prevod-repertoar`. **Do not commit.**

## What happened, so you know what state the tree is in

The first round translated all twenty-six files under `chess_app/lib/` and
finished them: `gate_english_ui` confirms there is **no Serbian letter left in
any string literal** in any of them. That half is done and is not to be touched
again.

It then ran out of time updating the tests, because the task told it to run the
suite after every file — twenty-six suite runs of three minutes each. **That
instruction was wrong and it is withdrawn.** See „How to spend the time" below.

## What is left

`chess_app/test/repertoire_build_test.dart` — **41 failing tests**, all of them
assertions that still name the Serbian copy the first round replaced.

`chess_app/test/repertoire_counts_refresh_test.dart` is already green and has no
Serbian left. Leave it alone.

Nothing else in the repository needs changing. The lead has already translated
some of the assertions in that file; the rest are the ones written across more
than one line, which is why they were missed.

## How to do it

For each failing test:

1. Read the Serbian string the assertion is looking for. Most are built from
   two or three adjacent string literals across lines — take the whole
   sentence, not the first fragment.
2. Find what that sentence says **now** in `chess_app/lib/features/repertoire/`.
   The English is already written there; you are not inventing wording. `grep`
   a distinctive middle fragment of the English, or read the widget the test is
   driving.
3. Replace the assertion's text with exactly what the source says, keeping the
   line breaks and concatenation as they are.

Where a sentence interpolates a count, the English may have a different shape
from the Serbian — the first round replaced three-form plurals with two-form
ones. Match what the source actually produces, not what the old assertion
expected.

**Do not delete a test, weaken an assertion, or relax a matcher to make
something pass.** If an assertion cannot be made to pass by naming the English
the source produces, that is a finding: stop and write it in the report,
because it means the first round changed a meaning rather than a language.

## How to spend the time

**Do not run the whole suite between files.** Run only:

    cd chess_app && flutter test test/repertoire_build_test.dart

as often as you like — it takes well under a minute — and run the whole suite
**once**, at the very end, to confirm 1774.

## Done means

* `cd chess_app && flutter test` → **1774 passing, 1 skipped**.
* `cd chess_app && flutter analyze` → 29 issues, all `info`. There is one
  **unused import** left by the first round to remove:
  `package:chess_app/core/services/serbian_plural.dart` in
  `lib/features/repertoire/screens/repertoire_build_screen.dart`. Remove the
  import only — do not change how that file counts anything.
* `dart format` clean. One file the first round left unformatted is included in
  that; running `dart format` over `lib/` and `test/` finds it.
* No Serbian letter in any string literal in the twenty-six translated files or
  in the two test files. Comments may stay Serbian.

## The report

Append to `REPORT-prevod-repertoar.md`, under a heading „Second round".

1. Test count before you started this round and after, both measured by you.
2. How many assertions you translated.
3. **Every assertion where the English source says something different from
   what the Serbian assertion expected** — not a different wording, a different
   meaning. This is the one thing this round can discover that nothing else
   will.
4. Anything this task got wrong.

Write only what you did.
