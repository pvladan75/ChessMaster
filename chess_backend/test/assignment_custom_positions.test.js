// Which items of an assignment are the trainer's own positions.
//
// Found live on 20.9.2026: an exercise made by hand (`ex_…`) and set as
// homework opened on "Assignment complete. Your trainer can see the result."
// for a student who had never seen the board. `getAssignmentDetail` told a
// trainer's position from a Lichess puzzle by `id.startsWith('cust_')` — a rule
// written when scans were the only writer of `custom_puzzles`. A hand-made
// exercise is `ex_…`, one made from mistakes is `hw_…`; both travelled without
// their position, the app took them for Lichess ids, could load none, skipped
// each in silence and announced the end.
//
// A prefix is not a column (`docs/PLAN-EXERCISE.md`, §3). A trainer's position
// is one that is in `custom_puzzles`; the table is asked, the id is not read.
//
// Fake the client, assert the request (CLAUDE.md rule 7).
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';
const { loadCustomPositions } = require('../services/assignmentService');

function fakePool(rows) {
  const asked = [];
  return {
    asked,
    query: async (text, values) => {
      asked.push({ text, values });
      const wanted = new Set(values[0]);
      return { rows: rows.filter((r) => wanted.has(r.puzzle_id)) };
    },
  };
}

const ROWS = [
  { puzzle_id: 'cust_aaaa', fen: 'f1' },
  { puzzle_id: 'ex_54d406e054660c5b', fen: 'f2' },
  { puzzle_id: 'hw_bbbb', fen: 'f3' },
];

test('every id is asked of the table, whatever it starts with', async () => {
  const pool = fakePool(ROWS);
  const found = await loadCustomPositions(pool, [
    { puzzle_id: 'ex_54d406e054660c5b' }, { puzzle_id: 'hw_bbbb' }, { puzzle_id: 'cust_aaaa' },
  ]);
  assert.equal(pool.asked.length, 1);
  assert.match(pool.asked[0].text, /FROM custom_puzzles/);
  assert.deepEqual([...pool.asked[0].values[0]].sort(), ['cust_aaaa', 'ex_54d406e054660c5b', 'hw_bbbb']);
  assert.deepEqual(found.map((r) => r.puzzle_id).sort(), ['cust_aaaa', 'ex_54d406e054660c5b', 'hw_bbbb']);
});

test('the answer never travels with the question', async () => {
  const pool = fakePool(ROWS);
  await loadCustomPositions(pool, [{ puzzle_id: 'ex_54d406e054660c5b' }]);
  const selected = pool.asked[0].text.split(/FROM/i)[0];
  assert.doesNotMatch(selected, /solution/i);
  assert.doesNotMatch(selected, /\*/);
});

test('a Lichess set is no trainer\'s position: asked, not found, null', async () => {
  const pool = fakePool(ROWS);
  assert.equal(await loadCustomPositions(pool, [{ puzzle_id: '00sHx' }, { puzzle_id: 'Zk3aP' }]), null);
  assert.equal(pool.asked.length, 1);
});

test('items without a puzzle (a tutorial\'s steps, a game) ask nothing', async () => {
  const pool = fakePool(ROWS);
  assert.equal(await loadCustomPositions(pool, [{ puzzle_id: null }, {}]), null);
  assert.equal(pool.asked.length, 0);
});
