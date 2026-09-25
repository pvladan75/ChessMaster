// lesson_routes_refuse_questions.test.js
// Phase 4 of `docs/PLAN-TUTORIJAL-VIDEO.md`: every part of a tutorial shows,
// and a part that asks is refused — on each of the four doors by which parts
// are written, not only in the builder. `lesson_step_kinds.test.js` holds the
// builder's rule; this holds that every route asks it, and that a refusal
// writes nothing.
//
// Drives the mounted routes, without their authentication, against a captured
// pool (the shape of `lesson_rename_keeps_steps.test.js`).

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in `middleware/auth`, which exits at import without
// JWT_SECRET; CI has no `.env`. Deliberately worthless: nothing signs here.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const REFUSAL = /A part only shows a position and a line; a question is an exercise/;

const SHOW = { fen: FEN, title: 'Shown' };
const ASK_MOVE = { fen: FEN, title: 'Asked', kind: 'ask_move', instruction: 'Mate.', solutionSan: 'Ra8#' };
const ASK_CHOICE = {
  fen: FEN,
  title: 'Chosen',
  kind: 'ask_choice',
  choices: [{ text: 'Ra8#', correct: true }, { text: 'Ra7', correct: false }],
};

function handler(method, path) {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method]
  );
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// Runs one route against a captured pool. [stored] is what a SELECT of the
/// tutorial answers (the clone reads the list it copies).
async function run(method, path, { params = {}, body = {}, stored = [SHOW] } = {}) {
  const queries = [];
  const original = db.pool.query;
  const originalConnect = db.pool.connect;
  const answer = async (text, params) => {
    queries.push({ text, params });
    if (/SELECT/.test(text) && /position_list/.test(text)) {
      return {
        rows: [{ title: 'T', fen: FEN, position_list: stored, language: null }],
        rowCount: 1,
      };
    }
    return { rows: [{ id: 7, title: 'T', step_count: 2 }], rowCount: 1 };
  };
  db.pool.query = answer;
  db.pool.connect = async () => ({ query: answer, release() {} });

  const answered = { status: 200, body: null };
  const res = {
    status(code) {
      answered.status = code;
      return this;
    },
    json(payload) {
      answered.body = payload;
      return this;
    },
  };
  try {
    await handler(method, path)({ params, user: { id: 1 }, body }, res);
  } finally {
    db.pool.query = original;
    db.pool.connect = originalConnect;
  }
  const writes = queries.filter((q) => /INSERT|UPDATE|DELETE/.test(q.text));
  return { answered, writes };
}

for (const [name, part] of [['ask_move', ASK_MOVE], ['ask_choice', ASK_CHOICE]]) {
  test(`POST /save refuses a tutorial whose second part is ${name}, and writes nothing`, async () => {
    const { answered, writes } = await run('post', '/save', {
      body: { title: 'T', positionList: [SHOW, part] },
    });
    assert.equal(answered.status, 400);
    assert.match(answered.body.error, REFUSAL);
    assert.match(answered.body.error, /^Step 2:/, 'the part is named');
    assert.equal(writes.length, 0);
  });

  test(`PUT /:id refuses a list with ${name}, and writes nothing`, async () => {
    const { answered, writes } = await run('put', '/:id', {
      params: { id: '7' },
      body: { title: 'T', positionList: [SHOW, part] },
    });
    assert.equal(answered.status, 400);
    assert.match(answered.body.error, REFUSAL);
    assert.equal(writes.length, 0);
  });

  test(`POST /:id/steps refuses ${name}, and writes nothing`, async () => {
    const { answered, writes } = await run('post', '/:id/steps', {
      params: { id: '7' },
      body: { step: part },
    });
    assert.equal(answered.status, 400);
    assert.match(answered.body.error, REFUSAL);
    assert.equal(writes.length, 0);
  });

  test(`POST /:id/clone refuses to copy a stored ${name}, and writes nothing`, async () => {
    const { answered, writes } = await run('post', '/:id/clone', {
      params: { id: '7' },
      stored: [SHOW, part],
    });
    assert.equal(answered.status, 400);
    assert.match(answered.body.error, REFUSAL);
    assert.equal(writes.length, 0);
  });
}

test('the same four doors take a tutorial that only shows', async () => {
  // The other side of each refusal above: without it, a route that refused
  // everything would pass them all.
  const save = await run('post', '/save', { body: { title: 'T', positionList: [SHOW, SHOW] } });
  assert.notEqual(save.answered.status, 400, JSON.stringify(save.answered.body));
  assert.ok(save.writes.length > 0);

  const put = await run('put', '/:id', {
    params: { id: '7' },
    body: { title: 'T', positionList: [SHOW, SHOW] },
  });
  assert.notEqual(put.answered.status, 400, JSON.stringify(put.answered.body));
  assert.ok(put.writes.length > 0);

  const steps = await run('post', '/:id/steps', { params: { id: '7' }, body: { step: SHOW } });
  assert.equal(steps.answered.status, 201, JSON.stringify(steps.answered.body));

  const clone = await run('post', '/:id/clone', { params: { id: '7' }, stored: [SHOW, SHOW] });
  assert.notEqual(clone.answered.status, 400, JSON.stringify(clone.answered.body));
  assert.ok(clone.writes.length > 0);
});
