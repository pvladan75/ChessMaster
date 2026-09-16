// rooms_join.test.js
// Asking for a room by its code tells you whether you may enter — nothing more.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 6).
// `POST /rooms/join` answered any signed-in caller's code with the whole `rooms`
// row — who created it, whether its board was open to students, whether guests
// were allowed — with no guest list and no limit on attempts. The guest list
// guarded the socket's door; this route was a directory of every room ever made
// and which ones had their board open, which is how a stranger would find a
// lesson to walk into.
//
// The route now asks the same `mayJoinRoom` the socket asks, returns the seat and
// nothing else, answers „no such room" and „not on the guest list" with one
// sentence, and is rate limited.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const roomsRouter = require('../routes/rooms');

function joinLayer() {
  const layer = roomsRouter.stack.find(
    (l) => l.route && l.route.path === '/join' && l.route.methods.post
  );
  assert.ok(layer, 'POST /rooms/join must be mounted');
  return layer;
}

/// Rooms: code -> { creator_id, allow_guests, board_control }. Relationships:
/// pairs of ids with an accepted edge. No guest lists, no invitations.
async function join({ userId, roomCode, rooms, related = [] }) {
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    const sql = text.replace(/\s+/g, ' ');
    if (/FROM rooms WHERE room_code = \$1/.test(sql)) {
      const room = rooms[params[0]];
      return room ? { rows: [{ ...room }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/FROM trainer_students/.test(sql)) {
      const [a, b] = params.map(Number);
      const hit = related.some(([x, y]) => (x === a && y === b) || (x === b && y === a));
      return hit ? { rows: [{ '?column?': 1 }], rowCount: 1 } : { rows: [], rowCount: 0 };
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
  const handlers = joinLayer().route.stack.map((s) => s.handle);
  try {
    await handlers[handlers.length - 1]({ user: { id: userId }, body: { roomCode } }, res);
  } finally {
    db.pool.query = original;
  }
  return answered;
}

const ROOMS = {
  '123456': { creator_id: 1, allow_guests: false, board_control: 'unrestricted', current_fen: 'secret-fen' },
  '222222': { creator_id: 1, allow_guests: true, board_control: 'host_only', current_fen: 'x' },
};

/// Everything a joiner must never be told about a room they asked for.
function assertNoRoomDetails(body) {
  const text = JSON.stringify(body);
  for (const field of ['creator_id', 'board_control', 'allow_guests', 'current_fen', 'secret-fen']) {
    assert.ok(!text.includes(field), `the answer must not carry ${field}: ${text}`);
  }
}

test('a stranger asking for an existing room is refused and learns nothing about it', async () => {
  const r = await join({ userId: 99, roomCode: '123456', rooms: ROOMS });
  assert.equal(r.status, 404);
  assertNoRoomDetails(r.body);
});

test('a room that exists and one that does not are refused with the same answer', async () => {
  const exists = await join({ userId: 99, roomCode: '123456', rooms: ROOMS });
  const missing = await join({ userId: 99, roomCode: '999999', rooms: ROOMS });
  assert.equal(exists.status, missing.status);
  assert.deepEqual(exists.body, missing.body);
});

test('the room\'s creator is let in and told their seat, not the row', async () => {
  const r = await join({ userId: 1, roomCode: '123456', rooms: ROOMS });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.room.room_code, '123456');
  assert.equal(r.body.room.role, 'trener');
  assertNoRoomDetails(r.body);
});

test('a student with an accepted relationship to the creator is let in', async () => {
  const r = await join({ userId: 7, roomCode: '123456', rooms: ROOMS, related: [[1, 7]] });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.room.role, 'ucenik');
  assertNoRoomDetails(r.body);
});

test('a room open to guests lets a stranger in as a guest', async () => {
  const r = await join({ userId: 99, roomCode: '222222', rooms: ROOMS });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.room.role, 'gost');
});

test('the route is rate limited before it answers', () => {
  // `express-rate-limit` returns an anonymous function, so the limiter is found
  // by identity rather than by a name nothing gives it.
  assert.equal(typeof roomsRouter.joinLimiter, 'function', 'rooms.js must expose joinLimiter');
  const handles = joinLayer().route.stack.map((s) => s.handle);
  const limiterAt = handles.indexOf(roomsRouter.joinLimiter);
  assert.ok(limiterAt >= 0, 'the limiter must be on POST /rooms/join');
  assert.ok(limiterAt < handles.length - 1, 'the limiter must run before the handler');
});
