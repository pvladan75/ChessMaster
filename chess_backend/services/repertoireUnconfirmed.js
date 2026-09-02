// repertoireUnconfirmed.js — the drafts nobody has answered for yet.
//
// A spine writes moves the student did not choose. That is the point of it —
// twelve questions before an opening looks like one is how the build loop lost
// its first user — and `source = 'auto'` is what makes it safe: a draft is
// drawn, walked through, and **never asked about by the drill**. Confirming is
// an act.
//
// The act existed and the queue for it did not. `confirmNode` and `confirmLine`
// have been there since the spine was, reachable one position at a time from
// whichever board happened to be on screen, so the honest answer to "what have
// I still not agreed to?" was to open the tree and read it. This file is that
// question asked once.
//
// Two reads, and they are deliberately different shapes:
//
//   * `unconfirmedPositions` **walks**. It is gate-aware and breadth-aware and
//     hands each position back with the line that reaches it, because the
//     review is a walk down the repertoire and a draft with no path is a board
//     with no story. This is what the workspace banner and the wizard read.
//   * `unconfirmedCounts` **counts**, per colour, in one query for every
//     repertoire at once. This is what the list screen's cards read, and it is
//     the same shape as the "N poteza u grafu" already on them — per colour,
//     because that is where moves live. Walking per card would make the
//     most-opened screen in the app the slowest one.
//
// The two do not always agree, and that is not a bug to be fixed by making one
// of them wrong. The card says how many drafts this colour holds; the banner
// says how many this repertoire's own walk reaches. A draft under a cut branch,
// or outside the gate, is in the first number and not the second — and the
// screen that has room for a sentence is the one that gets the exact number.

const { walkLines } = require('./repertoireLine');
const { requireColor, DEFAULT_BREADTH } = require('./repertoireService');

/// A position is unconfirmed when it holds moves and **none of them is the
/// student's**.
///
/// The same rule the coverage map already calls `draft`, said once more here so
/// the two cannot drift: a position with a decision in it has been answered
/// for, whatever else is lying beside it. An `auto` alternate next to a chosen
/// primary is scaffolding under a decision, not a question — putting it in the
/// review would ask somebody to re-confirm a move they made themselves.
function draftsAt(moves) {
  if (moves.length === 0) return null;
  if (moves.some((move) => move.source !== 'auto')) return null;
  return moves.map((move) => ({
    uci: move.uci, san: move.san, role: move.role,
  }));
}

/// The unconfirmed positions, in the order the walk meets them.
///
/// Walk order, not reach order. The review is played forwards — the wizard puts
/// up a board, shows the drafted move and asks — and a spine is a trunk, so
/// walking it is walking down the line the student will actually play. Sorting
/// by how often a position is reached is right for "where should I work next",
/// which is the queue's question and not this one.
///
/// Cut branches are left out, and it takes two facts rather than one.
/// `walkLines` does not walk *past* a cut, so nothing behind one is ever
/// reached — but the cut position itself was added to `nodes` on the wave
/// before, and it is the very position the student refused to prepare. Its
/// drafts are what "do not ask me about this branch" was said about, so the
/// walk's own `cut` set is read here and those nodes are dropped.
///
/// A branch the student refused must not come back as a list of things to agree
/// to; the drafts in it stay where they are, and putting the branch back puts
/// them back in the review with it.
async function unconfirmedPositions(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, gateUci = null,
  breadth = DEFAULT_BREADTH, limit = 200,
} = {}) {
  requireColor(color);
  const { nodes, kept, cut, truncated } = await walkLines(pool, userId, {
    color,
    rootFen,
    minRating,
    gateUci,
    breadth,
    // Drafts are exactly what is being looked for, so the walk has to follow
    // them: `onlyChosen` would hide every position this read exists for, and
    // would also stop the walk dead at the first drafted move.
    onlyChosen: false,
  });

  const found = [];
  for (const node of nodes.values()) {
    if (cut.has(node.key)) continue;
    const drafts = draftsAt(kept.get(node.key) ?? []);
    if (drafts === null) continue;
    found.push({
      fen: node.fen,
      fenKey: node.key,
      // From the repertoire's root, like every other walk here; the root's own
      // path is handed back once, below, and the screen joins the two.
      path: node.path,
      ply: node.ply,
      moves: drafts,
    });
  }

  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];
  const ceiling = Math.min(Math.max(1, Number(limit) || 200), 500);

  return {
    root: { fen: rootFen, path: base },
    positions: found.slice(0, ceiling),
    // How many there are, not how many were sent. A banner that counted the
    // page it was given would say "12" forever on a repertoire with three
    // hundred drafts in it.
    total: found.length,
    truncated,
  };
}

/// How many drafts each colour holds, in one query for the whole list.
///
/// No gate, no root, no walk — see the note at the top of the file. The card
/// needs a number it can put on a badge and the list screen draws every card at
/// once, so this is one round trip for both colours rather than one walk per
/// repertoire.
async function unconfirmedCounts(pool, userId) {
  const result = await pool.query(
    `SELECT color,
            COUNT(*)::int AS positions,
            COALESCE(SUM(drafts), 0)::int AS moves
       FROM (
         SELECT color, fen_key,
                COUNT(*) FILTER (WHERE source = 'auto') AS drafts
           FROM repertoire_moves
          WHERE user_id = $1
          GROUP BY color, fen_key
         HAVING COUNT(*) FILTER (WHERE source = 'auto') > 0
            AND COUNT(*) FILTER (WHERE source <> 'auto') = 0
       ) t
      GROUP BY color`,
    [userId],
  );
  // Both colours always, with zeros where there is nothing. A missing key and a
  // zero read the same on a badge and differently in code, and the screen
  // should not have to know which it got.
  const counts = {
    w: { positions: 0, moves: 0 },
    b: { positions: 0, moves: 0 },
  };
  for (const row of result.rows) {
    if (counts[row.color] === undefined) continue;
    counts[row.color] = {
      positions: Number(row.positions),
      moves: Number(row.moves),
    };
  }
  return counts;
}

module.exports = { unconfirmedPositions, unconfirmedCounts, draftsAt };
