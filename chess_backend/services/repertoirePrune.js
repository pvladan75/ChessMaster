// repertoirePrune.js — taking out what a changed mind left behind.
//
// The rule as it has to be built: **delete what became unreachable**, never
// "delete the subtree". The store is a graph keyed by position, not a tree
// keyed by path, so a position under an abandoned move may also stand on a line
// that is still played, and deleting by subtree would silently damage a line
// nobody touched.
//
// Two walks and a subtraction, therefore:
//
//   * `S` — what was reachable through the move about to go, taken **before**
//     it goes.
//   * `R` — what is reachable from every root of that colour **after**.
//   * orphans = S \ R.
//
// The move can be the student's own or an opponent move they entered: both
// are edges of the same walk, and removing either can strand what was behind
// it. Every move in a repertoire is one somebody played, so what is stranded is
// always counted and asked about before it goes.

const {
  step, keptByPosition, enteredReplies, MAX_NODES, MAX_PLY,
} = require('./repertoireFrontier');
const { fenKey, sweepDanglingReplies } = require('./repertoireService');

/// Every position the student is to move in, reachable from a set of starting
/// points.
///
/// Follows every move the student holds and every opponent move they entered —
/// the same walk the queue and the picture use, so what this calls reachable is
/// what they will draw.
///
/// `without` leaves one move out, the student's or the opponent's. It is how
/// "would this still be reachable if that move went" is asked before anything
/// is removed.
///
/// `from` takes either a plain FEN or `{ fen, viaUci }` — a starting point with
/// its **gate**. Gates are collected per position and unioned, and one ungated
/// starting point at a position opens it completely: this function answers
/// what everything given reaches, and anything else would call a line
/// unreachable because some other repertoire happens not to take it.
async function reachable(pool, userId, { color, from, without = null } = {}) {
  const skipKey = without ? fenKey(without.fen) : null;
  const skipped = (key, uci) => key === skipKey && uci === without.uci;
  const kept = await keptByPosition(pool, userId, color);

  const seen = new Set();
  const gates = new Map();
  let level = [];
  for (const one of from) {
    const fen = typeof one === 'string' ? one : one.fen;
    const gate = typeof one === 'string' ? null : (one.viaUci ?? null);
    const key = fenKey(fen);
    if (gate === null) {
      gates.set(key, null);
    } else if (gates.get(key) !== null) {
      const allowed = gates.get(key) ?? new Set();
      allowed.add(gate);
      gates.set(key, allowed);
    }
    if (seen.has(key)) continue;
    seen.add(key);
    level.push(fen);
  }

  let ply = 0;
  while (level.length > 0 && ply < MAX_PLY && seen.size < MAX_NODES) {
    const afters = [];
    for (const fen of level) {
      const here = fenKey(fen);
      // Only on the first wave: a gate is about the root of a repertoire, not
      // about every time the walk passes that position again by transposition.
      const allowed = ply === 0 ? gates.get(here) ?? null : null;
      for (const move of kept.get(here) ?? []) {
        if (allowed !== null && !allowed.has(move.uci)) continue;
        if (skipped(here, move.uci)) continue;
        const after = step(fen, move.uci);
        if (after !== null) afters.push(after.fen);
      }
    }

    const keys = [...new Set(afters.map(fenKey))];
    const replies = await enteredReplies(pool, userId, color, keys);

    const next = [];
    for (const after of afters) {
      const afterKey = fenKey(after);
      for (const reply of replies.get(afterKey) ?? []) {
        if (skipped(afterKey, reply.uci)) continue;
        const landed = step(after, reply.uci);
        if (landed === null) continue;
        const key = fenKey(landed.fen);
        if (seen.has(key)) continue;
        seen.add(key);
        next.push(landed.fen);
      }
    }

    level = next;
    ply += 2;
  }

  return seen;
}

/// The repertoire's own starting points, for this colour.
///
/// Every door into the graph, not one of them: a position is only orphaned when
/// *no* repertoire reaches it. Empty is refused by the caller rather than
/// treated as "nothing is reachable", which would make the sweep delete
/// everything.
async function rootsOf(pool, userId, color) {
  const result = await pool.query(
    `SELECT root_fen, via_uci
       FROM repertoires WHERE user_id = $1 AND color = $2`,
    [userId, color],
  );
  return result.rows.map((row) => ({ fen: row.root_fen, viaUci: row.via_uci }));
}

/// Whether the side to move in a FEN is the side the repertoire is for.
function studentToMove(fen, color) {
  return fen.trim().split(/\s+/)[1] === color;
}

/// What removing one move would strand, without removing it.
///
/// `fen` is the position the move is played from. When the student is to move
/// there it is one of their moves; otherwise it is an opponent move they
/// entered. Answers with the stranded positions and how many of the student's
/// moves stand in them. Nothing is written.
async function orphansOfRemoving(pool, userId, { color, fen, uci } = {}) {
  const roots = await rootsOf(pool, userId, color);
  if (roots.length === 0) {
    throw new RangeError('There is no repertoire for this color.');
  }
  const after = step(fen, uci);
  if (after === null) {
    // A move that will not replay strands nothing, because nothing was ever
    // reached through it.
    return { keys: [], decisions: 0 };
  }

  // `reachable` starts from positions the student is to move in. Removing one
  // of their own moves lands on the opponent's turn, so the walk is seeded one
  // step further on, with the replies entered there.
  let seeds = [after.fen];
  if (studentToMove(fen, color)) {
    const here = fenKey(after.fen);
    const replies = await enteredReplies(pool, userId, color, [here]);
    seeds = [];
    for (const reply of replies.get(here) ?? []) {
      const landed = step(after.fen, reply.uci);
      if (landed !== null) seeds.push(landed.fen);
    }
  }
  const behind = seeds.length === 0
    ? new Set()
    : await reachable(pool, userId, { color, from: seeds });
  // Without that move: every other way in, and the position it was played from
  // is still one of them.
  const otherwise = await reachable(pool, userId, {
    color, from: roots, without: { fen, uci },
  });

  const keys = [...behind].filter((key) => !otherwise.has(key));
  if (keys.length === 0) return { keys: [], decisions: 0 };

  const counts = await pool.query(
    `SELECT COUNT(*)::int AS decisions
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)
        AND source = 'chosen'`,
    [userId, color, keys],
  );
  return { keys, decisions: counts.rows[0]?.decisions ?? 0 };
}

/// Puts a primary back wherever a bulk delete took one away.
///
/// Not tidying. A position that has any moves at all **must** have a primary —
/// the drill has nothing to ask for otherwise — and a bulk delete is the one
/// path that can strip one without `removeMove` promoting the next. The oldest
/// surviving move wins, which is the same rule `removeMove` keeps.
///
/// Exported and taken as a client rather than written twice: it runs inside
/// whichever transaction did the deleting.
async function promoteWhereNoPrimary(client, userId, color, keys) {
  if (!Array.isArray(keys) || keys.length === 0) return 0;
  const promoted = await client.query(
    `UPDATE repertoire_moves
        SET role = 'primary'
      WHERE id IN (
        SELECT DISTINCT ON (fen_key) id
          FROM repertoire_moves
         WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)
           AND fen_key IN (
             SELECT fen_key FROM repertoire_moves
              WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)
              GROUP BY fen_key
             HAVING COUNT(*) FILTER (WHERE role = 'primary') = 0)
         ORDER BY fen_key, added_at ASC)`,
    [userId, color, keys],
  );
  return promoted.rowCount;
}

/// Removes the moves in a set of positions, the opponent moves entered after
/// them, and puts the primary back where taking one away left none.
///
/// Every key is re-checked against the roots before anything is deleted. The
/// answer to "is this still unreachable" can have changed between the question
/// and the confirmation, and a sweep that trusted a list from a minute ago
/// would delete a line that is back in use.
async function pruneKeys(pool, userId, { color, keys } = {}) {
  if (!Array.isArray(keys) || keys.length === 0) {
    return { removed: 0, promoted: 0, replies: 0 };
  }
  const roots = await rootsOf(pool, userId, color);
  if (roots.length === 0) {
    throw new RangeError('There is no repertoire for this color.');
  }

  const live = await reachable(pool, userId, { color, from: roots });
  const stranded = keys.filter((key) => !live.has(key));
  if (stranded.length === 0) return { removed: 0, promoted: 0, replies: 0 };

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const gone = await client.query(
      `DELETE FROM repertoire_moves
        WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)`,
      [userId, color, stranded],
    );
    const promoted = await promoteWhereNoPrimary(client, userId, color, stranded);
    const replies = await sweepDanglingReplies(client, userId, color);
    await client.query('COMMIT');
    return { removed: gone.rowCount, promoted, replies };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  reachable, orphansOfRemoving, pruneKeys, rootsOf, promoteWhereNoPrimary,
};
