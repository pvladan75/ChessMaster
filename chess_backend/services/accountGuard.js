// accountGuard.js — whether the account behind a valid token still exists.
//
// A token is a signed slip, not a row. `jwt.verify` proves the server issued it
// and that it has not expired; it proves nothing about the account it names.
// Until now nothing asked the second question, so a deleted account kept a
// working login for the remaining life of its token — **up to seven days**.
//
// Found on 25.8.2026 by emptying the database and watching a wiped account
// reconnect and register presence as "pavle (ID: 5)". Two reasons it matters
// beyond that afternoon:
//
//   * **The privacy policy promises deletion.** A parent may ask for the whole
//     account to go, and the consent text says it goes. A login that keeps
//     working for a week afterwards is that promise not being kept — the same
//     shape as a consent column that is written and never read.
//   * **Ids are reused.** `TRUNCATE ... RESTART IDENTITY` restarts the
//     sequence, so the fifth account created afterwards *is* id 5, and the old
//     slip becomes a valid credential for a different person. That is not a
//     stale session; it is somebody else's account.
//
// The rule here is the one this codebase keeps arriving at: **three answers,
// not two.** The account is there, the account is gone, or we could not ask.
// The third is not the second — a database that is briefly unreachable must
// not read as "your account was deleted", because the client's answer to that
// is to throw the session away.

/// What a valid token's holder is, as far as the database is concerned.
///
/// Returns `{ ok: true }`, or a refusal carrying the status to answer with:
///
///   * **403** — the token names nothing that could be a user id. It is
///     malformed rather than stale, and no amount of signing in fixes it.
///   * **401 `account-gone`** — verified, well formed, and about somebody who
///     is not here any more. This is the one a client should sign out on.
///   * **503 `unverifiable`** — the question could not be asked. Deliberately
///     not 401: the caller is told to try again, not that they were deleted.
///
/// On success it also hands back the **database's** role, which the caller
/// writes over the token's copy. A role is a claim frozen at sign-in, so an
/// admin whose rights were taken away kept them for the rest of the week — the
/// same bug as this file's, one field over. The row is already being read, so
/// the honest value is free.
///
/// The cost is one lookup by primary key per authenticated request. That is the
/// price of the promise; a cache would buy it back by reintroducing exactly the
/// window this closes, only shorter.
async function tokenHolderStanding(pool, userId) {
  const id = Number(userId);
  if (!Number.isInteger(id) || id <= 0) {
    return {
      ok: false,
      status: 403,
      reason: 'malformed',
      error: 'Neispravan token.',
      cause: null,
    };
  }

  try {
    const result = await pool.query('SELECT role FROM users WHERE id = $1', [id]);
    if (result.rowCount === 0) {
      return {
        ok: false,
        status: 401,
        reason: 'account-gone',
        error: 'Nalog više ne postoji. Prijavite se ponovo.',
        cause: null,
      };
    }
    return {
      ok: true,
      status: 200,
      reason: null,
      error: null,
      cause: null,
      role: result.rows[0].role,
    };
  } catch (err) {
    // Handed back rather than swallowed: the caller logs it, and the caller is
    // the one that knows whether this was a request or a socket.
    return {
      ok: false,
      status: 503,
      reason: 'unverifiable',
      error: 'Trenutno ne možemo da proverimo nalog. Pokušajte ponovo.',
      cause: err,
    };
  }
}

module.exports = { tokenHolderStanding };
