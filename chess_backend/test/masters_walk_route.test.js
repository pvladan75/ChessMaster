// POST /opening-explorer/masters-walk — the mounted route, not the service.
//
// The service is proved in masters_book.test.js. What is asked here is what a
// helper being right cannot say: that the route is mounted, that nobody can
// reach it without signing in, and that each refusal becomes the answer a
// client can act on.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in the whole server chain, and `middleware/auth`
// calls process.exit at import without this. A developer's machine has a `.env`
// and CI does not — run `npm test` with `.env` moved aside to check.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/openingExplorer');
const { authenticateToken } = require('../middleware/auth');
const { createOpeningBook } = require('../services/openingBook');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

function layer() {
  const found = router.stack.find(
    (l) => l.route && l.route.path === '/masters-walk' && l.route.methods.post
  );
  assert.ok(found, 'POST /opening-explorer/masters-walk must be mounted');
  return found.route.stack.map((s) => s.handle);
}

function call(body) {
  const handlers = layer();
  const res = {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  handlers[handlers.length - 1]({ body }, res);
  return res;
}

test('the walk is behind sign-in', () => {
  assert.equal(layer()[0], authenticateToken);
});

test('a walk answers with the positions the book holds', (t) => {
  const asked = [];
  router.useOpeningBook({
    walk: (fens) => {
      asked.push(fens);
      return { positions: [{ fen: START, white: 1, draws: 0, black: 0, moves: [] }] };
    },
  });
  t.after(() => router.useOpeningBook(createOpeningBook({ path: '' })));
  const res = call({ fens: [START] });
  assert.equal(res.statusCode, 200);
  assert.deepEqual(asked, [[START]]);
  assert.equal(res.body.positions[0].fen, START);
});

test('a body that is not a list of positions is a 400 with the reason', (t) => {
  router.useOpeningBook(createOpeningBook({ path: 'unused.sqlite', openDatabase: () => { throw new Error('not opened'); } }));
  t.after(() => router.useOpeningBook(createOpeningBook({ path: '' })));
  for (const body of [undefined, {}, { fens: 'x' }, { fens: [] }]) {
    const res = call(body);
    assert.equal(res.statusCode, 400, JSON.stringify(body));
    assert.match(res.body.error, /FEN/);
  }
});

test('no database on this server is a 503 that says so', () => {
  router.useOpeningBook(createOpeningBook({ path: '' }));
  const res = call({ fens: [START] });
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'not-configured');
});

test('anything else is a 500, not a crash', (t) => {
  router.useOpeningBook({ walk: () => { throw new Error('disk on fire'); } });
  t.after(() => router.useOpeningBook(createOpeningBook({ path: '' })));
  const res = call({ fens: [START] });
  assert.equal(res.statusCode, 500);
  assert.ok(!(res.body.error.includes('disk')), 'the cause is logged, not sent');
});
