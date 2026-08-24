// repertoireDrillService.js — asking a student what they decided to play, and
// remembering how well they knew it.
//
// **The algorithm is not repeated here.** Scheduling goes through `schedule()`
// in spacedRepetitionService, the same SM-2 that homework uses; only the
// storage is this file's, because a lesson item is (lesson, step) read by
// joining a lesson while a repertoire item is (colour, position) that joins
// nothing.
//
// **A drill costs nothing.** No Lichess request is made here at any point: what
// the opponent plays comes from `opening_replies`, filled when the student
// built the position and shared by everyone afterwards. A student without a
// token of their own can still drill what they built last week, and a student
// with one is not spending it to be asked questions.
//
// **The student is not asked to grade themselves.** In a drill the answer is
// objective - it is their own decision, written down - so the quality is
// derived: recalled outright is a pass, recalled after looking is a weaker
// pass, and anything else is a failure. Asking a child "how well did you know
// that?" produces noise, which is the same reason the four buttons exist
// instead of six.

const { schedule, GRADES } = require('./spacedRepetitionService');
const { fenKey } = require('./repertoireService');
const logger = require('./logger');

/// How an answer is scored, before SM-2 sees it.
const QUALITY = {
  /// The primary move, straight away.
  recalled: GRADES.good,
  /// One of their own alternates - they know the position, not the choice.
  alternate: GRADES.good,
  /// Right, but only after the answer was shown.
  revealed: GRADES.hard,
  /// Anything else, including a move that is perfectly good chess but is not
  /// what this student decided to play. The drill asks about a decision.
  missed: GRADES.again,
};

const OUTCOMES = ['primary', 'alternate', 'unknown'];

/// The next position to be asked about, or null when nothing is waiting.
///
/// Due reviews first, oldest first, so a backlog is worked off in the order it
/// built up. Then positions never drilled at all — and among those, the ones
/// where the student's first instinct was wrong, because those are what the
/// attempts table was written for.
async function nextItem(pool, userId, { color, now = new Date() } = {}) {
  const due = await pool.query(
    `SELECT r.fen_key, r.due_at, r.repetitions, r.interval_days
       FROM repertoire_reviews r
      WHERE r.user_id = $1 AND r.color = $2 AND r.due_at <= $3
        AND EXISTS (
          SELECT 1 FROM repertoire_moves m
           WHERE m.user_id = r.user_id AND m.color = r.color
             AND m.fen_key = r.fen_key AND m.role = 'primary'
        )
      ORDER BY r.due_at ASC
      LIMIT 1`,
    [userId, color, now],
  );
  if (due.rowCount > 0) {
    return itemFrom(pool, userId, color, due.rows[0].fen_key, {
      fresh: false,
      repetitions: Number(due.rows[0].repetitions),
    });
  }

  const fresh = await pool.query(
    `SELECT m.fen_key,
            COALESCE(a.mistakes, 0) AS mistakes
       FROM repertoire_moves m
       LEFT JOIN (
         SELECT fen_key,
                COUNT(*) FILTER (WHERE verdict = 'mistake' OR looked_up) AS mistakes
           FROM repertoire_attempts
          WHERE user_id = $1 AND color = $2
          GROUP BY fen_key
       ) a ON a.fen_key = m.fen_key
      WHERE m.user_id = $1 AND m.color = $2 AND m.role = 'primary'
        AND NOT EXISTS (
          SELECT 1 FROM repertoire_reviews r
           WHERE r.user_id = m.user_id AND r.color = m.color
             AND r.fen_key = m.fen_key
        )
      ORDER BY mistakes DESC, m.added_at ASC
      LIMIT 1`,
    [userId, color],
  );
  if (fresh.rowCount === 0) return null;

  return itemFrom(pool, userId, color, fresh.rows[0].fen_key, {
    fresh: true,
    repetitions: 0,
  });
}

/// One item, with everything the screen needs and nothing it should be told.
///
/// The moves are deliberately *not* sent: this is a question, and a question
/// that arrives with its answer attached is one a determined child will read
/// out of the network log rather than out of their memory.
async function itemFrom(pool, userId, color, key, { fresh, repetitions }) {
  const counts = await pool.query(
    `SELECT COUNT(*)::int AS moves
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
    [userId, color, key],
  );
  return {
    fenKey: key,
    // A board needs six fields; a repertoire keeps four, because the move
    // counters are exactly what must not distinguish two identical positions.
    // They are filled back in here with the only values that mean "no claim":
    // nothing captured yet, move one.
    fen: `${key} 0 1`,
    color,
    fresh,
    repetitions,
    moves: counts.rows[0]?.moves ?? 0,
  };
}

/// Judges one answer against what the student decided, and reschedules.
///
/// `revealed` says the answer was shown first. It is the difference between
/// remembering and recognising, and SM-2 has a grade for each.
async function answer(pool, userId, {
  color, fen, uci, revealed = false, now = new Date(),
}) {
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Potez nije prosleđen.');

  const moves = await pool.query(
    `SELECT uci, san, role FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
    [userId, color, key],
  );
  if (moves.rowCount === 0) {
    // Nothing decided here yet, so there is nothing to be right or wrong about.
    // Saying so is not a failure to grade - it is the honest answer, and the
    // screen turns it into an offer to build the position instead.
    return { outcome: 'unprepared', primary: null, alternates: [] };
  }

  const primary = moves.rows.find((m) => m.role === 'primary') ?? null;
  const alternates = moves.rows.filter((m) => m.role !== 'primary');
  const played = moves.rows.find((m) => m.uci === uci) ?? null;

  const outcome = played === null
    ? 'unknown'
    : (played.role === 'primary' ? 'primary' : 'alternate');

  let quality;
  if (outcome === 'unknown') {
    quality = QUALITY.missed;
  } else if (revealed) {
    quality = QUALITY.revealed;
  } else {
    quality = outcome === 'primary' ? QUALITY.recalled : QUALITY.alternate;
  }

  const current = await ensureReview(pool, userId, color, key);
  const next = schedule(current, quality, now);
  await pool.query(
    `UPDATE repertoire_reviews
        SET ease_factor = $1, interval_days = $2, repetitions = $3, lapses = $4,
            due_at = $5, last_reviewed_at = CURRENT_TIMESTAMP
      WHERE id = $6`,
    [next.easeFactor, next.intervalDays, next.repetitions, next.lapses,
      next.dueAt, current.id],
  );

  logger.info(
    { userId, color, outcome, quality, intervalDays: next.intervalDays },
    'Repertoire drill graded',
  );

  return {
    outcome,
    quality,
    primary: primary ? { uci: primary.uci, san: primary.san } : null,
    alternates: alternates.map((m) => ({ uci: m.uci, san: m.san })),
    intervalDays: next.intervalDays,
    dueAt: next.dueAt,
  };
}

/// The answer, when the student asks to be shown it.
///
/// A separate call on purpose. The question itself never carries its answer, so
/// looking is an act rather than a thing that quietly happened — and the next
/// answer is then graded as recognised rather than remembered.
async function revealPrimary(pool, userId, { color, fen }) {
  const key = fenKey(fen);
  const result = await pool.query(
    `SELECT uci, san, role FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3
      ORDER BY (role = 'primary') DESC, added_at ASC`,
    [userId, color, key],
  );
  const primary = result.rows.find((m) => m.role === 'primary') ?? null;
  return {
    primary: primary ? { uci: primary.uci, san: primary.san } : null,
    alternates: result.rows
      .filter((m) => m.role !== 'primary')
      .map((m) => ({ uci: m.uci, san: m.san })),
  };
}

async function ensureReview(pool, userId, color, key) {
  const inserted = await pool.query(
    `INSERT INTO repertoire_reviews (user_id, color, fen_key)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, color, fen_key) DO NOTHING
     RETURNING *`,
    [userId, color, key],
  );
  if (inserted.rowCount > 0) return inserted.rows[0];

  const existing = await pool.query(
    `SELECT * FROM repertoire_reviews
      WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
    [userId, color, key],
  );
  return existing.rows[0];
}

/// What the opponent plays next, drawn by how often it is really played.
///
/// Weighted rather than "the most common every time", because a drill that
/// always answers with the main move rehearses one line and calls it a
/// repertoire. The uncovered moves are in the draw on purpose: meeting one is
/// not a failure of the drill, it is the drill doing the one thing a book
/// cannot - showing the student the edge of what they prepared.
async function pickReply(pool, { fen, minRating = 0, random = Math.random }) {
  const key = fenKey(fen);
  const rows = await pool.query(
    `SELECT uci, san, games, covered FROM opening_replies
      WHERE fen_key = $1 AND min_rating = $2
      ORDER BY games DESC`,
    [key, minRating ?? 0],
  );
  if (rows.rowCount === 0) return null;

  const total = rows.rows.reduce((sum, row) => sum + Number(row.games), 0);
  if (total <= 0) return null;

  let ticket = random() * total;
  for (const row of rows.rows) {
    ticket -= Number(row.games);
    if (ticket < 0) {
      return { uci: row.uci, san: row.san, covered: row.covered };
    }
  }
  const last = rows.rows[rows.rows.length - 1];
  return { uci: last.uci, san: last.san, covered: last.covered };
}

/// Stores the book for a position, so the drill never has to ask Lichess.
///
/// Called with whatever the explorer returned, covered moves and all. Rows are
/// replaced rather than added to: a position's book is one fact, and two
/// half-updated copies of it would be worse than a stale one.
async function rememberReplies(pool, { fen, minRating = 0, moves }) {
  if (!Array.isArray(moves) || moves.length === 0) return 0;
  const key = fenKey(fen);
  const band = minRating ?? 0;

  const values = [];
  const params = [key, band];
  for (const move of moves) {
    const at = params.length;
    params.push(move.uci, move.san, move.games ?? 0, move.share ?? 0,
      move.covered === true);
    values.push(`($1, $2, $${at + 1}, $${at + 2}, $${at + 3}, $${at + 4}, $${at + 5})`);
  }

  // Replaced, not merged. A position's book is one fact, and merging leaves
  // yesterday's rows beside today's — which is not theoretical: castling used
  // to be stored in Lichess's own notation, and an upsert would have left those
  // unplayable rows in the draw forever, next to the corrected ones.
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'DELETE FROM opening_replies WHERE fen_key = $1 AND min_rating = $2',
      [key, band],
    );
    await client.query(
      `INSERT INTO opening_replies (fen_key, min_rating, uci, san, games, share, covered)
       VALUES ${values.join(', ')}`,
      params,
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
  return moves.length;
}

/// How much is waiting, for the badge and for "ništa nije na redu".
async function drillStats(pool, userId, { color, now = new Date() } = {}) {
  const result = await pool.query(
    `SELECT
       (SELECT COUNT(*)::int FROM repertoire_moves
         WHERE user_id = $1 AND color = $2 AND role = 'primary') AS positions,
       (SELECT COUNT(*)::int FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2) AS seen,
       (SELECT COUNT(*)::int FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2 AND due_at <= $3) AS due,
       (SELECT COUNT(*)::int FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2 AND repetitions >= 3) AS known`,
    [userId, color, now],
  );
  const row = result.rows[0] ?? {};
  const positions = row.positions ?? 0;
  return {
    positions,
    due: row.due ?? 0,
    known: row.known ?? 0,
    // Never drilled at all. Counted rather than inferred on screen, because
    // "nothing is due" and "nothing was ever built" are two different empty
    // states and only one of them is good news.
    fresh: Math.max(0, positions - (row.seen ?? 0)),
  };
}

module.exports = {
  nextItem,
  revealPrimary,
  answer,
  pickReply,
  rememberReplies,
  drillStats,
  QUALITY,
  OUTCOMES,
};
