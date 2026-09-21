// invitation_route.test.js
// An invitation to a lesson reaches only somebody the sender teaches or learns
// from — and reaches them at once when they are online.
//
// On 16.9.2026 the student list's „Invite to lesson" stopped using a socket event
// of its own (`send_lesson_invite`), which checked no relationship, wrote no
// notification, and — since the rename of 10.8.2026 — was delivered under a name
// the app did not listen for, while the trainer was told the invitation was sent.
// Both invitation doors in the app now go through this route. Until today the
// route's relationship check was pinned only by a 2500-character slice of the
// source (`room_access.test.js`); this drives the route.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const realtime = require('../services/realtime');
const social = require('../routes/social');

function sendHandler() {
  const layer = social.stack.find((l) => l.route && l.route.path === '/invitations/send' && l.route.methods.post);
  assert.ok(layer, 'POST /invitations/send must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// The room the invitation names. By default the sender's own live session —
/// since 21.9.2026 that is the only room anybody may be invited into — so the
/// cases about *who* is invited change nothing but the people.
const OWN_LIVE_ROOM = { creator_id: 1, allow_guests: false, status: 'active' };

async function invite({ senderId = 1, body, related, room = OWN_LIVE_ROOM }) {
  const queries = [];
  const pushed = [];
  const originalQuery = db.pool.query;
  const originalEmit = realtime.emitToUser;
  db.pool.query = async (text, params) => {
    const sql = String(text).replace(/\s+/g, ' ');
    queries.push(sql);
    if (/FROM rooms WHERE room_code = \$1/.test(sql)) {
      return room ? { rows: [{ ...room }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/FROM room_guests/.test(sql)) return { rows: [], rowCount: 0 };
    if (/FROM trainer_students/.test(sql)) {
      const [a, b] = params.map(Number);
      // `related` pairs are [trainer, student]. A query that names the direction
      // is answered in that direction; one that asks „either way" is answered
      // either way — so the stub cannot hide a route that asks the wrong one.
      const eitherWay = /trainer_id = \$2/.test(sql);
      const hit = related.some(([x, y]) => (x === a && y === b)
        || (eitherWay && x === b && y === a));
      return hit ? { rows: [{ '?column?': 1 }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/SELECT name FROM users/.test(sql)) return { rows: [{ name: 'Trainer One' }], rowCount: 1 };
    return { rows: [{ id: 1 }], rowCount: 1 };
  };
  realtime.emitToUser = (userId, event, payload) => {
    pushed.push({ userId, event, payload });
    return true;
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
    await sendHandler()({ user: { id: senderId }, body }, res);
  } finally {
    db.pool.query = originalQuery;
    realtime.emitToUser = originalEmit;
  }
  return { ...answered, queries, pushed };
}

test('an invitation to somebody with no accepted relationship is refused, and nothing is sent or written', async () => {
  const r = await invite({ body: { studentId: 42, roomCode: '123456' }, related: [] });
  assert.equal(r.status, 403);
  assert.deepEqual(r.pushed, []);
  assert.ok(!r.queries.some((q) => /INSERT/i.test(q)), 'no notification may be written');
});

test('an invitation to a student writes the notification and tells an open app at once', async () => {
  const r = await invite({ body: { studentId: 42, roomCode: '123456' }, related: [[1, 42]] });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.ok(r.queries.some((q) => /INSERT/i.test(q)), 'the notification row must be written');
  const live = r.pushed.filter((p) => p.event === 'lesson_invite_received');
  assert.equal(live.length, 1);
  assert.equal(live[0].userId, 42);
  assert.deepEqual(live[0].payload, { senderId: 1, senderName: 'Trainer One', roomCode: '123456' });
});

test('of several friends, only those in an accepted relationship are invited', async () => {
  const r = await invite({ body: { friendIds: [42, 43], roomCode: '123456' }, related: [[1, 43]] });
  assert.equal(r.status, 200);
  const live = r.pushed.filter((p) => p.event === 'lesson_invite_received').map((p) => p.userId);
  assert.deepEqual(live, [43]);
});

// The room half, added 21.9.2026 (`docs/PLAN-SESIJA.md`). Each case keeps the
// accepted relationship, so the room is the only thing that can refuse.

test('nobody is invited into a session that has ended', async () => {
  const r = await invite({
    body: { studentId: 42, roomCode: '123456' },
    related: [[1, 42]],
    room: { ...OWN_LIVE_ROOM, status: 'archived' },
  });
  assert.equal(r.status, 403);
  assert.deepEqual(r.pushed, []);
  assert.ok(!r.queries.some((q) => /INSERT/i.test(q)), 'no notification may be written');
});

test('nobody is invited into somebody else’s room', async () => {
  // The sender is an accepted student of the room's creator, so they *may be
  // in* the room — and still may not invite into it.
  const r = await invite({
    body: { studentId: 42, roomCode: '123456' },
    related: [[1, 42], [1, 7]],
    room: { ...OWN_LIVE_ROOM, creator_id: 7 },
  });
  assert.equal(r.status, 403);
  assert.deepEqual(r.pushed, []);
});

test('nobody is invited into a room that does not exist', async () => {
  const r = await invite({
    body: { studentId: 42, roomCode: '123456' },
    related: [[1, 42]],
    room: null,
  });
  assert.equal(r.status, 403);
  assert.deepEqual(r.pushed, []);
});

// Who may be invited, decided by the owner on 21.9.2026: whoever starts a
// session is teaching in it, so they invite **their own students** — not their
// trainer. Reported as „the student made a session and invited the trainer".

test('a student who starts a session cannot invite their trainer into it', async () => {
  // [7, 1]: 7 teaches 1. The sender (1) owns the live room and the relationship
  // is accepted — everything the route used to ask — and it is still a refusal.
  const r = await invite({ body: { friendIds: [7], roomCode: '123456' }, related: [[7, 1]] });
  assert.equal(r.status, 403);
  assert.deepEqual(r.pushed, []);
  assert.ok(!r.queries.some((q) => /INSERT/i.test(q)), 'no notification may be written');
  assert.match(r.body.error, /your own students/);
});

test('somebody who is both invites the ones they teach, and only those', async () => {
  const r = await invite({
    body: { friendIds: [7, 42], roomCode: '123456' },
    related: [[7, 1], [1, 42]],
  });
  assert.equal(r.status, 200);
  assert.deepEqual(r.pushed.filter((p) => p.event === 'lesson_invite_received').map((p) => p.userId), [42]);
});
