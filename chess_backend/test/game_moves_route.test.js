// GET /games/:id/moves — one of the caller's own games, for Analysis (D4 of
// docs/PLAN-SKELET.md). Driven mounted with `pool.query` faked, as
// lesson_fetch_one.test.js is.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in the whole server chain, and `middleware/auth`
// calls process.exit at import without this. A developer's machine has a `.env`
// and CI does not — run `npm test` with `.env` moved aside to check.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const router = require('../routes/userGames');
const { authenticateToken } = require('../middleware/auth');
const { OWN_GAMES_SQL } = require('../services/archiveScope');

function layer() {
  const found = router.stack.find(
    (l) => l.route && l.route.path === '/:id/moves' && l.route.methods.get
  );
  assert.ok(found, 'GET /games/:id/moves must be mounted');
  return found.route.stack.map((s) => s.handle);
}

async function drive(id, answer) {
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
  let passedOn = false;
  try {
    const handlers = layer();
    await handlers[handlers.length - 1](
      { params: { id }, user: { id: 4 } }, res, () => { passedOn = true; },
    );
  } finally {
    db.pool.query = original;
  }
  return { res, queries, passedOn };
}

const ROW = {
  start_fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  moves: ['e2e4', 'e7e5'],
  subject_color: 'b',
};

test('the game is behind sign-in', () => {
  assert.equal(layer()[0], authenticateToken);
});

test('an own game answers with its start, its moves and the player\'s side — no names', async () => {
  const { res, queries } = await drive('77', () => ({ rows: [ROW] }));
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { startFen: ROW.start_fen, moves: ROW.moves, subjectColor: 'b' });
  assert.deepEqual(queries[0].params, [77, 4]);
  assert.doesNotMatch(queries[0].text, /opponent/);
});

test('the query asks for the caller\'s game and for the own-games rule', async () => {
  const { queries } = await drive('77', () => ({ rows: [] }));
  const text = queries[0].text.replace(/\s+/g, ' ');
  assert.match(text, /id = \$1/);
  assert.match(text, /user_id = \$2/);
  assert.ok(text.includes(OWN_GAMES_SQL), 'an opponent\'s imported game is not the caller\'s');
});

test('a game that is not there, or not the caller\'s, is a 404', async () => {
  const { res } = await drive('77', () => ({ rows: [] }));
  assert.equal(res.statusCode, 404);
});

test('an id that is not a number is passed on, and nothing is asked', async () => {
  for (const id of ['mistakes', '12abc', '1e3']) {
    const { res, queries, passedOn } = await drive(id, () => ({ rows: [ROW] }));
    assert.equal(passedOn, true, id);
    assert.equal(queries.length, 0, id);
    assert.equal(res.body, null, id);
  }
});
