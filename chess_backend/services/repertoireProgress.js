// repertoireProgress.js — how much of each repertoire is still unanswered.
//
// One number per repertoire, for the screen somebody opens first. The list has
// said "N poteza u grafu" for a long time, which is how much was built and not
// how much is left, and a badge counting drafts per *colour* put the same 42 on
// three different cards — true, and useless for choosing which one to open.
//
// It is a walk per repertoire and there is no cheaper honest version: "a
// position this repertoire reaches and nobody has decided in" is defined by the
// walk, through the book, inside the breadth band. So the shape is the
// compromise instead: the list draws immediately from `list()` and fills these
// in when they arrive, and they arrive a few at a time rather than all at once.
//
// Measured on the reference account: about 300 ms per repertoire, and three of
// them in a second when run one behind the other. That is why the list must not
// wait for this, and why the concurrency below is not one.
const { frontier } = require('./repertoireFrontier');
const { DEFAULT_BREADTH } = require('./repertoireService');

/// How many walks run at once, and how many repertoires are walked at all.
///
/// Both caps exist for the same reason and neither is a guess about the
/// database: an account with forty repertoires would otherwise open forty walks
/// on one request, and the screen that started them has room for a number, not
/// for a reason to wait.
const CONCURRENCY = 4;
const MAX_ROWS = 40;

/// The unanswered count for every repertoire the caller owns.
///
/// `open` is what the reader asked to see: positions this repertoire reaches
/// where they have made no decision. `draft` is the other pile — a move is
/// there, generated, waiting for a yes — and the two are never added together,
/// because one is work to do and the other is work to agree to.
///
/// A repertoire whose walk throws is reported with nulls rather than zeros. A
/// zero here means "nothing left", and a walk that could not be read must not
/// be able to say that.
async function repertoireProgress(pool, userId, { minRating = 0 } = {}) {
  const rows = (await pool.query(
    `SELECT id, color, root_fen, root_path, via_uci, breadth
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
          breadth: row.breadth || DEFAULT_BREADTH,
          minRating,
        });
        return {
          id: row.id,
          open: walk.summary.undecided,
          draft: walk.summary.draft,
          decided: walk.summary.decided,
        };
      } catch {
        return { id: row.id, open: null, draft: null, decided: null };
      }
    }));
    items.push(...done);
  }

  return { items, truncated: rows.length > wanted.length };
}

module.exports = { repertoireProgress, CONCURRENCY, MAX_ROWS };
