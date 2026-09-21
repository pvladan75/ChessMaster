// recording_export_deadline.test.js — the recorded-lesson export tells the
// queue when its client stops waiting, and is told so when it cannot be drawn
// in time. Item 5 of part two of docs/PLAN-SNIMANJE.md.
//
// This export is still drawn inside the request that asked for it, so nginx's
// 300 s is its deadline. A tutorial film in the background has none since
// item 5, and could otherwise be ten minutes in front of it.
//
// Until this, no test drove `POST /recordings/:id/export-mp4` at all. The
// queue's rule was proved on its own; a proved function is not a proved caller.
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const recordingsRouter = require('../routes/recordings');
const renderQueue = require('../services/renderQueue');
const videoRenderer = require('../videoRenderer');

function handlers() {
  const layer = recordingsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/export-mp4' && l.route.methods.post
  );
  assert.ok(layer, 'POST /recordings/:id/export-mp4 must be mounted');
  return layer.route.stack.map((s) => s.handle);
}

// `duration_seconds` stood in this fixture until 22.9.2026 — a column the
// table never had, so the film's length came only from the fixture. The table
// has `duration_ms` since phase 5b of docs/PLAN-SESIJA.md.
const ROOM_ROW = { id: 3, host_id: 4, title: 'Lesson', timeline_json: [], duration_ms: 120000 };

async function exportWith(queueRun, { row = ROOM_ROW, onRender } = {}) {
  const originalQuery = db.pool.query;
  const originalRun = renderQueue.run;
  const originalRender = videoRenderer.renderRecordingToMP4;
  const queries = [];
  db.pool.query = async (text, values) => {
    queries.push({ text, values });
    if (/SELECT account_type FROM users/i.test(text)) return { rows: [{ account_type: 'premium' }], rowCount: 1 };
    if (/SELECT tier, status/i.test(text)) return { rows: [], rowCount: 0 };
    if (/FROM session_recordings/i.test(text)) {
      return {
        rows: [row],
        rowCount: 1,
      };
    }
    return { rows: [], rowCount: 0 };
  };
  renderQueue.run = queueRun;
  videoRenderer.renderRecordingToMP4 = async (opts) => {
    if (onRender) onRender(opts);
    return opts.outputPath;
  };

  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  const req = { params: { id: '3' }, body: {}, user: { id: 4 } };
  try {
    const [, entitlement, handler] = handlers();
    // The entitlement check calls `next()` without handing back its promise,
    // so awaiting the middleware is not awaiting the route: the handler's own
    // promise is captured and waited for. The first version of this file
    // asserted on a response the route had not written yet.
    let answered = null;
    await entitlement(req, res, () => { answered = handler(req, res); });
    assert.ok(answered, 'the entitlement check let the export through');
    await answered;
  } finally {
    db.pool.query = originalQuery;
    renderQueue.run = originalRun;
    videoRenderer.renderRecordingToMP4 = originalRender;
  }
  return { res, queries };
}

test('the export tells the queue when its client stops waiting', async () => {
  let options = null;
  const before = Date.now();
  const { res } = await exportWith(async (id, task, onPosition, opts) => {
    options = opts;
    throw new renderQueue.RenderQueueFull(2);
  });
  assert.equal(res.statusCode, 429);
  assert.ok(options, 'the queue was asked');
  assert.equal(options.owner, 4);
  assert.ok(options.estimateMs > 0, 'and told how long the film takes');
  assert.ok(options.deadline >= before + 300_000 && options.deadline <= Date.now() + 300_000,
    'the deadline is nginx\'s 300 s from when the request arrived');
});

test('a film the queue cannot finish in time is refused with when to try again', async () => {
  // Before item 5 this refusal could not happen, and the request was cut off
  // by the proxy instead — behind a tutorial being drawn for ten minutes.
  const { res, queries } = await exportWith(async () => {
    throw new renderQueue.RenderWontFit(90_000);
  });
  assert.equal(res.statusCode, 429);
  assert.match(res.body.error, /could not finish it before the connection closes\. Try again in about 2 minutes\.$/);
  assert.equal(queries.find((q) => /usage_counters/i.test(q.text)), undefined, 'nothing drawn, nothing metered');
});

test("a lesson's film has its own voice and runs to the end of it", async () => {
  // Phase 5b. The film used to run to the last event — a trainer who talks on
  // after the last move would be cut off — and a lesson's sound is in the
  // private folder, named by `audio_file`, never by a public `audio_url`.
  const lessonRecording = require('../services/lessonRecording');
  let rendered = null;
  await exportWith(async (id, task) => task(), {
    row: {
      id: 5, host_id: 4, title: 'Lucena', audio_url: null,
      audio_file: 'lesson_4_ab.wav', duration_ms: 95_000,
      timeline_json: [{ timestampMs: 0, eventType: 'init', data: { fen: 'x' } },
        { timestampMs: 400, eventType: 'move', data: { fen: 'y' } }],
    },
    onRender: (opts) => { rendered = opts; },
  });
  assert.ok(rendered, 'the renderer was called');
  assert.equal(rendered.durationSeconds, 95);
  assert.equal(rendered.audioFilePath, lessonRecording.lessonAudioPath('lesson_4_ab.wav'));
});
