// recording_transcript.test.js — speech to text on a recording made in
// Preparation. Phase 7 of docs/PLAN-PRIPREMA.md.
//
// The plan's gate, case by case: the vendor's client is faked and the
// **request** is asserted — the language, the file that was sent, and that no
// list of words to expect goes with it; a transcript whose times run
// backwards or past the end of the sound is refused; a vendor that fails is a
// sentence and the recording is as it was; a correction changes text and
// never a time. The times the rules allow are the measured ones: on every
// recording of the owner's, a sentence's end runs up to 480 ms past the next
// one's start, and one ended 60 ms after its sound.

const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { EventEmitter } = require('node:events');
const { spawnSync } = require('node:child_process');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const express = require('express');
const {
  MAX_OVERRUN_MS, TRANSCRIPT_LANGUAGES, VENDOR_LANGUAGE, applyCorrection,
  judgeSentences, latinOf, sentencesFrom,
} = require('../services/transcript');
const { TUTORIAL_LANGUAGES } = require('../services/tutorialLanguage');
const { createGroq, SttUnavailable, DEFAULT_MODEL } = require('../services/stt/groq');
const { speechToText } = require('../services/stt');
const { compressForSpeech, CompressFailed } = require('../services/stt/compress');
const { createTranscriptHandlers } = require('../routes/recordingTranscript');
const { sttSecondsMetric, STT_PROVIDERS, UNIT_COSTS } = require('../services/entitlementService');
const { PROVIDER } = require('../services/providerUsage');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const w = (text, startMs, endMs) => ({ text, startMs, endMs });
const seg = (text, startMs, endMs) => ({ text, startMs, endMs });

// ------------------------------------------------------------ sentences, R1

describe('sentences are cut from the words', () => {
  test('a segment\'s closing mark goes onto its last word, and cuts there', () => {
    const got = sentencesFrom({
      words: [w('Beli', 0, 300), w('igra', 300, 600), w('e4', 600, 900), w('Crni', 1000, 1300), w('odgovara', 1300, 1800)],
      segments: [seg('Beli igra e4.', 0, 900), seg('Crni odgovara', 1000, 1800)],
    });
    assert.deepEqual(got, [
      { startMs: 0, endMs: 900, text: 'Beli igra e4.', heard: 'Beli igra e4.' },
      { startMs: 1000, endMs: 1800, text: 'Crni odgovara', heard: 'Crni odgovara' },
    ]);
  });

  test('an ordinal is not a sentence end, a number before a capital is', () => {
    const words = [w('skakač', 0, 100), w('1.', 100, 200), w('e5,', 200, 300),
      w('lovac', 300, 400), w('c5.', 400, 500), w('Ako', 500, 600), w('želite', 600, 700)];
    const got = sentencesFrom({ words, segments: [seg('', 0, 700)] });
    assert.deepEqual(got.map((s) => s.text), ['skakač 1. e5, lovac c5.', 'Ako želite']);
  });

  test('sentences are built from the words, not from the segment text', () => {
    // The two disagree in Whisper's answers, and the words were the better
    // (2 wrong of 185 against 6 on the owner's corrected recording).
    const got = sentencesFrom({
      words: [w('može', 0, 300), w('da', 300, 500), w('odigra.', 500, 900)],
      segments: [seg('mo da odigra.', 0, 900)],
    });
    assert.equal(got[0].text, 'može da odigra.');
  });

  test('a word the vendor put before its first segment is not lost', () => {
    const got = sentencesFrom({
      words: [w('Dakle,', 0, 200), w('lovac.', 300, 600)],
      segments: [seg('lovac.', 300, 600)],
    });
    assert.deepEqual(got.map((s) => s.text), ['Dakle, lovac.']);
  });

  test('Serbian comes back in Latin, and only Serbian is turned', () => {
    const answer = { words: [w('Краљ', 0, 300), w('на', 300, 400), w('е4.', 400, 700)], segments: [] };
    assert.equal(sentencesFrom(answer, { language: 'sr-Latn' })[0].text, 'Kralj na e4.');
    assert.equal(sentencesFrom(answer, { language: 'en' })[0].text, 'Краљ на е4.');
    assert.equal(latinOf('ЉУБАВ Љубав њега'), 'LJUBAV Ljubav njega');
  });

  test('a word with no text is dropped rather than joined as a space', () => {
    const got = sentencesFrom({ words: [w('Da', 0, 100), w('  ', 100, 200), w('vidimo.', 200, 400)], segments: [] });
    assert.equal(got[0].text, 'Da vidimo.');
  });
});

// ---------------------------------------------------------- what is refused

describe('a transcript\'s times', () => {
  const s = (startMs, endMs, text = 'x.') => ({ startMs, endMs, text, heard: text });

  test('the measured untidiness is kept: an end past the next start, a last end past the sound', () => {
    const judged = judgeSentences([s(0, 3240), s(2760, 5000), s(5000, 10060)], 10000);
    assert.equal(judged.ok, true);
    assert.deepEqual(judged.sentences.map((x) => [x.startMs, x.endMs]),
      [[0, 3240], [2760, 5000], [5000, 10000]], 'the last end is brought back to the sound');
  });

  test('a start that runs backwards is refused — by one millisecond', () => {
    assert.equal(judgeSentences([s(1000, 2000), s(1000, 2500)], 5000).ok, true, 'equal starts stand');
    const judged = judgeSentences([s(1000, 2000), s(999, 2500)], 5000);
    assert.equal(judged.ok, false);
    assert.match(judged.error, /Sentence 2 starts before the one it follows/);
  });

  test('an end before its own start is refused', () => {
    assert.match(judgeSentences([s(2000, 1999)], 5000).error, /Sentence 1 ends before it starts/);
  });

  test('past the end of the sound: the tolerance stands, one millisecond more does not', () => {
    assert.equal(judgeSentences([s(0, 5000 + MAX_OVERRUN_MS)], 5000).ok, true);
    const judged = judgeSentences([s(0, 5000 + MAX_OVERRUN_MS + 1)], 5000);
    assert.equal(judged.ok, false);
    assert.match(judged.error, /runs past the end of the recording/);
  });

  test('a start past the end of the sound is refused', () => {
    assert.equal(judgeSentences([s(7000, 7000)], 5000).ok, false);
  });

  test('nothing heard, missing times, or no words are refused', () => {
    assert.match(judgeSentences([], 5000).error, /Nothing was heard/);
    assert.match(judgeSentences([{ startMs: 0, text: 'x' }], 5000).error, /without its times/);
    assert.match(judgeSentences([s(0, 10, '  ')], 5000).error, /without words/);
    assert.equal(judgeSentences([s(0, 10)], 0).ok, false);
  });
});

describe('a correction', () => {
  const stored = [
    { startMs: 480, endMs: 6300, text: 'lovat c5', heard: 'lovat c5' },
    { startMs: 7160, endMs: 9620, text: 'jedinje', heard: 'jedinje' },
  ];

  test('changes the text and never a time, and keeps what was heard', () => {
    const got = applyCorrection(stored, ['lovac c5', '  jedenje ']);
    assert.equal(got.ok, true);
    assert.deepEqual(got.sentences, [
      { startMs: 480, endMs: 6300, text: 'lovac c5', heard: 'lovat c5' },
      { startMs: 7160, endMs: 9620, text: 'jedenje', heard: 'jedinje' },
    ]);
  });

  test('a time sent with it is not read — a sentence is text or it is refused', () => {
    const got = applyCorrection(stored, [{ text: 'x', startMs: 0 }, 'y']);
    assert.equal(got.ok, false);
    assert.match(got.error, /Sentence 1 of the correction is not text/);
  });

  test('may empty a sentence the vendor invented', () => {
    assert.equal(applyCorrection(stored, ['lovac c5', '']).sentences[1].text, '');
  });

  test('must have one text per sentence', () => {
    assert.match(applyCorrection(stored, ['one']).error, /has 2 sentences, and the correction 1/);
    assert.equal(applyCorrection(stored, 'one').ok, false);
    assert.equal(applyCorrection(stored, ['x'.repeat(2001), 'y']).ok, false);
  });
});

describe('the languages offered', () => {
  test('are a tutorial\'s, less Cyrillic Serbian, each with the vendor\'s code', () => {
    assert.deepEqual(TRANSCRIPT_LANGUAGES, ['en', 'sr-Latn', 'de', 'es', 'it', 'fr']);
    for (const code of TRANSCRIPT_LANGUAGES) {
      assert.ok(TUTORIAL_LANGUAGES.includes(code), code);
      assert.equal(typeof VENDOR_LANGUAGE[code], 'string', code);
    }
    assert.equal(VENDOR_LANGUAGE['sr-Latn'], 'sr');
  });
});

describe('metering names', () => {
  test('a provider\'s seconds have their own metric and a price slot', () => {
    assert.deepEqual(STT_PROVIDERS, ['groq']);
    assert.equal(sttSecondsMetric('groq'), 'stt_groq_seconds');
    assert.equal(sttSecondsMetric('GROQ'), 'stt_groq_seconds');
    assert.throws(() => sttSecondsMetric('azure'), RangeError);
    assert.ok('stt_groq_seconds' in UNIT_COSTS);
    assert.equal(PROVIDER.GROQ_STT, 'groq_stt');
  });
});

// ------------------------------------------------------------ Groq's client

/// A fetch that remembers what it was sent and answers [reply].
function fakeFetch(reply) {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    if (reply instanceof Error) throw reply;
    if (typeof reply === 'function') return reply(options);
    return reply;
  };
  return { calls, fetchImpl };
}

const jsonReply = (status, body) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json' },
});

const GROQ_ANSWER = {
  duration: 3.2,
  text: ' Beli igra e4.',
  segments: [{ text: ' Beli igra e4.', start: 0.0, end: 1.25 }],
  words: [{ word: 'Beli', start: 0.0, end: 0.4 }, { word: 'igra', start: 0.4, end: 0.8 },
    { word: 'e4', start: 0.8, end: 1.25 }],
};

describe('Groq\'s client', () => {
  test('sends the sound, the language and the model, and no list of words to expect', async () => {
    const { calls, fetchImpl } = fakeFetch(jsonReply(200, GROQ_ANSWER));
    const client = createGroq({ apiKey: 'k-123', fetchImpl });
    const sound = Buffer.from('OggS-the-sound');
    const got = await client.transcribe({ sound, language: 'sr' });

    assert.equal(calls.length, 1);
    const { url, options } = calls[0];
    assert.equal(url, 'https://api.groq.com/openai/v1/audio/transcriptions');
    assert.equal(options.method, 'POST');
    assert.equal(options.headers.Authorization, 'Bearer k-123');
    const form = options.body;
    assert.equal(form.get('model'), DEFAULT_MODEL);
    assert.equal(DEFAULT_MODEL, 'whisper-large-v3');
    assert.equal(form.get('language'), 'sr');
    assert.equal(form.get('response_format'), 'verbose_json');
    assert.deepEqual(form.getAll('timestamp_granularities[]'), ['word', 'segment']);
    assert.equal(form.get('temperature'), '0');
    assert.equal(form.get('prompt'), null, 'no vocabulary hint: none was ever measured');
    const file = form.get('file');
    assert.equal(file.name, 'sound.ogg');
    assert.deepEqual(Buffer.from(await file.arrayBuffer()), sound, 'the file sent is the compressed sound');

    assert.equal(got.model, 'whisper-large-v3');
    assert.equal(got.durationMs, 3200);
    assert.deepEqual(got.words[2], { text: 'e4', startMs: 800, endMs: 1250 });
    assert.deepEqual(got.segments[0], { text: ' Beli igra e4.', startMs: 0, endMs: 1250 });
  });

  test('an unconfigured client never calls out', async () => {
    const { calls, fetchImpl } = fakeFetch(jsonReply(200, GROQ_ANSWER));
    const client = createGroq({ apiKey: '  ', fetchImpl });
    assert.equal(client.configured(), false);
    await assert.rejects(client.transcribe({ sound: Buffer.alloc(1), language: 'sr' }),
      (e) => e instanceof SttUnavailable && e.reason === 'not-configured');
    assert.equal(calls.length, 0);
  });

  for (const [status, reason, code] of [[401, 'key', 503], [413, 'too-large', 413], [429, 'busy', 503], [500, 'refused', 502]]) {
    test(`an answer of ${status} is a reason, not a stack`, async () => {
      const { fetchImpl } = fakeFetch(jsonReply(status, { error: { message: 'secret detail' } }));
      await assert.rejects(createGroq({ apiKey: 'k', fetchImpl }).transcribe({ sound: Buffer.alloc(1), language: 'en' }),
        (e) => e instanceof SttUnavailable && e.reason === reason && e.status === code
          && !/secret detail|Bearer/.test(e.message));
    });
  }

  test('an answer without word times is refused', async () => {
    const { fetchImpl } = fakeFetch(jsonReply(200, { text: 'x', segments: [] }));
    await assert.rejects(createGroq({ apiKey: 'k', fetchImpl }).transcribe({ sound: Buffer.alloc(1), language: 'en' }),
      (e) => e.reason === 'malformed');
  });

  test('a network failure and a service that never answers are each said', async () => {
    const down = fakeFetch(new TypeError('fetch failed'));
    await assert.rejects(createGroq({ apiKey: 'k', fetchImpl: down.fetchImpl })
      .transcribe({ sound: Buffer.alloc(1), language: 'en' }), (e) => e.reason === 'network');

    const silent = fakeFetch((options) => new Promise((_, reject) => {
      options.signal.addEventListener('abort', () => {
        const err = new Error('aborted');
        err.name = 'AbortError';
        reject(err);
      });
    }));
    await assert.rejects(createGroq({ apiKey: 'k', fetchImpl: silent.fetchImpl, timeoutMs: 20 })
      .transcribe({ sound: Buffer.alloc(1), language: 'en' }), (e) => e.reason === 'timeout');
  });

  test('the switch offers nothing unless a provider is named and has a key', () => {
    const saved = { p: process.env.STT_PROVIDER, k: process.env.GROQ_API_KEY };
    try {
      delete process.env.STT_PROVIDER;
      process.env.GROQ_API_KEY = 'k';
      assert.equal(speechToText(), null, 'no provider named');
      process.env.STT_PROVIDER = 'azure';
      assert.equal(speechToText(), null, 'not a provider that hears');
      process.env.STT_PROVIDER = 'groq';
      process.env.GROQ_API_KEY = '';
      assert.equal(speechToText(), null, 'no key');
      process.env.GROQ_API_KEY = 'k';
      assert.equal(speechToText().name, 'groq');
    } finally {
      if (saved.p === undefined) delete process.env.STT_PROVIDER; else process.env.STT_PROVIDER = saved.p;
      if (saved.k === undefined) delete process.env.GROQ_API_KEY; else process.env.GROQ_API_KEY = saved.k;
    }
  });
});

// -------------------------------------------------------------- compression

function fakeSpawn({ out = [Buffer.from('OggS')], code = 0, stderr = '' } = {}) {
  const calls = [];
  const spawnImpl = (cmd, args, options) => {
    calls.push({ cmd, args, options });
    const proc = new EventEmitter();
    proc.stdout = new EventEmitter();
    proc.stderr = new EventEmitter();
    proc.killed = null;
    proc.kill = (signal) => { proc.killed = signal; };
    setImmediate(() => {
      for (const chunk of out) proc.stdout.emit('data', chunk);
      if (stderr) proc.stderr.emit('data', Buffer.from(stderr));
      proc.emit('close', proc.killed ? null : code);
    });
    return proc;
  };
  return { calls, spawnImpl };
}

function wavFile(dir, ms = 1500) {
  const rate = 16000;
  const data = Buffer.alloc(Math.floor(ms * rate / 1000) * 2);
  for (let i = 0; i < data.length; i += 2) data.writeInt16LE(Math.round(8000 * Math.sin(i / 20)), i);
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVEfmt ', 8, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(data.length, 40);
  const file = path.join(dir, 'lesson_1_abc.wav');
  fs.writeFileSync(file, Buffer.concat([header, data]));
  return file;
}

const hasFfmpeg = spawnSync('ffmpeg', ['-version']).status === 0;

describe('compression', () => {
  test('reads the recording and writes Opus to its own output, nowhere else', async () => {
    const { calls, spawnImpl } = fakeSpawn({ out: [Buffer.from('OggS'), Buffer.from('-rest')] });
    const got = await compressForSpeech('/x/lesson.wav', { spawnImpl });
    assert.deepEqual(got, Buffer.from('OggS-rest'));
    const args = calls[0].args;
    assert.equal(args[args.indexOf('-i') + 1], '/x/lesson.wav');
    assert.equal(args[args.length - 1], 'pipe:1', 'the output is a pipe, not a file');
    assert.equal(args[args.indexOf('-c:a') + 1], 'libopus');
    assert.equal(args[args.indexOf('-b:a') + 1], '32k');
    assert.ok(!args.includes('-y'), 'nothing is overwritten');
  });

  test('a failing ffmpeg and an output past the cap are refusals', async () => {
    await assert.rejects(compressForSpeech('/x', { spawnImpl: fakeSpawn({ code: 1, stderr: 'bad' }).spawnImpl }),
      (e) => e instanceof CompressFailed && /exited 1: bad/.test(e.message));
    await assert.rejects(compressForSpeech('/x', { spawnImpl: fakeSpawn({ out: [] }).spawnImpl }),
      (e) => e instanceof CompressFailed && /wrote nothing/.test(e.message));
    const big = fakeSpawn({ out: [Buffer.alloc(6), Buffer.alloc(6)] });
    await assert.rejects(compressForSpeech('/x', { spawnImpl: big.spawnImpl, maxBytes: 10 }),
      (e) => e instanceof CompressFailed && /passed 10 bytes/.test(e.message));
  });

  test('with the real ffmpeg: Ogg out, the recording byte for byte as it was, no file beside it',
    { skip: hasFfmpeg ? false : 'ffmpeg is not installed on this machine' }, async () => {
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'stt-compress-'));
      try {
        const file = wavFile(dir);
        const before = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
        const out = await compressForSpeech(file);
        assert.equal(out.subarray(0, 4).toString('ascii'), 'OggS');
        assert.ok(out.length < fs.statSync(file).size / 4, 'smaller than a quarter of the wav');
        assert.equal(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'), before);
        assert.deepEqual(fs.readdirSync(dir), ['lesson_1_abc.wav']);
      } finally {
        fs.rmSync(dir, { recursive: true, force: true });
      }
    });
});

// ------------------------------------------------------------------ routes

/// A pool that answers by the question it is asked, and holds the host to the
/// parameters: a stub that answered in order could see a question asked, and
/// not which one.
function fakePool({ recordings, transcripts = new Map() }) {
  const queries = [];
  const pool = {
    transcripts,
    queries,
    async query(text, params) {
      queries.push({ text, params });
      if (/FROM session_recordings\s+WHERE id = \$1 AND host_id = \$2/.test(text)) {
        const row = recordings.find((r) => r.id === params[0] && r.host_id === params[1]);
        return { rows: row ? [{ id: row.id, source: row.source, audio_file: row.audio_file, duration_ms: row.duration_ms }] : [] };
      }
      if (/SELECT \* FROM recording_transcripts WHERE recording_id = \$1/.test(text)) {
        const t = transcripts.get(params[0]);
        return { rows: t ? [structuredClone(t)] : [] };
      }
      if (/INSERT INTO recording_transcripts/.test(text)) {
        const [recordingId, language, vendor, model, durationMs, sentences, words] = params;
        const row = {
          recording_id: recordingId, language, vendor, model, duration_ms: durationMs,
          sentences: JSON.parse(sentences), words: JSON.parse(words), updated_at: 'now',
        };
        transcripts.set(recordingId, row);
        return { rows: [structuredClone(row)] };
      }
      if (/UPDATE recording_transcripts\s+SET sentences = \$2/.test(text)) {
        const row = transcripts.get(params[0]);
        if (!row) return { rows: [] };
        row.sentences = JSON.parse(params[1]);
        return { rows: [structuredClone(row)] };
      }
      throw new Error(`unexpected query: ${text}`);
    },
  };
  return pool;
}

const HOST = 7;
const OTHER = 8;
const PREP = { id: 1, host_id: HOST, source: 'preparation', audio_file: 'lesson_7_a.wav', duration_ms: 10000 };
const ROOM = { id: 2, host_id: HOST, source: 'room', audio_file: null, duration_ms: 10000 };

const VENDOR_ANSWER = {
  model: 'whisper-large-v3',
  durationMs: 10000,
  words: [w('Краљ', 0, 400), w('на', 400, 600), w('е4.', 600, 1000), w('Dobro', 900, 1300), w('je.', 1300, 10060)],
  segments: [seg('Краљ на е4.', 0, 1000), seg('Dobro je.', 900, 10060)],
};

/// A fake vendor that remembers what it was asked.
function fakeStt(answer = VENDOR_ANSWER) {
  const asked = [];
  return {
    asked,
    client: {
      name: 'groq',
      async transcribe(request) {
        asked.push(request);
        if (typeof answer === 'function') return answer(request);
        if (answer instanceof Error) throw answer;
        return structuredClone(answer);
      },
    },
  };
}

function appWith({ pool, vendor, stt, compress, soundExists = true, user = HOST } = {}) {
  const recorded = [];
  const counted = [];
  const compressed = [];
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'stt-route-'));
  const handlers = createTranscriptHandlers({
    pool,
    stt: stt || (() => vendor.client),
    compress: compress || (async (file) => { compressed.push(file); return Buffer.from('OggS-opus'); }),
    soundOf: (row) => {
      const file = path.join(dir, row.audio_file);
      if (soundExists) fs.writeFileSync(file, 'wav');
      return file;
    },
    record: (userId, metric, amount) => { recorded.push({ userId, metric, amount }); },
    countRequest: (provider) => { counted.push(provider); },
  });
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.user = { id: user }; next(); });
  app.get('/recordings/:id/transcript', handlers.read);
  app.post('/recordings/:id/transcript', handlers.transcribe);
  app.put('/recordings/:id/transcript', handlers.correct);
  return { app, recorded, counted, compressed, dir };
}

async function call(app, method, url, body) {
  const server = app.listen(0);
  try {
    const port = server.address().port;
    const res = await fetch(`http://127.0.0.1:${port}${url}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

describe('POST /recordings/:id/transcript', () => {
  test('hears the host\'s Preparation recording, in Latin, and keeps it', async () => {
    const pool = fakePool({ recordings: [PREP, ROOM] });
    const vendor = fakeStt();
    const { app, compressed, dir } = appWith({ pool, vendor });
    const res = await call(app, 'POST', '/recordings/1/transcript', { language: 'sr-Latn' });

    assert.equal(res.status, 201);
    assert.equal(vendor.asked.length, 1);
    assert.equal(vendor.asked[0].language, 'sr', 'the vendor\'s code, not the tutorial\'s');
    assert.deepEqual(vendor.asked[0].sound, Buffer.from('OggS-opus'), 'the compressed sound is what is sent');
    assert.deepEqual(compressed, [path.join(dir, 'lesson_7_a.wav')], 'the recording\'s own sound');

    const t = res.body.transcript;
    assert.equal(t.language, 'sr-Latn');
    assert.equal(t.vendor, 'groq');
    assert.equal(t.model, 'whisper-large-v3');
    assert.deepEqual(t.sentences, [
      { startMs: 0, endMs: 1000, text: 'Kralj na e4.', heard: 'Kralj na e4.' },
      { startMs: 900, endMs: 10000, text: 'Dobro je.', heard: 'Dobro je.' },
    ]);
    assert.equal(pool.transcripts.get(1).words.length, 5, 'every word as heard is kept');
    assert.equal(pool.transcripts.get(1).words[0].text, 'Краљ', 'as heard, not as turned');
  });

  test('counts the recording\'s seconds against the account and the provider\'s day', async () => {
    const pool = fakePool({ recordings: [{ ...PREP, duration_ms: 10001 }] });
    const { app, recorded, counted } = appWith({ pool, vendor: fakeStt({ ...VENDOR_ANSWER, words: VENDOR_ANSWER.words.slice(0, 3), segments: [] }) });
    assert.equal((await call(app, 'POST', '/recordings/1/transcript', { language: 'en' })).status, 201);
    assert.deepEqual(recorded, [{ userId: HOST, metric: 'stt_groq_seconds', amount: 11 }], 'rounded up');
    assert.deepEqual(counted, ['groq_stt']);
  });

  test('a vendor that fails is a sentence, is still counted, and the transcript is as it was', async () => {
    const before = { recording_id: 1, language: 'sr-Latn', vendor: 'groq', model: 'm', duration_ms: 10000,
      sentences: [{ startMs: 0, endMs: 1000, text: 'corrected by hand', heard: 'heard' }], words: [], updated_at: 'then' };
    const pool = fakePool({ recordings: [PREP], transcripts: new Map([[1, structuredClone(before)]]) });
    const vendor = fakeStt(new SttUnavailable('The speech service is busy. Try again in a minute.', { reason: 'busy' }));
    const { app, recorded, counted } = appWith({ pool, vendor });
    const res = await call(app, 'POST', '/recordings/1/transcript', { language: 'sr-Latn' });

    assert.equal(res.status, 503);
    assert.deepEqual(res.body, { error: 'The speech service is busy. Try again in a minute.', reason: 'busy' });
    assert.deepEqual(pool.transcripts.get(1), before);
    assert.equal(recorded.length, 1, 'the vendor bills the attempt');
    assert.deepEqual(counted, ['groq_stt']);
  });

  test('an answer whose times cannot be a recording is refused, and nothing is kept', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const vendor = fakeStt({ ...VENDOR_ANSWER, words: [w('Past', 0, 400), w('the end.', 400, 10000 + MAX_OVERRUN_MS + 1)], segments: [] });
    const { app, recorded } = appWith({ pool, vendor });
    const res = await call(app, 'POST', '/recordings/1/transcript', { language: 'en' });
    assert.equal(res.status, 422);
    assert.match(res.body.error, /cannot be used: Sentence 1 runs past the end of the recording/);
    assert.equal(pool.transcripts.size, 0);
    assert.equal(recorded.length, 1, 'a refused answer was still paid for');
  });

  test('an answer whose sentences run backwards is refused', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const vendor = fakeStt({ ...VENDOR_ANSWER, words: [w('One.', 500, 900), w('Two.', 499, 950)], segments: [] });
    const res = await call(appWith({ pool, vendor }).app, 'POST', '/recordings/1/transcript', { language: 'en' });
    assert.equal(res.status, 422);
    assert.match(res.body.error, /starts before the one it follows/);
    assert.equal(pool.transcripts.size, 0);
  });

  test('another account reads not found, and nobody is asked anything', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const vendor = fakeStt();
    const { app, compressed, recorded } = appWith({ pool, vendor, user: OTHER });
    for (const [method, body] of [['GET'], ['POST', { language: 'en' }], ['PUT', { texts: [] }]]) {
      const res = await call(app, method, '/recordings/1/transcript', body);
      assert.equal(res.status, 404, method);
      assert.deepEqual(res.body, { error: 'Recording not found.' }, method);
    }
    assert.equal(vendor.asked.length, 0);
    assert.equal(compressed.length, 0);
    assert.equal(recorded.length, 0);
  });

  test('a room recording is not transcribed', async () => {
    const pool = fakePool({ recordings: [ROOM] });
    const vendor = fakeStt();
    const res = await call(appWith({ pool, vendor }).app, 'POST', '/recordings/2/transcript', { language: 'en' });
    assert.equal(res.status, 400);
    assert.match(res.body.error, /Only a lesson recorded in Preparation/);
    assert.equal(vendor.asked.length, 0);
  });

  test('Cyrillic Serbian and an unknown language are refused before anything is read', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const vendor = fakeStt();
    for (const language of ['sr-Cyrl', 'sr', undefined]) {
      const res = await call(appWith({ pool, vendor }).app, 'POST', '/recordings/1/transcript', { language });
      assert.equal(res.status, 400, String(language));
    }
    assert.equal(vendor.asked.length, 0);
    assert.equal(pool.queries.length, 0);
  });

  test('a server with no provider says so', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const res = await call(appWith({ pool, stt: () => null }).app, 'POST', '/recordings/1/transcript', { language: 'en' });
    assert.equal(res.status, 503);
    assert.match(res.body.error, /not configured/);
  });

  test('a missing sound is said, and not sent', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const vendor = fakeStt();
    const res = await call(appWith({ pool, vendor, soundExists: false }).app, 'POST', '/recordings/1/transcript', { language: 'en' });
    assert.equal(res.status, 404);
    assert.match(res.body.error, /sound is missing/);
    assert.equal(vendor.asked.length, 0);
  });

  test('a compression that fails is said, and nothing is sent', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const vendor = fakeStt();
    const { app, recorded } = appWith({ pool, vendor, compress: async () => { throw new CompressFailed('no'); } });
    const res = await call(app, 'POST', '/recordings/1/transcript', { language: 'en' });
    assert.equal(res.status, 500);
    assert.match(res.body.error, /could not be prepared/);
    assert.equal(vendor.asked.length, 0);
    assert.equal(recorded.length, 0, 'nothing reached the vendor, nothing is counted');
  });

  test('a second request while the first is with the vendor is refused, and the vendor is asked once', async () => {
    const pool = fakePool({ recordings: [PREP] });
    let release;
    const gate = new Promise((resolve) => { release = resolve; });
    const vendor = fakeStt(async () => { await gate; return structuredClone(VENDOR_ANSWER); });
    const { app } = appWith({ pool, vendor });
    const server = app.listen(0);
    try {
      const url = `http://127.0.0.1:${server.address().port}/recordings/1/transcript`;
      const post = () => fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ language: 'en' }) });
      const first = post();
      const deadline = Date.now() + 2000;
      while (vendor.asked.length === 0 && Date.now() < deadline) {
        await new Promise((r) => setTimeout(r, 5));
      }
      assert.equal(vendor.asked.length, 1, 'the first request reached the vendor');
      // Raced against a deadline: without the lock the second request waits
      // on the same held vendor, and a hang is not a failure anybody reads.
      let timer;
      const second = await Promise.race([
        post(),
        new Promise((resolve) => { timer = setTimeout(() => resolve(null), 2000); }),
      ]);
      clearTimeout(timer);
      assert.notEqual(second, null, 'the second request went to the vendor and waited there');
      assert.equal(second.status, 409);
      release();
      assert.equal((await first).status, 201);
      assert.equal(vendor.asked.length, 1);
      assert.equal((await post()).status, 201, 'the lock is let go when the first is done');
    } finally {
      release();
      await new Promise((resolve) => server.close(resolve));
    }
  });
});

describe('GET /recordings/:id/transcript', () => {
  test('says whether „Transcribe" is offered, in which languages, and what was heard', async () => {
    const pool = fakePool({ recordings: [PREP, ROOM] });
    const vendor = fakeStt();
    const { app } = appWith({ pool, vendor });
    const none = await call(app, 'GET', '/recordings/1/transcript');
    assert.deepEqual(none.body, { available: true, languages: TRANSCRIPT_LANGUAGES, transcript: null });
    await call(app, 'POST', '/recordings/1/transcript', { language: 'en' });
    const heard = await call(app, 'GET', '/recordings/1/transcript');
    assert.equal(heard.body.transcript.sentences.length, 2);
    assert.equal(heard.body.transcript.words, undefined, 'the app is handed the sentences, not every word');

    assert.equal((await call(app, 'GET', '/recordings/2/transcript')).body.available, false, 'a room recording');
    // A provider switched off offers nothing new, and what was heard before
    // is still the trainer's to read and correct.
    const off = await call(appWith({ pool, stt: () => null }).app, 'GET', '/recordings/1/transcript');
    assert.equal(off.body.available, false);
    assert.deepEqual(off.body.languages, []);
    assert.equal(off.body.transcript.sentences.length, 2);
  });
});

describe('PUT /recordings/:id/transcript', () => {
  test('a correction changes text and never a time, and keeps the words as heard', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const { app } = appWith({ pool, vendor: fakeStt() });
    await call(app, 'POST', '/recordings/1/transcript', { language: 'sr-Latn' });
    const words = structuredClone(pool.transcripts.get(1).words);

    const res = await call(app, 'PUT', '/recordings/1/transcript',
      { texts: ['Kralj na e4, kaže se.', 'Dobro je.'], sentences: [{ startMs: 5, endMs: 6 }] });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.transcript.sentences, [
      { startMs: 0, endMs: 1000, text: 'Kralj na e4, kaže se.', heard: 'Kralj na e4.' },
      { startMs: 900, endMs: 10000, text: 'Dobro je.', heard: 'Dobro je.' },
    ]);
    assert.deepEqual(pool.transcripts.get(1).words, words);
  });

  test('a correction of the wrong length, or of a recording never heard, is refused', async () => {
    const pool = fakePool({ recordings: [PREP] });
    const { app } = appWith({ pool, vendor: fakeStt() });
    assert.equal((await call(app, 'PUT', '/recordings/1/transcript', { texts: ['x'] })).status, 404);
    await call(app, 'POST', '/recordings/1/transcript', { language: 'en' });
    const res = await call(app, 'PUT', '/recordings/1/transcript', { texts: ['only one'] });
    assert.equal(res.status, 400);
    assert.match(res.body.error, /has 2 sentences, and the correction 1/);
  });
});

// ------------------------------------------------------ on a real database

const skip = skipUnlessDatabase();

describe('the transcripts table on a real database', { skip: skip ? skip.skip : false }, () => {
  test('initDB makes it, a transcript is kept and corrected, and goes with its recording', async () => {
    const testDb = await freshDatabase();
    try {
      const { pool } = testDb;
      const store = require('../services/recordingTranscripts');
      const user = await pool.query(
        "INSERT INTO users (email, password_hash, name) VALUES ('stt@example.test', 'x', 'T') RETURNING id");
      const hostId = user.rows[0].id;
      const rec = await pool.query(
        `INSERT INTO session_recordings
           (room_id, source, host_id, title, audio_file, duration_ms, timeline_json, participants)
         VALUES (NULL, 'preparation', $1, 'x', 'lesson_1_a.wav', 10000, '[]', '{}') RETURNING id`, [hostId]);
      const id = rec.rows[0].id;

      assert.equal(await store.hostRecording(pool, id, hostId + 1), null, 'not the host');
      const row = await store.hostRecording(pool, id, hostId);
      assert.equal(store.transcribable(row), true);

      const sentences = [{ startMs: 0, endMs: 900, text: 'A.', heard: 'A.' }];
      await store.saveTranscript(pool, { recordingId: id, language: 'en', vendor: 'groq', model: 'm',
        durationMs: 10000, sentences, words: [{ text: 'A.', startMs: 0, endMs: 900 }] });
      await store.saveSentences(pool, id, [{ ...sentences[0], text: 'B.' }]);
      const kept = await store.readTranscript(pool, id);
      assert.deepEqual(kept.sentences, [{ startMs: 0, endMs: 900, text: 'B.', heard: 'A.' }]);
      assert.deepEqual(kept.words, [{ text: 'A.', startMs: 0, endMs: 900 }]);

      await store.saveTranscript(pool, { recordingId: id, language: 'sr-Latn', vendor: 'groq', model: 'm',
        durationMs: 10000, sentences, words: [] });
      assert.equal((await pool.query('SELECT COUNT(*)::int AS n FROM recording_transcripts')).rows[0].n, 1,
        'hearing it again replaces, it does not add');

      await pool.query('DELETE FROM session_recordings WHERE id = $1', [id]);
      assert.equal(await store.readTranscript(pool, id), null);
    } finally {
      await testDb.drop();
    }
  });
});
