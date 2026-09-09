// tutorial_video_export.test.js
// Tests for POST /lessons/:id/export-video
//
// Gates:
// 1. no entitlement → refused, and the renderer is never called;
// 2. somebody else's tutorial → 404, and the query carries the user;
// 3. empty `events` → 400, nothing written to `exports/`;
// 4. `seconds` over 3600 → clamped, not refused;
// 5. metering booked after a successful render, and not after a failed one;
// 6. the answer carries a `downloadUrl` naming the file that was written.
//
// Fakes the renderer. Does not spawn ffmpeg.

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const videoRenderer = require('../videoRenderer');
const tts = require('../services/tts');
const tutorialNarration = require('../services/tutorialNarration');
const { METRIC } = require('../services/entitlementService');

const VALID_EVENTS = [
  {
    timestampMs: 0,
    eventType: 'init',
    data: { fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' },
  },
  {
    timestampMs: 2000,
    eventType: 'move',
    data: { fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1', san: 'e4', from: 'e2', to: 'e4' },
  },
];

function getRouteStack() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/export-video' && l.route.methods.post
  );
  assert.ok(layer, 'POST /lessons/:id/export-video must be mounted');
  return layer.route.stack.map((s) => s.handle);
}

async function run({
  params = { id: '15' },
  body = {
    events: VALID_EVENTS,
    seconds: 4,
    title: 'Slaba polja u centru',
    resolution: '720p',
    boardTheme: 'wood',
  },
  userId = 4,
  tier = 'premium',
  lesson = { id: 15, title: 'Slaba polja u centru' },
  renderError = null,
  narrateResult = null,
  narrateError = null,
} = {}) {
  const queries = [];
  const originalQuery = db.pool.query;
  const originalRender = videoRenderer.renderRecordingToMP4;
  const originalNarrateFilm = tutorialNarration.narrateFilm;

  const renderCalls = [];
  const narrateCalls = [];

  videoRenderer.renderRecordingToMP4 = async (opts) => {
    renderCalls.push(opts);
    if (renderError) throw renderError;
    return opts.outputPath;
  };

  tutorialNarration.narrateFilm = async (opts) => {
    narrateCalls.push(opts);
    if (narrateError) throw narrateError;
    if (narrateResult) return narrateResult;
    return {
      events: opts.events,
      audioPath: null,
      seconds: null,
      spokenBeats: 0,
    };
  };

  db.pool.query = async (text, values) => {
    queries.push({ text, values });
    if (/SELECT account_type FROM users/i.test(text)) {
      return { rows: [{ account_type: tier }], rowCount: 1 };
    }
    if (/SELECT tier, status/i.test(text)) {
      return { rows: [], rowCount: 0 };
    }
    if (/SELECT id, title FROM saved_lessons/i.test(text)) {
      return { rows: lesson ? [lesson] : [], rowCount: lesson ? 1 : 0 };
    }
    if (/INSERT INTO usage_counters/i.test(text)) {
      return { rows: [{ used: values[3] }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };

  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };

  const req = {
    params,
    body,
    user: { id: userId, role: 'trener' },
  };

  const handlers = getRouteStack();
  assert.equal(handlers.length, 3, 'route must have authenticateToken, requireEntitlement, and handler');

  let nextCalled = false;
  let finishHandler;
  const handlerFinished = new Promise((resolve, reject) => {
    finishHandler = { resolve, reject };
  });

  try {
    // Run requireEntitlement (handlers[1]) followed by route handler (handlers[2])
    await handlers[1](req, res, async () => {
      nextCalled = true;
      try {
        await handlers[2](req, res);
        finishHandler.resolve();
      } catch (err) {
        finishHandler.reject(err);
      }
    });
    if (nextCalled) {
      await handlerFinished;
    }
  } finally {
    db.pool.query = originalQuery;
    videoRenderer.renderRecordingToMP4 = originalRender;
    tutorialNarration.narrateFilm = originalNarrateFilm;
  }

  return { res, queries, renderCalls, narrateCalls };
}

function getVoicesRouteStack() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/tts/voices' && l.route.methods.get
  );
  assert.ok(layer, 'GET /lessons/tts/voices must be mounted');
  return layer.route.stack.map((s) => s.handle);
}

async function runVoices({
  userId = 4,
  available = false,
  voicesList = [],
} = {}) {
  const originalAvailable = tts.narrationAvailable;
  const originalVoices = tts.voices;

  tts.narrationAvailable = () => available;
  tts.voices = async () => voicesList;

  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };

  const req = {
    user: { id: userId, role: 'trener' },
  };

  const handlers = getVoicesRouteStack();

  try {
    await handlers[1](req, res);
  } finally {
    tts.narrationAvailable = originalAvailable;
    tts.voices = originalVoices;
  }

  return { res };
}

test('1. no entitlement -> refused, and the renderer is never called', async () => {
  const { res, renderCalls } = await run({ tier: 'free' });

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.upgradeRequired, true);
  assert.equal(renderCalls.length, 0, 'renderer must not be called when user has no entitlement');
});

test('2. somebody else\'s tutorial -> 404, and the query carries the user', async () => {
  const { res, queries, renderCalls } = await run({
    params: { id: '999' },
    userId: 5,
    lesson: null,
  });

  assert.equal(res.statusCode, 404);
  assert.equal(renderCalls.length, 0);

  const lessonQuery = queries.find((q) => /FROM saved_lessons/i.test(q.text));
  assert.ok(lessonQuery, 'must query saved_lessons');
  assert.match(lessonQuery.text, /user_id\s*=\s*\$2\s*OR\s*trainer_id\s*=\s*\$2/i);
  assert.deepEqual(lessonQuery.values, ['999', 5], 'query must carry id and user');
});

test('3. empty events -> 400, nothing written to exports/', async () => {
  const exportsDir = path.join(__dirname, '..', 'exports');
  const filesBefore = fs.existsSync(exportsDir) ? fs.readdirSync(exportsDir) : [];

  const { res, renderCalls } = await run({
    body: {
      events: [],
      seconds: 10,
    },
  });

  assert.equal(res.statusCode, 400);
  assert.equal(renderCalls.length, 0);

  const filesAfter = fs.existsSync(exportsDir) ? fs.readdirSync(exportsDir) : [];
  assert.equal(filesAfter.length, filesBefore.length, 'nothing must be written to exports directory');
});

test('4. seconds over 3600 -> clamped, not refused', async () => {
  const { res, renderCalls, queries } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 5000,
    },
  });

  assert.equal(res.statusCode, 200);
  assert.equal(renderCalls.length, 1);
  assert.equal(renderCalls[0].durationSeconds, 3600, 'duration must be clamped to 3600');

  const meterQuery = queries.find((q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDER_SECONDS);
  assert.ok(meterQuery);
  assert.equal(meterQuery.values[3], 3600, 'booked seconds must also be clamped to 3600');
});

test('5. metering booked after a successful render, and not after a failed one', async () => {
  // Successful render
  const success = await run();
  assert.equal(success.res.statusCode, 200);

  const renderCounter = success.queries.find(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDERS
  );
  const secondsCounter = success.queries.find(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDER_SECONDS
  );
  assert.ok(renderCounter, 'must book MP4_RENDERS on success');
  assert.ok(secondsCounter, 'must book MP4_RENDER_SECONDS on success');

  // Failed render
  const failed = await run({
    renderError: new Error('Render process crashed'),
  });
  assert.equal(failed.res.statusCode, 500);

  const failedRenders = failed.queries.filter((q) => /INSERT INTO usage_counters/i.test(q.text));
  assert.equal(failedRenders.length, 0, 'must NOT book metering when render fails');
});

test('6. the answer carries a downloadUrl naming the file that was written', async () => {
  const { res, renderCalls } = await run();

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.filename, 'answer must include filename');
  assert.ok(res.body.downloadUrl, 'answer must include downloadUrl');
  assert.equal(renderCalls.length, 1);

  const writtenFilename = path.basename(renderCalls[0].outputPath);
  assert.equal(res.body.filename, writtenFilename);
  assert.ok(
    res.body.downloadUrl.includes(`/recordings/export-download/${encodeURIComponent(writtenFilename)}`),
    'downloadUrl must name the written file'
  );
  assert.ok(res.body.downloadUrl.includes('token='), 'downloadUrl must carry a token');
});

test('7. narrate absent or false -> the narration door is never opened', async () => {
  // Case A: absent
  const resAbsent = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 4,
    },
  });
  assert.equal(resAbsent.res.statusCode, 200);
  assert.equal(resAbsent.narrateCalls.length, 0, 'narrateFilm must NOT be called when narrate is absent');
  assert.equal(resAbsent.renderCalls.length, 1);
  assert.equal(resAbsent.renderCalls[0].audioFilePath, null);
  assert.deepEqual(resAbsent.renderCalls[0].timelineEvents, VALID_EVENTS);
  assert.equal(resAbsent.renderCalls[0].durationSeconds, 4);

  // Case B: false
  const resFalse = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 4,
      narrate: false,
    },
  });
  assert.equal(resFalse.res.statusCode, 200);
  assert.equal(resFalse.narrateCalls.length, 0, 'narrateFilm must NOT be called when narrate is false');
  assert.equal(resFalse.renderCalls.length, 1);
  assert.equal(resFalse.renderCalls[0].audioFilePath, null);
  assert.deepEqual(resFalse.renderCalls[0].timelineEvents, VALID_EVENTS);
  assert.equal(resFalse.renderCalls[0].durationSeconds, 4);
});

test('8. narrate: true -> the render gets narrated.events, narrated.seconds and narrated.audioPath', async () => {
  const retimedEvents = [
    ...VALID_EVENTS,
    { timestampMs: 5000, eventType: 'caption', data: { text: 'Odlično' } },
  ];
  const fakeAudioPath = path.join(__dirname, '..', 'exports', 'fake.wav');

  const { res, renderCalls, narrateCalls } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 4,
      narrate: true,
      voice: 'sr-RS-Standard-B',
    },
    narrateResult: {
      events: retimedEvents,
      seconds: 14,
      audioPath: fakeAudioPath,
      spokenBeats: 1,
    },
  });

  assert.equal(res.statusCode, 200);
  assert.equal(narrateCalls.length, 1, 'narrateFilm must be called once');
  assert.equal(narrateCalls[0].voice, 'sr-RS-Standard-B');
  assert.deepEqual(narrateCalls[0].events, VALID_EVENTS);

  assert.equal(renderCalls.length, 1);
  assert.deepEqual(renderCalls[0].timelineEvents, retimedEvents);
  assert.equal(renderCalls[0].durationSeconds, 14);
  assert.equal(renderCalls[0].audioFilePath, fakeAudioPath);
});

test('9. metering books the rendered duration, not the requested one', async () => {
  const { res, queries } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 6,
      narrate: true,
    },
    narrateResult: {
      events: VALID_EVENTS,
      seconds: 24,
      audioPath: null,
      spokenBeats: 1,
    },
  });

  assert.equal(res.statusCode, 200);
  const secondsCounter = queries.find(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDER_SECONDS
  );
  assert.ok(secondsCounter, 'must book MP4_RENDER_SECONDS');
  assert.equal(secondsCounter.values[3], 24, 'metering must book 24 seconds, not the requested 6 seconds');
});

test('10. the narration wav is deleted after the render, and the mp4 is not', async () => {
  const exportsDir = path.join(__dirname, '..', 'exports');
  if (!fs.existsSync(exportsDir)) {
    fs.mkdirSync(exportsDir, { recursive: true });
  }
  const dummyWav = path.join(exportsDir, 'test-narration-cleanup.wav');
  fs.writeFileSync(dummyWav, 'dummy audio data');

  const dummyMp4 = path.join(exportsDir, 'test-output.mp4');
  fs.writeFileSync(dummyMp4, 'dummy mp4 data');

  try {
    const { res } = await run({
      body: {
        events: VALID_EVENTS,
        seconds: 4,
        narrate: true,
      },
      narrateResult: {
        events: VALID_EVENTS,
        audioPath: dummyWav,
        seconds: 10,
        spokenBeats: 1,
      },
    });

    assert.equal(res.statusCode, 200);
    assert.equal(fs.existsSync(dummyWav), false, 'wav file must be deleted');
    assert.equal(fs.existsSync(dummyMp4), true, 'mp4 file must not be deleted');
  } finally {
    if (fs.existsSync(dummyWav)) fs.unlinkSync(dummyWav);
    if (fs.existsSync(dummyMp4)) fs.unlinkSync(dummyMp4);
  }
});

test('11. narration that returns audioPath: null still answers 200 with a video', async () => {
  const { res, renderCalls, narrateCalls } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 4,
      narrate: true,
    },
    narrateResult: {
      events: VALID_EVENTS,
      seconds: 4,
      audioPath: null,
      spokenBeats: 0,
    },
  });

  assert.equal(res.statusCode, 200);
  assert.equal(narrateCalls.length, 1);
  assert.equal(renderCalls.length, 1);
  assert.equal(renderCalls[0].audioFilePath, null);
  assert.ok(res.body.downloadUrl);
  assert.ok(res.body.filename);
});

test('12. GET /lessons/tts/voices answers {available:false, voices:[]} when the provider is off, and resolves before GET /lessons/:id', async () => {
  const off = await runVoices({ available: false, voicesList: [] });
  assert.equal(off.res.statusCode, 200);
  assert.deepEqual(off.res.body, { available: false, voices: [] });

  const on = await runVoices({
    available: true,
    voicesList: [{ id: 'sr-RS-Standard-A', name: 'Standard A' }],
  });
  assert.equal(on.res.statusCode, 200);
  assert.deepEqual(on.res.body, {
    available: true,
    voices: [{ id: 'sr-RS-Standard-A', name: 'Standard A' }],
  });

  const voicesIndex = lessonsRouter.stack.findIndex(
    (l) => l.route && l.route.path === '/tts/voices'
  );
  const paramIdIndex = lessonsRouter.stack.findIndex(
    (l) => l.route && l.route.path.startsWith('/:id')
  );
  assert.ok(voicesIndex !== -1, '/tts/voices must be in router stack');
  assert.ok(paramIdIndex !== -1, '/:id routes must be in router stack');
  assert.ok(voicesIndex < paramIdIndex, '/tts/voices must be mounted before any /:id route');
});

