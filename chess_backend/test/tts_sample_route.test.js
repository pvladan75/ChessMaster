// tts_sample_route.test.js — one sentence, so a voice can be heard before a
// film is spent on it.
//
// „Ili da se pusti sample sa glasom da čuje, da ne ide odmah u renderovanje" —
// 11.9.2026, after a real Azure account answered with 655 voices. Auditioning
// by exporting is minutes and a queue slot per voice; the alternative is this
// route, and what it has to get right is which voice actually speaks.
const test = require('node:test');
const assert = require('node:assert/strict');

// **Before the route is required.** `middleware/auth` calls `process.exit(1)`
// at import without this, which on CI — where there is no `.env` — takes the
// whole suite down with no message. Measured the way CI has it: `npm test`
// with `.env` moved aside.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const lessonsRouter = require('../routes/lessons');
const tts = require('../services/tts');
const { sampleFor, SAMPLES } = require('../services/spokenMoves');
const { pool } = require('../db');

function sampleRouteStack() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/tts/sample' && l.route.methods.get,
  );
  assert.ok(layer, 'GET /lessons/tts/sample must be mounted');
  return layer.route.stack.map((s) => s.handle);
}

async function runSample({ voice = 'en-US-JennyNeural', offered, spoken } = {}) {
  const originalVoices = tts.voices;
  const originalSpeak = tts.speak;
  const originalQuery = pool.query;
  const asked = [];
  // The meter's writes, so a test can say what a sample cost — and no query
  // reaches a database that this test never has.
  const queries = [];
  pool.query = async (text, values) => {
    queries.push({ text, values });
    return { rows: [], rowCount: 0 };
  };

  tts.voices = async () => (offered === undefined
    ? [{ id: 'en-US-JennyNeural' }, { id: 'sr-Latn-RS-NicholasNeural' }]
    : offered);
  tts.speak = async (args) => {
    asked.push(args);
    return spoken === undefined ? { path: 'D:/clip.wav', seconds: 2 } : spoken;
  };

  const res = {
    statusCode: 200,
    body: null,
    headers: {},
    sent: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
    set(name, value) { this.headers[name] = value; return this; },
    sendFile(path) { this.sent = path; return this; },
  };
  const req = { user: { id: 4, role: 'trener' }, query: { voice } };

  const handlers = sampleRouteStack();
  try {
    await handlers[handlers.length - 1](req, res);
    // The meter is not awaited by the route; let its write land before reading.
    await new Promise((resolve) => setImmediate(resolve));
  } finally {
    tts.voices = originalVoices;
    tts.speak = originalSpeak;
    pool.query = originalQuery;
  }
  return { res, asked, queries };
}

test('the sample is spoken by the voice that was asked for', async () => {
  const { res, asked } = await runSample({ voice: 'sr-Latn-RS-NicholasNeural' });

  assert.equal(res.statusCode, 200);
  assert.equal(res.sent, 'D:/clip.wav', 'the wav itself, not a link to it');
  assert.equal(res.headers['Content-Type'], 'audio/wav');
  assert.equal(asked.length, 1);
  assert.equal(asked[0].voice, 'sr-Latn-RS-NicholasNeural');
});

test('what is spoken is what a beat of that language would be', async () => {
  // The sample goes through `spokenMoves` like any other beat, so a trainer
  // hears the treatment their tutorial will get — including the file letter
  // that this whole day started with.
  const { asked } = await runSample({ voice: 'sr-Latn-RS-NicholasNeural' });
  assert.equal(asked[0].text, sampleFor('sr-Latn-RS-NicholasNeural'));
  assert.match(asked[0].text, /lovac ce četiri/,
    'the c is a word, which is the fault this was reported for');
  assert.doesNotMatch(asked[0].text, /Bc4/,
    'and the notation itself never reaches the synthesiser');
});

test('every language has its own sentence, and every one carries a move', () => {
  // A sample of prose proves nothing: reading „Bc4" is the whole question, and
  // a voice that spells it is the wrong voice.
  for (const [language, sentence] of Object.entries(SAMPLES)) {
    assert.match(sentence, /Bc4/, language);
  }
  // And a language with no sentence of its own is spoken in English rather than
  // refused, exactly as its moves are.
  assert.equal(sampleFor('pl_PL-darkman-medium'), sampleFor('en-US-JennyNeural'));
});

test('a voice this server does not have is refused before anything is spoken', async () => {
  // An unchecked string reaches the provider as a voice name: Azure answers 400
  // and piper quietly synthesises with a different model, so a trainer
  // auditioning voices would hear one and choose another.
  const { res, asked } = await runSample({ voice: 'sr-RS-SomebodyElsesNeural' });

  assert.equal(res.statusCode, 404);
  assert.match(res.body.error, /does not have that voice/);
  assert.equal(asked.length, 0, 'and nothing was synthesised, or paid for');
});

test('no voice at all is a refusal, not the first voice on the list', async () => {
  const { res, asked } = await runSample({ voice: '' });
  assert.equal(res.statusCode, 400);
  assert.equal(asked.length, 0);
});

test('a voice that produces nothing says so rather than sending an empty file', async () => {
  const { res } = await runSample({ spoken: null });
  assert.equal(res.statusCode, 503);
  assert.match(res.body.error, /log/, 'and where to look');
  assert.equal(res.sent, null);
});

test('a sample the provider actually spoke is metered by its characters; a cached one is not', async () => {
  // The same sentence is pressed again the moment a trainer compares two
  // voices, and Azure bills only the first time it is sent.
  const sentence = sampleFor('en-US-JennyNeural');
  const spoken = { path: 'D:/clip.wav', seconds: 2, cached: false, provider: 'azure', characters: sentence.length };

  const first = await runSample({ spoken });
  assert.equal(first.res.statusCode, 200, 'the sample is served');
  const booked = first.queries.filter(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === 'tts_azure_characters'
  );
  assert.equal(booked.length, 1);
  assert.equal(booked[0].values[0], 4, 'to the account that asked');
  assert.equal(booked[0].values[3], sentence.length, 'the characters the provider was sent');

  const again = await runSample({ spoken: { ...spoken, cached: true, characters: 0 } });
  assert.equal(again.res.statusCode, 200);
  assert.equal(
    again.queries.filter((q) => /INSERT INTO usage_counters/i.test(q.text)).length, 0,
    'a cached clip cost nothing and books nothing',
  );
});

test('a voice the metric table does not know is still served — the meter cannot fail the sample', async () => {
  // A fifth provider added to services/tts without a metric of its own is a
  // gap in the meter, not a reason to answer 500 to a trainer auditioning it.
  const { res, queries } = await runSample({
    spoken: { path: 'D:/clip.wav', seconds: 2, cached: false, provider: 'elevenlabs', characters: 40 },
  });
  assert.equal(res.statusCode, 200);
  assert.equal(res.sent, 'D:/clip.wav');
  assert.equal(queries.filter((q) => /INSERT INTO usage_counters/i.test(q.text)).length, 0);
});
