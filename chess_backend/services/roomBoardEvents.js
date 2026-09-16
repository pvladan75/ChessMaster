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
// guest list. test/room_board_events.test.js.

const logger = require('./logger');

/// True when `joinGame` seated this socket in `roomId`.
function isSeatedIn(socket, roomId) {
  return typeof roomId === 'string' && roomId !== '' && socket.roomId === roomId;
}

/// Registers the board events on one connected socket.
///
/// `canAdministerRoom(socket, roomId)`, `denyPrivileged(socket, event, roomId)`
/// and `members()` stay in `server.js`, which owns the member table they read.
function registerRoomBoardEvents(socket, { pool, canAdministerRoom, denyPrivileged, members = () => ({}) }) {
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

  /// A student offers the position on their board to one member of the room.
  ///
  /// Restored 16.9.2026: the handler was deleted on 10.8.2026 while the app
  /// kept its button and kept saying „Position sent to trainer!". The sender's
  /// name comes from the socket and the recipient must be seated in the same
  /// room — a position is not a message channel to anybody with an id.
  socket.on('student_shares_position', ({ roomId, targetUserId, fen, pgn, title } = {}) => {
    if (!isSeatedIn(socket, roomId)) return;
    if (typeof fen !== 'string' || fen.length === 0 || fen.length > 120) return;
    const room = members()[roomId] || {};
    const target = room[targetUserId];
    if (!target || !target.socketId || String(targetUserId) === String(socket.userId)) return;
    socket.to(target.socketId).emit('student_position_shared', {
      studentId: socket.userId,
      studentName: socket.userName || 'Student',
      title: typeof title === 'string' && title.length <= 200 ? title : 'Position',
      fen,
      pgn: typeof pgn === 'string' && pgn.length <= 100000 ? pgn : null,
    });
  });
}

module.exports = { registerRoomBoardEvents, isSeatedIn };
