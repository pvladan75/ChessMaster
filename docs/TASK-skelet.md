# Task: the skeleton of a game tutorial, in Dart — batch 70

A bounded job for an outside agent. **This file plus
[brief-skelet-2026-09.md](brief-skelet-2026-09.md) are the only context you
get** — do not rely on any conversation before them. Read the brief first.

Branch: `batch/skelet`. **Do not commit.** Leave the worktree dirty; the lead
reads the diff.

Run this only on a tree where all of these exist:

* `tools/game_annotate/skeleton.py`
* `docs/gates/game_tutorial_skeleton_test.dart`
* `chess_app/test/fixtures/game_tutorial/answer_cases.json`
* `chess_app/lib/features/tutorial_studio/services/game_tutorial/evaluation_words.dart`

If any is missing, **stop and say so.** Do not find the nearest plausible file
and use that.

## What is asked

Port the rest of `tools/game_annotate/skeleton.py` to Dart, so that the app
makes exactly what the harness makes from the same facts and the same model
answer. Pure Dart, no I/O. **Only these files may be added:**

* `chess_app/lib/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart`
* `chess_app/lib/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart`
* `chess_app/lib/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart`
* `chess_app/lib/features/tutorial_studio/services/game_tutorial/board_queries.dart` (optional)
* `chess_app/test/game_tutorial_skeleton_test.dart` — the gate, copied
* `chess_app/test/game_tutorial_skeleton_extra_test.dart` — your own tests, optional
* `REPORT-skelet.md` — the report

**No existing file needs an edit**, with one possible exception: lifting
`_isAbsolutelyPinned` out of `lib/core/services/tactical_motif_detector.dart`
into `board_queries.dart`. If you do that, the detector must call the lifted
function, and its tests must stay green untouched.

**Do not touch** `tools/`, `chess_app/test/fixtures/`, `docs/gates/`,
`evaluation_words.dart`, `test/game_tutorial_evaluation_words_test.dart`,
`chess_backend/`, or any screen, widget or API service.

## The contract

In the header of `docs/gates/game_tutorial_skeleton_test.dart`. It is the
specification: read all of it — especially „Where Python and Dart disagree" —
before writing code. The brief's section on `play()` is the one part that is not
a translation.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read its summary line.
3. Read `tools/game_annotate/skeleton.py` whole, then open one fixture —
   `g08_nimzowitsch-defense.json` is the smallest — and find in it one
   `moments[].slots` entry, the `report`, and one part of `tutorialGame`.
4. Copy `docs/gates/game_tutorial_skeleton_test.dart` →
   `chess_app/test/game_tutorial_skeleton_test.dart`. 39 tests. Against the tree
   as it is now it **does not compile**, because the three files do not exist.

   **Do not edit that file**, except to run `dart format` on it. If you believe
   a test in it is wrong, **stop and say so in the report** — do not work around
   it. A workaround that satisfies a test without satisfying the rule is worth
   less than a stopped batch.
5. Build in this order, running **only the gate file** as you go
   (`flutter test test/game_tutorial_skeleton_test.dart`, about ten seconds):
   parameters → moments → report → both tutorials → the bad answers.
   The gate prints the JSON path where your output first parts from the
   harness's; read it, then read the line of `skeleton.py` that wrote it.
6. When the gate is green, `dart format` every Dart file you touched. Run it; do
   not report it as run.
7. **One** full `flutter test` and one `flutter analyze`, at the end. The suite
   must be higher by at least the 39 tests of the gate and **lower by none**; the
   analyzer list must be the same list, with nothing new suppressed — no new
   `// ignore:` and no new `ignore_for_file`.

## The report

`REPORT-skelet.md`, in the repository root.

* the test count **before and after**, both measured by you in this run;
* the analyzer summary line before and after, and the word „identical" or the
  difference;
* whether you added any `// ignore:` or `ignore_for_file` — a line of its own,
  even if the answer is no;
* the exact list of files you added or changed;
* **three divergences, measured.** For points 1 (the sort tie), 2 (Python's
  `round`) and 7 (the square order) of the gate's list: change your code to the
  naive Dart version, run the gate, and quote the name of the first test that
  failed and the path it printed — or write „no test failed", which is a finding
  too. Then put your code back and say that you did;
* how you answered `attacks` and `is_pinned`, and whether you lifted the
  detector's pin check;
* every test outside the gate that went red at any point, and what you did —
  the expected answer is „none";
* anything this task, the brief or the gate got wrong. A correction is worth
  more to us than a clean report.

**Write only what you did.** Quote nothing you have not just run or grepped.
