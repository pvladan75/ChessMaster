// email_verification.test.js
// What a six-digit code is worth, and what it is not.
//
// The hole this closes, found on 27.8.2026 while reading the route for an
// unrelated question: `/verify-email` looked the account up by address and, if
// it was already verified, **signed a token and returned it** — no code check,
// no password, nothing. Posting any registered address with any six characters
// returned a seven-day session for that account. Every account on the server.
//
// It did not look like a hole. It looked like a kindness for somebody
// submitting the same code twice, and it sat directly above the comparison it
// skipped.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { OUTCOME, verificationOutcome } = require('../services/emailVerification');

test('a matching code on a waiting account is the only way through', () => {
  assert.equal(
    verificationOutcome({
      isVerified: false,
      storedCode: '123456',
      providedCode: '123456',
    }),
    OUTCOME.OK
  );
});

test('surrounding whitespace is not a wrong code', () => {
  // The code arrives from a text field, and a phone keyboard adds a space more
  // often than a user notices.
  assert.equal(
    verificationOutcome({
      isVerified: false,
      storedCode: ' 123456 ',
      providedCode: '123456\n',
    }),
    OUTCOME.OK
  );
});

test('an already-verified account never gets a session from this route', () => {
  // The whole bug, in one assertion. Verification proves the address was
  // reachable once; reachable-once is not a credential, and this route has no
  // other proof of who is asking.
  for (const code of ['123456', '', null, undefined, '000000']) {
    assert.equal(
      verificationOutcome({
        isVerified: true,
        storedCode: null,
        providedCode: code,
      }),
      OUTCOME.ALREADY_VERIFIED,
      `verified account must not pass with code: ${code}`
    );
  }
});

test('an account with no stored code matches nothing', () => {
  // `null === null` and `'' === ''` are both true in the wrong shape of this
  // check, and either one hands out a token to somebody who typed nothing.
  for (const stored of [null, undefined, '', '   ']) {
    assert.equal(
      verificationOutcome({
        isVerified: false,
        storedCode: stored,
        providedCode: '',
      }),
      OUTCOME.BAD_CODE,
      `stored code ${JSON.stringify(stored)} must not match an empty answer`
    );
  }
});

test('a wrong code is a wrong code, whatever type it arrives as', () => {
  assert.equal(
    verificationOutcome({
      isVerified: false,
      storedCode: 123456,
      providedCode: 654321,
    }),
    OUTCOME.BAD_CODE
  );
  assert.equal(
    verificationOutcome({
      isVerified: false,
      storedCode: '123456',
      providedCode: null,
    }),
    OUTCOME.BAD_CODE
  );
});

test('a numeric stored code still matches the string that arrives', () => {
  // The column is text today, but the code is generated as a number and this
  // comparison has already been written twice.
  assert.equal(
    verificationOutcome({
      isVerified: false,
      storedCode: 123456,
      providedCode: '123456',
    }),
    OUTCOME.OK
  );
});

/// The body of one route, by matching the parentheses that open it.
///
/// Not a fixed slice: a slice runs past the end of the route into the next one,
/// so a check removed from *this* route still matches in the one below and the
/// test keeps passing. That has already happened once in this repository.
function routeBody(source, marker) {
  const start = source.indexOf(marker);
  assert.ok(start !== -1, `nema rute ${marker}`);

  let depth = 0;
  for (let i = source.indexOf('(', start); i < source.length; i++) {
    if (source[i] === '(') depth++;
    else if (source[i] === ')') {
      depth--;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  assert.fail(`ruta ${marker} nije zatvorena`);
}

const authSource = fs.readFileSync(
  path.join(__dirname, '..', 'routes', 'auth.js'),
  'utf8'
);

test('the route asks the gate rather than deciding for itself', () => {
  // Asserted on the source because the failure is invisible in behaviour: the
  // screen keeps working, verification keeps verifying, and the only difference
  // is that one branch hands out sessions.
  const route = routeBody(authSource, "router.post(['/verify-email'");

  assert.match(route, /verificationOutcome/, 'the decision must come from the gate');
  assert.match(route, /ALREADY_VERIFIED/);

  // And the shape that caused it must not come back: a token signed under a
  // bare `is_verified` test, before any code has been compared.
  assert.doesNotMatch(
    route,
    /if\s*\(\s*user\.is_verified\s*\)\s*\{\s*const token/,
    'a verified account must not be handed a token by this route'
  );
});

test('the brace matcher stops at the end of its own route', () => {
  // Proving the reader above by mutation rather than trusting it.
  const fake = [
    "router.post(['/a'], (req, res) => { res.json({ ok: true }); });",
    "router.post(['/b'], (req, res) => { verificationOutcome({}); });",
  ].join('\n');

  assert.doesNotMatch(routeBody(fake, "router.post(['/a'"), /verificationOutcome/);
  assert.match(routeBody(fake, "router.post(['/b'"), /verificationOutcome/);
});

test('Google sign-in does not adopt an unverified account with its password', () => {
  // The pre-hijack: anybody can register any address, and until the code is
  // entered nobody has proven they own it. If Google sign-in then adopted that
  // account as it stands, whoever registered it would keep a working password
  // to the account of the person who actually owns the address.
  const route = routeBody(authSource, "router.post(['/google'");

  assert.match(route, /if\s*\(\s*!user\.is_verified\s*\)/);
  assert.match(route, /password_hash\s*=\s*\$2/, 'the password has to go');
  assert.match(route, /GOOGLE_PLACEHOLDER_HASH/);
});
