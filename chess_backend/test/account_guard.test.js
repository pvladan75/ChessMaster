// account_guard.test.js
// A token is a signed slip, not a row.
//
// Found on 25.8.2026 by emptying the database: a wiped account reconnected and
// registered presence as "pavle (ID: 5)", because `jwt.verify` proves the server
// issued the slip and nothing else. The account behind it was never asked about,
// so a deleted account kept a working login for the rest of its seven days.
//
// Two reasons this is more than an afternoon's oddity, both pinned below:
//
//   * the privacy policy promises a parent that deleting the account deletes the
//     account, and a login that survives it for a week is that promise unkept;
//   * `TRUNCATE ... RESTART IDENTITY` reuses ids, so the fifth account made
//     afterwards *is* id 5 — the old slip becomes a credential for a different
//     person, which is not a stale session.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { tokenHolderStanding } = require('../services/accountGuard');

function stubPool(answer) {
  const calls = [];
  return {
    calls,
    async query(text, params) {
      calls.push({ sql: String(text).replace(/\s+/g, ' ').trim(), params });
      return answer(params);
    },
  };
}

test('an account that is still there passes, and brings its role', async () => {
  const pool = stubPool(() => ({ rows: [{ role: 'admin' }], rowCount: 1 }));
  const standing = await tokenHolderStanding(pool, 5);

  assert.equal(standing.ok, true);
  assert.equal(standing.role, 'admin');
  assert.equal(pool.calls[0].params[0], 5);
});

test('the role comes from the row, not from the slip', async () => {
  // A role is a claim frozen at sign-in. Revoking admin used to take effect a
  // week later, when the token expired — the same bug as this file's, one field
  // over. The row is already being read, so the honest value costs nothing.
  const pool = stubPool(() => ({ rows: [{ role: 'korisnik' }], rowCount: 1 }));
  const standing = await tokenHolderStanding(pool, 5);
  assert.equal(standing.role, 'korisnik');
});

test('a deleted account is 401 and says which kind of no it is', async () => {
  const pool = stubPool(() => ({ rows: [], rowCount: 0 }));
  const standing = await tokenHolderStanding(pool, 5);

  assert.equal(standing.ok, false);
  assert.equal(standing.status, 401);
  assert.equal(standing.reason, 'account-gone');
  // 401 rather than 403 on purpose: this is the one a client should react to by
  // signing out, and it needs to be told apart from a malformed token.
  assert.match(standing.error, /Nalog/);
});

test('a database that will not answer is not a deleted account', async () => {
  // The third state, and the whole reason this is not a boolean. A brief
  // outage read as "your account was deleted" makes every client throw its
  // session away — the project's recurring failure, pointed at everybody at
  // once.
  const pool = stubPool(() => { throw new Error('connection reset'); });
  const standing = await tokenHolderStanding(pool, 5);

  assert.equal(standing.ok, false);
  assert.equal(standing.status, 503);
  assert.equal(standing.reason, 'unverifiable');
  assert.equal(standing.cause.message, 'connection reset');
});

test('a token that names nothing usable never reaches the database', async () => {
  for (const bad of [undefined, null, '', 'pet', 0, -3, 1.5, {}, []]) {
    const pool = stubPool(() => { throw new Error('nije trebalo pitati bazu'); });
    const standing = await tokenHolderStanding(pool, bad);
    assert.equal(standing.status, 403, `primljeno: ${JSON.stringify(bad)}`);
    assert.equal(standing.reason, 'malformed');
    assert.equal(pool.calls.length, 0);
  }
});

test('a numeric id in a string is still an id', async () => {
  // JWT payloads survive a round trip through JSON, and nothing guarantees the
  // id comes back as a number.
  const pool = stubPool(() => ({ rows: [{ role: 'korisnik' }], rowCount: 1 }));
  const standing = await tokenHolderStanding(pool, '5');
  assert.equal(standing.ok, true);
  assert.equal(pool.calls[0].params[0], 5);
});

test('every gate into the API asks whether the account still exists', () => {
  // The regression guard. The hole was not that the check was wrong — there was
  // no check, and nothing in behaviour showed it: everybody who was signed in
  // stayed signed in, which is what it looks like when it works.
  //
  // Read from the source because a middleware that quietly stops calling this
  // fails exactly the same way it did the first time.
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'middleware', 'auth.js'), 'utf8',
  ).replace(/^\s*\/\/.*$/gm, '').replace(/^\s*\/\/\/.*$/gm, '');

  for (const gate of ['authenticateToken', 'optionalAuth', 'authenticateSocket']) {
    const body = bodyOf(source, gate);
    assert.match(body, /tokenHolderStanding\(/,
      `${gate} propušta token bez pitanja da li nalog postoji`);
  }
});

/// One function's body, by matching braces rather than by taking a slice.
///
/// The first version of the test above read a fixed 1600 characters from the
/// start of each function, which ran past the end of the short ones into the
/// next — so removing the check from `authenticateToken` still matched, in
/// `optionalAuth`. It passed against code with the hole reopened, which is the
/// exact failure this repository keeps paying for: a check that skips the thing
/// it appears to check. Verified by mutation this time, in both directions.
function bodyOf(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} više ne postoji`);
  const open = source.indexOf('{', start);
  assert.notEqual(open, -1, `${name} nema telo`);

  let depth = 0;
  for (let i = open; i < source.length; i += 1) {
    if (source[i] === '{') depth += 1;
    else if (source[i] === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(open, i + 1);
    }
  }
  assert.fail(`telo funkcije ${name} se ne zatvara`);
}

test('the guard above reads one function, not its neighbour', () => {
  // The test that tests the test, because the first attempt did not fail when
  // the hole was reopened. Two functions, the second of which contains the
  // marker: reading the first must not find it.
  const sample = [
    'function a() {', '  const x = 1;', '}',
    'function b() {', '  MARKER;', '}',
  ].join('\n');
  assert.doesNotMatch(bodyOf(sample, 'a'), /MARKER/);
  assert.match(bodyOf(sample, 'b'), /MARKER/);
});
