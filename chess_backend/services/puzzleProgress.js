// puzzleProgress.js — what a player solved, what beat them, and what to retry.
//
// docs/PLAN-NAPREDAK-VEZBI.md, phase 0. The store is `user_puzzle_attempts`,
// which every drill will write once phase 1 lands; today only tactics does.
// Nothing here is stored: the three states the owner asked for — solved on the
// first try, failed, skipped — are *derived* from the first and the latest row
// of each puzzle, so there is no second number to keep in step with the log.
//
// The fold is a pure function over rows, and that is deliberate: the tests
// cannot reach a database (CI has none), so the arithmetic lives where a test
// can feed it rows in any order and read the answer. The SQL is one line, and
// the one thing a test asks of it is that it is the right line.

const SOURCES = Object.freeze([
  'lichess',          // tactics — the Lichess id
  'mate_puzzle',      // puzzles.puzzle_id
  'winning_position', // puzzles.puzzle_id
  'endgame',          // endgame_puzzles.puzzle_id
  'blunder_game',     // `${blunder_games.game_id}:${ply}` — the text column the walk records
  'basic_mate',       // `basic:${preset}:${fen_key}` — the first four FEN fields
  'own',              // custom_puzzles.puzzle_id — one's own exercise, solved alone
]);
const SOURCE_SET = new Set(SOURCES);

/// Sources whose verdict the server reaches itself and writes itself. A row of
/// one of these is never taken from a client's `solved`: `POST /api/puzzles/
/// attempt` refuses them, and `POST /exercises/:id/attempt` is their writer
/// (docs/PLAN-MATERIJAL.md, phase 1).
const SERVER_JUDGED = Object.freeze(['own']);

function isKnownSource(source) {
  return SOURCE_SET.has(source);
}

function isServerJudged(source) {
  return SERVER_JUDGED.includes(source);
}

function emptyTally() {
  return { seen: 0, solved: 0, firstTry: 0, failed: 0, skipped: 0, toRetry: 0 };
}

/// One row of the log as the fold reads it. `bucket` is optional and names a
/// finer group inside the source (a mate depth, an endgame mode); phase 1
/// supplies it from a join, phase 0 only carries it through. `themes` is what
/// the trainer's report groups by; only tactics, mates and winning positions
/// write any.
function normalise(row) {
  return {
    puzzleId: String(row.puzzle_id),
    source: row.source,
    solved: row.solved === true,
    skipped: row.skipped === true,
    hinted: row.hinted === true,
    bucket: row.bucket == null ? null : String(row.bucket),
    themes: Array.isArray(row.themes) ? row.themes.map(String) : [],
    at: new Date(row.created_at).getTime(),
  };
}

/// Every puzzle in the rows once, with its first row, its latest, and all of
/// them oldest first (`rows`, which the puzzle list counts tries from): **the
/// one place where "a puzzle counts once" is decided.** The cards' fold below,
/// the trainer's report (`summariseAttempts` in assignmentService.js) and the
/// list (`puzzleList.js`) all read it, so a player cannot have one number on
/// the Practise tab and another anywhere else. Rows may arrive in any order:
/// "latest row wins" is the whole rule and must not depend on a caller's
/// ORDER BY. The sort is stable, so of rows that share a moment the first to
/// arrive stays first and the last to arrive is the latest.
function puzzlesOf(rows = []) {
  const byPuzzle = new Map();
  for (const raw of rows) {
    if (!isKnownSource(raw.source)) continue;
    const row = normalise(raw);
    const key = `${row.source}\u0000${row.puzzleId}`;
    const list = byPuzzle.get(key);
    if (list) list.push(row);
    else byPuzzle.set(key, [row]);
  }
  return [...byPuzzle.values()].map((list) => {
    list.sort((a, b) => a.at - b.at);
    return { first: list[0], latest: list[list.length - 1], rows: list };
  });
}

/// Where a puzzle stands now, read from its latest row. A skip is a third
/// answer, never a failure.
function stateOf({ latest }) {
  if (latest.solved) return 'solved';
  if (latest.skipped) return 'skipped';
  return 'failed';
}

/// Whether the first meeting solved it, with no hint and no skip.
function solvedFirstTry({ first }) {
  return first.solved && !first.hinted && !first.skipped;
}

function count(tally, entry) {
  const state = stateOf(entry);
  tally.seen += 1;
  tally[state] += 1;
  if (state !== 'solved') tally.toRetry += 1;
  if (solvedFirstTry(entry)) tally.firstTry += 1;
}

/// Folds attempt rows into a tally per source (and per bucket where the rows
/// name one), one puzzle at a time (`puzzlesOf`).
///
/// Returns `{ [source]: { seen, solved, firstTry, failed, skipped, toRetry,
/// buckets?: { [bucket]: tally } } }`. A source with no rows is absent — a card
/// with nothing seen says nothing.
function foldAttempts(rows = []) {
  const out = {};
  for (const entry of puzzlesOf(rows)) {
    const { first, latest } = entry;
    const source = latest.source;
    const tally = out[source] || (out[source] = emptyTally());
    count(tally, entry);
    const bucket = latest.bucket ?? first.bucket;
    if (bucket != null) {
      tally.buckets = tally.buckets || {};
      const b = tally.buckets[bucket] || (tally.buckets[bucket] = emptyTally());
      count(b, entry);
    }
  }
  return out;
}

/// The puzzles of one source whose latest attempt did not solve them, oldest
/// failure first — the order a player means by "the ones I failed".
function retryIds(rows = [], source) {
  if (!isKnownSource(source)) {
    throw new RangeError(`unknown puzzle source: ${String(source)}`);
  }
  const latest = new Map();
  for (const raw of rows) {
    if (raw.source !== source) continue;
    const row = normalise(raw);
    const seen = latest.get(row.puzzleId);
    if (!seen || row.at >= seen.at) latest.set(row.puzzleId, row);
  }
  return [...latest.values()]
    .filter((row) => !row.solved)
    .sort((a, b) => a.at - b.at)
    .map((row) => row.puzzleId);
}

// The bucket is the finer group a card shows inside a source — a mate's depth,
// an endgame's mode (win / draw) — and it comes from the puzzle's own row, not
// from a column of the log: the log records that a puzzle was tried, the
// puzzle knows what kind it is. Sources without a finer group join nothing.
const ATTEMPTS_SQL =
  `SELECT a.puzzle_id, a.source, a.solved, a.skipped, a.hinted, a.created_at,
          a.themes, a.rating_before, a.rating_after,
          COALESCE(p.mate_depth::text, e.mode) AS bucket
     FROM user_puzzle_attempts a
     LEFT JOIN puzzles p
       ON a.source IN ('mate_puzzle', 'winning_position') AND p.puzzle_id = a.puzzle_id
     LEFT JOIN endgame_puzzles e
       ON a.source = 'endgame' AND e.puzzle_id = a.puzzle_id
    WHERE a.user_id = $1
    ORDER BY a.created_at ASC`;

/// The log for one user. One query, read once, folded where it is needed —
/// `progressOf`, `retryIdsOf` and the trainer's report (`getStudentProgress`)
/// all go through here so they cannot disagree.
async function attemptsOf(pool, userId) {
  const res = await pool.query(ATTEMPTS_SQL, [userId]);
  return res.rows;
}

async function progressOf(pool, userId) {
  return foldAttempts(await attemptsOf(pool, userId));
}

async function retryIdsOf(pool, userId, source) {
  return retryIds(await attemptsOf(pool, userId), source);
}

module.exports = {
  SOURCES,
  SERVER_JUDGED,
  isKnownSource,
  isServerJudged,
  attemptsOf,
  puzzlesOf,
  stateOf,
  solvedFirstTry,
  foldAttempts,
  retryIds,
  progressOf,
  retryIdsOf,
};
