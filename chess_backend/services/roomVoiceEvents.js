// roomVoiceEvents.js
// Leaving the voice is not leaving the room.
//
// Found on 21.9.2026 from the owner's live pass of `docs/PLAN-SESIJA.md`: after
// „Leave voice" a trainer's roster stopped updating, and so — unnoticed — did
// their board. `audio_leave` ended with `socket.leave(roomId)`, and the voice and
// the board share one Socket.IO room named by the room code: `audio_join` joins
// it (a second time, for a seated socket), so its mirror image took the socket
// out of **everything** the room broadcasts — `room_members_list`, `move`,
// `pgn_loaded`, `session_ended`. The socket stayed on the roster, which is what
// made it look like a display fault on one device.
//
// The rule: **a socket that `joinGame` seated stays in the room until it
// disconnects or the session ends.** Only a socket that is in the room for the
// voice alone is taken out of it by leaving the voice.
//
// Moved out of `server.js` so a test can drive it, as `roomBoardEvents.js` was.

const logger = require('./logger');

/// Takes `userId` off `roster[roomId]` — **but only the entry `socketId`
/// wrote**, and answers whether anything was removed.
///
/// Both rosters are keyed by person, and a person's sockets overlap: a dropped
/// connection is noticed tens of seconds after the app is back on a new socket.
/// Deleting by person let that late `disconnect` remove the seat the new socket
/// had just taken — seated, talking, and gone from the list.
function dropEntry(roster, roomId, userId, socketId) {
  const room = roster[roomId];
  const entry = room && room[userId];
  if (!entry || entry.socketId !== socketId) return false;
  delete room[userId];
  if (Object.keys(room).length === 0) delete roster[roomId];
  return true;
}

/// Registers `audio_leave`, and the voice half of `disconnect`, on one
/// connected socket.
///
/// `audioUsers()` is `server.js`'s voice roster, `flushAudioUsage` books the
/// metered seconds; both stay there with the rest of the voice handlers.
function registerRoomVoiceEvents(socket, { io, audioUsers, flushAudioUsage }) {
  /// The one way out of the voice, whichever event brought it.
  function leaveVoice() {
    const roomId = socket.audioRoomId;
    const userId = socket.audioUserId;

    // Booked whoever holds the roster entry now: these are the seconds *this*
    // socket ran up.
    flushAudioUsage(socket);
    socket.audioRoomId = null;
    socket.audioUserId = null;

    if (dropEntry(audioUsers(), roomId, userId, socket.id)) {
      // Said even when nobody is left — **an empty list is news**. Without it
      // everybody whose voice is off keeps the last list they heard, and the
      // room goes on offering a call nobody is in.
      const left = audioUsers()[roomId];
      io.to(roomId).emit('audio_users_list', left ? Object.values(left) : []);
    }
    return { roomId, userId };
  }

  socket.on('audio_leave', ({ roomId } = {}) => {
    const userId = socket.audioUserId;
    // The app says this on closing the room whether or not the voice was ever
    // on. Nothing was joined, so there is nothing to leave — and above all
    // nothing to take out of the room.
    if (userId === undefined || userId === null || socket.audioRoomId !== roomId) {
      return;
    }

    leaveVoice();

    if (socket.roomId !== roomId) socket.leave(roomId);
    logger.info(`[AUDIO] User ${userId} left audio in room ${roomId}`);
  });

  // A dropped connection is the common ending for a lesson, not the rare one.
  socket.on('disconnect', () => {
    if (!socket.audioRoomId || !socket.audioUserId) return;
    leaveVoice();
  });
}

module.exports = { registerRoomVoiceEvents, dropEntry };
