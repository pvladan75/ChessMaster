// The words of a position study — docs/PLAN-STUDIJA-POZICIJE.md, §3 and D5:
// the request the app sends, the prompt this server writes, the shape of the
// answer, the two mounted routes, and that nothing here asks Gemini any more.
//
// The request stands on `docs/gates/study_words_request.json`, which is the
// app's own builder's output for the owner's position of 28.9.2026 and the
// fixture the app's tests are held to as well: two ends that must agree share
// one fixture (rule 12). The model is a fake that answers in turn, so each
// case says what the model said; what is asserted is what the route does with
// it.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const {
  CAPS, KINDS, SLOTS, MODEL, EFFORT,
  validateStudyWordsRequest, buildStudyPrompt, checkStudyAnswer,
} = require('../services/studyWords');
const router = require('../routes/studyWords');
const { authenticateToken } = require('../middleware/auth');
const { LlmUnavailable } = require('../services/llm/deepseek');
const {
  ENT, METRIC, QUOTAS, TIER_ENTITLEMENTS, UNIT_COSTS,
} = require('../services/entitlementService');

const FIXTURE = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', '..', 'docs', 'gates', 'study_words_request.json'), 'utf8'));
const body = () => structuredClone(FIXTURE.request);
const REQUEST = validateStudyWordsRequest(body());
const OFFERED = REQUEST.items.flatMap((i) => i.slots.map((s) => s.id));

/// One move, as „Generate AI comment" sends it: the fixture's first move item.
const commentBody = () => {
  const b = body();
  return { ...b, items: [b.items.find((i) => i.kind === 'move')] };
};

function refused(mutate, why, make = body) {
  const b = make();
  mutate(b);
  assert.throws(() => validateStudyWordsRequest(b), (err) => err instanceof RangeError && why.test(err.message));
}

// ---- the request ------------------------------------------------------------

test('the shared fixture is a request the server takes, and it is the owner\'s line', () => {
  assert.equal(REQUEST.side, 'Black');
  const tempting = REQUEST.items.find((i) => i.kind === 'tempting');
  assert.ok(tempting, 'the study has a tempting move');
  assert.equal(tempting.label, '7... Be4');
  assert.deepEqual(tempting.lines.trap.slice(0, 3), ['Bxh1', 'Rxa7', 'Rxa7']);
  assert.deepEqual(
    tempting.slots.map((s) => s.id),
    ['t1.move', 't1.reply', 't1.greedy', 't1.punish'],
  );
});

test('the position is pieces in words, never a FEN', () => {
  assert.match(REQUEST.position, /^White: K/);
  assert.ok(!REQUEST.position.includes('/'), 'a FEN has slashes');
  refused((b) => { b.position = ''; }, /position is empty/);
  refused((b) => { b.position = 'x'.repeat(CAPS.positionChars + 1); }, /longer than/);
  refused((b) => { b.side = 'white'; }, /side must be White or Black/);
});

test('at most twenty items, each with an id of its own', () => {
  assert.equal(CAPS.items, 20);
  refused((b) => {
    b.items = Array.from({ length: 21 }, (_, i) => ({
      ...b.items[1], id: `m${i + 1}`, slots: [{ id: `m${i + 1}.move`, text: 'x' }],
    }));
  }, /At most 20 items/);
  refused((b) => { b.items[1].id = b.items[0].id; }, /a new id/);
  refused((b) => { b.items[1].id = 'x1'; }, /a new id/);
  refused((b) => { b.items = []; }, /non-empty/);
});

test('a slot belongs to its item\'s kind', () => {
  assert.deepEqual(KINDS.position, ['position', 'threat']);
  assert.deepEqual(KINDS.trap, ['capture', 'punish']);
  assert.deepEqual(KINDS.tempting, ['move', 'reply', 'greedy', 'punish']);
  refused((b) => { b.items[0].slots[0].id = 's.move'; }, /must be one of s\.position, s\.threat/);
  refused((b) => { b.items[0].slots.push({ ...b.items[0].slots[0] }); }, /once/);
  refused((b) => { b.items[0].kind = 'opinion'; }, /kind must be one of/);
  refused((b) => { b.items[0].slots[0].text = '   '; }, /text is empty/);
  refused((b) => { b.items[0].slots = []; }, /must hold 1 to 4 slots/);
});

test('lines are named, few and short', () => {
  refused((b) => { b.items[0].lines = { main: Array(17).fill('Nf3') }; }, /at most 16 moves/);
  refused((b) => { b.items[0].lines = { 'Main Line': ['e4'] }; }, /lowercase letters/);
  refused((b) => {
    b.items[0].lines = {
      a: ['e4'], b: ['e4'], c: ['e4'], d: ['e4'], e: ['e4'],
    };
  }, /more than 4 lines/);
  refused((b) => { b.items[0].lines = ['e4']; }, /an object of named lines/);
});

// ---- the prompt ---------------------------------------------------------------

test('the prompt carries the pieces, every item\'s lines and every slot\'s facts', () => {
  const prompt = buildStudyPrompt(REQUEST);
  assert.ok(prompt.includes(REQUEST.position));
  assert.ok(prompt.includes('Black is to move.'));
  assert.ok(prompt.includes('### t1 — a tempting move: 7... Be4'));
  assert.ok(prompt.includes('Line "trap": Bxh1 Rxa7 Rxa7'));
  for (const item of REQUEST.items) {
    for (const slot of item.slots) {
      assert.ok(prompt.includes(`- \`${slot.id}\`: ${slot.text}`), slot.id);
    }
  }
  assert.ok(!/\{\w+\}/.test(prompt.replace(/\{"slots"[\s\S]*?\}\}/, '')),
    'no template name is left unfilled');
});

test('the prompt describes only the slots offered, and its example names only them', () => {
  // The first run of phase 0 described `s.threat` to a position with no
  // threat, and the model wrote one, twice.
  assert.ok(!OFFERED.includes('s.threat'), 'the fixture\'s position has no threat');
  const prompt = buildStudyPrompt(REQUEST);
  assert.ok(!prompt.includes('s.threat'));
  assert.ok(!prompt.includes(SLOTS['position.threat']));
  assert.ok(prompt.includes(SLOTS['tempting.greedy']));
  const example = JSON.parse(prompt.match(/\{"slots":\{[^\n]*\}\}/)[0]);
  assert.deepEqual(Object.keys(example.slots), OFFERED);

  const one = validateStudyWordsRequest(commentBody());
  const small = buildStudyPrompt(one);
  assert.ok(small.includes(SLOTS['move.move']));
  assert.ok(!small.includes(SLOTS['tempting.greedy']));
  assert.ok(!small.includes(SLOTS['outcome.outcome']));
});

test('every slot of every kind has its description', () => {
  for (const [kind, names] of Object.entries(KINDS)) {
    for (const name of names) {
      assert.equal(typeof SLOTS[`${kind}.${name}`], 'string', `${kind}.${name}`);
    }
  }
  assert.equal(Object.keys(SLOTS).length,
    Object.values(KINDS).reduce((n, names) => n + names.length, 0));
});

// ---- the answer's shape ------------------------------------------------------------

test('the fixture\'s answer is the shape: every slot it wrote, as written', () => {
  const checked = checkStudyAnswer(FIXTURE.answer, REQUEST);
  assert.equal(checked.ok, true, JSON.stringify(checked.problems));
  assert.deepEqual(Object.keys(checked.slots).sort(), [...OFFERED].sort());
  assert.deepEqual(checked.dropped, []);
});

test('a slot left out is allowed; an answer with none is not', () => {
  const some = checkStudyAnswer('{"slots": {"s.position": "Black gets the pawn back."}}', REQUEST);
  assert.equal(some.ok, true);
  assert.deepEqual(Object.keys(some.slots), ['s.position']);
  const none = checkStudyAnswer('{"slots": {"s.position": "  "}}', REQUEST);
  assert.equal(none.ok, false);
  assert.match(none.problems[0], /no slot was written/);
});

test('a slot that was not offered is dropped and named, and nothing of it is kept', () => {
  const extra = checkStudyAnswer(
    '{"slots": {"s.position": "Black gets the pawn back.", "s.threat": "White threatens mate."}}',
    REQUEST,
  );
  assert.equal(extra.ok, true);
  assert.deepEqual(Object.keys(extra.slots), ['s.position']);
  assert.deepEqual(extra.dropped, ['s.threat']);
  // With nothing else written it is no answer at all.
  const only = checkStudyAnswer('{"slots": {"s.threat": "White threatens mate."}}', REQUEST);
  assert.equal(only.ok, false);
  assert.match(only.problems[0], /no slot was written/);
});

test('a slot too long, or an answer that is not an object of slots, is not the shape', () => {
  const long = checkStudyAnswer(
    JSON.stringify({ slots: { 's.position': 'x'.repeat(CAPS.answerSlotChars + 1) } }), REQUEST,
  );
  assert.equal(long.ok, false);
  assert.match(long.problems[0], /at most 640/);
  assert.equal(checkStudyAnswer('not json at all', REQUEST).ok, false);
  assert.equal(checkStudyAnswer('{"slots": ["s.position"]}', REQUEST).ok, false);
  assert.equal(checkStudyAnswer('{"comments": {}}', REQUEST).ok, false);
});

test('an answer inside a code fence is read', () => {
  const fenced = `Here it is:\n\`\`\`json\n${FIXTURE.answer}\n\`\`\``;
  assert.equal(checkStudyAnswer(fenced, REQUEST).ok, true);
});

// ---- its own entitlement and counters ---------------------------------------------

test('a study has its own entitlement and counters; a comment keeps the one it had', () => {
  assert.equal(ENT.AI_STUDIES, 'ai_studies');
  assert.equal(METRIC.AI_STUDIES, 'ai_studies');
  assert.equal(METRIC.AI_STUDY_TOKENS, 'ai_study_tokens');
  assert.equal(METRIC.AI_COMMENT_TOKENS, 'ai_comment_tokens');
  assert.equal(new Set([
    METRIC.AI_STUDY_TOKENS, METRIC.AI_COMMENT_TOKENS, METRIC.AI_REVIEW_TOKENS,
    METRIC.AI_TUTORIAL_TOKENS, METRIC.AI_TRANSLATION_TOKENS,
  ]).size, 5, 'five counters, five names');
  assert.equal(QUOTAS.premium[ENT.AI_STUDIES], 30);
  assert.equal(QUOTAS.pro[ENT.AI_STUDIES], 100);
  assert.equal(QUOTAS.club[ENT.AI_STUDIES], -1);
  for (const tier of ['premium', 'pro', 'club']) {
    assert.ok(TIER_ENTITLEMENTS[tier].includes(ENT.AI_STUDIES), tier);
  }
  assert.equal(TIER_ENTITLEMENTS.free.includes(ENT.AI_STUDIES), false);
  assert.equal(QUOTAS.free[ENT.AI_STUDIES], undefined, 'a free account has no study');
  assert.equal(QUOTAS.free[ENT.AI_COMMENTS], 10, 'and the ten comments it always had');
  assert.ok(METRIC.AI_STUDY_TOKENS in UNIT_COSTS);
  assert.ok(METRIC.AI_COMMENT_TOKENS in UNIT_COSTS);
});

// ---- the routes -------------------------------------------------------------------------

function fakeRes() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
}

const BAD = '{"comments": "nothing"}';

function harness(replies, tokens = METRIC.AI_STUDY_TOKENS) {
  const recorded = [];
  const refunds = [];
  const prompts = [];
  const queue = [...replies];
  const provider = {
    configured: () => true,
    complete: async (prompt) => {
      prompts.push(prompt);
      const next = queue.shift();
      if (next instanceof Error) throw next;
      return { content: next, usage: { prompt: 10, answer: 20, thoughts: 5, total: 30 }, model: 'deepseek-flash' };
    },
  };
  const handler = router.createStudyWordsHandler({
    provider,
    tokens,
    record: async (userId, metric, amount) => { recorded.push([userId, metric, amount]); },
    refund: async (req) => { refunds.push(req.user.id); },
  });
  const call = async (userId = 7) => {
    const res = fakeRes();
    await handler({ user: { id: userId }, studyWordsRequest: REQUEST, quota: {} }, res);
    return res;
  };
  return {
    call, recorded, refunds, prompts,
  };
}

function route(at) {
  const layer = router.stack.find((l) => l.route && l.route.path === at && l.route.methods.post);
  assert.ok(layer, `POST ${at} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

test('a study\'s guards run in the order that spends least on a failing request', () => {
  const handlers = route('/');
  assert.equal(handlers.length, 7);
  assert.equal(handlers[0], authenticateToken, 'sign-in first');
  assert.equal(handlers[3], router.validateBody, 'the request is checked before a credit is reserved');
});

test('a comment\'s guards: no entitlement to ask for, the request before the credit', () => {
  const handlers = route('/comment');
  assert.equal(handlers.length, 6);
  assert.equal(handlers[0], authenticateToken, 'sign-in first');
  assert.equal(handlers[2], router.validateComment);
});

test('a study asks for its own entitlement and spends its own quota; a comment spends ai_comments', async () => {
  const entitlements = require('../services/entitlementService');
  const study = route('/');
  const comment = route('/comment');
  const saved = {
    resolveTier: entitlements.resolveTier,
    consumeQuota: entitlements.consumeQuota,
  };
  try {
    entitlements.resolveTier = async () => 'free';
    const locked = fakeRes();
    await study[2]({ user: { id: 7 } }, locked, () => {});
    assert.equal(locked.statusCode, 403);
    assert.equal(locked.body.entitlement, ENT.AI_STUDIES);

    const spent = [];
    entitlements.consumeQuota = async (_pool, userId, metric) => {
      spent.push([userId, metric]);
      return {
        allowed: true, used: 1, limit: 30, tier: 'premium',
      };
    };
    let passed = 0;
    await study[5]({ user: { id: 7 } }, fakeRes(), () => { passed += 1; });
    await comment[4]({ user: { id: 7 } }, fakeRes(), () => { passed += 1; });
    assert.equal(passed, 2);
    assert.deepEqual(spent, [[7, METRIC.AI_STUDIES], [7, METRIC.AI_COMMENTS]]);
  } finally {
    Object.assign(entitlements, saved);
  }
});

test('the server mounts it at /study-words', () => {
  const server = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
  assert.match(server, /^app\.use\('\/study-words', studyWordsRoutes\);$/m);
  assert.match(server, /^const studyWordsRoutes = require\('\.\/routes\/studyWords'\);$/m);
});

test('a malformed request is a 400 and reserves nothing', () => {
  const res = fakeRes();
  let reached = false;
  const b = body();
  b.items[0].kind = 'opinion';
  router.validateBody({ body: b }, res, () => { reached = true; });
  assert.equal(res.statusCode, 400);
  assert.equal(reached, false);
});

test('a comment is one item, a move or a position', () => {
  const pass = (b) => {
    const res = fakeRes();
    const req = { body: b };
    let reached = false;
    router.validateComment(req, res, () => { reached = true; });
    return { res, reached, req };
  };
  const one = pass(commentBody());
  assert.equal(one.reached, true);
  assert.equal(one.req.studyWordsRequest.items.length, 1);

  const whole = pass(body());
  assert.equal(whole.reached, false);
  assert.equal(whole.res.statusCode, 400);
  assert.match(whole.res.body.error, /about one item/);

  const b = body();
  const trap = pass({ ...b, items: [b.items.find((i) => i.kind === 'tempting')] });
  assert.equal(trap.reached, false);
  assert.match(trap.res.body.error, /about move or position/);
});

test('a good first answer: the slots, one token record, no refund', async () => {
  const h = harness([FIXTURE.answer]);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.slots['t1.greedy'], JSON.parse(FIXTURE.answer).slots['t1.greedy']);
  assert.equal(res.body.attempts, 1);
  assert.deepEqual(res.body.dropped, []);
  assert.deepEqual(h.recorded, [[7, METRIC.AI_STUDY_TOKENS, 30]]);
  assert.deepEqual(h.refunds, []);
  assert.equal(h.prompts[0], buildStudyPrompt(REQUEST), 'the model is asked the server\'s prompt');
});

test('a comment\'s tokens are counted under the comments\' own counter', async () => {
  const h = harness([FIXTURE.answer], METRIC.AI_COMMENT_TOKENS);
  await h.call();
  assert.deepEqual(h.recorded, [[7, METRIC.AI_COMMENT_TOKENS, 30]]);
  assert.throws(() => router.createStudyWordsHandler({ provider: {} }), /tokens are counted under/);
});

test('a refused attempt is counted like an accepted one', async () => {
  const h = harness([BAD, FIXTURE.answer]);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.attempts, 2);
  assert.deepEqual(h.recorded, [[7, METRIC.AI_STUDY_TOKENS, 30], [7, METRIC.AI_STUDY_TOKENS, 30]]);
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
  const handler = router.createStudyWordsHandler({
    provider,
    tokens: METRIC.AI_STUDY_TOKENS,
    record: async () => {},
    refund: async (req) => { refunds.push(req.user.id); },
  });
  const first = fakeRes();
  const running = handler({ user: { id: 7 }, studyWordsRequest: REQUEST }, first);
  const releaseFirst = release;
  const second = fakeRes();
  // Against a deadline: a second request that is let through waits on the
  // model as the first does, and a test that waits with it hangs instead of
  // failing (rule 9).
  const answered = await Promise.race([
    handler({ user: { id: 7 }, studyWordsRequest: REQUEST }, second).then(() => true),
    new Promise((resolve) => { setTimeout(() => resolve(false), 500); }),
  ]);
  if (!answered) {
    release();
    releaseFirst();
  }
  assert.equal(answered, true, 'the second request was let through to the model');
  assert.equal(second.statusCode, 429);
  assert.deepEqual(refunds, [7]);
  release();
  await running;
  assert.equal(first.statusCode, 200);
});

test('a server with no key answers 503 before a credit is reserved', () => {
  const res = fakeRes();
  let reached = false;
  router.requireProvider({ configured: () => false })({}, res, () => { reached = true; });
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'not-configured');
  assert.equal(reached, false);
});

// ---- the model ------------------------------------------------------------------------

test('a study is written by deepseek-v4-pro unless the server says otherwise', () => {
  // The owner's choice of 28.9.2026, from two reports of the same twelve
  // positions: it kept 104 and 106 of 109 sentences where the fast model kept
  // 99 to 103, and wrote nothing the facts did not give it.
  assert.equal(MODEL, 'deepseek-v4-pro');
  assert.equal(EFFORT, 'low', 'the effort every run was measured at');
});

test('every door of the study asks the one model, and the server may name another', () => {
  // Read from the code, comments off: the two files that make a provider
  // for these words, and the tool that measures them.
  const root = path.join(__dirname, '..');
  for (const file of [
    path.join(root, 'routes', 'studyWords.js'),
    path.join(root, 'routes', 'userGames.js'),
    path.join(root, '..', 'tools', 'position_study', 'words.js'),
  ]) {
    const code = fs.readFileSync(file, 'utf8').replace(/^\s*\/\/.*$/gm, '');
    assert.ok(!/['"]deepseek-[a-z0-9-]+['"]/.test(code),
      `${path.basename(file)} names a model of its own`);
    assert.match(code, /model: process\.env\.STUDY_(WORDS_)?MODEL \|\| MODEL,/,
      path.basename(file));
    assert.match(code, /reasoningEffort: process\.env\.STUDY_(WORDS_REASONING_)?EFFORT \|\| EFFORT,/,
      path.basename(file));
  }
});

test('two attempts of the slower model fit inside what the proxy waits for', () => {
  // The client gives the model 100 s an attempt; nginx gives the request 300.
  const client = fs.readFileSync(
    path.join(__dirname, '..', 'services', 'llm', 'deepseek.js'), 'utf8');
  const seconds = Number(client.match(/timeoutMs = (\d+) \* 1000/)[1]);
  assert.equal(seconds, 100);
  assert.ok(router.ATTEMPTS * seconds < 300);
});

// ---- Gemini has left ------------------------------------------------------------------

/// Every `.js` this server could load, by walking the folders it is made of.
function sources(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name === 'test' || entry.name.startsWith('.')) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) sources(full, out);
    else if (entry.name.endsWith('.js')) out.push(full);
  }
  return out;
}

/// What a source `require`s, read from its code and not from its comments.
function requiresOf(file) {
  const code = fs.readFileSync(file, 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');
  return [...code.matchAll(/require\(\s*['"]([^'"]+)['"]\s*\)/g)].map((m) => m[1]);
}

test('no source of this server loads Gemini, and the package is gone', () => {
  const root = path.join(__dirname, '..');
  const files = sources(root);
  assert.ok(files.some((f) => f.endsWith(`${path.sep}server.js`)), 'server.js is in the walk');
  assert.ok(files.some((f) => f.endsWith(path.join('routes', 'userGames.js'))), 'so is the route that narrated');
  const offenders = [];
  for (const file of files) {
    for (const name of requiresOf(file)) {
      if (/genai|gemini/i.test(name)) offenders.push(`${path.relative(root, file)} requires ${name}`);
    }
  }
  assert.deepEqual(offenders, []);
  const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  const deps = Object.keys({ ...pkg.dependencies, ...pkg.devDependencies });
  assert.deepEqual(deps.filter((d) => /genai|gemini/i.test(d)), []);
  assert.equal(fs.existsSync(path.join(root, 'geminiService.js')), false);
  const env = fs.readFileSync(path.join(root, '.env.example'), 'utf8');
  assert.ok(!/^GEMINI_API_KEY=/m.test(env), '.env.example no longer asks for its key');
});

test('the two routes that asked Gemini are gone, not left answering', () => {
  const puzzles = require('../routes/puzzles');
  const paths = puzzles.stack.filter((l) => l.route).map((l) => l.route.path);
  assert.ok(paths.includes('/puzzles/next'), 'the router is the one read');
  assert.deepEqual(paths.filter((p) => p.startsWith('/ai/')), []);
});

test('the opponent narrative asks DeepSeek for a sentence, and counts its tokens', () => {
  const file = path.join(__dirname, '..', 'routes', 'userGames.js');
  const code = fs.readFileSync(file, 'utf8').replace(/^\s*\/\/.*$/gm, '');
  const at = code.indexOf('function narratorFor(');
  assert.ok(at >= 0);
  // The function's body, by its braces.
  let depth = 0;
  let end = -1;
  for (let i = code.indexOf('{', at); i < code.length; i += 1) {
    if (code[i] === '{') depth += 1;
    if (code[i] === '}') { depth -= 1; if (depth === 0) { end = i; break; } }
  }
  const bodyOf = code.slice(at, end + 1);
  assert.match(bodyOf, /complete\(prompt, \{ json: false \}\)/);
  assert.match(bodyOf, /recordUsage\(pool, userId, METRIC\.AI_COMMENT_TOKENS, reply\.usage\.total\)/);
});
