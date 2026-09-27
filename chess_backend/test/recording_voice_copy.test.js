// recording_voice_copy.test.js — phase 8 of docs/PLAN-PRIPREMA.md: a
// recording's voice becomes the narration of the tutorial made from it.
//
// Gates:
//  1. who may give the tutorial a voice is asked before a byte is copied;
//  2. the recording must be the host's own, made in Preparation, and its sound
//     on disk — anything else reads as not found, and nothing is written;
//  3. the sound is COPIED (T4): the recording's file is never moved, changed
//     or deleted — not by the copy, not by a refused copy, not by the
//     tutorial's deletion;
//  4. the copy is judged as an upload is — the markers against the file's own
//     length — and a refused one leaves nothing behind;
//  5. the row says the voice is held to positions (D18), with the signature
//     (a take uploaded later is held to words again: narration_upload.test.js);
//  6. the film the app makes of a real recording lays over the copy
//     (fixtures/recording_tutorial_film.json, written by the app's test).

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';
const NARRATION_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'narration-copy-'));
const LESSON_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'lesson-sound-'));
process.env.NARRATION_DIR = NARRATION_DIR;
process.env.LESSON_RECORDING_DIR = LESSON_DIR;

const express = require('express');
const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const narrationUpload = require('../services/narrationUpload');

const FILM = JSON.parse(fs.readFileSync(
  path.join(__dirname, 'fixtures', 'recording_tutorial_film.json'), 'utf8'));

const RATE = 16000;

/// A 16 kHz mono 16-bit wav of [ms] milliseconds, loud enough to be heard.
function wavOf(ms, peak = 8000) {
  let dataBytes = Math.floor(ms * RATE * 2 / 1000);
  dataBytes -= dataBytes % 2;
  const data = Buffer.alloc(dataBytes);
  for (let i = 0; i + 1 < dataBytes; i += 2) data.writeInt16LE((i / 2) % 2 === 0 ? peak : -peak, i);
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + dataBytes, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(dataBytes, 40);
  return Buffer.concat([header, data]);
}

/// A recording's sound under the lesson folder, as `lessonRecording` keeps it.
function soundOf(ms, name = `lesson_${Math.random().toString(16).slice(2)}.wav`) {
  const bytes = wavOf(ms);
  fs.writeFileSync(path.join(LESSON_DIR, name), bytes);
  return { name, bytes };
}

function copiesKept() {
  return fs.readdirSync(NARRATION_DIR).filter((f) => f.startsWith('narration_'));
}

function clearCopies() {
  for (const f of fs.readdirSync(NARRATION_DIR)) fs.unlinkSync(path.join(NARRATION_DIR, f));
}

const SIGNATURE = 'b'.repeat(64);

/// The route's own stages, in the router's own order.
function copyStages() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/narration/from-recording' && l.route.methods.post,
  );
  assert.ok(layer, 'POST /:id/narration/from-recording must be mounted');
  const names = layer.route.stack.map((s) => s.handle.name);
  const gate = names.indexOf('narrationGate');
  const attach = names.indexOf('attachRecordingVoice');
  assert.ok(gate !== -1 && attach !== -1, 'the gate and the copy must both be on the route');
  assert.ok(gate < attach, 'who may record is asked before anything is copied');
  return layer.route.stack.map((s) => s.handle)
    .filter((h) => ['narrationGate', 'attachRecordingVoice'].includes(h.name));
}

/// Stubs the database: a tutorial 12 of user 4, and whatever recording the
/// case describes. Returns what was asked.
async function withRoute({
  owns = true, recording, birthYear = 1980, replaced = null, updated = 1,
} = {}, body) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    if (/SELECT id FROM saved_lessons/.test(sql)) {
      return owns ? { rows: [{ id: 12 }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/birth_year/.test(sql)) return { rows: [{ birth_year: birthYear }], rowCount: 1 };
    if (/FROM session_recordings/.test(sql)) {
      // The host's own, and nobody else's: the stub answers only the id and
      // host the query was actually asked about.
      const match = recording && values[0] === recording.id && values[1] === recording.host_id;
      return match ? { rows: [recording], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/UPDATE saved_lessons/.test(sql)) {
      return updated
        ? { rows: [{ replaced, narration_recorded_at: '2026-09-27T12:00:00.000Z' }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    }
    return { rows: [], rowCount: 0 };
  };
  const app = express();
  app.use(express.json());
  app.post(
    '/lessons/:id/narration/from-recording',
    (req, _res, next) => { req.user = { id: 4 }; next(); },
    ...copyStages(),
  );
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/lessons/12/narration/from-recording`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    return { status: res.status, body: await res.json(), queries };
  } finally {
    server.close();
    db.pool.query = original;
  }
}

function recordingRow(sound, ms, rest = {}) {
  return { id: 31, host_id: 4, source: 'preparation', audio_file: sound.name, duration_ms: ms, ...rest };
}

test('a recording\'s voice is copied, judged and named by the row as held to positions', async () => {
  clearCopies();
  const sound = soundOf(2000);
  const { status, body, queries } = await withRoute(
    { recording: recordingRow(sound, 2000) },
    { recordingId: 31, markersMs: [0, 700, 1400], beats: 3, signature: SIGNATURE },
  );
  assert.equal(status, 201, JSON.stringify(body));
  assert.deepEqual(body.narration, {
    ms: 2000, beats: 3, follows: 'positions', recordedAt: '2026-09-27T12:00:00.000Z',
  });

  const kept = copiesKept();
  assert.equal(kept.length, 1);
  assert.match(kept[0], /^narration_12_[0-9a-f]{16}\.wav$/);
  assert.ok(fs.readFileSync(path.join(NARRATION_DIR, kept[0])).equals(sound.bytes),
    'the copy is the recording\'s sound, byte for byte');
  assert.ok(fs.readFileSync(path.join(LESSON_DIR, sound.name)).equals(sound.bytes),
    'and the recording keeps its own');

  const update = queries.find((q) => /UPDATE saved_lessons/.test(q.sql));
  assert.equal(update.values[1], kept[0]);
  assert.equal(update.values[2], 2000);
  assert.equal(update.values[3], '[0,700,1400]');
  assert.equal(update.values[5], SIGNATURE);
  assert.equal(update.values[6], 'positions');
  assert.match(update.sql, /narration_take_id = NULL/, 'no device holds a take of it');
  assert.match(update.sql, /FOR UPDATE/, 'the old name is read with the row locked');
  assert.match(update.sql, /\(user_id = \$5 OR trainer_id = \$5\)/, 'only the account\'s own tutorial');
});

test('the recording asked about is the host\'s own: the query names the account', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const { queries } = await withRoute(
    { recording: recordingRow(sound, 1000) },
    { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE },
  );
  const asked = queries.find((q) => /FROM session_recordings/.test(q.sql));
  assert.match(asked.sql, /host_id = \$2/);
  assert.deepEqual(asked.values, [31, 4]);
});

test('another host\'s recording, a room recording or a missing sound is not found, and nothing is copied', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const body = { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE };

  const theirs = await withRoute({ recording: recordingRow(sound, 1000, { host_id: 9 }) }, body);
  assert.equal(theirs.status, 404);
  assert.equal(theirs.body.error, 'Recording not found.');

  const room = await withRoute({ recording: recordingRow(sound, 1000, { source: 'room' }) }, body);
  assert.equal(room.status, 404);

  const gone = await withRoute({ recording: recordingRow({ name: 'lesson_gone.wav' }, 1000) }, body);
  assert.equal(gone.status, 404);
  assert.match(gone.body.error, /sound is missing/);

  assert.deepEqual(copiesKept(), []);
  for (const r of [theirs, room, gone]) {
    assert.ok(!r.queries.some((q) => /UPDATE saved_lessons/.test(q.sql)));
  }
});

test('who may record is asked before a byte is copied', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const body = { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE };

  const notYours = await withRoute({ owns: false, recording: recordingRow(sound, 1000) }, body);
  assert.equal(notYours.status, 404);
  const minor = await withRoute({ birthYear: new Date().getFullYear() - 15, recording: recordingRow(sound, 1000) }, body);
  assert.equal(minor.status, 403);

  assert.deepEqual(copiesKept(), []);
  for (const r of [notYours, minor]) {
    assert.ok(!r.queries.some((q) => /FROM session_recordings/.test(q.sql)),
      'the recording is not even looked up');
  }
});

test('a copy whose markers do not fit its sound is refused and removed; the recording stays', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const cases = [
    [{ markersMs: [0, 400], beats: 3 }, /stops at beat 2 of 3/],
    [{ markersMs: [0, 1000], beats: 2 }, /last beat starts after the recording ends/],
    [{ markersMs: [100, 400], beats: 2 }, /first beat does not start/],
    [{ markersMs: 'nope', beats: 2 }, /without its beats/],
  ];
  for (const [fields, expected] of cases) {
    const r = await withRoute({ recording: recordingRow(sound, 1000) },
      { recordingId: 31, signature: SIGNATURE, ...fields });
    assert.equal(r.status, 400, JSON.stringify(fields));
    assert.match(r.body.error, expected);
    assert.ok(!r.queries.some((q) => /UPDATE saved_lessons/.test(q.sql)));
  }
  assert.deepEqual(copiesKept(), []);
  assert.ok(fs.readFileSync(path.join(LESSON_DIR, sound.name)).equals(sound.bytes));
});

test('a recording whose row says another length than its sound is refused', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const r = await withRoute({ recording: recordingRow(sound, 1500) },
    { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE });
  assert.equal(r.status, 400);
  assert.match(r.body.error, /arrived incomplete/);
  assert.deepEqual(copiesKept(), []);
});

test('a copy without a signature is refused before anything is copied', async () => {
  clearCopies();
  const sound = soundOf(1000);
  for (const signature of [undefined, '', 'x'.repeat(64)]) {
    const r = await withRoute({ recording: recordingRow(sound, 1000) },
      { recordingId: 31, markersMs: [0, 400], beats: 2, signature });
    assert.equal(r.status, 400);
    assert.match(r.body.error, /not signed/);
  }
  assert.deepEqual(copiesKept(), []);
});

test('the tutorial\'s previous narration is deleted after the row stops naming it', async () => {
  clearCopies();
  fs.writeFileSync(path.join(NARRATION_DIR, 'narration_12_old.wav'), wavOf(500));
  const sound = soundOf(1000);
  const r = await withRoute({ recording: recordingRow(sound, 1000), replaced: 'narration_12_old.wav' },
    { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE });
  assert.equal(r.status, 201);
  assert.ok(!fs.existsSync(path.join(NARRATION_DIR, 'narration_12_old.wav')));
  assert.equal(copiesKept().length, 1);
});

test('a tutorial deleted between the gate and the write leaves no copy', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const r = await withRoute({ recording: recordingRow(sound, 1000), updated: 0 },
    { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE });
  assert.equal(r.status, 404);
  assert.deepEqual(copiesKept(), []);
});

test('deleting the tutorial deletes its copy and leaves the recording\'s sound on disk', async () => {
  clearCopies();
  const sound = soundOf(1000);
  const made = await withRoute({ recording: recordingRow(sound, 1000) },
    { recordingId: 31, markersMs: [0, 400], beats: 2, signature: SIGNATURE });
  assert.equal(made.status, 201);
  const [copy] = copiesKept();

  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id' && l.route.methods.delete,
  );
  const original = db.pool.query;
  db.pool.query = async () => ({ rows: [{ id: 12, narration_filename: copy, video_filename: null }], rowCount: 1 });
  const app = express();
  app.delete('/lessons/:id', (req, _res, next) => { req.user = { id: 4 }; next(); },
    ...layer.route.stack.map((s) => s.handle).filter((h) => h.name !== 'authenticateToken'));
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/lessons/12`, { method: 'DELETE' });
    assert.equal(res.status, 200);
  } finally {
    server.close();
    db.pool.query = original;
  }
  assert.deepEqual(copiesKept(), [], 'the tutorial\'s own copy went with it');
  assert.ok(fs.readFileSync(path.join(LESSON_DIR, sound.name)).equals(sound.bytes),
    'the recording\'s sound did not');
});

test('the film the app makes of a real recording lays over the copied voice', async () => {
  // fixtures/recording_tutorial_film.json is the app's own output for the
  // recording „proba 2" — five parts, 28 beats, 174.6 s of sound.
  clearCopies();
  const sound = soundOf(FILM.durationMs);
  const made = await withRoute({ recording: recordingRow(sound, FILM.durationMs) },
    { recordingId: 31, markersMs: FILM.markersMs, beats: FILM.beats, signature: FILM.signature });
  assert.equal(made.status, 201, JSON.stringify(made.body));
  const update = made.queries.find((q) => /UPDATE saved_lessons/.test(q.sql));

  // The row as the export reads it, and the film the export is sent.
  const row = {
    narration_filename: update.values[1],
    narration_ms: update.values[2],
    narration_markers: JSON.parse(update.values[3]),
    narration_take_id: null,
    narration_signature: update.values[5],
  };
  const film = narrationUpload.recordingForFilm({ row, takeId: null, signature: FILM.signature, events: FILM.events });
  assert.equal(film.ok, true, film.error);
  assert.equal(film.events.length, FILM.beats);
  assert.deepEqual(film.events.map((e) => e.timestampMs), FILM.markersMs);
  assert.equal(film.seconds, Math.ceil(FILM.durationMs / 1000));
  // Every beat is on screen for the time until the next one is spoken.
  for (let i = 0; i < film.events.length; i++) {
    const next = i + 1 < FILM.markersMs.length ? FILM.markersMs[i + 1] : FILM.durationMs;
    assert.equal(film.events[i].data.spokenMs, next - FILM.markersMs[i]);
  }

  // A film whose beats moved is refused, as for any take.
  const moved = narrationUpload.recordingForFilm({
    row, takeId: null, signature: 'c'.repeat(64), events: FILM.events,
  });
  assert.equal(moved.ok, false);
  assert.equal(moved.code, 'edited');
});

test('the synthesised film the app sends carries no time from the recording', () => {
  // The app's reading-speed film is 112 s where the recording is 174.6: its
  // times are the captions', not the voice's. None of its beats but the first
  // starts where a marker does.
  const times = FILM.events.map((e) => e.timestampMs);
  const shared = times.filter((t, i) => i > 0 && FILM.markersMs.includes(t));
  assert.deepEqual(shared, []);
  assert.ok(FILM.seconds * 1000 < FILM.durationMs);
});
