// room_board_events.test.js
// A socket acts in the room it was seated in, and in no other.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 3):
// `move` and `pgn_loaded` asked whether the room's board was open and never
// whether the sender had joined, so a client that knew a room code could move
// pieces in a live lesson it had never been let into, and write the room's
// stored position. See `services/roomBoardEvents.js`.
//
// Driven through the registered handlers with a fake socket, not through the
// predicate alone: the predicate being right and each handler asking it are two
// different facts.

const test = require('node:test');
const assert = require('node:assert/strict');

const { registerRoomBoardEvents } = require('../services/roomBoardEvents');

/// A socket that records what it was told to broadcast and what was denied.
function fakeSocket(seat = {}) {
  const handlers = {};
  const broadcasts = [];
  return {
    id: 'sock-1',
    data: { user: { id: 5 } },
    ...seat,
    handlers,
    broadcasts,
    on(event, fn) {
      handlers[event] = fn;
    },
    to(roomId) {
      return {
        emit: (event, payload) => broadcasts.push({ roomId, event, payload }),
      };
    },
  };
}

function setUp(seat, { boardControl = 'unrestricted', admin = false } = {}) {
  const socket = fakeSocket(seat);
  const denied = [];
  const writes = [];
  const pool = {
    async query(text, params) {
      if (/SELECT board_control FROM rooms/.test(text)) {
        return { rows: [{ board_control: boardControl }], rowCount: 1 };
      }
      if (/UPDATE rooms SET current_fen/.test(text)) {
        writes.push(params);
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`unexpected query: ${text}`);
    },
  };
  registerRoomBoardEvents(socket, {
    pool,
    canAdministerRoom: async () => admin,
    denyPrivileged: (_s, event, roomId) => denied.push({ event, roomId }),
  });
  return { socket, denied, writes };
}

const MOVE = { roomId: '123456', move: 'e4', currentFen: 'planted-fen' };

test('a move from a socket that never joined the room is refused and writes nothing', async () => {
  const { socket, denied, writes } = setUp({});
  await socket.handlers.move(MOVE);
  assert.deepEqual(socket.broadcasts, []);
  assert.deepEqual(writes, [], 'the room\'s stored position must not change');
  // Dropped silently rather than answered with `action_denied`: the local
  // Preparation board connects a socket, never joins, and reports every move.
  assert.deepEqual(denied, []);
});

test('a move aimed at another room than the one the socket sits in is refused', async () => {
  const { socket, writes } = setUp({ roomId: '999999' });
  await socket.handlers.move(MOVE);
  assert.deepEqual(socket.broadcasts, []);
  assert.deepEqual(writes, []);
});

test('a seated socket on an open board moves, and the position is stored', async () => {
  const { socket, writes } = setUp({ roomId: '123456' });
  await socket.handlers.move(MOVE);
  assert.equal(socket.broadcasts.length, 1);
  assert.equal(socket.broadcasts[0].event, 'move');
  assert.deepEqual(writes, [['planted-fen', '123456']]);
});

test('a seated student on a host-only board is refused, and told so', async () => {
  const { socket, writes, denied } = setUp({ roomId: '123456' }, { boardControl: 'host_only' });
  await socket.handlers.move(MOVE);
  assert.deepEqual(socket.broadcasts, []);
  assert.deepEqual(writes, []);
  assert.deepEqual(denied, [{ event: 'move', roomId: '123456' }]);
});

test('the local Preparation board, which never joins a room, is not told it lacks permission', async () => {
  const { socket, denied, writes } = setUp({}, { boardControl: 'host_only' });
  await socket.handlers.move({ roomId: 'STUDIO', move: null, currentFen: 'x' });
  await socket.handlers.pgn_loaded({ roomId: 'STUDIO', pgn: '1. e4' });
  assert.deepEqual(denied, []);
  assert.deepEqual(socket.broadcasts, []);
  assert.deepEqual(writes, []);
});

test('a PGN from a socket that never joined the room is refused', async () => {
  const { socket, denied } = setUp({});
  await socket.handlers.pgn_loaded({ roomId: '123456', pgn: '1. e4' });
  assert.deepEqual(socket.broadcasts, []);
  assert.deepEqual(denied, []);
});

test('a PGN from a seated socket on an open board is relayed', async () => {
  const { socket } = setUp({ roomId: '123456' });
  await socket.handlers.pgn_loaded({ roomId: '123456', pgn: '1. e4' });
  assert.deepEqual(socket.broadcasts.map((b) => b.event), ['pgn_loaded']);
});

test('a speaker indicator is relayed only into the voice the socket joined', async () => {
  const outsider = setUp({});
  outsider.socket.handlers.audio_speaker_active({ roomId: '123456', isSpeaking: true });
  assert.deepEqual(outsider.socket.broadcasts, []);

  const inside = setUp({ audioRoomId: '123456', audioUserId: 5 });
  inside.socket.handlers.audio_speaker_active({ roomId: '123456', isSpeaking: true });
  assert.equal(inside.socket.broadcasts.length, 1);
});

test('an event with no payload at all does not throw', async () => {
  const { socket } = setUp({ roomId: '123456' });
  await socket.handlers.move();
  await socket.handlers.pgn_loaded();
  socket.handlers.audio_speaker_active();
  assert.deepEqual(socket.broadcasts, []);
});
