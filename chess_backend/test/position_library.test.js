// position_library.test.js
// Covers the one shelf a trainer reads over three tables that stay apart: what
// each source contributes, who is allowed to see it, and which entries may be
// set as homework.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  listLibrary,
  listScanned,
  listSavedPositions,
  listAnalyses,
  isKind,
} = require('../services/positionLibrary');

/// Captures queries and replays canned rows, one result per call in order.
function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      const rows = results[Math.min(index, results.length - 1)];
      index++;
      return { rows, rowCount: rows.length };
    },
  };
}

function scannedRow(overrides = {}) {
  return {
    puzzle_id: 'cust_1',
    fen: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
    side_to_move: 'w',
    solution_san: 'Ra8#',
    instruction: 'Beli matira u jednom potezu',
    themes: ['mate'],
    source_title: 'Mat u 333',
    source_page: 12,
    source_label: '122',
    needs_review: false,
    created_at: '2026-08-19T10:00:00Z',
    ...overrides,
  };
}

test('a scanned position with a solution can be set as homework', async () => {
  const pool = stubPool([[scannedRow()]]);
  const [item] = await listScanned(pool, 5, {});

  assert.equal(item.kind, 'scan');
  assert.equal(item.id, 'cust_1');
  assert.equal(item.assignable, true);
  assert.equal(item.blockedReason, null);
  assert.equal(item.hasSolution, true);
});

test('a scanned position without a solution says why it cannot be assigned', async () => {
  const pool = stubPool([[scannedRow({ solution_san: null })]]);
  const [item] = await listScanned(pool, 5, {});

  // Nothing could judge the answer, so a child would be told "netačno"
  // whatever they played. The reason travels with the row rather than the
  // picker deciding it a second time.
  assert.equal(item.assignable, false);
  assert.match(item.blockedReason, /nema rešenje/);
});

test('a position still flagged for review cannot be assigned', async () => {
  const pool = stubPool([[scannedRow({ needs_review: true })]]);
  const [item] = await listScanned(pool, 5, {});

  assert.equal(item.assignable, false);
  assert.match(item.blockedReason, /proveru/);
  assert.equal(item.needsReview, true);
});

test('a scanned position is named by its book and printed number', async () => {
  const pool = stubPool([[scannedRow()]]);
  const [item] = await listScanned(pool, 5, {});

  assert.equal(item.title, 'Mat u 333 #122');
});

test('a scanned position with no book still gets a name, not an empty one', async () => {
  const pool = stubPool([[scannedRow({ source_title: null, source_label: null })]]);
  const [item] = await listScanned(pool, 5, {});

  assert.notEqual(item.title.trim(), '');
});

test('saved positions are read through acceptedTrainersOf, not a fourth copy', async () => {
  const pool = stubPool([[]]);
  await listSavedPositions(pool, 5, {});

  // Three hand-written copies of this subquery all forgot the status once, and
  // an unanswered request unlocked the sender's lessons.
  assert.match(pool.calls[0].text, /status = 'accepted'/);
});

test('a course is not one of the positions it contains', async () => {
  const pool = stubPool([[]]);
  await listSavedPositions(pool, 5, {});

  assert.match(pool.calls[0].text, /position_list IS NULL/);
});

test('nothing but a scanned position can be homework yet', async () => {
  const pool = stubPool([
    [{ id: 3, title: 'Završnica', fen: '8/8/8/8/8/8/8/K6k w - - 0 1', pgn: null, tags: [], created_at: null, from_trainer: false }],
  ]);
  const [item] = await listSavedPositions(pool, 5, {});

  // A saved board carries no solution, so it can go into a lesson but not into
  // homework. Saying so is the point: hiding it would look like a bug.
  assert.equal(item.kind, 'position');
  assert.equal(item.assignable, false);
  assert.match(item.blockedReason, /nema rešenje/);
});

test('an analysis is listed without its tree', async () => {
  const pool = stubPool([
    [{ id: 9, title: 'Sicilijanka', starting_fen: 'startpos-ish', created_at: null }],
  ]);
  const [item] = await listAnalyses(pool, 5, {});

  assert.equal(item.kind, 'analysis');
  assert.equal(item.id, '9');
  assert.ok(!('tree_json' in item), 'the heavy half stays on the server until someone picks it');
  assert.ok(!pool.calls[0].text.includes('tree_json'));
});

test('a search term reaches every shelf', async () => {
  const pool = stubPool([[]]);
  await listLibrary(pool, 5, { search: '  mat  ' });

  assert.equal(pool.calls.length, 3);
  for (const call of pool.calls) {
    assert.ok(call.params.includes('%mat%'), `not filtered: ${call.text.slice(0, 40)}`);
  }
});

test('an empty search is not a filter that matches nothing', async () => {
  const pool = stubPool([[]]);
  await listLibrary(pool, 5, { search: '   ' });

  for (const call of pool.calls) {
    assert.equal(call.params.length, 1, 'only the user id');
  }
});

test('asking for one shelf queries only that shelf', async () => {
  const pool = stubPool([[]]);
  await listLibrary(pool, 5, { kind: 'analysis' });

  assert.equal(pool.calls.length, 1);
  assert.match(pool.calls[0].text, /saved_analyses/);
});

test('only the three known kinds are accepted', () => {
  assert.equal(isKind('scan'), true);
  assert.equal(isKind('position'), true);
  assert.equal(isKind('analysis'), true);
  // A typo must be refused by the route, not silently widened to everything.
  assert.equal(isKind('scans'), false);
  assert.equal(isKind(''), false);
  assert.equal(isKind(undefined), false);
});
