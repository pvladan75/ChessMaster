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

// ---- The distance to mate, for the drill's reply ---------------------------
//
// Our own tables have no DTM, and the drill's reply is chosen by it
// (`bestReply`). So a probe with `mateDistance` goes to Lichess even for five
// men; when Lichess cannot answer, our own tables' answer is used and the log
// says so.

test('with the distance to mate asked, five men go to Lichess', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const probed = await tb.probe(FIVE, { mateDistance: true });
  assert.deepEqual(s.where(), ['lichess']);
  assert.equal(probed.source, 'lichess');
  // And it is cached for everybody: a plain probe asks nothing more.
  await tb.probe(FIVE);
  assert.deepEqual(s.where(), ['lichess']);
});

test('a cached local answer does not answer a question about the distance to mate', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  await tb.probe(FIVE);
  await tb.probe(FIVE, { mateDistance: true });
  await tb.probe(FIVE, { mateDistance: true });
  assert.deepEqual(s.where(), ['local', 'lichess'],
    'Lichess is asked once, and its answer then replaces ours in the cache');
});

test('six men ask Lichess once, whatever is asked for', async () => {
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  await tb.probe(SIX, { mateDistance: true });
  await tb.probe(SIX);
  assert.deepEqual(s.where(), ['lichess']);
});

test('when Lichess cannot answer, the reply comes from our own tables, and the log says so', async () => {
  const s = server((url) => (url.startsWith(LOCAL) ? ANSWER : 500));
  const w = warnings();
  const tb = createTablebase({
    fetchImpl: s.fetchImpl, localUrl: LOCAL, retries: 0, log: w.log, ...clock(),
  });
  const probed = await tb.probe(FIVE, { mateDistance: true });
  assert.equal(probed.category, 'loss');
  assert.equal(probed.source, 'local');
  assert.deepEqual(s.where(), ['lichess', 'local']);
  assert.equal(w.said.length, 1);
  assert.match(w.said[0], /udaljenost do mata/);
});

test('two replies asked at once share one request, and its fallback', async () => {
  const s = server((url) => (url.startsWith(LOCAL) ? ANSWER : 500));
  const tb = createTablebase({
    fetchImpl: s.fetchImpl, localUrl: LOCAL, retries: 0, log: warnings().log, ...clock(),
  });
  const [a, b] = await Promise.all([
    tb.probe(FIVE, { mateDistance: true }),
    tb.probe(FIVE, { mateDistance: true }),
  ]);
  assert.equal(a.category, 'loss');
  assert.equal(b.category, 'loss');
  assert.deepEqual(s.where(), ['lichess', 'local']);
});

test('a full Lichess line is not joined for the distance to mate: our own tables answer at once', async () => {
  // Stepping through an ending in Analysis asks a position a move. Behind a
  // line, the app's ten-second wait for the server would run out, and the
  // device would ask Lichess itself — the same request twice.
  const { MATE_QUEUE_LIMIT } = require('../services/tablebaseService');
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  const urls = [];
  const fetchImpl = async (url) => {
    urls.push(url);
    if (url.startsWith(LOCAL)) return { ok: true, status: 200, json: async () => ANSWER };
    await gate;
    return { ok: true, status: 200, json: async () => ANSWER };
  };
  const where = () => urls.map((u) => (u.startsWith(LOCAL) ? 'local' : 'lichess'));
  const tb = createTablebase({ fetchImpl, localUrl: LOCAL, ...clock() });
  // One sent and held, then MATE_QUEUE_LIMIT more waiting behind it — six men
  // each, distinct, so none shares another's request.
  const sixes = [
    SIX,
    SIX_B,
    '8/5Rp1/6k1/6r1/7P/4K3/8/8 w - - 1 62',
    '8/5Rp1/6k1/6r1/7P/6K1/8/8 w - - 1 62',
    '8/5Rp1/6k1/6r1/7P/8/5K2/8 w - - 1 62',
  ].slice(0, MATE_QUEUE_LIMIT + 1);
  assert.equal(new Set(sixes).size, MATE_QUEUE_LIMIT + 1);
  const held = sixes.map((fen) => tb.probe(fen).catch(() => null));
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(where(), ['lichess'], 'one is out, the rest wait');

  // A deadline, so joining the line fails here instead of hanging the file.
  let timer;
  const deadline = new Promise((resolve) => {
    timer = setTimeout(() => resolve('joined the line'), 1000);
  });
  try {
    const probed = await Promise.race([tb.probe(FIVE, { mateDistance: true }), deadline]);
    assert.notEqual(probed, 'joined the line');
    assert.equal(probed.source, 'local');
    assert.deepEqual(where(), ['lichess', 'local']);
  } finally {
    clearTimeout(timer);
    release();
    await Promise.all(held);
  }
});

test('a short Lichess line is still joined for the distance to mate', async () => {
  const { MATE_QUEUE_LIMIT } = require('../services/tablebaseService');
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  const urls = [];
  const fetchImpl = async (url) => {
    urls.push(url);
    if (!url.startsWith(LOCAL)) await gate;
    return { ok: true, status: 200, json: async () => ANSWER };
  };
  const tb = createTablebase({ fetchImpl, localUrl: LOCAL, ...clock() });
  // One out and MATE_QUEUE_LIMIT - 1 waiting: one short of the limit.
  const fens = [SIX, SIX_B, '8/5Rp1/6k1/6r1/7P/4K3/8/8 w - - 1 62']
    .slice(0, MATE_QUEUE_LIMIT);
  const held = fens.map((fen) => tb.probe(fen).catch(() => null));
  await new Promise((resolve) => setImmediate(resolve));
  const asked = tb.probe(FIVE, { mateDistance: true });
  release();
  const probed = await asked;
  await Promise.all(held);
  assert.equal(probed.source, 'lichess');
  assert.ok(!urls.some((u) => u.startsWith(LOCAL)), 'our own tables were not asked');
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
  // Our own tables know no distance to mate: it is there, and null.
  assert.deepEqual(body, {
    ...ANSWER,
    dtm: null,
    moves: ANSWER.moves.map((m) => ({ ...m, dtm: null })),
  });
  assert.deepEqual(s.where(), ['local']);
});

test('the route keeps Lichess\'s order and its distance to mate', async () => {
  // The app plays from the first move of this list and never sorts it again,
  // so the order the source gave is part of the answer.
  const [, afterKf3] = require('./fixtures/tablebase_best.json').cases;
  const s = server(() => afterKf3.answer);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const { status, body } = await call(createTablebaseHandler({ tablebase: tb }), {
    fen: afterKf3.fen,
  });
  assert.equal(status, 200);
  assert.deepEqual(body.moves.map((m) => m.uci), afterKf3.answer.moves.map((m) => m.uci));
  assert.deepEqual(body.moves.map((m) => m.dtm), afterKf3.answer.moves.map((m) => m.dtm));
  assert.equal(body.dtm, afterKf3.answer.dtm);
});

test('mate=1 asks Lichess for five men, for the distance to mate', async () => {
  // Analysis's panel, a person reading the list. Without it the review's walk
  // keeps our own tables first (the case above), and Lichess is not spent.
  const s = server(() => ANSWER);
  const tb = createTablebase({ fetchImpl: s.fetchImpl, localUrl: LOCAL, ...clock() });
  const { status } = await call(createTablebaseHandler({ tablebase: tb }), {
    fen: FIVE.replace(/ /g, '_'), mate: '1',
  });
  assert.equal(status, 200);
  assert.deepEqual(s.where(), ['lichess']);
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
