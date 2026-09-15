# Task: the app after the opening book became ours — batch 71

A bounded job for an outside agent. **This file plus
[brief-opening-book-app-2026-09.md](brief-opening-book-app-2026-09.md) are the
only context you get** — do not rely on any conversation before them. Read the
brief first, then the header of the gate.

Branch: `batch/opening-book-app`. **Do not commit.** Leave the worktree dirty;
the lead reads the diff.

Run this only on a tree where all of these exist:

* `docs/gates/opening_book_app_test.dart`
* `chess_app/test/support/dart_source.dart`
* `chess_app/lib/features/analysis_studio/services/opening_explorer_service.dart`
* `chess_app/lib/features/analysis_studio/services/chessdb_service.dart`

If any is missing, **stop and say so.** Do not find the nearest plausible file
and use that.

## What is asked

Phase 4 of `docs/PLAN-OTVARANJA-LOKALNO.md`, as the brief's inventory lists it:
ChessDB and the personal Lichess token deleted from the app, every rating the
book was asked for removed, the explorer panel rewritten to say what the server
answered, and the comments that still describe a book that cost a Lichess
request corrected.

**Only these files may be added:**

* `chess_app/test/opening_book_app_test.dart` — the gate, copied
* `REPORT-opening-book-app.md` — the report, in the repository root

**Only these may be deleted:**

* `chess_app/lib/features/analysis_studio/services/chessdb_service.dart`
* `chess_app/test/opening_explorer_panel_widget_test.dart`

Every other change is an edit to a file the brief's inventory names, or to a
test whose fake overrides a signature you changed.

**Do not touch** `chess_backend/`, `tools/`, `docs/`, `chess_app/test/support/`,
`chess_app/lib/features/assignments/`, the judge panel
(`opening_judge_panel_widget.dart`), or any `pubspec`.

## Removed copy

The strings gate compares every literal in every file you edit against the tree
you started from. **These, and only these, may disappear.** Anything else that
disappears or changes fails the batch — log messages included.

* `lib/screens/settings_screen.dart` — the whole „OPENING EXPLORER" section and
  the two token methods: `'OPENING EXPLORER'`, `'Data source:'`, `'Lichess'`,
  `'ChessDB'`, the `'lichess'` / `'chessdb'` comparisons, the two source
  descriptions („Lichess: move popularity…", „ChessDB: move quality…"), „A
  personal Lichess token is not required…", `'Lichess API token (optional)'`,
  `'lip_...'`, `'Create token'`, `'Save token'`, `'Token removed.'`,
  `'Lichess token saved.'`, `'Unable to open lichess.org in browser.'`
* `lib/services/app_settings_service.dart` — `'app_repertoire_min_rating'`,
  `'app_opening_db_source'`, `'chessdb'`, `'lichess'`, and **one** of the two
  `'lichess_api_token'` (the other stays, in `prefs.remove`)
* `lib/features/repertoire/screens/repertoire_list_screen.dart` —
  `'Opponent rating'`, `'Book now answers from games rated $band and above.'`,
  `'$band+ ✓'`, `'$band+'`
* `lib/features/repertoire/widgets/repertoire_tree_panel.dart` —
  `'Book: games from $minRating+'`
* `lib/features/analysis_studio/screens/analysis_studio_screen.dart` — the
  `'chessdb'` comparisons and four log lines: `'[OpeningExplorer] 🔍
  wantsChessDb=…'`, `'[OpeningExplorer] ⚙️ User selected ChessDB'`,
  `'[OpeningExplorer] ⛔ Unavailable (…) — using ChessDB'`, `'[ChessDB] 📊
  Result: …'`. You may add a log line in their place.
* `lib/features/repertoire/services/repertoire_api_service.dart` — every
  `'minRating'` key and its `'$minRating'` value
* `lib/features/analysis_studio/services/opening_judge_service.dart` — the two
  `'minRating'` keys, their values, and the two cache keys, which become
  `'$fen|$move'` and `'replies|$fen'`
* `lib/features/archive/services/archive_api_service.dart` — `'minRating'`
* `lib/features/analysis_studio/services/opening_explorer_service.dart` and
  `…/widgets/opening_explorer_panel_widget.dart` are rewritten; their copy is
  held by the gate's sentences instead.

**Rewritten, exactly:** in `repertoire_build_screen.dart`, „Local engine — does
not use Lichess quota. Evaluation is from White's perspective." → „Local engine.
Evaluation is from White's perspective." Keep it the same single-quoted
literal, with the apostrophe written `\'` as it is now: the strings gate compares
the source text, and `"White's"` in double quotes reads as a different string.

## Method

1. `cd chess_app && flutter test` **before changing anything**; write the number
   down. Measure it yourself; do not trust a number quoted at you.
2. `flutter analyze` before, and keep the **list**. Read its summary line.
3. Copy `docs/gates/opening_book_app_test.dart` →
   `chess_app/test/opening_book_app_test.dart`. 26 tests. Against the tree as it
   is now it **does not compile** (`withClient`, `unlisted`, `openingName` do not
   exist yet).

   **Do not edit that file**, except to run `dart format` on it. If you believe
   a test in it is wrong, **stop and say so in the report** — do not work around
   it. A workaround that satisfies a test without satisfying the rule is worth
   less than a stopped batch.
4. Work in this order, running **only the gate file** as you go
   (`flutter test test/opening_book_app_test.dart`):
   the explorer service → the panel → the analysis screen → the judge service →
   the repertoire API service and every caller the compiler then names → the
   settings service and the Settings screen → the list screen and the tree panel
   → the leak report's call → the comments → the test fakes and the three tests
   whose assertions change. The „what is gone" group names the file and the
   identifier on every failure; read it rather than searching by hand.
5. When the gate is green, `dart format` every Dart file you touched. Run it; do
   not report it as run.
6. **One** full `flutter test` and one `flutter analyze`, at the end. The suite
   must be at least **2715** (the number you measured in step 1, plus the gate's
   26, minus the 3 tests of the deleted panel test file) and **lower by nothing
   else**; the analyzer list must be the same list, with nothing new suppressed —
   no new `// ignore:` and no new `ignore_for_file`.

## The report

`REPORT-opening-book-app.md`, in the repository root.

* the test count **before and after**, both measured by you in this run, and the
  arithmetic between them;
* the analyzer summary line before and after, and the word „identical" or the
  difference;
* whether you added any `// ignore:` or `ignore_for_file` — a line of its own,
  even if the answer is no;
* the exact list of files you added, deleted or changed;
* **every test you deleted or whose assertions you changed**, by name, with the
  line of the brief that allowed it — the expected list is the three panel tests
  and the three files the brief names;
* **three mutations, measured.** In your finished code: (1) make the panel check
  `total == 0` before `beyondBook`; (2) send `'minRating': '1600'` from
  `OpeningExplorerService.lookup`; (3) stop `AppSettingsService.init` removing the
  stored token. For each, run the gate and quote the name of the first test that
  failed — or write „no test failed", which is a finding too. Then put your code
  back and say that you did;
* every test outside the gate that went red at any point, and what you did;
* anything this task, the brief or the gate got wrong. A correction is worth
  more to us than a clean report.

**Write only what you did.** Quote nothing you have not just run or grepped.
