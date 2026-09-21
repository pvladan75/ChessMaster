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

test('an event with no payload at all does not throw', async () => {
  const { socket } = setUp({ roomId: '123456' });
  await socket.handlers.move();
  await socket.handlers.pgn_loaded();
  socket.handlers.student_shares_position();
  assert.deepEqual(socket.broadcasts, []);
});

// Sharing a position: restored 16.9.2026 after five weeks with a button that
// said „Position sent to trainer!" and no handler behind it.

function sharing(seat, members) {
  const socket = fakeSocket({ userId: 7, userName: 'Student Seven', ...seat });
  const denied = [];
  registerRoomBoardEvents(socket, {
    pool: { query: async () => ({ rows: [], rowCount: 0 }) },
    canAdministerRoom: async () => false,
    denyPrivileged: (_s, event, roomId) => denied.push({ event, roomId }),
    members: () => members,
  });
  return socket;
}

const ROOM = { '123456': { 1: { userId: 1, socketId: 'trainer-socket', role: 'trener' }, 7: { userId: 7, socketId: 'sock-1' } } };
const FEN = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

test('a seated student shares a position with a member of the room, named by the server', async () => {
  const socket = sharing({ roomId: '123456' }, ROOM);
  socket.handlers.student_shares_position({ roomId: '123456', targetUserId: 1, fen: FEN, studentName: 'Somebody Else' });
  assert.equal(socket.broadcasts.length, 1);
  const sent = socket.broadcasts[0];
  assert.equal(sent.roomId, 'trainer-socket', 'only to the chosen member, not the whole room');
  assert.equal(sent.event, 'student_position_shared');
  assert.equal(sent.payload.studentName, 'Student Seven', 'the name comes from the socket, not the message');
  assert.equal(sent.payload.fen, FEN);
});

test('a position is not shared by a socket outside the room, nor with somebody who is not in it', async () => {
  const outside = sharing({}, ROOM);
  outside.handlers.student_shares_position({ roomId: '123456', targetUserId: 1, fen: FEN });
  assert.deepEqual(outside.broadcasts, []);

  const seated = sharing({ roomId: '123456' }, ROOM);
  seated.handlers.student_shares_position({ roomId: '123456', targetUserId: 99, fen: FEN });
  assert.deepEqual(seated.broadcasts, []);
});

test('a share without a position sends nothing', async () => {
  const socket = sharing({ roomId: '123456' }, ROOM);
  socket.handlers.student_shares_position({ roomId: '123456', targetUserId: 1, fen: '' });
  assert.deepEqual(socket.broadcasts, []);
});

// Two board states, and one leader — phase 3 of docs/PLAN-SESIJA.md.

const fs = require('node:fs');
const path = require('node:path');
const {
  BOARD_LOCKED, BOARD_OPEN, boardIsOpen, boardControlFor,
} = require('../services/roomBoardEvents');

test('every spelling the column has held reads as one of two states', () => {
  for (const locked of ['host_only', 'trainer_only', null, undefined, '']) {
    assert.equal(boardIsOpen(locked), false, String(locked));
  }
  // `student_white` and `student_black` never filtered a move by colour on
  // either end: they were open boards with a misleading label.
  for (const open of ['student_both', 'student_white', 'student_black', 'unrestricted']) {
    assert.equal(boardIsOpen(open), true, open);
  }
});

test('what is stored is one of two values, and nonsense is not stored', () => {
  assert.equal(boardControlFor('host_only'), BOARD_LOCKED);
  assert.equal(boardControlFor('trainer_only'), BOARD_LOCKED);
  for (const open of ['student_both', 'student_white', 'student_black', 'unrestricted']) {
    assert.equal(boardControlFor(open), BOARD_OPEN, open);
  }
  // The value is broadcast to every client in the room and read back on join.
  for (const junk of ['', 'everyone', null, undefined, 7, { a: 1 }, "x'; DROP TABLE rooms; --"]) {
    assert.equal(boardControlFor(junk), null, String(junk));
  }
  // What is written must read back as what was meant.
  assert.equal(boardIsOpen(BOARD_OPEN), true);
  assert.equal(boardIsOpen(BOARD_LOCKED), false);
});

test('a client that asks for a board state that does not exist is refused, not stored', () => {
  // Read from the source because the handler lives in server.js, which cannot
  // be required without starting a server. Comments are stripped first: the
  // story of the old behaviour is told in them.
  const source = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8')
    .split(/\r?\n/).map((line) => line.replace(/\/\/.*$/, '')).join('\n');

  const start = source.indexOf("socket.on('change_permissions'");
  assert.ok(start > 0, 'change_permissions was not found');
  const handler = source.slice(start, source.indexOf("socket.on('", start + 10));
  assert.match(handler, /boardControlFor\(boardControl\)/);
  assert.match(handler, /stored === null/);
  assert.doesNotMatch(handler, /\[boardControl, roomId\]/,
    'the raw value from the client is what gets stored');

  // One leader: nobody is promoted, and a seat does not administer a room.
  assert.ok(!source.includes("'change_user_role'"), 'promotion is back');
  assert.ok(!/role === 'host'/.test(source), 'the co-host seat still counts for something');
  assert.ok(!source.includes('previousSeat'), 'a seat survives a rejoin again');
});
