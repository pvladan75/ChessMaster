// repertoireFrontier.js — where the student actually is, derived and never stored.
//
// The build screen used to keep its queue in memory: close it and the walk was
// gone, so reopening a repertoire started at the root and re-fetched every
// reply that had already been paid for. Nothing about that queue was worth
// storing, because it is not a fact — it is a *consequence* of two tables that
// are already there:
//
//   * `repertoire_moves` — what the student decided, per position.
//   * `opening_replies`  — what the opponent plays there, written down when the
//     position was first opened and shared by everyone afterwards.
//
// Walking those two gives the queue back exactly, and gives it back the same on
// any device, after any crash, for free. **No Lichess request is made here at
// any point**, which is the rule the drill already keeps: building spends the
// allowance, everything that reads what was built spends nothing.
//
// Two kinds of position come out of the walk, and both are questions the build
// screen can already ask:
//
//   * `undecided` — your move, and you have kept nothing here. Play something.
//   * `unopened`  — your move, you have kept something, but at least one of
//     your moves has no book behind it, so the line stops. Take the replies.
//
// And one kind that comes out of the walk without being a question: a position
// the student **cut** (`repertoire_skips`). The walk stops there and hands it
// back separately, because a cut branch must not read as progress. Dropping it
// silently would let `openReach` fall — "less of your games run into an
// unanswered position" — when nothing has been answered at all.
//
// Everything else is either answered or below the cut, and neither is a place
// the student needs to be taken back to.

const { Chess } = require('chess.js');
const { fenKey, skippedKeys } = require('./repertoireService');

/// Ceilings, so a wide repertoire cannot turn one request into a minute of
/// database time. Hit either and the answer says `truncated`, because a
/// silently shortened walk is the bug this codebase keeps meeting.
const MAX_NODES = 4000;
const MAX_PLY = 60;

/// Advances a position by one UCI move, or answers null if it will not go.
///
/// Null rather than a throw: a stored move that no longer fits its position is
/// a broken branch, not a broken request, and the rest of the walk is still
/// worth having.
function step(fen, uci) {
  try {
    const board = new Chess(fen);
    const played = board.move({
      from: uci.slice(0, 2),
      to: uci.slice(2, 4),
      promotion: uci.length > 4 ? uci[4] : undefined,
    });
    if (!played) return null;
    return { fen: board.fen(), san: played.san };
  } catch {
    return null;
  }
}

/// Every move this student has decided on for this colour, keyed by position.
///
/// One query rather than one per node. A repertoire is a few hundred rows at
/// the outside and the walk touches most of them; asking the database node by
/// node would make the request quadratic in the thing it is measuring.
async function keptByPosition(pool, userId, color) {
  const result = await pool.query(
    `SELECT fen_key, uci, san, role
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2
      ORDER BY (role = 'primary') DESC, added_at ASC`,
    [userId, color],
  );
  const map = new Map();
  for (const row of result.rows) {
    const list = map.get(row.fen_key) ?? [];
    list.push({ uci: row.uci, san: row.san, role: row.role });
    map.set(row.fen_key, list);
  }
  return map;
}

/// The book for a whole level of the walk, in one query.
///
/// Only the covered moves. The table also holds the tail — everything the
/// explorer returned past the 80% cut — and the drill draws from all of it on
/// purpose, so the student meets the edge of what they prepared. A *frontier*
/// must not: following the tail would grow the queue by moves the build loop
/// never enqueued, and hand back a walk that does not match the one the student
/// was actually on.
async function coveredReplies(pool, keys, minRating) {
  if (keys.length === 0) return new Map();
  const result = await pool.query(
    `SELECT fen_key, uci, san, games, share
       FROM opening_replies
      WHERE min_rating = $1 AND fen_key = ANY($2) AND covered = TRUE
      ORDER BY games DESC`,
    [minRating, keys],
  );
  const map = new Map();
  for (const row of result.rows) {
    const list = map.get(row.fen_key) ?? [];
    list.push({ uci: row.uci, san: row.san, share: Number(row.share) });
    map.set(row.fen_key, list);
  }
  return map;
}

/// The positions still waiting for the student, most-reached first.
///
/// `reach` is the product of the opponent's shares along the path: how often a
/// game played down this repertoire actually arrives here. It is the ordering,
/// and it is why the answer goes down the main line before it goes wide —
/// 1.e4 c5 2.Nf3 d6 3.d4 at 0.21 outranks a third-choice sideline at move two,
/// and keeps outranking it until the main line's own probability has decayed
/// far enough. Breadth-first and depth-first are both guesses at this number.
/// This is the number.
///
/// The student's own moves do not divide it. Which of their moves they play is
/// a decision, not a coin, so an alternate carries the same reach as the
/// primary — read it as "if you play this, how often do you land here".
async function frontier(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, limit = 200,
} = {}) {
  if (color !== 'w' && color !== 'b') {
    throw new RangeError(`Boja mora biti "w" ili "b", a ne "${color}".`);
  }
  // Throws on a broken FEN, which is right: a walk from nowhere is not an empty
  // answer, it is a bad request.
  fenKey(rootFen);

  const kept = await keptByPosition(pool, userId, color);
  const cut = await skippedKeys(pool, userId, color);
  const band = Number(minRating) || 0;
  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];

  const open = [];
  const pruned = [];
  const seen = new Set([fenKey(rootFen)]);
  let level = [{ fen: rootFen, path: [], reach: 1 }];
  let ply = 0;
  let nodes = 1;
  let decided = 0;
  let unopened = 0;
  let maxPly = 0;
  let truncated = false;

  while (level.length > 0 && ply < MAX_PLY && !truncated) {
    // Every position on this level the student has answered, paired with where
    // their answer leads — collected first so the whole level asks the book in
    // one query instead of one per branch.
    const branches = [];
    for (const node of level) {
      // Counted for every node the walk reaches, answered or not: how deep the
      // repertoire *goes* is the question, and stopping the count at the last
      // decided position would report the depth of the second-to-last wave.
      maxPly = Math.max(maxPly, node.path.length);
      // Cut on purpose. Counted as cut and as nothing else: the walk stops
      // here, so this is neither a question that is open nor a position the
      // walk passed through, and a header whose numbers overlap is a header
      // nobody can add up.
      if (cut.has(fenKey(node.fen))) {
        pruned.push(node);
        continue;
      }
      const mine = kept.get(fenKey(node.fen)) ?? [];
      if (mine.length === 0) {
        open.push({ ...node, kind: 'undecided' });
        continue;
      }
      decided += 1;
      for (const move of mine) {
        const after = step(node.fen, move.uci);
        if (after === null) continue;
        branches.push({ node, after });
      }
    }

    const keys = [...new Set(branches.map((b) => fenKey(b.after.fen)))];
    const book = await coveredReplies(pool, keys, band);

    const next = [];
    const dangling = new Set();
    for (const branch of branches) {
      const replies = book.get(fenKey(branch.after.fen)) ?? [];
      if (replies.length === 0) {
        // Decided, but the opponent's side was never taken. The position that
        // needs the student back is the one *before* their move, because that
        // is the board the build screen puts up and where its button lives.
        dangling.add(branch.node);
        continue;
      }
      for (const reply of replies) {
        const landed = step(branch.after.fen, reply.uci);
        if (landed === null) continue;
        const key = fenKey(landed.fen);
        if (seen.has(key)) continue;
        seen.add(key);
        nodes += 1;
        if (nodes > MAX_NODES) {
          truncated = true;
          break;
        }
        next.push({
          fen: landed.fen,
          path: [...branch.node.path, branch.after.san, landed.san],
          reach: branch.node.reach * (reply.share > 0 ? reply.share : 0),
        });
      }
      if (truncated) break;
    }
    for (const node of dangling) {
      unopened += 1;
      open.push({ ...node, kind: 'unopened' });
    }

    level = next;
    ply += 2;
  }

  // Most-reached first, and among equals the shallower one: two positions a
  // student is equally likely to meet are not equally urgent, and the one
  // closer to the start decides more games.
  open.sort((a, b) => (b.reach - a.reach) || (a.path.length - b.path.length));
  pruned.sort((a, b) => (b.reach - a.reach) || (a.path.length - b.path.length));

  return {
    // The moves that led to the repertoire's own root, handed back once here
    // rather than repeated on every node. Each node's path starts at the root;
    // the screen joins the two for a breadcrumb that reads from move one.
    root: { fen: rootFen, path: base },
    open: open.slice(0, limit).map((node) => ({
      fen: node.fen,
      fenKey: fenKey(node.fen),
      path: node.path,
      ply: node.path.length,
      reach: node.reach,
      kind: node.kind,
    })),
    // The cut branches, handed back so they can be put back. A prune the
    // student cannot find again is not a decision, it is a hole they made and
    // then lost.
    pruned: pruned.slice(0, limit).map((node) => ({
      fen: node.fen,
      fenKey: fenKey(node.fen),
      path: node.path,
      ply: node.path.length,
      reach: node.reach,
      kind: 'pruned',
    })),
    summary: {
      decided,
      open: open.length,
      undecided: open.length - unopened,
      unopened,
      maxPly,
      // What share of the games arriving in this repertoire runs into a
      // position with no answer yet. The one number that says how finished it
      // is, and the only one that does not flatter a wide shallow tree.
      openReach: open.reduce((sum, node) => sum + node.reach, 0),
      pruned: pruned.length,
      // Reported beside `openReach` and never subtracted from it, because these
      // two numbers say opposite things: one is work left, the other is work
      // refused. Cutting a branch makes `openReach` fall, and only this number
      // says the games in it are still going to be played.
      prunedReach: pruned.reduce((sum, node) => sum + node.reach, 0),
      truncated,
    },
  };
}

module.exports = { frontier, MAX_NODES, MAX_PLY };
