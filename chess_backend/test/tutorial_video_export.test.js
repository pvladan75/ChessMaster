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
// A recording is read from here by a recorded export; never the real uploads/.
const NARRATION_DIR = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'export-narration-'));
process.env.NARRATION_DIR = NARRATION_DIR;

const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const videoRenderer = require('../videoRenderer');
const tts = require('../services/tts');
const tutorialNarration = require('../services/tutorialNarration');
const renderQueue = require('../services/renderQueue');
const renderProgress = require('../services/renderProgress');
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
  previousVideo = null,
  narrateError = null,
  // The tutorial's stored recording, for an export that asks for it.
  narrationRow = null,
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
    // The film this tutorial had before this render, read so the old file can
    // be removed once the row names the new one.
    if (/SELECT video_filename FROM saved_lessons/i.test(text)) {
      return { rows: [{ video_filename: previousVideo }], rowCount: 1 };
    }
    if (/SELECT narration_filename, narration_ms, narration_markers, narration_take_id/i.test(text)) {
      return { rows: narrationRow ? [narrationRow] : [], rowCount: narrationRow ? 1 : 0 };
    }
    if (/INSERT INTO usage_counters/i.test(text)) {
      return { rows: [{ used: values[3] }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };

  const res = {
    statusCode: 200,
    body: null,
    // Since the abort landed (9.9.2026) the export route watches the response
    // for the client hanging up — `services/renderAbort.js`. A fake with no
    // listeners throws inside the handler, and every assertion in this file
    // then reads 500 instead of what it is about. **The assertions are
    // unchanged**; the fixture grew two methods a real `ServerResponse` has
    // always had.
    writableFinished: false,
    on() { return this; },
    off() { return this; },
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

test('a film that was meant to speak and did not says so', async () => {
  // „Trenutno se ne čuje, renderuje bez zvuka iako sam stavio jezik" — piper
  // could not start on the owner's machine, the log said so, and the app said
  // „Video ready!". A voice that was asked for and did not arrive is news: the
  // film is still worth having, so this is a sentence on a **successful**
  // export rather than a failure. Do the thing, then say what happened to it.
  const { res } = await run({
    body: { events: VALID_EVENTS, seconds: 4, narrate: true, voice: 'en_US-lessac-medium' },
    narrateResult: {
      events: VALID_EVENTS,
      seconds: null,
      audioPath: null,
      spokenBeats: 0,
      silentBecause: 'voice',
    },
  });

  assert.equal(res.statusCode, 200, 'the video is finished and downloadable');
  assert.ok(res.body.downloadUrl, 'and the file is still offered');
  assert.equal(res.body.narration, 'failed', 'a word the app can act on');
  assert.match(res.body.message, /no narration/i,
    'and a sentence the trainer can read');
});

test('the four silences are told apart, and one of them is not news', async () => {
  // A tutorial with nothing written in it is the one silence nobody needs to be
  // told about: there was nothing to say. The other three are the engine
  // missing, the voice producing nothing, and the clips failing to join — and
  // saying „no narration" without saying which would send a trainer to check
  // their own text when the server has no voices installed at all.
  const silent = async (silentBecause) => {
    const { res } = await run({
      body: { events: VALID_EVENTS, seconds: 4, narrate: true, voice: 'en_US-lessac-medium' },
      narrateResult: {
        events: VALID_EVENTS,
        seconds: null,
        audioPath: null,
        spokenBeats: 0,
        silentBecause,
      },
    });
    return res.body;
  };

  const nothingToSay = await silent(null);
  assert.equal(nothingToSay.narration, undefined);
  assert.doesNotMatch(nothingToSay.message, /no narration/i,
    'a wordless tutorial is not a narration failure');

  const unavailable = await silent('unavailable');
  assert.match(unavailable.message, /no speech voices installed/i);

  const track = await silent('track');
  assert.match(track.message, /could not be joined/i);

  const voice = await silent('voice');
  assert.match(voice.message, /the voice produced nothing/i);
  assert.match(voice.message, /log/i, 'and where to look');
});

test('two renders that start in the same millisecond are two files', async () => {
  // „Šta se dešava ako dva ili više korisnika pošalju zahtev za renderovanje u
  // isto vreme?" They interleave, which is fine — but the filename used to end
  // at `Date.now()`, so two renders of one tutorial that started together
  // agreed on it. The second overwrote the first while both download links
  // pointed at that one name, and whoever clicked got a film they had not asked
  // for. The signed token did not stop it: it is bound to a filename, and both
  // tokens named the same one.
  //
  // The clock is frozen here so the test is about the name and not about how
  // fast the machine runs.
  const realNow = Date.now;
  Date.now = () => 1788957059894;
  try {
    const first = await run({ body: { events: VALID_EVENTS, seconds: 4 } });
    const second = await run({ body: { events: VALID_EVENTS, seconds: 4 } });
    assert.equal(first.res.statusCode, 200);
    assert.equal(second.res.statusCode, 200);
    assert.notEqual(first.res.body.filename, second.res.body.filename,
      'one tutorial, one millisecond, two files');
    assert.notEqual(first.res.body.downloadUrl, second.res.body.downloadUrl,
      'and two links, each naming its own');
  } finally {
    Date.now = realNow;
  }
});

test('a full queue is refused at once, and costs the trainer nothing', async () => {
  // „Ja bih ih stavio u red" — and the waiting is bounded, because the render
  // happens inside the request the client already made and nginx closes a
  // proxied request after 300 s. „You are fourth" is a promise this server
  // cannot keep, so it is not made: the refusal comes back before any work,
  // which is why nothing is metered and no file is written.
  // One gate for all three, because a hold created inside a task that has not
  // started yet cannot be released: the first version of this test released the
  // only hold that existed, the next filler started and made a new one, and the
  // queue never drained.
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  const filling = [0, 1, 2].map((i) => renderQueue.run(`filler-${i}`, () => gate));
  await new Promise((r) => setImmediate(r));
  assert.equal(renderQueue.snapshot().waiting, 2, 'one drawing, two waiting');

  const { res, renderCalls, queries } = await run({
    body: { events: VALID_EVENTS, seconds: 4, jobId: 'job-queue-full-1' },
  });

  assert.equal(res.statusCode, 429, 'one client too many for a moment, not a server that is down');
  assert.match(res.body.error, /rendering other videos/i);
  assert.equal(renderCalls.length, 0, 'nothing was drawn');
  assert.equal(
    queries.filter((q) => /INSERT INTO usage_events|usage/i.test(q.text)).length,
    0,
    'and nothing was metered',
  );
  assert.equal(renderProgress.statusOf('job-queue-full-1').done, true,
    'the bar stops rather than creeping at 0');

  openGate();
  await Promise.all(filling);
  assert.equal(renderQueue.snapshot().waiting, 0);
});

test('a render that waits says it is waiting, and where', async () => {
  // What the screen shows while a film is in the queue: not „Starting…" over an
  // empty bar, which is what a queued render looked like before — the number
  // was 0 and the bar was indeterminate, exactly like a render that had begun.
  const job = 'job-queued-1';
  renderProgress.queued(job, 2);
  assert.deepEqual(renderProgress.statusOf(job), {
    percent: 0, done: false, known: true, etaSeconds: null, queuedAhead: 2,
  });

  // The queue moves, and the screen can see it move. A place that never changes
  // is indistinguishable from a queue that has stopped.
  renderProgress.queued(job, 1);
  assert.equal(renderProgress.statusOf(job).queuedAhead, 1);

  // Its turn comes, and from here the bar means what it always meant.
  renderProgress.queued(job, 0);
  assert.equal(renderProgress.statusOf(job).queuedAhead, 0);
  renderProgress.report(job, 40, 80);
  assert.equal(renderProgress.statusOf(job).percent, 50);
  assert.equal(renderProgress.statusOf(job).queuedAhead, 0);

  // And a job already drawing is not pushed back into the queue by a late
  // position report from the queue it has already left.
  renderProgress.queued(job, 0);
  assert.equal(renderProgress.statusOf(job).percent, 50, 'the frames it drew are still drawn');
});

test('an export that has to wait reports its place through the progress route', async () => {
  // End to end, which is the only way to see the wiring: the route hands the
  // queue a callback, the queue calls it whenever the queue moves, and the poll
  // the app is already making answers with a place rather than „Starting…".
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  const filling = renderQueue.run('ahead-of-you', () => gate);
  await new Promise((r) => setImmediate(r));

  const job = 'job-waiting-1';
  const exporting = run({ body: { events: VALID_EVENTS, seconds: 4, jobId: job } });
  await new Promise((r) => setImmediate(r));

  assert.equal(renderProgress.statusOf(job).queuedAhead, 1,
    'one film in front of this one');
  assert.equal(renderProgress.statusOf(job).percent, 0, 'and nothing drawn yet');

  openGate();
  const { res, renderCalls } = await exporting;
  await filling;

  assert.equal(res.statusCode, 200, 'and then it is rendered like any other');
  assert.equal(renderCalls.length, 1);
  assert.equal(renderProgress.statusOf(job).queuedAhead, 0);
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

test('a finished export is recorded on the tutorial', async () => {
  // The film used to exist only as a link in this response, whose token dies in
  // thirty minutes. The row is what makes „Download video" possible tomorrow.
  const { res, queries } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 90,
      title: 'Weak squares',
      resolution: '1080p',
      boardTheme: 'wood',
    },
  });

  assert.strictEqual(res.statusCode, 200);
  const recorded = queries.find((q) => /UPDATE saved_lessons/i.test(q.text));
  assert.ok(recorded, 'the tutorial keeps the name of its film');
  assert.match(recorded.text, /video_filename = \$1/);
  assert.match(recorded.text, /video_rendered_at = NOW\(\)/);
  assert.strictEqual(recorded.values[0], res.body.filename);
  assert.strictEqual(recorded.values[1], '1080p');
  assert.strictEqual(recorded.values[2], 90);
  assert.strictEqual(recorded.values[4], '15');
});

test('the film it replaces is deleted, and the row is written first', async () => {
  // **The order is the whole safety of it.** A crash between the two leaves a
  // file nothing points at, which the retention timer collects. The other way
  // round leaves a row naming a file that is gone — a trainer pressing
  // „Download" and getting nothing.
  const exportsDir = path.join(__dirname, '..', 'exports');
  fs.mkdirSync(exportsDir, { recursive: true });
  const stale = `tutorial_15_wood_720p_old_${Date.now()}.mp4`;
  fs.writeFileSync(path.join(exportsDir, stale), 'the previous film');

  const { res, queries } = await run({ previousVideo: stale });

  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(
    fs.existsSync(path.join(exportsDir, stale)), false,
    'one video per tutorial: the one it replaces is gone',
  );

  const read = queries.findIndex((q) => /SELECT video_filename FROM saved_lessons/i.test(q.text));
  const written = queries.findIndex((q) => /UPDATE saved_lessons/i.test(q.text));
  assert.ok(read >= 0 && written > read, 'read the old name, then write the new one');
});

test('a render that failed records nothing', async () => {
  // Same rule as the metering beside it: the trainer got no film, so the row
  // must not claim one — least of all by deleting the film they already had.
  const { res, queries } = await run({ renderError: new Error('ffmpeg died') });

  assert.strictEqual(res.statusCode, 500);
  assert.strictEqual(
    queries.find((q) => /UPDATE saved_lessons/i.test(q.text)),
    undefined,
  );
});

test('the export competes for its own account share, not the whole machine', async () => {
  // One trainer pressing Export three times used to fill the queue and refuse
  // every other trainer with a 429. The queue cannot know who is asking unless
  // the route tells it.
  const seen = [];
  const originalRun = renderQueue.run;
  renderQueue.run = async (id, task, onPosition, options) => {
    seen.push(options);
    return originalRun(id, task, onPosition, options);
  };

  try {
    const { res } = await run({ userId: 77 });
    assert.strictEqual(res.statusCode, 200);
    assert.deepEqual(seen, [{ owner: 77 }]);
  } finally {
    renderQueue.run = originalRun;
  }
});

test('a trainer at their own share is told so, and not that the server is busy',
  async () => {
    // Two refusals, two sentences. „The server is rendering other videos" is a
    // lie when the other videos are this trainer's own, and it sends them off
    // to wait for somebody else.
    const originalRun = renderQueue.run;
    renderQueue.run = async () => {
      throw new renderQueue.RenderAccountBusy(2);
    };

    try {
      const { res, queries } = await run();
      assert.strictEqual(res.statusCode, 429);
      assert.match(res.body.error, /you already have/i);
      assert.doesNotMatch(res.body.error, /server is rendering/i);
      // Nothing was drawn, so nothing is metered and no film is recorded.
      assert.strictEqual(queries.find((q) => /INSERT INTO usage_counters/i.test(q.text)), undefined);
      assert.strictEqual(queries.find((q) => /UPDATE saved_lessons/i.test(q.text)), undefined);
    } finally {
      renderQueue.run = originalRun;
    }
  });

// ------------------------------------------ phase 4: the trainer's own voice
//
// The export with a recording is the one place a trainer's voice — which exists
// nowhere else — is handed to code that deletes audio files when it is done.

function keptRecording(name) {
  fs.writeFileSync(path.join(NARRATION_DIR, name), 'a trainer\'s voice');
  return {
    narration_filename: name,
    narration_ms: 7300,
    narration_markers: [0, 4100],
    narration_take_id: 'ab12',
  };
}

function recordedBody(extra = {}) {
  return { events: VALID_EVENTS, seconds: 4, title: 'x', useRecording: true, takeId: 'ab12', ...extra };
}

test('a recorded export is drawn on the recording\'s own timing, with its audio', async () => {
  const row = keptRecording('narration_15_00000000000000dd.wav');
  const { res, renderCalls, narrateCalls, queries } = await run({
    body: recordedBody({ narrate: true }),
    narrationRow: row,
  });

  assert.strictEqual(res.statusCode, 200, JSON.stringify(res.body));
  assert.strictEqual(narrateCalls.length, 0, 'a synthesised voice was asked for over a recording');
  const call = renderCalls[0];
  assert.strictEqual(call.audioFilePath, path.join(NARRATION_DIR, row.narration_filename));
  assert.deepStrictEqual(call.timelineEvents.map((e) => e.timestampMs), [0, 4100]);
  assert.deepStrictEqual(call.timelineEvents.map((e) => e.data.spokenMs), [4100, 3200]);
  assert.strictEqual(call.durationSeconds, 8);

  const recorded = queries.find((q) => /UPDATE saved_lessons/i.test(q.text) && /video_filename/.test(q.text));
  assert.strictEqual(recorded.values[3], true, 'a film in the trainer\'s voice is a narrated film');
});

test('the recording survives the export that used it', async () => {
  const row = keptRecording('narration_15_00000000000000ee.wav');
  const { res, queries } = await run({ body: recordedBody(), narrationRow: row });
  assert.strictEqual(res.statusCode, 200);
  // Asked here, with no synthesised voice in the request, because the test
  // above also sends `narrate: true` — which would set the flag on its own.
  const recorded = queries.find((q) => /UPDATE saved_lessons/i.test(q.text) && /video_filename/.test(q.text));
  assert.strictEqual(recorded.values[3], true, 'a film in the trainer\'s voice is a narrated film');
  assert.ok(fs.existsSync(path.join(NARRATION_DIR, row.narration_filename)),
    'the export deleted the trainer\'s voice with the synthesised track');
});

test('a recording made against beats that have moved is refused, and nothing is drawn', async () => {
  // Phase 5, through the route: the beats the app sends now against the ones
  // the recording was made over. The count is the same in both, which is what
  // makes this the case the phase exists for.
  const row = { ...keptRecording('narration_15_0000000000000a11.wav'), narration_signature: 'a'.repeat(64) };

  const { res, renderCalls, queries } = await run({
    body: recordedBody({ signature: 'b'.repeat(64) }),
    narrationRow: row,
  });
  assert.strictEqual(res.statusCode, 409, JSON.stringify(res.body));
  assert.strictEqual(res.body.recording, 'edited');
  assert.strictEqual(renderCalls.length, 0, 'an edited tutorial was drawn over its old voice');

  // Asked of the statement, because the fake hands back the whole row whatever
  // is selected: a SELECT that forgets the column would leave this refusal
  // green here and never fire against a database.
  const read = queries.find((q) => /FROM saved_lessons WHERE id/i.test(q.text) && /narration_filename/.test(q.text));
  assert.match(read.text, /narration_signature/, 'the row is read without the column it is judged by');

  const same = await run({ body: recordedBody({ signature: 'a'.repeat(64) }), narrationRow: row });
  assert.strictEqual(same.res.statusCode, 200, JSON.stringify(same.res.body));
  assert.strictEqual(same.renderCalls.length, 1);
});

test('a recording that does not fit is refused before the queue, and nothing is drawn', async () => {
  const row = keptRecording('narration_15_00000000000000ff.wav');
  const cases = [
    [{ body: recordedBody({ takeId: 'ffff' }), narrationRow: row }, 'other'],
    [{ body: recordedBody({ events: [VALID_EVENTS[0]] }), narrationRow: row }, 'beats'],
    [{ body: recordedBody(), narrationRow: null }, 'none'],
  ];
  for (const [options, code] of cases) {
    const { res, renderCalls } = await run(options);
    assert.strictEqual(res.statusCode, 409, code);
    assert.strictEqual(res.body.recording, code);
    assert.strictEqual(renderCalls.length, 0, `${code} was drawn anyway`);
  }
});
