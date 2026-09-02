const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const {
  unconfirmedPositions, unconfirmedCounts, draftsAt,
} = require('../services/repertoireUnconfirmed');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

/// Computed rather than pasted, like every other walk test here: a hand-written
/// FEN is a chance to assert against a position that does not exist, and the
/// service would then be right while the test is wrong.
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

function stubPool({
  moves = [], replies = [], skips = [], counts = [],
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
        if (flat.includes('SELECT fen_key, uci, san, role')) {
          return params[2] === true
            ? moves.filter((m) => (m.source ?? 'chosen') === 'chosen')
            : moves;
        }
        if (flat.includes('FROM repertoire_skips')) {
          return skips.map((fen_key) => ({ fen_key }));
        }
        if (flat.includes('FROM opening_replies')) {
          const [band, keys] = params;
          // The whole book: `covered` and `asked` are columns the breadth rule
          // reads at walk time, not a filter this query applies.
          return replies
            .filter((r) => Number(r.min_rating ?? 0) === band
              && keys.includes(r.fen_key))
            .map((r) => ({ covered: true, asked: false, ...r }));
        }
        if (flat.includes('GROUP BY color')) return counts;
        throw new Error(`Neočekivan upit: ${flat}`);
      })();
      return { rows, rowCount: rows.length };
    },
  };
}

/// A spine's worth of 1.e4 c5 2.Nf3 d6 3.d4, every move of it generated, plus
/// one position where the student has actually decided.
const SPINE = {
  moves: [
    {
      fen_key: fenKey(START), uci: 'e2e4', san: 'e4',
      role: 'primary', source: 'auto',
    },
    {
      fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3',
      role: 'primary', source: 'auto',
    },
    {
      fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'd7d6'), uci: 'd2d4', san: 'd4',
      role: 'primary', source: 'chosen',
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

test('the drafts come back in the order the walk meets them', async () => {
  // Walk order, not reach order. The review is played forwards — a board, the
  // drafted move, and a question — so walking it is walking down the line the
  // student will actually play.
  const walk = await unconfirmedPositions(stubPool(SPINE), 7, {
    color: 'w', rootFen: START,
  });

  assert.deepEqual(walk.positions.map((p) => p.fenKey), [
    fenKey(START),
    keyAfter('e2e4', 'c7c5'),
  ]);
  assert.equal(walk.total, 2);
  // With the line that reaches each one: a draft with no path is a board with
  // no story.
  assert.deepEqual(walk.positions[1].path, ['e4', 'c5']);
  assert.equal(walk.positions[1].ply, 2);
  assert.deepEqual(walk.positions[1].moves, [
    { uci: 'g1f3', san: 'Nf3', role: 'primary' },
  ]);
});

test('a position the student decided is not asked about again', async () => {
  // 3.d4 was chosen. Putting it in the review would ask somebody to re-confirm
  // a move they made themselves.
  const walk = await unconfirmedPositions(stubPool(SPINE), 7, {
    color: 'w', rootFen: START,
  });

  assert.equal(
    walk.positions.some(
      (p) => p.fenKey === keyAfter('e2e4', 'c7c5', 'g1f3', 'd7d6')),
    false,
  );
});

test('a draft beside a decision is scaffolding, not a question', async () => {
  // The same rule the coverage map already calls `draft`, said once here so the
  // two cannot drift. A position with a decision in it has been answered for,
  // whatever else is lying beside it.
  assert.equal(draftsAt([
    { uci: 'e2e4', san: 'e4', role: 'primary', source: 'chosen' },
    { uci: 'd2d4', san: 'd4', role: 'alternate', source: 'auto' },
  ]), null);
  // And a position with nothing in it is not a draft either — it is an open
  // question, which is the queue's business and not this one's.
  assert.equal(draftsAt([]), null);
});

test('a cut branch is not a list of things to agree to', async () => {
  // `repertoire_skips` says "do not prepare this". Handing its drafts back as a
  // review would ask the student to confirm the branch they had just refused.
  const walk = await unconfirmedPositions(
    stubPool({ ...SPINE, skips: [keyAfter('e2e4', 'c7c5')] }), 7,
    { color: 'w', rootFen: START },
  );

  assert.deepEqual(walk.positions.map((p) => p.fenKey), [fenKey(START)]);
});

test('the review walks the drafts rather than stopping at the first one',
  async () => {
    // `onlyChosen` would hide every position this read exists for, and would
    // also stop the walk dead at the first drafted move — 1.e4 is a draft, so
    // nothing below it would ever be reached.
    const pool = stubPool(SPINE);
    await unconfirmedPositions(pool, 7, { color: 'w', rootFen: START });

    assert.equal(pool.paramsOf('SELECT fen_key, uci, san, role')[2], false);
  });

test('the gate narrows the review, because it is a walk', async () => {
  // Gate-aware and breadth-aware, unlike the card's count. The two can differ,
  // and the screen with room for a sentence is the one that gets the exact
  // number.
  const pool = stubPool(SPINE);
  const walk = await unconfirmedPositions(pool, 7, {
    color: 'w', rootFen: START, gateUci: 'd2d4',
  });

  // Nothing is kept for 1.d4, so the gated walk leaves the root with no move to
  // follow — and a root whose only draft is behind another gate is not this
  // repertoire's draft.
  assert.deepEqual(walk.positions, []);
});

test('the count is what there is, not what was sent', async () => {
  // A banner that counted the page it was given would say "1" forever on a
  // repertoire with three hundred drafts in it.
  const walk = await unconfirmedPositions(stubPool(SPINE), 7, {
    color: 'w', rootFen: START, limit: 1,
  });

  assert.equal(walk.positions.length, 1);
  assert.equal(walk.total, 2);
});

test('the card counts both colours in one query and never walks', async () => {
  const pool = stubPool({
    counts: [{ color: 'b', positions: 12, moves: 14 }],
  });
  const counts = await unconfirmedCounts(pool, 7);

  assert.deepEqual(counts, {
    // Both colours always. A missing key and a zero read the same on a badge
    // and differently in code.
    w: { positions: 0, moves: 0 },
    b: { positions: 12, moves: 14 },
  });
  assert.equal(pool.calls.length, 1, 'kartica ne sme da šeta po repertoaru');
  assert.equal(
    pool.calls[0].text.includes('FROM opening_replies'), false,
    'brojanje je otvorilo knjigu',
  );
});
