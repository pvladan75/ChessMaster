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

const COLORS = ['w', 'b'];
const ROLES = ['primary', 'alternate'];

/// Who decided a move. `auto` is a draft: drawn and walked through, never
/// asked about by the drill until somebody confirms it.
const SOURCES = ['chosen', 'auto'];

/// How wide a repertoire is walked — how many of the opponent's replies at each
/// position the queue, the tree, the coverage map and the drill follow.
///
/// A property of the **repertoire**, not of the book. `opening_replies.covered`
/// is the 80% cut and it is one column shared by every user of this server, so
/// widening it for somebody widens it for everybody. Breadth is stored per
/// repertoire and applied when the rows are read, from the `share` each row was
/// stored with — see `withinBreadth` in `repertoireFrontier`, which is the one
/// place the rule is written.
///
/// `standard` is the stored cut exactly as it is, so every repertoire made
/// before the column keeps the tree it had.
const BREADTHS = ['main', 'standard', 'broad'];
const DEFAULT_BREADTH = 'standard';

/// Reads a breadth, or refuses. Absent means the default rather than an error:
/// every caller written before this existed is asking for `standard`, and that
/// is what it used to get.
function requireBreadth(breadth) {
  if (breadth === null || breadth === undefined || breadth === '') {
    return DEFAULT_BREADTH;
  }
  if (!BREADTHS.includes(breadth)) {
    throw new RangeError(`Širina mora biti ${BREADTHS.join(', ')} — ne „${breadth}".`);
  }
  return breadth;
}

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

/// The move a repertoire goes through at its root, read as a move.
///
/// Returns `{ uci, san }`, or null when there is no gate. Refused rather than
/// stored when the move is not legal in that position: a gate that cannot be
/// played is a filter that silently matches nothing, and the repertoire would
/// open on an empty tree with no sentence anywhere saying why.
function readGate(rootFen, viaUci) {
  if (viaUci === null || viaUci === undefined || viaUci === '') return null;
  if (typeof viaUci !== 'string' || viaUci.length < 4 || viaUci.length > 6) {
    throw new RangeError('Potez kroz koji ide repertoar nije ispravan.');
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
      'Taj potez se ne može odigrati u početnoj poziciji repertoara.');
  }
  return { uci: viaUci, san: played.san };
}

async function createRepertoire(pool, userId, {
  name, color, rootFen, rootPath, viaUci = null, breadth = null,
}) {
  const clean = typeof name === 'string' ? name.trim() : '';
  if (clean === '') throw new RangeError('Repertoar mora imati ime.');
  requireColor(color);
  const wide = requireBreadth(breadth);
  // Validated here so a broken FEN is refused at the door rather than stored
  // and then failing every time the repertoire is opened.
  fenKey(rootFen);

  // Validated before the insert, so a gate that cannot be played is a 400 with
  // a sentence rather than a repertoire that opens on an empty tree.
  const gate = readGate(rootFen, viaUci);

  const result = await pool.query(
    `INSERT INTO repertoires
       (user_id, name, color, root_fen, root_path, via_uci, breadth)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, name, color, root_fen, root_path, via_uci, breadth,
               created_at`,
    [userId, clean, color, rootFen.trim(), pathText(rootPath),
      gate === null ? null : gate.uci, wide],
  );
  const row = result.rows[0];
  return row
    ? {
      ...row,
      rootPath: pathList(row.root_path),
      viaUci: row.via_uci,
      viaSan: gate === null ? null : gate.san,
      breadth: row.breadth,
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
            r.breadth, r.created_at,
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
    // How wide this one is walked. Carried on the row rather than looked up
    // per screen, because every walk the client asks for has to send it back —
    // the walks are keyed by position and gate, not by repertoire id.
    breadth: row.breadth ?? DEFAULT_BREADTH,
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
async function addMove(pool, userId, {
  color, fen, uci, san, verdict = null, source = 'chosen',
}) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci || !san) throw new RangeError('Potez nije prosleđen.');
  if (!SOURCES.includes(source)) {
    throw new RangeError(`Izvor poteza mora biti ${SOURCES.join(' ili ')}.`);
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
     RETURNING uci, san, role, verdict, source, added_at`,
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

/// What the opponent plays here, out of what has already been fetched.
///
/// No Lichess request, ever. `opening_replies` holds what anybody's build
/// session paid for — the rows are about a position and a rating band, never
/// about a person — so a panel that sits beside the board can be drawn from it
/// for free, and only a position nobody has ever opened costs anything.
///
/// That is the whole rule for a panel that follows the board: one token serves
/// every child using this app, and a list that refetched on every click would
/// spend their allowance on a drawing nobody asked for.
///
/// `opened` tells the two empties apart: no rows means nobody has ever looked
/// here, which is an offer to look rather than "the opponent plays nothing".
async function storedBook(pool, userId, { color, fen, minRating = 0 }) {
  requireColor(color);
  const key = fenKey(fen);
  const band = Number(minRating) || 0;

  const result = await pool.query(
    `SELECT r.uci, r.san, r.games, r.share, r.covered,
            EXISTS (
              SELECT 1 FROM repertoire_extra_replies e
               WHERE e.user_id = $3 AND e.color = $4
                 AND e.fen_key = r.fen_key AND e.uci = r.uci
            ) AS prepared
       FROM opening_replies r
      WHERE r.fen_key = $1 AND r.min_rating = $2
      ORDER BY r.games DESC`,
    [key, band, userId, color],
  );

  return {
    fen,
    fenKey: key,
    minRating: band,
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

/// A generated move becomes a decision.
///
/// Confirming is an act, and that is the whole reason the auto-spine is safe to
/// offer: until somebody says "yes, this one", a generated move is scaffolding
/// — drawn, walked through, and never asked about by the drill. Without this
/// the spine would be the archive seed again, wearing better moves.
///
/// Without `uci`, every draft in the position. With it, one move.
async function confirmNode(pool, userId, { color, fen, uci = null }) {
  requireColor(color);
  const key = fenKey(fen);
  const result = await pool.query(
    `UPDATE repertoire_moves
        SET source = 'chosen'
      WHERE user_id = $1 AND color = $2 AND fen_key = $3
        AND source = 'auto'
        AND ($4::text IS NULL OR uci = $4)`,
    [userId, color, key, uci],
  );
  return { confirmed: result.rowCount };
}

/// A whole line at once — every position along it.
///
/// One statement rather than one per position: a line half confirmed is a line
/// the student would have to walk twice, and a loop of updates is exactly where
/// a dropped connection leaves one.
async function confirmLine(pool, userId, { color, fens }) {
  requireColor(color);
  if (!Array.isArray(fens) || fens.length === 0) {
    throw new RangeError('Linija nije prosleđena.');
  }
  const keys = fens.map(fenKey);
  const result = await pool.query(
    `UPDATE repertoire_moves
        SET source = 'chosen'
      WHERE user_id = $1 AND color = $2 AND source = 'auto'
        AND fen_key = ANY($3)`,
    [userId, color, keys],
  );
  return { confirmed: result.rowCount, positions: keys.length };
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
    throw new RangeError('Repertoar nije imenovan brojem.');
  }
  const found = await pool.query(
    'SELECT root_fen FROM repertoires WHERE id = $1 AND user_id = $2',
    [numeric, userId],
  );
  if (found.rowCount === 0) throw new RangeError('Taj repertoar ne postoji.');

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

/// Changes how wide a repertoire is walked.
///
/// Its own door, and changeable, because breadth is a decision somebody revises:
/// a trunk is the right shape while an opening is being learned and the wrong
/// one a month later. Nothing is written to `opening_replies` and no move is
/// touched — the next walk simply follows more replies, or fewer, and the queue
/// and the map are recomputed from it.
///
/// Narrowing hides positions rather than deleting them. A position built under
/// `broad` and then narrowed to `main` keeps every move in it; it stops being
/// walked to, and widening again brings it straight back. That is the whole
/// reason breadth is read at walk time.
async function setBreadth(pool, userId, { id, breadth } = {}) {
  const numeric = Number(id);
  if (!Number.isInteger(numeric)) {
    throw new RangeError('Repertoar nije imenovan brojem.');
  }
  const wide = requireBreadth(breadth);
  const written = await pool.query(
    `UPDATE repertoires SET breadth = $3
      WHERE id = $1 AND user_id = $2
      RETURNING id, breadth`,
    [numeric, userId, wide],
  );
  if (written.rowCount === 0) throw new RangeError('Taj repertoar ne postoji.');
  return { id: numeric, breadth: written.rows[0].breadth };
}

/// The repertoires named by a list of ids: their doors, gates and breadths.
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
    throw new RangeError('Nijedan repertoar nije izabran.');
  }
  const result = await pool.query(
    `SELECT id, name, color, root_fen, root_path, via_uci, breadth
       FROM repertoires
      WHERE user_id = $1 AND id = ANY($2::int[])
      ORDER BY created_at ASC`,
    [userId, wanted],
  );
  if (result.rowCount !== new Set(wanted).size) {
    throw new RangeError('Neki od izabranih repertoara ne postoji.');
  }
  const colors = new Set(result.rows.map((row) => row.color));
  if (colors.size > 1) {
    throw new RangeError('Zajednička sesija ide za jednu boju.');
  }
  return result.rows.map((row) => ({
    id: row.id,
    name: row.name,
    color: row.color,
    rootFen: row.root_fen,
    rootPath: pathList(row.root_path),
    viaUci: row.via_uci,
    breadth: row.breadth ?? DEFAULT_BREADTH,
  }));
}

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
  skipNode,
  unskipNode,
  skippedKeys,
  addExtraReply,
  removeExtraReply,
  confirmNode,
  confirmLine,
  storedBook,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  setGate,
  setBreadth,
  repertoiresByIds,
  requireBreadth,
  COLORS,
  ROLES,
  SOURCES,
  BREADTHS,
  DEFAULT_BREADTH,
};
