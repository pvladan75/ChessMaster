// google_account.test.js
// Pins that an account without a password says so.
//
// The failure this guards against is not a crash and not a wrong answer: it is
// a *true* answer that misleads. "Invalid email or password" is literally
// correct for an account whose password cannot match anything — and it sends
// whoever reads it looking for a typo that does not exist.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { GOOGLE_PLACEHOLDER_HASH, isPasswordlessHash } = require('../services/googleAccount');

test('the marker written by Google sign-in reads as passwordless', () => {
  assert.equal(isPasswordlessHash(GOOGLE_PLACEHOLDER_HASH), true);
});

test('a real bcrypt hash never reads as passwordless', () => {
  // Shape of the hashes in the users table: $2b$, cost, salt, digest.
  assert.equal(isPasswordlessHash('$2b$10$abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTU'), false);
  assert.equal(isPasswordlessHash('$2a$12$something'), false);
});

test('a missing or non-string hash is not mistaken for a Google account', () => {
  // Wrong in the safe direction: an unreadable value must fall through to the
  // ordinary password path, which fails closed, rather than announce that the
  // account exists and needs Google.
  assert.equal(isPasswordlessHash(null), false);
  assert.equal(isPasswordlessHash(undefined), false);
  assert.equal(isPasswordlessHash(''), false);
  assert.equal(isPasswordlessHash(12345), false);
});

test('login checks for a passwordless account before comparing a password', () => {
  // Order is the whole point: bcrypt.compare against the marker returns false
  // rather than throwing, so a check placed after it would never be reached.
  const source = fs.readFileSync(path.join(__dirname, '..', 'routes', 'auth.js'), 'utf8');
  const loginStart = source.indexOf("router.post('/login'");
  assert.notEqual(loginStart, -1, 'login route not found');

  const nextRoute = source.indexOf('router.post(', loginStart + 1);
  const handler = source
    .slice(loginStart, nextRoute === -1 ? undefined : nextRoute)
    // Comments name the very calls being located — including the one explaining
    // why this order matters — so they are removed before looking.
    .replace(/\/\/.*$/gm, '');

  const guard = handler.indexOf('isPasswordlessHash');
  const compare = handler.indexOf('bcrypt.compare');

  assert.notEqual(guard, -1, 'login never checks whether the account has a password');
  assert.notEqual(compare, -1, 'login no longer compares a password at all');
  assert.ok(guard < compare, 'the check must come before bcrypt.compare, not after');
});

test('the marker is defined once and reused by the Google route', () => {
  // Two spellings of the same marker would make the login check pass for
  // accounts created before the change and fail for the ones created after.
  const source = fs.readFileSync(path.join(__dirname, '..', 'routes', 'auth.js'), 'utf8');
  assert.equal(
    source.includes(`'${GOOGLE_PLACEHOLDER_HASH}'`),
    false,
    'auth.js still spells the marker out instead of importing it'
  );
  assert.match(source, /GOOGLE_PLACEHOLDER_HASH/);
});
