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

test('fifteen minutes is the most one recording may be', () => {
  const over = judge({ ms: 15 * 60 * 1000 + 40, peak: 0, markers: [0], beats: 1 });
  assert.equal(over.ok, false);
  assert.equal(over.status, 413);
  assert.match(over.error, /15:00 long.*at most 15 minutes/);

  assert.ok(narrationUpload.NARRATION_MAX_BYTES > 15 * 60 * BYTE_RATE,
    'the multer limit must leave room for a whole fifteen-minute take');
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

function formOf({ audio, markers = [0, 400], durationMs = 1000, beats = 2, takeId }) {
  const form = new FormData();
  if (takeId !== undefined) form.append('takeId', takeId);
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

test('over fifteen minutes is refused while it arrives, and leaves nothing', async () => {
  clearKept();
  const tooBig = Buffer.alloc(narrationUpload.NARRATION_MAX_BYTES + 4096);
  const { status, body } = await withRoute({}, formOf({ audio: tooBig }));
  assert.equal(status, 413);
  assert.match(body.error, /longer than 15 minutes/);
  assert.deepEqual(filesKept(), []);
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
  assert.deepEqual(none.body, { status: 'none' });

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
