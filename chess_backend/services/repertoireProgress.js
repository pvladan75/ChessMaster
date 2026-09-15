// repertoireProgress.js — how much of each repertoire is still unanswered.
//
// One number per repertoire, for the screen somebody opens first: positions
// after an opponent move the student entered, where they have no move yet.
//
// It is a walk per repertoire and there is no cheaper honest version, so the
// list draws immediately from `list()` and fills these in when they arrive, a
// few at a time rather than all at once.
const { frontier } = require('./repertoireFrontier');

/// How many walks run at once, and how many repertoires are walked at all.
///
/// Both caps exist for the same reason: an account with forty repertoires would
/// otherwise open forty walks on one request, and the screen that started them
/// has room for a number, not for a reason to wait.
const CONCURRENCY = 4;
const MAX_ROWS = 40;

/// The unanswered count for every repertoire the caller owns.
///
/// A repertoire whose walk throws is reported with nulls rather than zeros. A
/// zero here means "nothing left", and a walk that could not be read must not
/// be able to say that.
async function repertoireProgress(pool, userId) {
  const rows = (await pool.query(
    `SELECT id, color, root_fen, root_path, via_uci
       FROM repertoires
      WHERE user_id = $1
      ORDER BY id`,
    [userId],
  )).rows;

  const wanted = rows.slice(0, MAX_ROWS);
  const items = [];
  for (let at = 0; at < wanted.length; at += CONCURRENCY) {
    const slice = wanted.slice(at, at + CONCURRENCY);
    const done = await Promise.all(slice.map(async (row) => {
      try {
        const walk = await frontier(pool, userId, {
          color: row.color,
          rootFen: row.root_fen,
          gateUci: row.via_uci,
        });
        return {
          id: row.id,
          open: walk.summary.open,
          decided: walk.summary.decided,
        };
      } catch {
        return { id: row.id, open: null, decided: null };
      }
    }));
    items.push(...done);
  }

  return { items, truncated: rows.length > wanted.length };
}

module.exports = { repertoireProgress, CONCURRENCY, MAX_ROWS };
