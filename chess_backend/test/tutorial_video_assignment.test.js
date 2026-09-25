// tutorial_video_assignment.test.js — phase 2 of docs/PLAN-TUTORIJAL-VIDEO.md:
// a tutorial reaches a student as its film, and the download is recorded.
//
// The download cases run over a **real HTTP connection**: whether the file's
// last byte went out, whether a transfer was cut off, what a `HEAD` or a range
// does — none of that exists on a fake `res`. The database is a stub here; the
// homework gate and the „recorded once" rule are proved on a real database in
// `tutorial_video_db.test.js`.
//
// Gates:
//  1. a tutorial without a film is not sent; one with a film is one item;
//  2. the student's link is theirs, for their assignment and that file;
//  3. a whole download records, and so does the tail of a resumed one; a
//     `HEAD`, a range short of the end and an aborted transfer record nothing;
//  4. a link to a replaced film, to another file, of another purpose or of a
//     deleted account records nothing and serves nothing;
//  5. the student's detail says what the film is and carries no part;
//  6. the retention timer keeps a film a tutorial names;
//  7. a lone film does not wait in the trainer's review queue.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const express = require('express');
const jwt = require('jsonwebtoken');
const db = require('../db');
const assignmentsRouter = require('../routes/assignments');
const assignments = require('../services/assignmentService');
const { deliveredLastByte, EXPORTS_DIR } = require('../services/tutorialFilm');
const { cleanupOldExports } = require('../services/retentionService');
const trainerPanel = require('../services/trainerPanelService');

const STUDENT = 9;
const TRAINER = 5;
const ASSIGNMENT = 70;
const SECRET = process.env.JWT_SECRET;

// ---- a film on disk ---------------------------------------------------------

/// Large enough that an abort after the first chunk leaves most of it unsent.
const FILM_BYTES = 12 * 1024 * 1024;

function filmOnDisk() {
  fs.mkdirSync(EXPORTS_DIR, { recursive: true });
  const name = `tutorial_test_${process.pid}_${crypto.randomBytes(4).toString('hex')}.mp4`;
  fs.writeFileSync(path.join(EXPORTS_DIR, name), Buffer.alloc(FILM_BYTES, 7));
  return name;
}

// ---- the database, as far as these routes ask it ------------------------------

/// Answers the queries the video routes send, from [state]. Every query is
/// kept, so a case can ask whether the download was written.
function stubDatabase(state) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    if (/FROM users WHERE id/.test(sql)) {
      return state.accountGone ? { rows: [], rowCount: 0 } : { rows: [{ role: 'user' }], rowCount: 1 };
    }
    if (/AS locked/.test(sql)) return { rows: [{ locked: false, blocked_by: null }], rowCount: 1 };
    if (/FROM assignments a\s+LEFT JOIN saved_lessons l/.test(sql)) {
      const mine = values[0] === ASSIGNMENT && values[1] === STUDENT;
      if (!mine) return { rows: [], rowCount: 0 };
      return {
        rows: [{ id: ASSIGNMENT, title: 'Broken pawns', video_filename: state.film, video_seconds: 194 }],
        rowCount: 1,
      };
    }
    if (/UPDATE assignment_items/.test(sql)) {
      state.recorded = (state.recorded || 0) + 1;
      return { rows: [{ id: 1 }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
  return { queries, restore: () => { db.pool.query = original; } };
}

async function withServer(fn) {
  const app = express();
  app.use(express.json());
  app.use('/assignments', assignmentsRouter);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await fn(server.address().port);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

/// One request. [abortAfterFirstChunk] destroys the connection as soon as the
/// first bytes arrive, which is a student closing the download.
function request(port, urlPath, { method = 'GET', headers = {}, abortAfterFirstChunk = false } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path: urlPath, method, headers }, (res) => {
      let bytes = 0;
      let body = '';
      res.on('data', (chunk) => {
        bytes += chunk.length;
        if (bytes < 4096) body += chunk.toString('utf8');
        if (abortAfterFirstChunk) {
          req.destroy();
          resolve({ status: res.statusCode, bytes, aborted: true });
        }
      });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, bytes, body }));
    });
    req.on('error', (err) => { if (!abortAfterFirstChunk) reject(err); });
    req.end();
  });
}

/// Waits a moment for the server's `res.download` callback, which runs after
/// the client has what it asked for.
const settle = (ms = 400) => new Promise((resolve) => setTimeout(resolve, ms));

function videoToken({ purpose = 'assignment-video', assignment = ASSIGNMENT, file, id = STUDENT }) {
  return jwt.sign({ purpose, id, assignment, file }, SECRET, { expiresIn: '30m' });
}

function downloadPath(file, token = videoToken({ file })) {
  return `/assignments/video-download/${encodeURIComponent(file)}?token=${encodeURIComponent(token)}`;
}

// ---- 1. sending ---------------------------------------------------------------

/// A pool for `createLessonAssignment`: an accepted student, one tutorial
/// whose film is [film], and a transaction whose statements are kept.
function sendPool({ film }) {
  const inTransaction = [];
  return {
    inTransaction,
    async query(sql) {
      if (/FROM trainer_students/.test(sql)) return { rows: [{ '?column?': 1 }], rowCount: 1 };
      if (/FROM saved_lessons/.test(sql)) {
        return { rows: [{ id: 3, title: 'Broken pawns', video_filename: film }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    },
    async connect() {
      return {
        async query(sql, values) {
          inTransaction.push({ sql, values });
          if (/INSERT INTO assignments/.test(sql)) {
            return { rows: [{ id: ASSIGNMENT, student_id: STUDENT, title: 'Broken pawns' }], rowCount: 1 };
          }
          return { rows: [], rowCount: 0 };
        },
        release() {},
      };
    },
  };
}

test('a tutorial with no film is not sent, and the refusal says to export it', async () => {
  const pool = sendPool({ film: null });
  const result = await assignments.createLessonAssignment(pool, {
    trainerId: TRAINER, studentId: STUDENT, lessonId: 3,
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 422);
  assert.match(result.reason, /Export the video first/);
  assert.equal(pool.inTransaction.length, 0, 'nothing is written');
});

test('a tutorial whose film file is gone is not sent either', async () => {
  const pool = sendPool({ film: 'tutorial_never_rendered_here.mp4' });
  const result = await assignments.createLessonAssignment(pool, {
    trainerId: TRAINER, studentId: STUDENT, lessonId: 3,
  });
  assert.equal(result.ok, false);
  assert.match(result.reason, /no video yet/);
});

test('a tutorial with a film is sent as one item, whatever its parts', async () => {
  const film = filmOnDisk();
  try {
    const pool = sendPool({ film });
    const result = await assignments.createLessonAssignment(pool, {
      trainerId: TRAINER, studentId: STUDENT, lessonId: 3,
    });
    assert.equal(result.ok, true);
    assert.equal(result.assignment.itemCount, 1);
    const items = pool.inTransaction.filter((q) => /INSERT INTO assignment_items/.test(q.sql));
    assert.equal(items.length, 1);
    assert.deepEqual(items[0].values, [ASSIGNMENT], 'one row, at position 0');
  } finally {
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

// ---- 2 – 4. the link and the download ----------------------------------------------

test('the student gets a link for their assignment and that film', async () => {
  const film = filmOnDisk();
  const state = { film };
  const database = stubDatabase(state);
  try {
    await withServer(async (port) => {
      const bearer = jwt.sign({ id: STUDENT }, SECRET);
      const res = await request(port, `/assignments/${ASSIGNMENT}/video`, {
        headers: { Authorization: `Bearer ${bearer}` },
      });
      assert.equal(res.status, 200);
      const body = JSON.parse(res.body);
      assert.equal(body.status, 'ready');
      assert.equal(body.seconds, 194);
      const token = new URL(body.downloadUrl, 'http://x').searchParams.get('token');
      const payload = jwt.verify(token, SECRET);
      assert.equal(payload.purpose, 'assignment-video');
      assert.equal(payload.id, STUDENT);
      assert.equal(payload.assignment, ASSIGNMENT);
      assert.equal(payload.file, film);
      assert.equal(state.recorded, undefined, 'asking for the link records nothing');
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('somebody who is not the student gets no link', async () => {
  const film = filmOnDisk();
  const database = stubDatabase({ film });
  try {
    await withServer(async (port) => {
      const bearer = jwt.sign({ id: TRAINER }, SECRET);
      const res = await request(port, `/assignments/${ASSIGNMENT}/video`, {
        headers: { Authorization: `Bearer ${bearer}` },
      });
      assert.equal(res.status, 404);
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('a whole download is recorded, after the last byte went out', async () => {
  const film = filmOnDisk();
  const state = { film };
  const database = stubDatabase(state);
  try {
    await withServer(async (port) => {
      const res = await request(port, downloadPath(film));
      assert.equal(res.status, 200);
      assert.equal(res.bytes, FILM_BYTES, 'the whole film');
      await settle();
      assert.equal(state.recorded, 1);
      const write = database.queries.find((q) => /UPDATE assignment_items/.test(q.sql));
      assert.deepEqual(write.values, [ASSIGNMENT, STUDENT], 'this assignment, this student');
      assert.match(write.sql, /attempted_at IS NULL/, 'the first download only');
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('a download cut off halfway records nothing', async () => {
  const film = filmOnDisk();
  const state = { film };
  const database = stubDatabase(state);
  try {
    await withServer(async (port) => {
      const res = await request(port, downloadPath(film), { abortAfterFirstChunk: true });
      assert.ok(res.bytes < FILM_BYTES, 'the transfer really was cut off');
      await settle(800);
      assert.equal(state.recorded, undefined);
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('a HEAD and a range short of the end record nothing; the tail of a resumed one does', async () => {
  const film = filmOnDisk();
  const state = { film };
  const database = stubDatabase(state);
  try {
    await withServer(async (port) => {
      const head = await request(port, downloadPath(film), { method: 'HEAD' });
      assert.equal(head.status, 200);
      const part = await request(port, downloadPath(film), { headers: { Range: 'bytes=0-1023' } });
      assert.equal(part.status, 206);
      assert.equal(part.bytes, 1024);
      await settle();
      assert.equal(state.recorded, undefined, 'no whole film went out');

      const tail = await request(port, downloadPath(film), { headers: { Range: `bytes=${FILM_BYTES - 1000}-` } });
      assert.equal(tail.status, 206);
      assert.equal(tail.bytes, 1000);
      await settle();
      assert.equal(state.recorded, 1, 'the last byte went out');
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('a link to a film since replaced is refused and records nothing', async () => {
  const oldFilm = filmOnDisk();
  const newFilm = filmOnDisk();
  const state = { film: newFilm };
  const database = stubDatabase(state);
  try {
    await withServer(async (port) => {
      const res = await request(port, downloadPath(oldFilm));
      assert.equal(res.status, 410);
      assert.match(res.body, /newer video/);
      await settle();
      assert.equal(state.recorded, undefined);
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, oldFilm), { force: true });
    fs.rmSync(path.join(EXPORTS_DIR, newFilm), { force: true });
  }
});

test('a token for another file, another purpose, another assignment or a deleted account opens nothing', async () => {
  const film = filmOnDisk();
  const state = { film };
  const database = stubDatabase(state);
  try {
    await withServer(async (port) => {
      const otherFile = await request(port, downloadPath(film, videoToken({ file: 'other.mp4' })));
      assert.equal(otherFile.status, 403);

      // A trainer's ordinary download link names the same file and must not
      // be able to record a student's work.
      const plainDownload = jwt.sign({ purpose: 'download', id: STUDENT, file: film }, SECRET);
      assert.equal((await request(port, downloadPath(film, plainDownload))).status, 403);

      const notTheirs = await request(port, downloadPath(film, videoToken({ file: film, assignment: ASSIGNMENT + 1 })));
      assert.equal(notTheirs.status, 404);

      state.accountGone = true;
      const gone = await request(port, downloadPath(film));
      assert.ok(gone.status === 401 || gone.status === 403, `a deleted account is refused (${gone.status})`);
      assert.ok(gone.bytes < FILM_BYTES);

      await settle();
      assert.equal(state.recorded, undefined);
    });
  } finally {
    database.restore();
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('only a response carrying the last byte counts as delivered', () => {
  const res = (statusCode, range) => ({ statusCode, getHeader: () => range });
  assert.equal(deliveredLastByte(res(200), 100), true);
  assert.equal(deliveredLastByte(res(206, 'bytes 0-99/100'), 100), true);
  assert.equal(deliveredLastByte(res(206, 'bytes 50-99/100'), 100), true);
  assert.equal(deliveredLastByte(res(206, 'bytes 0-98/100'), 100), false);
  assert.equal(deliveredLastByte(res(206, undefined), 100), false);
  assert.equal(deliveredLastByte(res(416), 100), false);
});

// ---- 5. the student's detail -------------------------------------------------

function detailPool({ film }) {
  return {
    async query(sql) {
      if (/FROM assignments a\s+LEFT JOIN users t/.test(sql)) {
        return {
          rows: [{ id: ASSIGNMENT, kind: 'lesson', lesson_id: 3, trainer_id: TRAINER, student_id: STUDENT }],
          rowCount: 1,
        };
      }
      if (/AS locked/.test(sql)) return { rows: [{ locked: false }], rowCount: 1 };
      if (/FROM assignment_items/.test(sql)) return { rows: [{ puzzle_id: null, position: 0 }], rowCount: 1 };
      if (/FROM saved_lessons/.test(sql)) {
        // Only what was asked for comes back, as from a real database.
        const selected = sql.split('FROM saved_lessons')[0];
        const row = {};
        for (const [column, value] of Object.entries({
          video_filename: film, video_seconds: 194, video_resolution: '720p',
          fen: 'x', pgn: '1. e4', position_list: [{ fen: 'x', pgn: '1. e4' }], title: 'Broken pawns',
        })) {
          if (new RegExp(`\\b${column}\\b`).test(selected)) row[column] = value;
        }
        return { rows: [row], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    },
  };
}

test('the student is told what the film is, and handed no part, line or file name', async () => {
  const film = filmOnDisk();
  try {
    const detail = await assignments.getAssignmentDetail(detailPool({ film }), ASSIGNMENT, STUDENT);
    assert.equal(detail.video.status, 'ready');
    assert.equal(detail.video.seconds, 194);
    assert.equal(detail.video.resolution, '720p');
    assert.equal(detail.steps, undefined);
    const wire = JSON.stringify(detail);
    assert.doesNotMatch(wire, /1\. e4/, 'no line');
    assert.ok(!wire.includes(film), 'the file name travels only inside a signed link');
  } finally {
    fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
  }
});

test('a tutorial with no film on disk reads as none', async () => {
  const detail = await assignments.getAssignmentDetail(
    detailPool({ film: 'tutorial_gone.mp4' }), ASSIGNMENT, STUDENT);
  assert.deepEqual(detail.video, { status: 'none' });
});

// ---- 6. retention ----------------------------------------------------------------

function aged(dir, name, days) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, 'mp4');
  const past = new Date(Date.now() - days * 86400000);
  fs.utimesSync(file, past, past);
  return file;
}

test('the timer keeps an old film a tutorial names, and still takes one nothing names', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'retention-film-'));
  const named = aged(dir, 'tutorial_76_wood_720p_1_a.mp4', 40);
  const orphan = aged(dir, 'tutorial_20_wood_720p_1_b.mp4', 40);
  const pool = {
    async query(sql) {
      if (/SELECT video_filename FROM saved_lessons/.test(sql)) {
        return { rows: [{ video_filename: 'tutorial_76_wood_720p_1_a.mp4' }] };
      }
      return { rows: [] };
    },
  };
  const result = await cleanupOldExports(pool, { dir, maxAgeDays: 14 });
  assert.equal(result.deleted, 1);
  assert.equal(fs.existsSync(named), true, 'a film a tutorial names stays');
  assert.equal(fs.existsSync(orphan), false);
});

test('when it cannot tell which films are kept, the timer deletes nothing', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'retention-film-'));
  const file = aged(dir, 'tutorial_76_wood_720p_1_a.mp4', 40);
  const pool = { async query() { throw new Error('database down'); } };
  const result = await cleanupOldExports(pool, { dir, maxAgeDays: 14 });
  assert.equal(result.deleted, 0);
  assert.equal(fs.existsSync(file), true);
});

// ---- 7. the review queue ---------------------------------------------------------

test('a lone film does not wait in the trainer’s review queue', async () => {
  const queries = [];
  const pool = { async query(sql) { queries.push(sql); return { rows: [] }; } };
  await trainerPanel.awaitingReview(pool, TRAINER);
  assert.match(queries[0], /a\.kind <> 'lesson'/);
  // A homework is its own parent and waits as it did.
  assert.match(queries[0], /a\.parent_id IS NULL/);
});
