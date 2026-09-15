# Brief — the app after the opening book became ours, batch 71

Written 15.9.2026 by the lead. This brief and `docs/TASK-opening-book-app.md`
are the whole of the context for this batch.

## Where this sits

Until today the app asked Lichess what was played in a position: the opening
panel in Analysis, the move judge, and the repertoire trainer. The panel went
through our server on a token every student shared; the judge and the
repertoire demanded each user's **own** Lichess token and did nothing without
one, so in practice nobody could build a repertoire. A ChessDB panel stood in
whenever Lichess could not be reached, and a Settings switch chose between the
two.

`docs/PLAN-OTVARANJA-LOKALNO.md` replaced all of that with one file on our own
server: master games in which both players are rated 2200+, the first 50 plies,
single-game rows pruned. **The server half is finished and frozen** (commits
`ed723ef` and `1dd66c7`), and so is the judge's half of the app: no token is
sent, the judge panel has no token state. **Your job is the rest of the app.**

The owner's decisions, which you do not reopen:

1. **One book, no rating bands.** A student learns the sound move whatever
   their own rating. The rating filter is **removed**, not re-sourced.
2. **No personal token anywhere.** Nothing in the app sends one after this
   batch — so the Settings field that held it goes too, and a value already
   stored on a device is deleted when the settings load. (The plan said the
   field would stay "for importing your own games"; the lead checked, and
   importing goes through the server's own token and never read it. A field
   that does nothing and holds a secret is not kept.)
3. **ChessDB goes.** No fallback, no switch.
4. **A guest is told to sign in**: „Sign in to see the opening book." The route
   is behind sign-in and nothing else can show a signed-out reader a book.

## The contract

In the header of `docs/gates/opening_book_app_test.dart`: the server's answer
shapes, the five sentences the panel says, and the Dart shapes the gate
compiles against. **Read all of it before writing code.** The two short ones
worth repeating here:

`GET /opening-explorer?fen=…&moves=12` answers
`{ fen, white, draws, black, opening: null, moves: [{uci, san, white, draws, black}], unlisted, beyondBook }`
— `white + draws + black` is every game that reached the position, **including**
`unlisted` games in moves the server does not list. A move's percentage is of
that total. It refuses with `{ error, reason }`.

The panel's states, first match wins: loading (spinner, no sentence) → a
refusal (`guest` → „Sign in to see the opening book."; `not-configured`,
`unreadable`, `inconsistent` → „The opening book is not available on this
server."; anything else → „The opening book could not be reached.") →
`beyondBook` → „This position is deeper than the opening book goes." → no games
→ „No master game reached this position." → the count and the moves.

## What is already there, and must be reused

| | |
|---|---|
| `displayOpeningName` in `AnalysisStudioScreen._buildPositionInfoPanel` | the ECO name of the position, already computed beside the panel. Pass **it** as `openingName`; do not look the name up a second time |
| `OpeningJudgeService.withClient` | the shape `OpeningExplorerService.withClient` copies: a `@visibleForTesting` factory over an optional `http.Client` |
| `test/support/dart_source.dart` | `codeOf`, `commentsOf`, `literalsIn`. The gate reads source with these |
| `_buildMoveChip` in the panel | keeps its bar and its colours; only its caller changes |

## The inventory

Measured by the lead against the tree the batch starts from, with the gate's own
checks. **This is where the work is**, not a suggestion of where to look.

**Delete**

* `lib/features/analysis_studio/services/chessdb_service.dart`
* `test/opening_explorer_panel_widget_test.dart` — every test in it is about the
  dropdown, ChessDB or Lichess's `opening` name; the gate replaces it.

**Rewrite**

* `lib/features/analysis_studio/services/opening_explorer_service.dart` — one
  path, through our server; `withClient`; `unlisted`, `beyondBook`; no
  `minRating`, no `_direct`, no `createTokenUrl`, no personal token; comments that
  say what it is now.
* `lib/features/analysis_studio/widgets/opening_explorer_panel_widget.dart` — no
  dropdown, no ChessDB, the states above, `openingName`, `reason`.

**Edit**

* `lib/features/analysis_studio/screens/analysis_studio_screen.dart` — the
  explorer fetch keeps the lookup's `reason`, passes `openingName:
  displayOpeningName` and `reason:` to the panel, and loses
  `_openingExplorerMinRating`, `_onOpeningExplorerMinRatingChanged`,
  `_openingExplorerAvailable`, `_chessDbService`, `_chessDbResult`,
  `_chessDbLoading`, `_fetchChessDbFallback` and the ChessDB branch. The judge
  call there loses its `minRating:`.
* `lib/features/analysis_studio/services/opening_judge_service.dart` —
  `judge(String fen, String move)`, `replies(String fen)`, cache keys
  `'$fen|$move'` and `'replies|$fen'`, no `minRating` query key.
* `lib/features/repertoire/services/repertoire_api_service.dart` — every
  `int? minRating` parameter and every `'minRating'` wire key (fifteen methods).
* `lib/features/repertoire/screens/repertoire_build_screen.dart` (36 uses),
  `repertoire_drill_screen.dart` (12), `repertoire_list_screen.dart` (18, and
  the „Opponent rating" `PopupMenuButton<int>` with its comment),
  `repertoire_walkthrough_screen.dart` (6), `repertoire_coverage_screen.dart`
  (4), `widgets/repertoire_tree_panel.dart` (5, and its „Book: games from …+"
  sentence — the „Breadth" sentence beside it stays).
* `lib/features/archive/services/archive_api_service.dart` — `getLeaks` loses
  `minRating`; and its caller if it passes one.
* `lib/services/app_settings_service.dart` — `kRepertoireRatingBands`,
  `repertoireMinRating` / `setRepertoireMinRating`, `openingDbSource` /
  `setOpeningDbSource`, `lichessApiToken` / `setLichessApiToken`; in `init`,
  `prefs.remove('lichess_api_token')` where the token used to be read.
* `lib/screens/settings_screen.dart` — the whole „OPENING EXPLORER" section (its
  heading, the source chips, the token text, field and both buttons),
  `_lichessTokenController` and its dispose, `_openLichessTokenPage`,
  `_saveLichessToken`, and the imports only they used.
* **Comments** that say the book costs a Lichess request, allowance or quota:
  16 in `repertoire_build_screen.dart`, 5 in `repertoire_api_service.dart`, 2 in
  `repertoire_drill_screen.dart`, 1 each in `repertoire_coverage_screen.dart` and
  `repertoire_list_screen.dart`, and the explorer service's own. **Even a true
  one** — „costs no Lichess request" — goes: nothing here can cost one now, so
  the sentence describes a world that is gone. Reword to what is true (the book
  is read on our server; the stored replies cost nothing to read) or delete the
  clause; do not just swap the word.
* **One user-facing sentence is rewritten, exactly:** in
  `repertoire_build_screen.dart`, „Local engine — does not use Lichess quota.
  Evaluation is from White's perspective." becomes „Local engine. Evaluation is
  from White's perspective."
* **Tests with fakes** that override a changed signature — about twenty files
  hold `{int? minRating}` or `minRating,` in a fake's parameter list. Remove the
  parameter; change nothing else in them.

**Tests whose assertions change, and exactly how**

* `test/repertoire_tree_legend_test.dart` — `_pump` loses `minRating`; the two
  `find.text('Book: games from …+')` expectations are deleted; the first test is
  renamed „the legend names the width". „nothing is invented when nothing is
  known" keeps its `Book:` absence line **only if** it can still fail — it
  cannot, once the sentence does not exist, so delete that line too.
* `test/repertoire_breadth_wire_test.dart` — „every query value the client sends
  has something in it" loses `minRating: 1600` and `asked['minRating']`; its
  `limit` and empty-value assertions stay.
* `test/opening_judge_service_test.dart` — the two `minRating: 1600` arguments go.

No other assertion anywhere changes. If one has to, **stop and say so.**

## Rules that bite

* **Puzzle assignments keep their `minRating`** (`lib/features/assignments/`). It
  is a puzzle's difficulty, not the book. The gate's last test fails a sweep
  that took it.
* **Copy is graded literal by literal.** Every string you remove must be one of
  those listed under „Removed copy" in the task file; every other literal in a
  file you edit stays byte-identical. Log messages included — do not reword one
  you are not deleting.
* **A comment that only says what code used to do is not kept.** Say what is
  true now, or nothing.
* `dart format` every Dart file you touch. `flutter analyze` must report the
  same list it reports before you start — **26 infos, zero warnings** — with no
  new `// ignore:`.
* The repository is public: no scratch files left in the tree.

## How it will be judged

By machine, not by the report: the gate (26 tests), the full suite with a floor
of **2715** (2692 on master + the gate's 26 − the 3 in the deleted panel test),
the analyzer list, `dart format`, the strings gate against the lists in the task
file, and the tree gate. Then the lead reads the diff, re-measures every number
in the report, and runs mutations against your work.

## Out of scope

`chess_backend/`, `tools/`, `docs/` (except your report), the judge panel,
`lib/features/assignments/`, the endgame trainer's own „bands"
(`endgame_catalog.dart` — a different thing with the same word), and
`OpeningBookEntry.variation`'s Serbian „Osnovna linija", which the lead has
flagged separately.
