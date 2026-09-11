// tutorial_video_export.test.js
// Tests for POST /lessons/:id/export-video
//
// Gates:
// 1. no entitlement → refused, and the renderer is never called;
// 2. somebody else's tutorial → 404, and the query carries the user;
// 3. empty `events` → 400, nothing written to `exports/`;
// 4. `seconds` over 3600 → clamped, not refused;
// 5. metering booked after a successful render, and not after a failed one;
// 6. the job's outcome names the file that was written, and the progress route
//    hands out a link to it.
//
// Since item 5 of part two of docs/PLAN-SNIMANJE.md an accepted export is
// answered 202 and its film is drawn behind the answer. `run` waits for the job
// to settle (`renderJobs.settled`) and hands back what it came to as `outcome`;
// everything that refuses a film is still answered in the request.
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
const renderJobs = require('../services/renderJobs');
const realtime = require('../services/realtime');
const { RenderAborted } = require('../services/renderAbort');
const { METRIC } = require('../services/entitlementService');

// A finished or failed film notifies its trainer, and the nudge half of that
// needs a socket server to have been handed over.
realtime.init({ to: () => ({ emit: () => {} }) });

const EXPORTS_DIR = path.join(__dirname, '..', 'exports');

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

const tick = () => new Promise((resolve) => setImmediate(resolve));

/// Races [promise] against a deadline. A mutation that makes an export wait for
/// something that never comes would otherwise hang the file with no message.
function within(promise, ms = 3000) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('HUNG')), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

/// tutorial_render_jobs, shared by every export in this file the way the table
/// is — two exports of one tutorial meet in it — including the partial unique
/// index that allows one running render per tutorial and trainer.
const jobRows = [];
const jobRow = (id) => jobRows.find((r) => r.id === id);

function jobTable(text, values = []) {
  const flat = text.replace(/\s+/g, ' ').trim();
  if (!/tutorial_render_jobs/.test(flat)) return null;
  if (/^INSERT INTO/.test(flat)) {
    const [id, userId, lessonId] = values;
    if (jobRows.some((r) => r.status === 'running' && r.user_id === userId && r.lesson_id === lessonId)) {
      const err = new Error('duplicate key value violates unique constraint "ux_tutorial_render_jobs_running"');
      err.code = '23505';
      throw err;
    }
    jobRows.push({
      id, user_id: userId, lesson_id: lessonId, status: 'running', message: null, error: null, filename: null,
    });
    return { rows: [], rowCount: 1 };
  }
  if (/^SELECT id FROM/.test(flat)) {
    const [userId, lessonId] = values;
    return {
      rows: jobRows.filter((r) => r.user_id === userId && r.lesson_id === lessonId && r.status === 'running')
        .slice(0, 1).map((r) => ({ id: r.id })),
    };
  }
  if (/^SELECT id, lesson_id, status/.test(flat)) {
    const [id, userId] = values;
    const row = jobRows.find((r) => r.id === id && r.user_id === userId);
    return { rows: row ? [{ ...row }] : [] };
  }
  if (/SET status = 'failed', error = \$2/.test(flat)) {
    const row = jobRows.find((r) => r.id === values[0] && r.status === 'running');
    if (row) Object.assign(row, { status: 'failed', error: values[1] });
    return { rows: [], rowCount: row ? 1 : 0 };
  }
  if (/SET status = \$2, message = \$3/.test(flat)) {
    const [id, status, message, error, filename] = values;
    const row = jobRows.find((r) => r.id === id && r.status === 'running');
    if (row) Object.assign(row, { status, message, error, filename });
    return { rows: [], rowCount: row ? 1 : 0 };
  }
  if (/^DELETE FROM/.test(flat)) {
    const at = jobRows.findIndex((r) => r.id === values[0]);
    if (at !== -1) jobRows.splice(at, 1);
    return { rows: [], rowCount: at === -1 ? 0 : 1 };
  }
  throw new Error(`the job table fake was not taught: ${flat}`);
}

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
  // Called while the fake renderer is „drawing" — the one moment the film is
  // in the queue's slot, which is when a newcomer's arrival can be judged
  // against it. A fixture, added with item 4.
  duringRender = null,
  // Called with the response as soon as the export is answered and before its
  // film is settled — the only moment a test can act between the two. Added
  // with item 5.
  onAccepted = null,
} = {}) {
  const queries = [];
  const notices = [];
  const originalQuery = db.pool.query;
  const originalRender = videoRenderer.renderRecordingToMP4;
  const originalNarrateFilm = tutorialNarration.narrateFilm;

  const renderCalls = [];
  const narrateCalls = [];

  videoRenderer.renderRecordingToMP4 = async (opts) => {
    renderCalls.push(opts);
    if (duringRender) await duringRender(opts);
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
    const job = jobTable(text, values);
    if (job) return job;
    if (/INSERT INTO user_notifications/i.test(text)) {
      notices.push({ user: values[0], message: values[4], kind: values[5], ref: values[6] });
      return { rows: [], rowCount: 1 };
    }
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

  // Every event somebody listened for on the response. Since item 5 nothing
  // may listen for `close`: the answer is sent before the first frame, and a
  // listener that stops the render when the socket closes would stop every
  // one of them at birth.
  const listeners = [];
  const res = {
    statusCode: 200,
    body: null,
    writableFinished: false,
    on(event) { listeners.push(event); return this; },
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

  let outcome = null;
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
    // Waited for inside the fakes: the film is drawn after the answer, and a
    // database restored in the meantime would take its writes somewhere real.
    if (res.statusCode === 202) {
      if (onAccepted) await onAccepted(res);
      outcome = await renderJobs.settled(res.body.jobId);
    }
  } finally {
    db.pool.query = originalQuery;
    videoRenderer.renderRecordingToMP4 = originalRender;
    tutorialNarration.narrateFilm = originalNarrateFilm;
  }

  return { res, outcome, queries, renderCalls, narrateCalls, notices, listeners };
}

/// One of the two routes a trainer uses on a render once it is accepted —
/// `GET .../progress` or `DELETE` — asked as [userId], against the shared table.
async function ask(method, routePath, { jobId, userId = 4 }) {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === routePath && l.route.methods[method]
  );
  assert.ok(layer, `${method.toUpperCase()} /lessons${routePath} must be mounted`);
  const stack = layer.route.stack.map((s) => s.handle);

  const queries = [];
  const originalQuery = db.pool.query;
  db.pool.query = async (text, values) => {
    queries.push({ text, values });
    return jobTable(text, values) || { rows: [], rowCount: 0 };
  };
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  try {
    await stack[stack.length - 1]({ params: { jobId }, user: { id: userId } }, res);
  } finally {
    db.pool.query = originalQuery;
  }
  return { res, queries };
}

const PROGRESS = '/export-video/:jobId/progress';
const CANCEL = '/export-video/:jobId';

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
  // Only this route's own files for this tutorial are counted. `exports/` is
  // shared with every other test file, which run in parallel, and counting all
  // of it failed this test whenever one of them wrote a film at the same
  // moment — 34 against 33 in the measured run of 10.9.2026.
  const ours = (names) => names.filter((name) => name.startsWith('tutorial_15_'));
  const filesBefore = ours(fs.existsSync(EXPORTS_DIR) ? fs.readdirSync(EXPORTS_DIR) : []);

  const { res, renderCalls } = await run({
    body: {
      events: [],
      seconds: 10,
    },
  });

  assert.equal(res.statusCode, 400);
  assert.equal(renderCalls.length, 0);

  const filesAfter = ours(fs.existsSync(EXPORTS_DIR) ? fs.readdirSync(EXPORTS_DIR) : []);
  assert.deepEqual(filesAfter, filesBefore, 'nothing must be written to exports directory');
});

test('4. seconds over 3600 -> clamped, not refused', async () => {
  const { res, renderCalls, queries } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 5000,
    },
  });

  assert.equal(res.statusCode, 202);
  assert.equal(renderCalls.length, 1);
  assert.equal(renderCalls[0].durationSeconds, 3600, 'duration must be clamped to 3600');

  const meterQuery = queries.find((q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDER_SECONDS);
  assert.ok(meterQuery);
  assert.equal(meterQuery.values[3], 3600, 'booked seconds must also be clamped to 3600');
});

test('5. metering booked after a successful render, and not after a failed one', async () => {
  // Successful render
  const success = await run();
  assert.equal(success.res.statusCode, 202);
  assert.equal(success.outcome.status, 'done');

  const renderCounter = success.queries.find(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDERS
  );
  const secondsCounter = success.queries.find(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDER_SECONDS
  );
  assert.ok(renderCounter, 'must book MP4_RENDERS on success');
  assert.ok(secondsCounter, 'must book MP4_RENDER_SECONDS on success');
  assert.deepEqual(success.notices.map((n) => [n.user, n.kind, n.ref]), [[4, 'video_ready', 15]],
    'and the trainer is told, since nobody is waiting on the request any more');

  // Failed render: accepted, then failed behind the answer. It used to be the
  // request's 500; now it is the job's, with a sentence and a notification.
  const failed = await run({
    renderError: new Error('Render process crashed'),
  });
  assert.equal(failed.res.statusCode, 202);
  assert.equal(failed.outcome.status, 'failed');
  assert.equal(failed.outcome.error, renderJobs.RENDER_FAILED);
  assert.equal(jobRow(failed.res.body.jobId).status, 'failed');
  assert.deepEqual(failed.notices.map((n) => n.kind), ['video_failed']);

  const failedRenders = failed.queries.filter((q) => /INSERT INTO usage_counters/i.test(q.text));
  assert.equal(failedRenders.length, 0, 'must NOT book metering when render fails');
});

test('6. the job\'s outcome names the file that was written, and the progress route hands out a link to it', async () => {
  const { res, outcome, renderCalls } = await run();

  assert.equal(res.statusCode, 202);
  assert.ok(res.body.jobId, 'the answer names the job to watch');
  assert.equal(renderCalls.length, 1);

  const writtenFilename = path.basename(renderCalls[0].outputPath);
  assert.equal(outcome.filename, writtenFilename);
  assert.equal(jobRow(res.body.jobId).filename, writtenFilename, 'and the row keeps it');

  // The renderer is faked, so the file is written here for the link to find.
  fs.mkdirSync(EXPORTS_DIR, { recursive: true });
  fs.writeFileSync(renderCalls[0].outputPath, 'a film');
  try {
    const { res: progress } = await ask('get', PROGRESS, { jobId: res.body.jobId });
    assert.equal(progress.statusCode, 200);
    assert.equal(progress.body.status, 'done');
    assert.equal(progress.body.percent, 100);
    assert.ok(
      progress.body.downloadUrl.includes(`/recordings/export-download/${encodeURIComponent(writtenFilename)}`),
      'downloadUrl must name the written file'
    );
    assert.ok(progress.body.downloadUrl.includes('token='), 'downloadUrl must carry a token');
  } finally {
    fs.unlinkSync(renderCalls[0].outputPath);
  }

  // A file that has aged out since is not offered: a „Download" on a file that
  // is gone is a button that does nothing.
  const { res: later } = await ask('get', PROGRESS, { jobId: res.body.jobId });
  assert.equal(later.body.status, 'done');
  assert.equal(later.body.downloadUrl, undefined);
});

test('7. narrate absent or false -> the narration door is never opened', async () => {
  // Case A: absent
  const resAbsent = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 4,
    },
  });
  assert.equal(resAbsent.res.statusCode, 202);
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
  assert.equal(resFalse.res.statusCode, 202);
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
  const fakeAudioPath = path.join(EXPORTS_DIR, 'fake.wav');

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

  assert.equal(res.statusCode, 202);
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
  //
  // Since item 5 the sentence travels in the job's outcome, which is what the
  // app shows. The `narration: 'failed'` word that sat beside it in the old
  // response is gone: nothing in the app ever read it.
  const { res, outcome } = await run({
    body: { events: VALID_EVENTS, seconds: 4, narrate: true, voice: 'en_US-lessac-medium' },
    narrateResult: {
      events: VALID_EVENTS,
      seconds: null,
      audioPath: null,
      spokenBeats: 0,
      silentBecause: 'voice',
    },
  });

  assert.equal(res.statusCode, 202);
  assert.equal(outcome.status, 'done', 'the video is finished and downloadable');
  assert.ok(outcome.filename, 'and the file is still offered');
  assert.match(outcome.message, /no narration/i,
    'and a sentence the trainer can read');
});

test('the five silences are told apart, and one of them is not news', async () => {
  // A tutorial with nothing written in it is the one silence nobody needs to be
  // told about: there was nothing to say. The other four are no voices
  // installed, an engine that will not start, the voice producing nothing, and
  // the clips failing to join — and saying „no narration" without saying which
  // would send a trainer to check their own text when the server has no voices
  // installed at all.
  const silent = async (silentBecause) => {
    const { outcome } = await run({
      body: { events: VALID_EVENTS, seconds: 4, narrate: true, voice: 'en_US-lessac-medium' },
      narrateResult: {
        events: VALID_EVENTS,
        seconds: null,
        audioPath: null,
        spokenBeats: 0,
        silentBecause,
      },
    });
    return outcome;
  };

  const nothingToSay = await silent(null);
  assert.doesNotMatch(nothingToSay.message, /no narration/i,
    'a wordless tutorial is not a narration failure');

  const unavailable = await silent('unavailable');
  assert.match(unavailable.message, /no speech voices installed/i);

  // Told apart from the one above on purpose: the voices *are* installed and
  // the thing that reads them will not start, which is what „No module named
  // piper" looked like from a trainer's seat on 10.9.2026.
  const engine = await silent('engine');
  assert.match(engine.message, /engine could not start/i);
  assert.doesNotMatch(engine.message, /no speech voices installed/i);
  assert.match(engine.message, /log/i, 'and where to look');

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
    assert.equal(first.outcome.status, 'done');
    assert.equal(second.outcome.status, 'done');
    assert.notEqual(first.outcome.filename, second.outcome.filename,
      'one tutorial, one millisecond, two files');
  } finally {
    Date.now = realNow;
  }
});

test('a full queue is refused at once, and costs the trainer nothing', async () => {
  // „Ja bih ih stavio u red" — and the waiting is bounded. The refusal comes
  // back before any work, which is why nothing is metered and no file is
  // written — and, since item 5, why no job is left behind to say otherwise.
  // One gate for all three, because a hold created inside a task that has not
  // started yet cannot be released: the first version of this test released the
  // only hold that existed, the next filler started and made a new one, and the
  // queue never drained.
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  const filling = [0, 1, 2].map((i) => renderQueue.run(`filler-${i}`, () => gate));
  await tick();
  assert.equal(renderQueue.snapshot().waiting, 2, 'one drawing, two waiting');

  const { res, renderCalls, queries } = await run({
    body: { events: VALID_EVENTS, seconds: 4 },
  });

  assert.equal(res.statusCode, 429, 'one client too many for a moment, not a server that is down');
  assert.match(res.body.error, /rendering other videos/i);
  assert.equal(renderCalls.length, 0, 'nothing was drawn');
  assert.equal(
    queries.filter((q) => /INSERT INTO usage_events|usage/i.test(q.text)).length,
    0,
    'and nothing was metered',
  );
  assert.ok(queries.some((q) => /DELETE FROM tutorial_render_jobs/.test(q.text)),
    'the refused job\'s row was removed');
  assert.ok(!jobRows.some((r) => r.status === 'running' && r.user_id === 4 && r.lesson_id === '15'),
    'and nothing is left running to block the next export of this tutorial');

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
  // the app makes answers with a place rather than „Starting…".
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  const filling = renderQueue.run('ahead-of-you', () => gate);
  await tick();

  let seen = null;
  const { res, renderCalls, outcome } = await within(run({
    body: { events: VALID_EVENTS, seconds: 4 },
    onAccepted: async (answer) => {
      // Answered while the film waits — the request no longer holds the
      // trainer's screen for the length of somebody else's film.
      assert.equal(answer.statusCode, 202);
      seen = (await ask('get', PROGRESS, { jobId: answer.body.jobId })).res.body;
      openGate();
    },
  }));
  await filling;

  assert.equal(seen.status, 'running');
  assert.equal(seen.queuedAhead, 1, 'one film in front of this one');
  assert.equal(seen.percent, 0, 'and nothing drawn yet');

  assert.equal(res.statusCode, 202, 'and then it is rendered like any other');
  assert.equal(outcome.status, 'done');
  assert.equal(renderCalls.length, 1);
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

  assert.equal(res.statusCode, 202);
  const secondsCounter = queries.find(
    (q) => /INSERT INTO usage_counters/i.test(q.text) && q.values[1] === METRIC.MP4_RENDER_SECONDS
  );
  assert.ok(secondsCounter, 'must book MP4_RENDER_SECONDS');
  assert.equal(secondsCounter.values[3], 24, 'metering must book 24 seconds, not the requested 6 seconds');
});

test('10. the narration wav is deleted after the render, and the mp4 is not', async () => {
  if (!fs.existsSync(EXPORTS_DIR)) {
    fs.mkdirSync(EXPORTS_DIR, { recursive: true });
  }
  const dummyWav = path.join(EXPORTS_DIR, 'test-narration-cleanup.wav');
  fs.writeFileSync(dummyWav, 'dummy audio data');

  const dummyMp4 = path.join(EXPORTS_DIR, 'test-output.mp4');
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

    assert.equal(res.statusCode, 202);
    assert.equal(fs.existsSync(dummyWav), false, 'wav file must be deleted');
    assert.equal(fs.existsSync(dummyMp4), true, 'mp4 file must not be deleted');
  } finally {
    if (fs.existsSync(dummyWav)) fs.unlinkSync(dummyWav);
    if (fs.existsSync(dummyMp4)) fs.unlinkSync(dummyMp4);
  }
});

test('11. narration that returns audioPath: null still finishes a video', async () => {
  const { res, outcome, renderCalls, narrateCalls } = await run({
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

  assert.equal(res.statusCode, 202);
  assert.equal(narrateCalls.length, 1);
  assert.equal(renderCalls.length, 1);
  assert.equal(renderCalls[0].audioFilePath, null);
  assert.equal(outcome.status, 'done');
  assert.ok(outcome.filename);
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
  const { res, outcome, queries } = await run({
    body: {
      events: VALID_EVENTS,
      seconds: 90,
      title: 'Weak squares',
      resolution: '1080p',
      boardTheme: 'wood',
    },
  });

  assert.strictEqual(res.statusCode, 202);
  const recorded = queries.find((q) => /UPDATE saved_lessons/i.test(q.text));
  assert.ok(recorded, 'the tutorial keeps the name of its film');
  assert.match(recorded.text, /video_filename = \$1/);
  assert.match(recorded.text, /video_rendered_at = NOW\(\)/);
  assert.strictEqual(recorded.values[0], outcome.filename);
  assert.strictEqual(recorded.values[1], '1080p');
  assert.strictEqual(recorded.values[2], 90);
  assert.strictEqual(recorded.values[4], '15');
});

test('the film it replaces is deleted, and the row is written first', async () => {
  // **The order is the whole safety of it.** A crash between the two leaves a
  // file nothing points at, which the retention timer collects. The other way
  // round leaves a row naming a file that is gone — a trainer pressing
  // „Download" and getting nothing.
  fs.mkdirSync(EXPORTS_DIR, { recursive: true });
  const stale = `tutorial_15_wood_720p_old_${Date.now()}.mp4`;
  fs.writeFileSync(path.join(EXPORTS_DIR, stale), 'the previous film');

  const { res, queries } = await run({ previousVideo: stale });

  assert.strictEqual(res.statusCode, 202);
  assert.strictEqual(
    fs.existsSync(path.join(EXPORTS_DIR, stale)), false,
    'one video per tutorial: the one it replaces is gone',
  );

  const read = queries.findIndex((q) => /SELECT video_filename FROM saved_lessons/i.test(q.text));
  const written = queries.findIndex((q) => /UPDATE saved_lessons/i.test(q.text));
  assert.ok(read >= 0 && written > read, 'read the old name, then write the new one');
});

test('a render that failed records nothing', async () => {
  // Same rule as the metering beside it: the trainer got no film, so the row
  // must not claim one — least of all by deleting the film they already had.
  const { res, outcome, queries } = await run({ renderError: new Error('ffmpeg died') });

  assert.strictEqual(res.statusCode, 202);
  assert.strictEqual(outcome.status, 'failed');
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
    assert.strictEqual(res.statusCode, 202);
    // Field by field rather than the whole object: the options grew with item
    // 4, and `deepEqual` against one shape is a claim about the object rather
    // than about what the queue is told. **The claim is unchanged**: the queue
    // is told who is asking.
    assert.strictEqual(seen.length, 1);
    assert.strictEqual(seen[0].owner, 77);
    // And how long the film will take — four seconds with nothing said is four
    // frames, one second of drawing at the default rate.
    assert.strictEqual(seen[0].estimateMs, 1000);
    // **But no deadline, since item 5.** The deadline was the moment the
    // request's connection closed, and nothing waits on a connection any more:
    // a film behind a long one is late, not worthless.
    assert.strictEqual(seen[0].deadline, undefined);
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
      assert.ok(queries.some((q) => /DELETE FROM tutorial_render_jobs/.test(q.text)),
        'and the refused job leaves no row behind');
    } finally {
      renderQueue.run = originalRun;
    }
  });

// ------------------------------------------ item 5: the render leaves the request
//
// Part two of docs/PLAN-SNIMANJE.md. The export used to hold the request — and
// the trainer's whole screen — for the length of the film. It is answered as
// soon as the film is accepted now, and drawn behind the answer.

test('the export is answered before its film is drawn', async () => {
  // „Ekran se zamrzne kad pošaljem na renderovanje." The answer is the whole
  // point of item 5: until it comes, the app can do nothing else.
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  // Set by the renderer on the way in and cleared on the way out: the answer
  // has to arrive between the two.
  let drawing = false;
  let atAnswer = null;

  const { res, outcome, queries } = await within(run({
    duringRender: async () => {
      drawing = true;
      await gate;
      drawing = false;
    },
    onAccepted: (answer) => {
      atAnswer = {
        status: answer.statusCode,
        body: answer.body,
        drawing,
        row: { ...jobRow(answer.body.jobId) },
      };
      openGate();
    },
  }));

  assert.equal(atAnswer.status, 202);
  assert.deepEqual(Object.keys(atAnswer.body).sort(), ['jobId', 'status']);
  assert.equal(atAnswer.body.status, 'running');
  assert.equal(atAnswer.drawing, true, 'answered with the film still being drawn');
  assert.equal(atAnswer.row.status, 'running');
  assert.equal(atAnswer.row.filename, null, 'and nothing yet recorded as its result');

  assert.equal(outcome.status, 'done');
  assert.equal(jobRow(res.body.jobId).status, 'done');
  assert.ok(queries.some((q) => /UPDATE saved_lessons/i.test(q.text)), 'and kept once it was drawn');
});

test('a closed connection no longer stops the film', async () => {
  // With a 202 the socket closes the moment the answer is sent. The listener
  // that stopped a render when its client went away would now stop every
  // render at birth; the trainer's own „Cancel" is what stops one.
  const { res, outcome, listeners } = await run();
  assert.equal(res.statusCode, 202);
  assert.equal(outcome.status, 'done');
  assert.ok(!listeners.includes('close'), 'something still stops the render when the socket closes');
});

test('a second export of a tutorial being rendered is shown the running one', async () => {
  // One film per tutorial: a second render would replace the first the moment
  // it finished. The trainer who pressed Export again — or on another device —
  // is handed the render already running, which is also how a hidden render is
  // found again.
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  let second = null;

  const first = await within(run({
    duringRender: () => gate,
    onAccepted: async () => {
      second = await run();
      openGate();
    },
  }));

  assert.equal(second.res.statusCode, 409);
  assert.equal(second.res.body.alreadyRendering, true);
  assert.equal(second.res.body.jobId, first.res.body.jobId, 'the running render is the one named');
  assert.equal(second.renderCalls.length, 0, 'and nothing was drawn for the second');

  // One *running* render, not one render ever.
  const third = await run();
  assert.equal(third.res.statusCode, 202);
  assert.equal(third.outcome.status, 'done');
});

test('cancel stops a film being drawn, and nobody is told about their own cancel', async () => {
  let cancelled = null;
  const { res, outcome, notices, queries } = await within(run({
    // A renderer that stops when its signal fires, as the real one does between
    // frames.
    duringRender: (opts) => new Promise((resolve, reject) => {
      if (opts.signal.aborted) reject(new RenderAborted());
      opts.signal.addEventListener('abort', () => reject(new RenderAborted()), { once: true });
    }),
    onAccepted: async (answer) => {
      cancelled = await ask('delete', CANCEL, { jobId: answer.body.jobId });
    },
  }));

  assert.equal(cancelled.res.statusCode, 202);
  assert.equal(outcome.status, 'cancelled');
  assert.equal(jobRow(res.body.jobId).status, 'cancelled');
  assert.equal(notices.length, 0, 'the trainer pressed the button; a notification about it is noise');
  assert.strictEqual(queries.find((q) => /INSERT INTO usage_counters/i.test(q.text)), undefined,
    'no film, no charge');
  assert.strictEqual(queries.find((q) => /UPDATE saved_lessons/i.test(q.text)), undefined);
  assert.equal(renderQueue.snapshot().running, 0, 'and the slot is the next trainer\'s');
});

test('a render is somebody\'s: another account cannot read or stop it', async () => {
  jobRows.push({ id: 'someone-elses-job', user_id: 9, lesson_id: '15', status: 'running' });
  try {
    const read = await ask('get', PROGRESS, { jobId: 'someone-elses-job', userId: 4 });
    assert.equal(read.res.statusCode, 404);
    assert.deepEqual(read.queries[0].values, ['someone-elses-job', 4], 'the query carries the user');
    // Asked of the statement too: the fake filters by user on its own, so a
    // query that forgot the column would pass here and hand out another
    // account's download link against a database.
    assert.match(read.queries[0].text, /user_id = \$2/);

    const stop = await ask('delete', CANCEL, { jobId: 'someone-elses-job', userId: 4 });
    assert.equal(stop.res.statusCode, 404);
    assert.equal(jobRow('someone-elses-job').status, 'running', 'and it was not touched');
  } finally {
    jobRows.splice(jobRows.findIndex((r) => r.id === 'someone-elses-job'), 1);
  }
});

test('a render that has ended cannot be cancelled, and says how it ended', async () => {
  const { res } = await run({ renderError: new Error('ffmpeg died') });

  const stop = await ask('delete', CANCEL, { jobId: res.body.jobId });
  assert.equal(stop.res.statusCode, 409);
  assert.equal(stop.res.body.status, 'failed');

  const read = await ask('get', PROGRESS, { jobId: res.body.jobId });
  assert.equal(read.res.body.status, 'failed');
  assert.equal(read.res.body.error, renderJobs.RENDER_FAILED, 'the trainer is told why, not just that');
});

test('a job id that is not one is refused before the database is asked', async () => {
  for (const [method, route] of [['get', PROGRESS], ['delete', CANCEL]]) {
    const { res, queries } = await ask(method, route, { jobId: '../../etc' });
    assert.equal(res.statusCode, 400);
    assert.equal(queries.length, 0);
  }
});

test('a render the server does not have is an answer, not a failure to get one', async () => {
  const { res } = await ask('get', PROGRESS, { jobId: 'never-started-1' });
  assert.equal(res.statusCode, 404);
  assert.equal(res.body.status, 'unknown');
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

  assert.strictEqual(res.statusCode, 202, JSON.stringify(res.body));
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
  assert.strictEqual(res.statusCode, 202);
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
  assert.strictEqual(same.res.statusCode, 202, JSON.stringify(same.res.body));
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
    assert.strictEqual(res.body.jobId, undefined, 'a refused recording is not a render already running');
    assert.strictEqual(renderCalls.length, 0, `${code} was drawn anyway`);
  }
});

// ------------------------------------------ item 4: refused before drawing
//
// Part two of docs/PLAN-SNIMANJE.md. A film too long to draw in one go is
// refused with a sentence before anything is drawn. Written while the render
// lived inside the request; since item 5 the ceiling is the longest one film
// may hold the render slot, at the same default.

const BUDGET_KEYS = ['RENDER_MAX_DRAW_SECONDS', 'RENDER_DRAW_FPS_720P', 'RENDER_DRAW_FPS_1080P'];

/// Runs [fn] with the drawing rate set to [vars], and puts it back: a rate
/// left behind would decide every export test after this one.
async function withRate(vars, fn) {
  const saved = Object.fromEntries(BUDGET_KEYS.map((k) => [k, process.env[k]]));
  Object.assign(process.env, vars);
  try {
    return await fn();
  } finally {
    for (const k of BUDGET_KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

/// A refusal costs the trainer nothing: no frame, no quota, no film recorded.
function nothingHappened({ renderCalls, queries }, what) {
  assert.strictEqual(renderCalls.length, 0, `${what} was drawn anyway`);
  assert.strictEqual(queries.find((q) => /INSERT INTO usage_counters/i.test(q.text)), undefined,
    `${what} was metered`);
  assert.strictEqual(queries.find((q) => /UPDATE saved_lessons/i.test(q.text)), undefined,
    `${what} was recorded as the tutorial's film`);
}

test('a film too long to draw in one go is refused before the queue, and says how to split it', async () => {
  // Thirty minutes with nothing said, drawn at one frame a second: 1800 s of
  // drawing against the 600 one film may take since item 5.
  await withRate({ RENDER_DRAW_FPS_720P: '1' }, async () => {
    const result = await run({ body: { events: VALID_EVENTS, seconds: 1800 } });
    assert.strictEqual(result.res.statusCode, 422, JSON.stringify(result.res.body));
    assert.strictEqual(result.res.body.tooLong, true);
    assert.match(result.res.body.error, /would take about 30 minutes to render/);
    assert.match(result.res.body.error, /Split the tutorial into three shorter ones\.$/);
    nothingHappened(result, 'a film too long to draw in one go');
    assert.ok(!result.queries.some((q) => /INSERT INTO tutorial_render_jobs/.test(q.text)),
      'and no job was started for it');
  });
});

test('a film too long at 1080p is offered 720p, and only where 720p fits', async () => {
  await withRate({ RENDER_DRAW_FPS_1080P: '1' }, async () => {
    const result = await run({ body: { events: VALID_EVENTS, seconds: 1800, resolution: '1080p' } });
    assert.strictEqual(result.res.statusCode, 422, JSON.stringify(result.res.body));
    // 1800 frames at the default 720p rate of twelve a second is 150 s.
    assert.match(result.res.body.error, /, or export it at 720p\.$/);
    nothingHappened(result, 'a 1080p film too long to draw in one go');
  });
  await withRate({ RENDER_DRAW_FPS_1080P: '1', RENDER_DRAW_FPS_720P: '1' }, async () => {
    const { res } = await run({ body: { events: VALID_EVENTS, seconds: 1800, resolution: '1080p' } });
    assert.strictEqual(res.statusCode, 422);
    assert.doesNotMatch(res.body.error, /720p/, 'a way out that would be refused too was offered');
  });
});

test('a recording is judged by its own length, and the film without it is offered', async () => {
  // The app says 4 s; the recording is 7.3 s, drawn as 8. At a hundredth of a
  // frame a second those are 400 s and 800 s of drawing against the 600 one
  // film may take — only the recording is too long, so only the recording's
  // length can have refused it.
  const row = keptRecording('narration_15_0000000000000b01.wav');
  await withRate({ RENDER_DRAW_FPS_720P: '0.01' }, async () => {
    const result = await run({ body: recordedBody(), narrationRow: row });
    assert.strictEqual(result.res.statusCode, 422, JSON.stringify(result.res.body));
    assert.match(result.res.body.error, /, or export it without your recording\.$/);
    nothingHappened(result, 'a recording too long to draw in one go');
  });
  assert.ok(fs.existsSync(path.join(NARRATION_DIR, row.narration_filename)),
    'a refusal deleted the trainer\'s voice');
});

test('a voice that made the film too long fails at its turn, says why, and its track is removed', async () => {
  // Accepted on the app's 4 s; the voice took thirty minutes. That is known
  // only once it has spoken, so the film is asked again at its turn — before a
  // single frame. Since item 5 the request has long been answered by then, so
  // the sentence travels in the job and in the notification.
  const track = path.join(require('node:os').tmpdir(), `narration-too-long-${Date.now()}.wav`);
  fs.writeFileSync(track, 'synthesised');
  await withRate({ RENDER_DRAW_FPS_720P: '1' }, async () => {
    const result = await run({
      body: { events: VALID_EVENTS, seconds: 4, narrate: true },
      narrateResult: { events: VALID_EVENTS, audioPath: track, seconds: 1800, spokenBeats: 2 },
    });
    assert.strictEqual(result.res.statusCode, 202, JSON.stringify(result.res.body));
    assert.strictEqual(result.narrateCalls.length, 1, 'the voice spoke, which is how its length was learnt');
    assert.strictEqual(result.outcome.status, 'failed');
    assert.match(result.outcome.error, /^With narration, this video would take/);
    assert.match(result.outcome.error, /, or export it without narration\.$/);
    assert.deepEqual(result.notices.map((n) => n.kind), ['video_failed']);
    assert.match(result.notices[0].message, /export it without narration/, 'and the notification says the way out');
    nothingHappened(result, 'a narrated film too long to draw in one go');
  });
  assert.ok(!fs.existsSync(track), 'the synthesised track was left behind');
});

test('a film behind a long one is accepted: no connection is waiting for it', async () => {
  // Before item 5 this was refused with „try again in a minute or two": 295 s
  // of somebody else's film in front of it, 120 s of its own, and 300 s of
  // connection to do both in. No connection is waiting now, so the film simply
  // waits its turn.
  let openGate;
  const gate = new Promise((resolve) => { openGate = resolve; });
  const ahead = renderQueue.run('long-ahead', () => gate, () => {}, { owner: 999, estimateMs: 295_000 });
  await tick();

  let answered = null;
  const { outcome } = await within(run({
    body: { events: VALID_EVENTS, seconds: 120 },
    onAccepted: (answer) => {
      answered = answer.statusCode;
      openGate();
    },
  }));
  await ahead;

  assert.strictEqual(answered, 202);
  assert.strictEqual(outcome.status, 'done');
});

test('a voice that made the film longer tells the queue, and a newcomer is judged by that', async () => {
  // Accepted on the app's 4 s — four seconds of drawing at one frame a second —
  // and 250 s once the voice has spoken. A newcomer that has a deadline of its
  // own (a recorded-lesson export, still drawn inside its request) arriving
  // while this draws has to be judged on the 250, or it is let in behind a film
  // that will leave it no time. Found by a mutation that survived: the queue's
  // `revise` was proved, the route calling it was not.
  let refused = null;
  await withRate({ RENDER_DRAW_FPS_720P: '1' }, async () => {
    const { res, renderCalls, outcome } = await run({
      body: { events: VALID_EVENTS, seconds: 4, narrate: true },
      narrateResult: { events: VALID_EVENTS, audioPath: null, seconds: 250, spokenBeats: 2 },
      duringRender: async () => {
        renderQueue.run('behind-the-voice', async () => {}, () => {}, {
          owner: 555, estimateMs: 100_000, deadline: Date.now() + 300_000,
        }).catch((err) => { refused = err; });
        await tick();
      },
    });
    assert.strictEqual(res.statusCode, 202, JSON.stringify(res.body));
    assert.strictEqual(outcome.status, 'done');
    assert.strictEqual(renderCalls[0].durationSeconds, 250, 'drawn at the voice\'s length');
  });
  assert.ok(refused instanceof renderQueue.RenderWontFit,
    'the newcomer was judged on the 4 s the film was admitted on, not the 250 it has');
});

test('a film with something said is counted at four frames a second', async () => {
  // The renderer draws a captioned film four times a second and a silent one
  // once, and the budget has to count the frames that will be drawn. 400 s of
  // film at two frames drawn a second: 200 s silent, 800 s with captions.
  const said = VALID_EVENTS.map((event, i) => ({
    ...event,
    data: { ...event.data, text: i === 0 ? 'White takes the centre.' : 'Black answers.' },
  }));
  await withRate({ RENDER_DRAW_FPS_720P: '2' }, async () => {
    const silent = await run({ body: { events: VALID_EVENTS, seconds: 400 } });
    assert.strictEqual(silent.res.statusCode, 202, JSON.stringify(silent.res.body));
    const captioned = await run({ body: { events: said, seconds: 400 } });
    assert.strictEqual(captioned.res.statusCode, 422, JSON.stringify(captioned.res.body));
    assert.match(captioned.res.body.error, /about 14 minutes to render/);
  });
});

test('the budget counts a film without comments at one frame a second', async () => {
  // The same 400 s of talking film as above, at two frames drawn a second: 800 s
  // of drawing with the comments, 200 s without. A budget that ignored the flag
  // would refuse a film that fits, for the cost of a layout nobody asked for.
  const said = VALID_EVENTS.map((event, i) => ({
    ...event,
    data: { ...event.data, text: i === 0 ? 'White takes the centre.' : 'Black answers.' },
  }));
  await withRate({ RENDER_DRAW_FPS_720P: '2' }, async () => {
    const captioned = await run({ body: { events: said, seconds: 400 } });
    assert.strictEqual(captioned.res.statusCode, 422, JSON.stringify(captioned.res.body));
    assert.match(captioned.res.body.error, /, or export it without the comments beside the board\.$/,
      'a way out the server checked, offered where it fits');

    const plain = await run({ body: { events: said, seconds: 400, captions: false } });
    assert.strictEqual(plain.res.statusCode, 202, JSON.stringify(plain.res.body));

    // **Offered only where it is a way out.** 1300 s is 650 s of drawing even
    // at one frame a second, over the 600 s ceiling — so saying „without the
    // comments" there is a second refusal waiting to happen.
    const tooLong = await run({ body: { events: said, seconds: 1300 } });
    assert.strictEqual(tooLong.res.statusCode, 422, JSON.stringify(tooLong.res.body));
    assert.doesNotMatch(tooLong.res.body.error, /comments/);
  });
});

test('the captions flag reaches the drawing, and absent still means yes', async () => {
  // Read off the options the renderer was actually called with. The route owns
  // the default, and an older app that says nothing must keep getting the film
  // it has always got.
  const asked = await run({ body: { events: VALID_EVENTS, seconds: 30, captions: false } });
  assert.equal(asked.res.statusCode, 202);
  assert.equal(asked.renderCalls.length, 1);
  assert.equal(asked.renderCalls[0].captions, false);

  const silent = await run({ body: { events: VALID_EVENTS, seconds: 30 } });
  assert.equal(silent.renderCalls[0].captions, true,
    'saying nothing is the request every client made before this field existed');
});
