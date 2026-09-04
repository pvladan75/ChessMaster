// repertoirePrune.js — taking out what a changed mind left behind.
//
// The rule the owner asked for: change your move at a node and everything
// generated behind the old choice goes with it. The rule as it has to be built:
// **delete what became unreachable**, never "delete the subtree".
//
// The store is a graph keyed by position, not a tree keyed by path — that is
// what makes work deep in the Smith-Morra part of a later 1.e4 repertoire the
// moment it reaches the same board. So a position under an abandoned move may
// also stand on a line that is still played, and deleting by subtree would
// silently damage a line nobody touched.
//
// Two walks and a subtraction, therefore:
//
//   * `S` — what was reachable through the move about to go, taken **before**
//     it goes.
//   * `R` — what is reachable from every root of that colour **after**.
//   * orphans = S \ R.
//
// That subtraction is also what keeps the sweep from eating positions that were
// never reachable in the first place — one built by jumping in from the drill,
// say, off the end of the covered tail. Those are not in `S`, so they are not
// in the answer, and an "unreachable" sweep over the whole colour would have
// taken every one of them.
//
// Cuts are walked straight through. `repertoire_skips` says "do not ask me
// about this branch", not "delete it", and a cut that quietly deleted the work
// behind it could never be undone.
//
// Drafts go without asking; **decisions are counted and handed back**. Losing an
// evening's work to a changed second move, with no sentence about it, is the
// kind of thing that happens once and ends trust in a feature.

const {
  step, keptByPosition, coveredReplies, MAX_NODES, MAX_PLY,
} = require('./repertoireFrontier');
const { fenKey, BREADTHS, DEFAULT_BREADTH } = require('./repertoireService');

/// Every position reachable from a set of starting points.
///
/// Follows every move the student holds — decisions and drafts alike, because a
/// draft is still a way through — and every reply the book covers plus the ones
/// they asked for by name. The same walk the queue and the picture use, so what
/// this calls reachable is what they will draw.
///
/// `without` leaves one move out. It is how "would this still be reachable if
/// that move went" is asked before anything is removed — the question has to be
/// answered while the move is still there, or the answer is about a repertoire
/// that no longer exists.
/// `from` takes either a plain FEN or `{ fen, viaUci }` — a starting point with
/// its **gate**, the one move that repertoire goes through at its root.
///
/// Two repertoires can start from the same position and go different ways, and
/// this function answers a *union*: what everything given reaches. So gates are
/// collected per position and unioned, and one ungated starting point at a
/// position opens it completely — anything else would call a line unreachable
/// because some other repertoire happens not to take it.
async function reachable(pool, userId, {
  color, from, minRating = 0, without = null, breadth = DEFAULT_BREADTH,
} = {}) {
  const skipKey = without ? fenKey(without.fen) : null;
  const kept = await keptByPosition(pool, userId, color);
  const band = Number(minRating) || 0;

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
    const branches = [];
    for (const fen of level) {
      const here = fenKey(fen);
      // Only on the first wave: a gate is about the root of a repertoire, not
      // about every time the walk passes that position again by transposition.
      const allowed = ply === 0 ? gates.get(here) ?? null : null;
      for (const move of kept.get(here) ?? []) {
        if (allowed !== null && !allowed.has(move.uci)) continue;
        if (here === skipKey && move.uci === without.uci) continue;
        const after = step(fen, move.uci);
        if (after !== null) branches.push(after.fen);
      }
    }

    const keys = [...new Set(branches.map(fenKey))];
    // The board for each key, and everything the student holds, so a reply that
    // leads into their own work is followed at every breadth — the same rule
    // the queue and the picture walk by. This function says of itself that it
    // is that same walk, and without these two arguments it was not: at a
    // narrow breadth it called the student's own line unreachable, and
    // unreachable is what the sweep deletes.
    const fens = new Map(branches.map((fen) => [fenKey(fen), fen]));
    const book = await coveredReplies(
      pool, userId, color, keys, band, breadth, { fens, kept });

    const next = [];
    for (const after of branches) {
      for (const reply of book.get(fenKey(after)) ?? []) {
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
    `SELECT root_fen, via_uci, breadth
       FROM repertoires WHERE user_id = $1 AND color = $2`,
    [userId, color],
  );
  // Each door with the move it goes through, and how wide that door is walked.
  // Two repertoires that share a root and differ only in their gate are two
  // doors, not one.
  return result.rows.map((row) => ({
    fen: row.root_fen, viaUci: row.via_uci, breadth: row.breadth,
  }));
}

/// The widest breadth among a set of doors.
///
/// Reachability decides what gets **deleted**, so the two errors are not the
/// same size: calling something reachable that is not leaves a dead position
/// lying about, and calling something unreachable that is not deletes work
/// somebody did. So the union walk goes as wide as the widest repertoire that
/// opens onto it, and this is never a parameter — a caller who passed a
/// narrower breadth than one of their own repertoires actually has would be
/// asking, in good faith, for exactly the second error.
function widestOf(roots) {
  let widest = BREADTHS.indexOf(DEFAULT_BREADTH);
  for (const root of roots) {
    const at = BREADTHS.indexOf(root.breadth ?? DEFAULT_BREADTH);
    if (at > widest) widest = at;
  }
  return BREADTHS[widest];
}

/// What removing one move would strand, without removing it.
///
/// Answers with the positions and how many moves in them are drafts and how
/// many are decisions, so a screen can delete the first silently and ask about
/// the second. Nothing is written.
async function orphansOfRemoving(pool, userId, {
  color, fen, uci, minRating = 0,
} = {}) {
  const roots = await rootsOf(pool, userId, color);
  if (roots.length === 0) {
    throw new RangeError('Za ovu boju nema nijednog repertoara.');
  }
  const breadth = widestOf(roots);
  const after = step(fen, uci);
  if (after === null) {
    // A move that will not replay strands nothing, because nothing was ever
    // reached through it.
    return { keys: [], drafts: 0, decisions: 0 };
  }

  // One reply expansion by hand first. `reachable` walks in whole waves — my
  // move, then the answer — so seeding it with the position *after* my move
  // lands it on a board where the student has nothing to play and it stops on
  // the spot. The position itself is stranded either way, so it goes in.
  const band = Number(minRating) || 0;
  const here = fenKey(after.fen);
  // Same rule as the walk above, and here it decides what a delete is allowed
  // to take silently: a reply outside the breadth that leads into the student's
  // own work never entered the set that gets counted, so the screen asked about
  // fewer decisions than it was about to remove.
  const kept = await keptByPosition(pool, userId, color);
  const book = await coveredReplies(
    pool, userId, color, [here], band, breadth,
    { fens: new Map([[here, after.fen]]), kept });
  const seeds = [];
  for (const reply of book.get(here) ?? []) {
    const landed = step(after.fen, reply.uci);
    if (landed !== null) seeds.push(landed.fen);
  }
  const behind = new Set([here]);
  for (const key of await reachable(pool, userId, {
    color, from: seeds, minRating, breadth,
  })) {
    behind.add(key);
  }
  // Without that move: every other way in, and the position it was played from
  // is still one of them.
  const otherwise = await reachable(pool, userId, {
    color, from: roots, minRating, breadth, without: { fen, uci },
  });

  const keys = [...behind].filter((key) => !otherwise.has(key));
  if (keys.length === 0) return { keys: [], drafts: 0, decisions: 0 };

  const counts = await pool.query(
    `SELECT COUNT(*) FILTER (WHERE source = 'auto')::int AS drafts,
            COUNT(*) FILTER (WHERE source <> 'auto')::int AS decisions
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)`,
    [userId, color, keys],
  );
  const row = counts.rows[0] ?? {};
  return {
    keys,
    drafts: row.drafts ?? 0,
    decisions: row.decisions ?? 0,
  };
}

/// Puts a primary back wherever a bulk delete took one away.
///
/// Not tidying. A position that has any moves at all **must** have a primary —
/// the drill has nothing to ask for otherwise — and a bulk delete is the one
/// path that can strip one without `removeMove` promoting the next. The oldest
/// surviving move wins, which is the same rule `removeMove` keeps.
///
/// Exported and taken as a client rather than written twice: it runs inside
/// whichever transaction did the deleting, and a second copy of a statement
/// this shape is a second place for the rule to drift.
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

/// Removes the moves in a set of positions, and puts the primary back where
/// taking one away left a position without one.
///
/// `includeDecisions` is the whole safety catch: without it only drafts go, and
/// the count of what was left behind comes back so the caller can ask.
///
/// Every key is re-checked against the roots before anything is deleted. The
/// answer to "is this still unreachable" can have changed between the question
/// and the confirmation — a spine run in another window is enough — and a
/// sweep that trusted a list from a minute ago would delete a line that is back
/// in use.
async function pruneKeys(pool, userId, {
  color, keys, includeDecisions = false, minRating = 0,
} = {}) {
  if (!Array.isArray(keys) || keys.length === 0) {
    return { removed: 0, kept: 0, promoted: 0 };
  }
  const roots = await rootsOf(pool, userId, color);
  if (roots.length === 0) {
    throw new RangeError('Za ovu boju nema nijednog repertoara.');
  }
  const breadth = widestOf(roots);

  const live = await reachable(pool, userId, {
    color, from: roots, minRating, breadth,
  });
  const stranded = keys.filter((key) => !live.has(key));
  if (stranded.length === 0) return { removed: 0, kept: 0, promoted: 0 };

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const gone = await client.query(
      `DELETE FROM repertoire_moves
        WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)
          AND ($4 = TRUE OR source = 'auto')`,
      [userId, color, stranded, includeDecisions],
    );
    const left = await client.query(
      `SELECT COUNT(*)::int AS moves FROM repertoire_moves
        WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)`,
      [userId, color, stranded],
    );
    const promoted = await promoteWhereNoPrimary(client, userId, color, stranded);
    await client.query('COMMIT');
    return {
      removed: gone.rowCount,
      kept: left.rows[0]?.moves ?? 0,
      promoted,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  reachable, orphansOfRemoving, pruneKeys, rootsOf, widestOf,
  promoteWhereNoPrimary,
};
