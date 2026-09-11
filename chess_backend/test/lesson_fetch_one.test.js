// lesson_fetch_one.test.js — GET /lessons/:id, one tutorial as the list shows it.
// Phase 2 of docs/PLAN-STUDIO-ISTORIJA.md.
//
// The studio fetches the saved version of a tutorial when it opens, to tell the
// trainer whether the draft on their device holds changes they have not saved.
// The route is small; what matters is that it answers **exactly the accounts
// the list answers**. Three hand-written copies of one access rule is how
// `status = 'accepted'` was lost in this repository, so the tests below ask
// that the single-row query carries the list's own condition, character for
// character, rather than re-deriving who may read what.
//
// Driven mounted with `pool.query` faked, for the reason
// `lesson_update_keeps_labels.test.js` gives.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');

function handler(method, path) {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method]
  );
  assert.ok(layer, `${method.toUpperCase()} /lessons${path} must be mounted`);
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

async function drive(method, path, req, answer) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    queries.push({ text, params });
    return answer(text, params);
  };
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  try {
    await handler(method, path)({ params: {}, query: {}, user: { id: 4 }, ...req }, res);
  } finally {
    db.pool.query = original;
  }
  return { res, queries };
}

const none = () => ({ rows: [], rowCount: 0 });
const ROW = { id: 31, title: 'Opozicija', position_list: [], language: 'de' };

/// The query text between two markers, whitespace collapsed.
function between(text, from, to) {
  const start = text.indexOf(from);
  assert.ok(start >= 0, `the query has no ${from}`);
  const end = to ? text.indexOf(to, start + from.length) : -1;
  return text.slice(start + from.length, end < 0 ? undefined : end).replace(/\s+/g, ' ').trim();
}

test('one tutorial is read with the list\'s own condition, and its id besides', async () => {
  const list = (await drive('get', '/', {}, none)).queries[0].text;
  const one = (await drive('get', '/:id', { params: { id: '31' } }, none)).queries[0].text;

  const listCondition = between(list, 'WHERE', 'ORDER BY');
  const oneCondition = between(one, 'WHERE', null);
  assert.match(listCondition, /status\s*=\s*'accepted'/,
    'the premise: the list reads through acceptedTrainersOf');
  assert.equal(oneCondition, `${listCondition} AND id = $2`,
    'the single-row route may narrow the list by id and in no other way');
});

test('one tutorial carries the columns the list carries', async () => {
  // The studio compares the fetched row with the one the list handed it; a
  // column in one and not the other is a difference nobody made.
  const list = (await drive('get', '/', {}, none)).queries[0].text;
  const one = (await drive('get', '/:id', { params: { id: '31' } }, none)).queries[0].text;
  assert.equal(between(one, 'SELECT', 'FROM saved_lessons'),
    between(list, 'SELECT', 'FROM saved_lessons'));
});

test('the reader and the tutorial are the two parameters, in that order', async () => {
  const { queries } = await drive('get', '/:id', { params: { id: '31' } }, none);
  assert.deepEqual(queries[0].params, [4, 31]);
});

test('the row comes back as the list would show it', async () => {
  const { res } = await drive('get', '/:id', { params: { id: '31' } },
    () => ({ rows: [ROW], rowCount: 1 }));
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, ROW);
});

test('a tutorial the reader may not see is not found, like one that does not exist', async () => {
  // Another trainer's tutorial, or one whose trainer's invitation was never
  // accepted: the condition leaves no row, and the answer must not tell those
  // apart from an id nobody has.
  const { res } = await drive('get', '/:id', { params: { id: '31' } }, none);
  assert.equal(res.statusCode, 404);
  assert.match(res.body.error, /not found/i);
});

test('an id that is not a tutorial id is not found, and the database is not asked', async () => {
  for (const id of ['abc', '0', '-3', '1.5', '31x', '99999999999', '2147483648']) {
    const { res, queries } = await drive('get', '/:id', { params: { id } }, none);
    assert.equal(res.statusCode, 404, `${id} must be not found`);
    assert.equal(queries.length, 0, `${id} must not reach the driver, which would answer 500`);
  }
  const largest = await drive('get', '/:id', { params: { id: '2147483647' } }, none);
  assert.equal(largest.queries.length, 1, 'the largest INTEGER is still an id');
});

test('a database that fails is a server error, not a missing tutorial', async () => {
  const { res } = await drive('get', '/:id', { params: { id: '31' } }, () => {
    throw new Error('connection reset');
  });
  assert.equal(res.statusCode, 500);
});

test('the single-row route comes after every one-segment GET it would swallow', () => {
  // `/labels` registered after `/:id` would be read as a tutorial called
  // „labels" and answer 404.
  const gets = lessonsRouter.stack
    .filter((l) => l.route && l.route.methods.get)
    .map((l) => l.route.path);
  const at = gets.indexOf('/:id');
  assert.ok(at >= 0);
  for (const path of gets) {
    if (/^\/[a-z-]+$/.test(path)) {
      assert.ok(gets.indexOf(path) < at, `${path} must be registered before /:id`);
    }
  }
});
