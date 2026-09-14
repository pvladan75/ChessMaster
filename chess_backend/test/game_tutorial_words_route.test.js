// POST /lessons/from-game/words — the mounted route and its handler.
//
// The prompt and the answer's shape are proved in tutorial_words.test.js; here
// is what only the route can get wrong: the order of its guards, and what a
// credit and a token count do when an attempt fails.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Requiring a route drags in the whole server chain, and `middleware/auth`
// calls process.exit at import without this. A developer's machine has a `.env`
// and CI does not — run `npm test` with `.env` moved aside to check.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/gameTutorialWords');
const { authenticateToken } = require('../middleware/auth');
const { LlmUnavailable } = require('../services/llm/deepseek');
const { validateWordsRequest } = require('../services/tutorialWords');
const { METRIC } = require('../services/entitlementService');

const FIXTURE = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'chess_app', 'test',
  'fixtures', 'game_tutorial', 'g01_scandinavian-defense.json'), 'utf8'));
const REQUEST = validateWordsRequest(FIXTURE.expected.wordsRequest);
const GOOD = FIXTURE.answer;
const BAD = '{"title": "x", "chosen": ["m1"], "slots": {}}';

function fakeRes() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
}

function harness(replies) {
  const recorded = [];
  const refunds = [];
  const queue = [...replies];
  const provider = {
    configured: () => true,
    complete: async () => {
      const next = queue.shift();
      if (next instanceof Error) throw next;
      return { content: next, usage: { prompt: 10, answer: 20, thoughts: 5, total: 30 }, model: 'deepseek-flash' };
    },
  };
  const handler = router.createWordsHandler({
    provider,
    record: async (userId, metric, amount) => { recorded.push([userId, metric, amount]); },
    refund: async (req) => { refunds.push(req.user.id); },
  });
  const call = async (userId = 7) => {
    const res = fakeRes();
    await handler({ user: { id: userId }, wordsRequest: REQUEST, quota: {} }, res);
    return res;
  };
  return { call, handler, recorded, refunds };
}

test('the guards run in the order that spends least on a failing request', () => {
  const layer = router.stack.find((l) => l.route && l.route.path === '/words' && l.route.methods.post);
  assert.ok(layer, 'POST /words must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  assert.equal(handlers.length, 7);
  assert.equal(handlers[0], authenticateToken, 'sign-in first');
  assert.equal(handlers[3], router.validateBody, 'the request is checked before a credit is reserved');
});

test('the server mounts it before /lessons, which would read from-game as an id', () => {
  const server = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
  const words = server.indexOf("app.use('/lessons/from-game'");
  const lessons = server.indexOf("app.use('/lessons', lessonRoutes)");
  assert.ok(words > 0 && lessons > words);
});

test('a request with headers is a 400 and reserves nothing', () => {
  const res = fakeRes();
  let reached = false;
  const body = structuredClone(FIXTURE.expected.wordsRequest);
  body.game = `[White "A Student"]\n\n${body.game}`;
  router.validateBody({ body }, res, () => { reached = true; });
  assert.equal(res.statusCode, 400);
  assert.equal(reached, false);
});

test('a good request is checked into req.wordsRequest', () => {
  const req = { body: FIXTURE.expected.wordsRequest };
  let reached = false;
  router.validateBody(req, fakeRes(), () => { reached = true; });
  assert.equal(reached, true);
  assert.equal(req.wordsRequest.moments.length, REQUEST.moments.length);
});

test('no model configured is a 503 before any credit is reserved', () => {
  const res = fakeRes();
  let reached = false;
  router.requireProvider({ configured: () => false })({}, res, () => { reached = true; });
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'not-configured');
  assert.equal(reached, false);
});

test('a good first answer: the words, one token record, no refund', async () => {
  const h = harness([GOOD]);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.answer, JSON.parse(GOOD));
  assert.equal(res.body.attempts, 1);
  assert.deepEqual(h.recorded, [[7, METRIC.AI_TUTORIAL_TOKENS, 30]]);
  assert.deepEqual(h.refunds, []);
});

test('a wrong shape is asked once more, and both attempts\' tokens are counted', async () => {
  const h = harness([BAD, GOOD]);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.attempts, 2);
  assert.equal(h.recorded.length, 2);
  assert.deepEqual(h.refunds, []);
});

test('two wrong shapes: a 422 with the problems, and the credit handed back', async () => {
  const h = harness([BAD, BAD]);
  const res = await h.call();
  assert.equal(res.statusCode, 422);
  assert.equal(res.body.reason, 'bad-answer');
  assert.ok(res.body.problems.some((p) => p.startsWith('attempt 1:')));
  assert.ok(res.body.problems.some((p) => p.startsWith('attempt 2:')));
  assert.equal(h.recorded.length, 2, 'the provider billed both attempts');
  assert.deepEqual(h.refunds, [7]);
});

test('a provider failure is its reason, and the credit is handed back', async () => {
  const h = harness([new LlmUnavailable('no balance', { reason: 'no-balance' })]);
  const res = await h.call();
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'no-balance');
  assert.deepEqual(h.refunds, [7]);
});

test('a second request from the same account while one is writing is refused', async () => {
  // One release per call, in order. A single variable would be overwritten by
  // the second account's call, and the first would then wait for ever.
  const releases = [];
  const release = () => releases.shift()();
  const provider = {
    configured: () => true,
    complete: () => new Promise((resolve) => {
      releases.push(() => resolve({ content: GOOD, usage: { total: 1 }, model: 'm' }));
    }),
  };
  const refunds = [];
  const handler = router.createWordsHandler({
    provider, record: async () => {}, refund: async (req) => { refunds.push(req.user.id); },
  });
  const first = fakeRes();
  const running = handler({ user: { id: 7 }, wordsRequest: REQUEST }, first);
  const second = fakeRes();
  await handler({ user: { id: 7 }, wordsRequest: REQUEST }, second);
  assert.equal(second.statusCode, 429);
  assert.equal(second.body.reason, 'already-writing');
  assert.deepEqual(refunds, [7], 'the second request\'s credit is handed back');

  const other = fakeRes();
  const otherRunning = handler({ user: { id: 8 }, wordsRequest: REQUEST }, other);
  release();
  await running;
  release();
  await otherRunning;
  assert.equal(first.statusCode, 200);
  assert.equal(other.statusCode, 200, 'another account is not blocked');

  // And the lock is released: the same account may ask again once it is done.
  const again = fakeRes();
  const againRunning = handler({ user: { id: 7 }, wordsRequest: REQUEST }, again);
  release();
  await againRunning;
  assert.equal(again.statusCode, 200);
});
