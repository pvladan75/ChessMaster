// spacedRepetitionService.js
// SM-2 scheduling over lesson positions.
//
// The algorithm is SuperMemo 2, the same one Anki and Chessable's MoveTrainer
// descend from. It is kept as a pure function because every mistake in it is
// invisible: a wrong interval does not throw, it just quietly stops teaching —
// either burying a position the student has forgotten, or asking them about one
// they know cold.

const logger = require('./logger');

/// How a student rates their recall, mapped to SM-2's 0–5 quality scale.
///
/// Four buttons rather than six: asking a child to distinguish six shades of
/// remembering produces noise, not data. Anything below 3 counts as a failure in
/// SM-2, which is why "again" sits at 1 and the other three sit above the line.
const GRADES = {
  again: 1,
  hard: 3,
  good: 4,
  easy: 5,
};

/// SM-2's floor. Below this the intervals collapse and an item that a student
/// genuinely finds hard would be shown several times a day forever.
const MIN_EASE = 1.3;
const DEFAULT_EASE = 2.5;

/// First two intervals are fixed by the algorithm; only from the third does the
/// ease factor start compounding.
const FIRST_INTERVAL = 1;
const SECOND_INTERVAL = 6;

function isValidGrade(quality) {
  return Number.isInteger(quality) && quality >= 0 && quality <= 5;
}

/// Computes the next schedule for one item.
///
/// Pure: takes the current state and the grade, returns the new state. `now` is
/// a parameter so the interval boundaries are testable without waiting a day.
function schedule(current, quality, now = new Date()) {
  const ease = Number(current?.ease_factor ?? DEFAULT_EASE);
  const repetitions = Number(current?.repetitions ?? 0);
  const lapses = Number(current?.lapses ?? 0);

  // SM-2's ease adjustment. Applied on every review, including failures — a
  // repeatedly forgotten item should get easier to re-encounter, not just reset.
  const delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
  const nextEase = Math.max(MIN_EASE, Math.round((ease + delta) * 100) / 100);

  let nextRepetitions;
  let intervalDays;
  let nextLapses = lapses;

  if (quality < 3) {
    // Failed. The repetition count restarts, but the ease factor carries over,
    // so an item that keeps being forgotten stays permanently more frequent.
    nextRepetitions = 0;
    intervalDays = 0; // due again in this same session
    nextLapses = lapses + 1;
  } else if (repetitions === 0) {
    nextRepetitions = 1;
    intervalDays = FIRST_INTERVAL;
  } else if (repetitions === 1) {
    nextRepetitions = 2;
    intervalDays = SECOND_INTERVAL;
  } else {
    nextRepetitions = repetitions + 1;
    const previous = Number(current?.interval_days ?? SECOND_INTERVAL);
    intervalDays = Math.max(1, Math.round(previous * nextEase));
  }

  // A failed item comes back after a short delay rather than instantly, so the
  // student is not shown the answer they just saw.
  const dueAt = new Date(
    intervalDays === 0
      ? now.getTime() + 10 * 60 * 1000
      : now.getTime() + intervalDays * 24 * 60 * 60 * 1000
  );

  return {
    easeFactor: nextEase,
    intervalDays,
    repetitions: nextRepetitions,
    lapses: nextLapses,
    dueAt,
  };
}

/// Human-readable "next review in ...", for the button that produced it.
function describeInterval(intervalDays) {
  if (intervalDays === 0) return 'za nekoliko minuta';
  if (intervalDays === 1) return 'sutra';
  if (intervalDays < 7) return `za ${intervalDays} dana`;
  if (intervalDays < 30) {
    const weeks = Math.round(intervalDays / 7);
    return weeks === 1 ? 'za nedelju dana' : `za ${weeks} nedelje`;
  }
  const months = Math.round(intervalDays / 30);
  return months === 1 ? 'za mesec dana' : `za ${months} meseca`;
}

/// Ensures a schedule row exists for a position the student has just seen.
///
/// New items are due immediately, so a step read today shows up in the first
/// review session rather than a day later.
async function ensureItem(pool, { userId, lessonId, position }) {
  const result = await pool.query(
    `INSERT INTO review_items (user_id, lesson_id, position)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, lesson_id, position) DO NOTHING
     RETURNING *`,
    [userId, lessonId, position]
  );
  if (result.rows.length > 0) return result.rows[0];

  const existing = await pool.query(
    'SELECT * FROM review_items WHERE user_id = $1 AND lesson_id = $2 AND position = $3',
    [userId, lessonId, position]
  );
  return existing.rows[0] || null;
}

/// Records a grade and writes the resulting schedule.
async function grade(pool, { userId, lessonId, position, quality }, now = new Date()) {
  if (!isValidGrade(quality)) {
    return { ok: false, reason: 'Ocena mora biti ceo broj od 0 do 5.' };
  }

  const current = await ensureItem(pool, { userId, lessonId, position });
  if (!current) {
    return { ok: false, reason: 'Stavka za ponavljanje nije pronađena.' };
  }

  const next = schedule(current, quality, now);

  const updated = await pool.query(
    `UPDATE review_items
     SET ease_factor = $1, interval_days = $2, repetitions = $3, lapses = $4,
         due_at = $5, last_reviewed_at = CURRENT_TIMESTAMP
     WHERE id = $6
     RETURNING *`,
    [next.easeFactor, next.intervalDays, next.repetitions, next.lapses, next.dueAt, current.id]
  );

  logger.info(
    { userId, lessonId, position, quality, intervalDays: next.intervalDays },
    'Review graded'
  );

  return {
    ok: true,
    item: updated.rows[0],
    intervalDays: next.intervalDays,
    dueAt: next.dueAt,
    description: describeInterval(next.intervalDays),
  };
}

/// Everything due now, with the board position each one refers to.
///
/// Oldest-due first so a backlog is worked off in the order it built up.
async function getDue(pool, userId, { limit = 30, now = new Date() } = {}) {
  const result = await pool.query(
    `SELECT r.id, r.lesson_id, r.position, r.interval_days, r.repetitions, r.due_at,
            l.title AS lesson_title, l.fen AS lesson_fen, l.pgn AS lesson_pgn,
            l.position_list
     FROM review_items r
     JOIN saved_lessons l ON l.id = r.lesson_id
     WHERE r.user_id = $1 AND r.due_at <= $2
     ORDER BY r.due_at ASC
     LIMIT $3`,
    [userId, now, Math.min(Math.max(limit, 1), 100)]
  );

  return result.rows.map((row) => {
    const raw = row.position_list;
    const list = Array.isArray(raw) ? raw : (typeof raw === 'string' ? JSON.parse(raw) : null);
    const steps = list && list.length > 0
      ? list
      : [{ title: row.lesson_title, fen: row.lesson_fen, pgn: row.lesson_pgn }];

    // A lesson edited down to fewer steps can leave a schedule row pointing past
    // the end; such rows are surfaced as null and skipped by the caller rather
    // than crashing the whole review session.
    const step = steps[row.position] || null;

    return {
      id: row.id,
      lessonId: row.lesson_id,
      position: row.position,
      lessonTitle: row.lesson_title,
      intervalDays: row.interval_days,
      repetitions: row.repetitions,
      dueAt: row.due_at,
      step,
    };
  }).filter((item) => item.step !== null);
}

/// Counts for the badge on the home screen.
async function getStats(pool, userId, now = new Date()) {
  const result = await pool.query(
    `SELECT
       COUNT(*)::int AS total,
       COUNT(*) FILTER (WHERE due_at <= $2)::int AS due,
       COUNT(*) FILTER (WHERE repetitions >= 3)::int AS mature
     FROM review_items WHERE user_id = $1`,
    [userId, now]
  );
  return result.rows[0] || { total: 0, due: 0, mature: 0 };
}

module.exports = {
  GRADES,
  MIN_EASE,
  DEFAULT_EASE,
  isValidGrade,
  schedule,
  describeInterval,
  ensureItem,
  grade,
  getDue,
  getStats,
};
