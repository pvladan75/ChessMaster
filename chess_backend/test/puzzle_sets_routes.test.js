// puzzle_sets_routes.test.js — a puzzle set belongs to the account, not to
// the machine that made it.
//
// Reported by the owner, 21.9.2026: „Library - Puzzle sets na telefonu ne
// prikazuje puzzle uopšte, iako na istom nalogu u windows-u prikazuje."
//
// It was not a display fault. „Review entire game" runs the engine in the
// Analysis Studio and writes the result to `SharedPreferences` on **that
// device** (`LocalPuzzleSetStorageService`); the server never saw one, and
// `libraryKindWire` throws for that kind because it has no wire name at all.
// Windows showed his sets because Windows made them.
//
// These routes are the account-wide half. JSONB rather than a child table,
// following `blunder_games.blunders` and for its stated reason — nothing ever
// queries inside a set, and a set is at most five puzzles.
//
// Handlers are called directly with a fake request and `db.pool.query`
// replaced — the idiom of `puzzle_progress_routes.test.js` and
// `endgame_catalog_online.test.js`. Every case reads **what the route asked
// the database**, not what a stub answered (rule 7). The scoping cases matter
// most: this is a server several accounts share, and a set id alone must
// never reach another account's row.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/puzzleSets');
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
    sendStatus(code) { sent.status = code; return res; },
  };
  try {
    await handler({ body, params, query: {}, user: { id: userId } }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls };
}

const PUZZLES = [
  {
    id: 'p1',
    fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
    themeLabel: 'fork',
    themeKey: 'fork',
    swing: 2.5,
    sourceMoveSan: 'Nf3',
    sourcePlyIndex: 4,
  },
];

// ── behind sign-in ────────────────────────────────────────────────────────

for (const [method, path] of [
  ['get', '/'],
  ['put', '/:setId'],
  ['delete', '/:setId'],
]) {
  test(`${method.toUpperCase()} /puzzle-sets${path} is behind sign-in`, () => {
    assert.equal(handlersOf(method, path)[0], authenticateToken);
  });
}

// ── reading ───────────────────────────────────────────────────────────────

test('the list is this account\'s sets, newest first', async () => {
  const out = await call('get', '/', {
    userId: 5,
    answer: () => ({
      rows: [{ set_id: 'a', title: 'Game vs Ana', puzzles: PUZZLES, created_at: new Date(0) }],
    }),
  });

  const q = out.calls[0];
  assert.match(q.text, /FROM puzzle_sets/);
  assert.match(q.text, /user_id = \$1/,
    'a list that is not scoped to the account is every account\'s sets');
  assert.deepEqual(q.params, [5]);
  assert.match(q.text, /ORDER BY created_at DESC/);
  assert.equal(out.status, 200);
  assert.equal(out.json.items.length, 1);
  assert.equal(out.json.items[0].id, 'a');
});

// ── writing ───────────────────────────────────────────────────────────────

test('a set is upserted, so uploading the same one twice is safe', async () => {
  // The app uploads what the device already holds the first time it can
  // reach the server. That runs again on every device, so the write has to
  // be idempotent or the owner's sets multiply.
  const out = await call('put', '/:setId', {
    params: { setId: 'set-1' },
    body: { title: 'Game vs Ana', createdAt: '2026-09-20T10:00:00.000Z', puzzles: PUZZLES },
    userId: 5,
  });

  const q = out.calls[0];
  assert.match(q.text, /INSERT INTO puzzle_sets/);
  assert.match(q.text, /ON CONFLICT \(user_id, set_id\) DO UPDATE/,
    'a second upload of the same set must not make a second row');
  assert.equal(q.params[0], 5);
  assert.equal(q.params[1], 'set-1');
  assert.equal(out.status, 200);
});

test('a set with no puzzles is refused', async () => {
  const out = await call('put', '/:setId', {
    params: { setId: 'set-1' },
    body: { title: 'Empty', puzzles: [] },
  });

  assert.equal(out.status, 400);
  assert.equal(out.calls.length, 0, 'it was written before it was checked');
});

test('a set without a title is refused', async () => {
  const out = await call('put', '/:setId', {
    params: { setId: 'set-1' },
    body: { puzzles: PUZZLES },
  });

  assert.equal(out.status, 400);
  assert.equal(out.calls.length, 0);
});

// ── deleting ──────────────────────────────────────────────────────────────

test('a delete names the account as well as the set', async () => {
  // The id is minted on a device and is not a secret. Without the account in
  // the WHERE clause, knowing an id would be enough to delete somebody
  // else's set — the shape `accountGuard` and `trainerOwnsStudent` exist for.
  const out = await call('delete', '/:setId', {
    params: { setId: 'set-1' },
    userId: 5,
    answer: () => ({ rows: [{ set_id: 'set-1' }] }),
  });

  const q = out.calls[0];
  assert.match(q.text, /DELETE FROM puzzle_sets/);
  assert.match(q.text, /user_id = \$1/);
  assert.deepEqual(q.params, [5, 'set-1']);
});

test('deleting a set that is not this account\'s is a 404, not a lie', async () => {
  const out = await call('delete', '/:setId', {
    params: { setId: 'somebody-elses' },
    answer: () => ({ rows: [] }),
  });

  assert.equal(out.status, 404);
});
