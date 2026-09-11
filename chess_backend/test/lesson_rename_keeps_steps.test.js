// lesson_rename_keeps_steps.test.js
// A PUT that says nothing about the steps must not delete them.
//
// Found on 5.9.2026 while scoping phase 7 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`.
// `_editSinglePosition` in the app renames a saved position and sends no
// `positionList`; the route ran that through `buildOrReject`, which answers `[]`
// for both a missing list and an empty one, and then wrote `position_list =
// NULL`. A rename would have destroyed every step of a lesson — silently, since
// nothing joins on those steps and nothing logs the write.
//
// Nothing lost data, and only because the *caller* was careful: the saved-lesson
// list offers the rename for a single position and the course dialog for a
// course, so the nulling path was never handed a lesson with steps. A guarantee
// that lives in a widget's `isCourse ? ... : ...` is one refactor away from
// being gone, and phase 7 is that refactor.
//
// This drives the **mounted route**, not the helper. The helper being right and
// the route asking it are two different things, and `scan_upload_limits.test.js`
// is here because it was the second one that was missing.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in the whole server chain, including `middleware/auth`,
// which calls `process.exit` at import when JWT_SECRET is missing. A developer's
// machine has a `.env` and CI does not, so without this the file is green here
// and takes the whole suite down there. Deliberately worthless: nothing below
// authenticates.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

/// The stored lesson every case below starts from: two steps, both with ids.
const STORED = [
  { id: 'a3f9c1d2', fen: FEN, title: 'Prvi' },
  { id: 'b7e2d4a1', fen: FEN, title: 'Drugi' },
];

/// The handler behind `PUT /lessons/:id`, without its authentication.
function putHandler() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id' && l.route.methods.put
  );
  assert.ok(layer, 'PUT /lessons/:id must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// Runs the route against a captured pool and returns every query it ran.
async function run(body) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    queries.push({ text, params });
    if (/SELECT position_list/.test(text)) {
      return { rows: [{ position_list: STORED }], rowCount: 1 };
    }
    return { rows: [{ id: 7 }], rowCount: 1 };
  };

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
    await putHandler()({ params: { id: '7' }, user: { id: 1 }, body }, res);
  } finally {
    db.pool.query = original;
  }

  return { queries, answered };
}

const updateOf = (queries) => queries.find((q) => /UPDATE saved_lessons/.test(q.text));

/// The value written to one column of the UPDATE, found **by name**.
///
/// The statement is built from a list of clauses now — only the columns the
/// request mentioned are in it — so a column's position is not fixed and an
/// assertion on `params[5]` is an assertion about the shape of the SET clause
/// rather than about what was stored. Same family as `retention.test.js`'s
/// "exactly one query".
function writtenTo(update, column) {
  // No regex: a `` written into a JS template literal is a backspace byte,
  // not a word boundary, and this repository has already shipped one of those.
  const marker = `${column} = $`;
  const at = update.text.indexOf(marker);
  assert.ok(at >= 0, `${column} must be written by this statement`);
  const digits = update.text.slice(at + marker.length).match(/^[0-9]+/);
  assert.ok(digits, `${column} must be written from a parameter`);
  return update.params[Number(digits[0]) - 1];
}

test('a rename that never mentions the steps leaves the column alone', async () => {
  // What the app sends when a trainer renames a saved position.
  const { queries, answered } = await run({
    title: 'Novo ime',
    description: 'opis',
    tags: ['taktika'],
    fen: FEN,
    pgn: null,
  });

  assert.equal(answered.status, 200);

  const update = updateOf(queries);
  assert.ok(update, 'the route must still write the title');
  assert.doesNotMatch(
    update.text,
    /position_list/,
    'a request that said nothing about the steps must not write the step column'
  );
  assert.ok(
    !update.params.some((p) => typeof p === 'string' && p.includes('a3f9c1d2')),
    'and must not be carrying a rebuilt list either'
  );
});

test('an empty list sent on purpose still clears them', async () => {
  // The other half, and the reason this is not just `COALESCE`: "there are no
  // steps now" is a thing a trainer is allowed to say. It has to stay sayable.
  const { queries, answered } = await run({
    title: 'Bez koraka',
    fen: FEN,
    positionList: [],
  });

  assert.equal(answered.status, 200);
  const update = updateOf(queries);
  assert.equal(writtenTo(update, 'position_list'), null,
    'an empty list is stored as NULL, as before');
});

test('a real list is written, and every id it arrived with survives', async () => {
  const { queries, answered } = await run({
    title: 'Slaba polja',
    fen: FEN,
    positionList: [
      { id: 'a3f9c1d2', fen: FEN, title: 'Prvi' },
      { id: 'b7e2d4a1', fen: FEN, title: 'Drugi' },
    ],
  });

  assert.equal(answered.status, 200);
  const written = JSON.parse(writtenTo(updateOf(queries), 'position_list'));
  assert.deepEqual(written.map((s) => s.id), ['a3f9c1d2', 'b7e2d4a1']);
});

test('the identity guard still fires, and only when the steps were sent', async () => {
  // Phase 1's 409: a client that sends back the same number of steps with every
  // id stripped has lost them, and writing that orphans every schedule row.
  const stripped = await run({
    title: 'Slaba polja',
    fen: FEN,
    positionList: [
      { fen: FEN, title: 'Prvi' },
      { fen: FEN, title: 'Drugi' },
    ],
  });

  assert.equal(stripped.answered.status, 409);

  // And a rename, which sends no list at all, must not be mistaken for one:
  // it strips nothing because it says nothing.
  const rename = await run({ title: 'Novo ime', fen: FEN });
  assert.equal(rename.answered.status, 200);
});
