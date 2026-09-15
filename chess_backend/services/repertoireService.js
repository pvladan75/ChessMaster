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

const { Chess } = require('chess.js');
const { BOOK_BAND, BOOK_SOURCE } = require('./storedReplies');

const COLORS = ['w', 'b'];
const ROLES = ['primary', 'alternate'];

/// Who decided a move. Only `chosen` is written: every move in a repertoire is
/// one somebody played on the board (docs/PLAN-REPERTOAR-RUCNO.md). Rows the
/// retired spine wrote as `auto` may still exist until a colour is emptied, and
/// every reader asks for `chosen`, so none of them is walked or drilled.
const SOURCES = ['chosen'];

/// The first four FEN fields: placement, side to move, castling, en passant.
///
/// The move counters are dropped on purpose. The same position reached at move
/// 12 and at move 16 is the same position to a repertoire, and keeping the
/// counters is what would quietly turn it into two.
function fenKey(fen) {
  if (typeof fen !== 'string' || fen.trim() === '') {
    throw new RangeError('Position (FEN) was not provided.');
  }
  const parts = fen.trim().split(/\s+/);
  if (parts.length < 4) {
    throw new RangeError('Position (FEN) is invalid.');
  }
  return parts.slice(0, 4).join(' ');
}

function requireColor(color) {
  if (!COLORS.includes(color)) {
    throw new RangeError(`Color must be "w" or "b", not "${color}".`);
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

/// The move a repertoire goes through at its root, read as a move.
///
/// Returns `{ uci, san }`, or null when there is no gate. Refused rather than
/// stored when the move is not legal in that position: a gate that cannot be
/// played is a filter that silently matches nothing, and the repertoire would
/// open on an empty tree with no sentence anywhere saying why.
function readGate(rootFen, viaUci) {
  if (viaUci === null || viaUci === undefined || viaUci === '') return null;
  if (typeof viaUci !== 'string' || viaUci.length < 4 || viaUci.length > 6) {
    throw new RangeError('The move through which the repertoire goes is invalid.');
  }
  let played = null;
  try {
    const board = new Chess(rootFen);
    played = board.move({
      from: viaUci.slice(0, 2),
      to: viaUci.slice(2, 4),
      promotion: viaUci.length > 4 ? viaUci.slice(4) : undefined,
    });
  } catch {
    played = null;
  }
  if (!played) {
    throw new RangeError(
      'That move cannot be played in the repertoire starting position.');
  }
  return { uci: viaUci, san: played.san };
}

async function createRepertoire(pool, userId, {
  name, color, rootFen, rootPath, viaUci = null,
}) {
  const clean = typeof name === 'string' ? name.trim() : '';
  if (clean === '') throw new RangeError('Repertoire must have a name.');
  requireColor(color);
  // Validated here so a broken FEN is refused at the door rather than stored
  // and then failing every time the repertoire is opened.
  fenKey(rootFen);

  // Validated before the insert, so a gate that cannot be played is a 400 with
  // a sentence rather than a repertoire that opens on an empty tree.
  const gate = readGate(rootFen, viaUci);

  const result = await pool.query(
    `INSERT INTO repertoires
       (user_id, name, color, root_fen, root_path, via_uci)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, name, color, root_fen, root_path, via_uci, created_at`,
    [userId, clean, color, rootFen.trim(), pathText(rootPath),
      gate === null ? null : gate.uci],
  );
  const row = result.rows[0];
  return row
    ? {
      ...row,
      rootPath: pathList(row.root_path),
      viaUci: row.via_uci,
      viaSan: gate === null ? null : gate.san,
    }
    : row;
}

/// The gate as a move, or null when it cannot be read.
///
/// Forgiving where [readGate] is strict, and on purpose: a stored gate that no
/// longer parses must not take the whole list of repertoires down with it. The
/// row still comes back, with the uci and no san.
function readGateSan(rootFen, viaUci) {
  try {
    return readGate(rootFen, viaUci)?.san ?? null;
  } catch {
    return null;
  }
}

async function listRepertoires(pool, userId) {
  const result = await pool.query(
    `SELECT r.id, r.name, r.color, r.root_fen, r.root_path, r.via_uci,
            r.created_at,
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
    // The gate, and the move as it is read. The SAN is worked out here rather
    // than on the client: the client would need a board and the move's legality
    // to write "0-0" instead of "e1g1", and this server has both already.
    viaUci: row.via_uci,
    viaSan: row.via_uci === null
      ? null
      : (readGateSan(row.root_fen, row.via_uci)),
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
    `SELECT uci, san, role, verdict, source, added_at
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
    // `chosen` or `auto`. The build screen shows both — a draft you cannot see
    // is a draft you cannot confirm — and marks which is which.
    source: row.source,
    addedAt: row.added_at,
  }));
}

/// Keeps a move. The first one kept in a position becomes the primary; the
/// rest are alternates until the student says otherwise.
///
/// Keeping the same move twice is not an error - it refreshes the verdict and
/// leaves the role alone, so re-judging an old position cannot silently demote
/// what the student chose.
///
/// `inserted` says which of the two happened. A move kept for the first time
/// brings the book's top reply with it (`repertoireBook.keepMove`); a move
/// played again must not, or a reply the student deleted comes back.
async function addMove(pool, userId, {
  color, fen, uci, san, verdict = null, source = 'chosen',
}) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci || !san) throw new RangeError('Move was not provided.');
  if (!SOURCES.includes(source)) {
    throw new RangeError(`Move source must be ${SOURCES.join(' or ')}.`);
  }

  const existing = await pool.query(
    `SELECT 1 FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND role = 'primary'`,
    [userId, color, key],
  );
  const role = existing.rowCount > 0 ? 'alternate' : 'primary';

  const result = await pool.query(
    `INSERT INTO repertoire_moves
       (user_id, color, fen_key, uci, san, role, verdict, source)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (user_id, color, fen_key, uci)
     DO UPDATE SET verdict = EXCLUDED.verdict,
       /* A move played by hand over a generated one is a decision, and the row
          stops being a draft. Never the other way round: a generator must not
          be able to turn somebody's decision back into a suggestion.
          Block comment rather than a line one: a line comment survives up until
          something flattens the query onto one line, and then it eats the rest
          of it. */
       source = CASE WHEN EXCLUDED.source = 'chosen'
                     THEN 'chosen' ELSE repertoire_moves.source END
     RETURNING uci, san, role, verdict, source, added_at,
               (xmax = 0) AS inserted`,
    [userId, color, key, uci, san, role, verdict, source],
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
      throw new RangeError('That move is not in the repertoire for this position.');
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
///
/// The opponent moves entered after it go too, unless another move of the
/// student's still leads to that position: an opponent move stands only after a
/// move of theirs, and one left behind would come back as a surprise the day a
/// transposition reaches it.
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
    const replies = await sweepDanglingReplies(client, userId, color);
    await client.query('COMMIT');
    return { removed: true, promoted, replies };
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
  if (!uci) throw new RangeError('Move was not provided.');

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

/// What is played here, out of what has been stored from the book.
///
/// `opening_replies` holds what the local book says about a position — the rows
/// are about a position, never about a person. `prepared` marks the ones this
/// student entered.
///
/// `opened: false` means nothing is stored yet; `repertoireBook.bookAt` reads the
/// book then and stores it, so a screen never has to ask for it.
async function storedBook(pool, userId, { color, fen }) {
  requireColor(color);
  const key = fenKey(fen);

  const result = await pool.query(
    `SELECT r.uci, r.san, r.games, r.share, r.covered,
            EXISTS (
              SELECT 1 FROM repertoire_extra_replies e
               WHERE e.user_id = $3 AND e.color = $4
                 AND e.fen_key = r.fen_key AND e.uci = r.uci
            ) AS prepared
       FROM opening_replies r
      WHERE r.fen_key = $1 AND r.min_rating = $2 AND r.source = $5
      ORDER BY r.games DESC, r.uci ASC`,
    [key, BOOK_BAND, userId, color, BOOK_SOURCE],
  );

  return {
    fen,
    fenKey: key,
    opened: result.rowCount > 0,
    replies: result.rows.map((row) => ({
      uci: row.uci,
      san: row.san,
      games: Number(row.games),
      share: Number(row.share),
      covered: row.covered === true,
      prepared: row.prepared === true,
    })),
  };
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
/// Sets, changes or clears the move a repertoire goes through.
///
/// Needed as its own door because the repertoires that most want a gate are the
/// ones that already exist: the owner built two from the same position before
/// this column did, and the second one's tree is showing the first one's
/// opening right now.
///
/// Null clears it — back to the whole graph, which is what every repertoire did
/// before and is still right for a root with only one move.
async function setGate(pool, userId, { id, viaUci = null } = {}) {
  const numeric = Number(id);
  if (!Number.isInteger(numeric)) {
    throw new RangeError('Repertoire is not named by a number.');
  }
  const found = await pool.query(
    'SELECT root_fen FROM repertoires WHERE id = $1 AND user_id = $2',
    [numeric, userId],
  );
  if (found.rowCount === 0) throw new RangeError('That repertoire does not exist.');

  const gate = readGate(found.rows[0].root_fen, viaUci);
  const written = await pool.query(
    `UPDATE repertoires SET via_uci = $3
      WHERE id = $1 AND user_id = $2
      RETURNING id, via_uci`,
    [numeric, userId, gate === null ? null : gate.uci],
  );
  return {
    id: numeric,
    viaUci: written.rows[0]?.via_uci ?? null,
    viaSan: gate === null ? null : gate.san,
  };
}

/// The repertoires named by a list of ids: their doors and gates.
///
/// This is what a **combined** session is made of. Everything below the drill
/// takes one `(rootFen, gateUci)`, and a student who wants to practise two
/// openings in one sitting has no way to say so — so the request names
/// repertoires by id and the pairing is read here rather than sent as two
/// parallel lists, which is the shape that goes wrong the first time one of
/// them is shorter than the other.
///
/// One colour, always. A session mixes positions into one queue and the queue
/// is per colour; a mixed request is a mistake worth a sentence rather than an
/// answer that silently drops half of it. Ids that are not this user's are the
/// same kind of mistake, and refused by name.
async function repertoiresByIds(pool, userId, ids) {
  const wanted = (Array.isArray(ids) ? ids : [])
    .map((id) => Number(id))
    .filter((id) => Number.isInteger(id));
  if (wanted.length === 0) {
    throw new RangeError('No repertoire was chosen.');
  }
  const result = await pool.query(
    `SELECT id, name, color, root_fen, root_path, via_uci
       FROM repertoires
      WHERE user_id = $1 AND id = ANY($2::int[])
      ORDER BY created_at ASC`,
    [userId, wanted],
  );
  if (result.rowCount !== new Set(wanted).size) {
    throw new RangeError('Some of the chosen repertoires do not exist.');
  }
  const colors = new Set(result.rows.map((row) => row.color));
  if (colors.size > 1) {
    throw new RangeError('A combined session is for one color only.');
  }
  return result.rows.map((row) => ({
    id: row.id,
    name: row.name,
    color: row.color,
    rootFen: row.root_fen,
    rootPath: pathList(row.root_path),
    viaUci: row.via_uci,
  }));
}

async function deleteRepertoire(pool, userId, id) {
  const numeric = Number(id);
  if (!Number.isInteger(numeric)) {
    throw new RangeError('Repertoire is not named by a number.');
  }
  const result = await pool.query(
    'DELETE FROM repertoires WHERE id = $1 AND user_id = $2',
    [numeric, userId],
  );
  return { removed: result.rowCount };
}

/// An opponent move the student entered — played on the board, or the book's
/// top reply entered with their own move.
///
/// This table is the whole opponent side of a repertoire. The name is older
/// than the model: it was "prepare this one too" when the book decided the rest.
/// `fen` is the position the opponent moves from — after the student's move.
/// The move does not have to be in the book.
async function addExtraReply(pool, userId, { color, fen, uci, san = null }) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Move was not provided.');

  const result = await pool.query(
    `INSERT INTO repertoire_extra_replies (user_id, color, fen_key, uci, san)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, color, fen_key, uci) DO UPDATE SET san = EXCLUDED.san
     RETURNING id, fen_key, uci, san, created_at`,
    [userId, color, key, uci, san],
  );
  return { prepared: true, ...result.rows[0] };
}

/// Takes an entered opponent move back out. What only it reached is found and
/// asked about by `repertoirePrune.orphansOfRemoving`, before this is called.
async function removeExtraReply(pool, userId, { color, fen, uci }) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci) throw new RangeError('Move was not provided.');

  const result = await pool.query(
    `DELETE FROM repertoire_extra_replies
      WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4`,
    [userId, color, key, uci],
  );
  return { prepared: false, removed: result.rowCount };
}

/// Deletes the entered opponent moves no move of the student's leads to.
///
/// An opponent move stands only after a move of theirs. Taken as a client so it
/// runs inside the transaction that removed the moves — a repertoire between
/// the two is one with replies hanging off nothing.
///
/// Computed from the moves rather than from the move just removed, because the
/// store is a graph: the position after the removed move may still be reached
/// by another move of theirs, and its replies are then still in use.
async function sweepDanglingReplies(client, userId, color) {
  const moves = await client.query(
    `SELECT fen_key, uci FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND source = 'chosen'`,
    [userId, color],
  );
  const live = new Set();
  for (const row of moves.rows) {
    try {
      const board = new Chess(`${row.fen_key} 0 1`);
      // chess.js throws on a move it cannot play rather than answering null,
      // so reaching the next line means the move was played.
      board.move({
        from: row.uci.slice(0, 2),
        to: row.uci.slice(2, 4),
        promotion: row.uci.length > 4 ? row.uci[4] : undefined,
      });
      live.add(fenKey(board.fen()));
    } catch {
      // A stored move that no longer plays leads nowhere, so nothing it
      // reached is live.
    }
  }
  const gone = await client.query(
    `DELETE FROM repertoire_extra_replies
      WHERE user_id = $1 AND color = $2
        AND NOT (fen_key = ANY($3::text[]))`,
    [userId, color, [...live]],
  );
  return gone.rowCount;
}

module.exports = {
  fenKey,
  requireColor,
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
  addExtraReply,
  removeExtraReply,
  sweepDanglingReplies,
  storedBook,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  setGate,
  repertoiresByIds,
  COLORS,
  ROLES,
  SOURCES,
};
