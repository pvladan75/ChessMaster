// api_usage_metering.test.js — what the server counts about the services it
// pays for or borrows, added 26.9.2026 so a month of measuring can decide the
// billing model (docs/CENA-I-PRETPLATA.md, §5).
//
// Three things had no meter until now:
//   1. the characters a cloud voice actually spoke (Azure bills per character;
//      a cached clip is never sent again) — `speakBeats` reports them, the
//      export route books them to the trainer;
//   2. the requests this whole server sends Lichess (tablebase, cloud
//      evaluation, archive streams, user lookups) and our own tablebase — per
//      provider per day, `provider_requests`, because most of those calls
//      cannot say whose they are;
//   3. the metric names and unit costs that price the first.
//
// Every meter must be unable to fail the thing it measures: a hook that throws
// is swallowed, a write that fails is logged, nothing is awaited.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

// The voice cache is read once, when the tts module loads: set before the
// require, into a directory this file owns.
const CACHE = fs.mkdtempSync(path.join(os.tmpdir(), 'meter-ttscache-'));
process.env.TTS_CACHE_DIR = CACHE;
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const tts = require('../services/tts');
const { narrateFilm } = require('../services/tutorialNarration');
const { RenderAborted } = require('../services/renderAbort');
const {
  PROVIDER, dayOf, recordProviderRequest, wireProviderMeters, providerHook,
} = require('../services/providerUsage');
const {
  ttsCharactersMetric, TTS_PROVIDERS, UNIT_COSTS,
} = require('../services/entitlementService');
const { createTablebase } = require('../services/tablebaseService');
const { createOpeningJudge } = require('../services/openingJudgeService');
const { wavWith } = require('./support/fakeWav');

test.after(() => fs.rmSync(CACHE, { recursive: true, force: true }));

/// A pg-pool stand-in that records what it was asked and answers nothing.
function stubPool({ fail = null } = {}) {
  const queries = [];
  return {
    queries,
    async query(text, values) {
      queries.push({ text: text.replace(/\s+/g, ' ').trim(), values });
      if (fail) throw fail;
      return { rows: [], rowCount: 0 };
    },
  };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

// ---------------------------------------------------------------- names and prices

test("a provider's characters have a metric of their own, and only known providers do", () => {
  assert.equal(ttsCharactersMetric('azure'), 'tts_azure_characters');
  assert.equal(ttsCharactersMetric('PIPER'), 'tts_piper_characters', 'case is not a second provider');
  assert.throws(() => ttsCharactersMetric('elevenlabs'), RangeError);
  assert.throws(() => ttsCharactersMetric(''), RangeError);
  assert.deepEqual(TTS_PROVIDERS, ['azure', 'google', 'piper', 'windows'],
    'the four voices services/tts/index.js can name');
});

test("every provider's characters metric is priced — at zero until .env says otherwise", () => {
  for (const provider of TTS_PROVIDERS) {
    assert.ok(ttsCharactersMetric(provider) in UNIT_COSTS, provider);
  }
});

// ---------------------------------------------------------------- provider_requests

test("a request is counted into the provider's row for the UTC day it was sent", async () => {
  const pool = stubPool();
  const at = new Date('2026-09-26T23:30:00Z');
  await recordProviderRequest(pool, PROVIDER.LICHESS_TABLEBASE, 1, at);

  assert.equal(pool.queries.length, 1);
  assert.match(pool.queries[0].text, /^INSERT INTO provider_requests/);
  assert.match(pool.queries[0].text, /ON CONFLICT \(provider, day\) DO UPDATE/);
  assert.deepEqual(pool.queries[0].values, ['lichess_tablebase', '2026-09-26', 1]);
  // Half past midnight in Belgrade is still the previous day in UTC; the row
  // is keyed by UTC, the clock usage_counters keeps.
  assert.equal(dayOf(new Date('2026-09-26T22:30:00+02:00')), '2026-09-26');
  assert.equal(dayOf(new Date('2026-09-27T00:30:00+02:00')), '2026-09-26');
});

test('an unknown provider or a count of nothing writes nothing', async () => {
  const pool = stubPool();
  await recordProviderRequest(pool, 'chesscom', 1);
  await recordProviderRequest(pool, PROVIDER.LICHESS_CLOUD_EVAL, 0);
  await recordProviderRequest(pool, PROVIDER.LICHESS_CLOUD_EVAL, -3);
  await recordProviderRequest(pool, PROVIDER.LICHESS_CLOUD_EVAL, NaN);
  assert.equal(pool.queries.length, 0);
});

test('a database that refuses the count is logged, and the caller never sees it', async () => {
  const pool = stubPool({ fail: new Error('relation "provider_requests" does not exist') });
  await assert.doesNotReject(recordProviderRequest(pool, PROVIDER.LOCAL_TABLEBASE));
  assert.equal(pool.queries.length, 1, 'it was tried');
});

test('the server wires both shared clients, and each kind lands on its own provider', async () => {
  const pool = stubPool();
  const hooks = {};
  const tablebase = { setOnRequest: (fn) => { hooks.tablebase = fn; } };
  const openingJudge = { setOnRequest: (fn) => { hooks.judge = fn; } };

  wireProviderMeters({ pool, tablebase, openingJudge });
  assert.equal(typeof hooks.tablebase, 'function');
  assert.equal(typeof hooks.judge, 'function');

  hooks.tablebase('lichess');
  hooks.tablebase('local');
  hooks.judge();
  // The hooks do not await their writes; let them land.
  await settle();

  assert.deepEqual(
    pool.queries.map((q) => q.values[0]),
    ['lichess_tablebase', 'local_tablebase', 'lichess_cloud_eval'],
  );
});

test('a hook built for a known pool counts one request per call', async () => {
  const pool = stubPool();
  const hook = providerHook(pool, PROVIDER.LICHESS_GAMES);
  hook();
  hook();
  await settle();
  assert.deepEqual(
    pool.queries.map((q) => [q.values[0], q.values[2]]),
    [['lichess_games', 1], ['lichess_games', 1]],
  );
});

// ---------------------------------------------------------------- tablebase

const PAWN_ENDING = '8/8/3pkp1p/7P/4KP2/8/8/8 b - - 6 53';
const FIVE_MEN = '8/8/5k2/p7/P1K5/2N5/8/8 b - - 0 52';
const ANSWER = {
  category: 'draw', dtz: 0, checkmate: false, stalemate: false, insufficient_material: false,
  moves: [{ uci: 'e6e7', san: 'Ke7', category: 'draw', dtz: 0, zeroing: false }],
};
const okFetch = async () => ({ ok: true, status: 200, json: async () => ANSWER });

test('a Lichess tablebase answer is reported once, and a cache hit never', async () => {
  const kinds = [];
  const tb = createTablebase({ fetchImpl: okFetch, onRequest: (kind) => kinds.push(kind) });

  await tb.probe(PAWN_ENDING);
  await tb.probe(PAWN_ENDING);
  await Promise.all([tb.probe(FIVE_MEN), tb.probe(FIVE_MEN)]);

  assert.deepEqual(kinds, ['lichess', 'lichess'], 'two positions, two requests, four probes');
});

test('our own tables report as local, and Lichess is not asked', async () => {
  const kinds = [];
  const urls = [];
  const fetchImpl = async (url) => { urls.push(url); return okFetch(); };
  const tb = createTablebase({
    fetchImpl, localUrl: 'http://127.0.0.1:9000/standard', onRequest: (kind) => kinds.push(kind),
  });

  await tb.probe(FIVE_MEN);

  assert.deepEqual(kinds, ['local']);
  assert.equal(urls.length, 1);
  assert.match(urls[0], /^http:\/\/127\.0\.0\.1:9000/);
});

test('a counter that throws costs the probe nothing, and the hook can be set after the fact', async () => {
  const warned = [];
  const tb = createTablebase({
    fetchImpl: okFetch,
    log: { warn: (line) => warned.push(line), error: () => {}, info: () => {} },
  });
  tb.setOnRequest(() => { throw new Error('pool is gone'); });

  const answer = await tb.probe(PAWN_ENDING);

  assert.equal(answer.category, 'draw', 'the position was still judged');
  assert.equal(warned.length, 1, 'and the broken counter was said once');
  assert.match(warned[0], /pool is gone/);
});

// ---------------------------------------------------------------- opening judge

const ITALIAN = 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 5 4';
const ITALIAN_NF6 = 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 6 5';

/// A book that knows the position and lists no move in it, so every verdict
/// has to ask the cloud about the position before and after.
const emptyBook = { answer: () => ({ white: 0, draws: 0, black: 0, moves: [], beyondBook: false }) };

function cloudStub() {
  const requests = [];
  const fetchImpl = async (url) => {
    requests.push(url);
    return { ok: true, status: 200, json: async () => ({ depth: 40, pvs: [{ moves: 'e2e4', cp: 20 }] }) };
  };
  return { fetchImpl, requests };
}

test('each cloud evaluation that went out is reported, and a cached one is not', async () => {
  const cloud = cloudStub();
  let reported = 0;
  const judge = createOpeningJudge({
    book: emptyBook, fetchImpl: cloud.fetchImpl, onRequest: () => { reported += 1; },
    now: () => 0, sleep: async () => {},
  });

  await judge.judge(ITALIAN, 'Nf6');
  assert.equal(cloud.requests.length, 2, 'the position before and the position after');
  assert.equal(reported, 2);

  await judge.judge(ITALIAN, 'Nf6');
  assert.equal(reported, 2, 'a cached verdict asks nobody');
  assert.equal(new Set(cloud.requests.map((u) => new URL(u).searchParams.get('fen'))).size, 2);
  assert.ok(cloud.requests.some((u) => new URL(u).searchParams.get('fen') === ITALIAN_NF6));
});

test("the judge's hook can be set after creation, and its throw is not the verdict's", async () => {
  const cloud = cloudStub();
  const judge = createOpeningJudge({
    book: emptyBook, fetchImpl: cloud.fetchImpl, now: () => 0, sleep: async () => {},
  });
  let calls = 0;
  judge.setOnRequest(() => { calls += 1; throw new Error('counter down'); });

  const verdict = await judge.judge(ITALIAN, 'Nf6');

  assert.ok(verdict.verdict, 'a verdict was still given');
  assert.equal(calls, 2);
});

// ---------------------------------------------------------------- opponent lookup

test('a rating looked up on Lichess is counted once, and a handle Lichess does not know is not', async () => {
  const { lookupRating } = require('../services/opponentPrep');
  const pacer = { spaced: (send) => send(), block() {} };
  let counted = 0;
  const onRequest = () => { counted += 1; };
  const answer = (status, body) => async () => ({ ok: status === 200, status, json: async () => body });

  const rating = await lookupRating('somebody', {
    fetchImpl: answer(200, { perfs: { blitz: { rating: 1900 } } }),
    baseUrl: 'https://lichess.org/api/user', pacer, perfTypes: [], onRequest,
  });
  assert.equal(rating, 1900);
  assert.equal(counted, 1);

  await assert.rejects(lookupRating('nobody', {
    fetchImpl: answer(404, {}), baseUrl: 'https://lichess.org/api/user', pacer, perfTypes: [], onRequest,
  }));
  assert.equal(counted, 1, 'a 404 answered nothing worth counting');
});

// ---------------------------------------------------------------- the voice

/// A voice that writes a real clip for every sentence it is given, and can be
/// told to fail or to abort part way through a film.
function fakeVoice({ failAfter = Infinity, abortAfter = Infinity, controller = null } = {}) {
  const spoken = [];
  return {
    spoken,
    provider: {
      available: () => true,
      voices: async () => [{ id: 'fake-voice', language: 'en-US' }],
      async synthesize({ text, outputPath }) {
        if (spoken.length >= failAfter) throw new Error('the voice fell over');
        if (spoken.length >= abortAfter) {
          controller.abort();
          throw new Error('killed');
        }
        spoken.push(text);
        wavWith({ seconds: 1, from: 0.1, to: 0.9, file: outputPath });
      },
    },
  };
}

function withFakeVoice(t, options) {
  const voice = fakeVoice(options);
  const saved = process.env.TTS_PROVIDER;
  process.env.TTS_PROVIDER = 'fake';
  tts.PROVIDERS.fake = voice.provider;
  t.after(() => {
    delete tts.PROVIDERS.fake;
    if (saved === undefined) delete process.env.TTS_PROVIDER;
    else process.env.TTS_PROVIDER = saved;
  });
  return voice;
}

function cachedClip(text) {
  wavWith({
    seconds: 1, from: 0.1, to: 0.9,
    file: path.join(CACHE, `${tts.cacheKey({ text, voice: 'fake-voice', provider: 'fake' })}.wav`),
  });
}

test('speakBeats reports the sentences it had to synthesise, and not the ones the cache held', async (t) => {
  const voice = withFakeVoice(t);
  const cached = 'Look at the centre.';
  cachedClip(cached);
  const reports = [];

  const clips = await tts.speakBeats(
    [cached, 'The knight goes to d five.', 'The knight goes to d five.', '', 'And now the rook.'],
    { voice: 'fake-voice', onSynthesised: (r) => reports.push(r) },
  );

  assert.equal(clips.filter((c) => c.clipSeconds).length, 4, 'every sentence has a clip');
  assert.deepEqual(voice.spoken, ['The knight goes to d five.', 'And now the rook.'],
    'the cached sentence and the repeat were never sent');
  assert.deepEqual(reports, [{
    provider: 'fake',
    characters: 'The knight goes to d five.'.length + 'And now the rook.'.length,
    sentences: 2,
  }]);
});

test('a film whose every sentence is cached reports nothing, since nothing was paid for', async (t) => {
  withFakeVoice(t);
  cachedClip('Already spoken.');
  const reports = [];
  await tts.speakBeats(['Already spoken.'], { voice: 'fake-voice', onSynthesised: (r) => reports.push(r) });
  assert.deepEqual(reports, []);
});

test('a voice that fails part way reports what it did make, and the film goes on without the rest', async (t) => {
  withFakeVoice(t, { failAfter: 1 });
  const reports = [];
  const clips = await tts.speakBeats(
    ['One sentence spoken.', 'A second that is not.'],
    { voice: 'fake-voice', onSynthesised: (r) => reports.push(r) },
  );
  assert.deepEqual(clips.map((c) => Boolean(c.clipSeconds)), [true, false]);
  assert.deepEqual(reports, [{ provider: 'fake', characters: 'One sentence spoken.'.length, sentences: 1 }]);
});

test('a film aborted during its synthesis still reports the sentences it paid for', async (t) => {
  const controller = new AbortController();
  withFakeVoice(t, { abortAfter: 1, controller });
  const reports = [];

  await assert.rejects(
    tts.speakBeats(['Paid for.', 'Never reached.'], {
      voice: 'fake-voice', signal: controller.signal, onSynthesised: (r) => reports.push(r),
    }),
    RenderAborted,
  );
  assert.deepEqual(reports, [{ provider: 'fake', characters: 'Paid for.'.length, sentences: 1 }]);
});

test('a report that throws cannot fail the film', async (t) => {
  withFakeVoice(t);
  const clips = await tts.speakBeats(['Spoken anyway.'], {
    voice: 'fake-voice', onSynthesised: () => { throw new Error('the meter is down'); },
  });
  assert.equal(clips.length, 1);
  assert.ok(clips[0].clipSeconds > 0, 'the clip exists and the film has its voice');
});

test('a spoken sample says which provider spoke it and how many characters it cost', async (t) => {
  withFakeVoice(t);
  const first = await tts.speak({ text: 'A sample sentence.', voice: 'fake-voice' });
  assert.equal(first.cached, false);
  assert.equal(first.provider, 'fake');
  assert.equal(first.characters, 'A sample sentence.'.length);

  const again = await tts.speak({ text: 'A sample sentence.', voice: 'fake-voice' });
  assert.equal(again.cached, true);
  assert.equal(again.characters, 0, 'nothing was sent the second time');
});

test('narrateFilm hands the report through to speakBeats untouched', async (t) => {
  withFakeVoice(t);
  const original = tts.speakBeats;
  const seen = [];
  tts.speakBeats = async (texts, opts) => {
    seen.push(opts);
    return texts.map(() => ({ clipSeconds: null }));
  };
  t.after(() => { tts.speakBeats = original; });
  const marker = () => {};

  const result = await narrateFilm({
    events: [{ timestampMs: 0, eventType: 'init', data: { fen: '8/8/8/8/8/8/8/8 w - - 0 1', text: 'Say this.' } }],
    voice: 'fake-voice', exportsDir: CACHE, filename: 'never-written', onSynthesised: marker,
  });

  assert.equal(seen.length, 1);
  assert.equal(seen[0].onSynthesised, marker, 'the very function the route gave');
  assert.equal(result.silentBecause, 'voice', 'and a voiceless film is still returned');
});
