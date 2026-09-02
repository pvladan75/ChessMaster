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
const {
  fenKey, requireColor, DEFAULT_BREADTH,
} = require('./repertoireService');
// The walk's own "advance one move", not a second copy of it: the opponent's
// reply has to be played out to know which position it lands on, and that is
// the same reading of a stored UCI the frontier already does. `withinBreadth`
// is there for the same reason — the live opponent and the walk have to draw
// from the same set, and they have disagreed before.
const { step, withinBreadth } = require('./repertoireFrontier');
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

/// How many successful repetitions make a position "known".
///
/// One number, used twice and for the same reason: it is what the empty screen
/// counts as known, and it is where the line drill starts its replay. A line
/// rehearsed from move one every time is a line nobody rehearses twice, so the
/// replay begins at the deepest position that has got this far.
const KNOWN_REPETITIONS = 3;

/// The next position to be asked about, or null when nothing is waiting.
///
/// Due reviews first, oldest first, so a backlog is worked off in the order it
/// built up. Then positions never drilled at all — and among those, the ones
/// where the student's first instinct was wrong, because those are what the
/// attempts table was written for.
///
/// `only` narrows the choice to a set of positions and is how one branch gets
/// drilled on its own: the ordering rule stays here, in one place, rather than
/// being written a second time by whoever wants a subset of it. Null means the
/// whole colour, which is what it has always meant.
///
/// `ahead` drops the "is it due yet" condition and takes the position that is
/// due soonest. A branch of three positions all scheduled for tomorrow is a
/// branch nobody can practise today, and "come back tomorrow" is the wrong
/// answer to somebody who has just built it and wants to run it once. What
/// makes it safe is at the other end: an answer given ahead of schedule is not
/// written down, so practising early cannot inflate an interval.
async function nextItem(pool, userId, {
  color, now = new Date(), only = null, ahead = false,
} = {}) {
  const within = Array.isArray(only) ? only : null;
  if (within !== null && within.length === 0) return null;

  const due = await pool.query(
    `SELECT r.fen_key, r.due_at, r.repetitions, r.interval_days
       FROM repertoire_reviews r
      WHERE r.user_id = $1 AND r.color = $2
        AND ($5 = TRUE OR r.due_at <= $3)
        AND ($4::text[] IS NULL OR r.fen_key = ANY($4))
        AND EXISTS (
          SELECT 1 FROM repertoire_moves m
           WHERE m.user_id = r.user_id AND m.color = r.color
             AND m.fen_key = r.fen_key AND m.role = 'primary'
             AND m.source = 'chosen'
        )
      ORDER BY r.due_at ASC
      LIMIT 1`,
    [userId, color, now, within, ahead],
  );
  // Only when something is genuinely due. Running ahead, a position that has
  // never been drilled at all still comes first: it is the one thing that is
  // not practice but real, and burying it under an early repetition would be
  // the wrong order.
  if (due.rowCount > 0 && (!ahead || Number(due.rows[0].repetitions) === 0)) {
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
        AND m.source = 'chosen'
        AND ($3::text[] IS NULL OR m.fen_key = ANY($3))
        AND NOT EXISTS (
          SELECT 1 FROM repertoire_reviews r
           WHERE r.user_id = m.user_id AND r.color = m.color
             AND r.fen_key = m.fen_key
        )
      ORDER BY mistakes DESC, m.added_at ASC
      LIMIT 1`,
    [userId, color, within],
  );
  if (fresh.rowCount === 0) {
    if (due.rowCount > 0) {
      return itemFrom(pool, userId, color, due.rows[0].fen_key, {
        fresh: false,
        repetitions: Number(due.rows[0].repetitions),
      });
    }
    return null;
  }

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
      WHERE user_id = $1 AND color = $2 AND fen_key = $3
        AND source = 'chosen'`,
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
///
/// `practice` judges without writing anything down. It is what an answer given
/// ahead of schedule is: the same rule the line drill's rehearsal already
/// keeps, for the same reason — a position run through five times in an evening
/// because somebody enjoyed themselves must not come back in a month on the
/// strength of it. Told apart on the way out by `intervalDays: null`, so the
/// screen cannot accidentally promise a return date nobody stored.
/// `onlyIfDue` keeps the same rule for a line that is walked on past its
/// question. The drill asks one position and then carries on down the line, and
/// the positions below it were not what the schedule asked for — grading them
/// would push their intervals out on the strength of moves nobody had to
/// remember cold. It is the sparring rule (`dueKeys`) said once more, here
/// rather than in the client, because `due_at` is the server's to read.
///
/// A position never reviewed at all **is** due: it is the most overdue thing
/// there is, and walking into one is exactly when it should be written down.
async function answer(pool, userId, {
  color, fen, uci, revealed = false, practice = false, onlyIfDue = false,
  now = new Date(),
}) {
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Potez nije prosleđen.');

  // Only what the student chose. A position holding nothing but generated
  // moves has no answer to be right or wrong about, and saying so is the
  // honest outcome — the screen turns it into an offer to confirm the line.
  const moves = await pool.query(
    `SELECT uci, san, role FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3
        AND source = 'chosen'`,
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

  const judged = () => ({
    outcome,
    quality,
    practice: true,
    primary: primary ? { uci: primary.uci, san: primary.san } : null,
    alternates: alternates.map((m) => ({ uci: m.uci, san: m.san })),
    intervalDays: null,
    dueAt: null,
  });

  if (practice) return judged();

  if (onlyIfDue) {
    const review = await pool.query(
      `SELECT due_at FROM repertoire_reviews
        WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
      [userId, color, key],
    );
    const due = review.rowCount === 0
      || new Date(review.rows[0].due_at) <= now;
    if (!due) return judged();
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
        AND source = 'chosen'
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
/// repertoire.
///
/// **A reply has to pass three conditions, not one.** The book has to say the
/// move is played here; the student must not have *cut* the position it leads
/// to; and they must have decided something there. Only the first was checked,
/// and the other two were missing in the same way — the line walk had refused
/// to go into a cut branch or past the end of the preparation for months
/// (`repertoire_skips`, `coveredReplies`), while the live opponent walked
/// straight into both. One of the two was wrong, and it was not the walk.
///
/// Cut is the plainer of the two: a branch the student deleted is a decision,
/// and answering them with it asks them to remember the thing they decided by
/// deleting.
///
/// "Decided something there" is `source = 'chosen'` — which is `answer()`'s own
/// definition of prepared, and that is the point of using it rather than a
/// condition of this function's own. The reply can then never land on a
/// position that the very next call would grade `unprepared`, so the spar ends
/// on "the branch is played out" instead of on a question with no answer
/// behind it. `role` is deliberately not part of it: a position whose only
/// decision is an alternate still has an answer that `answer()` grades.
///
/// **Prepared** still means covered *or* pressed "prepare this too" on. That is
/// per student, and so are both new conditions — which is why a call that does
/// not say who is asking is refused outright rather than answered with null.
/// Null is what the end of the book looks like, and a missing caller must not
/// be able to counterfeit it.
///
/// `breadth` is the repertoire's, and it has to reach here for the same reason
/// the two conditions above do: the walk follows what the breadth says, and an
/// opponent drawing from a narrower set than the walk would refuse to spar into
/// a position the student built. Read through `withinBreadth`, the one place
/// that rule is written.
///
/// All three are computed in SQL and filtered in JS on purpose. The rule is
/// then one expression that can be read, and a test can put a cut position or
/// an undecided one in front of it against rows — a guard written into a WHERE
/// clause is a guard no stub pool can disprove by mutation.
async function pickReply(pool, {
  fen, minRating = 0, userId = null, color = null, breadth = DEFAULT_BREADTH,
  random = Math.random,
}) {
  const key = fenKey(fen);
  requireColor(color);
  if (userId === null || userId === undefined) {
    throw new RangeError('Korisnik nije prosleđen.');
  }
  const rows = await pool.query(
    `SELECT r.uci, r.san, r.games, r.share, r.covered,
            EXISTS (
              SELECT 1 FROM repertoire_extra_replies e
               WHERE e.user_id = $3 AND e.color = $4
                 AND e.fen_key = r.fen_key AND e.uci = r.uci) AS asked
       FROM opening_replies r
      WHERE r.fen_key = $1 AND r.min_rating = $2
      ORDER BY r.games DESC`,
    [key, minRating ?? 0, userId, color],
  );
  // The games count is dropped by `withinBreadth`, which answers what the walk
  // needs, and the draw is weighted by games — so the rows are matched back up
  // by uci rather than re-queried.
  const followed = new Set(
    withinBreadth(rows.rows, breadth).map((reply) => reply.uci));
  const covered = rows.rows.filter((row) => followed.has(row.uci));
  if (covered.length === 0) return null;

  // Where each reply lands. A stored move that no longer fits the position is
  // a broken book row rather than a broken request, so it is dropped and the
  // rest of the draw is still worth having — the same reading `step` answers
  // null for in the walk.
  const landing = new Map();
  for (const row of covered) {
    const after = step(fen, row.uci);
    if (after !== null) landing.set(row.uci, fenKey(after.fen));
  }
  const keys = [...new Set(landing.values())];
  if (keys.length === 0) return null;

  const state = await pool.query(
    `SELECT k.fen_key,
            EXISTS (
              SELECT 1 FROM repertoire_moves m
               WHERE m.user_id = $1 AND m.color = $2
                 AND m.fen_key = k.fen_key AND m.source = 'chosen') AS decided,
            EXISTS (
              SELECT 1 FROM repertoire_skips s
               WHERE s.user_id = $1 AND s.color = $2
                 AND s.fen_key = k.fen_key) AS cut
       FROM UNNEST($3::text[]) AS k(fen_key)`,
    [userId, color, keys],
  );
  const decided = new Set();
  const cut = new Set();
  for (const row of state.rows) {
    if (row.decided === true) decided.add(row.fen_key);
    if (row.cut === true) cut.add(row.fen_key);
  }

  const usable = covered.filter((row) => {
    const landed = landing.get(row.uci);
    if (landed === undefined) return false;
    if (cut.has(landed)) return false;
    return decided.has(landed);
  });
  // Nothing left to play, so the line ends here. That is what a book running
  // out looks like, and the screen already reads it as "grana odigrana do
  // kraja" rather than as a failure.
  if (usable.length === 0) return null;

  const total = usable.reduce((sum, row) => sum + Number(row.games), 0);
  if (total <= 0) return null;

  let ticket = random() * total;
  for (const row of usable) {
    ticket -= Number(row.games);
    if (ticket < 0) {
      return { uci: row.uci, san: row.san, covered: true };
    }
  }
  const last = usable[usable.length - 1];
  return { uci: last.uci, san: last.san, covered: true };
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
///
/// `only` narrows it to a branch, the same way `nextItem` narrows its choice —
/// so "4 od 11 u ovoj grani" is counted by the same query that counts the whole
/// colour, rather than by a second one written beside it.
async function drillStats(pool, userId, { color, now = new Date(), only = null } = {}) {
  const within = Array.isArray(only) ? only : null;
  if (within !== null && within.length === 0) {
    return { positions: 0, due: 0, known: 0, fresh: 0, nextDueAt: null };
  }
  const result = await pool.query(
    `SELECT
       (SELECT COUNT(*)::int FROM repertoire_moves
         WHERE user_id = $1 AND color = $2 AND role = 'primary'
           AND source = 'chosen'
           AND ($4::text[] IS NULL OR fen_key = ANY($4))) AS positions,
       (SELECT COUNT(*)::int FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2
           AND ($4::text[] IS NULL OR fen_key = ANY($4))) AS seen,
       (SELECT COUNT(*)::int FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2 AND due_at <= $3
           AND ($4::text[] IS NULL OR fen_key = ANY($4))) AS due,
       (SELECT COUNT(*)::int FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2
           AND ($4::text[] IS NULL OR fen_key = ANY($4))
           AND repetitions >= ${KNOWN_REPETITIONS}) AS known,
       (SELECT MIN(due_at) FROM repertoire_reviews
         WHERE user_id = $1 AND color = $2 AND due_at > $3
           AND ($4::text[] IS NULL OR fen_key = ANY($4))) AS next_due`,
    [userId, color, now, within],
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
    // When the soonest one comes back. "Nothing is due" without this reads as
    // "you cannot practise this", which is how the owner read it on the first
    // branch he tried: one position, drilled once, scheduled for tomorrow, and
    // a screen that said only that there was nothing there.
    nextDueAt: row.next_due ?? null,
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
  KNOWN_REPETITIONS,
};
