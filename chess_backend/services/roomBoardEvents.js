// roomBoardEvents.js
// The events that change what everybody in a room sees on the board.
//
// Moved out of `server.js` on 16.9.2026 so they can be driven by a test, because
// the audit that day found them answering anybody: `move` and `pgn_loaded` asked
// only whether the room's board was open, never whether the socket sending them
// had joined the room. A client that knew a six-digit code — invited or not,
// refused at the door by `joinGame` or not, signed in or not — could push moves
// into a live lesson and overwrite the room's stored position. The guest list in
// `mayJoinRoom` guarded the door and nothing guarded the board.
//
// The rule is one sentence: **a socket acts in the room it was seated in.**
// `joinGame` is the only place a seat is granted (`socket.roomId`), after the
// guest list; `audio_join` seats a socket in a room's voice (`socket.audioRoomId`)
// after its own. test/room_board_events.test.js.

const logger = require('./logger');

/// True when `joinGame` seated this socket in `roomId`.
function isSeatedIn(socket, roomId) {
  return typeof roomId === 'string' && roomId !== '' && socket.roomId === roomId;
}

/// True when `audio_join` admitted this socket to `roomId`'s voice.
function isInVoiceOf(socket, roomId) {
  return typeof roomId === 'string' && roomId !== '' && socket.audioRoomId === roomId;
}

/// Registers the board and speaker events on one connected socket.
///
/// `canAdministerRoom(socket, roomId)` and `denyPrivileged(socket, event, roomId)`
/// stay in `server.js`, which owns the member table they read.
function registerRoomBoardEvents(socket, { pool, canAdministerRoom, denyPrivileged }) {
  /// Enforces the room's board_control setting server-side, for a socket that is
  /// already seated. Rooms that do not exist in the database (the local 'STUDIO'
  /// board) have no shared state to protect.
  async function canMoveInRoom(roomId) {
    let room;
    try {
      const res = await pool.query('SELECT board_control FROM rooms WHERE room_code = $1', [roomId]);
      room = res.rows[0];
    } catch (err) {
      logger.error('Error checking board control:', err);
      return false;
    }
    if (!room) return true;
    const control = room.board_control || 'host_only';
    if (control !== 'host_only' && control !== 'trainer_only') return true;
    return canAdministerRoom(socket, roomId);
  }

  socket.on('move', async ({ roomId, move, currentFen, role, currentMoveIndex, movePath } = {}) => {
    // Not seated: dropped without a word. The only client that does this on
    // purpose is the local Preparation board, which connects a socket, never
    // joins a room, and still reports its moves — telling it „no permission" on
    // every move would be a red bar over somebody's own analysis. Anybody else
    // who is not seated has nothing to be told.
    if (!isSeatedIn(socket, roomId)) return;
    if (!(await canMoveInRoom(roomId))) {
      return denyPrivileged(socket, 'move', roomId);
    }
    socket.to(roomId).emit('move', { move, currentFen, role, currentMoveIndex, movePath });
    try {
      await pool.query('UPDATE rooms SET current_fen = $1 WHERE room_code = $2', [currentFen, roomId]);
    } catch (err) {
      logger.error('Error updating room FEN:', err);
    }
  });

  socket.on('pgn_loaded', async ({ roomId, pgn } = {}) => {
    if (!isSeatedIn(socket, roomId)) return;
    if (!(await canMoveInRoom(roomId))) {
      return denyPrivileged(socket, 'pgn_loaded', roomId);
    }
    socket.to(roomId).emit('pgn_loaded', { pgn });
  });

  socket.on('audio_speaker_active', ({ roomId, isSpeaking } = {}) => {
    if (!isInVoiceOf(socket, roomId)) return;
    socket.to(roomId).emit('audio_speaker_active', { userId: socket.audioUserId, isSpeaking });
  });
}

module.exports = { registerRoomBoardEvents, isSeatedIn, isInVoiceOf };
