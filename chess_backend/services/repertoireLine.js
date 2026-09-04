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
  gateMoves,
  MAX_NODES,
  MAX_PLY,
} = require('./repertoireFrontier');
const {
  fenKey, skippedKeys, requireBreadth, DEFAULT_BREADTH,
} = require('./repertoireService');
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
async function walkLines(pool, userId, {
  color, rootFen, minRating = 0, maxPly = MAX_PLY, onlyChosen = false,
  gateUci = null, breadth = DEFAULT_BREADTH,
} = {}) {
  if (color !== 'w' && color !== 'b') {
    throw new RangeError(`Boja mora biti "w" ili "b", a ne "${color}".`);
  }
  fenKey(rootFen);

  const rootKey = fenKey(rootFen);
  // The gate is applied to `kept` itself, before a single step is taken, and
  // that is why one line covers everything: the walk reads this map, and so
  // does `tree` — which draws from `kept` rather than from what the walk
  // reached, so a move decided and not yet opened still gets a card. Filtering
  // in one place is what keeps the picture and the queue from disagreeing.
  const kept = gateMoves(
    await keptByPosition(pool, userId, color, { onlyChosen }), rootKey, gateUci);
  const cut = await skippedKeys(pool, userId, color);
  const band = Number(minRating) || 0;
  const wide = requireBreadth(breadth);
  const root = {
    key: rootKey, fen: rootFen, parent: null, ply: 0, path: [], moves: [],
  };
  const nodes = new Map([[rootKey, root]]);

  let level = [root];
  let ply = 0;
  let count = 1;
  let truncated = false;
  const ceiling = Math.min(Math.max(2, Number(maxPly) || MAX_PLY), MAX_PLY);

  while (level.length > 0 && ply < ceiling && !truncated) {
    const branches = [];
    for (const node of level) {
      if (cut.has(node.key)) continue;
      const here = kept.get(node.key) ?? [];
      for (const move of here) {
        const after = step(node.fen, move.uci);
        if (after === null) continue;
        branches.push({
          node,
          uci: move.uci,
          after,
          role: move.role,
          // The student's *other* decisions in this position. A line runs
          // through whichever move leads to the question — the primary as
          // often as an alternate — and without this the rehearsal asks
          // "play the move" at a position where two of the student's own
          // moves are right and only one continues this line. Playing the
          // other one is then reported as a mistake, which it is not.
          alts: here
            .filter((m) => m.uci !== move.uci)
            .map((m) => ({ uci: m.uci, san: m.san, role: m.role })),
        });
      }
    }

    const keys = [...new Set(branches.map((b) => fenKey(b.after.fen)))];
    // The board for each of those keys, so the book can tell which replies land
    // somewhere this student has already decided — those are followed at every
    // breadth. See `coveredReplies`.
    const fens = new Map(branches.map((b) => [fenKey(b.after.fen), b.after.fen]));
    const book = await coveredReplies(
      pool, userId, color, keys, band, wide, { fens, kept });

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
          // How often the opponent plays the reply that leads here. Carried on
          // the node because the picture needs it and a second query for a
          // number already in hand would be the wrong kind of tidy.
          share: reply.share,
          // The moves of the line, in order, each one saying whose it is. This
          // is what the replay plays: the student is asked for theirs and the
          // opponent's are answered back at them.
          moves: [
            ...branch.node.moves,
            {
              uci: branch.uci,
              san: branch.after.san,
              mine: true,
              // Which of the student's decisions this move is, and what the
              // others were. The rehearsal needs both: to say that a line runs
              // through an alternate before asking for it, and to tell a move
              // of the student's own apart from a move that is simply wrong.
              role: branch.role ?? 'primary',
              alts: branch.alts ?? [],
            },
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

  // The walk stopped because it ran out of room, not because the repertoire
  // ends here. Said out loud, like everywhere else.
  if (level.length > 0 && ply >= ceiling) truncated = true;

  // `kept` and `cut` go back with it. They were loaded to walk with and the
  // tree needs exactly the same two facts about every node — reading them a
  // second time would be a second chance for the two answers to differ.
  return { nodes, root, truncated, kept, cut };
}

/// The repertoire as a tree of single moves, for a picture rather than a queue.
///
/// The walk works in whole waves — my move and the answer to it — because that
/// is the unit a question is asked in. A drawing is not: it needs one node per
/// ply, so a move I chose is a card of its own even when nothing has been taken
/// after it. That case is the reason this builds from `kept` rather than from
/// the children found: a move decided and not yet opened has no children, and
/// building from what was reached would draw a repertoire with that move
/// missing — which is precisely the position the owner was looking at.
///
/// Every node says what it is: whose move, its share of games (theirs) or
/// whether it is the main line (mine), and what state the position it leads to
/// is in — `open`, `unopened`, `cut` or `decided`. Without those the tree is a
/// decoration; with them it is the one place the holes are visible.
///
/// `maxPly` keeps it a picture. A seeded repertoire runs to thousands of moves
/// and nobody reads a drawing of all of them, so the depth is a parameter and
/// the answer says when it was reached.
async function tree(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, maxPly = 16, gateUci = null,
  breadth = DEFAULT_BREADTH,
} = {}) {
  const { nodes, root, truncated, kept, cut } = await walkLines(pool, userId, {
    color, rootFen, minRating, maxPly, gateUci, breadth,
  });

  const byParent = new Map();
  for (const node of nodes.values()) {
    if (node.parent == null) continue;
    const list = byParent.get(node.parent) ?? [];
    list.push(node);
    byParent.set(node.parent, list);
  }

  /// What a position is, in one word, for the card that leads to it.
  const stateOf = (node) => {
    if (cut.has(node.key)) return 'cut';
    if ((kept.get(node.key) ?? []).length === 0) return 'open';
    if ((byParent.get(node.key) ?? []).length === 0) return 'unopened';
    return 'decided';
  };

  const build = (node) => {
    if (cut.has(node.key)) return [];
    const kids = byParent.get(node.key) ?? [];
    const out = [];
    // In the student's own order: the primary first, then the alternates, the
    // way `keptByPosition` hands them back.
    for (const my of kept.get(node.key) ?? []) {
      const after = step(node.fen, my.uci);
      if (after === null) continue;
      const replies = kids
        .filter((c) => c.moves[c.moves.length - 2].uci === my.uci)
        .sort((a, b) => (b.share ?? 0) - (a.share ?? 0));
      out.push({
        uci: my.uci,
        san: after.san,
        mine: true,
        role: my.role,
        fen: after.fen,
        children: replies.map((child) => ({
          uci: child.moves[child.moves.length - 1].uci,
          san: child.moves[child.moves.length - 1].san,
          mine: false,
          share: Number(child.share ?? 0),
          fen: child.fen,
          fenKey: child.key,
          state: stateOf(child),
          children: build(child),
        })),
      });
    }
    return out;
  };

  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];

  return {
    root: { fen: rootFen, path: base },
    // The root is a position like any other and carries the same state, so a
    // repertoire whose first move is undecided says so on the picture instead
    // of drawing an empty page.
    state: stateOf(root),
    children: build(root),
    maxPly,
    truncated,
  };
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

/// The positions reached by taking one particular move at one position.
///
/// A repertoire holds more than one move in plenty of positions, and the walk
/// spreads through all of them — so "the line behind my main move" is a thing
/// the student can see on the board and had no way to ask for. The queue
/// decided, and the other road came round when its positions fell due.
///
/// The move is found by *where it was played from* rather than by its own
/// square: a chain's move at index `2i` is the student's move out of the node
/// at chain position `i`, because the walk appends one pair per level. Matching
/// on the uci alone would catch the same move played somewhere else entirely.
///
/// The fork position itself is not in the answer. It is the position the choice
/// is made in, not one of the positions the choice leads to.
function nodesVia(nodes, viaKey, viaUci) {
  const out = [];
  for (const key of nodes.keys()) {
    const chain = chainTo(nodes, key);
    const at = chain.indexOf(viaKey);
    if (at === -1 || at >= chain.length - 1) continue;
    if (nodes.get(key).moves[at * 2]?.uci === viaUci) out.push(key);
  }
  return out;
}

/// The doors a session is being run through, always as a list.
///
/// Everything below the drill takes one `(rootFen, gateUci)` pair, and a
/// student who wants to practise two openings in one sitting had no way to say
/// so. Rather than teach every function to be two functions, one root becomes a
/// list of one here and the rest of the file only ever sees a list.
///
/// `roots` comes from `repertoiresByIds`, so each door already carries its
/// name, its gate and its breadth — the caller does not send three parallel
/// arrays, which is the shape that goes wrong the first time one of them is
/// shorter than the others.
///
/// The single-root parameters are still exactly what they were, and a request
/// that sends them gets the walk it has always got.
function doorsOf({
  roots = null, rootFen, rootPath = [], gateUci = null,
  breadth = DEFAULT_BREADTH,
} = {}) {
  if (Array.isArray(roots) && roots.length > 0) {
    return roots.map((one) => ({
      id: one.id ?? null,
      name: one.name ?? null,
      rootFen: one.rootFen,
      rootPath: Array.isArray(one.rootPath) ? one.rootPath : [],
      viaUci: one.viaUci ?? null,
      breadth: one.breadth ?? DEFAULT_BREADTH,
    }));
  }
  return [{
    id: null,
    name: null,
    rootFen,
    rootPath: Array.isArray(rootPath) ? rootPath : [],
    viaUci: gateUci,
    breadth,
  }];
}

/// The SAN moves that led to a door's root, cleaned.
const baseOf = (door) => door.rootPath
  .filter((san) => typeof san === 'string' && san !== '');

/// One line to rehearse, and the question at the end of it.
///
/// `question` is null when nothing is waiting — which the screen must tell
/// apart from a walk that found nothing at all, so `reason` names which of the
/// two it is.
/// `viaFen` + `viaUci` narrow it to the lines that go through one decision, and
/// are how somebody standing at a fork asks for the other road instead of
/// waiting for the schedule to offer it.
///
/// `exclude` drops positions already refused. Without it "another line" is a
/// promise the queue cannot keep: `nextItem` is a deterministic `ORDER BY
/// due_at LIMIT 1` and skipping writes nothing down, so the same line came back
/// every time the button was pressed.
///
/// `roots` runs **one session over several repertoires**. Each is walked with
/// its own gate and its own breadth, the question is taken from the union, and
/// the line is built from whichever walk holds it — so the breadcrumb reads
/// from that repertoire's own root and the answer says which one it came from.
///
/// A position two repertoires both reach is **one item**: `repertoire_reviews`
/// is keyed `(colour, position)` and stays that way, so it has one due date and
/// is answered once. Per-repertoire schedules would put the same board up twice
/// in one sitting and call the second time practice.
async function drillLine(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, fromFen = null,
  viaFen = null, viaUci = null, exclude = [], ahead = false, gateUci = null,
  breadth = DEFAULT_BREADTH, roots = null, now = new Date(),
} = {}) {
  const doors = doorsOf({ roots, rootFen, rootPath, gateUci, breadth });

  const walks = [];
  let truncated = false;
  for (const door of doors) {
    // Sequential rather than in parallel: these are database round trips
    // against one pool, and a combined session of four repertoires firing four
    // wide walks at once is how a pool runs out of clients.
    // eslint-disable-next-line no-await-in-loop
    const walk = await walkLines(pool, userId, {
      color,
      rootFen: door.rootFen,
      minRating,
      gateUci: door.viaUci,
      breadth: door.breadth,
      // A rehearsal replays decisions. A line through a move nobody chose is
      // not the student's line, and playing it would teach a move they have
      // not agreed to.
      onlyChosen: true,
    });
    truncated = truncated || walk.truncated;
    walks.push({ door, ...walk });
  }

  const from = fromFen != null && String(fromFen).trim() !== ''
    ? fenKey(fromFen)
    : null;
  const forkKey = viaFen != null && String(viaFen).trim() !== '' && viaUci
    ? fenKey(viaFen)
    : null;

  /// What one door contributes to the queue, or null for "everything it has".
  ///
  /// Null is not the same as "all of this walk": with a single ungated door and
  /// no narrowing it means the whole **colour**, which is what this call has
  /// always meant and what the schedule is keyed by. It stops meaning that the
  /// moment there is more than one door — a combined session is exactly the
  /// union of the repertoires named, not everything the student owns.
  const narrow = (walk) => {
    let within = walk.door.viaUci ? [...walk.nodes.keys()] : null;
    if (from !== null) {
      // A position this walk never reached — cut since, or built under a move
      // no longer kept. An empty block rather than a 400: the request was well
      // formed, and "there is nothing there any more" is the answer.
      const block = walk.nodes.has(from) ? subtree(walk.nodes, from) : [];
      // Intersected, never replaced, for the same reason the fork below is: a
      // gate and a branch are two narrowings of one walk.
      within = within === null
        ? block
        : within.filter((key) => block.includes(key));
    }
    if (forkKey !== null) {
      const through = walk.nodes.has(forkKey)
        ? nodesVia(walk.nodes, forkKey, viaUci)
        : [];
      within = within === null
        ? through
        : within.filter((key) => through.includes(key));
    }
    return within;
  };

  const narrowed = walks.map(narrow);
  const within = (doors.length === 1 && narrowed[0] === null)
    ? null
    : [...new Set(narrowed.flatMap(
      (keys, at) => keys ?? [...walks[at].nodes.keys()]))];

  const refused = new Set(Array.isArray(exclude) ? exclude : []);
  const keys = (within ?? walks.flatMap((walk) => [...walk.nodes.keys()]))
    .filter((key) => !refused.has(key));
  // The counts describe the walk, not what is left of it after skipping: a
  // student who has skipped four of six positions has not thereby learned
  // them, and "dospelo 2" would say they had.
  const stats = await drillStats(pool, userId, { color, now, only: within });
  const item = keys.length === 0
    ? null
    : await nextItem(pool, userId, { color, now, only: keys, ahead });

  // Which repertoire the question turned out to be in. First door wins where
  // two of them reach the same position, which is the same first-wins rule the
  // walk itself keeps — and it is one question either way, because the schedule
  // is keyed by position and not by repertoire.
  const found = item === null
    ? null
    : walks.find((walk) => walk.nodes.has(item.fenKey)) ?? null;
  const tag = (walk) => (walk === null || walk.door.id === null
    ? null
    : { id: walk.door.id, name: walk.door.name });

  if (item === null || found === null) {
    // A door has to be named even with no question, because the screen draws a
    // board from it. The first one, which with a single root is the only one.
    const door = walks[0].door;
    return {
      root: { fen: door.rootFen, path: baseOf(door) },
      repertoire: tag(walks[0]),
      from,
      question: null,
      reason: stats.positions === 0 ? 'nothing-built' : 'nothing-due',
      ahead,
      start: null,
      prefix: [],
      stats,
      truncated,
    };
  }

  const { nodes, root, door } = found;
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
    // the two for a line that reads from move one. In a combined session this
    // is the root of the repertoire the question came from, not of the first
    // one named — a breadcrumb from the wrong door is a line that does not add
    // up on the board.
    root: { fen: door.rootFen, path: baseOf(door) },
    // Which repertoire that was. Null when the caller asked by root rather than
    // by id, because then there is nothing to name it with.
    repertoire: tag(found),
    // Whether this line was taken ahead of its schedule. The screen has to say
    // so, because the answer at the end of it will not be written down.
    ahead,
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

/// The opponent's first answers, each with how much of it is waiting.
///
/// A repertoire is a handful of branches — what they play against your first
/// move — and that is the unit somebody sits down to practise: "today the lines
/// against 3...Bc5". Mixing every position in the colour into one queue is
/// right for a schedule and wrong for a session, because the ten positions that
/// hang together are the ones worth meeting in a row.
///
/// The branch is keyed by the **pair** of moves that opens it — the student's
/// own and the reply — because a repertoire may keep more than one first move,
/// and then "2...d6" names two different branches. Same rule the coverage map
/// keeps, and for the same reason.
///
/// With `roots`, several repertoires are listed at once and every branch says
/// which one it came from. Two of them can produce the same pair of moves from
/// different doors, so the pair is not an identity any more: `key` stays what it
/// was, and `id` is what a list should be keyed by.
///
/// A position both repertoires reach is counted into both branches, and that is
/// the truth rather than double counting — it *is* in both openings. It is one
/// question with one due date all the same, which is the sentence the branch
/// sheet has to carry where two are ticked.
///
/// Only decisions are walked (`onlyChosen`). A drill never asks about a move
/// nobody chose, so counting drafts here would promise questions that will
/// never be asked.
///
/// No Lichess request, like everything that reads what was built.
async function drillBranches(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, gateUci = null,
  breadth = DEFAULT_BREADTH, roots = null, now = new Date(),
} = {}) {
  const doors = doorsOf({ roots, rootFen, rootPath, gateUci, breadth });

  const groups = new Map();
  let truncated = false;
  for (const door of doors) {
    // eslint-disable-next-line no-await-in-loop
    const { nodes, truncated: short } = await walkLines(pool, userId, {
      color,
      rootFen: door.rootFen,
      minRating,
      gateUci: door.viaUci,
      breadth: door.breadth,
      onlyChosen: true,
    });
    truncated = truncated || short;

    for (const node of nodes.values()) {
      // The root belongs to no branch: it is the position every branch leaves
      // from, and counting it into one of them would make that one look bigger.
      if (node.moves.length < 2) continue;
      const key = `${node.moves[0].uci}-${node.moves[1].uci}`;
      const id = `${door.id ?? 0}:${key}`;
      let group = groups.get(id);
      if (group === undefined) {
        group = {
          id,
          key,
          door,
          // The two moves that open it, so a screen can name the branch the way
          // the coverage map names it.
          path: node.path.slice(0, 2),
          san: node.moves.slice(0, 2).map((m) => m.san).join(' '),
          fen: null,
          share: 0,
          keys: [],
        };
        groups.set(id, group);
      }
      // The branch's own starting position: after the student's move and the
      // reply to it. Exactly one node sits at that ply per branch, and it is
      // where a run of the branch begins.
      if (node.ply === 2) {
        group.fen = node.fen;
        group.share = Number(node.share ?? 0);
      }
      group.keys.push(node.key);
    }
  }

  const everyKey = [...new Set([...groups.values()].flatMap((g) => g.keys))];
  const reviews = everyKey.length === 0
    ? { rows: [] }
    : await pool.query(
      `SELECT fen_key, due_at, repetitions FROM repertoire_reviews
        WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)`,
      [userId, color, everyKey],
    );
  const byKey = new Map(reviews.rows.map((row) => [row.fen_key, row]));

  const branches = [];
  for (const group of groups.values()) {
    if (group.fen === null) continue;
    let due = 0;
    let known = 0;
    const dueKeys = [];
    for (const key of group.keys) {
      const row = byKey.get(key);
      // Never reviewed is due: it is the most overdue thing there is, and a
      // branch that has never been opened must not read as finished.
      if (row === undefined || new Date(row.due_at) <= now) {
        due += 1;
        dueKeys.push(key);
        continue;
      }
      if (Number(row.repetitions) >= KNOWN_REPETITIONS) known += 1;
    }
    branches.push({
      // Unique across the whole answer, which `key` is not once more than one
      // repertoire is listed. A list keyed by `key` would collapse two openings
      // that happen to start with the same two moves into one row.
      id: group.id,
      key: group.key,
      // Which repertoire this branch is in, or null when the caller asked by
      // root rather than by id and there is nothing to name it with.
      repertoire: group.door.id === null
        ? null
        : { id: group.door.id, name: group.door.name },
      // The door it is walked from, so a run of this branch alone can be asked
      // for with the same root and gate the list was built with.
      root: { fen: group.door.rootFen, path: baseOf(group.door) },
      gateUci: group.door.viaUci,
      breadth: group.door.breadth,
      fen: group.fen,
      path: group.path,
      san: group.san,
      share: group.share,
      positions: group.keys.length,
      due,
      known,
      // The positions in this branch that are actually due, so a run through it
      // can grade those and leave the rest alone. A whole branch replayed with
      // every position graded would push the schedule out on the strength of
      // moves nobody had to remember cold — the same rule that keeps the line
      // walk's prefix ungraded.
      dueKeys,
    });
  }

  // Most waiting first, and among equals the bigger branch: that is the order
  // they are worth sitting down to, not the order they were built.
  branches.sort((a, b) => (b.due - a.due) || (b.positions - a.positions));

  const first = doors[0];
  return {
    root: { fen: first.rootFen, path: baseOf(first) },
    branches,
    truncated,
  };
}

module.exports = {
  drillLine, drillBranches, walkLines, tree, chainTo, subtree, doorsOf,
};
