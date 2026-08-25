// ageService.js — how old the user says they are, and the one thing that
// follows from it.
//
// Two facts decide the shape of this file.
//
// **The app does not know anybody's age.** `users` has an email, a name, a
// password and a verification flag; there is no birth date and no parent.
// Google sign-in does not help — it returns an email, a name and a `sub`, and
// no age even for an account supervised by Family Link. So the age is something
// the user tells us, or nothing at all.
//
// **An age is a statement, not proof.** A child can type any year. That is why
// nothing which actually protects a child is allowed to *depend* on this
// number: the room's guest list and the per-relationship consent hold whatever
// is typed here. The age decides which flow somebody goes through, not how safe
// they are.
//
// What it does decide, and the rule this file exists for: **a minor connects to
// an adult who teaches them, and to nobody else.** Not to another child as a
// "student", not to another child as their "trainer". The app is then not a
// place where children meet each other, which is the answer to the question
// about which countries this can ship in — and it is cheap, because the edge
// with consent on it already exists.

const logger = require('./logger');

/// The strictest threshold that is actually applicable, and the default.
///
/// Not 18: the GDPR digital-consent age runs from 13 to 16 depending on the
/// country and never above it, so 18 buys friction rather than protection.
/// Serbia — the only country this ships to on the lawyer's advice of 25.8.2026
/// — sits at 15, and 16 covers it. It is configuration rather than a constant
/// because the number is a per-country decision, and the country list is
/// somebody's decision to make rather than a default to accept.
const DEFAULT_AGE_OF_CONSENT = 16;

/// Parses `AGE_OF_CONSENT`, or says why it cannot.
///
/// Returns the number, or throws. Deliberately narrow: outside 13–18 there is
/// no legal regime this could be implementing, so a stray value is a mistake
/// rather than a choice, and the mistake is one that quietly stops protecting
/// children. Empty means "not configured", which is the strict default.
function parseAgeOfConsent(raw) {
  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return DEFAULT_AGE_OF_CONSENT;
  }
  const value = Number(String(raw).trim());
  if (!Number.isInteger(value) || value < 13 || value > 18) {
    throw new RangeError(
      `AGE_OF_CONSENT must be a whole number between 13 and 18, got: ${raw}`,
    );
  }
  return value;
}

// Read once, at startup, and loudly. A threshold that falls back to a default
// because somebody wrote `AGE_OF_CONSENT=sixteen` is this codebase's recurring
// bug aimed at the one rule that decides whether a child can be enrolled by
// another child.
let AGE_OF_CONSENT;
try {
  AGE_OF_CONSENT = parseAgeOfConsent(process.env.AGE_OF_CONSENT);
} catch (err) {
  logger.error(`FATAL: ${err.message}`);
  process.exit(1);
}

function ageOfConsent() {
  return AGE_OF_CONSENT;
}

/// The youngest this person can be, given the year they gave.
///
/// A year rather than a full date is deliberate: it is one field less about a
/// child, and it answers the only question asked of it. The cost is that within
/// the year of somebody's birthday the answer is ambiguous by one — so the
/// *younger* reading is taken. Somebody born in 2010 counts as 15 for the whole
/// of 2026, including after their sixteenth birthday. That errs towards asking
/// a parent when it did not have to, which is the direction to err in.
///
/// `null` when nothing was ever stated, and for a year that cannot be one.
function statedAge(birthYear, now = new Date()) {
  const year = Number(birthYear);
  if (!Number.isInteger(year)) return null;

  const thisYear = now.getFullYear();
  if (year < 1900 || year > thisYear) return null;

  return Math.max(0, thisYear - year - 1);
}

/// The year somebody typed, or the reason it cannot be one.
///
/// Lives here rather than inside the route because it is the only part of
/// stating an age that can be got wrong quietly: a check that lets `0` or
/// `"2014abc"` through writes a row that `statedAge` then reads as *no age at
/// all*, and the account goes back to being one nobody has ever asked — while
/// the screen says it was saved. The route is a thin caller so this can be
/// tested without a database.
///
/// The upper bound is this year: somebody not yet born has no age, and a year
/// in the future is a typo rather than a claim.
function parseStatedYear(raw, now = new Date()) {
  const thisYear = now.getFullYear();
  const year = Number(raw);
  const ok = typeof raw !== 'boolean'
    && raw !== null
    && String(raw).trim() !== ''
    && Number.isInteger(year)
    && year >= 1900
    && year <= thisYear;

  if (!ok) {
    return {
      year: null,
      error: `Unesite godinu rođenja, između 1900. i ${thisYear}.`,
    };
  }
  return { year, error: null };
}

/// What is known about one user's age.
///
/// `known: false` is a real answer and not an error — today it is the answer for
/// every account, because nothing has ever asked. Callers must handle it
/// explicitly rather than letting it collapse into "adult": that collapse is
/// how a rule ends up looking implemented while doing nothing.
async function ageStatus(pool, userId) {
  if (userId === null || userId === undefined) {
    return { known: false, minor: false, age: null };
  }

  const result = await pool.query(
    'SELECT birth_year FROM users WHERE id = $1',
    [userId],
  );
  if (result.rowCount === 0) {
    return { known: false, minor: false, age: null };
  }

  const age = statedAge(result.rows[0].birth_year);
  if (age === null) {
    return { known: false, minor: false, age: null };
  }
  return { known: true, minor: age < ageOfConsent(), age };
}

/// Whether a relationship may be created between these two, and why not.
///
/// The whole rule, in one place, so the two routes that create an edge
/// (`requestRelationship` and `respondToRequest`) cannot drift apart — the same
/// reason `acceptedTrainersOf` exists.
///
///   * a minor may be the **student**, never the trainer;
///   * so two minors are refused whichever way round they ask, since one of
///     them would have to be the trainer.
///
/// The honest limit, written down rather than assumed away: while nobody's age
/// is known, this refuses nothing. The teeth arrive with the age gate that
/// fills `users.birth_year` — and that gate has to ask **existing** accounts as
/// well as new ones, or this rule stays a comment. That is the trap this
/// codebase keeps falling into, one layer up.
async function mayRelate(pool, { trainerId }) {
  // Only the teaching side is asked about. A minor on the *student* side is the
  // case this whole model is for; a minor on the trainer side is two children
  // pairing up with one of them holding homework, reports and a recording of
  // the other's voice.
  const trainer = await ageStatus(pool, trainerId);

  if (trainer.minor) {
    return {
      allowed: false,
      reason: 'minor-as-trainer',
      message: 'Maloletnik ne može da bude trener. '
        + 'Vezu sa učenikom zasniva punoletna osoba.',
    };
  }

  return { allowed: true, reason: null, message: null };
}

/// Where a new relationship starts on the microphone.
///
/// A child begins by listening: they hear the trainer, answer on the board and
/// with the ready answers, and their own voice is never published — so it is
/// never in the recording either. Talking is granted afterwards, by the trainer,
/// once there is a reason to.
///
/// The gain is not mainly legal. `uploads/` is the one thing in this project
/// that cannot be reproduced or anonymised, and this keeps a child's voice out
/// of it until somebody has decided it belongs there.
///
/// An adult, and anybody whose age is unknown, starts talking: that is how every
/// lesson works today, and muting forty existing students on the strength of a
/// column nobody has filled in would be its own kind of silent failure. The
/// teeth arrive with the age gate, like the rest of this file.
async function startingVoiceLevel(pool, studentId) {
  const student = await ageStatus(pool, studentId);
  return student.minor ? 'listen' : 'talk';
}

module.exports = {
  startingVoiceLevel,
  DEFAULT_AGE_OF_CONSENT,
  parseAgeOfConsent,
  parseStatedYear,
  ageOfConsent,
  statedAge,
  ageStatus,
  mayRelate,
};
