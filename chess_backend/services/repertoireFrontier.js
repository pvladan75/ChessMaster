// repertoireFrontier.js — where the student actually is, derived and never stored.
//
// A repertoire is two tables and nothing else (docs/PLAN-REPERTOAR-RUCNO.md):
//
//   * `repertoire_moves`         — the student's own moves, per position.
//   * `repertoire_extra_replies` — the opponent's moves the student entered:
//     the book's most played reply, entered with the student's move, and every
//     other one played by hand on the board.
//
// **The book decides nothing here.** `opening_replies` is read beside the
// entered moves only for how often each is played, which is a number for the
// card and for the drill's draw. A move the book does not know is followed like
// any other, with a share of 0. Until 15.9.2026 the opponent's side was read
// out of the book at a breadth, which put moves in the tree the student had
// never gone through — the thing this model exists to stop.
//
// One kind of position comes out of the walk as a question: `undecided` — the
// student is to move after an entered opponent move and has kept nothing. A
// move of the student's with no reply entered after it is the end of that
// line, not a question.

const { Chess } = require('chess.js');
const { BOOK_BAND, BOOK_SOURCE } = require('./storedReplies');
const { fenKey } = require('./repertoireService');

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
/// One query rather than one per node: asking the database node by node would
/// make the request quadratic in the thing it is measuring.
///
/// Decisions only. A row written as a draft by the retired spine is not a move
/// anybody played, and nothing may walk through it.
async function keptByPosition(pool, userId, color) {
  const result = await pool.query(
    `SELECT fen_key, uci, san, role, source
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2 AND source = 'chosen'
      ORDER BY (role = 'primary') DESC, added_at ASC`,
    [userId, color],
  );
  const map = new Map();
  for (const row of result.rows) {
    const list = map.get(row.fen_key) ?? [];
    list.push({
      uci: row.uci, san: row.san, role: row.role, source: row.source,
    });
    map.set(row.fen_key, list);
  }
  return map;
}

/// The opponent's moves the student entered, for a whole level of the walk.
///
/// One query per level. The book is joined for its numbers and nothing else —
/// a LEFT JOIN, so an entered move the book has never seen is still a row, with
/// 0 games and a share of 0. Most played first, then the order they were
/// entered, so two moves the book cannot separate keep one order.
async function enteredReplies(pool, userId, color, keys) {
  if (keys.length === 0) return new Map();
  const result = await pool.query(
    `SELECT e.fen_key, e.uci, e.san,
            COALESCE(r.games, 0) AS games, COALESCE(r.share, 0) AS share
       FROM repertoire_extra_replies e
       LEFT JOIN opening_replies r
         ON r.fen_key = e.fen_key AND r.uci = e.uci
        AND r.min_rating = $4 AND r.source = $5
      WHERE e.user_id = $1 AND e.color = $2 AND e.fen_key = ANY($3)
      ORDER BY COALESCE(r.games, 0) DESC, e.created_at ASC, e.uci ASC`,
    [userId, color, keys, BOOK_BAND, BOOK_SOURCE],
  );
  const map = new Map();
  for (const row of result.rows) {
    const list = map.get(row.fen_key) ?? [];
    list.push({
      uci: row.uci,
      san: row.san,
      games: Number(row.games) || 0,
      share: Number(row.share) || 0,
    });
    map.set(row.fen_key, list);
  }
  return map;
}

/// Narrows what the student holds at one position to a single move.
///
/// The **gate**: a repertoire that starts where another one starts follows only
/// its own move out of that position. Everything downstream — the queue, the
/// tree, the drill, the coverage map — is a walk, so filtering the walk's
/// starting fork is the whole implementation of "show me this opening only".
///
/// Mutates the map it is given, which is a fresh one per read
/// (`keptByPosition` builds it), and answers it back so a caller can chain.
///
/// A gate whose move is not among the kept ones leaves the position **empty**
/// rather than untouched: that is the honest state, and it reads on screen as
/// "this position is not decided yet".
function gateMoves(kept, rootKey, gateUci) {
  if (!gateUci) return kept;
  const here = kept.get(rootKey);
  if (here === undefined) return kept;
  kept.set(rootKey, here.filter((move) => move.uci === gateUci));
  return kept;
}

/// The positions still waiting for the student, and how far each of the
/// opponent's first answers has been taken.
///
/// Walked level by level — the student's moves, then the replies entered after
/// them — so the open positions come back shallower first, in the order the
/// walk met them. Counts only: how often a position is reached is not a number
/// this model can honestly produce, because the opponent's side is what the
/// student chose to prepare rather than what the book says is played.
async function frontier(pool, userId, {
  color, rootFen, rootPath = [], limit = 200, gateUci = null,
} = {}) {
  if (color !== 'w' && color !== 'b') {
    throw new RangeError(`Color must be "w" or "b", not "${color}".`);
  }
  // Throws on a broken FEN, which is right: a walk from nowhere is not an empty
  // answer, it is a bad request.
  fenKey(rootFen);

  const kept = gateMoves(
    await keptByPosition(pool, userId, color), fenKey(rootFen), gateUci);
  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];

  const open = [];
  // One tally per opponent first answer, keyed by the pair of moves that opens
  // it — the student's own move and the reply — because a repertoire may keep
  // more than one first move and "2...d6" then means two different branches.
  const branches = new Map();
  const tallyFor = (node) => {
    if (node.branch === undefined) return null;
    let tally = branches.get(node.branch.key);
    if (tally === undefined) {
      tally = {
        key: node.branch.key,
        path: node.branch.path,
        fen: node.branch.fen,
        share: node.branch.share,
        decided: 0,
        open: 0,
        maxPly: 0,
        found: branches.size,
      };
      branches.set(node.branch.key, tally);
    }
    return tally;
  };

  const seen = new Set([fenKey(rootFen)]);
  let level = [{ fen: rootFen, path: [] }];
  let ply = 0;
  let nodes = 1;
  let decided = 0;
  let maxPly = 0;
  let truncated = false;

  while (level.length > 0 && ply < MAX_PLY && !truncated) {
    const moves = [];
    for (const node of level) {
      maxPly = Math.max(maxPly, node.path.length);
      const tally = tallyFor(node);
      if (tally !== null) tally.maxPly = Math.max(tally.maxPly, node.path.length);
      const mine = kept.get(fenKey(node.fen)) ?? [];
      if (mine.length === 0) {
        open.push(node);
        if (tally !== null) tally.open += 1;
        continue;
      }
      decided += 1;
      if (tally !== null) tally.decided += 1;
      for (const move of mine) {
        const after = step(node.fen, move.uci);
        if (after !== null) moves.push({ node, after });
      }
    }

    const keys = [...new Set(moves.map((m) => fenKey(m.after.fen)))];
    const replies = await enteredReplies(pool, userId, color, keys);

    const next = [];
    for (const { node, after } of moves) {
      for (const reply of replies.get(fenKey(after.fen)) ?? []) {
        const landed = step(after.fen, reply.uci);
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
          path: [...node.path, after.san, landed.san],
          // Children of the root open a branch; everything deeper inherits the
          // one it is in. A transposition keeps the branch it was first reached
          // through, which is the same first-wins rule the queue itself keeps.
          branch: node.branch ?? {
            key: `${after.san} ${landed.san}`,
            path: [after.san, landed.san],
            fen: landed.fen,
            share: reply.share,
          },
        });
      }
      if (truncated) break;
    }

    level = next;
    ply += 2;
  }

  return {
    // The moves that led to the repertoire's own root, handed back once here
    // rather than repeated on every node.
    root: { fen: rootFen, path: base },
    open: open.slice(0, limit).map((node) => ({
      fen: node.fen,
      fenKey: fenKey(node.fen),
      path: node.path,
      ply: node.path.length,
      kind: 'undecided',
    })),
    // Most played first, then the order the walk found them in — an off-book
    // reply the student entered has a share of 0 and still gets its row.
    branches: [...branches.values()]
      .sort((a, b) => (b.share - a.share) || (a.found - b.found))
      .map(({ found, ...tally }) => tally),
    summary: {
      decided,
      open: open.length,
      maxPly,
      truncated,
    },
  };
}

// The pieces of the walk are exported as well as the walk itself. The line
// drill, the orphan sweep and the drill's opponent need the same queries and
// the same "advance one move", and a second copy of any of them is a second
// place for the rule to drift.
module.exports = {
  gateMoves,
  frontier,
  step,
  keptByPosition,
  enteredReplies,
  MAX_NODES,
  MAX_PLY,
};
