// The words of a whole-game review — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, §3a and
// phase 3: the request the app sends, the prompt this server writes, the shape
// of the answer, and the mounted route.
//
// The request stands on `docs/gates/review_words_request.json`, the fixture the
// app's builder is held to as well: two ends that must agree share one fixture
// (rule 12). The model is a fake that answers in turn, so each case says what
// the model said; what is asserted is what the route does with it — above all
// that a refused attempt costs its tokens like an accepted one, because the
// provider bills the attempt.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const {
  CAPS, validateReviewWordsRequest, buildReviewPrompt, checkReviewAnswer,
} = require('../services/reviewWords');
const router = require('../routes/reviewWords');
const { authenticateToken } = require('../middleware/auth');
const { LlmUnavailable } = require('../services/llm/deepseek');
const {
  ENT, METRIC, QUOTAS, TIER_ENTITLEMENTS,
} = require('../services/entitlementService');

const FIXTURE = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', '..', 'docs', 'gates', 'review_words_request.json'), 'utf8'));
const body = () => structuredClone(FIXTURE.request);
const REQUEST = validateReviewWordsRequest(body());

function refused(mutate, why) {
  const b = body();
  mutate(b);
  assert.throws(() => validateReviewWordsRequest(b), (err) => err instanceof RangeError && why.test(err.message));
}

// ---- the request ------------------------------------------------------------

test('the shared fixture is a request the server takes', () => {
  assert.equal(REQUEST.moments.length, 2);
  assert.deepEqual(REQUEST.moments[0].lines.refutation, ['Nf6', 'd3']);
  assert.deepEqual(REQUEST.moments[1].lines.refutation, [], 'a found move has none');
});

test('the players never leave the device: a game with headers is refused', () => {
  refused((b) => { b.game = `[White "A Student"]\n\n${b.game}`; }, /without PGN headers/);
});

test('at most ten moments — the owner\'s cap of 25.9.2026', () => {
  assert.equal(CAPS.moments, 10);
  refused((b) => {
    b.moments = Array.from({ length: 11 }, (_, i) => ({ ...b.moments[1], id: `m${i + 1}`, slots: [{ id: `m${i + 1}.played`, text: 'x' }] }));
  }, /At most 10 moments/);
});

test('a slot belongs to its moment\'s kind: a found move has one, a mistake three', () => {
  refused((b) => { b.moments[1].slots.push({ id: 'm2.better', text: 'x' }); }, /must hold 1 to 1 slots/);
  refused((b) => { b.moments[1].slots[0].id = 'm2.better'; }, /must be one of m2\.played/);
  refused((b) => { b.moments[0].slots[2].id = 'm1.played'; }, /once/);
  refused((b) => { b.moments[0].slots[0].id = 'm2.played'; }, /must be one of m1\./);
  refused((b) => { b.moments[1].lines.refutation = ['d3']; }, /no refutation/);
  refused((b) => { b.moments[0].kind = 'blunder'; }, /kind must be/);
});

test('a moment needs its better line, and a line has a length', () => {
  refused((b) => { b.moments[0].lines.better = []; }, /better is empty/);
  refused((b) => { b.moments[0].lines.second = Array(17).fill('Nf3'); }, /at most 16 moves/);
});

// ---- the prompt ---------------------------------------------------------------

test('the prompt carries each moment\'s lines, facts and slots, and the game', () => {
  const prompt = buildReviewPrompt(REQUEST);
  assert.ok(prompt.includes('1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. O-O Bc5'));
  assert.ok(prompt.includes('Italian Game'));
  assert.ok(prompt.includes('### m1 — at 3. Bc4, White to move: a mistake'));
  assert.ok(prompt.includes('Better line: d4 exd4 Nxd4'));
  assert.ok(prompt.includes('Refutation after Bc4: Nf6 d3'));
  assert.ok(prompt.includes('Second line: Nc3 Nf6'));
  assert.ok(prompt.includes('12 seconds left'), 'the clock is among the facts');
  assert.ok(prompt.includes('### m2 — at 4...Bc5, Black to move: the only move, found'));
  assert.ok(!prompt.includes('Refutation after Bc5'), 'a found move has no refutation line');
  for (const id of ['m1.played', 'm1.better', 'm1.refutation', 'm2.played']) {
    assert.ok(prompt.includes(`\`${id}\``), id);
  }
  assert.ok(!/\{\w+\}/.test(prompt.replace(/\{"slots"[\s\S]*?\}\}/, '')),
    'no template name is left unfilled');
});

// ---- the answer's shape ------------------------------------------------------------

test('the fixture\'s answer is the shape: every slot, as written', () => {
  const checked = checkReviewAnswer(FIXTURE.answer, REQUEST);
  assert.equal(checked.ok, true, JSON.stringify(checked.problems));
  assert.equal(Object.keys(checked.slots).length, 4);
});

test('a slot left out is allowed; an answer with none is not', () => {
  const some = checkReviewAnswer('{"slots": {"m1.played": "Bc4 lets Black gain time."}}', REQUEST);
  assert.equal(some.ok, true);
  assert.deepEqual(Object.keys(some.slots), ['m1.played']);
  const none = checkReviewAnswer('{"slots": {"m1.played": "  "}}', REQUEST);
  assert.equal(none.ok, false);
  assert.match(none.problems[0], /no slot was written/);
});

test('a slot not offered, or too long, is not the shape', () => {
  const extra = checkReviewAnswer('{"slots": {"m2.better": "x"}}', REQUEST);
  assert.equal(extra.ok, false);
  assert.match(extra.problems[0], /not offered/);
  const long = checkReviewAnswer(JSON.stringify({ slots: { 'm1.played': 'x'.repeat(401) } }), REQUEST);
  assert.equal(long.ok, false);
  assert.match(long.problems[0], /at most 400/);
  assert.equal(checkReviewAnswer('not json at all', REQUEST).ok, false);
});

test('an answer inside a code fence is read', () => {
  const fenced = `Here it is:\n\`\`\`json\n${FIXTURE.answer}\n\`\`\``;
  assert.equal(checkReviewAnswer(fenced, REQUEST).ok, true);
});

// ---- its own entitlement and counters ---------------------------------------------

test('the review\'s words have their own entitlement and counters, not the tutorial\'s', () => {
  assert.equal(ENT.AI_REVIEW_WORDS, 'ai_review_words');
  assert.equal(METRIC.AI_REVIEW_WORDS, 'ai_review_words');
  assert.equal(METRIC.AI_REVIEW_TOKENS, 'ai_review_tokens');
  assert.notEqual(METRIC.AI_REVIEW_TOKENS, METRIC.AI_TUTORIAL_TOKENS);
  for (const tier of ['premium', 'pro', 'club']) {
    assert.ok(TIER_ENTITLEMENTS[tier].includes(ENT.AI_REVIEW_WORDS), tier);
    assert.equal(QUOTAS[tier][ENT.AI_REVIEW_WORDS], QUOTAS[tier][ENT.AI_TUTORIALS],
      `${tier}: a placeholder, the tutorial's, until plans are decided`);
  }
  assert.equal(TIER_ENTITLEMENTS.free.includes(ENT.AI_REVIEW_WORDS), false);
});

// ---- the route --------------------------------------------------------------------------

function fakeRes() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
}

const BAD = '{"slots": {"m9.played": "nothing"}}';

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
  const handler = router.createReviewWordsHandler({
    provider,
    record: async (userId, metric, amount) => { recorded.push([userId, metric, amount]); },
    refund: async (req) => { refunds.push(req.user.id); },
  });
  const call = async (userId = 7) => {
    const res = fakeRes();
    await handler({ user: { id: userId }, reviewWordsRequest: REQUEST, quota: {} }, res);
    return res;
  };
  return { call, recorded, refunds };
}

test('the guards run in the order that spends least on a failing request', () => {
  const layer = router.stack.find((l) => l.route && l.route.path === '/' && l.route.methods.post);
  assert.ok(layer, 'POST / must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  assert.equal(handlers.length, 7);
  assert.equal(handlers[0], authenticateToken, 'sign-in first');
  assert.equal(handlers[3], router.validateBody, 'the request is checked before a credit is reserved');
});

test('the route asks for its own entitlement and spends its own quota', async () => {
  const entitlements = require('../services/entitlementService');
  const layer = router.stack.find((l) => l.route && l.route.path === '/' && l.route.methods.post);
  const handlers = layer.route.stack.map((s) => s.handle);
  const saved = {
    resolveTier: entitlements.resolveTier,
    consumeQuota: entitlements.consumeQuota,
  };
  try {
    // A free account: the entitlement guard says which entitlement it wanted.
    entitlements.resolveTier = async () => 'free';
    const locked = fakeRes();
    await handlers[2]({ user: { id: 7 } }, locked, () => {});
    assert.equal(locked.statusCode, 403);
    assert.equal(locked.body.entitlement, ENT.AI_REVIEW_WORDS);

    // The quota guard reserves a unit of the review's counter, not the tutorial's.
    const spent = [];
    entitlements.consumeQuota = async (_pool, userId, metric) => {
      spent.push([userId, metric]);
      return { allowed: true, used: 1, limit: 30, tier: 'premium' };
    };
    let passed = false;
    await handlers[5]({ user: { id: 7 } }, fakeRes(), () => { passed = true; });
    assert.equal(passed, true);
    assert.deepEqual(spent, [[7, METRIC.AI_REVIEW_WORDS]]);
  } finally {
    Object.assign(entitlements, saved);
  }
});

test('the server mounts it at /review-words', () => {
  const server = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
  assert.match(server, /^app\.use\('\/review-words', reviewWordsRoutes\);$/m);
  assert.match(server, /^const reviewWordsRoutes = require\('\.\/routes\/reviewWords'\);$/m);
});

test('a malformed request is a 400 and reserves nothing', () => {
  const res = fakeRes();
  let reached = false;
  const b = body();
  b.moments[0].kind = 'blunder';
  router.validateBody({ body: b }, res, () => { reached = true; });
  assert.equal(res.statusCode, 400);
  assert.equal(reached, false);
});

test('a good first answer: the slots, one token record, no refund', async () => {
  const h = harness([FIXTURE.answer]);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.slots['m1.better'], 'd4 opens the centre while Black is still developing.');
  assert.equal(res.body.attempts, 1);
  assert.deepEqual(h.recorded, [[7, METRIC.AI_REVIEW_TOKENS, 30]]);
  assert.deepEqual(h.refunds, []);
});

test('a refused attempt is counted like an accepted one', async () => {
  const h = harness([BAD, FIXTURE.answer]);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.attempts, 2);
  assert.deepEqual(h.recorded, [[7, METRIC.AI_REVIEW_TOKENS, 30], [7, METRIC.AI_REVIEW_TOKENS, 30]]);
});

test('two wrong shapes: a 422 with the problems, both attempts counted, the credit handed back', async () => {
  const h = harness([BAD, BAD]);
  const res = await h.call();
  assert.equal(res.statusCode, 422);
  assert.equal(res.body.reason, 'bad-answer');
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
  let release;
  const provider = {
    configured: () => true,
    complete: () => new Promise((resolve) => {
      release = () => resolve({ content: FIXTURE.answer, usage: { total: 1 }, model: 'm' });
    }),
  };
  const refunds = [];
  const handler = router.createReviewWordsHandler({
    provider, record: async () => {}, refund: async (req) => { refunds.push(req.user.id); },
  });
  const first = fakeRes();
  const running = handler({ user: { id: 7 }, reviewWordsRequest: REQUEST }, first);
  const second = fakeRes();
  await handler({ user: { id: 7 }, reviewWordsRequest: REQUEST }, second);
  assert.equal(second.statusCode, 429);
  assert.deepEqual(refunds, [7]);
  release();
  await running;
  assert.equal(first.statusCode, 200);
});
