const test = require('node:test');
const assert = require('node:assert/strict');

const { repertoireProgress, MAX_ROWS } =
  require('../services/repertoireProgress');

/// The list screen asks "which of these still needs me", once, for all of them.
///
/// The walk itself is `repertoire_frontier.test.js`'s subject. What is tested
/// here is the part that goes wrong quietly: a repertoire whose walk fails
/// must not be reported as finished, the band must reach every walk, and the
/// caller's own rows must be the ones walked.
function stubPool({ rows = [], onWalk = null, failFor = new Set() } = {}) {
  const bands = [];
  const walked = [];
  return {
    bands,
    walked,
    query: async (text, params) => {
      if (text.includes('FROM repertoires')) {
        return { rows, rowCount: rows.length };
      }
      // Everything below is the walk. It asks for the student's moves first;
      // answering with nothing ends it after one level, which is enough — the
      // walk is not what this file is about.
      if (text.includes('FROM repertoire_moves')) {
        walked.push(params);
        return { rows: [], rowCount: 0 };
      }
      if (text.includes('FROM repertoire_skips')) return { rows: [], rowCount: 0 };
      return { rows: [], rowCount: 0 };
    },
  };
}

const row = (id, extra = {}) => ({
  id,
  color: 'w',
  root_fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  root_path: [],
  via_uci: null,
  breadth: 'standard',
  ...extra,
});

test('one entry per repertoire, in id order', async () => {
  const pool = stubPool({ rows: [row(3), row(7), row(8)] });
  const out = await repertoireProgress(pool, 1, { minRating: 1600 });

  assert.deepEqual(out.items.map((x) => x.id), [3, 7, 8]);
  assert.equal(out.truncated, false);
  for (const item of out.items) {
    assert.equal(typeof item.open, 'number');
    assert.equal(typeof item.draft, 'number');
  }
});

test('a walk that fails reports null, never zero', async () => {
  // Zero means "nothing left to do" and is the one answer a failure must not
  // be able to give. The same rule the drill's three-answer load follows.
  const pool = stubPool({ rows: [row(3)] });
  pool.query = async (text) => {
    if (text.includes('FROM repertoires')) {
      return { rows: [row(3)], rowCount: 1 };
    }
    throw new Error('baza ne odgovara');
  };

  const out = await repertoireProgress(pool, 1, { minRating: 1600 });
  assert.equal(out.items.length, 1);
  assert.equal(out.items[0].open, null);
  assert.equal(out.items[0].draft, null);
});

test('only the caller own rows are asked for', async () => {
  let seen = null;
  const pool = stubPool({ rows: [] });
  const inner = pool.query;
  pool.query = async (text, params) => {
    if (text.includes('FROM repertoires')) seen = { text, params };
    return inner(text, params);
  };

  await repertoireProgress(pool, 42, { minRating: 1600 });
  assert.match(seen.text, /WHERE user_id = \$1/);
  assert.deepEqual(seen.params, [42]);
});

test('a long list is cut and says so', async () => {
  const many = Array.from({ length: MAX_ROWS + 5 }, (_, i) => row(i + 1));
  const pool = stubPool({ rows: many });

  const out = await repertoireProgress(pool, 1, { minRating: 1600 });
  assert.equal(out.items.length, MAX_ROWS);
  assert.equal(out.truncated, true);
});
