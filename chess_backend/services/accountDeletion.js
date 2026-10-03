// accountDeletion.js — an account deleted by the person it belongs to.
//
// The owner's decisions of 3.10.2026: it is confirmed (the password, or the
// typed word for an account that has none), it happens at once, and **the
// account's files go with it** — the sound of its recordings, the narration of
// its tutorials and their films. The privacy policy had promised all of that
// since it was written („Brisanjem naloga trajno se brišu i svi vezani
// podaci"), and until now no route kept the promise.
//
// **The rows are the schema's work.** Every table that names a user does so
// through a foreign key that cascades (or sets null), so `DELETE FROM users`
// takes the account's rows with it, and `test/account_deletion_db.test.js`
// holds every such key to that on a real database. What a cascade cannot do is
// delete a file, so the two tables whose rows name files are deleted here by
// hand first, `RETURNING` what they named — the same statement that removes a
// row is the one that says which file it was.
//
// This module reads no path and removes no file: the caller does
// (`routes/account.js`), because the helpers that turn a row into a path import
// `middleware/auth`, and a service must load without `JWT_SECRET`.

const bcrypt = require('bcrypt');
const { isPasswordlessHash } = require('./googleAccount');
const { endLiveRoomsOf } = require('./roomLifecycle');

/// What an account without a password types instead of one.
const CONFIRM_WORD = 'DELETE';

/// Which proof this account gives: `'password'`, or `'word'` for an account
/// made through Google, which has no password that could be asked for.
function confirmationKind(passwordHash) {
  return isPasswordlessHash(passwordHash) ? 'word' : 'password';
}

/// Null when [body] proves the request is meant, or the refusal to answer
/// with. Never 401: the app reads a 401 as a session that ended, and a
/// mistyped password is not that.
async function confirmationProblem(passwordHash, body) {
  if (confirmationKind(passwordHash) === 'word') {
    if (body && body.confirm === CONFIRM_WORD) return null;
    return {
      status: 400,
      body: { error: `Type ${CONFIRM_WORD} to confirm.`, code: 'confirmation-required' },
    };
  }
  const password = body && body.password;
  if (typeof password !== 'string' || password === '') {
    return { status: 400, body: { error: 'Enter your password to confirm.', code: 'password-required' } };
  }
  if (typeof passwordHash !== 'string' || !(await bcrypt.compare(password, passwordHash))) {
    return { status: 400, body: { error: 'Wrong password.', code: 'wrong-password' } };
  }
  return null;
}

/// Deletes [userId] and everything that belongs to it, in one transaction.
///
/// Answers null when there is no such account, and otherwise what the caller
/// still has to do once the rows are gone:
///
///   * `rooms` — the codes of the sessions this account had live, so whoever
///     is sitting in one is told;
///   * `lessons` — `{ narration_filename, video_filename }` of every tutorial
///     that went, **including a row the account only taught** (`trainer_id`),
///     because that row cascades too and its files would be left behind;
///   * `recordings` — `{ audio_file, audio_url, video_url }` of its recordings.
///
/// The user's row is locked first, so a session being started or a tutorial
/// being saved at the same moment waits and then finds no account, rather than
/// writing a row between the two deletes whose file nobody collects.
async function deleteAccount(pool, userId) {
  const id = Number(userId);
  if (!Number.isInteger(id) || id <= 0) return null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const held = await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [id]);
    if (held.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    const rooms = await endLiveRoomsOf(client, id);
    const lessons = await client.query(
      `DELETE FROM saved_lessons WHERE user_id = $1 OR trainer_id = $1
       RETURNING narration_filename, video_filename`,
      [id],
    );
    const recordings = await client.query(
      `DELETE FROM session_recordings WHERE host_id = $1
       RETURNING audio_file, audio_url, video_url`,
      [id],
    );
    await client.query('DELETE FROM users WHERE id = $1', [id]);
    await client.query('COMMIT');
    return { rooms, lessons: lessons.rows, recordings: recordings.rows };
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { CONFIRM_WORD, confirmationKind, confirmationProblem, deleteAccount };
