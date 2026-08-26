// recordingConsent.js — who may put a voice into `uploads/`, and why almost
// nobody may.
//
// **The rule, since 26.8.2026: audio is recorded only by an adult who is alone
// in the room.** Not "a lesson may be recorded once the parent agrees" — the
// interaction between a trainer and a student is not recorded at all any more,
// by anyone, under any consent.
//
// The decision behind it. A recorded lesson was the one feature in this app
// that put a child's voice into `uploads/`, which is the only thing here that
// cannot be reproduced, anonymised or taken back. It bought a replay of the
// lesson; it cost a per-market legal text about children's voices and the worst
// breach this project could have. The replay survives without it: a recording
// is a `timeline_json` — moves, arrows, marks — and `audio_url` was always
// nullable. So the lesson is still replayed, silently, and what is gone is only
// the sound of a child.
//
// What is left is a feature rather than a leftover: a trainer alone in a room
// records teaching material, downloads it and publishes it wherever they like.
// Nobody else is in the recording, so nobody else has to agree to it.
//
// Three consequences worth stating, because each is a place this could quietly
// stop meaning anything.
//
// **Anybody who is not the owner blocks it — guests included.** A guest has no
// account and therefore no age and no relationship, which under the old rule
// made them invisible to it. Under this rule they need no account to matter:
// they are somebody else in the room, and that is the whole question. The
// roster keeps their socket id for exactly this reason.
//
// **An unknown age is a refusal, not a pass.** Recording is for adults, and an
// account nobody has ever asked cannot be asserted to be one. Everywhere else
// in this codebase an unstated age is deliberately grandfathered — refusing on
// an empty column would have switched a working feature off for everybody. Here
// the direction is reversed on purpose: this is permission to create the one
// artefact that cannot be undone, and "we never asked" must not read as "yes".
// The refusal says what to do about it, which is why it is a separate reason.
//
// **Eighteen, not `AGE_OF_CONSENT`.** The consent age is 13–18 by country and
// answers a different question — whether a parent must agree to processing. This
// one is about publishing a recording of your own voice, so it is majority, and
// it is a constant rather than configuration because it is not a per-country
// decision this app gets to make.

const { statedAge, ageStatus } = require('./ageService');

/// Old enough to record and publish their own voice.
const ADULT_AGE = 18;

/// Everybody in this room who is not its owner.
///
/// Ids arrive as numbers for accounts and as socket ids for guests, and both
/// count. Compared as strings so that `7` and `'7'` are one person, and so a
/// guest id that is not a number at all survives the comparison instead of
/// being dropped by it.
function othersInRoom(userIds, ownerId) {
  const owner = String(ownerId);
  return [...new Set((userIds ?? []).map(String))]
    .filter((id) => id !== '' && id !== 'undefined' && id !== 'null')
    .filter((id) => id !== owner);
}

/// Who is in the way of a recording, named where they can be named.
///
/// A name is looked up for accounts so the trainer is told *who* — a refusal
/// that cannot name anybody is one nobody can act on. Guests have no account
/// and no name, and are called what they are.
async function blockedForRecording(pool, { ownerId, userIds }) {
  const others = othersInRoom(userIds, ownerId);
  if (others.length === 0) return [];

  const accountIds = others.map(Number).filter(Number.isInteger);
  const names = new Map();
  if (accountIds.length > 0) {
    const result = await pool.query(
      'SELECT id, name FROM users WHERE id = ANY($1::int[])',
      [accountIds],
    );
    for (const row of result.rows) names.set(String(row.id), row.name);
  }

  return others.map((id) => ({
    id: Number.isInteger(Number(id)) ? Number(id) : id,
    name: names.get(id) || (Number.isInteger(Number(id)) ? 'Učesnik' : 'Gost'),
    reason: 'present',
  }));
}

/// Whether this room may be recording audio right now.
///
/// `allowed: false` always carries a reason a human can act on, and `blocked`
/// names the people when the answer is about people. When the answer is about
/// the owner's own age, `blocked` is empty and the reason says so — there is
/// nobody to name.
async function mayRecordRoom(pool, { roomCode, userIds }) {
  const room = await pool.query(
    'SELECT creator_id FROM rooms WHERE room_code = $1',
    [roomCode],
  );
  if (room.rowCount === 0) {
    return { allowed: false, blocked: [], reason: 'Soba ne postoji.' };
  }

  const ownerId = room.rows[0].creator_id;

  // Asked first, and about people rather than about the owner: somebody else in
  // the room is the answer the trainer can do something about immediately.
  const blocked = await blockedForRecording(pool, { ownerId, userIds });
  if (blocked.length > 0) {
    return { allowed: false, blocked, reason: refusalSentence(blocked) };
  }

  const owner = await ageStatus(pool, ownerId);
  if (!owner.known) {
    return {
      allowed: false,
      blocked: [],
      reason: 'Snimanje traži da unesete godinu rođenja — snima se samo '
        + 'punoletna osoba, sama u sobi.',
    };
  }
  if (owner.age < ADULT_AGE) {
    return {
      allowed: false,
      blocked: [],
      reason: 'Snimanje je dostupno samo punoletnim korisnicima.',
    };
  }

  return { allowed: true, blocked: [], reason: null };
}

/// What the trainer is told when somebody else is in the room.
///
/// One sentence that says the rule as well as the fact, because "Mila is in the
/// room" without "a lesson is not recorded" reads like a fault to be worked
/// around rather than the way this works.
function refusalSentence(blocked) {
  const names = blocked.map((b) => b.name).join(', ');
  return `Čas se ne snima. Zvuk se snima samo dok ste sami u sobi, a ovde je `
    + `još: ${names}.`;
}

module.exports = {
  ADULT_AGE,
  blockedForRecording,
  mayRecordRoom,
  othersInRoom,
  refusalSentence,
  // Re-exported so a caller that only needs the age reading does not have to
  // reach past this module for it.
  statedAge,
};
