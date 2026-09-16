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

async function invite({ senderId = 1, body, related }) {
  const queries = [];
  const pushed = [];
  const originalQuery = db.pool.query;
  const originalEmit = realtime.emitToUser;
  db.pool.query = async (text, params) => {
    const sql = String(text).replace(/\s+/g, ' ');
    queries.push(sql);
    if (/FROM trainer_students/.test(sql)) {
      const [a, b] = params.map(Number);
      const hit = related.some(([x, y]) => (x === a && y === b) || (x === b && y === a));
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
