// playerProfile.js — the weaknesses that are not about openings.
//
// Section 5 of docs/PLAN-MOJE-PARTIJE.md. Everything here comes out of
// `user_games` alone: no engine, no tablebase, no network. Where the leak
// report asks "which position do you keep answering badly", this asks the
// questions that have no position in them at all — how you do as each colour,
// in each time control, in long games against short ones, in games that reached
// an endgame, and above all what happens when your clock runs low.
//
// The clock half is new data. A default Lichess export carries no `%clk` at
// all, and the archive that sized this plan had none until it was re-exported
// with them; 3632 of its 4126 games have them now, the rest being older than
// Lichess recording clocks.
//
// **Which entries on the clock array belong to the player is the thing most
// likely to be silently wrong here.** `clocks[i]` is the clock after ply i+1,
// so the player's own clocks are every other entry and which every-other
// depends on their colour. Getting that backwards does not throw: it reports
// the opponent's time trouble as the player's, and every number downstream
// stays plausible. So it lives in [subjectClocks], a pure function with its own
// test, rather than inside a SQL expression nobody can call directly.

const logger = require('./logger');

/// How many games with clocks one profile reads. The arrays are per ply, so
/// this is the one query here that moves real data — a bound, and a number
/// reported back rather than a silent truncation.
const CLOCK_SAMPLE = 2000;

/// Under a minute is where a blitz game stops being chess and starts being a
/// race. The buckets are in seconds of the player's own clock at move 20.
const CLOCK_BUCKETS = [
  { key: 'under-30s', max: 30 },
  { key: '30-60s', max: 60 },
  { key: '60-120s', max: 120 },
  { key: 'over-120s', max: Infinity },
];

/// The move the clock is read at: 20, which in a 3+2 game is about where the
/// opening is over and the clock starts deciding things.
const CLOCK_AT_MOVE = 20;

/// A move played in under this many seconds, once the opening is over, counts
/// as hurried.
const HURRIED_SECONDS = 3;

/// The increment, in seconds, from a `TimeControl` header like `180+2`.
///
/// Needed because the clock is not a stopwatch: in a 3+2 game a move played in
/// one second leaves the clock **higher** than it was. Time spent is
/// `before - after + increment`, and forgetting the increment does not produce
/// an error — it produces a plausible number that says a 3+2 player never
/// hurries and a 3+0 player always does.
function incrementOf(timeControl) {
  const match = /^(\d+)\+(\d+)$/.exec(String(timeControl || '').trim());
  return match ? Number(match[2]) : 0;
}

/// The player's own clock readings, in seconds, in move order.
///
/// `clocks[i]` is the clock after ply i+1. White moves on odd plies, so White's
/// readings are the even indices and Black's are the odd ones. Reversing this
/// does not throw — it silently reports the opponent's time trouble as the
/// player's — which is why it is a function with a test and not an expression.
function subjectClocks(clocks, color) {
  if (!Array.isArray(clocks)) return [];
  const first = color === 'w' ? 0 : 1;
  const out = [];
  for (let i = first; i < clocks.length; i += 2) {
    const centiseconds = clocks[i];
    out.push(centiseconds === null || centiseconds === undefined
      ? null
      : centiseconds / 100);
  }
  return out;
}

/// The player's clock, in seconds, after their own Nth move — or null if the
/// game did not last that long or carried no reading there.
///
/// Built on [subjectClocks] rather than indexing the raw array again, so the
/// parity rule has exactly one definition. Two expressions of it is how one of
/// them ends up describing the opponent.
function clockAfterMove(clocks, color, moveNumber) {
  const mine = subjectClocks(clocks, color);
  const reading = mine[moveNumber - 1];
  return reading === undefined ? null : reading;
}

function bucketFor(seconds) {
  return CLOCK_BUCKETS.find((b) => seconds < b.max) || CLOCK_BUCKETS[CLOCK_BUCKETS.length - 1];
}

function emptyBucket(key) {
  return { key, games: 0, points: 0 };
}

function withScore(bucket) {
  return {
    ...bucket,
    score: bucket.games > 0 ? bucket.points / bucket.games : null,
  };
}

/// Everything that is one GROUP BY over the archive.
async function shape(pool, userId, subject) {
  const params = [userId, subject];
  const grouped = (expression, extra = '') => pool.query(
    `SELECT ${expression} AS key,
            COUNT(*)::int AS games,
            SUM(subject_score)::numeric AS points
            ${extra}
       FROM user_games
      WHERE user_id = $1 AND subject = $2
      GROUP BY 1 ORDER BY 2 DESC`,
    params,
  );

  const [color, speed, termination, length, phase, year, opening] = await Promise.all([
    grouped('subject_color'),
    grouped("COALESCE(speed, 'nepoznato')"),
    grouped("COALESCE(termination, 'nepoznato')"),
    grouped(`CASE WHEN ply_count < 40 THEN 'do 20. poteza'
                  WHEN ply_count < 80 THEN '20-40. potez'
                  ELSE 'preko 40. poteza' END`),
    // min_men is written at import for exactly this kind of question: it is the
    // fewest men the game ever had, so it says which phase the game reached
    // without replaying a single move.
    grouped(`CASE WHEN min_men <= 7 THEN 'stigla do tablica'
                  WHEN min_men <= 10 THEN 'stigla u završnicu'
                  ELSE 'rešena pre završnice' END`),
    grouped("to_char(played_at, 'YYYY')", ', AVG(subject_elo)::int AS avg_elo'),
    pool.query(
      `SELECT COALESCE(eco, '?') || ' ' || COALESCE(opening, 'bez imena') AS key,
              COUNT(*)::int AS games, SUM(subject_score)::numeric AS points
         FROM user_games
        WHERE user_id = $1 AND subject = $2 AND opening IS NOT NULL
        GROUP BY 1 HAVING COUNT(*) >= 10 ORDER BY 2 DESC LIMIT 25`,
      params,
    ),
  ]);

  const rows = (result) => result.rows.map((row) => ({
    key: row.key,
    games: row.games,
    score: Number(row.points) / row.games,
    ...(row.avg_elo === undefined ? {} : { avgElo: row.avg_elo }),
  }));

  return {
    byColor: rows(color),
    bySpeed: rows(speed),
    byTermination: rows(termination),
    byLength: rows(length),
    byPhase: rows(phase),
    byYear: rows(year).sort((a, b) => String(a.key).localeCompare(String(b.key))),
    byOpening: rows(opening),
  };
}

/// What the clock does to this player.
///
/// Read in JavaScript rather than SQL because the parity above is the part that
/// can be wrong without anything failing, and a pure function can be tested
/// where a subscript expression inside a lateral join cannot.
async function clockProfile(pool, userId, subject, { sample = CLOCK_SAMPLE } = {}) {
  const { rows } = await pool.query(
    `SELECT subject_color, subject_score, clocks, ply_count, termination,
            time_control
       FROM user_games
      WHERE user_id = $1 AND subject = $2 AND clocks IS NOT NULL
      ORDER BY played_at DESC NULLS LAST
      LIMIT $3`,
    [userId, subject, sample],
  );

  const buckets = new Map(CLOCK_BUCKETS.map((b) => [b.key, emptyBucket(b.key)]));
  let reachedMove20 = 0;
  let hurriedMoves = 0;
  let subjectMoves = 0;
  let lostOnTime = 0;

  for (const row of rows) {
    const score = Number(row.subject_score);
    if (row.termination === 'Time forfeit' && score === 0) lostOnTime += 1;

    const mine = subjectClocks(row.clocks, row.subject_color);
    const increment = incrementOf(row.time_control);
    // Hurried moves are counted after the opening only: the first ten moves of
    // a prepared line are meant to be fast, and counting them would make every
    // player look rushed.
    for (let move = 10; move < mine.length; move += 1) {
      const before = mine[move - 1];
      const after = mine[move];
      if (before === null || after === null) continue;
      subjectMoves += 1;
      if (before - after + increment < HURRIED_SECONDS) hurriedMoves += 1;
    }

    const atMove20 = clockAfterMove(row.clocks, row.subject_color, CLOCK_AT_MOVE);
    if (atMove20 === null) continue;
    reachedMove20 += 1;
    const bucket = buckets.get(bucketFor(atMove20).key);
    bucket.games += 1;
    bucket.points += score;
  }

  return {
    sampled: rows.length,
    reachedMove20,
    lostOnTime,
    hurriedShare: subjectMoves > 0 ? hurriedMoves / subjectMoves : null,
    atMove20: CLOCK_BUCKETS.map((b) => withScore(buckets.get(b.key))),
  };
}

async function playerProfile(pool, userId, { subject, clockSample } = {}) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  const handle = String(subject || '').trim();
  if (!handle) throw new RangeError('Nedostaje korisničko ime.');

  const [totals, shaped, clock] = await Promise.all([
    pool.query(
      `SELECT COUNT(*)::int AS games, SUM(subject_score)::numeric AS points,
              MIN(played_at) AS oldest, MAX(played_at) AS newest,
              COUNT(*) FILTER (WHERE clocks IS NOT NULL)::int AS with_clocks
         FROM user_games WHERE user_id = $1 AND subject = $2`,
      [userId, handle],
    ),
    shape(pool, userId, handle),
    clockProfile(pool, userId, handle, clockSample ? { sample: clockSample } : {}),
  ]);

  const row = totals.rows[0] || { games: 0, points: 0 };
  logger.info(`[PROFIL] ${handle}: ${row.games} partija.`);

  return {
    subject: handle,
    games: row.games,
    score: row.games > 0 ? Number(row.points) / row.games : null,
    oldest: row.oldest,
    newest: row.newest,
    gamesWithClocks: row.with_clocks,
    ...shaped,
    clock,
  };
}

module.exports = {
  playerProfile,
  clockProfile,
  subjectClocks,
  clockAfterMove,
  incrementOf,
  CLOCK_BUCKETS,
  CLOCK_AT_MOVE,
  CLOCK_SAMPLE,
  HURRIED_SECONDS,
};
