// A tutorial made from a game, translated whole before it is saved —
// docs/PLAN-JEZIK-STUDIJE.md, §8 (phase 6).
//
// The tutorial is the app's own: `expected.tutorial` of the first game in
// `chess_app/test/fixtures/game_tutorial/`, the assembly of a recorded model
// answer — a real one, with the sentences the app writes itself beside the
// model's, because that is why it is translated whole. The model is a fake
// that reads the items out of the prompt it was sent and answers each by a
// rule the case gives.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const {
  BODY_CAPS, readTutorialToTranslate, extractItems, notation,
} = require('../services/tutorialTranslation');
const router = require('../routes/gameTutorialWords');
const { authenticateToken } = require('../middleware/auth');
const { LlmUnavailable } = require('../services/llm/deepseek');
const { ENT, METRIC } = require('../services/entitlementService');

const GAME = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'chess_app', 'test',
  'fixtures', 'game_tutorial', 'g01_scandinavian-defense.json'), 'utf8'));
const tutorial = () => {
  const t = structuredClone(GAME.expected.tutorial);
  return { title: t.title, description: t.description, steps: t.positionList };
};
const body = (language = 'sr-Latn') => ({ language, tutorial: tutorial() });

function refused(mutate, why) {
  const b = body();
  mutate(b);
  assert.throws(() => readTutorialToTranslate(b), (err) => err instanceof RangeError && why.test(err.message));
}

/// The items a translation prompt carries, as `{ id: text }`.
function itemsOf(prompt) {
  const at = prompt.lastIndexOf('## Items');
  return Object.fromEntries(JSON.parse(prompt.slice(at + '## Items'.length))
    .map((i) => [i.id, i.text]));
}

function translatorOf(answer) {
  const prompts = [];
  return {
    prompts,
    configured: () => true,
    complete: async (prompt) => {
      prompts.push(prompt);
      const out = answer(itemsOf(prompt), prompts.length);
      if (out instanceof Error) throw out;
      return {
        content: JSON.stringify({ items: Object.entries(out).map(([id, text]) => ({ id, text })) }),
        usage: { total: 100 + prompts.length },
        model: 'deepseek-flash',
      };
    },
  };
}

const serbian = (items) => Object.fromEntries(
  Object.entries(items).map(([id, text]) => [id, `SR ${text}`]),
);

function fakeRes() {
  return {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
}

function harness(translator) {
  const recorded = [];
  const handler = router.createTranslateHandler({
    provider: translator,
    record: async (userId, metric, amount) => { recorded.push([userId, metric, amount]); },
  });
  const call = async (b = body(), userId = 7) => {
    const res = fakeRes();
    await handler({ user: { id: userId }, toTranslate: readTutorialToTranslate(b) }, res);
    return res;
  };
  return { call, recorded };
}

function route(at) {
  const layer = router.stack.find((l) => l.route && l.route.path === at && l.route.methods.post);
  assert.ok(layer, `POST ${at} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

// ---- the request ------------------------------------------------------------------------

test('the fixture is a tutorial with the app\'s own sentences beside the model\'s', () => {
  const { code, tutorial: t } = readTutorialToTranslate(body());
  assert.equal(code, 'sr-Latn');
  const prose = Object.values(extractItems(t));
  assert.ok(prose.length > 10, 'many texts to translate');
  // A sentence of the app's lexicon, which no model slot carries.
  assert.ok(prose.some((s) => /Watch for chances given and taken/.test(s)));
});

test('English is not a translation, and nothing but the seven languages is taken', () => {
  refused((b) => { b.language = 'en'; }, /language must be one of sr-Latn/);
  refused((b) => { b.language = 'sr'; }, /language must be one of/);
  refused((b) => { delete b.language; }, /language must be one of/);
  for (const code of ['sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr']) {
    assert.equal(readTutorialToTranslate(body(code)).code, code);
  }
});

test('a tutorial is parts with a position and a line, within the caps', () => {
  refused((b) => { b.tutorial.steps = []; }, /1 to 80 parts/);
  refused((b) => {
    b.tutorial.steps = Array(BODY_CAPS.steps + 1).fill(b.tutorial.steps[0]);
  }, /1 to 80 parts/);
  refused((b) => { b.tutorial.steps[0] = 'e4'; }, /is not a part/);
  refused((b) => { b.tutorial.steps[0].pgn = 'x'.repeat(BODY_CAPS.pgnChars + 1); }, /pgn is longer/);
  refused((b) => { delete b.tutorial.steps[0].fen; }, /fen must be text/);
  refused((b) => { b.tutorial.title = 'x'.repeat(BODY_CAPS.titleChars + 1); }, /title is longer/);
  refused((b) => {
    b.tutorial.title = null;
    b.tutorial.description = null;
    b.tutorial.steps = [{ fen: b.tutorial.steps[0].fen, pgn: '1. e4 e5', title: 'Part 1' }];
  }, /no words to translate/);
  refused((b) => {
    b.tutorial.steps = Array.from({ length: 5 }, () => ({
      fen: b.tutorial.steps[0].fen, pgn: `{ ${'word '.repeat(1800)}}`, title: 'Part 1',
    }));
  }, /more than 40000 characters/);
});

test('a malformed request is a 400 before anything is asked', () => {
  const res = fakeRes();
  let reached = false;
  router.validateTranslation({ body: { ...body(), language: 'en' } }, res, () => { reached = true; });
  assert.equal(res.statusCode, 400);
  assert.equal(reached, false);
});

// ---- the route -----------------------------------------------------------------------------

test('its guards: sign-in, a limiter, the words\' entitlement, the request, a model — no quota', async () => {
  const handlers = route('/translate');
  assert.equal(handlers.length, 6);
  assert.equal(handlers[0], authenticateToken);
  assert.equal(handlers[3], router.validateTranslation);
  assert.equal(route('/words').length, 7, 'the words spend the unit, and the translation does not');

  const entitlements = require('../services/entitlementService');
  const saved = entitlements.resolveTier;
  try {
    entitlements.resolveTier = async () => 'free';
    const locked = fakeRes();
    await handlers[2]({ user: { id: 7 } }, locked, () => {});
    assert.equal(locked.statusCode, 403);
    assert.equal(locked.body.entitlement, ENT.AI_TUTORIALS);
  } finally {
    entitlements.resolveTier = saved;
  }
});

test('the tutorial comes back translated, its moves as they were, and says its language', async () => {
  const t = translatorOf(serbian);
  const h = harness(t);
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  const out = res.body.tutorial;
  const source = tutorial();
  assert.equal(out.language, 'sr-Latn');
  assert.equal(out.title, `SR ${source.title}`);
  assert.equal(out.description, `SR ${source.description}`);
  assert.equal(out.steps.length, source.steps.length);
  const strip = (pgn) => pgn.replace(/\{[^}]*\}/g, '{}');
  out.steps.forEach((step, i) => {
    assert.equal(strip(step.pgn), strip(source.steps[i].pgn), `part ${i + 1}: the moves`);
    assert.equal(step.fen, source.steps[i].fen);
  });
  assert.ok(out.steps[0].pgn.includes('{ SR A long fight of four turning points'),
    'the app\'s own sentence is translated too');
  assert.deepEqual(h.recorded, [[7, METRIC.AI_TUTORIAL_TOKENS, 101]]);
});

test('a text whose moves changed is asked for again; twice is a 422 that names it', async () => {
  // The first text that holds notation: one without any cannot lose it.
  const source = extractItems(tutorial());
  const lost = Object.keys(source).find((key) => notation(source[key]).length > 0);
  assert.ok(lost, 'the fixture has a text with a move in it');
  const t = translatorOf((items) => {
    const out = serbian(items);
    if (out[lost]) out[lost] = 'Tekst bez ijednog poteza.';
    return out;
  });
  const h = harness(t);
  const res = await h.call();
  assert.equal(res.statusCode, 422);
  assert.equal(res.body.reason, 'bad-translation');
  assert.equal(t.prompts.length, 2);
  assert.deepEqual(Object.keys(itemsOf(t.prompts[1])), [lost]);
  assert.ok(res.body.problems.some((p) => p.startsWith(`${lost}: notation differs`)));
  assert.equal(h.recorded.length, 2, 'the provider billed both');
  assert.equal(res.body.tutorial, undefined, 'nothing half translated');
});

test('a provider failure is its reason', async () => {
  const h = harness(translatorOf(() => new LlmUnavailable('no balance', { reason: 'no-balance' })));
  const res = await h.call();
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'no-balance');
});

test('a second translation from the same account while one runs is refused', async () => {
  let release;
  const provider = {
    configured: () => true,
    complete: (prompt) => new Promise((resolve) => {
      release = () => resolve({
        content: JSON.stringify({ items: Object.entries(serbian(itemsOf(prompt))).map(([id, text]) => ({ id, text })) }),
        usage: { total: 1 },
        model: 'm',
      });
    }),
  };
  const handler = router.createTranslateHandler({ provider, record: async () => {} });
  const first = fakeRes();
  const running = handler({ user: { id: 7 }, toTranslate: readTutorialToTranslate(body()) }, first);
  const second = fakeRes();
  const answered = await Promise.race([
    handler({ user: { id: 7 }, toTranslate: readTutorialToTranslate(body()) }, second).then(() => true),
    new Promise((resolve) => { setTimeout(() => resolve(false), 500); }),
  ]);
  release();
  assert.equal(answered, true, 'the second request was let through to the model');
  assert.equal(second.statusCode, 429);
  await running;
  assert.equal(first.statusCode, 200);
});

// ---- one home -------------------------------------------------------------------------------

test('both routes translate through translateTutorial, and neither judges on its own', () => {
  for (const file of ['lessonTranslation.js', 'gameTutorialWords.js']) {
    const code = fs.readFileSync(path.join(__dirname, '..', 'routes', file), 'utf8')
      .replace(/^\s*\/\/.*$/gm, '');
    assert.match(code, /await translateTutorial\(\{/, file);
    for (const step of ['judgeTranslation(', 'mergeTranslation(', 'proveUntouched(', 'buildTranslationPrompt(']) {
      assert.ok(!code.includes(step), `${file} calls ${step} itself`);
    }
  }
});

test('the Serbian prompt carries the two corrections of §8a', () => {
  const prompt = fs.readFileSync(
    path.join(__dirname, '..', 'services', 'prompts', 'tutorial_translate.md'), 'utf8');
  assert.match(prompt, /„crni je jasno bolji"/);
  assert.match(prompt, /majstorske partije/);
  assert.match(prompt, /never „velemajstor…"/);
});
