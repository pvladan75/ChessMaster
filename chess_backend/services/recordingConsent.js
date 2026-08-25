// recordingConsent.js — whether this lesson may be recorded, and who says no.
//
// This closes the half of the consent flow that was a written record and
// nothing more. `parent_allows_recording` was filled honestly by the parent's
// page from the first day it existed, and **nothing read it**: the column was
// touched by exactly two places, the migration that created it and the write
// that set it. A rule that is recorded and never enforced is this codebase's
// oldest failure wearing its best suit — and `docs/saglasnost-roditelja.md`
// says so itself: "Druga stavka je važnija od prve — ona pretvara pravilo iz
// obećanja u nešto što sistem stvarno sprovodi."
//
// **The rule: a lesson may not be recorded while a child whose parent has not
// agreed to recording is in the room.** Not "should not" — `uploads/` is the
// one thing in this project that cannot be reproduced or anonymised, and a
// child's voice put there is put there for good.
//
// Three decisions shape it.
//
// **Only a *stated* minor blocks anything.** An account whose age nobody has
// ever asked about is not blocked, which is the same grandfathering `status`
// and `voice_level` got: refusing on an empty column would have switched
// recording off for every lesson in the app on the strength of a field that was
// empty an hour ago. The teeth arrive with the age gate, as everywhere else in
// this area.
//
// **`NULL` and `false` both block, and they are told apart.** Once a child is
// known to be a child, "the parent said no" and "no parent was ever asked" are
// the same answer to "may I record" and different answers to "what do I do
// about it" — one is a decision to respect, the other a letter to send.
//
// **Blocking a new recording is not the same as rewriting an old one.** The
// decision of 25.8.2026 was *tell the trainer, do not change what exists*: an
// age arriving late does not silently mute a child or undo a relationship. That
// rule is about state somebody already relies on. This is about an action that
// has not happened yet, and refusing to start it takes nothing away from
// anybody.

const { statedAge, ageOfConsent } = require('./ageService');

/// Which of these people may not be recorded by this trainer, and why not.
///
/// Guests are skipped: they join with a socket id rather than a user id, they
/// have no account and therefore no stated age, and whether they may be in the
/// room at all is the guest switch's question rather than this one.
///
/// The room's owner is skipped too — they are the one recording.
async function blockedForRecording(pool, { ownerId, userIds }) {
  const candidates = [...new Set((userIds ?? []).map(Number))]
    .filter((id) => Number.isInteger(id) && id !== Number(ownerId));
  if (candidates.length === 0) return [];

  // One query, left-joined: somebody in the room with no relationship row to
  // this trainer still has an age, and a stated minor sitting in a lesson with
  // no relationship at all is the least consented case there is.
  const result = await pool.query(
    `SELECT u.id, u.name, u.birth_year, ts.parent_allows_recording
       FROM users u
       LEFT JOIN trainer_students ts
         ON ts.student_id = u.id AND ts.trainer_id = $1
      WHERE u.id = ANY($2::int[])`,
    [ownerId, candidates],
  );

  const blocked = [];
  for (const row of result.rows) {
    const age = statedAge(row.birth_year);
    // Nobody ever asked. Not blocked, and deliberately so.
    if (age === null) continue;
    if (age >= ageOfConsent()) continue;
    if (row.parent_allows_recording === true) continue;

    blocked.push({
      id: row.id,
      name: row.name || 'Učenik',
      reason: row.parent_allows_recording === false ? 'refused' : 'not-asked',
    });
  }
  return blocked;
}

/// The same question asked about a room, which is how both callers ask it.
///
/// `allowed: false` with an empty `blocked` never happens: a refusal here can
/// always name who it is about, because a trainer who is told "no" without
/// being told which child cannot do anything about it.
async function mayRecordRoom(pool, { roomCode, userIds }) {
  const room = await pool.query(
    'SELECT creator_id FROM rooms WHERE room_code = $1',
    [roomCode],
  );
  if (room.rowCount === 0) {
    return { allowed: false, blocked: [], reason: 'Soba ne postoji.' };
  }

  const blocked = await blockedForRecording(pool, {
    ownerId: room.rows[0].creator_id,
    userIds,
  });
  if (blocked.length === 0) {
    return { allowed: true, blocked: [], reason: null };
  }
  return { allowed: false, blocked, reason: refusalSentence(blocked) };
}

/// What the trainer is told, naming the children and the way out.
///
/// Two lists rather than one, because the two halves need different actions:
/// a parent who refused is a decision to respect, and a parent who was never
/// asked is a letter that has not gone out yet.
function refusalSentence(blocked) {
  const refused = blocked.filter((b) => b.reason === 'refused').map((b) => b.name);
  const notAsked = blocked.filter((b) => b.reason !== 'refused').map((b) => b.name);

  const parts = [];
  if (refused.length > 0) {
    parts.push(
      `roditelj nije dozvolio snimanje za: ${refused.join(', ')}`,
    );
  }
  if (notAsked.length > 0) {
    parts.push(
      `saglasnost roditelja za snimanje još nije data za: ${notAsked.join(', ')}`,
    );
  }
  return `Čas ne može da se snima — ${parts.join('; ')}.`;
}

module.exports = {
  blockedForRecording,
  mayRecordRoom,
  refusalSentence,
};
