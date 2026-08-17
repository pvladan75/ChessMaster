// googleAccount.js
// What a "no password" account looks like in the users table.
//
// `password_hash` is NOT NULL, so an account created through Google sign-in has
// to put *something* there. It puts this marker. The consequence is easy to miss:
// `bcrypt.compare(anything, marker)` returns false rather than throwing, so such
// an account answers every password with "Invalid email or password" — identical
// to a typo. That cost a live debugging session on 17.8.2026.

const GOOGLE_PLACEHOLDER_HASH = 'google_oauth_placeholder_hash';

/// True when the stored value is a marker rather than a real hash.
///
/// Matched on the prefix, not on equality: a bcrypt hash always begins with
/// `$2`, so the two can never be confused, and an older or later marker spelling
/// still reads as passwordless instead of silently accepting a login attempt.
function isPasswordlessHash(passwordHash) {
  return typeof passwordHash === 'string' && passwordHash.startsWith('google_');
}

module.exports = { GOOGLE_PLACEHOLDER_HASH, isPasswordlessHash };
