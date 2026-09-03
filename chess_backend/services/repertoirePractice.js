// repertoirePractice.js — what was actually practised, and when.
//
// Phase 3 of `docs/PLAN-JEDNOSTAVNOST.md`. The owner's complaint is about
// rhythm: *„mora da se natera korisnik da češće vežba, ne da čeka po 6 dana da
// ponovo odigra neku liniju"*. SM-2 is right about retention and says nothing
// about habit — after two good answers a position is six days away, and a child
// in their first week opens the app to be told there is nothing to do.
//
// The answer is not to shorten the intervals. It is to let somebody practise
// anyway — which the drill has always allowed, unscored — and then to **count
// it**, because a target that ignores the practice it asked for is worse than
// no target.
//
// Two rules this file exists to keep apart:
//
//   * **Nothing here decides what is due.** `repertoire_reviews` is still the
//     only thing that schedules, and an answer given ahead of schedule still
//     writes nothing to it. This is a record of work done, not of knowledge.
//   * **A day is the reader's day, not the server's.** The caller sends the
//     instant its own day started; a server counting in UTC would tell a child
//     in Belgrade at 01:00 that they had already practised tomorrow.
const logger = require('./logger');
const { requireColor } = require('./repertoireService');

/// How far back a caller may ask. A week is generous for "today" and stops a
/// bad clock or a hand-written query from scanning the whole table.
const MAX_WINDOW_DAYS = 7;

/// Writes one answer down, and can never break the answer.
///
/// Called after the judging and the scheduling, never before — the drill's
/// oldest rule, paid for twice: a message must not be able to take down the
/// action it reports on. A log that cannot be written is a log line, not a
/// failed answer, so this swallows everything and says so.
async function logAnswer(pool, userId, { color, fenKey, scored, outcome }) {
  try {
    await pool.query(
      `INSERT INTO repertoire_practice_log
         (user_id, color, fen_key, scored, outcome)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, color, fenKey, scored === true, outcome ?? 'unknown'],
    );
  } catch (err) {
    logger.warn(
      { err: err.message, userId, color },
      'Practice log not written; the answer itself stands',
    );
  }
}

/// What this student has practised since [since].
///
/// `positions` is the number the target is read against: distinct positions,
/// so answering the same board four times is one position practised and not
/// four. `answers` is every answer given, which is the honest second number
/// when somebody wants to know why the first one stopped moving.
///
/// `scored` and `practice` split the same answers by whether the schedule was
/// told. Both are work; only one moves a due date, and a screen that adds them
/// into one number would be saying the second kind counts for repetition —
/// which is exactly the thing early practice is not.
async function practisedSince(pool, userId, { since, color = null } = {}) {
  const from = new Date(since);
  if (Number.isNaN(from.getTime())) {
    throw new RangeError('Početak dana nije ispravan datum.');
  }
  const oldest = new Date(Date.now() - MAX_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  if (from < oldest) {
    throw new RangeError(`Može se tražiti najviše ${MAX_WINDOW_DAYS} dana unazad.`);
  }
  if (color !== null) requireColor(color);

  const result = await pool.query(
    `SELECT COUNT(DISTINCT fen_key)::int AS positions,
            COUNT(*)::int                AS answers,
            COUNT(*) FILTER (WHERE scored)::int     AS scored,
            COUNT(*) FILTER (WHERE NOT scored)::int AS practice
       FROM repertoire_practice_log
      WHERE user_id = $1
        AND answered_at >= $2
        AND ($3::char(1) IS NULL OR color = $3)`,
    [userId, from.toISOString(), color],
  );

  const row = result.rows[0] ?? {};
  return {
    positions: Number(row.positions ?? 0),
    answers: Number(row.answers ?? 0),
    scored: Number(row.scored ?? 0),
    practice: Number(row.practice ?? 0),
    since: from.toISOString(),
  };
}

module.exports = { logAnswer, practisedSince, MAX_WINDOW_DAYS };
