// roomAccess.js — who may be in a room, and in what seat.
//
// Until this file existed the answer was "anybody": `joinGame` took a room code
// and joined, without asking whether the caller had any business there — not a
// relationship, not an invitation, not even a login, since a guest joined as
// "Gost". `audio_join` was the same, so whoever was in the room was in the
// voice; and when the trainer records, that voice lands in uploads/ beside the
// children's. The code was six digits from `Math.random()` with no limit on
// attempts, which made it a lock in name only.
//
// The rule now: **a room is a place with a guest list, not a string that opens
// a door.** The code stays useful — it is how a student names the room they are
// joining — but it stops being the thing that authorises them.
//
// The list, in order:
//
//   1. The room's creator. Their room, their seat as host.
//   2. If the room has a **guest list** — groups or single students the trainer
//      invited — then whoever is on it, and nobody else. An empty list means
//      what the room always meant: every accepted student of the creator. One
//      row narrows it, which is exactly what "invite this group" has to mean.
//   3. Otherwise, anyone in an accepted relationship with the creator, in
//      either direction. Read through `acceptedEdgeBetween` rather than a fresh
//      subquery, for the reason CLAUDE.md gives: three hand-written copies of
//      that condition all forgot `status`, and an unanswered request already
//      unlocked what it had asked for.
//   4. Anyone the creator invited to a session scheduled on this very room
//      code — the invitation is the consent, and it is already recorded.
//   5. A guest, only where the room says guests are allowed. Off by default,
//      because the default decides what happens in the room nobody thought
//      about.
//
// Being on the guest list is not on its own enough: the accepted relationship is
// checked as well, so a student who left keeps no key through a group row that
// was never cleaned up.
//
// Everything else is refused, with a reason the screen can say out loud. A
// refusal that reads as "connecting…" forever is the same silent failure this
// codebase keeps paying for.

const { acceptedEdgeBetween } = require('./relationshipService');

/// Why somebody is not in the room. The app turns these into sentences, so they
/// are values rather than prose.
const REFUSED = {
  noRoom: 'no-room',
  guestNotAllowed: 'guest-not-allowed',
  notInvited: 'not-invited',
};

/**
 * Decides whether `userId` may enter the room with `roomCode`.
 *
 * `userId` is null for somebody who is not signed in. Returns the seat as well,
 * so the caller does not have to work out a second time who the host is.
 */
async function mayJoinRoom(pool, { roomCode, userId = null }) {
  if (typeof roomCode !== 'string' || roomCode.trim() === '') {
    return { allowed: false, reason: REFUSED.noRoom, role: null };
  }

  const room = await pool.query(
    'SELECT creator_id, allow_guests FROM rooms WHERE room_code = $1',
    [roomCode],
  );
  if (room.rowCount === 0) {
    return { allowed: false, reason: REFUSED.noRoom, role: null };
  }

  const creatorId = room.rows[0].creator_id;
  const allowGuests = room.rows[0].allow_guests === true;

  if (userId === null || userId === undefined) {
    return allowGuests
      ? { allowed: true, reason: null, role: 'gost' }
      : { allowed: false, reason: REFUSED.guestNotAllowed, role: null };
  }

  if (creatorId !== null && Number(userId) === Number(creatorId)) {
    return { allowed: true, reason: null, role: 'trener' };
  }

  const related = await acceptedEdgeBetween(pool, creatorId, userId);

  // Does this room have a guest list at all?
  const list = await pool.query(
    'SELECT 1 FROM room_guests WHERE room_code = $1 LIMIT 1',
    [roomCode],
  );

  if (list.rowCount > 0) {
    // Narrowed. On the list *and* still a student — the second half is what
    // keeps a stale group row from being a key.
    const onList = await pool.query(
      `SELECT 1
         FROM room_guests rg
         LEFT JOIN student_group_members m ON m.group_id = rg.group_id
        WHERE rg.room_code = $1
          AND ($2 = rg.user_id OR $2 = m.student_id)
        LIMIT 1`,
      [roomCode, userId],
    );
    if (onList.rowCount > 0 && related) {
      return { allowed: true, reason: null, role: 'ucenik' };
    }
    return { allowed: false, reason: REFUSED.notInvited, role: null };
  }

  if (related) {
    return { allowed: true, reason: null, role: 'ucenik' };
  }

  const invited = await pool.query(
    `SELECT 1
       FROM scheduled_session_invites i
       JOIN scheduled_sessions s ON s.id = i.session_id
      WHERE s.room_code = $1 AND i.user_id = $2 AND i.status <> 'declined'
      LIMIT 1`,
    [roomCode, userId],
  );
  if (invited.rowCount > 0) {
    return { allowed: true, reason: null, role: 'ucenik' };
  }

  return { allowed: false, reason: REFUSED.notInvited, role: null };
}

module.exports = { mayJoinRoom, REFUSED };
