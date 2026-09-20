// endgame_catalog_online.test.js
//
// The picker's total is counted over the same pool the drill serves from.
//
// Reported live by the owner, 20.9.2026, against TODO-provera 206 point 5:
// „očekivao sam da uključivanje/isključivanje online partija menja brojeve,
// ali ne menja brojeve". It does not, and the reason is worse than an inert
// switch:
//
//   GET /puzzles/endgame/next      excludes the online base unless asked
//   GET /puzzles/endgame/nextGame  the same
//   GET /puzzles/endgame/catalog   counted everything
//
// So „Selected: N positions" over-counted by however many online positions the
// selection held, and the drill — whose default is to leave them out — then
// served from a smaller pool. A selection whose only matches are online read
// as a healthy number with „Start" enabled and had nothing behind it. The
// picker screen's own comment says the counts arrive split by band precisely
// so that a combination is added up in the app „rather than sent to the server
// to be answered with 'nothing matches' after the fact"; for this one filter
// that promise was not kept.
//
// `services/endgameSources.js` says in its own header that one place knows the
// base's name „because two would drift", and that **both routes** filter on
// it. The catalogue is the third route over the same table and it did not.
//
// Handlers are called directly with a fake request and the pool's `query`
// replaced — the idiom of `puzzle_progress_routes.test.js`. Every case reads
// what the route asked the database, not what a stub answered (rule 7).

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/puzzles');
const db = require('../db');
const { excludeOnlineClause } = require('../services/endgameSources');

function handlersOf(method, path) {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method]
  );
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

/// Runs a route's last handler with a fake request and collects the SQL it
/// asked for. `answer` shapes what comes back, so a route that reads its own
/// rows still gets something to read.
async function call(method, path, { query = {}, answer = () => ({ rows: [] }) } = {}) {
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
    await handler({ body: {}, query, params: {}, user: { id: 5 } }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls };
}

/// The one statement that reads `endgame_puzzles`.
function statementOf(calls) {
  const hit = calls.find((c) => /FROM endgame_puzzles/.test(c.text));
  assert.ok(hit, 'the route never read endgame_puzzles');
  return hit.text;
}

// ── the catalogue answers the same question the drill does ────────────────

test('by default the catalogue leaves the online base out', async () => {
  const out = await call('get', '/puzzles/endgame/catalog');
  assert.match(
    statementOf(out.calls),
    new RegExp(excludeOnlineClause().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
    'the catalogue counts positions the drill will not serve'
  );
});

test('asked for, the online base is counted too', async () => {
  const out = await call('get', '/puzzles/endgame/catalog', {
    query: { includeOnline: 'true' },
  });
  assert.ok(
    !statementOf(out.calls).includes(excludeOnlineClause()),
    'the switch was turned on and the count did not follow'
  );
});

test('anything other than the word true leaves them out', async () => {
  // The drill routes compare against the string `'true'` exactly, and the
  // catalogue has to read the flag the same way or the two disagree on
  // `includeOnline=1` — which is the whole fault, in miniature.
  for (const value of ['1', 'yes', 'True', '', undefined]) {
    const out = await call('get', '/puzzles/endgame/catalog', {
      query: value === undefined ? {} : { includeOnline: value },
    });
    assert.ok(
      statementOf(out.calls).includes(excludeOnlineClause()),
      `includeOnline=${JSON.stringify(value)} must not let the online base in`
    );
  }
});

test('the clause is the shared one, not a second copy of the file name',
  async () => {
    // Rule 12, and the module's own header: one place knows the name, because
    // two would drift. A hand-written `source_db <> '...'` would also read as
    // a filter and would silently drop every mined position, which carries no
    // source at all — that is why the shared clause uses IS DISTINCT FROM.
    const out = await call('get', '/puzzles/endgame/catalog');
    assert.ok(statementOf(out.calls).includes(excludeOnlineClause()));
  });

test('the drill still leaves them out by default', async () => {
  // Guarding the other half of the pair: the two routes are only right
  // together, and a later change that "unifies" them must not unify them onto
  // the wrong answer.
  const out = await call('get', '/puzzles/endgame/next', {
    answer: () => ({ rows: [] }),
  });
  assert.ok(
    out.calls.some((c) => c.text.includes(excludeOnlineClause())),
    'the drill stopped excluding the online base'
  );
});

test('mode still narrows the catalogue', async () => {
  // Guarding: the flag is added beside the filter that was already there, not
  // instead of it.
  const out = await call('get', '/puzzles/endgame/catalog', {
    query: { mode: 'draw' },
  });
  const hit = out.calls.find((c) => /FROM endgame_puzzles/.test(c.text));
  assert.match(hit.text, /mode = \$\d/);
  assert.deepEqual(hit.params, ['draw']);
});
