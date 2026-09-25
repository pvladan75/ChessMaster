// tablebase_local.test.js — five men or fewer from our own tables.
//
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1t: `tablebaseService` asks our own
// lila-tablebase (LOCAL_TABLEBASE_URL) for a position of five men or fewer and
// Lichess for six and seven; a local server that does not answer sends the
// question to Lichess and says so in the log; Lichess's pacing and its 429
// block hold for the Lichess half only. And `GET /api/tablebase`, through which
// the app asks: behind sign-in, in the explorer's shape.
//
// Every case asserts the URLs actually requested (rule 7), not a method a fake
// could answer for.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const {
  createTablebase, pieceCount, LOCAL_MAX_MEN, TablebaseUnavailable,
} = require('../services/tablebaseService');

const LOCAL = 'http://127.0.0.1:9000/standard';
const LICHESS = 'https://tablebase.lichess.ovh/standard';

// Positions from phase 0's walks — five men, and six with a pawn added.
const FIVE = '8/8/5k2/p7/P1K5/2N5/8/8 b - - 0 52';
const FIVE_B = '8/6p1/6k1/5R2/8/5K2/8/8 b - - 0 63';
const SIX = '8/5Rp1/6k1/6r1/7P/5K2/8/8 w - - 1 62';
const SIX_B = '5R2/6p1/6k1/5r2/7P/5K2/8/8 w - - 3 63';

const ANSWER = {
  category: 'loss',
  dtz: -4,
  checkmate: false,
  stalemate: false,
  insufficient_material: false,
  moves: [
    { uci: 'f6e5', san: 'Ke5', category: 'win', dtz: 3, zeroing: false, checkmate: false, stalemate: false },
  ],
};

/// A fetch that records every URL. [answer] decides each reply by URL:
/// an object is a 200 with it as the body, a number a status, an Error a throw.
function server(answer) {
  const urls = [];
  const fetchImpl = async (url) => {
    urls.push(url);
    const reply = answer(url);
    if (reply instanceof Error) throw reply;
    if (typeof reply === 'number') return { ok: false, status: reply, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => reply };
  };
  return { fetchImpl, urls, where: () => urls.map((u) => (u.startsWith(LOCAL) ? 'local' : 'lichess')) };
}

/// A clock the pacer can be read against: sleeping moves it, and every sleep
/// is recorded.
function clock() {
  let t = 1_000_000;
  const sleeps = [];
  return {
    now: () => t,
    sleep: async (ms) => { sleeps.push(ms); t += ms; },
    sleeps,
  };
}

function warnings() {
  const said = [];
  return { log: { warn: (m) => said.push(m) }, said };
}

test('the men are counted from the placement field, kings included', () => {
  assert.equal(LOCAL_MAX_MEN, 5);
  assert.equal(pieceCount(FIVE), 5);
  assert.equal(pieceCount(SIX), 6);
});

test('five men or fewer go to our own tables, and Lichess is not asked', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const probed = await tb.probe(FIVE);
  assert.deepEqual(s.where(), ['local']);
  assert.ok(s.urls[0].startsWith(`${LOCAL}?fen=`));
  assert.equal(decodeURIComponent(s.urls[0].split('fen=')[1]), FIVE);
  assert.equal(probed.category, 'loss');
  assert.equal(tb.stats().localRequests, 1);
  assert.equal(tb.stats().requests, 0);
});

test('six men go to Lichess even with our own tables set', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  await tb.probe(SIX);
  assert.deepEqual(s.where(), ['lichess']);
  assert.ok(s.urls[0].startsWith(`${LICHESS}?fen=`));
});

test('without our own tables, five men go to Lichess as before', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: null, ...clock() });
  await tb.probe(FIVE);
  assert.deepEqual(s.where(), ['lichess']);
});

for (const [why, reply] of [
  ['refuses', 500],
  ['cannot be reached', new Error('connect ECONNREFUSED')],
  ['answers without a category', { moves: [] }],
]) {
  test(`our own tables that ${why}: Lichess is asked, and the log says so`, async () => {
    const s = server((url) => (url.startsWith(LOCAL) ? reply : ANSWER));
    const w = warnings();
    const tb = createTablebase({
      fetchImpl: s.fetchImpl, localUrl: LOCAL, log: w.log, ...clock(),
    });
    const probed = await tb.probe(FIVE);
    assert.deepEqual(s.where(), ['local', 'lichess']);
    assert.equal(probed.category, 'loss');
    assert.equal(w.said.length, 1);
    assert.match(w.said[0], /Lokalne tabele nisu odgovorile/);
    assert.ok(w.said[0].includes(FIVE), 'the log names the position');
    assert.equal(tb.stats().localMisses, 1);
  });
}

test('a local answer is cached like any other', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  await tb.probe(FIVE);
  await tb.probe(FIVE);
  assert.deepEqual(s.where(), ['local']);
});

test('our own tables are not paced; Lichess still is', async () => {
  const s = server(() => ANSWER);
  const c = clock();
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...c });
  await tb.probe(FIVE);
  await tb.probe(FIVE_B);
  assert.deepEqual(c.sleeps, [], 'two local questions in a row wait for nothing');
  await tb.probe(SIX);
  await tb.probe(SIX_B);
  assert.deepEqual(s.where(), ['local', 'local', 'lichess', 'lichess']);
  assert.ok(c.sleeps.length > 0 && c.sleeps.every((ms) => ms > 0),
    'the second Lichess question waits for its gap');
});

test('a Lichess block holds for Lichess only: five men are still answered', async () => {
  const s = server((url) => (url.startsWith(LICHESS) ? 429 : ANSWER));
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  await assert.rejects(tb.probe(SIX), (e) => e instanceof TablebaseUnavailable && e.reason === 'rate-limited');
  assert.ok(tb.blockedForMs() > 0);
  const probed = await tb.probe(FIVE);
  assert.equal(probed.category, 'loss');
  await assert.rejects(tb.probe(SIX_B), (e) => e.reason === 'rate-limited');
  assert.deepEqual(s.where(), ['lichess', 'local'],
    'nothing is sent to Lichess while it is blocked');
});

// ---- GET /api/tablebase ------------------------------------------------------

const router = require('../routes/tablebase');
const { createTablebaseHandler } = router;
const { authenticateToken } = require('../middleware/auth');

function call(handler, query) {
  return new Promise((resolve) => {
    const res = {
      statusCode: 200,
      status(code) { this.statusCode = code; return this; },
      json(body) { resolve({ status: this.statusCode, body }); return this; },
    };
    handler({ query, user: { id: 7 } }, res);
  });
}

test('the route is behind sign-in: a guest never reaches it', () => {
  const layer = router.stack.find((l) => l.route && l.route.path === '/');
  assert.ok(layer, 'GET / is mounted');
  assert.equal(layer.route.stack[0].handle, authenticateToken);
  assert.ok(layer.route.methods.get);
});

test('the route answers in the explorer\'s shape, from the one service', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const { status, body } = await call(createTablebaseHandler({ tablebase: tb }), {
    fen: FIVE.replace(/ /g, '_'),
  });
  assert.equal(status, 200);
  assert.deepEqual(body, ANSWER);
  assert.deepEqual(s.where(), ['local']);
});

test('the route refuses what no tablebase answers, and asks nothing', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const handler = createTablebaseHandler({ tablebase: tb });
  assert.equal((await call(handler, { fen: 'not a fen' })).status, 400);
  assert.equal((await call(handler, {})).status, 400);
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  assert.equal((await call(handler, { fen: start })).status, 400);
  assert.deepEqual(s.urls, []);
});

test('a tablebase that cannot answer is a 503 with its reason, never a guess', async () => {
  const s = server(() => 429);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const { status, body } = await call(createTablebaseHandler({ tablebase: tb }), { fen: SIX });
  assert.equal(status, 503);
  assert.equal(body.reason, 'rate-limited');
});
