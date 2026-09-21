// Reaching a signed-in user who is connected right now.
//
// Two halves already existed and never met: `onlineUsers`, a socket-id registry
// living inside server.js, and the notification rows written by the HTTP routes.
// So a notification raised while the app was open sat in the database until the
// next launch — the client fetches `/notifications` at startup and on a socket
// event, never on a timer. That is why an answered request looked like nothing
// had happened.
//
// The registry moved here so both halves can use it. The socket is only the
// nudge: the notification row is the durable record, and a recipient who is
// offline simply reads it the next time they open the app.

const logger = require('./logger');

const onlineUsers = {}; // userId -> { socketId, userId, name, email, role }

let io = null;

/// Handed the Socket.IO server once, at startup, before any route is served.
function init(ioInstance) {
  io = ioInstance;
}

/// A person is reachable at **every** socket they hold, and they hold two while
/// they are in a room: Home's and the room's. The table kept one, so whichever
/// registered last was the only one that heard anything — and the room's never
/// registered at all, which is why „Grant microphone" did not reach a student
/// sitting in the room it was granted in: their Home socket is disconnected for
/// as long as the room is open (`docs/PLAN-SESIJA.md`, F9).
function setOnline(user, socketId) {
  const entry = onlineUsers[user.id];
  const socketIds = entry ? entry.socketIds : new Set();
  socketIds.add(socketId);
  onlineUsers[user.id] = {
    socketIds,
    userId: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
  };
}

/// [socketId] is the socket that closed, and it takes only itself: seen in the
/// log of 21.9.2026, „User registered" and one line later „User disconnected"
/// for the same id — the room's socket closing had wiped what Home's had
/// registered, and every nudge missed that person afterwards. Without a
/// [socketId] the call means „this person, everywhere".
///
/// True when this call is the one that took the person offline altogether.
function goOffline(userId, socketId = null) {
  const entry = onlineUsers[userId];
  if (!entry) return false;
  if (socketId !== null) {
    if (!entry.socketIds.delete(socketId)) return false;
    if (entry.socketIds.size > 0) return false;
  }
  delete onlineUsers[userId];
  return true;
}

/// Every socket `userId` is reachable at, oldest first.
function socketIdsOf(userId) {
  return onlineUsers[userId] ? [...onlineUsers[userId].socketIds] : [];
}

/// The socket a person registered last — kept for callers that want one.
function socketIdOf(userId) {
  const ids = socketIdsOf(userId);
  return ids.length > 0 ? ids[ids.length - 1] : null;
}

/// Nudges one user, if they are connected. Returns whether anything was sent.
///
/// Missing [init] is a wiring mistake rather than a runtime condition, and it
/// would otherwise make every nudge in the app quietly do nothing — the exact
/// failure this module exists to end. So it throws, at the first call, where the
/// stack still says who forgot.
function emitToUser(userId, event, payload) {
  if (!io) {
    throw new Error('realtime.init(io) was never called');
  }
  const socketIds = socketIdsOf(userId);
  if (socketIds.length === 0) return false;

  try {
    for (const socketId of socketIds) io.to(socketId).emit(event, payload);
  } catch (err) {
    // The transport failing is a runtime condition, not a wiring mistake: the
    // notification row is already written and the action already happened.
    logger.error(`[REALTIME] could not send ${event} to user ${userId}:`, err);
    return false;
  }
  logger.info(`[REALTIME] ${event} -> user ${userId}`);
  return true;
}

/// What else has to forget a room when it ends. `server.js` keeps the seated
/// roster and the voice roster in its own memory, so it registers here rather
/// than this module reaching back into it.
const roomClosers = [];

function onRoomClosed(fn) {
  roomClosers.push(fn);
}

/// Tells everybody in `roomCode` that the session is over, then empties it.
///
/// **The order is the rule** (CLAUDE.md, „do the thing, then say it" — here the
/// saying *is* the thing for the people in the room, so it goes first, and
/// nothing after it may stop the rest): the announcement, then the sockets out
/// of the room, then the rosters. A closer that throws is logged and the others
/// still run — a room half-forgotten is a seat nobody holds.
function closeRoom(roomCode, { reason = 'ended' } = {}) {
  if (!io) {
    throw new Error('realtime.init(io) was never called');
  }
  try {
    io.to(roomCode).emit('session_ended', { roomId: roomCode, reason });
    io.in(roomCode).socketsLeave(roomCode);
  } catch (err) {
    logger.error(`[REALTIME] could not announce the end of room ${roomCode}:`, err);
  }
  for (const closer of roomClosers) {
    try {
      closer(roomCode);
    } catch (err) {
      logger.error(`[REALTIME] a closer failed for room ${roomCode}:`, err);
    }
  }
  logger.info(`[SOBA] ${roomCode}: sesija završena (${reason})`);
}

module.exports = {
  onlineUsers,
  init,
  setOnline,
  goOffline,
  socketIdOf,
  socketIdsOf,
  emitToUser,
  onRoomClosed,
  closeRoom,
};
