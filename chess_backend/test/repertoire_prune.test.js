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
  moves = [], extras = [], roots = [START], counts = {},
} = {}) {
  const calls = [];
  const deleted = [];
  const sweeps = [];
  const chosen = () => moves.filter((m) => (m.source ?? 'chosen') === 'chosen');
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (flat.includes('FROM repertoires WHERE user_id')) {
      const rows = roots.map((root_fen) => ({ root_fen, via_uci: null }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('SELECT fen_key, uci, san, role, source')) {
      const rows = flat.includes("source = 'chosen'") ? chosen() : moves;
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('FROM repertoire_extra_replies e')) {
      const keys = params[2];
      const rows = extras
        .filter((e) => keys.includes(e.fen_key))
        .map((e) => ({ games: 0, share: 0, ...e }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('AS decisions')) {
      return { rows: [{ decisions: counts.decisions ?? 0 }], rowCount: 1 };
    }
    if (flat.startsWith('SELECT fen_key, uci FROM repertoire_moves')) {
      return { rows: chosen(), rowCount: chosen().length };
    }
    if (flat.includes('DELETE FROM repertoire_moves')) {
      deleted.push(params);
      return { rows: [], rowCount: counts.removed ?? 1 };
    }
    if (flat.includes('DELETE FROM repertoire_extra_replies')) {
      sweeps.push(params);
      return { rows: [], rowCount: 0 };
    }
    if (flat.includes("SET role = 'primary'")) return { rows: [], rowCount: 0 };
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(flat)) {
      return { rows: [], rowCount: 0 };
    }
    throw new Error(`Unexpected query: ${flat}`);
  };
  return {
    calls,
    deleted,
    sweeps,
    query,
    connect: async () => ({ query, release: () => {} }),
  };
}

/// 1.e4 and 1.d4, both kept. The student entered one reply to each, and both
/// are answered — two separate branches.
const TWO_FIRST_MOVES = {
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
    { fen_key: fenKey(START), uci: 'd2d4', san: 'd4', role: 'alternate' },
    { fen_key: keyAfter('e2e4', 'e7e5'), uci: 'g1f3', san: 'Nf3', role: 'primary' },
    { fen_key: keyAfter('d2d4', 'd7d5'), uci: 'c2c4', san: 'c4', role: 'primary' },
  ],
  extras: [
    { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5' },
    { fen_key: keyAfter('d2d4'), uci: 'd7d5', san: 'd5' },
  ],
};

test('reachability follows the student\'s moves and the replies they entered',
  async () => {
    const pool = stubPool(TWO_FIRST_MOVES);
    const seen = await reachable(pool, 7, { color: 'w', from: [START] });

    assert.ok(seen.has(keyAfter('e2e4', 'e7e5')));
    assert.ok(seen.has(keyAfter('d2d4', 'd7d5')));
  });

test('a move the retired spine wrote is not a way through', async () => {
  const pool = stubPool({
    ...TWO_FIRST_MOVES,
    moves: TWO_FIRST_MOVES.moves.map((m) => (
      m.uci === 'd2d4' ? { ...m, source: 'auto' } : m)),
  });
  const seen = await reachable(pool, 7, { color: 'w', from: [START] });

  assert.equal(seen.has(keyAfter('d2d4', 'd7d5')), false);
});

test('removing a move of the student\'s strands only what nothing else reaches',
  async () => {
    const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { decisions: 1 } });
    const out = await orphansOfRemoving(pool, 7, {
      color: 'w', fen: START, uci: 'd2d4',
    });

    // The position after 1...d5 was only ever reached through the move that is
    // going; 1.e4 and everything under it is untouched.
    assert.deepEqual(out.keys, [keyAfter('d2d4', 'd7d5')]);
    assert.equal(out.decisions, 1);
  });

test('removing an entered opponent move strands what was behind it', async () => {
  // The opponent's move is an edge of the walk like the student's own. Delete
  // 1...d5 and the student's 2.c4 after it has nothing leading to it.
  const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { decisions: 1 } });
  const out = await orphansOfRemoving(pool, 7, {
    color: 'w', fen: after('d2d4'), uci: 'd7d5',
  });

  assert.deepEqual(out.keys, [keyAfter('d2d4', 'd7d5')]);
  assert.equal(out.keys.includes(keyAfter('e2e4', 'e7e5')), false);
});

test('an opponent move with nothing behind it strands no decision', async () => {
  // The position right after it is reported, as it is for a move of the
  // student's — it is where the walk starts — and nothing of theirs stands
  // there, so there is nothing to ask about.
  const pool = stubPool({
    ...TWO_FIRST_MOVES,
    extras: [
      ...TWO_FIRST_MOVES.extras,
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5' },
    ],
  });
  const out = await orphansOfRemoving(pool, 7, {
    color: 'w', fen: after('e2e4'), uci: 'c7c5',
  });

  assert.deepEqual(out.keys, [keyAfter('e2e4', 'c7c5')]);
  assert.equal(out.decisions, 0);
  const counted = pool.calls.find((c) => c.text.includes('AS decisions'));
  assert.deepEqual(counted.params[2], [keyAfter('e2e4', 'c7c5')]);
});

test('a position two moves reach is not stranded by losing one of them',
  async () => {
    // Black meets 1.e4 with 1...c5 and answers both 2.Nf3 and 2.Nc3 with 2...Nc6;
    // White's next move transposes the two. Take away the Nc6 that answers
    // 2.Nf3 and that board is still reached the other way round.
    const root = after('e2e4');
    const meeting = keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6', 'b1c3');
    assert.equal(meeting, keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6', 'g1f3'),
      'these two must be one position, or this test measures nothing');

    const pool = stubPool({
      roots: [root],
      moves: [
        { fen_key: fenKey(root), uci: 'c7c5', san: 'c5', role: 'primary' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'), uci: 'b8c6', san: 'Nc6', role: 'primary' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'b1c3'), uci: 'b8c6', san: 'Nc6', role: 'primary' },
        { fen_key: meeting, uci: 'g8f6', san: 'Nf6', role: 'primary' },
      ],
      extras: [
        { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3' },
        { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'b1c3', san: 'Nc3' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6'), uci: 'b1c3', san: 'Nc3' },
        { fen_key: keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6'), uci: 'g1f3', san: 'Nf3' },
      ],
    });

    const out = await orphansOfRemoving(pool, 7, {
      color: 'b',
      fen: after('e2e4', 'c7c5', 'g1f3'),
      uci: 'b8c6',
    });

    assert.equal(out.keys.includes(meeting), false,
      'the sweep took a position still reached by the other move order');
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

test('a key that is reachable again is not deleted, whatever the list said',
  async () => {
    // The list comes from a question asked a moment earlier, and a move played
    // in another window is enough to make it wrong.
    const pool = stubPool(TWO_FIRST_MOVES);
    const out = await pruneKeys(pool, 7, {
      color: 'w', keys: [keyAfter('e2e4', 'e7e5')],
    });

    assert.equal(out.removed, 0);
    assert.equal(pool.deleted.length, 0);
  });

test('the sweep, the promotion and the dangling replies are one transaction',
  async () => {
    // A position with moves and no primary is one the drill cannot ask about,
    // and an opponent move left after a deleted move hangs off nothing.
    const pool = stubPool({ ...TWO_FIRST_MOVES, counts: { removed: 1 } });
    await pruneKeys(pool, 7, {
      color: 'w', keys: [keyAfter('d2d4', 'd7d5', 'c2c4', 'e7e6')],
    });

    const texts = pool.calls.map((c) => c.text);
    const begin = texts.indexOf('BEGIN');
    const commit = texts.indexOf('COMMIT');
    assert.ok(begin >= 0 && commit > begin);
    const inside = texts.slice(begin, commit);
    assert.ok(inside.some((t) => t.includes('DELETE FROM repertoire_moves')));
    assert.ok(inside.some((t) => t.includes("SET role = 'primary'")));
    assert.ok(inside.some((t) => t.includes('DELETE FROM repertoire_extra_replies')));
  });
