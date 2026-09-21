// analysis_replace_routes.test.js — an analysis saved under a name that is
// already taken can replace the one there.
//
// Item 4 of the owner's review of 21.9.2026, from TODO-provera 201.9: „Kada se
// čuva analiza i ako staviš isto ime kao već sačuvana, treba da se pita da li
// hoću da je pregazim." The server never overwrote anything — `POST
// /analysis` always inserts — so the same name made a second row that looked
// exactly like the first. The app now asks „Replace / Keep both"; „Replace"
// needs a way to write over one row, which is `PUT /analysis/:id`.
//
// Handlers are called directly with `db.pool.query` replaced, the idiom of
// `puzzle_sets_routes.test.js`, and every case reads **what the route asked
// the database** (rule 7). The scoping cases matter most: an analysis id is a
// small integer, and on its own it must never reach another account's row —
// the same shape `accountGuard` and `trainerOwnsStudent` exist for.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/analysis');
const { authenticateToken } = require('../middleware/auth');
const db = require('../db');

function handlersOf(method, path) {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method]
  );
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

async function call(method, path, { body = {}, params = {}, userId = 5, answer = () => ({ rows: [] }) } = {}) {
  const handlers = handlersOf(method, path);
  const handler = handlers[handlers.length - 1];
  const calls = [];
  const original = db.pool.query;
  db.pool.query = async (text, values = []) => {
    const flat = String(text).replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params: values });
    const out = answer(flat, values) || { rows: [] };
    return { rowCount: out.rows.length, ...out };
  };
  const sent = { status: 200, json: null };
  const res = {
    status(code) { sent.status = code; return res; },
    json(payload) { sent.json = payload; return res; },
  };
  try {
    await handler({ body, params, query: {}, user: { id: userId } }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls };
}

const TREE = { fen: 'startpos', children: [{ fen: 'after-e4', moveSan: 'e4', children: [] }] };
const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

test('PUT /analysis/:id is behind sign-in', () => {
  assert.equal(handlersOf('put', '/:id')[0], authenticateToken);
});

test('a replace writes the new tree over that row', async () => {
  const out = await call('put', '/:id', {
    params: { id: '31' },
    body: { title: 'Najdorf', startingFen: START, tree: TREE },
    answer: () => ({ rows: [{ id: 31, title: 'Najdorf', starting_fen: START }] }),
  });
  assert.equal(out.status, 200);
  assert.equal(out.calls.length, 1);
  const { text, params } = out.calls[0];
  assert.match(text, /^UPDATE saved_analyses SET/);
  assert.ok(params.includes('Najdorf'));
  assert.ok(params.includes(START));
  assert.ok(params.includes(JSON.stringify(TREE)), 'the tree is not what was written');
  assert.equal(out.json.id, 31);
});

test('a replace is scoped to the account, not to the id alone', async () => {
  // Mutating the WHERE to `id = $n` alone must turn this red.
  const out = await call('put', '/:id', {
    params: { id: '31' },
    userId: 5,
    body: { title: 'Najdorf', startingFen: START, tree: TREE },
    answer: () => ({ rows: [{ id: 31 }] }),
  });
  const { text, params } = out.calls[0];
  const where = text.slice(text.indexOf('WHERE'));
  assert.match(where, /id = \$\d+/);
  assert.match(where, /user_id = \$\d+/, 'an id alone reaches any account\'s analysis');
  const userSlot = Number(where.match(/user_id = \$(\d+)/)[1]);
  assert.equal(params[userSlot - 1], 5, 'the account in the WHERE is not the caller');
  const idSlot = Number(where.match(/(?:^|\s|\()id = \$(\d+)/)[1]);
  assert.equal(String(params[idSlot - 1]), '31');
});

test('another account\'s analysis is not found, and nothing is said about it', async () => {
  const out = await call('put', '/:id', {
    params: { id: '31' },
    userId: 6,
    body: { title: 'Najdorf', startingFen: START, tree: TREE },
    answer: () => ({ rows: [] }),
  });
  assert.equal(out.status, 404);
});

test('a replace without a tree, a title or a position is refused before the database', async () => {
  for (const body of [
    { startingFen: START, tree: TREE },
    { title: 'Najdorf', tree: TREE },
    { title: 'Najdorf', startingFen: START },
  ]) {
    const out = await call('put', '/:id', { params: { id: '31' }, body });
    assert.equal(out.status, 400, JSON.stringify(body));
    assert.equal(out.calls.length, 0, 'the database was asked anyway');
  }
});
