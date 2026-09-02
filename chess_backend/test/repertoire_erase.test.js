const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const {
  orphansOfDeleting, deleteRepertoire, colorStats, eraseColor, POSITION_TABLES,
} = require('../services/repertoireErase');
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

/// A pool over the queries these two doors ask: the walk's two (moves, book),
/// the repertoire rows, the two counts, and the deletes.
///
/// The deletes are recorded rather than modelled — what matters is *which
/// tables* were emptied and *with which keys*, which is the whole contract.
function stubPool({
  repertoires = [], moves = [], replies = [], comments = 0, counts = {},
} = {}) {
  const calls = [];
  const deletes = [];
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (flat.startsWith('DELETE FROM')) {
      const table = flat.split(' ')[2];
      deletes.push({ table, keys: params[2] ?? null });
      return { rows: [], rowCount: counts[table] ?? 1 };
    }
    if (flat.includes('FROM repertoires WHERE id')) {
      const rows = repertoires.filter((r) => r.id === params[0]);
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('SELECT root_fen, via_uci FROM repertoires')) {
      const rows = repertoires.filter(
        (r) => r.color === params[1] && r.id !== params[2]);
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('AS repertoires FROM repertoires')) {
      const rows = repertoires.filter((r) => r.color === params[1]);
      return { rows: [{ repertoires: rows.length }], rowCount: 1 };
    }
    if (flat.includes('SELECT fen_key, uci, san, role, source')) {
      return { rows: moves, rowCount: moves.length };
    }
    if (flat.includes('FROM opening_replies')) {
      const [band, keys] = params;
      const rows = replies.filter(
        (r) => Number(r.min_rating ?? 0) === band && keys.includes(r.fen_key));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('AS positions')) {
      const keys = params[2];
      const mine = moves.filter(
        (m) => keys === null || keys.includes(m.fen_key));
      return {
        rows: [{
          moves: mine.length,
          positions: new Set(mine.map((m) => m.fen_key)).size,
          drafts: mine.filter((m) => m.source === 'auto').length,
          decisions: mine.filter((m) => m.source !== 'auto').length,
        }],
        rowCount: 1,
      };
    }
    if (flat.includes('AS comments')) {
      return { rows: [{ comments }], rowCount: 1 };
    }
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(flat)) {
      return { rows: [], rowCount: 0 };
    }
    throw new Error(`Neočekivan upit: ${flat}`);
  };
  return {
    calls,
    deletes,
    query,
    connect: async () => ({ query, release: () => {} }),
  };
}

/// Two repertoires of the same colour: one from the start, one from the
/// position after 1.e4 e5. Everything the second reaches, the first reaches too.
///
/// Both roots are positions the student is to move in, which is what the walk
/// takes a root to be — it looks for the moves *they* hold there and stops on a
/// board where they have none.
const SHARED = {
  repertoires: [
    { id: 1, name: 'Sve belim', color: 'w', root_fen: START, root_path: null },
    {
      id: 2,
      name: 'Otvorena partija',
      color: 'w',
      root_fen: after('e2e4', 'e7e5'),
      root_path: 'e4 e5',
    },
  ],
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary', source: 'chosen' },
    { fen_key: keyAfter('e2e4', 'e7e5'), uci: 'g1f3', san: 'Nf3', role: 'primary', source: 'chosen' },
  ],
  replies: [
    { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5', games: 500, share: '0.5' },
  ],
};

test('deleting one of two repertoires strands only what the other cannot reach',
  async () => {
    // The subtraction is the point. Everything under 1.e4 is still played by
    // the repertoire that starts from the initial position.
    const pool = stubPool(SHARED);
    const out = await orphansOfDeleting(pool, 7, { id: 2 });

    assert.equal(out.keys.length, 0);
    assert.equal(out.moves, 0);
    assert.ok(out.shared > 0);
  });

test('the last repertoire of a colour strands everything it reaches', async () => {
  // No second set to subtract, which is right — and is exactly why the count is
  // shown before the button does anything.
  const pool = stubPool({ ...SHARED, repertoires: [SHARED.repertoires[0]] });
  const out = await orphansOfDeleting(pool, 7, { id: 1 });

  assert.ok(out.keys.includes(fenKey(START)));
  assert.ok(out.keys.includes(keyAfter('e2e4', 'e7e5')));
  assert.equal(out.decisions, 2);
  assert.equal(out.shared, 0);
});

test('deleting without moves touches nothing but the name', async () => {
  // The old behaviour, unchanged, and it is still the default.
  const pool = stubPool(SHARED);
  const done = await deleteRepertoire(pool, 7, { id: 2 });

  assert.equal(done.movesRemoved, 0);
  assert.deepEqual(pool.deletes.map((d) => d.table), ['repertoires']);
});

test('deleting with moves empties every position table, in one transaction',
  async () => {
    const pool = stubPool({ ...SHARED, repertoires: [SHARED.repertoires[0]] });
    await deleteRepertoire(pool, 7, { id: 1, withMoves: true });

    const tables = pool.deletes.map((d) => d.table);
    assert.deepEqual(tables, ['repertoires', ...POSITION_TABLES]);
    // A cut, a review or an evaluation left behind would re-apply to a line
    // rebuilt later — a decision from a repertoire that no longer exists.
    assert.ok(tables.includes('repertoire_skips'));
    assert.ok(tables.includes('repertoire_reviews'));
    assert.ok(pool.calls.some((c) => c.text === 'BEGIN'));
    assert.ok(pool.calls.some((c) => c.text === 'COMMIT'));
  });

test('the comments are kept unless they are asked for by name', async () => {
  const pool = stubPool({ ...SHARED, repertoires: [SHARED.repertoires[0]] });
  await deleteRepertoire(pool, 7, { id: 1, withMoves: true });
  assert.equal(pool.deletes.some((d) => d.table === 'repertoire_comments'), false);

  const second = stubPool({ ...SHARED, repertoires: [SHARED.repertoires[0]] });
  await deleteRepertoire(second, 7, { id: 1, withMoves: true, includeComments: true });
  assert.ok(second.deletes.some((d) => d.table === 'repertoire_comments'));
});

test('the stranded keys are the ones the deletes are given', async () => {
  // Not "everything for the colour" — the subtraction has to reach the SQL, or
  // the dialog counted one thing and the delete took another.
  const pool = stubPool(SHARED);
  const pruned = await orphansOfDeleting(pool, 7, { id: 1 });
  const second = stubPool(SHARED);
  await deleteRepertoire(second, 7, { id: 1, withMoves: true });

  const moves = second.deletes.find((d) => d.table === 'repertoire_moves');
  assert.deepEqual([...moves.keys].sort(), [...pruned.keys].sort());
  // 1.e4 is still reached by the repertoire that starts there, so the initial
  // position goes and the position after 1.e4 stays.
  assert.equal(moves.keys.includes(keyAfter('e2e4')), false);
});

test('a colour can be counted and emptied with no repertoire left at all',
  async () => {
    // The state the owner was in: every repertoire deleted, every move still
    // stored, and `repertoirePrune` refusing to run because there is no root to
    // reason from. This door is the one that opens there.
    const pool = stubPool({ ...SHARED, repertoires: [], comments: 3 });
    const stats = await colorStats(pool, 7, { color: 'w' });

    assert.equal(stats.repertoires, 0);
    assert.equal(stats.moves, 2);
    assert.equal(stats.comments, 3);

    const done = await eraseColor(pool, 7, { color: 'w' });
    assert.equal(done.positions, stats.positions);
    // The whole colour: every delete goes out with a null key list.
    assert.deepEqual(pool.deletes.map((d) => d.table), POSITION_TABLES);
    assert.ok(pool.deletes.every((d) => d.keys === null));
  });

test('emptying a colour leaves the repertoires standing', async () => {
  // A name and a starting point. Somebody emptying the moves is starting that
  // opening over, not saying they no longer play it.
  const pool = stubPool(SHARED);
  await eraseColor(pool, 7, { color: 'w' });
  assert.equal(pool.deletes.some((d) => d.table === 'repertoires'), false);
});

test('two repertoires from one root are told apart by their gates', async () => {
  // The case the gate was built for: both start after 1.e4 e5 2.Nf3 Nc6 3.Bc4
  // Bc5, one plays 4.b4 and the other 4.0-0. Without the gate each looked as
  // though the other reached everything, so deleting either reported that it
  // stranded nothing at all.
  const shared = {
    repertoires: [
      { id: 1, name: 'Evans', color: 'w', root_fen: START, root_path: null, via_uci: 'e2e4' },
      { id: 2, name: 'Mirno', color: 'w', root_fen: START, root_path: null, via_uci: 'd2d4' },
    ],
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary', source: 'chosen' },
      { fen_key: fenKey(START), uci: 'd2d4', san: 'd4', role: 'alternate', source: 'chosen' },
      { fen_key: keyAfter('e2e4', 'e7e5'), uci: 'g1f3', san: 'Nf3', role: 'primary', source: 'chosen' },
      { fen_key: keyAfter('d2d4', 'd7d5'), uci: 'c2c4', san: 'c4', role: 'primary', source: 'chosen' },
    ],
    replies: [
      { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5', games: 500, share: '0.5' },
      { fen_key: keyAfter('d2d4'), uci: 'd7d5', san: 'd5', games: 500, share: '0.5' },
    ],
  };
  const pool = stubPool(shared);
  const out = await orphansOfDeleting(pool, 7, { id: 1 });

  // What only the 1.e4 repertoire reaches — and the root itself stays, because
  // the other one is still standing on it.
  assert.ok(out.keys.includes(keyAfter('e2e4', 'e7e5')));
  assert.equal(out.keys.includes(keyAfter('d2d4', 'd7d5')), false);
  assert.equal(out.keys.includes(fenKey(START)), false);
});

test('a repertoire that is not yours is not found', async () => {
  const pool = stubPool(SHARED);
  await assert.rejects(() => orphansOfDeleting(pool, 7, { id: 99 }), RangeError);
});
