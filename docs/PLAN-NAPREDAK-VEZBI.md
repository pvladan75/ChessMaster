# Plan: what I solved, what I failed, and how I get it back

Proposed 17.9.2026 at the owner's request, as a lean design. Phases 0–2 were built and merged the same day; phase 3 (SM-2) stays optional and unbuilt.
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
  summary, no new query shape.
- Home (Variant B) shows none of this. The numbers belong to the cards.

## 5. Phases

| # | Phase | Carrier | Gate |
|---|---|---|---|
| 0 | `source` values and the two columns frozen (§3.1); `progress` and `retry` queries written as functions in a new `services/puzzleProgress.js` with tests on a seeded pool: first-try vs later solve, skip is not failure, hinted solve is not first-try, latest row wins | lead | **done 17.9.2026.** The fold is a pure function over rows (CI has no database, so the arithmetic lives where a test can feed it rows in any order); the SQL is one line and a stub pool asserts it. Eleven tests; five mutations tried — latest picked by `<`, hinted ignored, skip counted as failed, newest-first retry order, `ORDER BY` dropped — each caught by the test it names |
| 1 | Backend writes: `/submit` inserts the attempt row with `source = puzzles.type`; `/attempt` accepts `source`, `skipped`, `hinted`; two by-id routes (`puzzles`, `endgame_puzzles`); `GET /api/puzzles/progress`, `GET /api/puzzles/retry` | implementer | **done 17.9.2026**, merged `da433d3`. The gate `test/puzzle_progress_routes.test.js` (19 tests, handlers called with a fake request, the pool's `query` replaced) was red on master on 15 and is green and byte-identical to `docs/gates/`. Backend 1387 → 1406 in CI's environment. The worker's one correction: the Lichess insert wrote `'lichess'` as a SQL literal and the gate reads it as a bound parameter — bound now, on both branches |
| 2 | App writes and reads: the five drills post their outcome and skips through one `PuzzleAttemptApi` (fake the client, assert the request — rule 7); hub cards show the line and the button; retry mode in the drill screens (`retryIds` on the route as a query, not a new path) | implementer | **done 17.9.2026**, merged `1677f34`. The wire (`puzzle_attempt_api.dart`, 11 tests, three mutations caught) is the lead's; the hub gate (8 tests) is green; three drill tests fake the client. The worker found the brief's premise wrong twice — winning positions and basic mates recorded *nothing* before, and the mate drill's „Incorrect Move" sheet recorded nothing on either button — and wired both. **Not tested by machine:** the mate drill's recording (`ai_studio_screen.dart` starts a real engine) — live check 176. The blunder game's id is opaque on the wire (`1adbc17`, `7da960b`). Master: 2878, 1 skipped, analyze 26 |
| 3 | *Optional* — `puzzle_reviews` and SM-2 on the second failure (§3.2); the card's count becomes „due" | lead (schema) then implementer | `schedule()` untouched; a puzzle enters on the second failure and not the first; grading moves `due_at` |
| 4 | Live pass, one `TODO-provera` item, on Windows and a phone | owner | ticked |

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
