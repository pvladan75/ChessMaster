// realtime.test.js
// Pins the nudge that keeps an answered request from staying invisible.
//
// The client fetches `/notifications` when it starts and on a socket event —
// never on a timer. So a notification row written by an HTTP route reaches a
// user who is already looking only if something tells their socket. These tests
// hold that wiring in place, including the part that must fail loudly.

const test = require('node:test');
const assert = require('node:assert/strict');

const realtime = require('../services/realtime');

/// Enough of a Socket.IO server to record what was sent where.
function stubIo() {
  const sent = [];
  return {
    sent,
    to(socketId) {
      return {
        emit(event, payload) {
          sent.push({ socketId, event, payload });
        },
      };
    },
  };
}

const user = { id: 42, name: 'pvladan', email: 'a@b.c', role: 'korisnik' };

test.beforeEach(() => {
  realtime.goOffline(user.id);
  realtime.init(null);
});

test('a connected user is reached at the socket they registered', () => {
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'socket-1');

  assert.equal(realtime.emitToUser(user.id, 'relationship_changed', {}), true);
  assert.deepEqual(io.sent, [
    { socketId: 'socket-1', event: 'relationship_changed', payload: {} },
  ]);
});

test('a user who is not connected is not an error', () => {
  // The notification row is the durable half; they read it at next launch.
  const io = stubIo();
  realtime.init(io);

  assert.equal(realtime.emitToUser(user.id, 'relationship_changed', {}), false);
  assert.deepEqual(io.sent, []);
});

test('a reconnect replaces the old socket rather than adding one', () => {
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'socket-1');
  realtime.setOnline(user, 'socket-2');

  realtime.emitToUser(user.id, 'relationship_changed', {});
  assert.deepEqual(io.sent.map((s) => s.socketId), ['socket-2']);
});

test('going offline stops the nudge, and says whether it had to', () => {
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'socket-1');

  assert.equal(realtime.goOffline(user.id), true);
  assert.equal(realtime.goOffline(user.id), false, 'already gone');
  assert.equal(realtime.emitToUser(user.id, 'relationship_changed', {}), false);
});

test('a server that never handed over its io says so, loudly', () => {
  // Without this it would return quietly, and every nudge in the app would do
  // nothing while every test and every log looked healthy.
  realtime.setOnline(user, 'socket-1');
  assert.throws(
    () => realtime.emitToUser(user.id, 'relationship_changed', {}),
    /realtime\.init/
  );
});
