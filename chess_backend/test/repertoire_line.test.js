const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const {
  drillLine, drillBranches, tree, walkLines,
} = require('../services/repertoireLine');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

/// The FEN after a line of UCI moves from the start, and its repertoire key.
///
/// Computed rather than pasted, for the same reason the frontier's tests
/// compute theirs: a hand-written FEN is a chance to assert against a position
/// that does not exist, and the walk would then be right while the test is
/// wrong.
function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

function keyAfter(...ucis) {
  return fenKey(after(...ucis));
}

/// 1.e4 c5 2.Nf3 d6 3.d4 — three decisions on one line, and nothing else.
///
/// `replies` are the opponent moves the student entered, with the numbers the
/// book joins in beside them. Small on purpose: what is being tested is the
/// shape of the line handed back.
const SICILIAN = {
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
    {
      fen_key: keyAfter('e2e4', 'c7c5'),
      uci: 'g1f3', san: 'Nf3', role: 'primary',
    },
    {
      fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'd7d6'),
      uci: 'd2d4', san: 'd4', role: 'primary',
    },
  ],
  replies: [
    {
      fen_key: keyAfter('e2e4'),
      uci: 'c7c5', san: 'c5', games: 500, share: '0.50000',
    },
    {
      fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
      uci: 'd7d6', san: 'd6', games: 300, share: '0.60000',
    },
  ],
};

/// A pool that answers each of the questions this walk asks.
///
/// Matched on a fragment unique to each query rather than replayed in order:
/// how many times the walk asks for the entered moves is itself a thing the
/// tests check, so a positional stub would pass for the wrong reason.
function stubPool({
  moves = [], replies = [], due = [], fresh = [], known = [],
  reviews = [],
  stats = { positions: 3, seen: 0, due: 0, known: 0 },
} = {}) {
  const calls = [];
  return {
    calls,
    paramsOf: (fragment) =>
      calls.find((c) => c.text.includes(fragment))?.params ?? null,
    query: async (text, params) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      const rows = (() => {
        if (flat.includes('AS positions')) {
          return [{
            positions: stats.positions,
            seen: stats.seen,
            due: stats.due,
            known: stats.known,
          }];
        }
        if (flat.includes('SELECT fen_key, uci, san, role')) {
          // Decisions only, and only while the query asks for them: whether
          // the rehearsal walks through a move the retired spine wrote is
          // exactly what one test asks.
          return flat.includes("source = 'chosen'")
            ? moves.filter((m) => (m.source ?? 'chosen') === 'chosen')
            : moves;
        }
        if (flat.includes('FROM repertoire_extra_replies e')) {
          const keys = params[2];
          return replies
            .filter((r) => keys.includes(r.fen_key))
            .sort((a, b) => Number(b.games ?? 0) - Number(a.games ?? 0));
        }
        if (flat.includes('AS moves')) return [{ moves: 1 }];
        if (flat.includes('r.due_at <= $3')) {
          const within = params[3];
          return due.filter((row) => within === null || within.includes(row.fen_key));
        }
        if (flat.includes('mistakes DESC')) {
          const within = params[2];
          return fresh.filter((row) => within === null || within.includes(row.fen_key));
        }
        if (flat.includes('repetitions >= $4')) {
          const within = params[2];
          return known.filter((row) => within.includes(row.fen_key));
        }
        // The branch tally reads every review row at once rather than asking
        // per branch: a repertoire is a few hundred positions and the walk
        // touches most of them.
        if (flat.includes('SELECT fen_key, due_at, repetitions')) {
          const within = params[2];
          return reviews.filter((row) => within.includes(row.fen_key));
        }
        throw new Error(`Unexpected query: ${flat}`);
      })();
      return { rows, rowCount: rows.length };
    },
  };
}

const DEEP = keyAfter('e2e4', 'c7c5', 'g1f3', 'd7d6');
const MIDDLE = keyAfter('e2e4', 'c7c5');

test('the question comes with the line that leads to it', async () => {
  // The drill used to put up a bare board four moves into something, with no
  // way to tell how it arose. A repertoire is played forwards, and this is the
  // difference between remembering a line and recognising a photograph of it.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.question.fenKey, DEEP);
  assert.equal(line.question.ply, 4);
  assert.deepEqual(line.prefix.map((m) => m.san), ['e4', 'c5', 'Nf3', 'd6']);
  // Whose each move is, because the replay asks for the student's and answers
  // back with the opponent's.
  assert.deepEqual(line.prefix.map((m) => m.mine), [true, false, true, false]);
  // Nothing known yet, so the rehearsal starts where the repertoire does.
  assert.equal(line.start.fenKey, fenKey(START));
  assert.equal(line.start.known, false);
});

test('a line says which of the decisions it walks, and what the others were',
  async () => {
    // A line runs through whichever move leads to the question — the primary
    // as often as an alternate — and a rehearsal that does not say which is
    // asking the student to guess.
    const pool = stubPool({
      ...SICILIAN,
      moves: [
        ...SICILIAN.moves,
        // A second first move, kept and not the main one.
        {
          fen_key: fenKey(START), uci: 'd2d4', san: 'd4', role: 'alternate',
        },
      ],
      fresh: [{ fen_key: DEEP, mistakes: 0 }],
    });
    const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

    const first = line.prefix[0];
    assert.equal(first.san, 'e4');
    assert.equal(first.role, 'primary');
    assert.deepEqual(first.alts, [{ uci: 'd2d4', san: 'd4', role: 'alternate' }]);

    // And a position with one decision in it carries no alternates at all,
    // rather than an empty promise of a choice.
    assert.deepEqual(line.prefix[2].alts, []);
    assert.equal(line.prefix[2].role, 'primary');
  });

test('a reply carries no choice of its own', async () => {
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  for (const move of line.prefix.filter((m) => !m.mine)) {
    assert.equal(move.alts, undefined);
    assert.equal(move.role, undefined);
  }
});

test('the walk follows the opponent moves the student entered, and only those',
  async () => {
    // The book decides nothing. A reply that is not entered is not a position
    // of the repertoire, however often it is played.
    const { nodes } = await walkLines(stubPool(SICILIAN), 7, {
      color: 'w', rootFen: START,
    });

    assert.deepEqual([...nodes.values()].map((n) => n.path.join(' ')),
      ['', 'e4 c5', 'e4 c5 Nf3 d6']);
  });

test('an entered move the book does not know is walked and drawn', async () => {
  const fixture = {
    ...SICILIAN,
    replies: [
      ...SICILIAN.replies,
      { fen_key: keyAfter('e2e4'), uci: 'a7a6', san: 'a6', games: 0, share: 0 },
    ],
  };
  const { nodes } = await walkLines(stubPool(fixture), 7, {
    color: 'w', rootFen: START,
  });
  assert.ok(nodes.has(keyAfter('e2e4', 'a7a6')));

  const drawn = await tree(stubPool(fixture), 7, { color: 'w', rootFen: START });
  const replies = drawn.children[0].children;
  assert.deepEqual(replies.map((n) => n.san), ['c5', 'a6']);
  assert.equal(replies[1].share, 0);
  assert.equal(replies[1].state, 'open');
});

/// The same Sicilian, plus a second first move with a line of its own:
/// 1.d4 d5 2.c4. Two roads out of the starting position, both prepared.
const TWO_ROADS = {
  moves: [
    ...SICILIAN.moves,
    { fen_key: fenKey(START), uci: 'd2d4', san: 'd4', role: 'alternate' },
    {
      fen_key: keyAfter('d2d4', 'd7d5'),
      uci: 'c2c4', san: 'c4', role: 'primary',
    },
  ],
  replies: [
    ...SICILIAN.replies,
    {
      fen_key: keyAfter('d2d4'),
      uci: 'd7d5', san: 'd5', games: 400, share: '0.40000',
    },
  ],
};

test('one fork can be walked instead of the one the queue chose', async () => {
  // Standing in front of your own main move and being drilled down the
  // alternative, with no way to say "the other one", was the queue deciding
  // something the student can see on the board.
  const pool = stubPool({
    ...TWO_ROADS,
    // Due in both roads, and the Sicilian one first.
    due: [
      { fen_key: MIDDLE, due_at: '2020-01-01', repetitions: '2' },
    ],
    fresh: [{ fen_key: keyAfter('d2d4', 'd7d5'), mistakes: 0 }],
  });

  const line = await drillLine(pool, 7, {
    color: 'w', rootFen: START, viaFen: START, viaUci: 'd2d4',
  });

  assert.equal(line.question.fenKey, keyAfter('d2d4', 'd7d5'));
  assert.deepEqual(line.prefix.map((m) => m.san), ['d4', 'd5']);
});

test('a fork it never reached narrows to nothing rather than to everything',
  async () => {
    // The dangerous failure: a `via` nobody can honour quietly falling back to
    // the whole repertoire would answer a question that was not asked.
    const pool = stubPool({
      ...TWO_ROADS,
      due: [{ fen_key: MIDDLE, due_at: '2020-01-01', repetitions: '2' }],
    });

    const line = await drillLine(pool, 7, {
      color: 'w', rootFen: START, viaFen: START, viaUci: 'h2h4',
    });

    assert.equal(line.question, null);
  });

test('the fork position itself is not one of the positions it leads to',
  async () => {
    // It is where the choice is made, not somewhere the choice takes you —
    // and offering it back would ask the student the question they had just
    // answered by pressing the button.
    const pool = stubPool({
      ...TWO_ROADS,
      due: [{ fen_key: fenKey(START), due_at: '2020-01-01', repetitions: '2' }],
    });

    const line = await drillLine(pool, 7, {
      color: 'w', rootFen: START, viaFen: START, viaUci: 'd2d4',
    });

    assert.notEqual(line.question?.fenKey, fenKey(START));
  });

test('a refused position is not offered again', async () => {
  // `nextItem` is a deterministic `ORDER BY due_at LIMIT 1` and skipping writes
  // nothing down, so without this the skip button handed back exactly what it
  // was asked to take away.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
  });

  const line = await drillLine(pool, 7, {
    color: 'w', rootFen: START, exclude: [DEEP],
  });

  assert.equal(line.question, null);
  // And the counts still describe the walk rather than what is left of it: a
  // student who skipped a position has not thereby learned it.
  assert.equal(line.stats.positions, 3);
});

test('the replay starts at the last position known cold', async () => {
  // Twelve plies of rehearsal to reach one question is how a drill stops being
  // opened. What the student has already got to three clean repetitions is not
  // worth their evening.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
    known: [{ fen_key: MIDDLE, repetitions: 4 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.start.fenKey, MIDDLE);
  assert.equal(line.start.known, true);
  assert.deepEqual(line.prefix.map((m) => m.san), ['Nf3', 'd6']);
  // Only the positions above the question are consulted. The question's own
  // review says nothing about where the rehearsal should begin — it is the
  // thing being asked.
  assert.deepEqual(pool.paramsOf('repetitions >= $4')[2],
    [fenKey(START), MIDDLE]);
});

test('the line never carries the move it is asking for', async () => {
  // The oldest rule of this drill: a question that arrives with its answer
  // attached is one a determined student reads out of the network log instead
  // of out of their memory. The prefix is not an exception to it — those moves
  // are rehearsal, and the one move that is a question is 3.d4.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  const wire = JSON.stringify(line);
  assert.equal(wire.includes('d2d4'), false, 'the answer went out with the question');
  assert.equal(wire.includes('"d4"'), false, 'the answer went out with the question');
});

test('one branch can be drilled on its own', async () => {
  // The block. The day after a build session the ten positions just built are
  // the thing somebody sits down to practise, and the rest of the repertoire is
  // in the way.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }, { fen_key: fenKey(START), mistakes: 9 }],
  });
  const line = await drillLine(pool, 7, {
    color: 'w', rootFen: START, fromFen: after('e2e4', 'c7c5'),
  });

  // The root has nine missed attempts and would win the whole-colour ordering
  // outright. It is not in this branch, so it is not asked.
  assert.equal(line.question.fenKey, DEEP);
  assert.equal(line.from, MIDDLE);
  const within = pool.paramsOf('mistakes DESC')[2];
  assert.deepEqual([...within].sort(), [DEEP, MIDDLE].sort());
});

test('a branch that is no longer there is an empty block, not a bad request',
  async () => {
    // Built under a move that is no longer kept. The request was well formed
    // and the honest answer is "there is nothing there any more".
    const pool = stubPool({
      ...SICILIAN,
      stats: { positions: 0, seen: 0, due: 0, known: 0 },
    });
    const line = await drillLine(pool, 7, {
      color: 'w', rootFen: START, fromFen: after('d2d4'),
    });

    assert.equal(line.question, null);
    assert.equal(line.reason, 'nothing-built');
    assert.equal(line.stats.positions, 0);
  });

test('nothing due and nothing built are two different answers', async () => {
  // Only one of them is good news, and a screen that renders them the same way
  // tells a beginner they have finished something they have not started.
  const pool = stubPool({ ...SICILIAN, stats: { positions: 3, seen: 3, due: 0, known: 3 } });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.question, null);
  assert.equal(line.reason, 'nothing-due');
});

test('the entered moves are asked for once per wave, not once per branch',
  async () => {
    // The same shape the frontier keeps. A walk that asked per branch would
    // turn one drill question into a minute of database time on a wide
    // repertoire.
    const pool = stubPool({ ...SICILIAN, fresh: [{ fen_key: DEEP, mistakes: 0 }] });
    await drillLine(pool, 7, { color: 'w', rootFen: START });

    const waves = pool.calls.filter(
      (c) => c.text.includes('FROM repertoire_extra_replies e'));
    assert.equal(waves.length, 3, `waves: ${waves.length}`);
  });

test('the tree draws one node per ply, in the order the student chose', async () => {
  // The walk works in whole waves because that is the unit a question is asked
  // in. A picture is not: it needs a card per move.
  const pool = stubPool(SICILIAN);
  const drawn = await tree(pool, 7, { color: 'w', rootFen: START });

  assert.deepEqual(drawn.children.map((n) => n.san), ['e4']);
  assert.equal(drawn.children[0].mine, true);
  const replies = drawn.children[0].children;
  assert.deepEqual(replies.map((n) => n.san), ['c5']);
  assert.equal(replies[0].mine, false);
  assert.equal(Math.round(replies[0].share * 100), 50);
  // And on down: 1.e4 c5 2.Nf3 d6 3.d4, five plies, five levels.
  assert.deepEqual(replies[0].children.map((n) => n.san), ['Nf3']);
  assert.deepEqual(
    replies[0].children[0].children.map((n) => n.san), ['d6']);
  assert.deepEqual(
    replies[0].children[0].children[0].children.map((n) => n.san), ['d4']);
});

test('a move with no reply entered after it is still drawn', async () => {
  // Building the tree from the positions the walk *reached* would draw a
  // repertoire with that move missing, which is why it is built from what was
  // kept.
  const pool = stubPool({ moves: SICILIAN.moves, replies: [] });
  const drawn = await tree(pool, 7, { color: 'w', rootFen: START });

  assert.deepEqual(drawn.children.map((n) => n.san), ['e4']);
  assert.deepEqual(drawn.children[0].children, []);
});

test('every node says whether the position after it is answered', async () => {
  // Without this the tree is a decoration. With it, it is the one place the
  // holes are visible.
  const pool = stubPool(SICILIAN);
  const drawn = await tree(pool, 7, { color: 'w', rootFen: START });

  const afterC5 = drawn.children[0].children[0];
  assert.equal(afterC5.state, 'decided');
  const afterD6 = afterC5.children[0].children[0];
  assert.equal(afterD6.state, 'decided');

  const unanswered = await tree(stubPool({
    ...SICILIAN,
    moves: SICILIAN.moves.slice(0, 2),
  }), 7, { color: 'w', rootFen: START });
  assert.equal(
    unanswered.children[0].children[0].children[0].children[0].state, 'open');
});

test('the depth is a parameter, and reaching it is said out loud', async () => {
  const pool = stubPool(SICILIAN);
  const drawn = await tree(pool, 7, { color: 'w', rootFen: START, maxPly: 2 });

  assert.equal(drawn.truncated, true);
  assert.deepEqual(drawn.children[0].children.map((n) => n.san), ['c5']);
  // One wave, and then it stops. The student's own move at the edge is still
  // drawn — those are decisions already made and already loaded, and only the
  // opponent's replies cost a level of the walk — but nothing comes after it.
  const afterC5 = drawn.children[0].children[0];
  assert.deepEqual(afterC5.children.map((n) => n.san), ['Nf3']);
  assert.deepEqual(afterC5.children[0].children, []);
});

test('a rehearsal does not walk through a move nobody played', async () => {
  // A row the retired spine wrote as a draft is not the student's line, and
  // replaying it would teach a move they never played.
  const pool = stubPool({
    moves: SICILIAN.moves.map((m) => (
      m.fen_key === MIDDLE ? { ...m, source: 'auto' } : m)),
    replies: SICILIAN.replies,
    fresh: [{ fen_key: fenKey(START), mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  // 2.Nf3 was a draft, so nothing below it is reachable as a rehearsal and
  // the question is the root itself.
  assert.equal(line.question.fenKey, fenKey(START));
  const within = pool.paramsOf('mistakes DESC')[2];
  assert.equal(within.includes(DEEP), false, 'the drill walked through a draft');
});

/// 1.e4 with two answers — c5 and e5 — each with a move of the student's after
/// it. Two branches, which is the whole point of the tally.
const TWO_BRANCHES = {
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
    {
      fen_key: keyAfter('e2e4', 'c7c5'),
      uci: 'g1f3', san: 'Nf3', role: 'primary',
    },
    {
      fen_key: keyAfter('e2e4', 'e7e5'),
      uci: 'g1f3', san: 'Nf3', role: 'primary',
    },
  ],
  replies: [
    {
      fen_key: keyAfter('e2e4'),
      uci: 'c7c5', san: 'c5', games: 500, share: '0.50000',
    },
    {
      fen_key: keyAfter('e2e4'),
      uci: 'e7e5', san: 'e5', games: 300, share: '0.30000',
    },
  ],
};

test('branches are the opponent\'s first answers, counted apart', async () => {
  const pool = stubPool(TWO_BRANCHES);
  const answer = await drillBranches(pool, 7, { color: 'w', rootFen: START });

  assert.equal(answer.branches.length, 2);
  const names = answer.branches.map((b) => b.san).sort();
  assert.deepEqual(names, ['e4 c5', 'e4 e5']);
  // The root belongs to no branch: it is the position every branch leaves
  // from, and counting it into one would make that one look bigger.
  for (const branch of answer.branches) {
    assert.equal(branch.positions, 1);
  }
});

test('a position never reviewed counts as due', async () => {
  // The most overdue thing there is. A branch nobody has ever drilled must not
  // read as finished.
  const pool = stubPool(TWO_BRANCHES);
  const answer = await drillBranches(pool, 7, { color: 'w', rootFen: START });

  for (const branch of answer.branches) {
    assert.equal(branch.due, 1);
    assert.deepEqual(branch.dueKeys.length, 1);
  }
});

test('a review in the future is not due, and a known one is counted', async () => {
  const later = new Date('2026-12-01T00:00:00Z');
  const pool = stubPool({
    ...TWO_BRANCHES,
    reviews: [
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        due_at: later.toISOString(),
        repetitions: 5,
      },
    ],
  });
  const answer = await drillBranches(pool, 7, {
    color: 'w', rootFen: START, now: new Date('2026-09-01T00:00:00Z'),
  });

  const sicilian = answer.branches.find((b) => b.san === 'e4 c5');
  assert.equal(sicilian.due, 0);
  assert.equal(sicilian.known, 1);
  assert.deepEqual(sicilian.dueKeys, []);

  // And the other branch is untouched by that: they are counted apart.
  const open = answer.branches.find((b) => b.san === 'e4 e5');
  assert.equal(open.due, 1);
});

test('the branch carries where it starts and how often it is played', async () => {
  const pool = stubPool(TWO_BRANCHES);
  const answer = await drillBranches(pool, 7, { color: 'w', rootFen: START });

  const sicilian = answer.branches.find((b) => b.san === 'e4 c5');
  // Where a run through the branch begins: after the student's move and the
  // reply to it.
  assert.equal(fenKey(sicilian.fen), keyAfter('e2e4', 'c7c5'));
  assert.equal(sicilian.share, 0.5);
  assert.equal('breadth' in sicilian, false);
});

test('most waiting first', async () => {
  const later = new Date('2026-12-01T00:00:00Z');
  const pool = stubPool({
    ...TWO_BRANCHES,
    reviews: [
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        due_at: later.toISOString(),
        repetitions: 5,
      },
    ],
  });
  const answer = await drillBranches(pool, 7, {
    color: 'w', rootFen: START, now: new Date('2026-09-01T00:00:00Z'),
  });

  // The order they are worth sitting down to, not the order they were built.
  assert.equal(answer.branches[0].san, 'e4 e5');
});

test('a repertoire with nothing under the root has no branches', async () => {
  const pool = stubPool({ moves: [], replies: [] });
  const answer = await drillBranches(pool, 7, { color: 'w', rootFen: START });
  assert.deepEqual(answer.branches, []);
});

// --- combined sessions -------------------------------------------------
//
// Everything below the drill took one `(rootFen, gateUci)`, so "practise these
// two openings in one sitting" was a thing the student could want and not ask
// for. `roots` is a list of doors, each walked with its own gate.

/// The same graph, opened by two doors: one at the start and one at the
/// Sicilian after 1.e4 c5. They overlap on purpose — that overlap is the case
/// the shared schedule is about.
const TWO_DOORS = [
  {
    id: 3, name: 'e4 complete', rootFen: START, rootPath: [], viaUci: null,
  },
  {
    id: 7,
    name: 'Sicilian',
    rootFen: after('e2e4', 'c7c5'),
    rootPath: ['e4', 'c5'],
    viaUci: null,
  },
];

test('a branch says which repertoire it came from', async () => {
  const pool = stubPool({ ...SICILIAN, reviews: [] });
  const listed = await drillBranches(pool, 7, {
    color: 'w', roots: TWO_DOORS,
  });

  const names = listed.branches.map((b) => b.repertoire?.name);
  assert.ok(names.includes('e4 complete'), `names: ${names}`);
  assert.ok(names.includes('Sicilian'), `names: ${names}`);
  // And carries the door it is walked from, so a run of this branch alone can
  // be asked for with the same root and gate the list was built with.
  const sicilian = listed.branches.find((b) => b.repertoire?.id === 7);
  assert.equal(sicilian.root.fen, after('e2e4', 'c7c5'));
  assert.deepEqual(sicilian.root.path, ['e4', 'c5']);
});

test('two openings that start the same way are two rows, not one', async () => {
  // `key` is the pair of moves that opens a branch, and once more than one
  // repertoire is listed that pair is no longer an identity. A list keyed by
  // `key` would collapse them, and the student would tick one opening and drill
  // the other.
  const pool = stubPool({ ...SICILIAN, reviews: [] });
  const listed = await drillBranches(pool, 7, {
    color: 'w',
    roots: [
      { ...TWO_DOORS[0], id: 3, name: 'e4 complete', viaUci: null },
      {
        id: 9, name: 'Only 1.e4', rootFen: START, rootPath: [], viaUci: 'e2e4',
      },
    ],
  });

  const ids = listed.branches.map((b) => b.id);
  assert.equal(new Set(ids).size, ids.length, `an id repeats: ${ids}`);
  // The same two moves, twice, told apart only by the door.
  const shared = listed.branches.filter((b) => b.san === 'e4 c5');
  assert.equal(shared.length, 2, `branches with the same pair: ${shared.length}`);
  assert.deepEqual(shared.map((b) => b.repertoire.id).sort((a, b) => a - b),
    [3, 9]);
  assert.deepEqual(shared.map((b) => b.gateUci), [null, 'e2e4']);
});

test('asked by root rather than by id, a branch has nothing to name',
  async () => {
    // The old shape, unchanged. `repertoire` is null rather than invented,
    // because the caller did not say which one this is.
    const pool = stubPool({ ...SICILIAN, reviews: [] });
    const listed = await drillBranches(pool, 7, { color: 'w', rootFen: START });

    assert.ok(listed.branches.length > 0);
    for (const branch of listed.branches) {
      assert.equal(branch.repertoire, null);
      assert.match(branch.id, /^0:/);
    }
  });

test('a combined line is built from the door the question is behind',
  async () => {
    // The breadcrumb has to read from the right root, or it does not add up on
    // the board: the question is four plies from the start and two from the
    // Sicilian's own door, and only one of those lines is the one being
    // rehearsed.
    const pool = stubPool({
      ...SICILIAN,
      fresh: [{ fen_key: DEEP, mistakes: 0 }],
    });
    const line = await drillLine(pool, 7, { color: 'w', roots: TWO_DOORS });

    assert.equal(line.question.fenKey, DEEP);
    // First door wins where both reach it, which is the same first-wins rule
    // the walk itself keeps — and it is one question either way, because the
    // schedule is keyed by position.
    assert.equal(line.repertoire.id, 3);
    assert.equal(line.root.fen, START);
    assert.deepEqual(line.prefix.map((m) => m.san), ['e4', 'c5', 'Nf3', 'd6']);
  });

test('a combined session is the repertoires named, not the whole colour',
  async () => {
    // With a single ungated door `only: null` still means the whole colour,
    // which is what the schedule is keyed by; with two doors it means their
    // union, or ticking two openings would quietly drill a third.
    const pool = stubPool({
      ...SICILIAN,
      fresh: [{ fen_key: DEEP, mistakes: 0 }],
    });
    await drillLine(pool, 7, { color: 'w', roots: TWO_DOORS });

    const asked = pool.paramsOf('AS positions');
    assert.ok(Array.isArray(asked[3]), 'the counts were not narrowed to the chosen ones');
    assert.ok(asked[3].includes(DEEP));

    const one = stubPool({ ...SICILIAN, fresh: [{ fen_key: DEEP, mistakes: 0 }] });
    await drillLine(one, 7, { color: 'w', rootFen: START });
    assert.equal(one.paramsOf('AS positions')[3], null);
  });

test('each door of a combined session is walked on its own', async () => {
  // Two walks, so two sets of queries for the entered moves: the doors do not
  // share a walk, and each is read from its own root and gate.
  const pool = stubPool({ ...SICILIAN, reviews: [] });
  await drillBranches(pool, 7, { color: 'w', roots: TWO_DOORS });

  const reads = pool.calls.filter(
    (c) => c.text.includes('FROM repertoire_extra_replies e'));
  assert.ok(reads.length >= 2, `waves: ${reads.length}`);
});
