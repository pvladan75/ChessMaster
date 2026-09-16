// recording_participants.test.js
// Who a saved recording belongs to is decided by the server, never by the body.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 2 and
// 8). `POST /recordings/save` wrote `participants` straight from the request, and
// `participants` is exactly who may list and open a recording
// (`$1 = ANY(sr.participants)`). So any account could put a „lesson" — its own
// title, its own timeline, and after recording alone in a room of its own, its
// own voice — into any other user's list, around every accepted-relationship
// rule this app has. `roomId` was any string, so the room did not have to be the
// caller's, and `audioUrl` from the body was stored as the recording's sound and
// later opened as a path by the renderer.
//
// The rules now: the room must be the caller's; `participants` is what the
// server's own roster saw, and nothing the body adds to it; `audioUrl` is never
// read from the body.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const realtime = require('../services/realtime');
const recordingsRouter = require('../routes/recordings');

const OWNER = 11;

function saveHandler() {
  const layer = recordingsRouter.stack.find(
    (l) => l.route && l.route.path === '/save' && l.route.methods.post
  );
  assert.ok(layer, 'POST /recordings/save must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// Runs the save as `userId` against rooms owned as `rooms` says, and returns the
/// answer and the INSERT it made, if any.
async function save({ userId = OWNER, rooms = { '123456': OWNER }, body, file = null }) {
  const inserts = [];
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    if (/SELECT creator_id FROM rooms WHERE room_code = \$1/.test(text)) {
      const owner = rooms[params[0]];
      return owner === undefined
        ? { rows: [], rowCount: 0 }
        : { rows: [{ creator_id: owner }], rowCount: 1 };
    }
    if (/INSERT INTO session_recordings/.test(text)) {
      inserts.push(params);
      return { rows: [{ id: 1, room_id: params[0], title: params[2] }], rowCount: 1 };
    }
    // The owner is an adult, so a room holding only them may carry sound —
    // otherwise a test about `audioUrl` would pass because consent removed the
    // sound, not because the body was ignored. Anybody else in the roster makes
    // the room not alone and the audio is refused, which the participant tests
    // do not care about: they are about who the row names.
    if (/SELECT birth_year FROM users WHERE id = \$1/.test(text)) {
      return { rows: [{ birth_year: 1980 }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };

  const answered = { status: 200, body: null };
  const res = {
    status(code) {
      answered.status = code;
      return this;
    },
    json(payload) {
      answered.body = payload;
      return this;
    },
  };
  try {
    await saveHandler()({ user: { id: userId }, body, file }, res);
  } finally {
    db.pool.query = original;
  }
  const insert = inserts[0];
  return {
    status: answered.status,
    body: answered.body,
    participants: insert ? insert[5] : undefined,
    audioUrl: insert ? insert[3] : undefined,
    inserted: inserts.length,
  };
}

const TIMELINE = JSON.stringify([{ t: 0, type: 'move', san: 'e4' }]);

test('a user id the room never saw is not written into the recording', async () => {
  realtime.beginRecordingRoster('123456', [String(OWNER), '42']);
  const r = await save({
    body: { roomId: '123456', title: 'Lesson', timelineJson: TIMELINE, participants: JSON.stringify([42, 777]) },
  });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  assert.deepEqual(r.participants, [42], 'only who the roster saw; 777 was never in the room');
});

test('with no roster the recording names nobody but its host', async () => {
  realtime.clearRecordedRoster('123456');
  const r = await save({
    body: { roomId: '123456', title: 'Lesson', timelineJson: TIMELINE, participants: JSON.stringify([42, 777]) },
  });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  assert.deepEqual(r.participants, []);
});

test('a recording cannot be saved against somebody else\'s room, and its upload is not kept', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rec-owner-'));
  const upload = path.join(dir, 'recording_x.aac');
  fs.writeFileSync(upload, 'not really audio');

  realtime.beginRecordingRoster('654321', ['99']);
  const r = await save({
    userId: OWNER,
    rooms: { '654321': 99 },
    body: { roomId: '654321', title: 'Planted', timelineJson: TIMELINE, participants: '[99]' },
    file: { path: upload, filename: 'recording_x.aac', size: 16 },
  });
  assert.equal(r.status, 403, JSON.stringify(r.body));
  assert.equal(r.inserted, 0);
  assert.equal(fs.existsSync(upload), false, 'a refused upload must not stay in uploads/');
  realtime.clearRecordedRoster('654321');
});

test('a room that does not exist is refused the same way', async () => {
  const r = await save({
    rooms: {},
    body: { roomId: 'NOPE', title: 'Planted', timelineJson: TIMELINE, participants: '[42]' },
  });
  assert.equal(r.status, 403, JSON.stringify(r.body));
  assert.equal(r.inserted, 0);
});

test('an audioUrl in the body is never stored as the recording\'s sound', async () => {
  // Alone in the room and an adult: the sound itself is allowed, so the only
  // thing that could keep `audioUrl` out of the row is that it is not read.
  realtime.beginRecordingRoster('123456', [String(OWNER)]);
  const r = await save({
    body: {
      roomId: '123456',
      title: 'Lesson',
      timelineJson: TIMELINE,
      audioUrl: '/uploads/somebody-elses-lesson.aac',
    },
  });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  assert.equal(r.audioUrl, null);
});
