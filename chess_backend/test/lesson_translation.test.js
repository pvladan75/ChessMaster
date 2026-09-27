// lesson_translation.test.js — phase 9 of docs/PLAN-PRIPREMA.md: a tutorial
// translated into a copy.
//
// Gates:
//  1. the judge faults exactly what the shared fixture says, as the batch
//     tool's judge does (fixtures/translation_cases.json);
//  2. only prose leaves the tutorial — found by braces, never by reading a
//     move — and the merge changes nothing but prose, which is proved;
//  3. the faked model is asserted on the request it was sent;
//  4. a translation that changes, drops or adds a move or a square, or drops
//     or invents an item, is asked for once more and then refused;
//  5. a refused translation leaves NO copy behind, not half of one, and the
//     source is never written to;
//  6. the copy is one INSERT in the language asked for, with new step ids.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const express = require('express');
const {
  LANGUAGE_NAMES, extractItems, judgeTranslation, mergeTranslation, proveUntouched,
  chunksOf, CHUNK_CHARS,
} = require('../services/tutorialTranslation');
const { TUTORIAL_LANGUAGES } = require('../services/tutorialLanguage');
const { LlmUnavailable } = require('../services/llm/deepseek');
const { METRIC } = require('../services/entitlementService');
const { createTranslateHandler } = require('../routes/lessonTranslation');
const translationRouter = require('../routes/lessonTranslation');

const CASES = JSON.parse(fs.readFileSync(
  path.join(__dirname, 'fixtures', 'translation_cases.json'), 'utf8')).cases;

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const ROOK = '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1';

/// A tutorial as the server stores it: two parts, a generated part title, a
/// comment with a command on each side, a command-only comment, two
/// sentences on one move.
function storedTutorial() {
  return {
    title: 'The Italian Game',
    description: '## What you learn\n\n- the centre\n- **Bc4**',
    tags: ['opening'],
    fen: START,
    pgn: null,
    language: 'en',
    position_list: [
      {
        id: 'src-1',
        title: 'The first moves',
        fen: START,
        pgn: '[Event "?"]\n\n{ White starts. } 1. e4 { The king pawn. [%cal Gg1f3] } '
          + '{ And the centre is taken. } e5 { [%csl Rd5] } 2. Nf3 *',
        blackOrientation: false,
      },
      {
        id: 'src-2',
        title: 'Part 2',
        fen: ROOK,
        pgn: '{ [%cal Gc1c4] Cut the king off with Rc4. } 1. Rc4 *',
        blackOrientation: false,
      },
    ],
  };
}

// ------------------------------------------------------------------ the judge

test('the judge faults exactly what the shared fixture says', () => {
  assert.ok(CASES.length > 10);
  for (const c of CASES) {
    const faults = judgeTranslation(c.source, c.translation, { code: c.code });
    assert.deepEqual(
      Object.fromEntries(Object.entries(faults).map(([k, f]) => [k, f.kind])),
      c.faults,
      c.name,
    );
  }
});

test('every language a tutorial may be in has a name to be asked for in', () => {
  assert.deepEqual(Object.keys(LANGUAGE_NAMES).sort(), [...TUTORIAL_LANGUAGES].sort());
});

// ------------------------------------------------------- extraction and merge

test('only prose leaves the tutorial, keyed by where it lives', () => {
  const t = storedTutorial();
  const items = extractItems({ title: t.title, description: t.description, steps: t.position_list });
  assert.deepEqual(items, {
    title: 'The Italian Game',
    description: '## What you learn\n\n- the centre\n- **Bc4**',
    'p1.title': 'The first moves',
    'p1.c1': 'White starts.',
    'p1.c2': 'The king pawn.',
    'p1.c3': 'And the centre is taken.',
    // p1.c4 holds a command and no words; „Part 2" is the app's own name.
    'p2.c1': 'Cut the king off with Rc4.',
  });
});

test('the merge changes words and nothing else, drops the ids, and says so', () => {
  const t = storedTutorial();
  const tutorial = { title: t.title, description: t.description, steps: t.position_list };
  const merged = mergeTranslation(tutorial, {
    title: 'Italijanska partija',
    'p1.c2': 'Kraljev pešak.',
    'p2.c1': 'Odseci kralja sa Rc4.',
  });
  assert.equal(merged.title, 'Italijanska partija');
  assert.equal(merged.description, t.description, 'what was not translated stays');
  assert.equal(merged.steps[0].id, undefined);
  assert.equal(merged.steps[1].id, undefined);
  assert.match(merged.steps[0].pgn, /\{ Kraljev pešak\. \[%cal Gg1f3\] \}/);
  assert.match(merged.steps[1].pgn, /\{ \[%cal Gc1c4\] Odseci kralja sa Rc4\. \}/,
    'a command stays on the side of the words it was on');
  assert.match(merged.steps[0].pgn, /\{ \[%csl Rd5\] \}/, 'a command-only comment is untouched');
  assert.doesNotThrow(() => proveUntouched(t.position_list, merged.steps));
  assert.deepEqual(t.position_list[0].id, 'src-1', 'the source is not changed in place');
});

test('the proof refuses a move, an arrow or a field that changed', () => {
  const t = storedTutorial();
  const tutorial = { title: t.title, description: t.description, steps: t.position_list };
  const good = mergeTranslation(tutorial, {});
  const move = structuredClone(good.steps);
  move[0].pgn = move[0].pgn.replace('2. Nf3', '2. Nc3');
  assert.throws(() => proveUntouched(t.position_list, move), /outside its comments/);
  const arrow = structuredClone(good.steps);
  arrow[0].pgn = arrow[0].pgn.replace('Gg1f3', 'Gg1h3');
  assert.throws(() => proveUntouched(t.position_list, arrow), /arrow or a coloured square/);
  const fen = structuredClone(good.steps);
  fen[1].fen = START;
  assert.throws(() => proveUntouched(t.position_list, fen), /fen changed/);
});

test('a long tutorial is asked for in pieces, every item in one of them', () => {
  const items = {};
  for (let i = 1; i <= 40; i += 1) items[`p${i}.c1`] = `${'Sentence '.repeat(60)}${i}.`;
  const chunks = chunksOf(items);
  assert.ok(chunks.length > 1);
  for (const chunk of chunks) {
    const size = Object.values(chunk).reduce((n, text) => n + text.length, 0);
    assert.ok(size <= CHUNK_CHARS || Object.keys(chunk).length === 1);
  }
  assert.deepEqual(Object.assign({}, ...chunks), items);
});

// ------------------------------------------------------------------ the route

/// A model that answers from a script: each call takes the next answer, which
/// is a function of the items it was sent. Remembers every prompt.
function fakeModel(answers, { configured = true } = {}) {
  const prompts = [];
  return {
    prompts,
    configured: () => configured,
    async complete(prompt) {
      prompts.push(prompt);
      const next = answers[Math.min(prompts.length - 1, answers.length - 1)];
      const itemsJson = prompt.slice(prompt.lastIndexOf('## Items') + '## Items'.length);
      const asked = Object.fromEntries(JSON.parse(itemsJson).map((i) => [i.id, i.text]));
      const out = await next(asked);
      return {
        content: typeof out === 'string' ? out : JSON.stringify({
          items: Object.entries(out).map(([id, text]) => ({ id, text })),
        }),
        usage: { total: 100 },
        model: 'fake-model',
      };
    },
  };
}

/// A faithful translator: marks every text as translated and keeps its
/// notation.
const faithful = (asked) => Object.fromEntries(
  Object.entries(asked).map(([id, text]) => [id, `[sr] ${text}`.replace('[sr] ', 'SR: ')]),
);

function stubDb({ row = storedTutorial(), owns = true } = {}) {
  const queries = [];
  return {
    queries,
    async query(sql, values) {
      queries.push({ sql, values });
      if (/SELECT .* FROM saved_lessons/s.test(sql)) {
        return owns ? { rows: [row], rowCount: 1 } : { rows: [], rowCount: 0 };
      }
      if (/INSERT INTO saved_lessons/.test(sql)) {
        return {
          rows: [{
            id: 99, title: values[1], description: values[2], tags: values[3],
            position_list: JSON.parse(values[6]), language: values[7],
          }],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 0 };
    },
  };
}

async function translate({ model, db = stubDb(), body = { language: 'sr-Latn' }, id = '12' }) {
  const recorded = [];
  const app = express();
  app.use(express.json());
  app.post('/lessons/:id/translate', (req, _res, next) => { req.user = { id: 4 }; next(); },
    createTranslateHandler({
      db, provider: model, record: async (u, metric, amount) => { recorded.push([u, metric, amount]); },
    }));
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/lessons/${id}/translate`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    return { status: res.status, body: await res.json(), db, recorded };
  } finally {
    server.close();
  }
}

const inserts = (db) => db.queries.filter((q) => /INSERT INTO/.test(q.sql));
const writesToSource = (db) => db.queries.filter((q) => /UPDATE|DELETE/.test(q.sql));

test('the route is mounted behind sign-in', () => {
  const layer = translationRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/translate' && l.route.methods.post,
  );
  assert.ok(layer, 'POST /:id/translate must be mounted');
  assert.equal(layer.route.stack[0].handle.name, 'authenticateToken');
});

test('a faithful translation makes one copy in the language asked for, and leaves the source alone', async () => {
  const model = fakeModel([faithful]);
  const { status, body, db, recorded } = await translate({ model });
  assert.equal(status, 201, JSON.stringify(body));

  // What the model was sent: the language in words, and only prose.
  assert.equal(model.prompts.length, 1);
  const prompt = model.prompts[0];
  assert.match(prompt, /into Serbian \(Latin script\)/);
  const sent = JSON.parse(prompt.slice(prompt.lastIndexOf('## Items') + 8));
  const t = storedTutorial();
  assert.deepEqual(sent.map((i) => i.id).sort(),
    Object.keys(extractItems({ title: t.title, description: t.description, steps: t.position_list })).sort());
  assert.doesNotMatch(prompt, /\[%cal|\[%csl|1\. e4|rnbqkbnr/, 'no move, command or position leaves');

  // One copy, one INSERT, nothing written to the source.
  assert.equal(inserts(db).length, 1);
  assert.deepEqual(writesToSource(db), []);
  const [values] = inserts(db).map((q) => q.values);
  assert.equal(values[0], 4, 'the copy is the account\'s own');
  assert.equal(values[1], 'SR: The Italian Game');
  assert.equal(values[7], 'sr-Latn');
  const steps = JSON.parse(values[6]);
  assert.equal(steps.length, 2);
  assert.ok(steps.every((s) => typeof s.id === 'string' && !s.id.startsWith('src-')),
    'new step ids, never the source\'s');
  assert.match(steps[0].pgn, /\{ SR: The king pawn\. \[%cal Gg1f3\] \}/);
  assert.equal(steps[1].title, 'Part 2', 'the app\'s own name is not translated');
  assert.equal(body.id, 99);
  assert.equal(body.language, 'sr-Latn');

  // Counted: the tokens of the attempt, and one translation.
  assert.deepEqual(recorded, [
    [4, METRIC.AI_TRANSLATION_TOKENS, 100],
    [4, METRIC.AI_TRANSLATIONS, 1],
  ]);
});

test('what was refused is asked for once more, alone and with the reason, and then kept', async () => {
  const model = fakeModel([
    (asked) => ({ ...faithful(asked), 'p2.c1': 'Odseci kralja sa Tc4.' }),
    (asked) => ({ 'p2.c1': `SR: ${asked['p2.c1']}` }),
  ]);
  const { status, db, recorded } = await translate({ model });
  assert.equal(status, 201);
  assert.equal(model.prompts.length, 2);
  const second = model.prompts[1];
  const asked = JSON.parse(second.slice(second.lastIndexOf('## Items') + 8));
  assert.deepEqual(asked.map((i) => i.id), ['p2.c1']);
  assert.match(second, /## A correction[\s\S]*p2\.c1: notation differs - lost Rc4, gained nothing/);
  assert.equal(inserts(db).length, 1);
  assert.match(JSON.parse(inserts(db)[0].values[6])[1].pgn, /SR: Cut the king off with Rc4\./);
  assert.equal(recorded.filter(([, m]) => m === METRIC.AI_TRANSLATION_TOKENS).length, 2);
});

for (const [name, wrong] of [
  ['changes a move', (a) => ({ ...faithful(a), 'p2.c1': 'Odseci kralja sa Rc5.' })],
  ['drops a square', (a) => ({ ...faithful(a), 'p2.c1': 'Odseci kralja topom.' })],
  ['adds a move', (a) => ({ ...faithful(a), 'p1.c1': 'Beli počinje sa e4.' })],
  ['drops an item', (a) => { const out = faithful(a); delete out.title; return out; }],
  ['answers in no shape at all', () => 'not json'],
]) {
  test(`a translation that ${name} twice leaves no copy behind`, async () => {
    const model = fakeModel([wrong]);
    const { status, body, db, recorded } = await translate({ model });
    assert.equal(status, 422, JSON.stringify(body));
    assert.equal(body.reason, 'bad-translation');
    assert.ok(Array.isArray(body.problems) && body.problems.length > 0);
    assert.equal(model.prompts.length, 2, 'asked once more, and no more');
    assert.deepEqual(inserts(db), [], 'not half of a copy');
    assert.deepEqual(writesToSource(db), []);
    assert.ok(!recorded.some(([, m]) => m === METRIC.AI_TRANSLATIONS), 'no translation counted');
    assert.equal(recorded.filter(([, m]) => m === METRIC.AI_TRANSLATION_TOKENS).length, 2,
      'both attempts\' tokens are counted: the provider bills them');
  });
}

test('an invented item is refused and leaves no copy, with nothing to ask again', async () => {
  const model = fakeModel([(a) => ({ ...faithful(a), 'p1.c9': 'Rečenica koje nije bilo.' })]);
  const { status, body, db } = await translate({ model });
  assert.equal(status, 422);
  assert.ok(body.problems.some((p) => p.startsWith('p1.c9: not in the source')));
  assert.equal(model.prompts.length, 1, 'every real item was right; nothing is asked again');
  assert.deepEqual(inserts(db), []);
});

test('an item invented on the second attempt is refused too', async () => {
  const model = fakeModel([
    (a) => ({ ...faithful(a), 'p2.c1': 'Odseci kralja sa Tc4.' }),
    (a) => ({ 'p2.c1': `SR: ${a['p2.c1']}`, 'p2.c7': 'Izmišljeno.' }),
  ]);
  const { status, db } = await translate({ model });
  assert.equal(status, 422);
  assert.equal(model.prompts.length, 2);
  assert.deepEqual(inserts(db), []);
});

test('refused before the model is asked: a language not offered, the one it is in, not yours, no parts', async () => {
  const cases = [
    [{ body: { language: 'ru' } }, 400],
    [{ body: {} }, 400],
    [{ body: { language: 'en' } }, 400],
    [{ db: stubDb({ owns: false }) }, 404],
    [{ db: stubDb({ row: { ...storedTutorial(), position_list: null } }) }, 400],
    [{ id: '12abc' }, 400],
  ];
  for (const [options, status] of cases) {
    const model = fakeModel([faithful]);
    const res = await translate({ model, ...options });
    assert.equal(res.status, status, JSON.stringify(options));
    assert.equal(model.prompts.length, 0);
    assert.deepEqual(inserts(res.db), []);
  }
});

test('a server with no model says so, and a model that fails leaves no copy', async () => {
  const off = await translate({ model: fakeModel([faithful], { configured: false }) });
  assert.equal(off.status, 503);
  assert.equal(off.body.reason, 'not-configured');

  const failing = fakeModel([() => { throw new LlmUnavailable('The model did not answer in time.', { reason: 'timeout' }); }]);
  const res = await translate({ model: failing });
  assert.equal(res.status, 503);
  assert.equal(res.body.reason, 'timeout');
  assert.deepEqual(inserts(res.db), []);
});

test('a second translation by the same account waits for the first', async () => {
  let release;
  const held = new Promise((resolve) => { release = resolve; });
  const model = fakeModel([async (asked) => { await held; return faithful(asked); }]);
  const recorded = [];
  const db = stubDb();
  const app = express();
  app.use(express.json());
  app.post('/lessons/:id/translate', (req, _res, next) => { req.user = { id: 4 }; next(); },
    createTranslateHandler({ db, provider: model, record: async (...a) => { recorded.push(a); } }));
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const ask = () => fetch(`http://127.0.0.1:${port}/lessons/12/translate`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ language: 'de' }),
    });
    const first = ask();
    while (model.prompts.length === 0) await new Promise((r) => setTimeout(r, 5));
    // Never awaited on its own while the model is held: without the guard the
    // second request would wait on the same hold, and a hang is not a red.
    let second = null;
    const secondAsked = ask().then((res) => { second = res; });
    const deadline = Date.now() + 5000;
    while (second === null && model.prompts.length < 2 && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 5));
    }
    assert.equal(model.prompts.length, 1, 'the second request reached the model');
    assert.ok(second, 'the second request was not answered at once');
    assert.equal(second.status, 429);
    release();
    await secondAsked;
    assert.equal((await first).status, 201);
    assert.equal(inserts(db).length, 1);
  } finally {
    release();
    server.close();
  }
});
