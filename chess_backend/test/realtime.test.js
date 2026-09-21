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

test('a person is reached at every socket they hold', () => {
  // Supersedes „a reconnect replaces the old socket rather than adding one"
  // (21.9.2026). One socket per person was the fault: somebody in a room holds
  // two — Home's and the room's — and what is sent to them has to arrive where
  // they are looking. A socket that has really gone takes itself out when it
  // closes (the next case); until then a send to it is a send to nobody.
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'home-socket');
  realtime.setOnline(user, 'room-socket');

  realtime.emitToUser(user.id, 'voice_level_changed', { level: 'talk' });
  assert.deepEqual(io.sent.map((s) => s.socketId), ['home-socket', 'room-socket']);
});

test('a socket that closes takes only itself', () => {
  // The student's case: Home's socket is disconnected while the room is open,
  // so the room's is the only one left — and „Grant microphone" has to find it.
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'home-socket');
  realtime.setOnline(user, 'room-socket');

  assert.equal(realtime.goOffline(user.id, 'home-socket'), false, 'still reachable in the room');
  realtime.emitToUser(user.id, 'voice_level_changed', { level: 'talk' });
  assert.deepEqual(io.sent.map((s) => s.socketId), ['room-socket']);

  assert.equal(realtime.goOffline(user.id, 'room-socket'), true, 'the last one takes them offline');
  assert.equal(realtime.emitToUser(user.id, 'voice_level_changed', {}), false);
});

test('registering the same socket twice does not send twice', () => {
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'home-socket');
  realtime.setOnline(user, 'home-socket');

  realtime.emitToUser(user.id, 'relationship_changed', {});
  assert.equal(io.sent.length, 1);
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

test('a room socket closing does not take the registration Home made', () => {
  // Log of 21.9.2026: „User registered: … (ID: 2)" and, on the next line,
  // „[ONLINE PRESENCE] User disconnected: ID 2" — the room's socket closing
  // after Home's had registered. Invitations then missed that person.
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(user, 'home-socket');

  assert.equal(realtime.goOffline(user.id, 'room-socket'), false);
  assert.equal(realtime.emitToUser(user.id, 'lesson_invite_received', {}), true);
  assert.deepEqual(io.sent.map((s) => s.socketId), ['home-socket']);

  assert.equal(realtime.goOffline(user.id, 'home-socket'), true);
  assert.equal(realtime.emitToUser(user.id, 'lesson_invite_received', {}), false);
});
