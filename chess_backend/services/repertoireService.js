// repertoireService.js — what a student has decided to play, kept by position.
//
// The store is a graph, not a tree, and one graph per (user, colour). A
// repertoire with a name is a *door* into it — the position it starts from —
// and not a container of its own. That is what makes the thing the student
// actually asked for possible: work done from the Smith-Morra is already part
// of a later, shallower repertoire against 1.e4 the moment that repertoire
// reaches the same position, with nothing to merge and no chance of the same
// board carrying two different answers depending on how it was reached.
//
// Two invariants live here, and both are enforced rather than intended:
//
//   * A position has at most one **primary** move; anything else the student
//     kept is an alternate. Three equal answers cannot be drilled - everything
//     is correct, so nothing is ever learned past having to think about it.
//     The database holds this one, with a partial unique index.
//   * A position that has any moves has a primary. Removing the primary
//     promotes the oldest alternate rather than leaving a node that the drill
//     cannot ask about.

const COLORS = ['w', 'b'];
const ROLES = ['primary', 'alternate'];

/// The first four FEN fields: placement, side to move, castling, en passant.
///
/// The move counters are dropped on purpose. The same position reached at move
/// 12 and at move 16 is the same position to a repertoire, and keeping the
/// counters is what would quietly turn it into two.
function fenKey(fen) {
  if (typeof fen !== 'string' || fen.trim() === '') {
    throw new RangeError('Pozicija (FEN) nije prosleđena.');
  }
  const parts = fen.trim().split(/\s+/);
  if (parts.length < 4) {
    throw new RangeError('Pozicija (FEN) nije ispravna.');
  }
  return parts.slice(0, 4).join(' ');
}

function requireColor(color) {
  if (!COLORS.includes(color)) {
    throw new RangeError(`Boja mora biti „w" ili „b", a ne „${color}".`);
  }
  return color;
}

async function createRepertoire(pool, userId, { name, color, rootFen }) {
  const clean = typeof name === 'string' ? name.trim() : '';
  if (clean === '') throw new RangeError('Repertoar mora imati ime.');
  requireColor(color);
  // Validated here so a broken FEN is refused at the door rather than stored
  // and then failing every time the repertoire is opened.
  fenKey(rootFen);

  const result = await pool.query(
    `INSERT INTO repertoires (user_id, name, color, root_fen)
     VALUES ($1, $2, $3, $4)
     RETURNING id, name, color, root_fen, created_at`,
    [userId, clean, color, rootFen.trim()],
  );
  return result.rows[0];
}

async function listRepertoires(pool, userId) {
  const result = await pool.query(
    `SELECT r.id, r.name, r.color, r.root_fen, r.created_at,
            (SELECT COUNT(*) FROM repertoire_moves m
              WHERE m.user_id = r.user_id AND m.color = r.color) AS moves
       FROM repertoires r
      WHERE r.user_id = $1
      ORDER BY r.created_at DESC`,
    [userId],
  );
  return result.rows.map((row) => ({
    id: row.id,
    name: row.name,
    color: row.color,
    rootFen: row.root_fen,
    createdAt: row.created_at,
    // Moves are counted per colour, not per repertoire, because that is where
    // they live. Two repertoires for Black show the same number, and that is
    // the truth rather than a bug.
    moves: Number(row.moves),
  }));
}

/// What the student plays in this position: the primary first, then whatever
/// else they kept, oldest first.
async function nodeMoves(pool, userId, { color, fen }) {
  requireColor(color);
  const key = fenKey(fen);
  const result = await pool.query(
    `SELECT uci, san, role, verdict, added_at
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3
      ORDER BY (role = 'primary') DESC, added_at ASC`,
    [userId, color, key],
  );
  return result.rows.map((row) => ({
    uci: row.uci,
    san: row.san,
    role: row.role,
    verdict: row.verdict,
    addedAt: row.added_at,
  }));
}

/// Keeps a move. The first one kept in a position becomes the primary; the
/// rest are alternates until the student says otherwise.
///
/// Keeping the same move twice is not an error - it refreshes the verdict and
/// leaves the role alone, so re-judging an old position cannot silently demote
/// what the student chose.
async function addMove(pool, userId, { color, fen, uci, san, verdict = null }) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci || !san) throw new RangeError('Potez nije prosleđen.');

  const existing = await pool.query(
    `SELECT 1 FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND role = 'primary'`,
    [userId, color, key],
  );
  const role = existing.rowCount > 0 ? 'alternate' : 'primary';

  const result = await pool.query(
    `INSERT INTO repertoire_moves (user_id, color, fen_key, uci, san, role, verdict)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (user_id, color, fen_key, uci)
     DO UPDATE SET verdict = EXCLUDED.verdict
     RETURNING uci, san, role, verdict, added_at`,
    [userId, color, key, uci, san, role, verdict],
  );
  return result.rows[0];
}

/// Makes one kept move the primary and demotes the one that was.
///
/// Two statements in a transaction rather than one clever UPDATE: the partial
/// unique index is checked as each row is written, so a single statement that
/// moves the primary from one row to another can fail depending on which row
/// the planner touches first. Demote, then promote, and nothing in between is
/// ever visible to anyone else.
async function promoteMove(pool, userId, { color, fen, uci }) {
  requireColor(color);
  const key = fenKey(fen);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE repertoire_moves SET role = 'alternate'
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND role = 'primary'`,
      [userId, color, key],
    );
    const promoted = await client.query(
      `UPDATE repertoire_moves SET role = 'primary'
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4
        RETURNING uci, san, role, verdict`,
      [userId, color, key, uci],
    );
    if (promoted.rowCount === 0) {
      // Nothing was promoted, so the demotion must not stand either: a node
      // with moves and no primary is a node the drill cannot ask about.
      await client.query('ROLLBACK');
      throw new RangeError('Taj potez nije u repertoaru za ovu poziciju.');
    }
    await client.query('COMMIT');
    return promoted.rows[0];
  } catch (err) {
    if (!(err instanceof RangeError)) await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Drops a move, and never leaves the position without a primary.
async function removeMove(pool, userId, { color, fen, uci }) {
  requireColor(color);
  const key = fenKey(fen);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const removed = await client.query(
      `DELETE FROM repertoire_moves
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4
        RETURNING role`,
      [userId, color, key, uci],
    );
    if (removed.rowCount === 0) {
      await client.query('ROLLBACK');
      return { removed: false, promoted: null };
    }
    let promoted = null;
    if (removed.rows[0].role === 'primary') {
      const next = await client.query(
        `UPDATE repertoire_moves SET role = 'primary'
          WHERE id = (
            SELECT id FROM repertoire_moves
             WHERE user_id = $1 AND color = $2 AND fen_key = $3
             ORDER BY added_at ASC
             LIMIT 1
          )
          RETURNING uci, san`,
        [userId, color, key],
      );
      promoted = next.rows[0] ?? null;
    }
    await client.query('COMMIT');
    return { removed: true, promoted };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Writes down what the student reached for, whether or not they kept it.
///
/// Every attempt, not only the first, because "first" is a property of the
/// position over time and is read back with a query. Keeping them all means the
/// second pass over a position can be compared with the first, which is the
/// only way to see whether anything was actually learned.
async function recordAttempt(pool, userId, {
  color, fen, uci, san = null, verdict = null, kept = false, lookedUp = false,
}) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Potez nije prosleđen.');

  const result = await pool.query(
    `INSERT INTO repertoire_attempts
       (user_id, color, fen_key, uci, san, verdict, kept, looked_up)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, created_at`,
    [userId, color, key, uci, san, verdict, kept, lookedUp],
  );
  return result.rows[0];
}

/// The positions where the first instinct was wrong, worst first.
///
/// This is what the drill will schedule from, and it is why the attempts are
/// stored at all.
async function weakNodes(pool, userId, { color, limit = 20 } = {}) {
  requireColor(color);
  const result = await pool.query(
    `SELECT fen_key,
            COUNT(*) FILTER (WHERE verdict = 'mistake') AS mistakes,
            COUNT(*) FILTER (WHERE looked_up) AS lookups,
            COUNT(*) AS attempts,
            MAX(created_at) AS last_at
       FROM repertoire_attempts
      WHERE user_id = $1 AND color = $2
      GROUP BY fen_key
     HAVING COUNT(*) FILTER (WHERE verdict = 'mistake' OR looked_up) > 0
      ORDER BY mistakes DESC, lookups DESC, last_at DESC
      LIMIT $3`,
    [userId, color, limit],
  );
  return result.rows.map((row) => ({
    fenKey: row.fen_key,
    mistakes: Number(row.mistakes),
    lookups: Number(row.lookups),
    attempts: Number(row.attempts),
    lastAt: row.last_at,
  }));
}

module.exports = {
  fenKey,
  createRepertoire,
  listRepertoires,
  nodeMoves,
  addMove,
  promoteMove,
  removeMove,
  recordAttempt,
  weakNodes,
  COLORS,
  ROLES,
};
