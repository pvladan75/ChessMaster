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

function setOnline(user, socketId) {
  onlineUsers[user.id] = {
    socketId,
    userId: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
  };
}

function goOffline(userId) {
  if (onlineUsers[userId]) {
    delete onlineUsers[userId];
    return true;
  }
  return false;
}

function socketIdOf(userId) {
  return onlineUsers[userId] ? onlineUsers[userId].socketId : null;
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
  const socketId = socketIdOf(userId);
  if (!socketId) return false;

  try {
    io.to(socketId).emit(event, payload);
  } catch (err) {
    // The transport failing is a runtime condition, not a wiring mistake: the
    // notification row is already written and the action already happened.
    logger.error(`[REALTIME] could not send ${event} to user ${userId}:`, err);
    return false;
  }
  logger.info(`[REALTIME] ${event} -> user ${userId}`);
  return true;
}

module.exports = {
  onlineUsers,
  init,
  setOnline,
  goOffline,
  socketIdOf,
  emitToUser,
};
