# Plan: what I solved, what I failed, and how I get it back

Proposed 17.9.2026 at the owner's request, as a lean design. Phases 0–2 were built and merged the same day; phase 3 (SM-2) stays optional and unbuilt.
On 1.10.2026 the trainer's report was brought onto the same fold (§7.2), and
§7 plans the list of *which* puzzles, each account its own — every
decision answered 1.10.2026; phases 5–7 built the same day, phase 8 (the
owner's live pass) left.
It sits inside `PLAN-REORGANIZACIJA.md`: the Practise tab is „the hub,
unchanged", and this plan is the one thing that changes on its cards.

**It is a feature, and the freeze of `PLAN-ZAVRSNICA.md` 1c says no new
features.** The owner asked for it explicitly on 17.9.2026, which is how every
other row of that table was reopened; written here so it is a decision, not
a drift.

## 1. The request

The owner: in the Training hub a player solves mates, tailored tactics,
endgames, winning positions — and never sees what they solved or failed, and
cannot get a failed one back. Three requirements: **track** the state of each
puzzle per user (solved first try, failed, skipped); a **retry queue**; and
**counts on the cards**. Reuse what exists — attempts, reviews, SM-2.

## 2. What the backend already stores — and where the holes are

Read on `master` at `bd64f9c`, `chess_backend/db.js` and `routes/puzzles.js`.

| Store | What it holds | Who writes it | The hole |
|---|---|---|---|
| `user_puzzle_attempts` (user, puzzle_id, `source` default `'lichess'`, `solved`, themes, ms, created_at; index on (user, puzzle)) | one row per try | `POST /api/puzzles/attempt` — **tactics only** | mates, winning positions, endgames and blunder games write **nothing** here. The code's own comment beside the insert says it is kept „for the future progress view" — this plan is that view |
| `user_puzzle_ratings` (`puzzles_solved`, `puzzles_failed`, Elo) | two counters, all categories mixed | `/attempt` and `/submit` | a total, never per puzzle or per category; cannot say *which* |
| `POST /api/puzzles/submit` | rating update for mates and winning positions | the drill screen | updates the counters and **inserts no attempt row** — the one fix that unlocks most of this plan |
| `POST /api/puzzles/endgame/play` | judges one move by tablebase | endgame trainer | records nothing; the screen counts `Solved: n/m` in memory and forgets it |
| `review_items` (tutorial steps) and `mistake_reviews` (own-game mistakes) | SM-2: ease, interval, repetitions, lapses, `due_at` | `spacedRepetitionService.schedule()` — one implementation, two tables | neither can hold a puzzle: strict foreign keys to `saved_lessons` and `user_games` |
| „Save for later" (endgames, blunder walk) | a `saved_lessons` row tagged `Unclear` | `keepForLater` through `LessonApiService` | a shelf, not a queue: the player chose it, and nothing brings it back |
| Skip (tactics „Skip", endgame „Skip", blunder „Skip") | — | — | not recorded at all; a skipped puzzle is indistinguishable from one never seen |
| Basic checkmates | positions from client presets, no table, no id | — | untrackable as they stand |

So: **the attempt log exists, is indexed the right way, and is written by one
of five drills.** The rest of this plan is making the other four write it,
reading it back, and deciding what a retry is.

## 3. The design

### 3.1 Tracking — one table, no new one

`user_puzzle_attempts` becomes the log for every drill. Two changes to the
table, both additive:

```sql
ALTER TABLE user_puzzle_attempts ADD COLUMN IF NOT EXISTS skipped BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE user_puzzle_attempts ADD COLUMN IF NOT EXISTS hinted  BOOLEAN NOT NULL DEFAULT false;
-- solved=false AND skipped=true is a skip; solved=false AND skipped=false is a failure.
```

`source` stops meaning „lichess" and names the drill, frozen here:

| `source` | `puzzle_id` | Written by |
|---|---|---|
| `lichess` | the Lichess id (as today) | `/attempt` (tactics) |
| `mate_puzzle`, `winning_position` | `puzzles.puzzle_id` | `/submit`, which gains the same insert `/attempt` already has |
| `endgame` | `endgame_puzzles.puzzle_id` | the endgame trainer, after the tablebase verdict of the *first* move |
| `blunder_game` | `<blunder_games.id>:<ply>` | the blunder walk, per stop |
| `basic_mate` | `basic:<preset>:<fen_key>` — the first four FEN fields, the key `opening_nodes` and the repertoire already use | the drill, per preset position |

The states the owner asked for are **derived, not stored**: per (user,
puzzle), the *first* row says „solved on first try" (`solved AND NOT hinted`,
`NOT skipped`); the *latest* row says where it stands now. One query:

```sql
SELECT DISTINCT ON (puzzle_id) puzzle_id, solved, skipped, hinted, created_at
FROM user_puzzle_attempts WHERE user_id = $1 AND source = $2
ORDER BY puzzle_id, created_at DESC;      -- latest per puzzle; ASC for the first
```

`hinted` matters because the app already knows it (`TacticsPuzzle`,
`EndgamePuzzle` both mark a hinted attempt „so scoring can tell") and throws
it away at the wire.

### 3.2 The retry queue — a query first, SM-2 second

**Phase 1–2: the queue is a query.** *To retry* = every puzzle whose latest
attempt is not `solved`. No table, no scheduler, nothing to migrate, and it is
exactly the list a player means by „the ones I failed". `GET
/api/puzzles/retry?source=` returns the ids; each drill already has a way to
serve one puzzle by id (`/puzzles/by-id/:id` for tactics; `puzzles` and
`endgame_puzzles` need the same one-line route each; the blunder walk takes a
game id). A puzzle leaves the queue by being solved, which is the next row.

**Phase 3, optional: failed twice → spaced repetition.** When a puzzle's
second failure is written, it enters a `puzzle_reviews` table — the same seven
SM-2 columns as `review_items` and `mistake_reviews`, keyed (user, source,
puzzle_id), scheduled by the existing `schedule()`, graded by the existing
`GRADES`. A third table of the same shape is deliberate: the other two are
tied to their parents by foreign keys that cascade, and a puzzle has no parent
row to cascade from. What is **not** duplicated is the algorithm. The Practise
card then shows the due count where phase 2 showed the retry count; the
student's Review card on Home stays about tutorials.

Why not straight to SM-2: a player who failed a mate-in-two once wants it
back *now*, not in a day, and a review scheduler that shows ten of the same
motif on the same evening is the cost the mistake drill already paid for
(`docs/PLAN-MOJE-PARTIJE.md`, recurrence). The query answers the owner's
requirement; SM-2 improves it later, on top, without changing what phases 1–2
built.

### 3.3 Progress on the cards

One endpoint, `GET /api/puzzles/progress`, one round trip when the hub opens:

```json
{ "mate_puzzle":      { "seen": 61, "solved": 48, "firstTry": 40, "toRetry": 9,  "byDepth": { "1": {...}, "2": {...}, "3": {...} } },
  "lichess":          { "seen": 210, "solved": 154, "firstTry": 131, "toRetry": 39 },
  "endgame":          { "seen": 17, "solved": 11, "firstTry": 9,  "toRetry": 4, "byMode": { "win": {...}, "draw": {...} } },
  "winning_position": { ... }, "blunder_game": { ... }, "basic_mate": { "byPreset": {...} } }
```

`seen` rather than a denominator like „of 100": the pools are thousands (the
Lichess set) or open-ended (blunder games), and „34 / 100" would be a number
the app invented. The card says what is true: **Solved 48 · 9 to retry**.

## 4. From the user's seat

On the Practise tab (the hub), every card gains one line and, when the queue
is not empty, one button:

```
┌ Puzzles: Mate in 1, 2 or 3 ─────────────────────────────┐
│ Solved 48 · 9 to retry        [Mate in 1] [Mate in 2] [Mate in 3] │
│                               [↺ Retry failed (9)]               │
└──────────────────────────────────────────────────────────┘
┌ Tactics tailored to you ────────────────────────────────┐
│ Solved 154 · 39 to retry      [Start training] [↺ Retry (39)]    │
└──────────────────────────────────────────────────────────┘
┌ Endgames from master games ─────────────────────────────┐
│ Win: 7 solved · 2 to retry   Hold: 4 solved · 2 to retry         │
│ [Win] [Hold a draw] [Game blunders]   [↺ Retry failed (4)]       │
└──────────────────────────────────────────────────────────┘
```

- **A card with nothing seen says nothing** — no „Solved 0", no zero badge.
  The line appears after the first attempt, which is also the moment it can
  be true.
- **„Retry failed (n)"** opens the same drill screen in *retry mode*: the app
  bar says „Retry · 3 of 9", the queue is the list from §3.2 in the order
  failed, and „Skip" moves on without writing a row (a skip inside a retry is
  not a new skip of the puzzle). Solving one writes the ordinary attempt row,
  which is what removes it from the list.
- **Inside every drill, after a failure**, the existing buttons stay; nothing
  new. „Skip" now writes `skipped = true`. Nothing is asked of the player.
- **The trainer's view** (`StudentProgressScreen`, „Platform" tab) already
  reads `user_puzzle_attempts` for the last 30 days; it gains the same per-
  source line for free once the rows exist — phase 2 adds one row to its
  summary, no new query shape. *(1.10.2026: phase 2 never did, and the report
  kept summing rows — a puzzle tried five times was five, a skip a wrong
  answer. Brought onto the fold that day; §7.2.)*
- Home (Variant B) shows none of this. The numbers belong to the cards.

## 5. Phases

| # | Phase | Carrier | Gate |
|---|---|---|---|
| 0 | `source` values and the two columns frozen (§3.1); `progress` and `retry` queries written as functions in a new `services/puzzleProgress.js` with tests on a seeded pool: first-try vs later solve, skip is not failure, hinted solve is not first-try, latest row wins | lead | **done 17.9.2026.** The fold is a pure function over rows (CI has no database, so the arithmetic lives where a test can feed it rows in any order); the SQL is one line and a stub pool asserts it. Eleven tests; five mutations tried — latest picked by `<`, hinted ignored, skip counted as failed, newest-first retry order, `ORDER BY` dropped — each caught by the test it names |
| 1 | Backend writes: `/submit` inserts the attempt row with `source = puzzles.type`; `/attempt` accepts `source`, `skipped`, `hinted`; two by-id routes (`puzzles`, `endgame_puzzles`); `GET /api/puzzles/progress`, `GET /api/puzzles/retry` | implementer | **done 17.9.2026**, merged `da433d3`. The gate `test/puzzle_progress_routes.test.js` (19 tests, handlers called with a fake request, the pool's `query` replaced) was red on master on 15 and is green and byte-identical to `docs/gates/`. Backend 1387 → 1406 in CI's environment. The worker's one correction: the Lichess insert wrote `'lichess'` as a SQL literal and the gate reads it as a bound parameter — bound now, on both branches |
| 2 | App writes and reads: the five drills post their outcome and skips through one `PuzzleAttemptApi` (fake the client, assert the request — rule 7); hub cards show the line and the button; retry mode in the drill screens (`retryIds` on the route as a query, not a new path) | implementer | **done 17.9.2026**, merged `1677f34`. The wire (`puzzle_attempt_api.dart`, 11 tests, three mutations caught) is the lead's; the hub gate (8 tests) is green; three drill tests fake the client. The worker found the brief's premise wrong twice — winning positions and basic mates recorded *nothing* before, and the mate drill's „Incorrect Move" sheet recorded nothing on either button — and wired both. **Not tested by machine:** the mate drill's recording (`ai_studio_screen.dart` starts a real engine) — live check 176. The blunder game's id is opaque on the wire (`1adbc17`, `7da960b`). Master: 2878, 1 skipped, analyze 26 |
| 3 | *Optional* — `puzzle_reviews` and SM-2 on the second failure (§3.2); the card's count becomes „due" | lead (schema) then implementer | `schedule()` untouched; a puzzle enters on the second failure and not the first; grading moves `due_at` |
| 4 | Live pass, one `TODO-provera` item, on Windows and a phone | owner | ticked |
| 4b | The trainer's report and the parent report count puzzles through the fold (§7.2) | lead | **done 1.10.2026.** Backend 1992 → 2007 without a database, 2155 → 2170 with one (2007 and 2170 measured, and 2170 is 2155 + 15, which confirms that derived figure); eleven mutations of the fold and the report, ten red on the case written for them and the eleventh a no-op that asked whether `new Set(themes)` carried anything — it did not, and went. The route's `hasData` still read the old field; caught by grep, held by a test through the handler |

Phases 0 and 1 are backend only; 2 waits for 1. **This plan and
`PLAN-REORGANIZACIJA` phase 5 touch the same hub widget** — sequence 2 after
the tab change lands, or run it before phase 5 starts; not during.

## 6. What this plan does not do

- It does not rename `user_puzzle_attempts.solved` to an enum. Two booleans
  are additive and keep every reader working; an enum is a migration of a
  table the trainer panel and assignments read.
- It does not track the basic-mate presets beyond a per-position key; they
  have no pool to be a fraction of.
- It does not merge the tutorial Review, the mistake drill and the puzzle
  retry into one queue. They answer three questions („what did my trainer
  teach", „where do I go wrong in my games", „which puzzles beat me") and the
  hub already gives each its card.
- It does not add streaks, daily goals or a leaderboard.

## 7. Which puzzles, not only how many (proposed 1.10.2026)

### 7.1 The request

The owner, 1.10.2026: „can we follow which puzzles the user solved and which
not?" Phases 0–2 already record it — every drill writes `user_puzzle_attempts`,
and `puzzlesOf` / `stateOf` / `solvedFirstTry` (`services/puzzleProgress.js`)
say where each puzzle stands — but every screen shows only **counts**: the
Practise cards („Solved 48 · 9 to retry"), the trainer's Overview and the
parent report. Nobody can see *which* puzzles, open one, or try a particular
one again. This section is that list, **for the individual**: every account
sees its own puzzles, and only its own.

The owner, answering D3 the same day: not every user is a trainer or a
student, and these puzzles are an individual's own work, whoever they are —
roles play no part in them. So nothing in this section asks who the user
is; it asks only whose log it is. The first draft had a trainer's view of a
student's list and a rule that let a trainer do what a player could not;
both are gone (D1, D3, D5).

### 7.2 Done first, the same day: the report counts what the cards count

§4 promised that the trainer's view would gain the cards' numbers „for free";
phase 2 never touched it, and the report kept summing rows. Fixed 1.10.2026
before this plan was written, because the list would otherwise have
disagreed with the report beside it:

- `summariseAttempts` (`services/assignmentService.js`) reads `puzzlesOf`: a
  puzzle counts once, its state is its latest row, **a skip is a skip**.
- The period's accuracy is **solved at the first attempt** (no hint), over the
  puzzles *first met* in the period and answered there (`firstTries`). A retry
  is not a first meeting, so a month spent clearing old failures does not
  carry the failures of the month before it.
- `lifetimeSolved` is the same fold over the whole log, not
  `user_puzzle_ratings`' counters, which count rows and only of rated drills.
- Rating movement is read from the rows that carry a rating, so an endgame
  or a game blunder at either end of the period no longer makes it „no data".
- The parent report's snapshot carries the new figures under new names;
  snapshots sent before that day are still rendered in their own names, so a
  link shows what it showed (until their 60 days run out, 30.11.2026).
- **A drill is not a motif** (the owner's choice (b), the same day, over „no
  theme" and „a label"): `/submit` had stored `['mate_puzzle']` or
  `['winning_position']` as a row's themes, and the report printed them as
  motifs. A row's themes are now `motifsOf` (`puzzleProgress.js`): only the
  motifs the server trains count, a mate puzzle is the „mate in N" its depth
  names — one tally with the Lichess mates of that depth — and a winning
  position has none. It is read where the log is read, so the rows written
  before count the same way; `/submit` stores no themes. A snapshot sent
  before shows the two names in words (`FROZEN_DRILL_LABELS`).

### 7.3 What exists to build on

| Piece | Where | What the list takes from it |
|---|---|---|
| The per-puzzle fold | `puzzlesOf`, `stateOf`, `solvedFirstTry` | every row's state — **one home**; the list never decides a state itself |
| The log query | `attemptsOf` (`ATTEMPTS_SQL`) | the rows, whole, oldest first |
| Positions by id | `/puzzles/by-id/:id?source=` for `lichess`, `mate_puzzle`, `winning_position`, `endgame`; `custom_puzzles` for `own` | the board of each row — but one by one, which a list of 300 cannot afford (7.4) |
| The two sources with no by-id | `blunder_game` = `<blunder_games.id>:<ply>` (the position is `blunders[ply].fen`); `basic_mate` = `basic:<preset>:<first four FEN fields>` (the position is in the id) | both can still give a board; neither can be served again as a drill (`PuzzleSource.retryable`) |
| Retry mode | each drill's `retry: true`, which fetches `retryIds(source)` and walks it | „Try again" for one puzzle is the same mode handed a queue of one |
| The list + pane pattern | `LibraryList` (`onSelect`, `selectedId`), `BoardPreviewPanel`, `AdaptiveCardGrid` (`docs/PLAN-LISTE.md`, pattern B) | the layout, and its gates' widths |
| The caller | `authenticateToken` (`req.user.id`) | the list's only owner: the account comes from the session, never from the request |

### 7.4 The design

**One service function, one route.** `puzzleListOf(pool, userId, { source,
state, since, before, limit })` in `puzzleProgress.js`: `attemptsOf`, then
`puzzlesOf`, then one row per puzzle —

```json
{ "source": "endgame", "puzzleId": "eg_812", "state": "failed",
  "firstTry": false, "tries": 3, "solvedOnTry": null,
  "firstAt": "…", "latestAt": "…", "available": true, "fen": "8/5pk1/…",
  "detail": { "mode": "draw", "type": "RookEndgame", "material": "KRPvKR",
              "materialLabel": "rook and pawn versus rook" } }
```

— newest `latestAt` first, filtered by source and state, a page at a time.
*(As built, 1.10.2026: a row carries `detail` — the facts its table has, a
mate's depth, an ending's mode and label, a game blunder's ply and players,
a basic mate's preset, an own exercise's task — instead of a `title`. The
app writes the words, as it does everywhere; a basic mate's preset is only
named in the app. `tries` counts answers, not skips, and `solvedOnTry` says
which answer first solved it.)*

**The cursor holds the moment the first page read the log**, as well as the
place the page ended. Later pages read the log as it stood then: a puzzle
tried again while the list is being read keeps its place, instead of
jumping above the cursor where no later page would show it, and the new try
appears when the list is read again from the top. A cursor on `latestAt`
alone, as first drafted, loses exactly that puzzle; an offset loses it the
same way. Positions are joined **per source, in one query
each** (`… WHERE puzzle_id = ANY($1)`), never per row: at most five queries
for a page, whatever its length. `blunder_game` reads its game's JSONB once
per game on the page; `basic_mate` reads nothing.

**The board is the one the player was asked about.** For `lichess` that is
*not* the stored FEN: `lichess_puzzles.fen` is the position before the
opponent's move, and the drill plays `setup_move` first
(`toClientPuzzle`). The list plays that one move with chess.js, as the drill
does, and the gate holds a real row to it — a list of tactics drawn one move
early would show every player a position they never saw.

`GET /api/puzzles/list` is the caller's own list, the caller taken from the
session and never from a parameter. There is no second route: no account
reads another's list (§7.7). An `own` position is joined only for the
caller's own exercise (`custom_puzzles.owner_id`), so an id in the log
cannot fetch another account's board.

**A puzzle that no longer exists stays in the list** with `available:
false` and no board — an own exercise deleted since, or a pool row removed.
It still counts in the cards (the fold reads the log, not the pool), so
hiding it would make the list shorter than the number above it; „Selected:
N positions" taught that two answers to „how many" must count one set.

**The screen** (one widget, `PuzzleHistoryList`):

- Each row: a board (48 px — the `ListTile` slot is 48 high on a desktop,
  measured 21.9.2026), what it is (source and kind: „Mate in 2", „Tactics ·
  fork, pin", „Rook endgame · Hold a draw", „Game blunder · move 34"), its
  state **in words** — `Solved first try`, `Solved on try 3`, `Failed`,
  `Skipped` — the number of tries and the last date. *(As built: a solved
  puzzle's state already names its try, so the count is shown for the
  others — „Solved on try 2 · 2 tries" said one thing twice. A tactic's
  motifs come from the server, through `trainableThemes`, the rule the report
  reads them by.)* Words, not colour: the
  owner is colour-blind, and the state must read in luminance and shape.
- Filters above it: state chips (`All`, `Failed`, `Skipped`, `Solved`) and a
  source menu. *(As built: the chips are one row that scrolls sideways on a
  phone — wrapped, they took three lines of a 640 dp screen.)* They compose — the state cuts the source's remainder — and the
  gate holds that with a fixture where each filter cuts something the other
  would not (PLAN-LISTE phase 7's lesson).
- Wide (≥ 840): the list and a pane beside it with the selected puzzle's
  board, as the Library does. Narrow: a tap opens the same pane as a sheet.

**The door.** A card's progress line on the Practise tab („Solved 48 · 9 to
retry") opens the list filtered to that card's source. The Practise tab is
the same for every account, so the door is too — an account with no trainer
and no students reaches it like any other. Nowhere else: the list belongs
where its numbers are.

**Actions from the pane** (phase 7, smallest set):

- `Try again` — on a retryable source: the drill's retry mode with a queue
  of one (an `initialRetryIds` parameter beside the existing `retry` flag).
  Writes an ordinary attempt row, so the list and the card move together.
- `Open in Analysis` — on every row that has a board, whatever its state
  (D3: everything opens, for every account). A row with `available: false`
  has no board and so no door. Looking does not move the numbers it should
  not: a puzzle opened there and then tried again counts as solved, never as
  solved at the first attempt — `solvedFirstTry` reads the first row — so the
  report's accuracy, which is the first attempt, cannot be raised by
  looking.

### 7.5 Decisions (all answered 1.10.2026)

| # | Question | Answer |
|---|---|---|
| D1 | ~~Does the trainer see the student's own exercises in the list?~~ | **Withdrawn** with the trainer's view (D3's answer). An account's own exercises are in its own list like any other source |
| D2 | Do game blunders and basic mates appear, though neither can be tried again from the list? | **Answered 1.10.2026, as recommended: yes**, with no `Try again` — they are solved and failed like the rest, and the cards count them |
| D3 | May a puzzle **still to retry** be opened in Analysis, with the engine one tap away? | **Answered 1.10.2026: everything opens, for every account.** Not every user is a trainer or a student, the puzzles are an individual's own work, and roles play no part in them; whether to look before solving is the individual's choice. The first draft's „not until solved or skipped" and its trainer exception are both gone |
| D4 | How far back does the list go? | **Answered 1.10.2026, as recommended: all of it**, newest first, paged; the period chips of the report are not repeated here |
| D5 | ~~The trainer's list: a tab or a row in the Overview?~~ | **Withdrawn** with the trainer's view (D3's answer) |

### 7.6 Phases

| # | Phase | Carrier | Gate |
|---|---|---|---|
| 5 | Server: `puzzleListOf` and `GET /api/puzzles/list`; positions joined per source; `available: false`; the `before` cursor | lead, gate and build — **done 1.10.2026.** `services/puzzleList.js`, the route after `/puzzles/retry`, `puzzlesOf` keeping each puzzle's rows. Gate: `test/puzzle_list.test.js` (26 cases, the fold property over eight seeded random logs) and `test/puzzle_list_db.test.js` (one case on a real database: every source's table, the owner scope). Seventeen mutations red on their own cases, after one survived: a fold that lost the rows' time order kept every total, because the fold's own test of that rule uses two mirror-image puzzles and asserts only totals — a per-puzzle case now holds it. A wrong column name passes every stub and fails only on the real database, which is what the second file is for. Backend 2007 → 2033 without a database, 2170 → 2197 with one (both measured) | Stub pools asserting the SQL each source is asked (one query per source, never per row); **the list's states summed equal `foldAttempts` over the same rows** (one home, a property over random logs); a deleted own exercise listed with `available: false`; a real Lichess row's board is the position after its `setup_move`, not the stored FEN; paging returns every puzzle exactly once across pages while a new attempt arrives between them; **the list is the caller's alone** — the SQL is bound to the session's id, a `userId` or `studentId` in the query changes nothing, and an `own` exercise of another account named by an id in the log comes back with no board |
| 6 | App: the list screen and the cards' door | lead, gate and build — **done 1.10.2026.** `PuzzleHistoryScreen` (`lib/features/puzzle_history/`, the words in their own file), `PuzzleAttemptApi.list`, every Practise card's progress line a door to its own source (`onOpenList`, drawn as words when not given), route `/puzzles/history?source=`. Gate `test/puzzle_history_test.dart` (21), its rows the server's own answer. Twenty-five mutations, each red on its own case: two survived first — the guard that drops an answer to a filter already changed, and the pane cleared when a filter leaves its puzzle out — and got cases; one did not compile and was rewritten. A look at the rendered screen found what the gate passed: three lines of filters on a phone and a count said twice. App 5400 → 5421, backend unchanged in count (2042 / 2206) |
| 7 | Actions: `Try again` (retry mode with a queue of one, per retryable drill) and `Open in Analysis` (D3) | lead, gate and build — **done 1.10.2026.** One map of which drill retries what, `AppRoutes.retryPath`, read by the hub's „Retry failed" and the list's „Try again" alike; tactics, mates, winning positions and endgames take `retryIds` beside `retry`, and the router passes `&id=`; an own exercise is tried on the shared solver, as the Library's „Solve", and only when the server says it is answered with a move (`findable`, the queue's own rule). A realistic answer to a retry found a wrong word: a puzzle skipped and then solved on its first answer read „Solved with a hint"; the server now sends `solvedWithHint`, and the words say „Solved after a skip". Gate `test/puzzle_history_actions_test.dart` (20); sixteen mutations, each red on its own case, after one survived — a sheet left open under Analysis, invisible to a finder while Analysis covers it. App → 5446, backend 2049 → 2050 / 2213 → 2214 |
| 8 | Live pass, items in `TODO-provera.md` under Practise | owner | ticked |

Phase 5 needs no schema change: the log, the pools and the fold exist. If
`attemptsOf` over a long tactics history proves slow in phase 5's
measurement on the owner's account, a per-puzzle `DISTINCT ON` view is the
next step — measured first, not assumed.

### 7.7 What this section does not do

- No new store: the list is the fold over the log, as the cards are.
- No SM-2 (phase 3 stays optional), no streaks, no leaderboard.
- **No account reads another's list** — not a trainer, not a parent. The
  puzzles are an individual's own work (owner, 1.10.2026). What a trainer
  sees of a student stays where it was: the report's counts (§7.2), which
  the trainer–student relationship already shows, and a parent's report
  stays the summary.
- No `Add to homework` from the list. Sending a puzzle to someone is an act
  between two accounts, and the list is one account's own; the homework
  editor has its own doors.
- It does not change what counts as solved — `stateOf` is the one rule, and
  the list only shows it.
