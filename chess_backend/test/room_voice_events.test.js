// room_voice_events.test.js — leaving the voice is not leaving the room.
// The story is in `services/roomVoiceEvents.js`.

const test = require('node:test');
const assert = require('node:assert/strict');

const { registerRoomVoiceEvents, dropEntry } = require('../services/roomVoiceEvents');

/// A socket with `seat` already on it, and everything done to it written down.
function setUp(seat, roster = {}) {
  const handlers = {};
  const left = [];
  const emitted = [];
  const flushed = [];
  const socket = {
    // A real socket always has an id, and a roster entry names the socket that
    // wrote it — which is what decides whose entry a closing socket may remove.
    id: `s${seat.audioUserId}`,
    ...seat,
    on: (event, fn) => { handlers[event] = fn; },
    leave: (room) => left.push(room),
  };
  registerRoomVoiceEvents(socket, {
    io: { to: (room) => ({ emit: (event, payload) => emitted.push([room, event, payload]) }) },
    audioUsers: () => roster,
    flushAudioUsage: (s) => flushed.push(s.audioUserId),
  });
  return {
    socket, fire: (payload) => handlers.audio_leave(payload),
    close: () => handlers.disconnect(), left, emitted, flushed, roster,
  };
}

const inVoice = (userId) => ({ userId, socketId: `s${userId}` });

test('a seated socket that leaves the voice stays in the room', () => {
  // The report: after „Leave voice" the trainer's roster and board went quiet.
  const t = setUp(
    { roomId: '672493', audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: inVoice(1), 2: inVoice(2) } },
  );

  t.fire({ roomId: '672493' });

  assert.deepEqual(t.left, [], 'the socket was taken out of the room its board is broadcast in');
  assert.deepEqual(Object.keys(t.roster['672493']), ['2']);
  assert.deepEqual(t.emitted.map((e) => [e[0], e[1]]), [['672493', 'audio_users_list']]);
  assert.deepEqual(t.flushed, [1], 'the voice seconds were not booked');
});

test('a socket in the room for the voice alone is taken out of it', () => {
  const t = setUp(
    { audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: inVoice(1) } },
  );

  t.fire({ roomId: '672493' });

  assert.deepEqual(t.left, ['672493']);
  assert.equal(t.roster['672493'], undefined, 'an empty voice roster is forgotten');
});

test('closing a room whose voice was never on leaves nothing', () => {
  // The app sends `audio_leave` from `dispose` unconditionally. The log said
  // „User undefined left audio" every time a room was closed.
  const t = setUp({ roomId: '672493' }, { '672493': { 2: inVoice(2) } });

  t.fire({ roomId: '672493' });

  assert.deepEqual(t.left, []);
  assert.deepEqual(t.flushed, []);
  assert.deepEqual(t.emitted, []);
  assert.deepEqual(Object.keys(t.roster['672493']), ['2']);
});

test('leaving a voice one is not in does nothing to the one one is in', () => {
  const t = setUp(
    { roomId: '672493', audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: inVoice(1) }, '111111': { 1: inVoice(1) } },
  );

  t.fire({ roomId: '111111' });

  assert.deepEqual(t.left, []);
  assert.deepEqual(t.flushed, []);
  assert.ok(t.roster['111111'][1], 'a room named by the client was edited');
});

test('a second leave books nothing twice', () => {
  const t = setUp(
    { roomId: '672493', audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: inVoice(1), 2: inVoice(2) } },
  );

  t.fire({ roomId: '672493' });
  t.fire({ roomId: '672493' });

  assert.deepEqual(t.flushed, [1]);
  assert.equal(t.emitted.length, 1);
});

test('a leave with no payload does not throw', () => {
  const t = setUp({ roomId: '672493' });
  assert.doesNotThrow(() => t.fire(undefined));
});

// --- phase 4 of docs/PLAN-SESIJA.md -----------------------------------------

test('the last one out is announced too, as an empty list', () => {
  // Nothing was sent when the roster emptied, so everybody whose voice was off
  // kept the last list they had heard: „In call: Vladan." after Vladan left —
  // and, once the room's bar began to say it, „Vladan is in voice — Join voice"
  // for a call nobody was in.
  const t = setUp(
    { roomId: '672493', audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: inVoice(1) } },
  );

  t.fire({ roomId: '672493' });

  assert.deepEqual(t.emitted, [['672493', 'audio_users_list', []]]);
  assert.equal(t.roster['672493'], undefined, 'an empty voice roster is still forgotten');
});

test('a socket that closes leaves the voice, and the last one is announced', () => {
  const t = setUp(
    { roomId: '672493', audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: inVoice(1) } },
  );

  t.close();

  assert.deepEqual(t.flushed, [1], 'a dropped connection is the common ending, and it is billed');
  assert.deepEqual(t.emitted, [['672493', 'audio_users_list', []]]);
});

test('an old socket closing late does not remove the seat its successor took', () => {
  // A dropped connection is noticed by the server tens of seconds after the
  // app has already come back on a new socket and announced itself again
  // (phase 4, item 3). The roster is keyed by person, so the late `disconnect`
  // deleted the *new* entry: still talking, and gone from the list.
  const t = setUp(
    { id: 'old', roomId: '672493', audioRoomId: '672493', audioUserId: 1 },
    { '672493': { 1: { userId: 1, socketId: 'new' }, 2: inVoice(2) } },
  );

  t.close();

  assert.deepEqual(Object.keys(t.roster['672493']), ['1', '2']);
  assert.deepEqual(t.emitted, [], 'nothing changed, so nothing is said');
  assert.deepEqual(t.flushed, [1], 'the seconds the old socket ran up are still booked');
});

test('a socket that closes without ever being in the voice does nothing', () => {
  const t = setUp({ roomId: '672493' }, { '672493': { 2: inVoice(2) } });

  t.close();

  assert.deepEqual(t.flushed, []);
  assert.deepEqual(t.emitted, []);
});

test('dropEntry removes only what the closing socket wrote', () => {
  // The same rule for the room's own roster, which `server.js` keeps.
  const roster = { r: { 1: { socketId: 'new' }, 2: { socketId: 's2' } } };

  assert.equal(dropEntry(roster, 'r', 1, 'old'), false);
  assert.deepEqual(Object.keys(roster.r), ['1', '2']);

  assert.equal(dropEntry(roster, 'r', 2, 's2'), true);
  assert.deepEqual(Object.keys(roster.r), ['1']);

  assert.equal(dropEntry(roster, 'r', 1, 'new'), true);
  assert.equal(roster.r, undefined, 'an empty room is forgotten');

  assert.equal(dropEntry(roster, 'gone', 1, 'x'), false);
});

test('server.js removes nobody from a roster by hand when a socket closes', () => {
  // Read by braces, comments out: the two `delete`s that were here removed
  // whoever sat under that id, whichever socket had seated them.
  const fs = require('node:fs');
  const path = require('node:path');
  const source = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8')
    .replace(/^\s*\/\/.*$/gm, '');
  const start = source.indexOf("socket.on('disconnect'");
  assert.ok(start > 0, 'the disconnect handler was not found');
  let depth = 0;
  let end = -1;
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) { end = i; break; }
  }
  const body = source.slice(start, end + 1);
  assert.ok(body.length > 200, 'the body read is too short to prove anything');
  assert.match(body, /dropEntry\(activeRoomMembers, socket\.roomId, socket\.userId, socket\.id\)/);
  assert.doesNotMatch(body, /delete (activeRoomMembers|roomAudioUsers)\[/);
});
