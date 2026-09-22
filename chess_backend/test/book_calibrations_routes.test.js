// book_calibrations_routes.test.js — a book's calibration belongs to the
// account (phase 3a of docs/PLAN-SKENER-SLIKE.md).
//
// A book whose diagrams are pictures is read against the positions of a few
// of its own boards. The owner decided on 22.9.2026 that the app remembers
// them on the account, not on the device — the puzzle sets taught that data
// kept per device must either say so or stop being per device. What is kept is
// positions and where they are in the book; never a picture from it. The book
// is known by the SHA-256 of its file.
//
// Handlers are called directly with a fake request and `db.pool.query`
// replaced, the idiom of `puzzle_sets_routes.test.js`; every case reads **what
// the route asked the database** (rule 7). The last case runs on a real
// database: a stub cannot prove a primary key.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/scans');
const { authenticateToken } = require('../middleware/auth');
const db = require('../db');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const HASH = 'a'.repeat(64);
const BOARDS = [
  { page: 44, index: 1, fen: 'r1bqr1k1/pp1nbppp/2n1p3/2ppP3/3P1N1P/2PB1N2/PP2QPP1/R1B1K2R' },
  { page: 51, index: 2, fen: '7k/8/8/3q4/8/8/8/1KQ5', ignore: ['e4'] },
];

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
    sendStatus(code) { sent.status = code; return res; },
  };
  try {
    await handler({ body, params, query: {}, user: { id: userId } }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls };
}

const PATH = '/calibrations/:hash';

for (const method of ['get', 'put', 'delete']) {
  test(`${method.toUpperCase()} /scans${PATH} is behind sign-in`, () => {
    assert.equal(handlersOf(method, PATH)[0], authenticateToken);
  });
}

test('a hash that is not 64 hex characters is refused before the database is asked', async () => {
  for (const method of ['get', 'put', 'delete']) {
    for (const hash of ['abc', 'A'.repeat(64), `${'a'.repeat(63)}g`, `${HASH}0`]) {
      const { status, json, calls } = await call(method, PATH, { params: { hash }, body: { boards: BOARDS } });
      assert.equal(status, 400, `${method} ${hash}`);
      assert.equal(json.code, 'bad_book_hash');
      assert.equal(calls.length, 0, `${method} ${hash} reached the database`);
    }
  }
});

test('a calibration board that is not a placement is refused, and nothing is written', async () => {
  const { status, json, calls } = await call('put', PATH, {
    params: { hash: HASH },
    body: { bookName: 'Book', boards: [{ page: 1, index: 1, fen: '8/8/8' }] },
  });
  assert.equal(status, 422);
  assert.equal(json.code, 'calibration_invalid');
  assert.equal(calls.length, 0);
});

test('an empty calibration is refused: there is nothing to remember', async () => {
  const { status, json, calls } = await call('put', PATH, { params: { hash: HASH }, body: { boards: [] } });
  assert.equal(status, 422);
  assert.equal(json.code, 'calibration_invalid');
  assert.equal(calls.length, 0);
});

test('a calibration is upserted under this account, the boards as the shared reader cleaned them', async () => {
  const { status, calls } = await call('put', PATH, {
    params: { hash: HASH },
    userId: 7,
    body: { bookName: 'Silman', boards: BOARDS },
  });
  assert.equal(status, 200);
  assert.equal(calls.length, 1);
  const [{ text, params }] = calls;
  assert.match(text, /^INSERT INTO book_calibrations/);
  assert.match(text, /ON CONFLICT \(user_id, book_hash\) DO UPDATE/);
  assert.deepEqual(params.slice(0, 3), [7, HASH, 'Silman']);
  assert.deepEqual(JSON.parse(params[3]), [
    { page: 44, index: 1, fen: BOARDS[0].fen, ignore: [] },
    { page: 51, index: 2, fen: BOARDS[1].fen, ignore: ['e4'] },
  ]);
});

test('a read asks for this account\'s row, and another account\'s hash is a 404', async () => {
  const { status, json, calls } = await call('get', PATH, { params: { hash: HASH }, userId: 9 });
  assert.equal(status, 404);
  assert.equal(json.code, 'no_calibration');
  assert.equal(calls.length, 1);
  assert.match(calls[0].text, /WHERE user_id = \$1 AND book_hash = \$2/);
  assert.deepEqual(calls[0].params, [9, HASH]);
});

test('a read answers the boards the account saved', async () => {
  const { status, json } = await call('get', PATH, {
    params: { hash: HASH },
    answer: () => ({ rows: [{ book_name: 'Silman', boards: BOARDS, updated_at: '2026-09-22T10:00:00Z' }] }),
  });
  assert.equal(status, 200);
  assert.equal(json.bookName, 'Silman');
  assert.deepEqual(json.boards, BOARDS);
});

test('a delete names the account as well as the book', async () => {
  const { status, calls } = await call('delete', PATH, {
    params: { hash: HASH },
    userId: 11,
    answer: () => ({ rows: [{ book_hash: HASH }] }),
  });
  assert.equal(status, 204);
  assert.match(calls[0].text, /^DELETE FROM book_calibrations WHERE user_id = \$1 AND book_hash = \$2/);
  assert.deepEqual(calls[0].params, [11, HASH]);
});

test('deleting a calibration that is not there is a 404, not a lie', async () => {
  const { status, json } = await call('delete', PATH, { params: { hash: HASH } });
  assert.equal(status, 404);
  assert.equal(json.code, 'no_calibration');
});

test.describe('on a real database', skipUnlessDatabase() ?? {}, () => {
  let fresh;
  let users;
  test.before(async () => {
    fresh = await freshDatabase();
    const a = await fresh.pool.query(`INSERT INTO users (email, password_hash, name) VALUES ('cal_a@test.invalid', 'x', 'A') RETURNING id`);
    const b = await fresh.pool.query(`INSERT INTO users (email, password_hash, name) VALUES ('cal_b@test.invalid', 'x', 'B') RETURNING id`);
    users = [a.rows[0].id, b.rows[0].id];
  });
  test.after(async () => { await fresh.drop(); });

  async function onReal(method, params, body, userId) {
    const original = db.pool.query;
    db.pool.query = (text, values) => fresh.pool.query(text, values);
    try {
      const handlers = handlersOf(method, PATH);
      const sent = { status: 200, json: null };
      const res = {
        status(code) { sent.status = code; return res; },
        json(payload) { sent.json = payload; return res; },
        sendStatus(code) { sent.status = code; return res; },
      };
      await handlers[handlers.length - 1]({ body, params, query: {}, user: { id: userId } }, res);
      return sent;
    } finally {
      db.pool.query = original;
    }
  }

  test('two accounts with the same book keep separate calibrations, and a second save replaces the first', async () => {
    const [a, b] = users;
    assert.equal((await onReal('put', { hash: HASH }, { bookName: 'A', boards: [BOARDS[0]] }, a)).status, 200);
    assert.equal((await onReal('put', { hash: HASH }, { bookName: 'B', boards: [BOARDS[1]] }, b)).status, 200);
    assert.equal((await onReal('put', { hash: HASH }, { bookName: 'A2', boards: BOARDS }, a)).status, 200);
    const readA = await onReal('get', { hash: HASH }, {}, a);
    const readB = await onReal('get', { hash: HASH }, {}, b);
    assert.equal(readA.json.bookName, 'A2');
    assert.equal(readA.json.boards.length, 2);
    assert.equal(readB.json.bookName, 'B');
    assert.equal(readB.json.boards[0].fen, BOARDS[1].fen);
    const rows = await fresh.pool.query('SELECT COUNT(*)::int AS n FROM book_calibrations');
    assert.equal(rows.rows[0].n, 2);
  });
});
