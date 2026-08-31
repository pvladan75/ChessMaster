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

/// The moves that led to a repertoire's root, stored as one string and read
/// back as a list.
///
/// Text and not an array column, because this is never queried — it is carried
/// whole to the screen that draws the breadcrumb and nowhere else. Null is a
/// real answer and means "we do not know how this root was reached", which is
/// the truth for every repertoire made before the column existed.
function pathText(path) {
  if (!Array.isArray(path)) return null;
  const clean = path
    .filter((san) => typeof san === 'string' && san.trim() !== '')
    .map((san) => san.trim());
  return clean.length === 0 ? null : clean.join(' ');
}

function pathList(text) {
  if (typeof text !== 'string' || text.trim() === '') return [];
  return text.trim().split(/\s+/);
}

async function createRepertoire(pool, userId, { name, color, rootFen, rootPath }) {
  const clean = typeof name === 'string' ? name.trim() : '';
  if (clean === '') throw new RangeError('Repertoar mora imati ime.');
  requireColor(color);
  // Validated here so a broken FEN is refused at the door rather than stored
  // and then failing every time the repertoire is opened.
  fenKey(rootFen);

  const result = await pool.query(
    `INSERT INTO repertoires (user_id, name, color, root_fen, root_path)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, name, color, root_fen, root_path, created_at`,
    [userId, clean, color, rootFen.trim(), pathText(rootPath)],
  );
  const row = result.rows[0];
  return row ? { ...row, rootPath: pathList(row.root_path) } : row;
}

async function listRepertoires(pool, userId) {
  const result = await pool.query(
    `SELECT r.id, r.name, r.color, r.root_fen, r.root_path, r.created_at,
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
    // Empty for every repertoire made before the column existed. The screen
    // reads that as "start the breadcrumb at the root", which is exactly what
    // it knew before and no worse.
    rootPath: pathList(row.root_path),
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

/// "I am not preparing this" — stored, because it is a decision.
///
/// The one control in the build loop that makes the tree *smaller*. Everything
/// else adds: each wave of replies multiplies the queue, and a repertoire that
/// answers every sideline is a repertoire nobody finishes. Without somewhere to
/// put this, the only way to say it is to close the screen — and then the same
/// dead branch is back tomorrow, on every device.
///
/// Idempotent, so pressing it twice is not an error the student has to read
/// about.
async function skipNode(pool, userId, { color, fen }) {
  requireColor(color);
  const key = fenKey(fen);
  const result = await pool.query(
    `INSERT INTO repertoire_skips (user_id, color, fen_key)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, color, fen_key) DO UPDATE SET fen_key = EXCLUDED.fen_key
     RETURNING id, fen_key, created_at`,
    [userId, color, key],
  );
  return { skipped: true, ...result.rows[0] };
}

/// Puts a cut branch back. The same button, the other way round.
///
/// Cutting is cheap to do and must be cheap to undo, or it stops being a
/// decision and becomes a risk: nobody prunes a tree they cannot unprune.
async function unskipNode(pool, userId, { color, fen }) {
  requireColor(color);
  const key = fenKey(fen);
  const result = await pool.query(
    `DELETE FROM repertoire_skips
      WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
    [userId, color, key],
  );
  return { skipped: false, removed: result.rowCount };
}

/// The moves in this colour that nobody was ever asked about.
///
/// Every move kept by hand goes through `recordAttempt(kept: true)` the moment
/// it is kept — that row is the whole point of the attempts table, and it is
/// written for the student's own choices and for nothing else. So a move with
/// no kept attempt behind it was not chosen: it was written by the archive seed
/// that used to build a repertoire out of imported games.
///
/// A heuristic, and it is called one on the screen. It is the only signal there
/// is: the seed wrote through the same `addMove` as the build screen and left
/// nothing else to tell the two apart. The seed was removed on 31.8.2026 for
/// exactly that reason — moves nobody had chosen were indistinguishable from
/// decisions, and the drill went on to ask for them.
async function importedMoves(pool, userId, { color }) {
  requireColor(color);
  const result = await pool.query(
    `SELECT COUNT(*)::int AS moves,
            COUNT(DISTINCT fen_key)::int AS positions
       FROM repertoire_moves m
      WHERE m.user_id = $1 AND m.color = $2
        AND NOT EXISTS (
          SELECT 1 FROM repertoire_attempts a
           WHERE a.user_id = m.user_id AND a.color = m.color
             AND a.fen_key = m.fen_key AND a.uci = m.uci AND a.kept)`,
    [userId, color],
  );
  const row = result.rows[0] ?? {};
  return { moves: row.moves ?? 0, positions: row.positions ?? 0 };
}

/// Removes them, and puts the primary back where removing one took it away.
///
/// The second half is not tidying. A position must have a primary if it has any
/// moves at all — the drill has nothing to ask for otherwise — and a bulk delete
/// is the one path that can strip one without `removeMove` promoting the next.
/// Both halves in one transaction, because a repertoire between them is a
/// repertoire the drill cannot read.
async function forgetImportedMoves(pool, userId, { color }) {
  requireColor(color);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const gone = await client.query(
      `DELETE FROM repertoire_moves m
        WHERE m.user_id = $1 AND m.color = $2
          AND NOT EXISTS (
            SELECT 1 FROM repertoire_attempts a
             WHERE a.user_id = m.user_id AND a.color = m.color
               AND a.fen_key = m.fen_key AND a.uci = m.uci AND a.kept)`,
      [userId, color],
    );
    const promoted = await client.query(
      `UPDATE repertoire_moves
          SET role = 'primary'
        WHERE id IN (
          SELECT DISTINCT ON (fen_key) id
            FROM repertoire_moves
           WHERE user_id = $1 AND color = $2
             AND fen_key IN (
               SELECT fen_key FROM repertoire_moves
                WHERE user_id = $1 AND color = $2
                GROUP BY fen_key
               HAVING COUNT(*) FILTER (WHERE role = 'primary') = 0)
           ORDER BY fen_key, added_at ASC)`,
      [userId, color],
    );
    await client.query('COMMIT');
    return { removed: gone.rowCount, promoted: promoted.rowCount };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Removes a repertoire — the name and the starting point, never the moves.
///
/// The moves belong to (user, colour) and are shared by every repertoire that
/// reaches them; deleting them here would empty a door's worth of work out of
/// every other door. Until this existed there was no way to remove a repertoire
/// at all, which is how four of them made by a seed stayed on the list.
async function deleteRepertoire(pool, userId, id) {
  const numeric = Number(id);
  if (!Number.isInteger(numeric)) {
    throw new RangeError('Repertoar nije imenovan brojem.');
  }
  const result = await pool.query(
    'DELETE FROM repertoires WHERE id = $1 AND user_id = $2',
    [numeric, userId],
  );
  return { removed: result.rowCount };
}

/// "Prepare this opponent move too" — one reply past the coverage cut.
///
/// The build loop stops at 80% of what is played, up to four moves, and names
/// the remainder. That is a good default and a bad wall, and this is the way
/// through it: the tail is countable, and now it is reachable.
///
/// Stored per student rather than by flipping `opening_replies.covered`, which
/// is shared by everybody — one child's decision must not rewrite the walk
/// every other child follows.
async function addExtraReply(pool, userId, { color, fen, uci, san = null }) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Potez nije prosleđen.');

  const result = await pool.query(
    `INSERT INTO repertoire_extra_replies (user_id, color, fen_key, uci, san)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, color, fen_key, uci) DO UPDATE SET san = EXCLUDED.san
     RETURNING id, fen_key, uci, san, created_at`,
    [userId, color, key, uci, san],
  );
  return { prepared: true, ...result.rows[0] };
}

/// Takes one back out of the preparation. Same button, the other way round.
async function removeExtraReply(pool, userId, { color, fen, uci }) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Potez nije prosleđen.');

  const result = await pool.query(
    `DELETE FROM repertoire_extra_replies
      WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4`,
    [userId, color, key, uci],
  );
  return { prepared: false, removed: result.rowCount };
}

/// Every position this student has cut, for one colour, as a set.
///
/// One query for the whole walk. Asking per node would make the frontier
/// quadratic in the thing it is measuring, which is the mistake `keptByPosition`
/// exists to avoid.
async function skippedKeys(pool, userId, color) {
  requireColor(color);
  const result = await pool.query(
    `SELECT fen_key FROM repertoire_skips WHERE user_id = $1 AND color = $2`,
    [userId, color],
  );
  return new Set(result.rows.map((row) => row.fen_key));
}

module.exports = {
  fenKey,
  pathText,
  pathList,
  createRepertoire,
  listRepertoires,
  nodeMoves,
  addMove,
  promoteMove,
  removeMove,
  recordAttempt,
  weakNodes,
  skipNode,
  unskipNode,
  skippedKeys,
  addExtraReply,
  removeExtraReply,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  COLORS,
  ROLES,
};
