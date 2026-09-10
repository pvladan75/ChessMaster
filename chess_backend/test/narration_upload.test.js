// narration_upload.test.js — phase 3 of docs/PLAN-SNIMANJE.md: what the
// server checks before a trainer's voice is kept, and where it is kept.
//
// Gates:
//  1. the length is the file's own, and a take cut short on the wire is refused;
//  2. the markers describe this audio — start at 0, only ever increase, end
//     before the audio does, one per beat of the film;
//  3. a silent take is refused, a quiet room is not;
//  4. fifteen minutes is the most, and over it is refused while it arrives;
//  5. who may record is asked before a byte is written: not yours, no birth
//     year, under eighteen;
//  6. a new take is written to the row before the old file is deleted;
//  7. deleting the tutorial deletes the recording, after the row;
//  8. nothing under uploads/narration is served by URL, however it is spelt.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';
const NARRATION_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'narration-test-'));
process.env.NARRATION_DIR = NARRATION_DIR;

const express = require('express');
const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const narrationUpload = require('../services/narrationUpload');
const { mayRecordNarration } = require('../services/recordingConsent');
const { serveUploads, isPrivateUpload } = require('../middleware/uploadsStatic');

const RATE = 16000;
const BYTE_RATE = RATE * 2;

/// A 16 kHz mono 16-bit wav of [ms] milliseconds whose loudest sample is [peak].
function wavOf({ ms, peak = 8000, sampleRate = RATE, channels = 1 }) {
  const byteRate = sampleRate * channels * 2;
  let dataBytes = Math.floor(ms * byteRate / 1000);
  dataBytes -= dataBytes % 2;
  const data = Buffer.alloc(dataBytes);
  if (peak !== 0) {
    for (let i = 0; i + 1 < dataBytes; i += 2) {
      data.writeInt16LE((i / 2) % 2 === 0 ? peak : -peak, i);
    }
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + dataBytes, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(channels * 2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(dataBytes, 40);
  return Buffer.concat([header, data]);
}

function tempWav(options) {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'take-')), 'take.wav');
  fs.writeFileSync(file, wavOf(options));
  return file;
}

function judge({ ms = 1000, peak, markers = [0, 400], durationMs = ms, beats = 2, ...rest } = {}) {
  const file = tempWav({ ms, peak, ...rest });
  return narrationUpload.judgeNarration({ file, markersMs: JSON.stringify(markers), durationMs, beats });
}

// ---------------------------------------------------------------- the judge

test('a whole take is accepted, measured from its own header', () => {
  const judged = judge({ ms: 1000, markers: [0, 400, 800], beats: 3 });
  assert.equal(judged.ok, true, judged.error);
  assert.equal(judged.durationMs, 1000);
  assert.deepEqual(judged.markers, [0, 400, 800]);
});

test('a take cut short on the wire is refused, not corrected', () => {
  const judged = judge({ ms: 1000, durationMs: 1600 });
  assert.equal(judged.ok, false);
  assert.match(judged.error, /arrived incomplete/);
});

test('a recording in another format is refused', () => {
  const judged = judge({ ms: 1000, sampleRate: 44100 });
  assert.equal(judged.ok, false);
  assert.match(judged.error, /not in the format/);

  const stereo = judge({ ms: 1000, channels: 2 });
  assert.equal(stereo.ok, false);
  assert.match(stereo.error, /not in the format/);
});

test('a file that is not a wav is refused', () => {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'take-')), 'take.wav');
  fs.writeFileSync(file, 'ID3 not a wav at all');
  const judged = narrationUpload.judgeNarration({ file, markersMs: '[0]', durationMs: 0, beats: 1 });
  assert.equal(judged.ok, false);
  assert.match(judged.error, /not a wav file/);
});

test('the markers must describe this audio', () => {
  const cases = [
    [{ markers: [100, 400] }, /first beat does not start/],
    [{ markers: [0, 400, 400], beats: 3 }, /Beats 2 and 3 start at the same moment/],
    [{ markers: [0, 700, 500], beats: 3 }, /Beats 2 and 3 start at the same moment/],
    [{ markers: [0, 1000] }, /last beat starts after the recording ends/],
    [{ markers: [] }, /without its beats/],
    [{ markers: [0, 1.5] }, /could not be read/],
    [{ markers: [0, 400], beats: 5 }, /stops at beat 2 of 5/],
    [{ markers: [0, 400], beats: Number.NaN }, /how many beats/],
  ];
  for (const [options, expected] of cases) {
    const judged = judge(options);
    assert.equal(judged.ok, false, `${JSON.stringify(options)} was accepted`);
    assert.match(judged.error, expected, JSON.stringify(options));
  }
});

test('a silent take is refused, and a quiet room is not silence', () => {
  const muted = judge({ peak: 1 }); // ±1, the −90 dB of a muted microphone
  assert.equal(muted.ok, false);
  assert.equal(muted.status, 422);
  assert.match(muted.error, /Nothing reached the microphone/);

  const quiet = judge({ peak: 20 }); // about −64 dB: a live microphone between sentences
  assert.equal(quiet.ok, true, quiet.error);
});

/// Runs [fn] with the render budget's settings set to exactly [vars], so a
/// `.env` on the machine running the tests cannot decide what the cap is.
function withBudget(vars, fn) {
  const keys = ['RENDER_MAX_DRAW_SECONDS', 'RENDER_DRAW_FPS_720P', 'RENDER_DRAW_FPS_1080P'];
  const saved = Object.fromEntries(keys.map((k) => [k, process.env[k]]));
  for (const k of keys) delete process.env[k];
  Object.assign(process.env, vars);
  try {
    return fn();
  } finally {
    for (const k of keys) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

test('the longest recording is the longest captioned film one render may draw', () => {
  // Thirty minutes at the defaults since item 5 of part two: 600 s of drawing
  // at twelve frames a second is 7200 frames, four to a second of captioned
  // film. It was a fixed fifteen while the film was drawn inside a request.
  withBudget({}, () => {
    const maxSeconds = narrationUpload.narrationMaxSeconds();
    assert.equal(maxSeconds, 30 * 60);

    const over = judge({ ms: maxSeconds * 1000 + 40, peak: 0, markers: [0], beats: 1 });
    assert.equal(over.ok, false);
    assert.equal(over.status, 413);
    assert.match(over.error, /30:00 long.*at most 30 minutes/);

    assert.ok(narrationUpload.narrationMaxBytes() > maxSeconds * BYTE_RATE,
      'the multer limit must leave room for a whole take at the cap');
  });
});

test('the cap follows the render budget, so the two cannot disagree', () => {
  // A take accepted here is a take the export will draw. Set the ceiling back
  // to 300 s and the cap is fifteen minutes again, with nothing else changed.
  withBudget({ RENDER_MAX_DRAW_SECONDS: '300' }, () => {
    assert.equal(narrationUpload.narrationMaxSeconds(), 15 * 60);
    const over = judge({ ms: 15 * 60 * 1000 + 40, peak: 0, markers: [0], beats: 1 });
    assert.equal(over.status, 413);
    assert.match(over.error, /at most 15 minutes/);
  });
  // And a slower machine records less, rather than recording what it then
  // refuses to draw.
  withBudget({ RENDER_DRAW_FPS_720P: '6' }, () => {
    assert.equal(narrationUpload.narrationMaxSeconds(), 15 * 60);
  });
});

// ---------------------------------------------------------------- the consent

function poolAnswering(answers) {
  return {
    async query(sql) {
      for (const [pattern, rows] of answers) {
        if (pattern.test(sql)) return { rows, rowCount: rows.length };
      }
      return { rows: [], rowCount: 0 };
    },
  };
}

test('only an adult with a stated age may record — unknown refuses', async () => {
  const thisYear = new Date().getFullYear();
  const unknown = await mayRecordNarration(poolAnswering([[/birth_year/, [{ birth_year: null }]]]), 4);
  assert.equal(unknown.allowed, false);
  assert.match(unknown.reason, /birth year/);

  const minor = await mayRecordNarration(poolAnswering([[/birth_year/, [{ birth_year: thisYear - 16 }]]]), 4);
  assert.equal(minor.allowed, false);
  assert.match(minor.reason, /adult/);

  const adult = await mayRecordNarration(poolAnswering([[/birth_year/, [{ birth_year: 1980 }]]]), 4);
  assert.equal(adult.allowed, true);
});

// ---------------------------------------------------------------- the route

/// The route's three stages, **in the router's own order**. That the gate runs
/// before multer is what keeps a refused trainer's audio out of `uploads/`, and
/// a test that arranged the stages itself could not see the router arranging
/// them otherwise.
function narrationStages() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/narration' && l.route.methods.post,
  );
  assert.ok(layer, 'POST /:id/narration must be mounted');
  const stages = layer.route.stack
    .map((s) => s.handle)
    .filter((h) => ['narrationGate', 'receiveNarration', 'saveNarration'].includes(h.name));
  assert.equal(stages.length, 3, 'the gate, the receiver and the keeper must all be on the route');
  return stages;
}

/// The route's own three stages behind a real HTTP listener, with the user set
/// by hand: this file is about the stages, not the token middleware.
async function withRoute({ owns = true, birthYear = 1980, replaced = null, onUpdate } = {}, body) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    if (/SELECT id FROM saved_lessons/.test(sql)) {
      return owns ? { rows: [{ id: 12 }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/birth_year/.test(sql)) return { rows: [{ birth_year: birthYear }], rowCount: 1 };
    if (/UPDATE saved_lessons/.test(sql)) {
      if (onUpdate) onUpdate(values);
      return { rows: [{ replaced, narration_recorded_at: '2026-09-10T12:00:00.000Z' }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };

  const app = express();
  app.post(
    '/lessons/:id/narration',
    (req, _res, next) => { req.user = { id: 4 }; next(); },
    ...narrationStages(),
  );
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/lessons/12/narration`, { method: 'POST', body });
    return { status: res.status, body: await res.json(), queries };
  } finally {
    server.close();
    db.pool.query = original;
  }
}

const SIGNATURE = 'a'.repeat(64);

function formOf({ audio, markers = [0, 400], durationMs = 1000, beats = 2, takeId, signature }) {
  const form = new FormData();
  if (takeId !== undefined) form.append('takeId', takeId);
  if (signature !== undefined) form.append('signature', signature);
  form.append('markersMs', JSON.stringify(markers));
  form.append('durationMs', String(durationMs));
  form.append('beats', String(beats));
  form.append('audio', new Blob([audio]), 'take.wav');
  return form;
}

function filesKept() {
  return fs.readdirSync(NARRATION_DIR).filter((f) => f.startsWith('narration_'));
}

function clearKept() {
  for (const f of fs.readdirSync(NARRATION_DIR)) fs.unlinkSync(path.join(NARRATION_DIR, f));
}

test('a whole take is kept, and the row names it with its markers', async () => {
  clearKept();
  const { status, body, queries } = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }) }));

  assert.equal(status, 201, JSON.stringify(body));
  assert.deepEqual(body.narration.beats, 2);
  assert.equal(body.narration.ms, 1000);

  const kept = filesKept();
  assert.equal(kept.length, 1);
  assert.match(kept[0], /^narration_12_[0-9a-f]{16}\.wav$/);

  const update = queries.find((q) => /UPDATE saved_lessons/.test(q.sql));
  assert.equal(update.values[1], kept[0]);
  assert.equal(update.values[2], 1000);
  assert.equal(update.values[3], '[0,400]');
  assert.match(update.sql, /FOR UPDATE/, 'the old name is read with the row locked');
});

test('the beats a take was recorded against are kept beside it', async () => {
  // Phase 5. Markers name beats by index, so a beat list that has moved makes
  // every marker after the edit name a beat it was never recorded against —
  // and the count in the row cannot see a sentence being rewritten.
  clearKept();
  const { status, queries } = await withRoute({},
    formOf({ audio: wavOf({ ms: 1000 }), signature: SIGNATURE }));

  assert.equal(status, 201);
  const update = queries.find((q) => /UPDATE saved_lessons/.test(q.sql));
  assert.match(update.sql, /narration_signature = \$7/);
  assert.equal(update.values[6], SIGNATURE);
});

test('a take with no signature is kept, and the column says so', async () => {
  // A recording from an older app is a real recording. NULL is what marks it as
  // one that was never asked this question, and `recordingForFilm` judges those
  // by their beat count as it always did.
  clearKept();
  const { status, queries } = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }) }));

  assert.equal(status, 201);
  const update = queries.find((q) => /UPDATE saved_lessons/.test(q.sql));
  assert.equal(update.values[6], null);
});

test('a signature of the wrong shape is refused, and the file with it', async () => {
  // Not the same as none: it is a client this server does not recognise, and
  // storing it would leave a signature nothing can ever match — a recording
  // refused for ever, with no way to say why.
  clearKept();
  const { status, body } = await withRoute({},
    formOf({ audio: wavOf({ ms: 1000 }), signature: 'not-a-digest' }));

  assert.equal(status, 400);
  assert.match(body.error, /beat signature/);
  assert.deepEqual(filesKept(), [], 'a refused signature left a recording behind');
});

test('a refused take leaves nothing behind', async () => {
  clearKept();
  const { status, body } = await withRoute({}, formOf({ audio: wavOf({ ms: 1000, peak: 1 }) }));
  assert.equal(status, 422);
  assert.match(body.error, /Nothing reached the microphone/);
  assert.deepEqual(filesKept(), []);
});

test('who may record is asked before a byte is written', async () => {
  const thisYear = new Date().getFullYear();
  for (const [route, expected] of [
    [{ owns: false }, 404],
    [{ birthYear: null }, 403],
    [{ birthYear: thisYear - 15 }, 403],
  ]) {
    clearKept();
    const { status } = await withRoute(route, formOf({ audio: wavOf({ ms: 1000 }) }));
    assert.equal(status, expected, JSON.stringify(route));
    assert.deepEqual(filesKept(), [], `${JSON.stringify(route)} wrote a file`);
  }
});

test('over the cap is refused while it arrives, and leaves nothing', async () => {
  // The cap is whatever this server derives from its render budget — thirty
  // minutes at the defaults — so it is read rather than written into the test.
  clearKept();
  const tooBig = Buffer.alloc(narrationUpload.narrationMaxBytes() + 4096);
  const { status, body } = await withRoute({}, formOf({ audio: tooBig }));
  assert.equal(status, 413);
  assert.match(body.error,
    new RegExp(`longer than ${Math.floor(narrationUpload.narrationMaxSeconds() / 60)} minutes`));
  assert.deepEqual(filesKept(), []);
});

test('the app is told the cap rather than keeping a copy of it', async () => {
  // Item 5 of part two: the app had its own fifteen, kept in step with this
  // one by a comment. Both answers carry it, and the first matters most — a
  // tutorial nobody has recorded over is exactly the one about to be recorded.
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/narration' && l.route.methods.get
  );
  assert.ok(layer, 'GET /lessons/:id/narration must be mounted');
  const handler = layer.route.stack[layer.route.stack.length - 1].handle;

  const answers = [];
  for (const row of [
    { narration_filename: null },
    {
      narration_filename: 'narration_12_00000000000000ab.wav',
      narration_take_id: 'ab12',
      narration_ms: 1000,
      narration_markers: [0],
      narration_recorded_at: null,
    },
  ]) {
    const originalQuery = db.pool.query;
    db.pool.query = async () => ({ rows: [row], rowCount: 1 });
    const res = {
      statusCode: 200,
      body: null,
      status(code) { this.statusCode = code; return this; },
      json(payload) { this.body = payload; return this; },
    };
    try {
      await handler({ params: { id: '12' }, user: { id: 4 } }, res);
    } finally {
      db.pool.query = originalQuery;
    }
    answers.push(res.body);
  }

  const expected = narrationUpload.narrationMaxSeconds() * 1000;
  assert.equal(answers[0].status, 'none');
  assert.equal(answers[0].maxMs, expected);
  assert.equal(answers[1].status, 'ready');
  assert.equal(answers[1].maxMs, expected);
});

test('a new take is written to the row before the old one is deleted', async () => {
  clearKept();
  const old = 'narration_12_00000000000000aa.wav';
  fs.writeFileSync(path.join(NARRATION_DIR, old), 'the previous take');
  let oldExistedAtUpdate = null;

  const { status } = await withRoute({
    replaced: old,
    onUpdate: () => { oldExistedAtUpdate = fs.existsSync(path.join(NARRATION_DIR, old)); },
  }, formOf({ audio: wavOf({ ms: 1000 }) }));

  assert.equal(status, 201);
  assert.equal(oldExistedAtUpdate, true, 'the old file was gone before the row stopped naming it');
  assert.equal(fs.existsSync(path.join(NARRATION_DIR, old)), false, 'the old take was left behind');
  assert.equal(filesKept().length, 1);
});

test('a name from the row is never followed out of the directory', () => {
  const outside = path.join(path.dirname(NARRATION_DIR), `outside-${process.pid}.wav`);
  fs.writeFileSync(outside, 'not ours');
  try {
    narrationUpload.removeNarrationFile(`../${path.basename(outside)}`);
    assert.equal(fs.existsSync(outside), true);
  } finally {
    fs.unlinkSync(outside);
  }
});

test('deleting a tutorial deletes its recording, after the row', async () => {
  clearKept();
  const name = 'narration_12_00000000000000bb.wav';
  fs.writeFileSync(path.join(NARRATION_DIR, name), 'a take');
  let existedAtDelete = null;

  const original = db.pool.query;
  db.pool.query = async (sql) => {
    if (/DELETE FROM saved_lessons/.test(sql)) {
      existedAtDelete = fs.existsSync(path.join(NARRATION_DIR, name));
      assert.match(sql, /RETURNING id, narration_filename/);
      return { rows: [{ id: 12, narration_filename: name }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  try {
    const layer = lessonsRouter.stack.find(
      (l) => l.route && l.route.path === '/:id' && l.route.methods.delete,
    );
    const stack = layer.route.stack.map((s) => s.handle);
    await stack[stack.length - 1]({ params: { id: '12' }, user: { id: 4 } }, res);
  } finally {
    db.pool.query = original;
  }

  assert.equal(res.statusCode, 200);
  assert.equal(existedAtDelete, true);
  assert.equal(fs.existsSync(path.join(NARRATION_DIR, name)), false);
});

// ---------------------------------------------------------------- not by URL

test('nothing under uploads/narration is served, however it is spelt', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'uploads-'));
  fs.mkdirSync(path.join(dir, 'narration'));
  fs.writeFileSync(path.join(dir, 'narration', 'x.wav'), 'a voice');
  fs.writeFileSync(path.join(dir, 'recording_1.aac'), 'a room recording');

  const app = express();
  serveUploads(app, dir);
  const server = app.listen(0);
  try {
    const { port } = server.address();
    // Sent verbatim, not through `fetch`: a WHATWG URL resolves `.` and `..`
    // (and their %2E spellings) before the request leaves, so the server would
    // never see them — and a mutation deleting the normalisation survived for
    // exactly that reason. A client that does not normalise is the one to
    // guard against.
    const get = (p) => new Promise((resolve, reject) => {
      http.get({ host: '127.0.0.1', port, path: p }, (res) => {
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => resolve({ status: res.statusCode, body }));
      }).on('error', reject);
    });

    const rest = await get('/uploads/recording_1.aac');
    assert.equal(rest.status, 200, 'the rest of uploads/ is unchanged');
    for (const spelt of [
      '/uploads/narration/x.wav',
      '/uploads/%6Earration/x.wav',
      '/uploads/NARRATION/x.wav',
      '/uploads/./narration/x.wav',
      '/uploads/a/../narration/x.wav',
      '/uploads/a/%2E%2E/narration/x.wav',
      '/uploads//narration/x.wav',
      '/uploads/narration%5Cx.wav',
    ]) {
      const { status, body } = await get(spelt);
      assert.equal(status, 404, `${spelt} answered ${status}`);
      assert.notEqual(body, 'a voice', `${spelt} was served`);
    }
  } finally {
    server.close();
  }

  assert.equal(isPrivateUpload('/narration/x.wav'), true);
  assert.equal(isPrivateUpload('/%E0%A4%A'), true, 'a path that does not decode is not guessed about');
  assert.equal(isPrivateUpload('/recording_1.aac'), false);
});

// ---------------------------------------------------------------- phase 4

test('a take keeps its id, and a name that is not one is refused', async () => {
  clearKept();
  const kept = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }), takeId: 'ab12cd34ef567890' }));
  assert.equal(kept.status, 201, JSON.stringify(kept.body));
  assert.equal(kept.body.narration.takeId, 'ab12cd34ef567890');
  const update = kept.queries.find((q) => /UPDATE saved_lessons/.test(q.sql));
  assert.equal(update.values[5], 'ab12cd34ef567890');

  clearKept();
  const refused = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }), takeId: '../../x' }));
  assert.equal(refused.status, 400);
  assert.deepEqual(filesKept(), []);
});

test('the server says which take it holds, and says none plainly', async () => {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/narration' && l.route.methods.get,
  );
  assert.ok(layer, 'GET /:id/narration must be mounted');
  const handler = layer.route.stack[layer.route.stack.length - 1].handle;

  async function ask(rows) {
    const original = db.pool.query;
    db.pool.query = async () => ({ rows, rowCount: rows.length });
    const res = {
      statusCode: 200,
      body: null,
      status(code) { this.statusCode = code; return this; },
      json(payload) { this.body = payload; return this; },
    };
    try {
      await handler({ params: { id: '12' }, user: { id: 4 } }, res);
    } finally {
      db.pool.query = original;
    }
    return res;
  }

  const notYours = await ask([]);
  assert.equal(notYours.statusCode, 404);

  const none = await ask([{ narration_filename: null }]);
  assert.equal(none.statusCode, 200);
  // Since item 5 of part two the answer also says how long a take may be, so
  // an app about to record asks rather than keeping a copy. Still compared
  // whole: an answer that grows without anybody deciding it should is what
  // this assertion is for.
  assert.deepEqual(none.body, { status: 'none', maxMs: narrationUpload.narrationMaxSeconds() * 1000 });

  const ready = await ask([{
    narration_filename: 'narration_12_x.wav',
    narration_ms: 9100,
    narration_markers: [0, 3500, 7000],
    narration_take_id: 'ab12',
    narration_recorded_at: 't',
  }]);
  assert.equal(ready.body.status, 'ready');
  assert.equal(ready.body.takeId, 'ab12');
  assert.equal(ready.body.beats, 3);
  assert.equal(ready.body.filename, undefined, 'the file stays the server\'s business');
});

const FILM = [
  { timestampMs: 0, eventType: 'init', data: { fen: 'a', text: 'One.' } },
  { timestampMs: 2000, eventType: 'move', data: { fen: 'b' } },
  { timestampMs: 4000, eventType: 'move', data: { fen: 'c' } },
];

function storedTake(name = 'narration_12_00000000000000cc.wav') {
  fs.writeFileSync(path.join(NARRATION_DIR, name), 'a take');
  return {
    narration_filename: name,
    narration_ms: 9100,
    narration_markers: [0, 3500, 7000],
    narration_take_id: 'ab12',
  };
}

test('a recording retimes the film: each beat where it was spoken', () => {
  const row = storedTake();
  const judged = narrationUpload.recordingForFilm({ row, takeId: 'ab12', events: FILM });

  assert.equal(judged.ok, true, judged.error);
  assert.deepEqual(judged.events.map((e) => e.timestampMs), [0, 3500, 7000]);
  assert.deepEqual(judged.events.map((e) => e.data.spokenMs), [3500, 3500, 2100],
    'each caption is revealed across the time actually spent on its beat');
  assert.equal(judged.seconds, 10);
  assert.equal(judged.audioPath, path.join(NARRATION_DIR, row.narration_filename));
  assert.equal(judged.events[0].data.text, 'One.');
  assert.equal(FILM[1].timestampMs, 2000, 'the request\'s own events were rewritten in place');
  assert.equal(FILM[1].data.spokenMs, undefined);
});

test('a recording made against beats that have since moved is refused', () => {
  // The case no count can see, and the reason the column exists: three beats
  // before, three beats now, and one of them about another sentence. Both sides
  // must have a signature — a recording from before phase 5 carries none, and
  // it is judged by its beat count as it always was rather than thrown away for
  // a question it was never asked.
  const row = { ...storedTake(), narration_signature: 'a'.repeat(64) };

  const moved = narrationUpload.recordingForFilm({
    row, takeId: 'ab12', events: FILM, signature: 'b'.repeat(64),
  });
  assert.equal(moved.ok, false);
  assert.equal(moved.code, 'edited');
  assert.match(moved.error, /edited since this recording was made/);

  const same = narrationUpload.recordingForFilm({
    row, takeId: 'ab12', events: FILM, signature: 'a'.repeat(64),
  });
  assert.equal(same.ok, true, same.error);

  const older = narrationUpload.recordingForFilm({
    row: storedTake(), takeId: 'ab12', events: FILM, signature: 'b'.repeat(64),
  });
  assert.equal(older.ok, true, 'a recording from before phase 5 was thrown away');

  const unasked = narrationUpload.recordingForFilm({ row, takeId: 'ab12', events: FILM });
  assert.equal(unasked.ok, true, 'an app that sends no signature cannot be judged on one');
});

test('a recording that does not fit this film is refused, each for its own reason', () => {
  const row = storedTake();
  const cases = [
    [{ row: null }, 'none'],
    [{ row: { ...row, narration_filename: null } }, 'none'],
    [{ row, takeId: 'ffff' }, 'other'],
    [{ row, events: FILM.slice(0, 2) }, 'beats'],
    [{ row: { ...row, narration_filename: 'narration_12_gone.wav' } }, 'gone'],
  ];
  for (const [options, code] of cases) {
    const judged = narrationUpload.recordingForFilm({ takeId: 'ab12', events: FILM, ...options });
    assert.equal(judged.ok, false, `${code} was accepted`);
    assert.equal(judged.code, code);
    assert.ok(judged.error.length > 20, `${code} has no sentence`);
  }
});
