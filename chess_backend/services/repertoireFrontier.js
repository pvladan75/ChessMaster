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
//
// The same walk also answers "how far have I got, and where", per branch. A
// branch is one of the opponent's first answers — the Advance, the Exchange,
// the Two Knights — because in a repertoire the student's own first move is
// already decided and it is the opponent's choice that names the thing. The
// tallies are collected here rather than in a second walk, since every number
// the map needs is passing through this loop anyway.

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
///
/// `onlyChosen` leaves out the generated ones. The queue and the picture follow
/// everything — a draft you cannot reach is a draft you cannot confirm — while
/// the drill's line walk follows decisions only, because a line through a move
/// nobody chose is not the student's line.
async function keptByPosition(pool, userId, color, { onlyChosen = false } = {}) {
  const result = await pool.query(
    `SELECT fen_key, uci, san, role, source
       FROM repertoire_moves
      WHERE user_id = $1 AND color = $2
        AND ($3 = FALSE OR source = 'chosen')
      ORDER BY (role = 'primary') DESC, added_at ASC`,
    [userId, color, onlyChosen],
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
/// "this position is not decided yet", which is exactly true of a repertoire
/// whose first move has not been kept.
function gateMoves(kept, rootKey, gateUci) {
  if (!gateUci) return kept;
  const here = kept.get(rootKey);
  if (here === undefined) return kept;
  kept.set(rootKey, here.filter((move) => move.uci === gateUci));
  return kept;
}

/// The book for a whole level of the walk, in one query.
///
/// The covered moves, plus the ones this student asked for by name. The table
/// also holds the rest of the tail — everything the explorer returned past the
/// 80% cut — and neither the frontier nor the drill follows it. Following the
/// whole tail would grow the queue by moves the build loop never enqueued, and
/// hand back a walk that does not match the one the student was actually on.
///
/// The drill used to draw its opponent from the whole tail, so that meeting an
/// uncovered move showed the student the edge of what they prepared. It no
/// longer does (`pickReply`), which makes the live opponent and this walk agree
/// — they disagreed, and the rehearsal was the one that was right.
///
/// The exception is the point of `repertoire_extra_replies`. A move the student
/// pressed "prepare this too" on **was** enqueued, so the walk has to follow it
/// — otherwise the position is asked once, and closing the screen loses it. It
/// is also why that decision is stored per student rather than by flipping
/// `covered`, which is everybody's.
async function coveredReplies(pool, userId, color, keys, minRating) {
  if (keys.length === 0) return new Map();
  const result = await pool.query(
    `SELECT r.fen_key, r.uci, r.san, r.games, r.share
       FROM opening_replies r
      WHERE r.min_rating = $1 AND r.fen_key = ANY($2)
        AND (r.covered = TRUE OR EXISTS (
              SELECT 1 FROM repertoire_extra_replies e
               WHERE e.user_id = $3 AND e.color = $4
                 AND e.fen_key = r.fen_key AND e.uci = r.uci))
      ORDER BY r.games DESC`,
    [minRating, keys, userId, color],
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
  color, rootFen, rootPath = [], minRating = 0, limit = 200, gateUci = null,
} = {}) {
  if (color !== 'w' && color !== 'b') {
    throw new RangeError(`Boja mora biti "w" ili "b", a ne "${color}".`);
  }
  // Throws on a broken FEN, which is right: a walk from nowhere is not an empty
  // answer, it is a bad request.
  fenKey(rootFen);

  const kept = gateMoves(
    await keptByPosition(pool, userId, color), fenKey(rootFen), gateUci);
  const cut = await skippedKeys(pool, userId, color);
  const band = Number(minRating) || 0;
  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];

  const open = [];
  const pruned = [];
  // One tally per opponent first answer, keyed by the pair of moves that opens
  // it — the student's own move and the reply — because a repertoire may keep
  // more than one first move and "2...d6" then means two different branches.
  const branches = new Map();

  /// The tally a node belongs to, made on first sight.
  const tallyFor = (node) => {
    if (node.branch === undefined) return null;
    let tally = branches.get(node.branch.key);
    if (tally === undefined) {
      tally = {
        key: node.branch.key,
        path: node.branch.path,
        fen: node.branch.fen,
        // How often the opponent goes this way at all. Kept apart from
        // everything below it: a branch played in one game in twenty is not
        // urgent however unfinished it is, and a branch played in half of them
        // is urgent even when it is nearly done.
        share: node.branch.share,
        decided: 0,
        draft: 0,
        undecided: 0,
        unopened: 0,
        pruned: 0,
        openReach: 0,
        prunedReach: 0,
        maxPly: 0,
      };
      branches.set(node.branch.key, tally);
    }
    return tally;
  };
  const seen = new Set([fenKey(rootFen)]);
  let level = [{ fen: rootFen, path: [], reach: 1 }];
  let ply = 0;
  let nodes = 1;
  let decided = 0;
  let draft = 0;
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
      const tally = tallyFor(node);
      if (tally !== null) tally.maxPly = Math.max(tally.maxPly, node.path.length);
      // Cut on purpose. Counted as cut and as nothing else: the walk stops
      // here, so this is neither a question that is open nor a position the
      // walk passed through, and a header whose numbers overlap is a header
      // nobody can add up.
      if (cut.has(fenKey(node.fen))) {
        pruned.push(node);
        if (tally !== null) {
          tally.pruned += 1;
          tally.prunedReach += node.reach;
        }
        continue;
      }
      const mine = kept.get(fenKey(node.fen)) ?? [];
      if (mine.length === 0) {
        open.push({ ...node, kind: 'undecided' });
        if (tally !== null) {
          tally.undecided += 1;
          tally.openReach += node.reach;
        }
        continue;
      }
      // Decided by the student, or still a draft somebody generated. Counted
      // apart and never added together: a map that called a spine "prepared"
      // would be the seed's lie with a better source.
      const chosen = mine.some((move) => move.source !== 'auto');
      if (chosen) {
        decided += 1;
      } else {
        draft += 1;
      }
      if (tally !== null) {
        if (chosen) {
          tally.decided += 1;
        } else {
          tally.draft += 1;
        }
      }
      for (const move of mine) {
        const after = step(node.fen, move.uci);
        if (after === null) continue;
        branches.push({ node, after });
      }
    }

    const keys = [...new Set(branches.map((b) => fenKey(b.after.fen)))];
    const book = await coveredReplies(pool, userId, color, keys, band);

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
        const path = [...branch.node.path, branch.after.san, landed.san];
        const reach = branch.node.reach * (reply.share > 0 ? reply.share : 0);
        next.push({
          fen: landed.fen,
          path,
          reach,
          // Children of the root open a branch; everything deeper inherits the
          // one it is in. A transposition keeps the branch it was first reached
          // through, which is the same first-wins rule the queue itself keeps.
          branch: branch.node.branch ?? {
            key: `${branch.after.san} ${landed.san}`,
            path: [branch.after.san, landed.san],
            fen: landed.fen,
            share: reach,
          },
        });
      }
      if (truncated) break;
    }
    for (const node of dangling) {
      unopened += 1;
      open.push({ ...node, kind: 'unopened' });
      const tally = tallyFor(node);
      if (tally !== null) {
        tally.unopened += 1;
        tally.openReach += node.reach;
      }
    }

    level = next;
    ply += 2;
  }

  // Most-reached first, and among equals the shallower one: two positions a
  // student is equally likely to meet are not equally urgent, and the one
  // closer to the start decides more games.
  // The root itself is in no branch — it is the position every branch leaves
  // from — so a repertoire with nothing decided at the root has an empty map
  // and one open question, which is exactly the truth about it.
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
    // The coverage map: how far each of the opponent's first answers has been
    // taken. Most played first, because that is the order they are worth
    // finishing in — not the order they were built.
    branches: [...branches.values()]
      .sort((a, b) => b.share - a.share)
      .map((tally) => ({
        ...tally,
        open: tally.undecided + tally.unopened,
        // What share of the games that come down *this* branch run into a
        // position with no answer. Divided by the branch's own share on
        // purpose: measured against the whole repertoire, a rare sideline
        // would read as almost finished merely because few games go there.
        openWithin: tally.share > 0
          ? Math.min(1, tally.openReach / tally.share)
          : 0,
        prunedWithin: tally.share > 0
          ? Math.min(1, tally.prunedReach / tally.share)
          : 0,
      })),
    summary: {
      decided,
      // Positions whose every move was generated and none confirmed. Its own
      // number, beside `decided` rather than inside it.
      draft,
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

// The three pieces of the walk are exported as well as the walk itself. The
// line drill needs the same two queries and the same "advance one move" over a
// different question, and a second copy of any of them is a second place for
// the rule to drift — which is how three hand-written copies of one subquery
// all managed to forget the same status check.
module.exports = {
  gateMoves,
  frontier,
  step,
  keptByPosition,
  coveredReplies,
  MAX_NODES,
  MAX_PLY,
};
