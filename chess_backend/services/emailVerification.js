// emailVerification.js — what a verification code is worth.
//
// This is a service and not four lines inside the route because of what those
// four lines were doing. `/verify-email` looked the account up by address and,
// **if it was already verified, signed a token and returned it** — without
// checking the code, and without a password ever being involved. Anybody who
// knew any registered address could post it with six arbitrary digits and get a
// seven-day session for that account. Every account on the server, including
// every child's.
//
// The branch was almost certainly written for a kindness: a user who submits
// the same code twice, or whose first reply was lost, should not be told their
// code is wrong when their account is fine. That kindness must not be a token.
//
// The rule now lives in one pure function so it can be stated as a list of
// cases and tested as one. A gate that is a paragraph inside a route handler is
// a gate nobody reads twice.

const OUTCOME = {
  /// The code matches an account waiting to be verified. Issue the token.
  OK: 'ok',

  /// No code, wrong code, or an account with none stored.
  BAD_CODE: 'bad_code',

  /// This account has been verified already. **Never a token**: verification
  /// proves the address was reachable once, and reachable-once is not a
  /// credential. Whoever this is signs in with their password or with Google,
  /// both of which prove something about *now*.
  ALREADY_VERIFIED: 'already_verified',
};

/// Which of the three cases this attempt is.
///
/// Deliberately total: every combination lands on exactly one outcome, and
/// there is no path that falls through to "issue a token" by omission. That is
/// how the hole existed — not as a wrong comparison, but as a branch that
/// returned early before any comparison happened.
function verificationOutcome({ isVerified, storedCode, providedCode }) {
  if (isVerified) return OUTCOME.ALREADY_VERIFIED;

  // An account with no stored code has nothing to match. Answering "bad code"
  // rather than "ok" matters: `null === null` and `'' === ''` are both true in
  // the wrong shape of this check, and either one hands out a token.
  if (storedCode === null || storedCode === undefined || `${storedCode}`.trim() === '') {
    return OUTCOME.BAD_CODE;
  }
  if (providedCode === null || providedCode === undefined) return OUTCOME.BAD_CODE;

  return `${storedCode}`.trim() === `${providedCode}`.trim()
    ? OUTCOME.OK
    : OUTCOME.BAD_CODE;
}

module.exports = { OUTCOME, verificationOutcome };
