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

/// Who the server saw in a room while a recording was running.
///
/// Here for the same reason `onlineUsers` is: the socket layer knows it and an
/// HTTP route needs it. The upload arrives long after everybody has left, when
/// the room's member list is already empty — so without this, the save could
/// only be checked against nobody, which is the same as not checking it.
///
/// Its honest limit, written down rather than assumed away: this is memory, so
/// a backend restarted mid-lesson forgets. `POST /recordings/save` then says
/// the check could not run instead of quietly passing — "it did not run" and
/// "it passed" are the two states this project keeps collapsing into one.
const recordedRoomParticipants = {}; // roomCode -> Set(userId)

/// Starts the record for a room, with everybody who is in it now.
function beginRecordingRoster(roomCode, userIds) {
  recordedRoomParticipants[roomCode] = new Set(
    [...userIds].map(Number).filter(Number.isInteger),
  );
}

/// Adds somebody who walked in while it was running. A no-op when nothing is
/// being recorded, which is what makes it safe to call on every join.
function noteRecordedParticipant(roomCode, userId) {
  const roster = recordedRoomParticipants[roomCode];
  if (!roster) return false;
  const id = Number(userId);
  if (!Number.isInteger(id)) return false; // a guest, who has no account
  roster.add(id);
  return true;
}

/// What the room saw, or `null` when there is no record — which is not the
/// same as an empty room and must not be read as one.
function recordedRoster(roomCode) {
  const roster = recordedRoomParticipants[roomCode];
  return roster ? [...roster] : null;
}

function clearRecordedRoster(roomCode) {
  delete recordedRoomParticipants[roomCode];
  delete consentStops[roomCode];
}

/// A recording this server stopped itself, because somebody whose parent has
/// not agreed to a recording walked into the lesson.
///
/// This used to be `clearRecordedRoster`, and throwing the roster away made the
/// case indistinguishable from a backend restarted mid-lesson: the save found
/// no roster, took the branch written for the restart, and told the trainer
/// "I could not check who was on the lesson" about a room whose reason it had
/// logged thirteen seconds earlier. Seen in the log on 25.8.2026. Two states
/// collapsed into one — the failure this project keeps repeating — and worse,
/// the second lock then held nothing at all for that room.
const consentStops = {}; // roomCode -> { at, reason, blocked:Set, stoppedAt }

/// How long the room has to answer the stop before its upload stops counting as
/// the recording that was interrupted. An honest client sends `stopped` in the
/// same second (0s in the log of 25.8.2026); this is wide enough for a bad
/// connection and far too narrow to cover a client that simply kept recording.
const CONSENT_STOP_GRACE_MS = 30_000;

function stopRecordingForConsent(roomCode, { reason = null, blocked = [] } = {}) {
  const blockedIds = new Set([...blocked].map(Number).filter(Number.isInteger));
  // What was recorded before they walked in stays the trainer's, because they
  // are not in it — so the newcomer comes out of the roster, rather than the
  // roster being thrown away with them.
  const roster = recordedRoomParticipants[roomCode];
  if (roster) for (const id of blockedIds) roster.delete(id);
  consentStops[roomCode] = {
    at: Date.now(), reason, blocked: blockedIds, stoppedAt: null,
  };
}

/// The room answering. `recording_status_update {status:'stopped'}` is proof
/// the client obeyed, it already existed, and a client that ignores
/// `recording_must_stop` never sends it — which is exactly the client the save
/// has to refuse.
function noteRecordingStopped(roomCode) {
  const stop = consentStops[roomCode];
  if (!stop || stop.stoppedAt !== null) return false;
  stop.stoppedAt = Date.now();
  return true;
}

/// What the save should make of this room: `null` when nothing was stopped for
/// consent, otherwise the record, with `obeyed` already decided.
function consentStop(roomCode) {
  const stop = consentStops[roomCode];
  if (!stop) return null;
  return {
    at: stop.at,
    reason: stop.reason,
    blocked: [...stop.blocked],
    obeyed: stop.stoppedAt !== null
      && stop.stoppedAt - stop.at <= CONSENT_STOP_GRACE_MS,
  };
}

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
  beginRecordingRoster,
  noteRecordedParticipant,
  recordedRoster,
  clearRecordedRoster,
  stopRecordingForConsent,
  noteRecordingStopped,
  consentStop,
  CONSENT_STOP_GRACE_MS,
  init,
  setOnline,
  goOffline,
  socketIdOf,
  emitToUser,
};
