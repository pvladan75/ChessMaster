// roomLifecycle.js — a session has a beginning and an end.
//
// Until 21.9.2026 it had only a beginning. `rooms.status` allowed `'archived'`
// and nothing ever wrote it: every `POST /rooms/create` minted a new code and
// the old ones stayed open for ever, so an invitation from last week was still
// a working door. Reported live as three faults at once — no voice, a recording
// made „with several present", nobody sure who was leading — and the log gave
// one cause: two people sitting in two different rooms, each alone, one of them
// let in by an old invitation (`docs/PLAN-SESIJA.md`, §1).
//
// Two rules, and this file is their one home:
//
//   * **A trainer has at most one live session.** Starting a new one ends
//     whatever they had open, so „this trainer's session" names one room.
//   * **An ended room admits nobody** — not its creator either. That half lives
//     in `roomAccess.mayJoinRoom`, because the socket, `/rooms/join` and
//     `/agora/token` all ask there and must not be able to drift apart.
//
// Nothing here sweeps old rooms at startup: the first rule closes a trainer's
// stale rooms the next time they start a session, which is the moment it
// matters, and a server that rewrites rows while it boots is how this project
// has lost data before.

const { mayJoinRoom, REFUSED } = require('./roomAccess');
const { acceptedTrainersOf } = require('./relationshipService');

/// What the app may be told about a room it remembers.
const ROOM_STATE = {
  live: 'live',
  ended: 'ended',
  /// No such room, or not one this account may enter. One answer for both, for
  /// the reason `/rooms/join` gives: the reply must not confirm a code exists.
  notYours: 'not-yours',
};

/// Ends `roomCode` if it is `userId`'s and still live. Returns whether this
/// call is the one that ended it, so the caller announces an ending once.
async function endRoom(pool, { roomCode, userId }) {
  if (typeof roomCode !== 'string' || roomCode.trim() === '') return false;
  if (userId === null || userId === undefined) return false;

  const result = await pool.query(
    `UPDATE rooms
        SET status = 'archived', ended_at = NOW()
      WHERE room_code = $1 AND creator_id = $2 AND status <> 'archived'
      RETURNING room_code`,
    [roomCode, userId],
  );
  return result.rowCount > 0;
}

/// Ends every live room `userId` created, and returns their codes so whoever is
/// still sitting in one can be told.
async function endLiveRoomsOf(pool, userId) {
  if (userId === null || userId === undefined) return [];

  const result = await pool.query(
    `UPDATE rooms
        SET status = 'archived', ended_at = NOW()
      WHERE creator_id = $1 AND status <> 'archived'
      RETURNING room_code`,
    [userId],
  );
  return result.rows.map((row) => row.room_code);
}

/// Whether a room the app remembers is still somewhere to go back to.
///
/// Asked through `mayJoinRoom` rather than with a query of its own: „live" has
/// to mean „you could walk in now", or Home offers to resume a room whose door
/// then refuses.
async function roomState(pool, { roomCode, userId }) {
  const seat = await mayJoinRoom(pool, { roomCode: String(roomCode ?? ''), userId });
  if (seat.allowed) return ROOM_STATE.live;
  return seat.reason === REFUSED.ended ? ROOM_STATE.ended : ROOM_STATE.notYours;
}

/// The sessions `userId` could walk into right now: live rooms started by
/// somebody who teaches them. What Home draws as „*Name* is in a session — Join",
/// and what replaced typing a six-digit code (removed 21.9.2026).
///
/// Two halves, on purpose. The query finds candidates through
/// `acceptedTrainersOf` — the one home of „because someone teaches me". Then
/// every candidate is put to `mayJoinRoom`, because a room narrowed by a guest
/// list is live and its creator does teach this person, and it is still not
/// theirs to enter: a row offered here must be a door that opens.
async function liveSessionsFor(pool, userId) {
  if (userId === null || userId === undefined) return [];

  const candidates = await pool.query(
    `SELECT r.room_code, u.name AS trainer_name
       FROM rooms r
       JOIN users u ON u.id = r.creator_id
      WHERE r.status <> 'archived'
        AND r.creator_id IN (${acceptedTrainersOf('$1')})
      ORDER BY r.created_at DESC, r.id DESC`,
    [userId],
  );

  const sessions = [];
  for (const row of candidates.rows) {
    const seat = await mayJoinRoom(pool, { roomCode: row.room_code, userId });
    if (seat.allowed) {
      sessions.push({ roomCode: row.room_code, trainerName: row.trainer_name });
    }
  }
  return sessions;
}

module.exports = { ROOM_STATE, endRoom, endLiveRoomsOf, roomState, liveSessionsFor };
