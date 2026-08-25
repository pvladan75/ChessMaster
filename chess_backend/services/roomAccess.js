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
//   4. Anyone **the creator** invited to a session scheduled on this very room
//      code — the invitation is the consent, and it is already recorded. Whose
//      invitation it is has to be checked: the row is written by whoever asks
//      to schedule something, so without that check an invitation to oneself
//      would be a key to anybody's room.
//   5. A guest, only where the room says guests are allowed. Off by default,
//      because the default decides what happens in the room nobody thought
//      about.
//
// Being on the guest list is not on its own enough: the accepted relationship is
// checked as well, so a student who left keeps no key through a group row that
// was never cleaned up.
//
// The guest door is the **last** one tried, and it is tried for everybody who
// got no further — signed in or not. It used to be asked only of somebody who
// was not signed in, which had it backwards: a stranger who logged out could
// watch a room that accepted guests while a parent with an account could not.
// `allow_guests` now means one thing wherever it is read: *anyone who knows the
// code may come in, as a guest*. That includes a room narrowed by a guest list
// — the list decides who is a **student** here, the switch decides whether
// anybody may watch — and the screen that offers the switch says so, because a
// control whose meaning changes depending on another screen is the same kind of
// surprise as one that works while its button is hidden.
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
  const signedIn = userId !== null && userId !== undefined;

  /// The last door, for whoever every other check has turned away. The refusal
  /// keeps saying which kind of person was refused, so the screen can answer
  /// "prijavite se" and "niste pozvani" differently.
  const asGuest = () => (allowGuests
    ? { allowed: true, reason: null, role: 'gost' }
    : {
      allowed: false,
      reason: signedIn ? REFUSED.notInvited : REFUSED.guestNotAllowed,
      role: null,
    });

  if (!signedIn) {
    return asGuest();
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
    return asGuest();
  }

  if (related) {
    return { allowed: true, reason: null, role: 'ucenik' };
  }

  // `s.host_id = $3` is not decoration. Without it the door opens on a row
  // anybody can write: `POST /sessions/schedule` takes a room code and a list of
  // user ids, so a stranger could schedule a session **on somebody else's room
  // code**, invite themselves, and walk past the guest list holding an
  // invitation they had issued to themselves. The invitation is consent only
  // when it came from the person whose room it is.
  const invited = await pool.query(
    `SELECT 1
       FROM scheduled_session_invites i
       JOIN scheduled_sessions s ON s.id = i.session_id
      WHERE s.room_code = $1 AND i.user_id = $2 AND s.host_id = $3
        AND i.status <> 'declined'
      LIMIT 1`,
    [roomCode, userId, creatorId],
  );
  if (invited.rowCount > 0) {
    return { allowed: true, reason: null, role: 'ucenik' };
  }

  return asGuest();
}

/// Whether `userId` may **speak** in this room, or only listen.
///
/// Until this existed the answer was "everybody, always": `/agora/token` handed
/// out a publisher token to any signed-in caller for any channel name, and the
/// channel name is the room code. So the guest list guarded the socket while the
/// voice channel stayed open — somebody could take a token, join the Agora
/// channel and be heard in a lesson without ever passing `joinGame`. They would
/// not even appear on the roster.
///
/// Two different questions, answered here together because they must not drift:
///
///   * **may you be here at all** — `mayJoinRoom`, unchanged;
///   * **may you be heard** — the room's creator always; a guest never, because
///     a guest came to watch; a student according to `voice_level` on the
///     relationship, which is where "this child listens, that one talks" is
///     recorded.
///
/// Anyone let in on a scheduled-session invitation without an accepted
/// relationship listens: there is no relationship row to hold a decision about
/// their microphone, and the missing answer must not read as "yes".
///
/// The point of deciding it here rather than in the app: a microphone that is
/// off because the client chose to mute itself is off until somebody replaces
/// the client. This answer becomes the **role in the token**, which Agora
/// enforces on its own side.
async function maySpeakInRoom(pool, { roomCode, userId = null }) {
  const seat = await mayJoinRoom(pool, { roomCode, userId });
  if (!seat.allowed) {
    return { allowed: false, maySpeak: false, reason: seat.reason, role: null };
  }

  if (seat.role === 'trener') {
    return { allowed: true, maySpeak: true, reason: null, role: seat.role };
  }

  if (seat.role !== 'ucenik') {
    // A guest watches. Nothing about a guest says anybody agreed to hear them,
    // and if the trainer is recording, a guest's voice would land in uploads/
    // beside the children's.
    return { allowed: true, maySpeak: false, reason: 'gost-slusa', role: seat.role };
  }

  const level = await pool.query(
    `SELECT ts.voice_level
       FROM trainer_students ts
       JOIN rooms r ON r.room_code = $1
      WHERE ts.status = 'accepted'
        AND ((ts.trainer_id = r.creator_id AND ts.student_id = $2)
          OR (ts.trainer_id = $2 AND ts.student_id = r.creator_id))
      LIMIT 1`,
    [roomCode, userId],
  );

  // No row: in the room on an invitation to a scheduled session, with no
  // relationship behind it. Listening is the honest answer to a question nobody
  // has been asked.
  const maySpeak = level.rowCount > 0 && level.rows[0].voice_level === 'talk';
  return {
    allowed: true,
    maySpeak,
    reason: maySpeak ? null : 'samo-slusa',
    role: seat.role,
  };
}

/// Whether this room is `userId`'s to configure.
///
/// One copy, because the condition is a right and this codebase has already
/// paid for the same right written out three times: `studentGroups` reads it
/// from here rather than keeping its own.
async function ownsRoom(pool, { roomCode, userId }) {
  if (typeof roomCode !== 'string' || roomCode.trim() === '') return false;
  if (userId === null || userId === undefined) return false;

  const result = await pool.query(
    'SELECT 1 FROM rooms WHERE room_code = $1 AND creator_id = $2',
    [roomCode, userId],
  );
  return result.rowCount > 0;
}

/// Does this room take guests? Only its creator gets to ask, and only its
/// creator gets to answer — `null` means "not yours", which the route turns
/// into a 403 rather than into a comfortable `false`.
async function guestAccess(pool, { roomCode, userId }) {
  if (!(await ownsRoom(pool, { roomCode, userId }))) return null;

  const result = await pool.query(
    'SELECT allow_guests FROM rooms WHERE room_code = $1',
    [roomCode],
  );
  if (result.rowCount === 0) return null;
  return result.rows[0].allow_guests === true;
}

/// Opens or closes the guest door. Returns what the room says afterwards, read
/// back from the row rather than echoed from the request: a switch that reports
/// the value it was handed is the failure this codebase keeps meeting — it
/// looks right in the app and is wrong in the database.
async function setGuestAccess(pool, { roomCode, userId, allowGuests }) {
  if (!(await ownsRoom(pool, { roomCode, userId }))) return null;

  const result = await pool.query(
    `UPDATE rooms SET allow_guests = $1
      WHERE room_code = $2
      RETURNING allow_guests`,
    [allowGuests === true, roomCode],
  );
  if (result.rowCount === 0) return null;
  return result.rows[0].allow_guests === true;
}

module.exports = {
  mayJoinRoom,
  maySpeakInRoom,
  ownsRoom,
  guestAccess,
  setGuestAccess,
  REFUSED,
};
