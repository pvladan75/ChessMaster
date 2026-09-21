// lesson_recording.test.js
// A lesson recorded alone in Preparation — phase 5b.2 of docs/PLAN-SESIJA.md.
//
// The writer and the reader of a recording that, unlike the room's, carries a
// voice on purpose: an adult's, alone at their own board. What is checked is
// what the narration upload checks — eighteen and a known age before multer
// takes a byte, the wav read from its own header, the events inside the audio —
// plus the one thing the room never had: the sound is private, and reaches its
// reader only through a short-lived link bound to the file.

const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';
const LESSON_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'lesson-test-'));
process.env.LESSON_RECORDING_DIR = LESSON_DIR;

const express = require('express');
const db = require('../db');
const recordingsRouter = require('../routes/recordings');
const lessonRecording = require('../services/lessonRecording');
const { signDownloadToken } = require('../middleware/auth');
const { isPrivateUpload } = require('../middleware/uploadsStatic');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const RATE = 16000;

function wavOf({ ms, peak = 8000, sampleRate = RATE }) {
  const byteRate = sampleRate * 2;
  let dataBytes = Math.floor(ms * byteRate / 1000);
  dataBytes -= dataBytes % 2;
  const data = Buffer.alloc(dataBytes);
  for (let i = 0; i + 1 < dataBytes; i += 2) {
    data.writeInt16LE((i / 2) % 2 === 0 ? peak : -peak, i);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + dataBytes, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(dataBytes, 40);
  return Buffer.concat([header, data]);
}

const OPENING = { timestampMs: 0, eventType: 'init', data: { fen: 'start', pgn: '' } };

function events(...rest) {
  return [OPENING, ...rest];
}

// ---------------------------------------------------------------- the events

test('a lesson\'s events are what both readers replay, inside the audio, in order', () => {
  const ok = lessonRecording.judgeLessonEvents({
    events: events(
      { timestampMs: 0, eventType: 'move', data: { fen: 'a' } },
      { timestampMs: 400, eventType: 'arrow_drawn', data: { arrows: [] } },
      { timestampMs: 400, eventType: 'move', data: { fen: 'b' } },
    ),
    durationMs: 1000,
  });
  assert.equal(ok.ok, true, ok.error);
  assert.equal(ok.events.length, 4);

  const cases = [
    [[], /without its board/],
    [[{ ...OPENING, timestampMs: 5 }], /does not open on the board/],
    [[{ ...OPENING, eventType: 'move' }], /does not open on the board/],
    [[OPENING, { timestampMs: 300, eventType: 'fen_change', data: {} }], /cannot replay/],
    [[OPENING, { timestampMs: 300, eventType: 'lesson_loaded', data: {} }], /cannot replay/],
    [[OPENING, { timestampMs: 700, eventType: 'move', data: {} },
      { timestampMs: 500, eventType: 'move', data: {} }], /out of order/],
    [[OPENING, { timestampMs: 1001, eventType: 'move', data: {} }], /after the recording ends/],
    [[OPENING, { timestampMs: 1.5, eventType: 'move', data: {} }], /could not be read/],
    [[OPENING, { timestampMs: 10, eventType: 'move', data: 'x' }], /could not be read/],
  ];
  for (const [list, expected] of cases) {
    const judged = lessonRecording.judgeLessonEvents({ events: list, durationMs: 1000 });
    assert.equal(judged.ok, false, `${JSON.stringify(list)} was accepted`);
    assert.match(judged.error, expected, JSON.stringify(list));
  }
});

test('the events arrive as a multipart field, so text is read too', () => {
  const judged = lessonRecording.judgeLessonEvents({
    events: JSON.stringify(events()), durationMs: 10,
  });
  assert.equal(judged.ok, true, judged.error);
  assert.equal(lessonRecording.judgeLessonEvents({ events: '{no', durationMs: 10 }).ok, false);
});

// ---------------------------------------------------------------- privacy

test('the lessons folder is never served by URL', () => {
  assert.equal(isPrivateUpload('/lessons/lesson_4_ab.wav'), true);
  assert.equal(isPrivateUpload('/LESSONS/x.wav'), true);
  assert.equal(isPrivateUpload('/recording_1.aac'), false,
    'the old room files are not moved by this phase');
});

// ---------------------------------------------------------------- the route

/// The writer's three stages in the router's own order: the gate must come
/// before multer, or a refused voice is on the disk before it is refused.
function lessonStages() {
  const layer = recordingsRouter.stack.find(
    (l) => l.route && l.route.path === '/lesson' && l.route.methods.post,
  );
  assert.ok(layer, 'POST /recordings/lesson must be mounted');
  const names = layer.route.stack.map((s) => s.handle.name);
  const stages = ['lessonGate', 'receiveLesson', 'saveLesson'];
  const at = stages.map((n) => names.indexOf(n));
  assert.ok(at.every((i) => i >= 0), `stages on the route: ${names.join(', ')}`);
  assert.deepEqual([...at].sort((a, b) => a - b), at, 'gate, then multer, then the keeper');
  return stages.map((n) => layer.route.stack.find((s) => s.handle.name === n).handle);
}

function filesKept() {
  return fs.readdirSync(LESSON_DIR).filter((f) => f.startsWith('lesson_'));
}

function clearKept() {
  for (const f of fs.readdirSync(LESSON_DIR)) fs.unlinkSync(path.join(LESSON_DIR, f));
}

async function withRoute({ birthYear = 1980 } = {}, body) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    if (/birth_year/.test(sql)) return { rows: [{ birth_year: birthYear }], rowCount: 1 };
    if (/INSERT INTO session_recordings/.test(sql)) {
      return { rows: [{ id: 77, title: values[1], created_at: '2026-09-22T12:00:00.000Z' }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
  const app = express();
  app.post('/recordings/lesson', (req, _res, next) => { req.user = { id: 4 }; next(); }, ...lessonStages());
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/recordings/lesson`, { method: 'POST', body });
    return { status: res.status, body: await res.json(), queries };
  } finally {
    server.close();
    db.pool.query = original;
  }
}

function formOf({ audio, list = events({ timestampMs: 400, eventType: 'move', data: { fen: 'b' } }),
  durationMs = 1000, title = 'Rook endings' }) {
  const form = new FormData();
  if (title !== undefined) form.append('title', title);
  form.append('events', JSON.stringify(list));
  form.append('durationMs', String(durationMs));
  if (audio) form.append('audio', new Blob([audio]), 'take.wav');
  return form;
}

test('a whole lesson is kept, private, and the row names it', async () => {
  clearKept();
  const { status, body, queries } = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }) }));
  assert.equal(status, 201, JSON.stringify(body));
  assert.equal(body.recording.id, 77);

  const kept = filesKept();
  assert.equal(kept.length, 1);
  assert.match(kept[0], /^lesson_4_[0-9a-f]{16}\.wav$/);

  const insert = queries.find((q) => /INSERT INTO session_recordings/.test(q.sql));
  assert.match(insert.sql, /'preparation'/);
  assert.match(insert.sql, /room_id/);
  assert.equal(insert.values[0], 4, 'the host is the caller');
  assert.equal(insert.values[1], 'Rook endings');
  assert.equal(insert.values[2], kept[0], 'audio_file names the kept file');
  assert.equal(insert.values[3], 1000, 'duration_ms from the wav header');
  assert.equal(JSON.parse(insert.values[4]).length, 2);
  assert.doesNotMatch(insert.sql, /audio_url/, 'a private file is never given a public path');
});

test('an adult of unknown age, and a minor, are refused before a byte is kept', async () => {
  for (const birthYear of [null, new Date().getFullYear() - 16]) {
    clearKept();
    const { status, body, queries } = await withRoute({ birthYear }, formOf({ audio: wavOf({ ms: 1000 }) }));
    assert.equal(status, 403, `${birthYear}: ${JSON.stringify(body)}`);
    assert.deepEqual(filesKept(), [], 'a refused voice must not be on the disk');
    assert.equal(queries.some((q) => /INSERT/.test(q.sql)), false);
  }
});

test('a file that is not this app\'s recording is refused and deleted', async () => {
  clearKept();
  const other = await withRoute({}, formOf({ audio: wavOf({ ms: 1000, sampleRate: 44100 }) }));
  assert.equal(other.status, 400);
  assert.match(other.body.error, /format/);
  assert.deepEqual(filesKept(), []);

  const short = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }), durationMs: 1600 }));
  assert.equal(short.status, 400);
  assert.match(short.body.error, /incomplete/);
  assert.deepEqual(filesKept(), []);

  const silent = await withRoute({}, formOf({ audio: wavOf({ ms: 1000, peak: 1 }) }));
  assert.equal(silent.status, 422);
  assert.deepEqual(filesKept(), []);
});

test('events that do not fit the audio are refused and the file deleted', async () => {
  clearKept();
  const { status, body } = await withRoute({}, formOf({
    audio: wavOf({ ms: 1000 }),
    list: events({ timestampMs: 5000, eventType: 'move', data: { fen: 'x' } }),
  }));
  assert.equal(status, 400);
  assert.match(body.error, /after the recording ends/);
  assert.deepEqual(filesKept(), []);
});

test('a lesson needs a title and a file', async () => {
  clearKept();
  const untitled = await withRoute({}, formOf({ audio: wavOf({ ms: 1000 }), title: '   ' }));
  assert.equal(untitled.status, 400);
  assert.match(untitled.body.error, /title/);
  assert.deepEqual(filesKept(), []);

  const empty = await withRoute({}, formOf({}));
  assert.equal(empty.status, 400);
});

// ---------------------------------------------------------------- the reader

async function withReader(fn) {
  const app = express();
  app.use('/recordings', recordingsRouter);
  const server = app.listen(0);
  try {
    await fn(server.address().port);
  } finally {
    server.close();
  }
}

test('the sound is played through a link bound to its file', async () => {
  clearKept();
  const name = 'lesson_4_0123456789abcdef.wav';
  fs.writeFileSync(path.join(LESSON_DIR, name), wavOf({ ms: 100 }));
  await withReader(async (port) => {
    const base = `http://127.0.0.1:${port}/recordings/lesson-audio/${name}`;
    const good = await fetch(`${base}?token=${encodeURIComponent(signDownloadToken(4, name))}`);
    assert.equal(good.status, 200);
    assert.match(good.headers.get('content-type'), /audio\/(wav|x-wav|wave)/);

    const other = await fetch(`${base}?token=${encodeURIComponent(signDownloadToken(4, 'lesson_4_other.wav'))}`);
    assert.equal(other.status, 403, 'a link for one file must not open another');

    const none = await fetch(base);
    assert.equal(none.status, 401);
  });
});

test('a reader is handed a signed link, never the file\'s name alone', () => {
  const url = lessonRecording.lessonAudioUrl({ audio_file: 'lesson_4_ab.wav' }, 9);
  assert.match(url, /^\/recordings\/lesson-audio\/lesson_4_ab\.wav\?token=/);
  assert.equal(lessonRecording.lessonAudioUrl({ audio_file: null }, 9), null);
});

// ---------------------------------------------------------------- the table

const skip = skipUnlessDatabase();

describe('the recordings table on a real database', { skip: skip ? skip.skip : false }, () => {
  test('a recording made in Preparation has no room, and says where it came from', async () => {
    const testDb = await freshDatabase();
    try {
      const { pool } = testDb;
      const user = await pool.query(
        "INSERT INTO users (email, password_hash, name) VALUES ('t@example.test', 'x', 'T') RETURNING id");
      const row = await pool.query(
        `INSERT INTO session_recordings
           (room_id, source, host_id, title, audio_file, duration_ms, timeline_json, participants)
         VALUES (NULL, 'preparation', $1, 'x', 'lesson_1_a.wav', 1000, '[]', '{}')
         RETURNING room_id, source, duration_ms`, [user.rows[0].id]);
      assert.deepEqual(row.rows[0], { room_id: null, source: 'preparation', duration_ms: 1000 });

      const old = await pool.query(
        `INSERT INTO session_recordings (room_id, host_id, title, timeline_json)
         VALUES ('123456', $1, 'room', '[]') RETURNING source`, [user.rows[0].id]);
      assert.equal(old.rows[0].source, 'room', 'a room recording keeps saying so');
    } finally {
      await testDb.drop();
    }
  });
});

test('reading a lesson hands the signed link out, and never the file name', async () => {
  const original = db.pool.query;
  db.pool.query = async () => ({
    rows: [{ id: 77, host_id: 9, title: 'x', audio_url: null, audio_file: 'lesson_9_ab.wav', timeline_json: [],
      video_url: '/recordings/export-download/x.mp4?token=host' }],
    rowCount: 1,
  });
  const app = express();
  app.use((req, _res, next) => { req.headers.authorization = `Bearer ${require('jsonwebtoken').sign({ id: 9 }, process.env.JWT_SECRET)}`; next(); });
  app.use('/recordings', recordingsRouter);
  const server = app.listen(0);
  try {
    const res = await fetch(`http://127.0.0.1:${server.address().port}/recordings/77`);
    const body = await res.json();
    assert.equal(res.status, 200, JSON.stringify(body));
    assert.match(body.audio_url, /^\/recordings\/lesson-audio\/lesson_9_ab\.wav\?token=/);
    assert.equal('audio_file' in body, false, 'the private name stays on the server');
    assert.equal('video_url' in body, false, "the stored link carries the host's token");
  } finally {
    server.close();
    db.pool.query = original;
  }
});

test('the app is told in advance whether this account may record, and for how long', async () => {
  const original = db.pool.query;
  for (const [birthYear, allowed] of [[1980, true], [new Date().getFullYear() - 16, false], [null, false]]) {
    db.pool.query = async (sql) => (/birth_year/.test(sql)
      ? { rows: [{ birth_year: birthYear }], rowCount: 1 }
      : { rows: [{ id: 9 }], rowCount: 1 });
    const app = express();
    app.use((req, _res, next) => { req.headers.authorization = `Bearer ${require('jsonwebtoken').sign({ id: 9 }, process.env.JWT_SECRET)}`; next(); });
    app.use('/recordings', recordingsRouter);
    const server = app.listen(0);
    try {
      const res = await fetch(`http://127.0.0.1:${server.address().port}/recordings/lesson-limits`);
      const body = await res.json();
      assert.equal(res.status, 200, JSON.stringify(body));
      assert.equal(body.allowed, allowed, String(birthYear));
      assert.equal(body.maxMs, require('../services/narrationUpload').narrationMaxSeconds() * 1000);
      if (!allowed) assert.match(body.reason, /adult|birth year/);
    } finally {
      server.close();
    }
  }
  db.pool.query = original;
});
