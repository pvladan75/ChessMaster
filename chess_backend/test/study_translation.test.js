// A study in the reader's language — phase 1 of docs/PLAN-JEZIK-STUDIJE.md.
//
// The words are written in English, checked for shape, and every slot is then
// translated by the tutorial translation's prompt and judge
// (`services/studyTranslation.js`) inside the same request. What is asserted:
// what the model is sent, what comes back, that a slot refused twice has no
// text at all (never the English, L3), that the translation's tokens are
// counted under the route's own counter and no second unit is spent (L4), and
// that the worst case fits inside what nginx waits for.
//
// The model is a fake that reads the items it was sent out of the prompt and
// answers each by a rule the case gives, so a case says what the model did
// with the very text it received.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const {
  TRANSLATION_MODEL, TRANSLATION_TIMEOUT_S, LAST_START_S, readStudyLanguage, translateSlots,
} = require('../services/studyTranslation');
const { validateStudyWordsRequest } = require('../services/studyWords');
const { TUTORIAL_LANGUAGES } = require('../services/tutorialLanguage');
const router = require('../routes/studyWords');
const { LlmUnavailable } = require('../services/llm/deepseek');
const { METRIC } = require('../services/entitlementService');

const FIXTURE = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', '..', 'docs', 'gates', 'study_words_request.json'), 'utf8'));
const body = () => structuredClone(FIXTURE.request);
const ENGLISH = JSON.parse(FIXTURE.answer).slots;

/// The items a translation prompt carries, as `{ id: text }`.
function itemsOf(prompt) {
  const at = prompt.lastIndexOf('## Items');
  assert.ok(at >= 0, 'the prompt ends with its items');
  const list = JSON.parse(prompt.slice(at + '## Items'.length));
  return Object.fromEntries(list.map((i) => [i.id, i.text]));
}

/// A translator whose answer to request n is `answer(items, n)`: an object of
/// `{ id: text }`, or a string sent as it is.
function translatorOf(answer) {
  const prompts = [];
  return {
    prompts,
    complete: async (prompt) => {
      prompts.push(prompt);
      const out = answer(itemsOf(prompt), prompts.length);
      if (out instanceof Error) throw out;
      const content = typeof out === 'string' ? out : JSON.stringify({
        items: Object.entries(out).map(([id, text]) => ({ id, text })),
      });
      return { content, usage: { total: 100 + prompts.length }, model: 'deepseek-flash' };
    },
  };
}

/// Every item „translated" by a prefix, which keeps its notation as it is.
const serbian = (items) => Object.fromEntries(
  Object.entries(items).map(([id, text]) => [id, `SR ${text}`]),
);

const SLOTS = {
  's.position': 'White is a pawn up after 7... Be4 8. dxc6.',
  'm1.move': 'The knight goes to f3 with Nf3, and the bishop on c4 is safe.',
  't1.move': 'Bxh1 wins the rook on h1.',
};

async function translate(translator, extra = {}) {
  const tokens = [];
  const result = await translateSlots({
    provider: translator,
    slots: SLOTS,
    code: 'sr-Latn',
    record: (total) => { tokens.push(total); },
    ...extra,
  });
  return { ...result, tokens };
}

// ---- the language a request says ----------------------------------------------

test('absent, null, empty and en are English, and nothing is translated', () => {
  for (const value of [undefined, null, '', 'en']) {
    assert.equal(readStudyLanguage(value), null, String(value));
  }
});

test('every other language a tutorial may be written in is taken, and nothing else', () => {
  for (const code of TUTORIAL_LANGUAGES.filter((c) => c !== 'en')) {
    assert.equal(readStudyLanguage(code), code);
  }
  for (const value of ['sr', 'EN', 'Serbian', 'xx', 3, {}]) {
    assert.throws(() => readStudyLanguage(value), RangeError, JSON.stringify(value));
  }
});

test('the request carries its language, and an unknown one is a 400 before a credit', () => {
  assert.equal(validateStudyWordsRequest(body()).language, null);
  assert.equal(validateStudyWordsRequest({ ...body(), language: 'de' }).language, 'de');

  const res = { status(c) { this.statusCode = c; return this; }, json(p) { this.body = p; return this; } };
  let reached = false;
  router.validateBody({ body: { ...body(), language: 'sr' } }, res, () => { reached = true; });
  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /language must be one of/);
  assert.equal(reached, false);
});

// ---- translateSlots -------------------------------------------------------------

test('each slot goes as a comment the prompt describes, and comes back under its own id', async () => {
  const t = translatorOf(serbian);
  const out = await translate(t);
  const sent = itemsOf(t.prompts[0]);
  assert.deepEqual(Object.keys(sent), ['p1.c1', 'p1.c2', 'p1.c3']);
  assert.deepEqual(Object.values(sent), Object.values(SLOTS));
  assert.ok(t.prompts[0].startsWith('# Translate a chess tutorial into Serbian (Latin script)'));
  assert.ok(!t.prompts[0].includes('m1.move'), 'the model is not sent the study\'s ids');
  assert.deepEqual(out.slots, Object.fromEntries(
    Object.entries(SLOTS).map(([id, text]) => [id, `SR ${text}`]),
  ));
  assert.deepEqual(out.refused, []);
  assert.deepEqual(out.firstRefused, []);
  assert.equal(out.requests, 1);
  assert.deepEqual(out.tokens, [101]);
});

test('a move written in Serbian letters is asked for again, with the reason, and only that one', async () => {
  const t = translatorOf((items, n) => {
    const out = serbian(items);
    if (n === 1) out['p1.c2'] = out['p1.c2'].replace('Nf3', 'Sf3');
    return out;
  });
  const out = await translate(t);
  assert.equal(out.requests, 2);
  assert.deepEqual(Object.keys(itemsOf(t.prompts[1])), ['p1.c2']);
  assert.match(t.prompts[1], /- p1\.c2: notation differs - lost Nf3, gained nothing/);
  assert.deepEqual(out.firstRefused, ['m1.move']);
  assert.deepEqual(out.refused, []);
  assert.equal(out.slots['m1.move'], `SR ${SLOTS['m1.move']}`);
  assert.deepEqual(out.tokens, [101, 102], 'both requests are counted');
});

test('a slot refused twice has no text — never the English', async () => {
  const t = translatorOf((items) => {
    const out = serbian(items);
    if (out['p1.c3']) out['p1.c3'] = 'Lxh1 osvaja topa.';
    return out;
  });
  const out = await translate(t);
  assert.deepEqual(out.refused, ['t1.move']);
  assert.ok(!('t1.move' in out.slots));
  assert.ok(!Object.values(out.slots).includes(SLOTS['t1.move']));
  assert.deepEqual(Object.keys(out.slots), ['s.position', 'm1.move']);
});

test('an answer that is not the shape asked for is asked for again whole', async () => {
  const t = translatorOf((items, n) => (n === 1 ? 'Here is the translation.' : serbian(items)));
  const out = await translate(t);
  assert.equal(out.requests, 2);
  assert.equal(Object.keys(itemsOf(t.prompts[1])).length, 3);
  assert.deepEqual(out.refused, []);
  assert.deepEqual(out.firstRefused.sort(), Object.keys(SLOTS).sort());
});

test('an id the model made up refuses the whole answer', async () => {
  const t = translatorOf((items) => ({ ...serbian(items), 'p1.c9': 'Nešto.' }));
  const out = await translate(t);
  assert.deepEqual(out.slots, {});
  assert.deepEqual(out.refused, Object.keys(SLOTS));
});

test('no request starts after the last start; what it would have asked is refused', async () => {
  let clock = 0;
  const now = () => clock;
  const late = translatorOf(serbian);
  clock = (LAST_START_S + 1) * 1000;
  const none = await translate(late, { startedAt: 0, now });
  assert.equal(late.prompts.length, 0);
  assert.equal(none.requests, 0);
  assert.deepEqual(none.refused, Object.keys(SLOTS));

  // The first request starts in time and the clock passes the line while it
  // runs: the second is not asked.
  clock = 200 * 1000;
  const slow = translatorOf((items, n) => {
    clock = (LAST_START_S + 5) * 1000;
    const out = serbian(items);
    if (n === 1) out['p1.c1'] = out['p1.c1'].replace('Be4', 'Le4');
    return out;
  });
  const half = await translate(slow, { startedAt: 0, now });
  assert.equal(slow.prompts.length, 1);
  assert.deepEqual(half.refused, ['s.position']);
  assert.deepEqual(Object.keys(half.slots), ['m1.move', 't1.move']);
});

test('a provider that fails fails the translation', async () => {
  const t = translatorOf(() => new LlmUnavailable('no balance', { reason: 'no-balance' }));
  await assert.rejects(translate(t), (err) => err instanceof LlmUnavailable);
});

test('the Serbian prompt carries the owner\'s three corrections of phase 0', async () => {
  const t = translatorOf(serbian);
  await translate(t);
  assert.match(t.prompts[0], /tablebase[^\n]*\| baza završnica/);
  assert.match(t.prompts[0], /„beli ima pešaka više"/);
  assert.match(t.prompts[0], /never „belov" or\s+„crnov"/);
});

// ---- the route -------------------------------------------------------------------

function harness({ language, translator, tokens = METRIC.AI_STUDY_TOKENS }) {
  const events = [];
  const refunds = [];
  const provider = {
    configured: () => true,
    complete: async () => {
      events.push('words');
      return { content: FIXTURE.answer, usage: { total: 30 }, model: 'deepseek-v4-pro' };
    },
  };
  const watched = {
    complete: async (prompt) => {
      events.push('translation');
      return translator.complete(prompt);
    },
  };
  const handler = router.createStudyWordsHandler({
    provider,
    translator: watched,
    tokens,
    record: async (userId, metric, amount) => { events.push(['record', userId, metric, amount]); },
    refund: async (req) => { refunds.push(req.user.id); },
  });
  const call = async () => {
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(p) { this.body = p; return this; },
    };
    await handler({
      user: { id: 7 },
      studyWordsRequest: validateStudyWordsRequest({ ...body(), language }),
    }, res);
    return res;
  };
  return { call, events, refunds };
}

test('a study in Serbian: the English, then its translation, in one answer and one unit', async () => {
  const t = translatorOf(serbian);
  const h = harness({ language: 'sr-Latn', translator: t });
  const res = await h.call();
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.slots, ENGLISH, 'the English is answered as it always was');
  assert.equal(res.body.translated.language, 'sr-Latn');
  assert.deepEqual(res.body.translated.refused, []);
  assert.deepEqual(res.body.translated.slots, Object.fromEntries(
    Object.entries(ENGLISH).map(([id, text]) => [id, `SR ${text}`]),
  ));
  assert.deepEqual(Object.values(itemsOf(t.prompts[0])), Object.values(ENGLISH),
    'the translator is sent the words the model wrote');
  assert.deepEqual(h.events, [
    'words',
    ['record', 7, METRIC.AI_STUDY_TOKENS, 30],
    'translation',
    ['record', 7, METRIC.AI_STUDY_TOKENS, 101],
  ]);
  assert.deepEqual(h.refunds, []);
});

test('a slot the translation lost twice is named in the answer and has no text', async () => {
  const lost = 't1.greedy';
  assert.ok(ENGLISH[lost], 'the fixture wrote the slot this case loses');
  const t = translatorOf((items) => {
    const out = serbian(items);
    for (const [id, text] of Object.entries(items)) {
      if (text === ENGLISH[lost]) out[id] = 'Uzimanje je zamka.';
    }
    return out;
  });
  const res = await harness({ language: 'sr-Latn', translator: t }).call();
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.translated.refused, [lost]);
  assert.ok(!(lost in res.body.translated.slots));
  assert.equal(Object.keys(res.body.translated.slots).length, Object.keys(ENGLISH).length - 1);
});

test('a comment in German counts its translation under the comments\' counter', async () => {
  const h = harness({ language: 'de', translator: translatorOf(serbian), tokens: METRIC.AI_COMMENT_TOKENS });
  const res = await h.call();
  assert.equal(res.body.translated.language, 'de');
  assert.deepEqual(h.events.filter((e) => Array.isArray(e)).map((e) => e[2]),
    [METRIC.AI_COMMENT_TOKENS, METRIC.AI_COMMENT_TOKENS]);
});

test('English, said or not, is today\'s answer: no translation asked, no field added', async () => {
  for (const language of [undefined, 'en']) {
    const t = translatorOf(serbian);
    const h = harness({ language, translator: t });
    const res = await h.call();
    assert.equal(t.prompts.length, 0);
    assert.deepEqual(Object.keys(res.body).sort(),
      ['attempts', 'dropped', 'model', 'slots', 'tokens']);
  }
});

test('a translation that cannot be had is the words refused, and the credit handed back', async () => {
  const t = translatorOf(() => new LlmUnavailable('timeout', { reason: 'timeout' }));
  const h = harness({ language: 'sr-Latn', translator: t });
  const res = await h.call();
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'timeout');
  assert.equal(res.body.slots, undefined, 'the English is not sent in its place');
  assert.deepEqual(h.refunds, [7]);
});

test('the route will not be built without a translator', () => {
  assert.throws(
    () => router.createStudyWordsHandler({ provider: {}, tokens: METRIC.AI_STUDY_TOKENS }),
    /translated by/,
  );
});

// ---- the wait ----------------------------------------------------------------------

test('the worst case — two attempts at the words, then the translation — ends before nginx does', () => {
  const client = fs.readFileSync(
    path.join(__dirname, '..', 'services', 'llm', 'deepseek.js'), 'utf8');
  const wordsSeconds = Number(client.match(/timeoutMs = (\d+) \* 1000/)[1]);
  assert.ok(router.ATTEMPTS * wordsSeconds <= LAST_START_S,
    'the first translation request can always start');
  assert.ok(LAST_START_S + TRANSLATION_TIMEOUT_S < 300, 'the last one ends under nginx\'s 300 s');
  assert.equal(TRANSLATION_MODEL, 'deepseek-flash', 'the model phase 0 measured');

  const route = fs.readFileSync(path.join(__dirname, '..', 'routes', 'studyWords.js'), 'utf8')
    .replace(/^\s*\/\/.*$/gm, '');
  assert.match(route, /createDeepSeek\(\{\s*model: TRANSLATION_MODEL,\s*timeoutMs: TRANSLATION_TIMEOUT_S \* 1000,\s*\}\)/);
});
