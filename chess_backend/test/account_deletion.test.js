// account_deletion.test.js
// An account deleted by its own holder — `POST /me/delete`, over real HTTP and
// a pool that answers by the SQL it is sent (the owner's decisions of
// 3.10.2026: confirmed, at once, files included).
//
// What a stub can hold: who is refused and that a refusal deletes nothing; the
// order of the statements; that the files the deleted rows named are removed
// and no other; that the people in a live session are told and the account's
// sockets are closed; and that nothing after the rows can turn „deleted" into
// an error. What a stub cannot hold — the cascade itself — is
// `account_deletion_db.test.js`, on a real database.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

// Never the real folders: both are read at call time, so they are set before
// anything is deleted.
const NARRATION = fs.mkdtempSync(path.join(os.tmpdir(), 'del-narration-'));
const LESSONS = fs.mkdtempSync(path.join(os.tmpdir(), 'del-lessons-'));
process.env.NARRATION_DIR = NARRATION;
process.env.LESSON_RECORDING_DIR = LESSONS;

const db = require('../db');
const { mountBodyParsers } = require('../middleware/bodyParsers');
const realtime = require('../services/realtime');
const { EXPORTS_DIR } = require('../services/retentionService');
const { exportNameOf } = require('../services/filmName');
const { GOOGLE_PLACEHOLDER_HASH } = require('../services/googleAccount');
const accountDeletion = require('../services/accountDeletion');
const router = require('../routes/account');

const PASSWORD = 'correct horse';
const HASH = bcrypt.hashSync(PASSWORD, 4);

// Films live in the real exports directory (it has no override), under names
// no render writes; each is removed again whatever the test did.
fs.mkdirSync(EXPORTS_DIR, { recursive: true });
const made = [];
let minted = 0;
function file(dir, stem, ext) {
  minted += 1;
  const name = `${stem}_deltest_${process.pid}_${minted}.${ext}`;
  fs.writeFileSync(path.join(dir, name), 'x');
  made.push(path.join(dir, name));
  return name;
}
test.after(() => {
  for (const f of made) fs.rmSync(f, { force: true });
  fs.rmSync(NARRATION, { recursive: true, force: true });
  fs.rmSync(LESSONS, { recursive: true, force: true });
});

/// A pool that holds one account and answers by the statement. `sent` is every
/// statement of the transaction, in order.
function account({ hash = HASH, rooms = [], lessons = [], recordings = [] } = {}) {
  const state = { exists: true, sent: [] };
  const client = {
    async query(text, params) {
      const sql = String(text).replace(/\s+/g, ' ').trim();
      state.sent.push(sql.split(' ').slice(0, 3).join(' '));
      if (/^SELECT id FROM users .* FOR UPDATE/.test(sql)) {
        return { rows: state.exists ? [{ id: params[0] }] : [], rowCount: state.exists ? 1 : 0 };
      }
      if (/^UPDATE rooms/.test(sql)) return { rows: rooms.map((c) => ({ room_code: c })), rowCount: rooms.length };
      if (/^DELETE FROM saved_lessons/.test(sql)) return { rows: lessons, rowCount: lessons.length };
      if (/^DELETE FROM session_recordings/.test(sql)) return { rows: recordings, rowCount: recordings.length };
      if (/^DELETE FROM users/.test(sql)) {
        state.exists = false;
        return { rows: [], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    },
    release() {},
  };
  db.pool.connect = async () => client;
  db.pool.query = async (text) => {
    const sql = String(text);
    if (/FROM users/.test(sql)) {
      if (!state.exists) return { rows: [], rowCount: 0 };
      return {
        rows: [{ id: 7, role: 'korisnik', password_hash: hash, birth_year: 1990 }],
        rowCount: 1,
      };
    }
    return { rows: [], rowCount: 0 };
  };
  return state;
}

/// A Socket.IO server as far as `realtime` reads one.
function fakeIo({ failing = false } = {}) {
  const io = { announced: [], left: [], closed: [], sockets: { sockets: new Map() } };
  io.to = (room) => ({
    emit: (event, payload) => {
      if (failing) throw new Error('the transport is down');
      io.announced.push({ room, event, payload });
    },
  });
  io.in = (room) => ({ socketsLeave: () => io.left.push(room) });
  io.seat = (userId, socketId) => {
    io.sockets.sockets.set(socketId, { disconnect: (close) => io.closed.push({ socketId, close }) });
    realtime.setOnline({ id: userId, name: 'N', email: 'n@example.test', role: 'korisnik' }, socketId);
  };
  realtime.init(io);
  return io;
}

let userIds = 100;
async function ask(body, { path: route = '/me/delete', method = 'POST', userId } = {}) {
  const id = userId || (userIds += 1);
  const app = express();
  mountBodyParsers(app);
  app.use('/', router);
  const server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  const token = jwt.sign({ id, email: 'x@example.test', role: 'korisnik' }, process.env.JWT_SECRET);
  const data = body === undefined ? undefined : JSON.stringify(body);
  try {
    return await new Promise((resolve, reject) => {
      const req = http.request(
        {
          port: server.address().port,
          path: route,
          method,
          headers: {
            Authorization: `Bearer ${token}`,
            ...(data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {}),
          },
        },
        (res) => {
          let text = '';
          res.setEncoding('utf8');
          res.on('data', (chunk) => { text += chunk; });
          res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(text), userId: id }));
        },
      );
      req.on('error', reject);
      req.end(data);
    });
  } finally {
    await new Promise((r) => server.close(r));
  }
}

const deleted = (state) => state.sent.includes('DELETE FROM users');

test('the right password deletes the account, in one transaction, files first', async () => {
  const state = account();
  fakeIo();
  const r = await ask({ password: PASSWORD });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.deepEqual(r.body, { deleted: true });
  assert.deepEqual(state.sent, [
    'BEGIN',
    'SELECT id FROM',
    'UPDATE rooms SET',
    'DELETE FROM saved_lessons',
    'DELETE FROM session_recordings',
    'DELETE FROM users',
    'COMMIT',
  ]);
});

test('a wrong password deletes nothing and is not a 401', async () => {
  const state = account();
  fakeIo();
  const r = await ask({ password: 'correct horse ' });
  assert.equal(r.status, 400);
  assert.equal(r.body.code, 'wrong-password');
  assert.deepEqual(state.sent, [], 'no transaction may even begin');
});

test('no password deletes nothing — and the typed word does not stand in for one', async () => {
  for (const body of [{}, { password: '' }, { confirm: 'DELETE' }, undefined]) {
    const state = account();
    const r = await ask(body);
    assert.equal(r.status, 400, JSON.stringify(body));
    assert.equal(r.body.code, 'password-required');
    assert.equal(deleted(state), false);
  }
});

test('an account made through Google confirms with the word, exactly', async () => {
  for (const body of [{}, { confirm: 'delete' }, { confirm: 'DELETE ' }, { password: PASSWORD }, { password: GOOGLE_PLACEHOLDER_HASH }]) {
    const state = account({ hash: GOOGLE_PLACEHOLDER_HASH });
    const r = await ask(body);
    assert.equal(r.status, 400, JSON.stringify(body));
    assert.equal(r.body.code, 'confirmation-required');
    assert.equal(deleted(state), false);
  }
  const state = account({ hash: GOOGLE_PLACEHOLDER_HASH });
  fakeIo();
  const r = await ask({ confirm: 'DELETE' });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(deleted(state), true);
});

test('the files the deleted rows named are removed, and no other', async () => {
  const narration = file(NARRATION, 'narration_1', 'wav');
  const strangersNarration = file(NARRATION, 'narration_2', 'wav');
  const tutorialFilm = file(EXPORTS_DIR, 'tutorial_1', 'mp4');
  const sound = file(LESSONS, 'lesson_7', 'wav');
  const strangersSound = file(LESSONS, 'lesson_8', 'wav');
  const recordingFilm = file(EXPORTS_DIR, 'recording_1', 'mp4');
  const strangersFilm = file(EXPORTS_DIR, 'recording_2', 'mp4');
  account({
    lessons: [
      { narration_filename: narration, video_filename: tutorialFilm },
      { narration_filename: null, video_filename: null },
    ],
    recordings: [
      { audio_file: sound, audio_url: null, video_url: `/recordings/export-download/${recordingFilm}?token=abc` },
      { audio_file: null, audio_url: null, video_url: null },
    ],
  });
  fakeIo();
  const r = await ask({ password: PASSWORD });
  assert.equal(r.status, 200, JSON.stringify(r.body));

  assert.equal(fs.existsSync(path.join(NARRATION, narration)), false, 'the tutorial\'s narration');
  assert.equal(fs.existsSync(path.join(EXPORTS_DIR, tutorialFilm)), false, 'the tutorial\'s film');
  assert.equal(fs.existsSync(path.join(LESSONS, sound)), false, 'the recording\'s sound');
  assert.equal(fs.existsSync(path.join(EXPORTS_DIR, recordingFilm)), false, 'the recording\'s film');
  assert.equal(fs.existsSync(path.join(NARRATION, strangersNarration)), true);
  assert.equal(fs.existsSync(path.join(LESSONS, strangersSound)), true);
  assert.equal(fs.existsSync(path.join(EXPORTS_DIR, strangersFilm)), true);
});

test('a refused request removes no file', async () => {
  const narration = file(NARRATION, 'narration_3', 'wav');
  account({ lessons: [{ narration_filename: narration, video_filename: null }] });
  const r = await ask({ password: 'wrong' });
  assert.equal(r.status, 400);
  assert.equal(fs.existsSync(path.join(NARRATION, narration)), true);
});

test('a row is not a path: a film name that climbs out of exports/ removes nothing', async () => {
  // Beside exports/, not in the temp folder: on Windows that is another
  // drive, and a path that cannot be reached by climbing cannot fail.
  const beside = path.dirname(EXPORTS_DIR);
  const viaLesson = file(beside, 'outside_a', 'mp4');
  const viaRecording = file(beside, 'outside_b', 'mp4');
  const besideNarration = file(path.dirname(NARRATION), 'outside_c', 'wav');
  account({
    lessons: [{ narration_filename: `../${besideNarration}`, video_filename: `../${viaLesson}` }],
    recordings: [{
      audio_file: null,
      audio_url: null,
      video_url: `/recordings/export-download/${encodeURIComponent(`../${viaRecording}`)}`,
    }],
  });
  fakeIo();
  const r = await ask({ password: PASSWORD });
  assert.equal(r.status, 200);
  assert.equal(fs.existsSync(path.join(beside, viaLesson)), true, 'named by the film of a tutorial');
  assert.equal(fs.existsSync(path.join(beside, viaRecording)), true, 'named by the film of a recording');
  assert.equal(fs.existsSync(path.join(path.dirname(NARRATION), besideNarration)), true, 'named by a narration');
});

test('whoever sits in the account\'s live session is told, and its sockets are closed', async () => {
  account({ rooms: ['123456'] });
  const io = fakeIo();
  const r0 = await ask({ password: 'wrong' });
  io.seat(r0.userId, 'home-socket');
  io.seat(r0.userId, 'room-socket');
  io.seat(r0.userId + 1000, 'somebody-else');
  assert.deepEqual(io.announced, [], 'a refusal ends nothing');

  const r = await ask({ password: PASSWORD }, { userId: r0.userId });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.deepEqual(io.announced.map((a) => [a.room, a.event]), [['123456', 'session_ended']]);
  assert.deepEqual(io.closed, [
    { socketId: 'home-socket', close: true },
    { socketId: 'room-socket', close: true },
  ]);
  assert.deepEqual(realtime.socketIdsOf(r0.userId), []);
  assert.deepEqual(realtime.socketIdsOf(r0.userId + 1000), ['somebody-else']);
});

test('nothing after the rows can turn a deleted account into an error', async () => {
  const narration = file(NARRATION, 'narration_4', 'wav');
  const state = account({ rooms: ['654321'], lessons: [{ narration_filename: narration, video_filename: null }] });
  const io = fakeIo({ failing: true });
  userIds += 1;
  realtime.setOnline({ id: userIds, name: 'N', email: 'n@example.test', role: 'korisnik' }, 'broken-socket');
  io.sockets.sockets.set('broken-socket', { disconnect: () => { throw new Error('the socket is already half closed'); } });
  const r = await ask({ password: PASSWORD }, { userId: userIds });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(deleted(state), true);
  assert.equal(fs.existsSync(path.join(NARRATION, narration)), false, 'the file still goes when the announcement failed');
});

test('a transaction that fails is rolled back and says nothing was deleted', async () => {
  const state = account();
  const client = await db.pool.connect();
  const original = client.query;
  client.query = async (text, params) => {
    if (/^DELETE FROM users/.test(String(text).trim())) {
      state.sent.push('DELETE FROM users (refused)');
      throw new Error('a foreign key that does not cascade');
    }
    return original(text, params);
  };
  const narration = file(NARRATION, 'narration_5', 'wav');
  const r = await ask({ password: PASSWORD });
  assert.equal(r.status, 500);
  assert.equal(state.sent[state.sent.length - 1], 'ROLLBACK');
  assert.equal(fs.existsSync(path.join(NARRATION, narration)), true);
});

test('an account that is already gone is not found, and nothing is committed', async () => {
  const state = { sent: [] };
  db.pool.connect = async () => ({
    async query(text) {
      state.sent.push(String(text).trim().split(/\s+/)[0]);
      return { rows: [], rowCount: 0 };
    },
    release() {},
  });
  assert.equal(await accountDeletion.deleteAccount(db.pool, 7), null);
  assert.deepEqual(state.sent, ['BEGIN', 'SELECT', 'ROLLBACK']);
  for (const id of [0, -1, 'x', null, 1.5]) {
    assert.equal(await accountDeletion.deleteAccount({ connect: () => assert.fail('asked') }, id), null);
  }
});

test('the route is limited per account: the eleventh try in a quarter of an hour is refused', async () => {
  account();
  const statuses = [];
  for (let i = 0; i < 11; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    statuses.push((await ask({ password: 'guess' }, { userId: 9001 })).status);
  }
  assert.deepEqual(statuses.slice(0, 10), Array(10).fill(400));
  assert.equal(statuses[10], 429);
  // Counted per account: the neighbour behind the same address is not refused.
  assert.equal((await ask({ password: 'guess' }, { userId: 9002 })).status, 400);
});

test('the standing says which proof the account will be asked for', async () => {
  account();
  assert.equal((await ask(undefined, { path: '/me/standing', method: 'GET' })).body.deletionConfirmedBy, 'password');
  account({ hash: GOOGLE_PLACEHOLDER_HASH });
  assert.equal((await ask(undefined, { path: '/me/standing', method: 'GET' })).body.deletionConfirmedBy, 'word');
});

test('a stored export link names a file in exports/, or nothing', () => {
  assert.equal(exportNameOf('/recordings/export-download/recording_1_wood_720p.mp4?token=a.b'), 'recording_1_wood_720p.mp4');
  assert.equal(exportNameOf('/recordings/export-download/a%20b.mp4'), 'a b.mp4');
  for (const link of [
    null, undefined, 7, '', '/uploads/recording_1.mp4',
    '/recordings/export-download/', '/recordings/export-download/..%2Fserver.js',
    '/recordings/export-download/a%5Cb.mp4', '/recordings/export-download/..',
    '/recordings/export-download/%E0%A4%A',
  ]) {
    assert.equal(exportNameOf(link), null, String(link));
  }
});
