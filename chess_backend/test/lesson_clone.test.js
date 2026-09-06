// lesson_clone.test.js
// „Sačuvaj kao novu verziju" — phase 3a of `docs/PLAN-TUTORIJAL.md`.
//
// A trainer keeps one tutorial and makes an easier or harder version of it for
// another group. Two things must hold, and the second is the one that would be
// found a year late:
//
//   * the original is not touched — the route only ever reads it;
//   * **every copied step gets a fresh id.** `stepByKey` resolves a schedule row
//     and a recorded answer by that id, so two tutorials carrying one id is an
//     ambiguity that surfaces as a child's progress appearing in the wrong copy.
//
// Drives the **mounted route**, not a helper. The helper being right and the
// route asking it are two different things, and on the last occasion here it
// was the second one missing.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in the whole server chain, and `middleware/auth`
// calls process.exit at import without this. A developer's machine has a `.env`
// and CI does not — run `npm test` with `.env` moved aside to check.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

const STORED = {
  title: 'Opozicija',
  description: 'Za mlađu grupu',
  tags: ['zavrsnica'],
  fen: FEN,
  pgn: '1. Ra8#',
  position_list: [
    { id: 'a3f9c1d2', fen: FEN, title: 'Prvi', kind: 'show' },
    { id: 'b7e2d4a1', fen: FEN, title: 'Drugi', kind: 'show' },
  ],
};

function cloneHandler() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/clone' && l.route.methods.post
  );
  assert.ok(layer, 'POST /lessons/:id/clone must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// Runs the route against a captured pool and hands back every query it made.
async function run({ params = { id: '7' }, body = {}, stored = STORED, userId = 3 } = {}) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (text, values) => {
    queries.push({ text, values });
    if (/^\s*SELECT title/.test(text)) {
      return { rows: stored ? [stored] : [], rowCount: stored ? 1 : 0 };
    }
    if (/INSERT INTO saved_lessons/.test(text)) {
      return { rows: [{ id: 99, title: values[1] }], rowCount: 1 };
    }
    throw new Error(`unexpected query: ${text}`);
  };

  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };

  try {
    await cloneHandler()({ params, body, user: { id: userId } }, res);
  } finally {
    db.pool.query = original;
  }
  return { res, queries };
}

const insertOf = (queries) => queries.find((q) => /INSERT INTO saved_lessons/.test(q.text));

test('the copy is created, and the original is only read', async () => {
  const { res, queries } = await run();

  assert.equal(res.statusCode, 201);

  const writes = queries.filter((q) => /UPDATE|DELETE/i.test(q.text));
  assert.deepEqual(writes, [], 'cloning must never write to the source row');

  const select = queries[0];
  assert.match(select.text, /FROM saved_lessons/);
  assert.deepEqual(select.values, [7, 3], 'read by id, scoped to the caller');
});

test('every copied step gets a new id, and keeps everything else', async () => {
  const { queries } = await run();

  const steps = JSON.parse(insertOf(queries).values[6]);
  assert.equal(steps.length, 2);

  const oldIds = STORED.position_list.map((s) => s.id);
  for (const step of steps) {
    assert.equal(typeof step.id, 'string');
    assert.ok(step.id.length > 0);
    assert.ok(!oldIds.includes(step.id), `step id ${step.id} was copied, not minted`);
  }
  assert.notEqual(steps[0].id, steps[1].id, 'two steps must not share an id');

  assert.equal(steps[0].title, 'Prvi');
  assert.equal(steps[1].title, 'Drugi');
  assert.equal(steps[0].fen, FEN);
});

test('the stored steps are left exactly as they were', async () => {
  // The route strips ids to mint new ones; doing that in place would rewrite
  // the object the pool handed back, and with a real driver that is the row.
  await run();
  assert.deepEqual(
    STORED.position_list.map((s) => s.id),
    ['a3f9c1d2', 'b7e2d4a1'],
  );
});

test('the copy is named, and the caller may name it', async () => {
  const untitled = await run();
  assert.equal(insertOf(untitled.queries).values[1], 'Opozicija (kopija)');

  const named = await run({ body: { title: 'Opozicija — teža' } });
  assert.equal(insertOf(named.queries).values[1], 'Opozicija — teža');

  const blank = await run({ body: { title: '   ' } });
  assert.equal(insertOf(blank.queries).values[1], 'Opozicija (kopija)',
    'a blank title is not a title');
});

test('a long title does not overflow the column', async () => {
  // `title` is VARCHAR(255). Without shortening, appending the suffix is a
  // 22001 from the driver and a 500 to the trainer — which reads as "cloning is
  // broken" rather than "your title is long".
  const long = 'x'.repeat(255);
  const { queries } = await run({ stored: { ...STORED, title: long } });

  const title = insertOf(queries).values[1];
  assert.ok(title.length <= 255, `title was ${title.length} characters`);
  assert.ok(title.endsWith(' (kopija)'));
});

test('the copy belongs to whoever asked for it', async () => {
  const { queries } = await run({ userId: 11 });
  const values = insertOf(queries).values;
  assert.equal(values[0], 11, 'user_id and trainer_id are both the caller');
});

test('description, tags, fen and pgn come across', async () => {
  const { queries } = await run();
  const values = insertOf(queries).values;
  assert.equal(values[2], 'Za mlađu grupu');
  assert.deepEqual(values[3], ['zavrsnica']);
  assert.equal(values[4], FEN);
  assert.equal(values[5], '1. Ra8#');
});

test('a tutorial with no steps clones as a single position', async () => {
  const { res, queries } = await run({ stored: { ...STORED, position_list: null } });
  assert.equal(res.statusCode, 201);
  assert.equal(insertOf(queries).values[6], null);
});

test('a tutorial that is not yours is not found', async () => {
  const { res, queries } = await run({ stored: null });
  assert.equal(res.statusCode, 404);
  assert.equal(insertOf(queries), undefined, 'nothing is written on a refusal');
});

test('an unparseable id is refused before any query', async () => {
  const { res, queries } = await run({ params: { id: 'sedam' } });
  assert.equal(res.statusCode, 400);
  assert.deepEqual(queries, []);
});

test('a stored step the current rules refuse is not duplicated', async () => {
  // A list written before a validation rule existed. Copying it would carry the
  // fault into a second tutorial; refusing says which step and why.
  const { res, queries } = await run({
    stored: {
      ...STORED,
      position_list: [{ id: 'a3f9c1d2', fen: 'nonsense', title: 'Prvi' }],
    },
  });

  assert.ok(res.statusCode >= 400, `expected a refusal, got ${res.statusCode}`);
  assert.match(res.body.error, /Korak 1/);
  assert.equal(insertOf(queries), undefined);
});
