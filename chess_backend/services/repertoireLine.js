// repertoireLine.js — drilling a line rather than a position.
//
// The drill used to drop the student onto a bare board: a position with no
// history, four moves deep into something, and no way to tell how it arose. It
// is the right question and the wrong way to arrive at it. A repertoire is
// played forwards, from the first move, and the memory that matters is the one
// that runs *along* a line, not the one that recognises a photograph of its
// end.
//
// Three things this file adds, all of them one idea:
//
//   * **The line is replayed before the question is asked.** The student plays
//     their own moves from the start of the line and the opponent's answers
//     come back at them, until the board is standing in the position that is
//     actually due.
//   * **The replay starts at the last position they know cold**, not at move
//     one. Twelve plies of rehearsal to reach one question is how a drill
//     stops being opened. `KNOWN_REPETITIONS` is the threshold, and it is the
//     same number the empty screen already calls "known".
//   * **One branch can be drilled on its own** (`fromFen`), which is what makes
//     the thing usable the day after a build session: the ten positions just
//     built are a block, and a block is what somebody sits down to practise.
//
// **The replayed moves are not graded.** This is the rule the whole design
// rests on. A prefix is played many times a day on the way to whatever is due
// below it; grading it would push those positions' intervals out on the
// strength of rehearsals the student never had to remember cold, and the
// schedule would quietly become a fiction. Only the position at the end of the
// line is answered, and only it is scheduled.
//
// **No Lichess request is made here**, like everything else that reads what was
// built. The walk is `repertoire_moves` and `opening_replies`, the same two
// tables the frontier derives its queue from — and the same three helpers,
// imported rather than copied.

const {
  step,
  keptByPosition,
  coveredReplies,
  MAX_NODES,
  MAX_PLY,
} = require('./repertoireFrontier');
const { fenKey, skippedKeys } = require('./repertoireService');
const {
  nextItem,
  drillStats,
  KNOWN_REPETITIONS,
} = require('./repertoireDrillService');

/// Every position in the repertoire, with the moves that lead to it.
///
/// Positions where the *student* is to move, which is every position that can
/// be a question. Each node carries the whole line from the root: the moves are
/// what the replay plays, and the path is what the breadcrumb reads.
///
/// Breadth first, and the first line to reach a position wins. That matters
/// where a position can be reached two ways: the shortest one is the honest
/// rehearsal, and `keptByPosition` hands the primary back first, so the line
/// that wins is the one through the moves the student actually settled on.
///
/// Cut branches are not walked. A line the student refused to prepare is not a
/// line to be rehearsed down.
async function walkLines(pool, userId, { color, rootFen, minRating = 0 } = {}) {
  if (color !== 'w' && color !== 'b') {
    throw new RangeError(`Boja mora biti "w" ili "b", a ne "${color}".`);
  }
  fenKey(rootFen);

  const kept = await keptByPosition(pool, userId, color);
  const cut = await skippedKeys(pool, userId, color);
  const band = Number(minRating) || 0;

  const rootKey = fenKey(rootFen);
  const root = {
    key: rootKey, fen: rootFen, parent: null, ply: 0, path: [], moves: [],
  };
  const nodes = new Map([[rootKey, root]]);

  let level = [root];
  let ply = 0;
  let count = 1;
  let truncated = false;

  while (level.length > 0 && ply < MAX_PLY && !truncated) {
    const branches = [];
    for (const node of level) {
      if (cut.has(node.key)) continue;
      for (const move of kept.get(node.key) ?? []) {
        const after = step(node.fen, move.uci);
        if (after === null) continue;
        branches.push({ node, uci: move.uci, after });
      }
    }

    const keys = [...new Set(branches.map((b) => fenKey(b.after.fen)))];
    const book = await coveredReplies(pool, keys, band);

    const next = [];
    for (const branch of branches) {
      for (const reply of book.get(fenKey(branch.after.fen)) ?? []) {
        const landed = step(branch.after.fen, reply.uci);
        if (landed === null) continue;
        const key = fenKey(landed.fen);
        if (nodes.has(key)) continue;
        count += 1;
        if (count > MAX_NODES) {
          truncated = true;
          break;
        }
        const child = {
          key,
          fen: landed.fen,
          parent: branch.node.key,
          ply: branch.node.ply + 2,
          path: [...branch.node.path, branch.after.san, landed.san],
          // The moves of the line, in order, each one saying whose it is. This
          // is what the replay plays: the student is asked for theirs and the
          // opponent's are answered back at them.
          moves: [
            ...branch.node.moves,
            { uci: branch.uci, san: branch.after.san, mine: true },
            { uci: reply.uci, san: landed.san, mine: false },
          ],
        };
        nodes.set(key, child);
        next.push(child);
      }
      if (truncated) break;
    }

    level = next;
    ply += 2;
  }

  return { nodes, root, truncated };
}

/// The keys from the root down to a node, the node itself last.
function chainTo(nodes, key) {
  const chain = [];
  let at = key;
  while (at != null && nodes.has(at)) {
    chain.unshift(at);
    at = nodes.get(at).parent;
  }
  return chain;
}

/// Every position at or under one node.
///
/// This is the block. Ancestry is read off the parent links rather than off the
/// paths, because two positions can share a prefix of moves without one being
/// under the other — a repertoire is a graph, and a line that transposes back
/// into an earlier one would otherwise be counted into a branch it left.
function subtree(nodes, fromKey) {
  const inside = [];
  for (const key of nodes.keys()) {
    if (chainTo(nodes, key).includes(fromKey)) inside.push(key);
  }
  return inside;
}

/// One line to rehearse, and the question at the end of it.
///
/// `question` is null when nothing is waiting — which the screen must tell
/// apart from a walk that found nothing at all, so `reason` names which of the
/// two it is.
async function drillLine(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, fromFen = null,
  now = new Date(),
} = {}) {
  const { nodes, root, truncated } = await walkLines(pool, userId, {
    color, rootFen, minRating,
  });

  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];

  let within = null;
  let from = null;
  if (fromFen != null && String(fromFen).trim() !== '') {
    from = fenKey(fromFen);
    // A position the walk never reached — cut since, or built under a move that
    // is no longer kept. An empty block rather than a 400: the request was
    // well formed, and "there is nothing there any more" is the answer.
    within = nodes.has(from) ? subtree(nodes, from) : [];
  }

  const keys = within ?? [...nodes.keys()];
  const stats = await drillStats(pool, userId, { color, now, only: within });
  const item = await nextItem(pool, userId, { color, now, only: keys });

  if (item === null) {
    return {
      root: { fen: rootFen, path: base },
      from,
      question: null,
      reason: stats.positions === 0 ? 'nothing-built' : 'nothing-due',
      start: null,
      prefix: [],
      stats,
      truncated,
    };
  }

  const target = nodes.get(item.fenKey);
  const chain = chainTo(nodes, item.fenKey);
  // Everything above the question. The question's own review says nothing about
  // where the rehearsal should begin — it is the thing being asked.
  const above = chain.slice(0, -1);

  let start = target;
  if (above.length > 0) {
    const known = await pool.query(
      `SELECT fen_key, repetitions FROM repertoire_reviews
        WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)
          AND repetitions >= $4`,
      [userId, color, above, KNOWN_REPETITIONS],
    );
    const solid = new Set(known.rows.map((row) => row.fen_key));
    // The deepest one, so the rehearsal is as short as the student has earned.
    // Falling back to the root rather than to the question: a line with nothing
    // known in it is exactly the line worth playing from the beginning.
    const deepest = [...above].reverse().find((key) => solid.has(key));
    start = nodes.get(deepest ?? above[0]) ?? root;
  }

  return {
    // Handed back once rather than repeated on every move, the way the frontier
    // does it: each path starts at the repertoire's root and the screen joins
    // the two for a line that reads from move one.
    root: { fen: rootFen, path: base },
    from,
    start: {
      fen: start.fen,
      fenKey: start.key,
      path: start.path,
      ply: start.ply,
      // Whether the rehearsal was shortened because the student knows this far,
      // or simply begins where the repertoire does. Two different sentences on
      // screen, and only one of them is something they earned.
      known: start.key !== root.key,
    },
    // The moves between the start and the question, in order. The student's own
    // are asked for and *not* graded: a prefix is replayed many times a day on
    // the way to whatever is due below it, and grading it would push those
    // positions out on rehearsals nobody had to remember cold.
    prefix: target.moves.slice(start.moves.length),
    question: {
      ...item,
      // The real position rather than the one rebuilt from the key: the walk
      // arrived here by playing moves, so it knows the true move numbers, and a
      // board that says "move 1" four moves in is a small lie with no upside.
      fen: target.fen,
      path: target.path,
      ply: target.ply,
    },
    stats,
    truncated,
  };
}

module.exports = { drillLine, walkLines, chainTo, subtree };
