// GET /opening-judge, GET /opening-judge/replies and GET /repertoire/book —
// the three routes that read the opening book to tell a student something.
//
// Until 15.9.2026 the routes that read the book demanded the caller's own
// Lichess token and said `no-token` without one. The book is a file now (`docs/PLAN-OTVARANJA-
// LOKALNO.md`), so what is asked here is what the services being right cannot
// say: that nothing in a request has to carry a token, that a server without
// the book says so with its reason instead of answering as if nobody played
// the position, and that a rating sent by an older app selects nothing.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in the whole server chain, and `middleware/auth`
// calls process.exit at import without this.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const judgeRouter = require('../routes/openingJudge');
const repertoireRouter = require('../routes/repertoire');
const { authenticateToken } = require('../middleware/auth');
const { openingJudge } = require('../services/openingJudgeService');
const { OpeningBookUnavailable } = require('../services/openingBook');
const { pool } = require('../db');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

function handlersOf(router, method, path) {
  const found = router.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method]
  );
  assert.ok(found, `${method.toUpperCase()} ${path} must be mounted`);
  return found.route.stack.map((s) => s.handle);
}

/// Calls the last handler, past the sign-in and the limiter in front of it, and
/// waits for it to answer — a handler that answers twice throws on the second.
function call(router, method, path, req) {
  const handlers = handlersOf(router, method, path);
  return new Promise((resolve, reject) => {
    const res = {
      statusCode: 200,
      body: undefined,
      sent: 0,
      status(code) { this.statusCode = code; return this; },
      json(payload) {
        this.sent += 1;
        if (this.sent > 1) reject(new Error('answered twice'));
        this.body = payload;
        setImmediate(() => resolve(this));
        return this;
      },
    };
    const request = { query: {}, body: {}, user: { id: 7 }, get: () => undefined, ...req };
    Promise.resolve(handlers[handlers.length - 1](request, res)).catch(reject);
  });
}

/// Replaces [name] on the judge the routes share, for one test.
function stubJudge(t, name, impl) {
  const original = openingJudge[name];
  openingJudge[name] = impl;
  t.after(() => { openingJudge[name] = original; });
}

/// A pool that answers every query with nothing, and records them.
function quietPool(t) {
  const original = { query: pool.query, connect: pool.connect };
  const queries = [];
  const query = async (text, params) => {
    queries.push({ text: text.replace(/\s+/g, ' ').trim(), params });
    return { rows: [], rowCount: 0 };
  };
  pool.query = query;
  pool.connect = async () => ({ query, release: () => {} });
  t.after(() => Object.assign(pool, original));
  return queries;
}

const unavailable = () => new OpeningBookUnavailable(
  'The opening database is not configured on this server.',
  { reason: 'not-configured', status: 503 },
);

test('every route that reads the book is behind sign-in', () => {
  assert.equal(handlersOf(judgeRouter, 'get', '/')[0], authenticateToken);
  assert.equal(handlersOf(judgeRouter, 'get', '/replies')[0], authenticateToken);
  assert.equal(handlersOf(repertoireRouter, 'get', '/book')[0], authenticateToken);
});

test('a move is judged with no Lichess token anywhere in the request', async (t) => {
  const asked = [];
  stubJudge(t, 'judge', async (...args) => {
    asked.push(args);
    return { verdict: 'theory', masters: { games: 40, total: 90, beyondBook: false } };
  });

  const res = await call(judgeRouter, 'get', '/', {
    query: { fen: START, move: 'e4', minRating: '1600' },
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.verdict, 'theory');
  // The route passes the position and the move and nothing else: no token,
  // and no rating for the judge to believe in.
  assert.deepEqual(asked, [[START, 'e4']]);
});

test('a server without the book says so, on every route that reads it', async (t) => {
  // Loud on purpose. Judged by the engine alone a theory gambit comes back a
  // mistake, and an empty panel beside the board reads as an opening nobody
  // plays.
  quietPool(t);
  stubJudge(t, 'judge', async () => { throw unavailable(); });
  stubJudge(t, 'replies', async () => { throw unavailable(); });

  const verdict = await call(judgeRouter, 'get', '/', { query: { fen: START, move: 'e4' } });
  const replies = await call(judgeRouter, 'get', '/replies', { query: { fen: START } });
  for (const res of [verdict, replies]) {
    assert.equal(res.statusCode, 503);
    assert.equal(res.body.reason, 'not-configured');
  }

  // The panel still answers — the moves the student entered do not depend on
  // the book — and says why it has no statistics.
  const book = await call(repertoireRouter, 'get', '/book', {
    query: { color: 'w', fen: START },
  });
  assert.equal(book.statusCode, 200);
  assert.equal(book.body.opened, false);
  assert.equal(book.body.unavailable, 'not-configured');
});

test('a position that is not one is a bad request on the judge routes', async (t) => {
  stubJudge(t, 'judge', async () => { throw new RangeError('Position (FEN) is invalid.'); });
  stubJudge(t, 'replies', async () => { throw new RangeError('Position (FEN) is invalid.'); });

  assert.equal((await call(judgeRouter, 'get', '/', { query: { fen: 'x', move: 'e4' } }))
    .statusCode, 400);
  assert.equal((await call(judgeRouter, 'get', '/replies', { query: { fen: 'x' } }))
    .statusCode, 400);
});

test('replies are stored at the one band, whatever rating was sent', async (t) => {
  const queries = quietPool(t);
  stubJudge(t, 'replies', async (fen) => ({
    fen,
    total: 10,
    beyondBook: false,
    replies: [],
    all: [{ uci: 'e2e4', san: 'e4', games: 10, share: 1, covered: true }],
  }));

  const res = await call(judgeRouter, 'get', '/replies', {
    query: { fen: START, minRating: '1600' },
  });

  assert.equal(res.statusCode, 200);
  const insert = queries.find((q) => q.text.startsWith('INSERT INTO opening_replies'));
  assert.ok(insert, 'the answer was stored for the drill');
  assert.deepEqual(insert.params.slice(1, 3), [0, 'book']);
});

test('a position never stored is read from the book on the way, once', async (t) => {
  // No „open the book" step: the first read of a position fills it.
  const queries = quietPool(t);
  const asked = [];
  stubJudge(t, 'replies', async (fen) => {
    asked.push(fen);
    return {
      fen,
      total: 10,
      beyondBook: false,
      replies: [],
      all: [{ uci: 'e2e4', san: 'e4', games: 10, share: 1, covered: true }],
    };
  });

  const res = await call(repertoireRouter, 'get', '/book', {
    query: { color: 'w', fen: START },
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(asked, [START]);
  assert.ok(queries.some((q) => q.text.startsWith('INSERT INTO opening_replies')),
    'what the book said was stored');
});

test('no judge route reads a Lichess token from the request any more', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  // Comments stripped: the headers explain what the routes used to demand, and
  // a test that matched the prose would fail the explanation.
  const code = (file) => fs.readFileSync(path.join(__dirname, '..', file), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');
  for (const file of ['routes/openingJudge.js', 'routes/repertoire.js', 'routes/userGames.js',
    'services/openingJudgeService.js', 'services/repertoireBook.js']) {
    const source = code(file);
    assert.doesNotMatch(source, /X-Lichess-Token/i, `${file} still reads a token header`);
    assert.doesNotMatch(source, /no-token/, `${file} still answers no-token`);
    assert.doesNotMatch(source, /explorer\.lichess/, `${file} still reaches the explorer`);
  }
});

test("the server rewrites the explorer's stored rows at start-up", () => {
  // The refresh has one caller. Deleted, every old row would stay unread for
  // ever and a student's tree would lose its branches with every test green.
  const fs = require('node:fs');
  const path = require('node:path');
  const server = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
  const start = server.slice(server.indexOf('async function startServer'));
  assert.match(start, /await initDB\(\);[\s\S]*refreshStoredReplies\(pool, \{ judge: openingJudge \}\)/);
});
