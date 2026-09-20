# CLAUDE.md

Chess coaching platform: a Flutter client (`chess_app/`) and a Node backend
(`chess_backend/`). A trainer runs a live lesson in a room — board, voice, and a
silent replay of the lesson's move timeline — plus puzzles, homework, spaced
repetition and parent reports. Audio is recorded only by an adult alone in a
room, making their own teaching material. The app is for 13 and older (higher in
some countries), so many users are minors, which decides several rules below.

## Layout

| | |
|---|---|
| `chess_app/` | Flutter client. Android + Windows are the real targets |
| `chess_backend/` | Express + Socket.IO + PostgreSQL (managed, DigitalOcean) |
| `docs/` | Handoff and planning docs — read `STANJE-RADA.md` first |
| `deploy/` | Server provisioning scripts, idempotent, run as root |
| `puzzles/` | One-off import tooling and datasets, not part of the app |
| `tools/` | Reusable tooling run by hand, not part of the app — `tutorial_translate/` translates tutorial files through `agy` (`docs/PGN-TUTORIAL-FORMAT.md`, section 9) |

## Commands

```bash
cd chess_app && flutter test          # 3474 tests, 1 skipped, rest green
cd chess_app && flutter analyze       # exits 1 on 26 known infos — read the list
cd chess_backend && npm test          # node --test, 1630 with TEST_DATABASE_URL, 1536 without
cd chess_backend && npm run dev       # nodemon, port 3000
```

Measured on `master` on 18.9.2026 (after the owner's live pass of 18.9 and the five fixes it asked for: local scratch state is handed over with the account, Analysis opens with the engine off, the endgames card names both of its lines, the „Teach“ badge says what it counts, and the studio on a phone has a row of moves to read the line back; then the sixth, where a read of the attempt log overtook the write it was meant to see, and the deletion of a second hub nothing could reach; then the second pass over Settings, which took the „My games“/„Scan a book“ row off the board, put the navigation strip on one row and, on a second pass, folded the move and its four actions into that one row and took the shell's own bar off every screen; then „play it out“, which now takes the board a diagram tool gives you and lets the side switch decide who is on the move), with the Settings review before it (board size, the Analysis panels and the comment switch onto their screens, every depth picker to 50, the engine opponent onto the exercise screen, the whole of the homework plan bar the owner's live pass) and every built phase of the
reorganisation merged (`docs/PLAN-REORGANIZACIJA.md`: the shell Home · Practise ·
Analyse · Teach, the room's column on the shared library list, the studio's
`TutorialDraftController`, the studio on a phone, one tutorial editor everywhere)
and phases 1–2 of the puzzle progress plan; then phases 1, 2a and 3a of `docs/PLAN-EXERCISE.md`, backend only, and the removal of „must be solved" from both ends (the app went 3054 → 3053), then phase 2b, the app half of the line (3053 → 3077), then phases 3b and 4 (→ 3125) and phase 5, the check on save (→ 3157, a full
run on 19.9.2026), and the Board Setup dialog's two reported faults — a palette
wider than the dialog, a board sized from the wrong dimension, and tab labels
314dp wider than the strip that holds them, and the editor's refusal of a
position that is not chess (→ 3190); then the owner's live pass of the exercise
work on 19.9.2026 and its phase 8 — a number on „Win“ is „Checkmate in N moves“,
judged by the rules alone, the task said on every screen that shows it, and a
homework's own item counts (→ 3195; backend 1598/1512 → 1597/1511), then the server half of its phase 9, the
review of a played game (backend → 1603/1516), and its app half — the verdict
on the homework row and the review of a game as a game (→ 3212), and phase 10, a scan with nothing to
judge is a position and not an exercise (→ 3218), and phase 11, a saved
exercise opened, read and changed on its own screen (→ 3257), and phase 12, no engine, no Analysis and no FEN
inside an assigned item while it is being solved — they come back once it is
handed in (→ 3268, → 3275); then the owner's live pass of 20.9.2026 — a
hand-made exercise that opened on „Assignment complete" because the server told
a trainer's position by its `cust_` prefix, and whose move it is in „play it
out" (→ 3283; backend → 1607/1520), and a test for the rule that one answer
marks every open copy of a position for that student (backend → 1608/1520),
and any mate is a right answer, whatever the author's own move does (backend →
1612/1524); then phase 13 of `docs/PLAN-EXERCISE.md` — a played homework game
opens in Analysis with its moves, for the trainer and, once it is handed in,
the student (→ 3295) — the first of four phases in that plan's §10, which makes
„Find" one move and adds „Play N moves", judged by the trainer; then its phase
14 — the server's writer refuses a find solution of more than one move, and the
move is played on the exercise's own screen, opened from the sheet („Play the
move") instead of the red refusal (→ 3307; backend → 1614/1526); then its phase
15 — „Play N moves", a game with no goal that no tablebase is ever asked about,
and the route by which a trainer records a verdict, which nothing had until
then (→ 3334; backend → 1632/1539); then its phase 16, the deletion of the
multi-move machinery — the one old row with a line deleted on the owner's yes,
`judgeLine`, the replies and the step chips gone, the attempt's wire down to one
move (→ 3327; backend → 1624/1530 — the first time these numbers fall, because
tests of deleted code went with it); then the engine that went silent on the
phone — nothing told it to quit when the app was torn down, so the next run
started a second one behind it (`EngineWatch`, → 3329), and an engine that
answers nothing now says so on the screen (`EngineSilence`, `EngineNotice`, →
3338); then Preparation's two doors for keeping the work — „Save analysis",
which reads the room's tree back through the app's one reader and refuses a
line it could not replay, and „Export PGN" beside it (→ 3353), whose real cost
was the panel: two full-width buttons pushed the tutorial list below the fold of
a 1200 x 800 window and broke an unrelated test, so the four actions are now two
pairs and the panel is the same height it was; then parts moving between
tutorials — „Add parts from a tutorial…" and „Take parts into a new tutorial…",
both copying so the source is never rewritten, with no server change at all
(→ 3383), whose cost was again the room: three surfaces were measured full (the
contents panel's Wrap by 2 px, its title row by 19, the studio bar by 33) and
the door ended up as a 20 x 20 button in the title row rather than by moving
anything the trainer already reaches in one tap; then phase 1 of
`docs/PLAN-LISTE.md`, a search box in „Choose a game", where 4126 games sat in
a fixed 400 x 300 box with about five rows visible (-> 3393). Its two lessons
are both about the gate rather than the code: a width assertion **passed on
master** while the fault stood, because `AlertDialog` lays its children out
under an `IntrinsicWidth` and that `SizedBox(width: 400)` is actually given 912
— the height is the fixed dimension worth asserting; and „closes the dialog and
then reports it" could not see the **order**, so swapping `Navigator.pop` and
the callback left all nine cases green until a `NavigatorObserver` case was
added; then its phase 2, `AdaptiveCardGrid` (-> 3400), the one home for
pattern A, which is a wrapper over `SliverGridDelegateWithMaxCrossAxisExtent`
so that **the column count is never written down** — it falls out of the
constraint the widget is handed, which is why the room's narrow column needs no
special case and the phone is unchanged by construction. Written deliberately
wrong first (a fixed count of two) to watch the test catch it: three of the
four widths went red and **840 did not**, because two happens to be right
there — a single-width test would have proved nothing; then phase 3a, the
homework templates and the saved-puzzle sets onto that grid (-> 3407), whose
gate found a bug nobody had seen: the saved-puzzles dialog **already
overflowed on a 360 dp phone** (a `RenderFlex` by 1.3 px), because a release
build clips instead of warning. Mutation named the cause exactly — it was the
`Dialog`'s default `insetPadding` (40 a side, leaving about 280 for a
`Container` asking 460), **not** the fixed width; the width is what kept a wide
window to one column. Two independent faults in one widget that look like one.
Then the owner looked at it on Windows and found a third (-> 3410): with a
**single** set the dialog still took the full 640 it was allowed, the grid
correctly reserved a second column, and **half of it was empty** — the card
filled 49% of the row. The dialog had been made *able* to use width without
being made to take only the width it can fill, which is the very complaint the
plan exists to answer. It now asks for as many columns as it has cards; one set
gives a 460 dialog filled to 100%, two still share a row. The same pass took 29
px of dead air out of a card. Then phase 1b (-> 3423), which the same live
look opened: „Choose a game" drew `1. e4 { [%clk 0:03:00] } 1... c5 …`, two
moves where eight fit, **and the move search was half dead** — `e4 c5` matched
nothing, because the annotation sits between them in the string the filter
read. The cause was phase 1's fixture: clean movetext, while the owner's 4126
games come from online play and carry `%clk` on every move (rule 6, word for
word). `MoveTree.sanTokens` now reads the moves out of a body — comments, NAGs,
variations, numbers and the result out — and **both** the preview and the
search go through it, so typing `1. e4 c5` and `e4 c5` answer the same. Two of
the lead's own mutations were invalid there (deleting a line stopped the file
compiling, which is not the right red) and one **survived**: nothing covered
variations, because the dialog's fixtures have none, so the shared helper got
its own pure test. Then phase 3b (-> 3437), `LibraryList` onto that grid — the
risky half, because the widget is drawn by **two** callers of opposite widths
(the Library screen and the room's 300 px column) and eight other test files
reach its rows. `actionsBesideFrom = 480` was deleted: a card is never wider
than 420, so that branch could no longer be reached, and the actions sit under
the title at every width. The predicted churn was one line — `titlesShown`
rescoped from `ListView` to `AdaptiveCardGrid`, no assertion touched. **The
lesson was the ninth file the grep did not find.** The plan's own guard says to
grep the touched tests for `ListTile`; a grep for `LibraryList` and
`library-row-` found eight files, all green afterwards, and
`saved_tutorials_phone_test.dart` fell only in the full run. It names the widget
nowhere — it reaches a row through the shared helper `libraryRow` in
`test/support/shelf_over_lessons.dart` — and it asserted the very rule this
phase deleted (the send button within 24 px of the title's line; 68 after the
change). Its four phone cases stayed green, so the file still does its job; the
one Windows case was rewritten **openly**, with the supersession written above
it. **Grep the shared helpers and the constant being deleted, not only the
widget's name.** Nine mutations, each red on the right case; three survived,
all because the tile height is tight to the tallest card, so a `Spacer` or a
`spaceBetween` has 4 px to spread and spreading them shows nothing — only
`cardHeight = 180` *with* `spaceBetween` falls, which is 3a's fault word for
word. The third survivor is the gate's stated limit: a merely over-generous
card height breaks no rule it wrote down. Then phase 4 (-> 3445), „What to
drill" in columns, whose finding is that **pattern A has two halves**. A sliver
grid is a sheet of cells of *one* height, and a family card is a row tall shut
and some 800 px tall open — thirteen rook shapes — so one cell height gives
either an overflow or a window full of air, which is 3a's complaint word for
word. `AdaptiveCardColumns` joins `AdaptiveCardGrid` in the same file: ordinary
`Column`s, each the height it needs, so **opening one family moves nothing
outside its own column** — what the `ListView` could never do. The count is
still never written down, but it is now computed in *two* places, so the
delegate's formula was lifted into `AdaptiveCardGrid.columnsFor` and a case in
the grid's own test reads the delegate's answer off the rendering and holds the
helper to it — at 431/432/433/863/864, the band boundaries, which were the only
widths that caught „forget the spacing". Seven mutations, each red on the right
case, **none survived**. The lesson is in the three *wrong* reds the gate gave
first, none of them about layout: a fixture typed `Map<String, Object>` that
`whereType<Map<String, dynamic>>` silently threw away (rule 6); a chevron
tapped blind, which is a **toggle** — the screen opens its biggest family by
itself, so the case shut what it believed it opened; and
`find.ancestor(…).first` throwing `Bad state` rather than failing, because a
`ListView` builds nothing below the fold. **A helper that sets state must
assert the state it set, and an existence check must be able to fail rather
than throw.** Then the owner's live pass of that evening, three findings, all
three in code the same night (→ **3463**; backend 1530 → 1536 without a
database, 1624 → 1630 with a throwaway cluster): a puzzle set on the Library
shelf now **opens** (`initialPuzzles`, the fourth „open exactly this"
parameter — it was drawn and answered nothing, and the code said so in a
comment); the room's ☰ is **placed by hand**, past whatever the system has
reserved down the left edge, because measurement showed it already filled the
bar (48 × 44) and the fault was that it sat at x = 4, in the corner; and the
one that matters most — **„Selected: N positions" was counted over a different
pool than the drill serves from.** `/next` leaves the online base out unless
asked, the catalogue counted everything, and `fetchCatalog` never sent the
flag, so the total was larger than anything that could be served and the
switch that was meant to move it moved nothing. Three rules came out of it.
**Two routes over one table that answer „how many are there" and „give me one"
must count the same set** — each is internally right, so the fault shows only
as a number that is not true, which is the most expensive shape there is.
**„One place knows the name" is a rule about the constant, not about the list
of callers who must use it**: `endgameSources.js` says in its own header that
*both* routes filter on the base's name, and the catalogue was the third.
And, the ninth file again: a grep for `fetchCatalog` found the two fakes whose
signature needed widening and missed `endgame_wire_format_test`, which does
not override the method at all — it asserts the **query map** over the real
`client` seam, which is exactly the job it exists to do. **Grep for what a
method sends, not only for who calls it.** Then phase 5 of `docs/PLAN-LISTE.md`
(→ **3474**), pattern B for the Library: the preview dialog's body extracted to
`BoardPreviewPanel` and drawn by both, `LibraryList` given **optional**
`onSelect` and `selectedId` so the room's column is untouched, and the shelf
split at 840 with a pane beside it. Two small things a mutation each proved:
the selection is an **outline** rather than a tint, and `selectedId` carries
the kind as well as the id, because ids come from different tables and a
position 12 and a tutorial 12 both exist. **But the phase's real find was a bug
already on master.** A pane makes the shelf narrow, and a narrow shelf
overflowed — `AdaptiveCardGrid` had a *maximum* tile width and **no minimum**,
so `ceil` split 460 px into two columns of 224 and a card at 224 overran its
own height by 48. Measured with no pane and no screen in the way: a Library
window between roughly 440 and 530 px has been clipping the buttons off its
cards since 3b, silently, because a release build clips instead of warning.
`minTileWidth = 280` now, and `columnsFor` derives the count from **two**
constraints rather than one. **A maximum without a minimum is half a rule** —
wherever space is divided by „at most X", ask what happens just past the
boundary, because that is where the split hands out two halves. And the
sequencing lesson beside it: **when a gate goes red after a change, measure the
old state before tuning the new one** — half an hour spent narrowing the pane
would have made the test green and left the fault in every window the pane
never touches. Open: the rest of the owner's live
pass. Phase 6 of
`docs/PLAN-EXERCISE.md` (a verdict from the device's engine) was closed unbuilt
by the owner on 19.9.2026: where no tablebase answers, the trainer judges. Every change of these numbers,
with its arithmetic and what it taught, is in **`docs/LESSONS.md`** — append the
new entry there and update the block above in the same change. Re-derive a count
before quoting it: this file has been left behind the suite more than once, and
a floor below the suite hides exactly what it is for.

**The backend has a real-database half** since phase 1 of
`docs/PLAN-DOMACI-ZADATAK.md`: `test/homework_gate.test.js` builds a fresh
database through `test/support/pgTestDb.js`, runs `initDB` on it and drops it.
CI runs it against a `postgres:17` service container; **in CI a missing
`TEST_DATABASE_URL` fails the run**, it does not skip. On this workstation the
suite skips it (one line marked `﹣`) unless a throwaway cluster is started —
never the managed database and never the local `postgresql-x64-17` service:

```bash
"/c/Program Files/PostgreSQL/17/bin/initdb.exe" -D "$SCRATCH/pgtest" -U postgres -A trust -E UTF8 --no-locale
"/c/Program Files/PostgreSQL/17/bin/pg_ctl.exe" -D "$SCRATCH/pgtest" -o "-p 54329 -c listen_addresses=localhost" -w start
TEST_DATABASE_URL=postgres://postgres@localhost:54329/postgres npm test
"/c/Program Files/PostgreSQL/17/bin/pg_ctl.exe" -D "$SCRATCH/pgtest" -m fast -w stop
```

They are here so a suite that quietly stops
running half of itself is visible; if the number you get is lower, find out why
before carrying on.

The one skip is the golden screenshot group, skipped unconditionally in
`dart_test.yaml`. `--tags golden` alone does **not** run it — that selects the
tests and the skip still skips them, so the run exits 0 saying "All tests
skipped". Run them with `flutter test --tags golden --run-skipped`.

**`flutter analyze` does not exit clean, and has not for a long time.** It
reports 26 issues, every one of them `info` level and every one of them
`curly_braces_in_flow_control_structures`, spread over
`positional_evaluator_service.dart`, `game_analysis_walker_service.dart`,
`review_api_service.dart`, `ai_studio_screen.dart` and
`matrix_filter_panel.dart`. (29 until 13.9.2026, when the motif detector's
rewrite put braces on its three.) This file used to say
"must be clean", which is worse than saying nothing: it makes a red exit code
look like the normal state, so a real error added tomorrow reads as the same
failure as today's. **What must hold is zero errors, zero warnings, and no new
infos — compare the list, not the exit code.** Clearing the 29 is a fine
standalone chore and would restore the simpler rule.

Run `dart format` on any Dart file you edit — CI does not enforce it, but the
formatter reindents aggressively and an unformatted file turns the next diff
into noise.

## What the log keeps teaching

Each of these has been paid for more than once. The stories are in
`docs/LESSONS.md` — grep a phrase from the rule to find them.

**Checks and tests**

1. **A check that cannot fail is not a check.** Watch every new test — the
   lead's included — go red on the wrong code before believing it green on the
   right one.
2. **A surviving mutation is a question, not a verdict.** It says what the test
   cannot see, and what it cannot see is sometimes a real bug somewhere else.
3. **A red is a catch only if it is the right red.** A compile error, a hang or
   a flaky neighbour is not. Run mutants under a timeout, mutate a condition in a
   way that keeps its null promotion, read *which* test failed, and prove the
   untouched baseline green first.
4. **Read source by structure, never by slicing or plain text matching.**
   Braces or a lexer; comments, strings and doc prose all match a `contains`.
   Ask what shape of the thing a text check cannot represent.
5. **An assertion of absence is a claim about the whole screen**, and a finder
   that is unique today stops being unique when the screen grows. Scope the
   finder; never weaken it. After a rename, grep the old word in the tests.
6. **A fixture that is shorter, simpler or luckier than the real thing cannot
   fail.** Stand the test on the boundary, change only what the check is for,
   mint an id per test, and never seed the state the code was meant to write.
   A gate built from real data cannot see what the data never does.
7. **Fake the client, not the method, and assert on the request.** A fake that
   answers a question nobody asked cannot see the question go missing.
8. **A test that reads the wall clock, the machine's fonts or what one OS has
   installed is a test of that machine.** Widget tests draw text as squares;
   measure real layout with the real font, and print the font family first.
9. **A test that hangs is worse than one that fails.** Every wait races a
   deadline; a test's own hold or fake can be the thing that hangs it.

**The product**

10. **Every layer can be right and the feature still unreachable, silent or
    dead.** Ask whether the user can reach it from where they actually go, and
    look at the real output — the frame, the screen at 360 dp, the request.
11. **Absence is a third answer, all the way to the wire.** A request that says
    nothing about a column leaves it alone; `null` clears; a value writes.
12. **One rule, one home.** Before writing a second implementation, grep for the
    first (`git log -S` finds deleted ones). A number or list kept in two places
    by a comment is two numbers. When two ends must agree, share one fixture.
13. **When two parsers must agree, make one write what the other reads.** The
    app's reader is `LessonStepLine` / `MoveTree.parsePgn`; the server has no
    PGN parser and must not grow one.
14. **A dormant bug wakes when the feature it depends on ships** — usually not
    the feature that contains it. After a feature lands, look at what it newly
    exercises.
15. **A widget that takes optional callbacks draws only what it was given.**
16. **When a language model repeats its input word for word, the input is the
    product.** Fix the facts and markers you send before the prompt's rules.

**Numbers, reports and the machine**

17. **Re-derive every number before repeating it** — a count, a report's total,
    a width. A true number under a false label is harder to catch than an
    invented one.
18. **Run `flutter analyze` after the change and read its summary line**; check
    that nothing new is suppressed with an `ignore`.
19. **Measure a suite with nothing else running.** `opening_book_service_test`
    times out beside a heavy process — and the heaviest process in the suite is
    usually `game_tutorial_run_test`, which drives Stockfish over ten games and
    needed 12 minutes on its own on 18.9.2026. Under load, both blow the
    runner's three-minute per-test timeout and report as failures that pass in
    isolation, so check *which* tests failed and how before believing a red.
20. **Before editing anything the running server loads, ask what its startup
    does to data** — the owner's nodemon restarts on every `.js` save. Moving
    `.env` aside is done with a `trap` that restores it in the same command.
21. **A worker's report is graded by machine and re-measured section by
    section.** Prose about behaviour costs as much to verify as to write; ask a
    worker for what a gate can check.

## Who does the work

The model split is defined globally in `~/.claude/CLAUDE.md`, with the agents in
`~/.claude/agents/`. In this repository:

| Role | Who | Here that means |
|---|---|---|
| Lead | Opus 5, the main session | Plans (`docs/PLAN-*.md`), gates written and proved satisfiable before handing over, grading, merges, docs. Everything irreversible stays here: schema and migrations, deletions, `uploads/`, `.env`, `deploy/`, the droplet, the legal texts |
| Worker | `implementer` agent, Sonnet 5 | One phase of a plan whose gate already exists — usually in a worktree (`isolation: "worktree"`) |
| Measurement | `verifier` agent, Sonnet 5 | The full counts: app suite, analyze list against the 26 known infos, backend with `.env` moved aside |
| Escalation | `deep-debug` agent, Fable 5.1 | A fault that survived a full round of diagnosis, or a change across app, server and data where one missed reader corrupts something |
| External worker | Gemini through `agy` | Large mechanical sweeps (translations, renames, vocabulary) where Max quota is better saved. Harness: `D:\Projekti\mislisha-test\orchestrator` — not in git, read its `HANDOFF.md` first; the `worker-batches` skill has the method |

**Choosing between the two workers.** Sonnet for work that has to read and
understand this codebase; Gemini (`gemini-3.8-flash-high` for step-shaped
briefs) for volume. Gemini's 5-hour quota is the binding constraint — about a
third of it per large batch, so ask the owner for the reading before launching.
Either way the brief says, in its method section:

> If you believe a test in the gate is wrong, **stop and say so in the report** —
> do not work around it. A workaround that satisfies a test without satisfying
> the rule is worth less than a stopped batch.

**There is no `TASKS.md`.** The backlog lives in `docs/STANJE-RADA.md` (what is
next), the open `docs/PLAN-*.md` files (phases, each with its gate) and
`docs/TODO-provera.md` (built, not yet watched running). When a phase is
briefed, the plan names who carries it — `[implementer]`, `[gemini]` or
`[deep-debug]` — beside the phase, not in a separate list.

## Rules that bite

**The repository is public.** Never put secrets, IP addresses, email addresses,
account or cluster identifiers into `docs/`, comments, or commit messages. Real
values belong in `.env` on the machine that needs them. `.env.example` is the
authoritative list of environment variables — add new ones there, and the
deploy script picks them up automatically.

**`chess_backend/uploads/` is the only copy of every recording made.** It is
gitignored, it is never deleted by cleanup code, and it must never be committed.
Rendered MP4 exports are different: they are reproducible, so they age out on a
retention timer.

Since 26.8.2026 it can no longer hold a child's voice: audio is accepted only
from a room whose sole occupant is its adult owner (`services/
recordingConsent.js`). That is the reason the rule exists — `uploads/` is the
one thing here that cannot be reproduced, anonymised or taken back.

**The backend requires Node >= 22.15.** The Lichess puzzle import uses
`zlib.zstd*`, which does not exist before that. This already cost one silently
red CI pipeline.

**The branch is `master`**, and it is the default branch. CI (`.github/workflows/
ci_cd.yml`) triggers on pushes to it and builds an APK artifact after the tests.

**Never name the product "Chess Master" or "Chessmaster"** in anything
user-facing — it is Ubisoft's brand. The application id is
`rs.pejovic.chesscoach`, deliberately decoupled from whatever the brand ends up
being.

**Language:** the user writes in Serbian and reads English, so **reply in
English** and write new `docs/` in English. Code comments and commit messages
are English, as before. **The app and the server are English only** since the
pivot of 8–9.9.2026, with no i18n layer; `docs/GLOSSARY-EN.md` is the
vocabulary and two tests enforce it. What stays Serbian is deliberate and short:
voice vocabularies for speech, `routes/consent.js` and the parent-consent mail,
server logs, the role values in `db.js`, and the legal texts
(`docs/politika-privatnosti.md`, `docs/saglasnost-roditelja.md`), because a
lawyer approved that exact wording for Serbia. The existing Serbian
docs stay Serbian — follow whichever register a file already uses, and translate
one only when asked to.

## The recurring bug in this codebase

Steps that skip silently, report success, and fail one layer or one run later.
It has appeared five times: `zlib.zstd*` missing on old Node, a `certbot` guard
that skipped reinstalling TLS and dropped the host to port 80, `sed s/^KEY=.*/`
doing nothing when the key is absent, an unverified database certificate that
looked exactly like a verified one, and a `server.js` that did not parse — two
`const seat` in one block — while `npm test` stayed green, because the two tests
that look at that file read it as **text** and search it for a function name.
`test/sources_compile.test.js` now compiles every server source, and a second
test asserts `server.js` is actually in the walk.

Two more, both on 25.8.2026. A token outlived the account it named: `jwt.verify`
proves this server issued the slip and nothing else, so a deleted account kept a
working login for the rest of its seven days — and after a `RESTART IDENTITY`
the same slip was a credential for whoever inherited the id. Every gate now asks
whether the row is still there (`services/accountGuard.js`), with **three**
answers, since "the database did not answer" must not read as "you were
deleted".

A message must never be able to take down the action it reports on. Twice now:
playback that never started because a failing audio call sat in front of the
timer, and a recording that would not stop for a child whose parent had refused
it, because `showSnackBar` threw first. **Do the thing, then say it** — and say
it through `AppFeedback`, which cannot throw. All 82 raw
`ScaffoldMessenger` calls in `lib/` were moved onto it on 25.8.2026, and
`test/app_feedback_guard_test.dart` fails if one comes back. That sweep found
the guard itself still throwing: the helpers built their `SnackBar` — and with
it `context.colors`, which is `Theme.of(context)` — *before* the mounted check
and the `try`, so an ancestor lookup ran in front of the guard against ancestor
lookups. `_show` now takes a builder and builds inside. Same lesson as the one
below: prove a guard by mutation before believing it.

And the guard written for it did not guard: it read a fixed 1600 characters from
the start of each function, which ran into the next one, so removing the check
still matched — in a different function. **Read a function body by matching
braces, never by slicing, and prove any source-reading test by mutation before
believing it.**

When adding a guard or a fallback, prefer a loud failure. `DB_CA_PATH` pointing
at a missing file deliberately kills the process rather than downgrading to an
unverified connection — copy that instinct.

One more on 5.9.2026, and it is the local-versus-CI version of the same shape.
A test that `require`s a **route** drags in the whole server chain, and
`middleware/auth` calls `process.exit(1)` at import when `JWT_SECRET` is
missing. `db.js` and `middleware/auth.js` both call `dotenv.config()`, so on a
machine with a `.env` the require succeeds and the suite is green; CI has no
`.env`, so the same file killed the test process and took all 895 tests with
it. **A test that reaches a route must set the environment that route's imports
demand, and the way to check is to run `npm test` with `.env` moved aside** —
that is the environment CI actually has.

One more on 6.9.2026, and it is the oldest shape in this list wearing a new
coat. „Napravi korak od ove pozicije" sent a lesson step's `fen` from
`_currentNode` and its `pgn` from an export of `_rootNode`, and
`MoveTree.parsePgn` skips a move it cannot play **without a word** — so a
trainer standing anywhere but the root of their tree saved a step whose line
could not be replayed, was told „Korak uspešno dodat", and found out when a
child opened a board with no moves on it. Parity decided whether the student got
an empty line or a shortened one, so half the positions in any tree looked
correct. The fix is two rules worth copying: **one node answers for both
fields** (`StudioLessonStep.from`), and **the writer reads its own work back
through the reader's parser before saving it** — `LessonStepLine` is that one
parser, `rejectedMoves` is the number it reports, and a step that does not
replay is refused rather than stored.

## Two ways a Flutter release build hides a mistake

Both cost time on 20.8.2026, and neither shows up in tests, in `flutter
analyze`, or in the log.

**A release build paints no overflow warning.** In debug, a `Row` wider than the
screen gets the yellow-and-black stripes and an assertion. In release it is
simply clipped: the row looks shorter than it is and the buttons past the edge
are unreachable. Three of these were found by looking at a phone — the move
navigation strip, the Analysis Studio's app bar, and the notifications dialog,
which had a fixed content width of 360 on a 360 dp phone. Where a row can grow,
use `Wrap`; where a width is fixed, take it from `MediaQuery` instead. A widget
test at `Size(360, 640)` catches it, because in a *test* build the overflow does
throw.

**`flutter build windows` can ship a stale icon font.** Icons are tree-shaken
into `MaterialIcons-Regular.otf`, and that file is not always regenerated when
new icons are referenced: two builds in a row kept a font from before the icons
were added, so `Icons.handshake` and `Icons.chat_bubble_outline` rendered as
nothing at all. Icons already used elsewhere in the app kept working, which is
what makes it look like a problem with those two icons. If a newly added icon
comes out blank, check the timestamp:

```bash
stat -c '%y %s' chess_app/build/flutter_assets/fonts/MaterialIcons-Regular.otf
```

Delete that file and build again. `build_and_deploy.ps1` (Android) regenerates
it, so the same build can be right on the phone and wrong on Windows.

## Where things are written down

- `docs/STANJE-RADA.md` — the handoff document, and the only one worth reading
  whole. What is still live: where we are, what is open, what is next, and the
  rules that still hold. Read it before proposing work; much of the obvious
  backlog is already done.
- `docs/LESSONS.md` — the lesson log that used to fill this file (~150 KB).
  **Never read it whole**; grep it. New entries go at its end.
- `docs/arhiva/` — closed history split out on 27.8.2026, in two files: the
  handoff doc's finished sections (fixes with a ✅ and a date, measurements, the
  routes by which the current shape was reached) and the verification items that
  are closed in full. **Never read an archive file up front.** `grep` it when you
  need the *why* of an older decision, or the evidence that something passed,
  and read only the section you hit.
  Item numbers in `TODO-provera.md` were deliberately **not** renumbered when it
  was split — other docs cite them by number ("stavka 27"), so gaps in the
  numbering are expected, not a mistake.
- `docs/TODO-provera.md` — features that pass tests but have never been watched
  running. Ticked off only after the user confirms live.
- `docs/TODO-objavljivanje.md` — publishing steps, in dependency order.

Keep these current as part of the work, not afterwards. When something is
verified live, say who verified it and when. New entries go in
`docs/STANJE-RADA.md`; move one to `docs/arhiva/` once it is done, verified, and
nothing upcoming depends on reading it.

**These docs are big, and reading one whole is a real cost.** `TODO-provera.md`
is 75 KB and `TODO-objavljivanje.md` 45 KB — roughly 22k and 14k tokens, more
than that in Serbian. `grep` for the item you need and read around the hit;
slurping all three costs more context than the code they describe. The handoff
doc was 242 KB and `TODO-provera.md` 101 KB until they were split, which is why
every session used to open above 150k tokens before doing any work.

## Server

A provisioned droplet exists (`chess-backend-ams3`, Ubuntu 26.04 LTS, AMS3) with
nginx, a TLS certificate and a `chess-backend` systemd unit. **The service is
deliberately stopped and disabled**: while the app still points at a local
backend, two servers on one database split `uploads/` and live session state.
The switch happens in one direction, once a domain is chosen — the current
hostname is an interim `sslip.io` name.

`deploy/provision.sh` sets up the base system, `deploy/app-setup.sh` the
application half. Both are idempotent and both are meant to be re-run; that is
how two of the bugs above were found.

**Do not close port 80.** The backend is on `api.chesstrainers.app`, whose
certificate renews itself over HTTP-01 — that check reaches the host on port 80
and nowhere else. `.app` is HSTS-preloaded, so browsers never use plain HTTP and
closing 80 looks like tidying up; it silently breaks renewal, and the site
disappears three months later. Same shape as everything in the section above.

## Consent: built, and where it still has holes

*Trainer* is a position in a relationship, not a property of a person, so
`users.role` plays no part in teaching — the same account is a trainer in one
edge and a student in another. `users.role` survives only for `'admin'`.

A `trainer_students` row grants nothing until `status = 'accepted'`, and either
side may start the request; the sender chooses which capacity they are claiming.
**Verified live by the user on 17.8.2026**: invitation, greyed-out pending row,
acceptance, and assigning a lesson immediately afterwards.

Rights are read through exactly two places, and new code must use them rather
than write the condition again:

- `trainerOwnsStudent` (`services/assignmentService.js`) — homework, reports.
- `acceptedTrainersOf` (`services/relationshipService.js`) — anything a student
  reads *because* someone teaches them.

Three hand-written copies of that second subquery all forgot the status, so an
unanswered request already unlocked the sender's lessons. A test reads the source
and fails if a fourth copy appears.

**The parent half is built** (25.8.2026, not yet watched running). A minor's
relationship stops at `awaiting_parent`, the parent confirms through a link to a
page this backend serves, and `parent_consent_at/ip/version` are written from
that page — not from a code read out to a child, which proves a mail arrived and
nothing more. The age threshold (`AGE_OF_CONSENT`) and the text version
(`PARENT_CONSENT_VERSION`) are configuration, because a lawyer confirmed the
wording on 25.8.2026 **for Serbia only, and said so explicitly**; the country
list in Play Console is a decision somebody has to make rather than a default to
accept. Two rules that came out of it and hold generally: an age is read when an
edge is created and never applied backwards over edges that exist — **tell the
trainer, do not rewrite their lesson** — and the parent is asked **two**
questions rather than three.

The third question — recording the lesson — was removed on 26.8.2026, one day
after it was built. `parent_allows_recording` had spent its first hours written
by the parent's page and read by nobody; the enforcement written for it worked,
and then the feature it enforced was deleted. **A lesson is not recorded at all
any more, by anybody, under any consent.** The replay survives, silently: a
recording is a `timeline_json` and `audio_url` was always nullable.

The reasoning, because it generalises: the feature bought a replay with sound
and cost a per-market legal text about children's voices plus the worst breach
this project could have had. Removing it barely shrank the consent machinery —
that is driven by minors *having accounts*, not by recording — but it removed
the one artefact that could not be taken back. **Exposure falls by holding less,
not by getting an opinion that holding it is allowed.**

Still open: the account-level lock (a minor with no trainer uses the app as
before, since the approved text is per-trainer), and parent observation of a
lesson, which is designed (`docs/STANJE-RADA.md`, "Dogovoren model uloga i
nadzora") and not built.
