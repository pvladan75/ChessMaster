// lesson_update_keeps_labels.test.js
// A PUT that says nothing about the description or the labels must not clear
// them.
//
// Found on 11.9.2026 while wiring labels onto tutorials. `PUT /lessons/:id`
// wrote `description = $2, tags = $3` on every request, out of `body.x ||
// null` — and `commitDraft`, the one place the tutorial studio saves from,
// sends a title and a position list and nothing else. So opening a saved
// tutorial and pressing "Save tutorial" erased its description, and would have
// erased its labels the moment tutorials had any. Nobody noticed because
// nothing in the app had ever written a tutorial's description except the JSON
// import that arrived the same day.
//
// This drives the **mounted route**, for the same reason
// `lesson_rename_keeps_steps.test.js` does: the helper being right and the
// route asking it are two different things.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

function putHandler() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id' && l.route.methods.put
  );
  assert.ok(layer, 'PUT /lessons/:id must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

async function run(body) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    queries.push({ text, params });
    if (/SELECT position_list/.test(text)) {
      return { rows: [{ position_list: [] }], rowCount: 1 };
    }
    return { rows: [{ id: 7 }], rowCount: 1 };
  };

  const answered = { status: 200, body: null };
  const res = {
    status(code) { answered.status = code; return this; },
    json(payload) { answered.body = payload; return this; },
  };

  try {
    await putHandler()({ params: { id: '7' }, user: { id: 1 }, body }, res);
  } finally {
    db.pool.query = original;
  }

  return { queries, answered };
}

const updateOf = (queries) => queries.find((q) => /UPDATE saved_lessons/.test(q.text));

/// The value written to one column, found by name rather than by position.
function writtenTo(update, column) {
  const marker = `${column} = $`;
  const at = update.text.indexOf(marker);
  if (at < 0) return undefined;
  const digits = update.text.slice(at + marker.length).match(/^[0-9]+/);
  assert.ok(digits, `${column} must be written from a parameter`);
  return update.params[Number(digits[0]) - 1];
}

test('a save that never mentions the description or the labels writes neither', async () => {
  // Exactly what `commitDraft` sends.
  const { queries, answered } = await run({
    title: 'Opozicija',
    positionList: [{ fen: FEN, title: 'Deo 1' }],
  });

  assert.equal(answered.status, 200);
  const update = updateOf(queries);
  assert.doesNotMatch(update.text, /description/,
    'a request that said nothing about the description must not write that column');
  assert.doesNotMatch(update.text, /tags/,
    'nor the labels');
  assert.match(update.text, /title = /, 'the title is still written');
  assert.match(update.text, /position_list = /, 'and so are the steps it sent');
});

test('a save that carries them writes them', async () => {
  const { queries } = await run({
    title: 'Opozicija',
    description: 'Six lessons about the opposition',
    tags: ['endgame', 'opposition'],
    positionList: [{ fen: FEN, title: 'Deo 1' }],
  });

  const update = updateOf(queries);
  assert.equal(writtenTo(update, 'description'), 'Six lessons about the opposition');
  assert.deepEqual(writtenTo(update, 'tags'), ['endgame', 'opposition']);
});

test('an empty label list sent on purpose still clears them', async () => {
  // The other half, and the reason this is not `COALESCE`: "this tutorial has
  // no labels now" is a thing a trainer is allowed to say, and it has to stay
  // sayable. It reaches the column as an empty array rather than as NULL, and
  // the two read the same everywhere it matters: `unnest('{}')` yields no rows
  // for `GET /lessons/labels`, and `tags && '{}'` is false for every filter.
  const { queries } = await run({
    title: 'Opozicija',
    tags: [],
    positionList: [{ fen: FEN, title: 'Deo 1' }],
  });

  const update = updateOf(queries);
  assert.match(update.text, /tags = /, 'the column is written');
  assert.deepEqual(writtenTo(update, 'tags'), []);
});

test('the columns that are written still line up with their parameters', async () => {
  // The statement is built from a list now, so the danger it did not have
  // before is a clause numbered $4 reading the value meant for $5 — which no
  // assertion about one column can see. Every column in the SET clause is
  // checked against the value it was given, in one request that mentions
  // everything.
  const { queries } = await run({
    title: 'Opozicija',
    description: 'opis',
    tags: ['endgame'],
    fen: FEN,
    pgn: '1. e4 *',
    positionList: [{ fen: FEN, title: 'Deo 1' }],
  });

  const update = updateOf(queries);
  assert.equal(writtenTo(update, 'title'), 'Opozicija');
  assert.equal(writtenTo(update, 'description'), 'opis');
  assert.deepEqual(writtenTo(update, 'tags'), ['endgame']);
  assert.equal(writtenTo(update, 'fen'), FEN);
  assert.equal(writtenTo(update, 'pgn'), '1. e4 *');

  // And the two the WHERE clause is built from, which move with the list. Read
  // through the clause itself rather than off the end of the parameters: the
  // numbering is computed now, and a lesson id read out of the owner's slot
  // would update nothing while every assertion above still passed.
  const where = /WHERE id = \$([0-9]+) AND \(user_id = \$([0-9]+) OR trainer_id = \$([0-9]+)\)/
    .exec(update.text);
  assert.ok(where, 'the WHERE clause must still name its parameters');
  assert.equal(update.params[Number(where[1]) - 1], '7', 'the lesson being updated');
  assert.equal(update.params[Number(where[2]) - 1], 1, 'the account allowed to');
  assert.equal(where[2], where[3], 'and both owner tests read the same parameter');
});
