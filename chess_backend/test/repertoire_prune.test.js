const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const {
  reachable, orphansOfRemoving, pruneKeys,
} = require('../services/repertoirePrune');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

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
  moves = [], replies = [], roots = [START], counts = {},
} = {}) {
  const calls = [];
  const deleted = [];
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (flat.includes('FROM repertoires WHERE user_id')) {
      const rows = roots.map((root_fen) => ({ root_fen }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('SELECT fen_key, uci, san, role, source')) {
      return { rows: moves, rowCount: moves.length };
    }
    if (flat.includes('FROM opening_replies')) {
      const [band, keys] = params;
      // The whole book for the position: `covered` and `asked` are columns the
      // breadth rule reads, not a filter the query applies.
      const rows = replies
        .filter((r) => Number(r.min_rating ?? 0) === band
          && keys.includes(r.fen_key))
        .map((r) => ({ covered: true, asked: false, ...r }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes("FILTER (WHERE source = 'auto')")) {
      return {
        rows: [{ drafts: counts.drafts ?? 0, decisions: counts.decisions ?? 0 }],
        rowCount: 1,
      };
    }
    if (flat.includes('DELETE FROM repertoire_moves')) {
      deleted.push(params);
      return { rows: [], rowCount: counts.removed ?? 1 };
    }
    if (flat.includes('AS moves')) {
      return { rows: [{ moves: counts.kept ?? 0 }], rowCount: 1 };
    }
    if (flat.includes("SET role = 'primary'")) return { rows: [], rowCount: 0 };
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(flat)) {
      return { rows: [], rowCount: 0 };
    }
    throw new Error(`Neočekivan upit: ${flat}`);
  };
  return {
    calls,
    deleted,
    query,
    connect: async () => ({ query, release: () => {} }),
  };
}

/// 1.e4 and 1.d4, both kept. Black answers each with one reply, and both of
/// those transpose nowhere — two separate branches.
const TWO_FIRST_MOVES = {
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary', source: 'chosen' },
    { fen_key: fenKey(START), uci: 'd2d4', san: 'd4', role: 'alternate', source: 'auto' },
  ],
  replies: [
    { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5', games: 500, share: '0.5' },
    { fen_key: keyAfter('d2d4'), uci: 'd7d5', san: 'd5', games: 500, share: '0.5' },
  ],
};

test('reachability follows drafts as well as decisions', async () => {
  // A draft is still a way through. Leaving them out would call everything
  // under a generated move an orphan the moment it was written.
  const pool = stubPool(TWO_FIRST_MOVES);
  const seen = await reachable(pool, 7, { color: 'w', from: [START] });

  assert.ok(seen.has(keyAfter('e2e4', 'e7e5')));
  assert.ok(seen.has(keyAfter('d2d4', 'd7d5')));
});

test('removing a move strands only what nothing else reaches', async () => {
  // The whole point of computing this rather than deleting a subtree.
  const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { drafts: 1 } });
  const out = await orphansOfRemoving(pool, 7, {
    color: 'w', fen: START, uci: 'd2d4',
  });

  // The position after 1.d4 itself, and the one after 1...d5 — both were only
  // ever reached through the move that is going.
  assert.deepEqual([...out.keys].sort(),
    [keyAfter('d2d4'), keyAfter('d2d4', 'd7d5')].sort());
  // 1.e4 and everything under it is untouched: it was never reached through
  // the move that went.
  assert.equal(out.keys.includes(keyAfter('e2e4', 'e7e5')), false);
});

test('a position two moves reach is not stranded by losing one of them',
  async () => {
    // The reason this is a subtraction and not a subtree walk. Black meets 1.e4
    // with 1...c5 and answers both 2.Nf3 and 2.Nc3 with 2...Nc6; White's next
    // move transposes the two, so 2.Nf3 Nc6 3.Nc3 and 2.Nc3 Nc6 3.Nf3 are one
    // board. Take away the Nc6 that answers 2.Nf3 and that board is still
    // reached the other way round.
    const root = after('e2e4');
    const meeting = keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6', 'b1c3');
    assert.equal(meeting, keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6', 'g1f3'),
      'ovo dvoje mora da bude ista pozicija, inače test ne meri ništa');

    const pool = stubPool({
      roots: [root],
      moves: [
        { fen_key: fenKey(root), uci: 'c7c5', san: 'c5', role: 'primary', source: 'chosen' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'), uci: 'b8c6', san: 'Nc6', role: 'primary', source: 'chosen' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'b1c3'), uci: 'b8c6', san: 'Nc6', role: 'primary', source: 'chosen' },
      ],
      replies: [
        { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3', games: 500, share: '0.5' },
        { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'b1c3', san: 'Nc3', games: 500, share: '0.5' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6'), uci: 'b1c3', san: 'Nc3', games: 500, share: '1' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6'), uci: 'g1f3', san: 'Nf3', games: 500, share: '1' },
      ],
    });

    const out = await orphansOfRemoving(pool, 7, {
      color: 'b',
      fen: after('e2e4', 'c7c5', 'g1f3'),
      uci: 'b8c6',
    });

    assert.equal(out.keys.includes(meeting), false,
      'orezivanje je odnelo poziciju do koje se stiže i drugim redosledom');
  });

test('a move that will not replay strands nothing', async () => {
  const pool = stubPool(TWO_FIRST_MOVES);
  const out = await orphansOfRemoving(pool, 7, {
    color: 'w', fen: START, uci: 'e2e5',
  });

  assert.deepEqual(out.keys, []);
});

test('a colour with no repertoire refuses rather than calling all of it dead',
  async () => {
    // Without a root every position is unreachable, and a sweep that believed
    // that would delete the lot.
    const pool = stubPool({ ...TWO_FIRST_MOVES, roots: [] });
    await assert.rejects(
      () => orphansOfRemoving(pool, 7, { color: 'w', fen: START, uci: 'd2d4' }),
      RangeError);
    await assert.rejects(
      () => pruneKeys(pool, 7, { color: 'w', keys: ['x'] }), RangeError);
  });

test('drafts go by default and decisions do not', async () => {
  const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { removed: 1, kept: 2 } });
  // A position nothing in this fixture reaches — the walk stops at 1...d5.
  await pruneKeys(pool, 7, {
    color: 'w', keys: [keyAfter('d2d4', 'd7d5', 'c2c4')],
  });

  const del = pool.deleted[0];
  assert.equal(del[3], false, 'odluke su obrisane bez pitanja');
});

test('the confirmation says so, and only then do decisions go', async () => {
  const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { removed: 3 } });
  await pruneKeys(pool, 7, {
    color: 'w',
    keys: [keyAfter('d2d4', 'd7d5', 'c2c4')],
    includeDecisions: true,
  });

  assert.equal(pool.deleted[0][3], true);
});

test('a key that is reachable again is not deleted, whatever the list said',
  async () => {
    // The list comes from a question asked a moment earlier, and a spine run in
    // another window is enough to make it wrong.
    const pool = stubPool(TWO_FIRST_MOVES);
    const out = await pruneKeys(pool, 7, {
      color: 'w', keys: [keyAfter('e2e4', 'e7e5')],
    });

    assert.equal(out.removed, 0);
    assert.equal(pool.deleted.length, 0);
  });

test('the sweep and the promotion are one transaction', async () => {
  // A position with moves and no primary is one the drill cannot ask about, and
  // between those two statements is exactly where a dropped connection leaves
  // one.
  const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { removed: 1 } });
  await pruneKeys(pool, 7, {
    color: 'w', keys: [keyAfter('d2d4', 'd7d5', 'c2c4')],
  });

  const texts = pool.calls.map((c) => c.text);
  assert.ok(texts.includes('BEGIN'));
  assert.ok(texts.includes('COMMIT'));
  assert.ok(texts.some((t) => t.includes("SET role = 'primary'")));
});
