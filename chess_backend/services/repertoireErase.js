// repertoireErase.js — taking a repertoire, or a whole colour, back out.
//
// `repertoires` is a **name for a starting point**, not a container: the moves
// belong to (user, colour), which is what makes transpositions free and what
// makes deleting one confusing. Deleting the row has always taken the name and
// the starting point and left every move standing — correctly, since another
// repertoire of the same colour may be standing on them — and the owner met the
// hole that leaves: delete *every* repertoire, open "new", and the tree is full
// of moves already answered, with no door anywhere to the rows behind them.
//
// The hole is not that the moves survive. It is that `repertoirePrune` refuses
// to run when no repertoire is left — `rootsOf` returns nothing, and a sweep
// that treated "no roots" as "nothing is reachable" would delete the lot. That
// guard is right and stays. This file is the door it made necessary.
//
// Two doors, because there are two questions:
//
//   * **Deleting one repertoire, with its moves.** What goes is what *only this
//     repertoire reaches* — reachable from its root, minus everything reachable
//     from the other roots of that colour. A shared position stays, because it
//     is still being played.
//   * **Emptying a colour.** Everything stored for that side, counted first.
//     This is the only door that opens when no repertoire is left, which is the
//     state the hole above leaves behind.
//
// What goes with the moves: the cut branches, the extra replies, the attempts,
// the drill's schedule and the engine's evaluations for those positions. All of
// them are *about* moves that are going, and a cut or a review left behind
// would silently re-apply to a line rebuilt later — a decision from a
// repertoire the student deleted, arriving as a surprise weeks on.
//
// What does **not** go: the comments the student wrote. Prose is the one thing
// here nothing can recompute, and a comment whose moves are gone costs a row
// and comes back the moment the position is reached again. It goes only when
// the person deleting says so, in as many words.

const { reachable } = require('./repertoirePrune');
const { requireColor } = require('./repertoireService');

/// The tables holding per-position state for one colour, in the order they are
/// emptied.
///
/// A literal list in this file, never anything a caller passed: the names are
/// interpolated into the SQL below, which is only safe because of that.
const POSITION_TABLES = Object.freeze([
  'repertoire_moves',
  'repertoire_skips',
  'repertoire_extra_replies',
  'repertoire_attempts',
  'repertoire_reviews',
  'repertoire_notes',
]);

function requireId(id) {
  const numeric = Number(id);
  if (!Number.isInteger(numeric)) {
    throw new RangeError('Repertoar nije imenovan brojem.');
  }
  return numeric;
}

/// What is stored for a set of positions, in the words a confirmation dialog
/// needs: how many positions, how many moves, how many of those the student
/// chose themselves, and how many carry something they wrote.
///
/// `keys === null` means the whole colour. Written as one `IS NULL OR` rather
/// than two queries so the two doors count by the same rule — a wipe that
/// counted differently from a cascade is a dialog that lies on one of them.
async function countsFor(pool, userId, color, keys = null) {
  const moves = await pool.query(
    `SELECT COUNT(*)::int AS moves,
            COUNT(DISTINCT fen_key)::int AS positions,
            COUNT(*) FILTER (WHERE source = 'auto')::int AS drafts,
            COUNT(*) FILTER (WHERE source <> 'auto')::int AS decisions
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2
        AND ($3::text[] IS NULL OR fen_key = ANY($3))`,
    [userId, color, keys],
  );
  const comments = await pool.query(
    `SELECT COUNT(*)::int AS comments
       FROM repertoire_comments
      WHERE user_id = $1 AND color = $2
        AND ($3::text[] IS NULL OR fen_key = ANY($3))`,
    [userId, color, keys],
  );
  const row = moves.rows[0] ?? {};
  return {
    positions: row.positions ?? 0,
    moves: row.moves ?? 0,
    decisions: row.decisions ?? 0,
    drafts: row.drafts ?? 0,
    comments: comments.rows[0]?.comments ?? 0,
  };
}

/// The repertoire, read for its colour and its starting point.
async function repertoireRow(pool, userId, id) {
  const found = await pool.query(
    `SELECT id, name, color, root_fen, root_path, via_uci
       FROM repertoires WHERE id = $1 AND user_id = $2`,
    [requireId(id), userId],
  );
  if (found.rowCount === 0) {
    throw new RangeError('Taj repertoar ne postoji.');
  }
  return found.rows[0];
}

/// What deleting this repertoire would strand, without deleting anything.
///
/// The subtraction is the whole point, and it is the same one `orphansOfRemoving`
/// makes for a single move: reachable from this root, minus reachable from every
/// *other* root of the same colour. A position two repertoires share is not
/// stranded by losing one of them.
///
/// When this is the last repertoire of its colour the second set is empty, and
/// the answer is everything the walk reaches — which is right, and is why the
/// screen shows the count before it asks.
async function orphansOfDeleting(pool, userId, { id, minRating = 0 } = {}) {
  const row = await repertoireRow(pool, userId, id);
  const color = row.color;

  const others = await pool.query(
    `SELECT root_fen, via_uci FROM repertoires
      WHERE user_id = $1 AND color = $2 AND id <> $3`,
    [userId, color, row.id],
  );

  // Each side of the subtraction walks through its own gate. Without that, two
  // repertoires from one root would each look as though the other reached
  // everything, and deleting either would report that it strands nothing.
  const mine = await reachable(pool, userId, {
    color, from: [{ fen: row.root_fen, viaUci: row.via_uci }], minRating,
  });
  const otherwise = others.rowCount === 0
    ? new Set()
    : await reachable(pool, userId, {
      color,
      from: others.rows.map((r) => ({ fen: r.root_fen, viaUci: r.via_uci })),
      minRating,
    });

  const keys = [...mine].filter((key) => !otherwise.has(key));
  const counts = keys.length === 0
    ? { positions: 0, moves: 0, decisions: 0, drafts: 0, comments: 0 }
    : await countsFor(pool, userId, color, keys);

  return {
    id: row.id,
    name: row.name,
    color,
    keys,
    shared: mine.size - keys.length,
    ...counts,
  };
}

/// Empties the position tables for a set of keys, or for a whole colour.
///
/// `keys === null` is the colour; a list is the cascade. One code path for both
/// so there is no second delete to fall out of step with this one.
async function purge(client, userId, color, keys, { includeComments = false }) {
  const removed = {};
  for (const table of POSITION_TABLES) {
    const gone = await client.query(
      `DELETE FROM ${table}
        WHERE user_id = $1 AND color = $2
          AND ($3::text[] IS NULL OR fen_key = ANY($3))`,
      [userId, color, keys],
    );
    removed[table] = gone.rowCount;
  }
  if (includeComments) {
    const gone = await client.query(
      `DELETE FROM repertoire_comments
        WHERE user_id = $1 AND color = $2
          AND ($3::text[] IS NULL OR fen_key = ANY($3))`,
      [userId, color, keys],
    );
    removed.repertoire_comments = gone.rowCount;
  }
  return removed;
}

/// Deletes a repertoire — the name and the starting point always, the moves
/// behind it when asked.
///
/// The stranded positions are worked out **before** the row goes, because the
/// question needs the root that is about to be deleted. Both halves then happen
/// in one transaction: a repertoire deleted without its moves is the old
/// behaviour and recoverable; moves deleted without the repertoire, or the other
/// way round after a failure, is a state nobody asked for.
async function deleteRepertoire(pool, userId, {
  id, withMoves = false, includeComments = false, minRating = 0,
} = {}) {
  const numeric = requireId(id);
  if (!withMoves) {
    const gone = await pool.query(
      'DELETE FROM repertoires WHERE id = $1 AND user_id = $2',
      [numeric, userId],
    );
    return { removed: gone.rowCount, movesRemoved: 0, positions: 0 };
  }

  const orphans = await orphansOfDeleting(pool, userId, { id: numeric, minRating });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const gone = await client.query(
      'DELETE FROM repertoires WHERE id = $1 AND user_id = $2',
      [numeric, userId],
    );
    const cleared = orphans.keys.length === 0
      ? {}
      : await purge(client, userId, orphans.color, orphans.keys,
        { includeComments });
    await client.query('COMMIT');
    return {
      removed: gone.rowCount,
      movesRemoved: cleared.repertoire_moves ?? 0,
      commentsRemoved: cleared.repertoire_comments ?? 0,
      positions: orphans.keys.length,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Everything stored for one side, counted.
///
/// The number the wipe dialog reads out. It answers the question the owner
/// actually had — "what is still in there?" — which until now had no answer at
/// all once the last repertoire of the colour was gone.
async function colorStats(pool, userId, { color } = {}) {
  requireColor(color);
  const counts = await countsFor(pool, userId, color, null);
  const named = await pool.query(
    'SELECT COUNT(*)::int AS repertoires FROM repertoires WHERE user_id = $1 AND color = $2',
    [userId, color],
  );
  return { color, ...counts, repertoires: named.rows[0]?.repertoires ?? 0 };
}

/// Empties a colour: every move, cut, extra reply, attempt, review and
/// evaluation stored for that side.
///
/// The repertoires themselves are left standing. They are a name and a starting
/// point; somebody emptying the moves is starting that opening over, not
/// throwing away the fact that they play it. Deleting the name is the other
/// button, and it is one click away.
///
/// Comments stay unless asked for, for the reason at the top of this file.
async function eraseColor(pool, userId, { color, includeComments = false } = {}) {
  requireColor(color);
  const before = await countsFor(pool, userId, color, null);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cleared = await purge(client, userId, color, null, { includeComments });
    await client.query('COMMIT');
    return {
      color,
      movesRemoved: cleared.repertoire_moves ?? 0,
      commentsRemoved: cleared.repertoire_comments ?? 0,
      positions: before.positions,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  orphansOfDeleting,
  deleteRepertoire,
  colorStats,
  eraseColor,
  countsFor,
  POSITION_TABLES,
};
