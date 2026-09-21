// recordingConsent.js — who may put a voice into `uploads/`, and why almost
// nobody may.
//
// **The rule, since 26.8.2026: audio is recorded only by an adult, alone.** The
// interaction between a trainer and a student is not recorded at all, by
// anyone, under any consent — and since phase 5a of docs/PLAN-SESIJA.md
// (22.9.2026) a room is not recorded at all, so there is no roster left to ask.
// A voice is recorded where nobody else can be connected: the trainer's own
// device, over a tutorial (and, with phase 5b, over a lesson in Preparation).
//
// The decision behind it. A recorded lesson was the one feature in this app
// that put a child's voice into `uploads/`, which is the only thing here that
// cannot be reproduced, anonymised or taken back. It bought a replay of the
// lesson; it cost a per-market legal text about children's voices and the worst
// breach this project could have. „Recorded with several present" — the owner's
// report of 21.9.2026 — was that check getting a room wrong; the room no longer
// asks it, so it cannot.
//
// Two consequences worth stating, because each is a place this could quietly
// stop meaning anything.
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

/// Whether this account may record its own voice over a tutorial — phase 3 of
/// `docs/PLAN-SNIMANJE.md`, and the rule a room once had, re-expressed.
///
/// **The studio has no room**, so there is nobody else to ask about: the
/// recording is made on the trainer's own device, and nobody else is connected
/// to it. What must not be assumed is that the rest goes with it. The owner's
/// half stays, with both of its edges: **eighteen, not
/// `AGE_OF_CONSENT`**, and **an unknown age refuses** — this is permission to
/// put into `uploads/` the one artefact that cannot be taken back, and „we
/// never asked" must not read as „yes".
async function mayRecordNarration(pool, userId) {
  const owner = await ageStatus(pool, userId);
  if (!owner.known) {
    return {
      allowed: false,
      reason: 'Recording requires entering your birth year — only adults may '
        + 'record their voice.',
    };
  }
  if (owner.age < ADULT_AGE) {
    return { allowed: false, reason: 'Recording is only available to adult users.' };
  }
  return { allowed: true, reason: null };
}

module.exports = {
  ADULT_AGE,
  mayRecordNarration,
  // Re-exported so a caller that only needs the age reading does not have to
  // reach past this module for it.
  statedAge,
};
