// mistakeReviews.js — a player's own mistakes, on the spacing algorithm.
//
// Section 3 of docs/PLAN-MOJE-PARTIJE.md. The store is `mistake_reviews`, the
// parallel table decided on 30.8.2026 rather than a nullable `lesson_id` on
// `review_items`: both keep a strict foreign key that cascades, so a lesson
// position dies with its lesson and a mistake dies with the game it came from.
//
// **The arithmetic is not re-implemented here.** `schedule()` in
// spacedRepetitionService.js is a pure function over `ease_factor`,
// `repetitions` and `lapses`, and this table names those columns identically on
// purpose. Two stores, one SM-2, owned by neither — a second copy of an
// interval calculation is a second chance to get it wrong, and wrong is
// invisible: a bad interval does not throw, it quietly stops teaching.
//
// Two kinds of row arrive here from two directions. The endgame audit writes
// its own, server-side, from the tables (`kind = 'tablebase'`). Engine findings
// come from the client, because a whole-archive engine pass is an overnight
// desktop job and has no business on a 960 MB droplet — so [recordMistakes] is
// the door they come through, and it checks what it is handed rather than
// trusting it.
//
// What makes this worth drilling at all is **recurrence**. One missed fork is a
// bad evening; the same motif missed forty times is a weakness, and that
// ranking is a query over the whole archive — which is why it lives here and
// not on the client, where it could only ever rank what it had been sent.

const {
  GRADES, isValidGrade, schedule, describeInterval,
} = require('./spacedRepetitionService');
const { ownGameIds } = require('./archiveScope');
const logger = require('./logger');

const KINDS = ['engine', 'tablebase'];
const MAX_ITEMS_PER_CALL = 500;

/// Material on the board, as a sorted signature: 'KPRkppr' is a rook and pawns
/// against a rook and pawns. It is what makes a recurrence bucket for endgames —
/// the exact positions never repeat (measured: 4255 probes, 4255 distinct), but
/// the material repeats constantly, and "you keep losing rook and pawn endings"
/// is the sentence a player can act on.
function materialSignature(fen) {
  return String(fen).split(' ')[0].replace(/[^a-zA-Z]/g, '').split('').sort().join('');
}

/// Takes engine findings from the client and stores the ones that hold up.
///
/// Returns a tally in the same shape the importer uses, and for the same
/// reason: every item handed in is stored, already known, or **rejected with a
/// named reason**. A silent drop here would be a drill quietly missing the
/// mistakes a player most wants to see.
async function recordMistakes(pool, userId, items = []) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  if (!Array.isArray(items)) throw new RangeError('Nedostaje spisak grešaka.');
  if (items.length > MAX_ITEMS_PER_CALL) {
    throw new RangeError(`Najviše ${MAX_ITEMS_PER_CALL} grešaka po pozivu.`);
  }

  const rejected = [];
  // The index travels with the item. Recovering it later with indexOf would be
  // quadratic and, worse, wrong: two identical findings are two items and
  // indexOf would name the first one twice.
  const candidates = [];
  items.forEach((item, index) => {
    const reason = whyNotStorable(item);
    if (reason) rejected.push({ index, reason });
    else candidates.push({ item, index });
  });

  // The games have to be the caller's **own**, which is two conditions and not
  // one. `user_id` alone would also match an opponent archive imported for
  // match preparation, and a blunder out of somebody else's game filed here
  // would be drilled as the player's and ranked in their recurrence report.
  // Checked at all because `game_id` arrives from a client: without this, a
  // guessed id would file another user's game under this one.
  const mine = candidates.length > 0
    ? await ownGameIds(pool, userId, candidates.map(({ item }) => item.gameId))
    : new Set();

  const storable = [];
  for (const { item, index } of candidates) {
    if (mine.has(String(item.gameId))) storable.push(item);
    else rejected.push({ index, reason: 'game-not-yours' });
  }

  let stored = 0;
  if (storable.length > 0) {
    const params = [];
    const tuples = storable.map((item) => {
      const values = [
        userId, Number(item.gameId), Number(item.ply), item.fenBefore,
        item.playedUci, item.bestUci || null, 'engine',
        item.theme || null, Math.round(Number(item.swingCp)),
      ];
      const start = params.length;
      params.push(...values);
      return `(${values.map((_, i) => `$${start + i + 1}`).join(', ')})`;
    });
    const result = await pool.query(
      `INSERT INTO mistake_reviews
         (user_id, game_id, ply, fen_before, played_uci, best_uci,
          kind, theme, swing_cp)
       VALUES ${tuples.join(', ')}
       ON CONFLICT (user_id, game_id, ply) DO NOTHING
       RETURNING id`,
      params,
    );
    stored = result.rowCount;
  }

  const tally = {
    read: items.length,
    stored,
    duplicate: storable.length - stored,
    rejected: rejected.length,
    rejected_by_reason: rejected.reduce((acc, r) => {
      acc[r.reason] = (acc[r.reason] || 0) + 1;
      return acc;
    }, {}),
  };

  const accounted = tally.stored + tally.duplicate + tally.rejected;
  if (accounted !== tally.read) {
    throw new Error(
      `mistakes lost: handed ${tally.read}, accounted ${accounted}`,
    );
  }
  return tally;
}

/// Why one item cannot be stored, or null.
///
/// The swing is required rather than defaulted. `mistake_reviews` refuses an
/// engine row without one anyway — that is its check constraint — and a
/// mistake with no measure of how bad it was cannot be ranked, shown, or
/// argued with.
function whyNotStorable(item) {
  if (!item || typeof item !== 'object') return 'not-an-object';
  if (!Number.isInteger(Number(item.gameId))) return 'no-game';
  if (!Number.isInteger(Number(item.ply)) || Number(item.ply) < 0) return 'no-ply';
  if (typeof item.fenBefore !== 'string' || item.fenBefore.split(' ').length < 4) {
    return 'no-position';
  }
  if (typeof item.playedUci !== 'string' || item.playedUci.length < 4) return 'no-move';
  // Tested before converting: Number(null) and Number('') are both 0, so a
  // finding with no swing at all would pass a Number.isFinite check and be
  // stored as "zero centipawns" — a mistake claiming it cost nothing.
  if (item.swingCp === null || item.swingCp === undefined || item.swingCp === '') {
    return 'no-swing';
  }
  if (!Number.isFinite(Number(item.swingCp))) return 'no-swing';
  return null;
}

/// What is due, with enough of the game around it to be worth looking at.
async function dueItems(pool, userId, { limit = 20, now = new Date() } = {}) {
  const { rows } = await pool.query(
    `SELECT m.id, m.game_id, m.ply, m.fen_before, m.played_uci, m.best_uci,
            m.kind, m.theme, m.swing_cp, m.wdl_before, m.wdl_after,
            m.interval_days, m.repetitions, m.lapses, m.due_at,
            g.played_at, g.opponent, g.result, g.subject_color, g.opening
       FROM mistake_reviews m
       JOIN user_games g ON g.id = m.game_id
      WHERE m.user_id = $1 AND m.due_at <= $2
      ORDER BY m.due_at ASC
      LIMIT $3`,
    [userId, now, Math.min(Math.max(limit, 1), 100)],
  );
  return rows;
}

/// One answer, scheduled by the same SM-2 as the lesson reviews.
async function gradeItem(pool, { userId, itemId, quality }, now = new Date()) {
  if (!isValidGrade(quality)) {
    return { ok: false, reason: 'Ocena mora biti ceo broj od 0 do 5.' };
  }
  const { rows } = await pool.query(
    'SELECT * FROM mistake_reviews WHERE id = $1 AND user_id = $2',
    [itemId, userId],
  );
  const current = rows[0];
  if (!current) return { ok: false, reason: 'Greška za ponavljanje nije pronađena.' };

  const next = schedule(current, quality, now);
  const updated = await pool.query(
    `UPDATE mistake_reviews
        SET ease_factor = $1, interval_days = $2, repetitions = $3, lapses = $4,
            due_at = $5, last_reviewed_at = CURRENT_TIMESTAMP
      WHERE id = $6
      RETURNING *`,
    [next.easeFactor, next.intervalDays, next.repetitions, next.lapses,
      next.dueAt, current.id],
  );

  logger.info(
    { userId, itemId, quality, intervalDays: next.intervalDays },
    'Mistake review graded',
  );
  return {
    ok: true,
    item: updated.rows[0],
    intervalDays: next.intervalDays,
    dueAt: next.dueAt,
    description: describeInterval(next.intervalDays),
  };
}

async function stats(pool, userId, now = new Date()) {
  const { rows } = await pool.query(
    `SELECT kind,
            COUNT(*)::int AS total,
            COUNT(*) FILTER (WHERE due_at <= $2)::int AS due,
            COUNT(*) FILTER (WHERE repetitions >= 3)::int AS mature
       FROM mistake_reviews WHERE user_id = $1
      GROUP BY kind`,
    [userId, now],
  );
  const empty = { total: 0, due: 0, mature: 0 };
  const byKind = Object.fromEntries(KINDS.map((k) => [k, { ...empty }]));
  for (const row of rows) {
    byKind[row.kind] = { total: row.total, due: row.due, mature: row.mature };
  }
  return {
    byKind,
    total: rows.reduce((n, r) => n + r.total, 0),
    due: rows.reduce((n, r) => n + r.due, 0),
    mature: rows.reduce((n, r) => n + r.mature, 0),
  };
}

/// What keeps happening, which is the difference between a bad evening and a
/// weakness. Engine mistakes bucket by their tactical motif; tablebase ones by
/// the material they were played in, because the positions never repeat and the
/// material always does.
async function recurrence(pool, userId, { limit = 12, sample = 5000 } = {}) {
  const { rows } = await pool.query(
    `SELECT id, kind, theme, fen_before, swing_cp
       FROM mistake_reviews WHERE user_id = $1
      ORDER BY id DESC LIMIT $2`,
    [userId, sample],
  );

  const motifs = new Map();
  const endings = new Map();
  for (const row of rows) {
    const into = row.kind === 'tablebase' ? endings : motifs;
    const key = row.kind === 'tablebase'
      ? materialSignature(row.fen_before)
      : (row.theme || 'bez teme');
    const bucket = into.get(key) || { key, count: 0, worstSwing: 0, example: row.id };
    bucket.count += 1;
    const swing = Math.abs(Number(row.swing_cp) || 0);
    if (swing > bucket.worstSwing) {
      bucket.worstSwing = swing;
      bucket.example = row.id;
    }
    into.set(key, bucket);
  }

  const top = (map) => [...map.values()]
    .sort((a, b) => b.count - a.count)
    .slice(0, limit);

  return { sampled: rows.length, motifs: top(motifs), endings: top(endings) };
}

module.exports = {
  GRADES,
  recordMistakes,
  dueItems,
  gradeItem,
  stats,
  recurrence,
  materialSignature,
  whyNotStorable,
  MAX_ITEMS_PER_CALL,
};
