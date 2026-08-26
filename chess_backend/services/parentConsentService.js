// parentConsentService.js — the parent's half of a teaching relationship.
//
// The rule it implements, in one sentence: **a minor's relationship with a
// trainer does not start when the two of them agree, it starts when the parent
// says so.** Both sides agreeing moves the row to `awaiting_parent`, which is
// the state the column was given when it was added and nothing has ever
// written until now.
//
// Three decisions shape this file.
//
// **The parent confirms through a link in an email, not through a code typed
// into the app.** The choice was made on 25.8.2026 and the reason is the
// record: `parent_consent_at`, `parent_consent_ip` and `parent_consent_version`
// are three columns that only a page the parent actually opened can fill
// honestly. A code read out to a child proves that a mail arrived; it does not
// show that anybody read the text, and a consent record that cannot say what
// was consented to is not a record.
//
// **The text has a version, and the version is configuration.** The wording was
// confirmed by a lawyer on 25.8.2026 **for Serbia only, and he said so
// explicitly**. It will change when the country list does, so which text
// somebody agreed to is stored per answer, copied onto the request when it is
// created rather than read again when it is answered.
//
// **The token is a token, not a name.** It is 32 random bytes from
// `crypto.randomBytes`, stored hashed, single-use and time-limited. The room
// code was six digits from `Math.random()` for a year and that was a lock which
// was not one; this opens a page listing a child's name, their trainer's name
// and what may be done with their voice.

const crypto = require('crypto');
const logger = require('./logger');

/// How long a request stays answerable.
///
/// Fourteen days rather than an hour: this is not a login code that somebody is
/// waiting on with the app open, it is an email to a parent who may read it on
/// Sunday. Long enough not to be a trap, short enough that a link in an old
/// inbox is not a permanent key.
const EXPIRY_DAYS = 14;

/// The wording in `docs/saglasnost-roditelja.md`, as approved on 25.8.2026.
///
/// The country is part of the identifier on purpose: the same product will need
/// different text elsewhere, and `2026-08-25` alone would not say which of them
/// a parent read.
const DEFAULT_TEXT_VERSION = 'rs-2026-08-25';

/// Parses `PARENT_CONSENT_VERSION`, or says why it cannot.
///
/// Narrow deliberately: this string is written into a legal record and read
/// back years later, so a stray space or a 60-character sentence is a mistake
/// rather than a choice. The column is `VARCHAR(40)`, and a value the database
/// would truncate is a record that quietly says something else.
function parseTextVersion(raw) {
  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return DEFAULT_TEXT_VERSION;
  }
  const value = String(raw).trim();
  if (!/^[A-Za-z0-9._-]{1,40}$/.test(value)) {
    throw new RangeError(
      'PARENT_CONSENT_VERSION must be 1-40 characters of letters, digits, '
      + `dot, dash or underscore, got: ${raw}`,
    );
  }
  return value;
}

/// Parses `PUBLIC_BASE_URL`, or says why it cannot.
///
/// `null` when it is not set, which is not an error: the whole flow only
/// matters once a minor enrols, and every development machine runs without one.
/// A value that is set but is not an absolute http(s) origin **is** an error,
/// and a loud one — a half-formed base makes a link that goes nowhere, and the
/// only person who would ever find out is a parent who has already decided the
/// app does not work.
function parseBaseUrl(raw) {
  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return null;
  }
  const value = String(raw).trim().replace(/\/+$/, '');
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new RangeError(`PUBLIC_BASE_URL is not a URL: ${raw}`);
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new RangeError(`PUBLIC_BASE_URL must be http or https, got: ${raw}`);
  }
  return value;
}

// Both read once, at startup. A version that falls back because somebody typed
// it with a space, or a base URL that is silently dropped, are this codebase's
// recurring bug pointed at the one record that is supposed to prove a parent
// agreed.
let TEXT_VERSION;
let BASE_URL;
try {
  TEXT_VERSION = parseTextVersion(process.env.PARENT_CONSENT_VERSION);
  BASE_URL = parseBaseUrl(process.env.PUBLIC_BASE_URL);
} catch (err) {
  logger.error(`FATAL: ${err.message}`);
  process.exit(1);
}

if (BASE_URL === null) {
  logger.warn(
    '[SAGLASNOST] PUBLIC_BASE_URL nije podešen — link za roditelja ne može da '
    + 'se sastavi. Veza sa maloletnikom će stati na "čeka roditelja" i to će '
    + 'biti prijavljeno, umesto da tiho postane odobrena.',
  );
}

function textVersion() {
  return TEXT_VERSION;
}

function baseUrl() {
  return BASE_URL;
}

/// The link a parent opens, or `null` when this server cannot make one.
///
/// Null rather than a relative path: a half link in an email is worse than no
/// email, because it looks like the app asked and the parent failed to answer.
function consentLink(token) {
  if (BASE_URL === null) return null;
  return `${BASE_URL}/consent/${token}`;
}

/// An email address, or why it is not one.
///
/// Not a full RFC check — those either reject real addresses or accept
/// anything. This rejects what is actually typed wrong: no `@`, spaces, a
/// missing dot in the domain.
function parseParentEmail(raw) {
  const value = String(raw ?? '').trim().toLowerCase();
  const ok = value.length > 0
    && value.length <= 255
    && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  if (!ok) {
    return { email: null, error: 'Unesite ispravnu email adresu roditelja.' };
  }
  return { email: value, error: null };
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

/// Opens a request against one relationship, returning what the mail needs.
///
/// The relationship is put into `awaiting_parent` in the same transaction that
/// writes the request: a row that says "accepted" while nobody has asked a
/// parent, or a request with no relationship behind it, are both worse than
/// either half failing.
///
/// A previous unanswered request for the same relationship is dropped. Two live
/// links for one question means the record cannot say which one the parent
/// answered — and a parent who asks for the mail again should not have to find
/// the newest of three.
async function openRequest(pool, { relationshipId, studentId, trainerId, parentEmail }) {
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `DELETE FROM parent_consent_requests
        WHERE relationship_id = $1 AND answered_at IS NULL`,
      [relationshipId],
    );
    await client.query(
      `INSERT INTO parent_consent_requests
         (relationship_id, student_id, trainer_id, parent_email, token_hash,
          text_version, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [relationshipId, studentId, trainerId, parentEmail, hashToken(token),
        TEXT_VERSION, expiresAt],
    );
    await client.query(
      `UPDATE trainer_students
          SET status = 'awaiting_parent',
              parent_email = $2,
              responded_at = CURRENT_TIMESTAMP
        WHERE id = $1`,
      [relationshipId, parentEmail],
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  return { token, link: consentLink(token), expiresAt, textVersion: TEXT_VERSION };
}

/// What the page has to show, or why there is no page.
///
/// The reasons are kept apart — `not-found`, `expired`, `answered` — because
/// they need different sentences: one is a broken link, one is a link that has
/// to be asked for again, and one is a parent who already answered and should
/// be told so rather than shown the form a second time.
async function findRequest(pool, token) {
  const result = await pool.query(
    `SELECT r.id, r.relationship_id, r.student_id, r.trainer_id, r.parent_email,
            r.text_version, r.expires_at, r.answered_at, r.granted,
            student.name AS student_name, trainer.name AS trainer_name
       FROM parent_consent_requests r
       JOIN users student ON student.id = r.student_id
       JOIN users trainer ON trainer.id = r.trainer_id
      WHERE r.token_hash = $1`,
    [hashToken(String(token ?? ''))],
  );

  if (result.rowCount === 0) return { request: null, reason: 'not-found' };
  const row = result.rows[0];
  if (row.answered_at !== null) {
    return { request: row, reason: 'answered' };
  }
  if (new Date(row.expires_at).getTime() < Date.now()) {
    return { request: row, reason: 'expired' };
  }
  return { request: row, reason: null };
}

/// Writes the answer: on the request, on the relationship, and on the account.
///
/// All of it in one transaction, because these are three halves of one record.
/// A relationship that says `accepted` while `parent_consent_at` is empty is
/// exactly the state somebody would later point at and ask what it means.
///
/// The account row (`users.parent_consent_*`) is filled only the **first** time.
/// It answers "may this child be here at all", which one parent answers once;
/// the per-relationship columns answer "may it be this trainer", which is asked
/// again for every trainer.
///
/// Refusal is recorded too, and it deletes nothing: `granted = false` with a
/// time on it is the answer. A refused request that erased itself would look
/// identical to one that was never sent.
/// `allowsRecording` is gone from this signature on purpose rather than kept and
/// ignored. Since 26.8.2026 a lesson is not recorded at all, so there is no
/// third question for a parent to answer — and a parameter that is accepted and
/// dropped is how a rule ends up looking implemented while doing nothing, which
/// is the failure `parent_allows_recording` itself was the example of.
async function recordAnswer(pool, { token, ip, granted }) {
  const found = await findRequest(pool, token);
  if (found.reason !== null) return { ok: false, reason: found.reason };

  const row = found.request;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Single-use, and enforced by the write rather than by the read above: two
    // clicks on the same link half a second apart both pass the check, and only
    // one of them may count.
    const claimed = await client.query(
      `UPDATE parent_consent_requests
          SET answered_at = CURRENT_TIMESTAMP, granted = $2
        WHERE id = $1 AND answered_at IS NULL
        RETURNING id`,
      [row.id, granted],
    );
    if (claimed.rowCount === 0) {
      await client.query('ROLLBACK');
      return { ok: false, reason: 'answered' };
    }

    if (granted) {
      await client.query(
        `UPDATE trainer_students
            SET status = 'accepted',
                responded_at = CURRENT_TIMESTAMP,
                parent_consent_at = CURRENT_TIMESTAMP,
                parent_consent_ip = $2,
                parent_consent_version = $3
          WHERE id = $1`,
        [row.relationship_id, ip ?? null, row.text_version],
      );
      // Friendship follows an accepted relationship everywhere else in this
      // codebase, and a row in `friends` has exactly one origin. This is now one
      // of the two doors into `accepted`, so it writes it too.
      await client.query(
        `INSERT INTO friends (user_id, friend_id) VALUES ($1, $2), ($2, $1)
         ON CONFLICT DO NOTHING`,
        [row.trainer_id, row.student_id],
      );
      await client.query(
        `UPDATE users
            SET parent_email = COALESCE(parent_email, $2),
                parent_consent_at = COALESCE(parent_consent_at, CURRENT_TIMESTAMP),
                parent_consent_ip = COALESCE(parent_consent_ip, $3),
                parent_consent_version = COALESCE(parent_consent_version, $4)
          WHERE id = $1`,
        [row.student_id, row.parent_email, ip ?? null, row.text_version],
      );
    } else {
      // A refused relationship goes back to waiting on the parent rather than
      // to `accepted` or to nothing: the trainer and the child agreed, and only
      // the parent said no. Deleting it would let the pair simply ask each
      // other again and land in the same place with no record that a parent had
      // already answered.
      await client.query(
        `UPDATE trainer_students
            SET parent_consent_version = $2
          WHERE id = $1 AND status = 'awaiting_parent'`,
        [row.relationship_id, row.text_version],
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  return {
    ok: true,
    granted,
    studentId: row.student_id,
    trainerId: row.trainer_id,
    studentName: row.student_name,
    trainerName: row.trainer_name,
    relationshipId: row.relationship_id,
  };
}

module.exports = {
  DEFAULT_TEXT_VERSION,
  EXPIRY_DAYS,
  parseTextVersion,
  parseBaseUrl,
  parseParentEmail,
  textVersion,
  baseUrl,
  consentLink,
  openRequest,
  findRequest,
  recordAnswer,
};
