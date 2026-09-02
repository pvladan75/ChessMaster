const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const {
  putComment, removeComment, commentsFor, MAX_BODY,
} = require('../services/repertoireComments');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

/// A pool that models the one rule this table holds: one row per (colour,
/// position), replaced on write and gone on an empty body.
function stubPool({ comments = [] } = {}) {
  const calls = [];
  const stored = new Map(comments.map((row) => [row.fen_key, { ...row }]));
  return {
    calls,
    stored,
    query: async (text, params) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      if (flat.startsWith('INSERT INTO repertoire_comments')) {
        const [, , key, body] = params;
        const row = {
          fen_key: key,
          body,
          updated_at: new Date('2026-09-02T10:00:00Z'),
        };
        stored.set(key, row);
        return { rows: [row], rowCount: 1 };
      }
      if (flat.startsWith('DELETE FROM repertoire_comments')) {
        const key = params[2];
        const had = stored.delete(key);
        return { rows: [], rowCount: had ? 1 : 0 };
      }
      if (flat.includes('FROM repertoire_comments')) {
        const wanted = params[2];
        const rows = [...stored.values()]
          .filter((row) => wanted === null || wanted.includes(row.fen_key));
        return { rows, rowCount: rows.length };
      }
      throw new Error(`Neočekivan upit: ${flat}`);
    },
  };
}

test('a comment is stored on the position, not on the line', async () => {
  // The whole reason it is keyed like the moves: the same board reached another
  // way carries what was written about it.
  const pool = stubPool();
  await putComment(pool, 7, { color: 'w', fen: after('e2e4'), body: 'Plan: d4 i c4.' });

  const read = await commentsFor(pool, 7, { color: 'w' });
  assert.equal(read.comments.length, 1);
  assert.equal(read.comments[0].fenKey, fenKey(after('e2e4')));
  assert.equal(read.comments[0].body, 'Plan: d4 i c4.');
});

test('writing again replaces, it does not add a second row', async () => {
  const pool = stubPool();
  await putComment(pool, 7, { color: 'w', fen: START, body: 'prvo' });
  const second = await putComment(pool, 7, { color: 'w', fen: START, body: 'drugo' });

  assert.equal(second.stored, true);
  assert.equal(second.comment.body, 'drugo');
  assert.equal(pool.stored.size, 1);
});

test('an emptied box deletes the row rather than storing nothing', async () => {
  // A stored empty comment would draw a comment card on a position nobody has
  // said anything about.
  const pool = stubPool();
  await putComment(pool, 7, { color: 'w', fen: START, body: 'nešto' });
  const cleared = await putComment(pool, 7, { color: 'w', fen: START, body: '   ' });

  assert.equal(cleared.stored, false);
  assert.equal(cleared.removed, 1);
  assert.equal(cleared.comment, null);
  assert.equal(pool.stored.size, 0);
});

test('the delete door does the same thing as an emptied box', async () => {
  const pool = stubPool();
  await putComment(pool, 7, { color: 'b', fen: START, body: 'nešto' });
  const gone = await removeComment(pool, 7, { color: 'b', fen: START });

  assert.equal(gone.removed, 1);
  assert.equal(pool.stored.size, 0);
});

test('a comment longer than the cap is refused, not truncated', async () => {
  // Truncating would store half a sentence and say it saved.
  const pool = stubPool();
  await assert.rejects(
    () => putComment(pool, 7, { color: 'w', fen: START, body: 'x'.repeat(MAX_BODY + 1) }),
    RangeError,
  );
  assert.equal(pool.stored.size, 0);
});

test('a colour is refused before anything is written', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => putComment(pool, 7, { color: 'x', fen: START, body: 'nešto' }),
    RangeError,
  );
  assert.equal(pool.calls.length, 0);
});

test('reading by keys asks only for the positions named', async () => {
  const pool = stubPool();
  await putComment(pool, 7, { color: 'w', fen: START, body: 'koren' });
  await putComment(pool, 7, { color: 'w', fen: after('e2e4'), body: 'posle e4' });

  const read = await commentsFor(pool, 7, {
    color: 'w', keys: [fenKey(after('e2e4'))],
  });
  assert.equal(read.comments.length, 1);
  assert.equal(read.comments[0].body, 'posle e4');
});
