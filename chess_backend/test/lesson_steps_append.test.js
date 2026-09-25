// lesson_steps_append.test.js — `POST /lessons/:id/steps` takes several parts
// at once (phase 2 of docs/PLAN-MAPA-DELOVA.md).
//
// A line from Analysis with side lines in it becomes one part per line in the
// app, which alone can read PGN (rule 13), and arrives here as `steps`. The
// rule the route holds is **whole or not at all**: a list written by several
// requests, or by one statement after a half-checked list, is left
// half-written by the first step that fails. One step still works as before.
//
// The stub cases read what the route asked the database (rule 7); the last
// group runs on a real database, because only a real one can show that a
// refused list left the stored one as it was.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in `middleware/auth`, which exits at import without
// JWT_SECRET; CI has no `.env`. Deliberately worthless: nothing signs here.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const step = (title, extra = {}) => ({ fen: FEN, title, pgn: '1. Ra8# *', ...extra });
const BAD = { fen: 'not a position', title: 'Broken' };

function handler() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/steps' && l.route.methods.post
  );
  assert.ok(layer, 'POST /:id/steps must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

async function post(body, { query } = {}) {
  const calls = [];
  const original = db.pool.query;
  db.pool.query =
    query ||
    (async (text, params) => {
      calls.push({ text: String(text), params });
      return { rows: [{ id: 7, title: 'T', step_count: 3 }], rowCount: 1 };
    });
  const sent = { status: 200, json: null };
  const res = {
    status(code) { sent.status = code; return res; },
    json(payload) { sent.json = payload; return res; },
  };
  try {
    await handler()({ params: { id: '7' }, user: { id: 1 }, body }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls };
}

/// The entries the route asked to append, in order.
function appended(calls) {
  const update = calls.find((c) => /UPDATE saved_lessons/.test(c.text));
  assert.ok(update, 'nothing was appended');
  return JSON.parse(update.params[0]);
}

test('one step is appended as before', async () => {
  const { status, calls } = await post({ step: step('Alone') });
  assert.equal(status, 201);
  assert.deepEqual(appended(calls).map((e) => e.title), ['Alone']);
});

test('several steps are appended in one statement, in their order', async () => {
  const { status, calls } = await post({ steps: [step('One'), step('Two'), step('Three')] });
  assert.equal(status, 201);
  assert.equal(calls.filter((c) => /UPDATE/.test(c.text)).length, 1);
  assert.deepEqual(appended(calls).map((e) => e.title), ['One', 'Two', 'Three']);
  const ids = appended(calls).map((e) => e.id);
  assert.equal(new Set(ids).size, 3, 'each step has an id of its own');
});

test('a bad step anywhere refuses the list, naming it, and writes nothing', async () => {
  const { status, json, calls } = await post({ steps: [step('One'), BAD, step('Three')] });
  assert.equal(status, 422, "the builder's own refusal of a position");
  assert.match(json.error, /^Step 2:/);
  assert.equal(calls.length, 0, 'the database was asked before the list was checked');
});

test('a body that is neither one step nor a list of them is refused before the database', async () => {
  for (const body of [
    {},
    { step: step('A'), steps: [step('B')] },
    { steps: [] },
    { steps: step('Not a list') },
  ]) {
    const { status, calls } = await post(body);
    assert.equal(status, 400, JSON.stringify(body));
    assert.equal(calls.length, 0, JSON.stringify(body));
  }
});

test.describe('on a real database', skipUnlessDatabase() ?? {}, () => {
  let fresh;
  let owner;
  test.before(async () => {
    fresh = await freshDatabase();
    const u = await fresh.pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ('steps@test.invalid', 'x', 'S') RETURNING id`
    );
    owner = u.rows[0].id;
  });
  test.after(async () => { await fresh.drop(); });

  async function lessonWith(titles) {
    const r = await fresh.pool.query(
      `INSERT INTO saved_lessons (user_id, title, fen, position_list)
       VALUES ($1, 'Tutorial', $2, $3::jsonb) RETURNING id`,
      [owner, FEN, JSON.stringify(titles.map((t, i) => ({ id: `s${i}`, fen: FEN, title: t, kind: 'show' })))]
    );
    return r.rows[0].id;
  }

  async function onReal(id, body) {
    const original = db.pool.query;
    db.pool.query = (text, values) => fresh.pool.query(text, values);
    const sent = { status: 200, json: null };
    const res = {
      status(code) { sent.status = code; return res; },
      json(payload) { sent.json = payload; return res; },
    };
    try {
      await handler()({ params: { id: String(id) }, user: { id: owner }, body }, res);
    } finally {
      db.pool.query = original;
    }
    return sent;
  }

  async function titlesOf(id) {
    const r = await fresh.pool.query('SELECT position_list FROM saved_lessons WHERE id = $1', [id]);
    return r.rows[0].position_list.map((s) => s.title);
  }

  test('a list with a bad step in the middle leaves the tutorial as it was', async () => {
    const id = await lessonWith(['First']);
    const sent = await onReal(id, { steps: [step('One'), BAD, step('Three')] });
    assert.equal(sent.status, 422);
    assert.deepEqual(await titlesOf(id), ['First']);
  });

  test('a good list is appended whole, after what was there', async () => {
    const id = await lessonWith(['First']);
    const sent = await onReal(id, { steps: [step('One'), step('Two'), step('Three')] });
    assert.equal(sent.status, 201);
    assert.deepEqual(await titlesOf(id), ['First', 'One', 'Two', 'Three']);
  });
});
