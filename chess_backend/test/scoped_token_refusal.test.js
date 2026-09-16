// scoped_token_refusal.test.js
// A download link is not a login.
//
// Found untested by the architecture audit on 16.9.2026 (`docs/audit/tests.md`,
// 3). `signDownloadToken` puts the trainer's own id into a token that travels in
// a URL for thirty minutes, and `authenticateToken` refuses it only because it
// carries a `purpose`. Deleting that one `if` left both suites green, and turned
// every shared download link into a bearer credential for the whole API of the
// account that made it. The same holds for a parent's report link.
//
// Driven through the real middleware with real signed tokens.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const { authenticateToken, signDownloadToken, signReportToken } = require('../middleware/auth');
const jwt = require('jsonwebtoken');

/// Runs the middleware with `token` against a database in which every account
/// exists, and says whether the request got through.
async function authenticate(token) {
  const original = db.pool.query;
  db.pool.query = async () => ({ rows: [{ role: 'korisnik' }], rowCount: 1 });
  const answered = { status: null, next: false };
  const res = {
    status(code) {
      answered.status = code;
      return this;
    },
    json() {
      return this;
    },
  };
  try {
    await authenticateToken({ headers: { authorization: `Bearer ${token}` } }, res, () => {
      answered.next = true;
    });
  } finally {
    db.pool.query = original;
  }
  return answered;
}

test('an ordinary session token gets through — the control', async () => {
  const token = jwt.sign({ id: 5, email: 'x@example.test', role: 'korisnik' }, process.env.JWT_SECRET, { expiresIn: '1h' });
  const r = await authenticate(token);
  assert.equal(r.next, true);
});

test('a download link\'s token, which carries the user\'s id, does not authenticate the API', async () => {
  const r = await authenticate(signDownloadToken(5, 'export.mp4'));
  assert.equal(r.next, false);
  assert.equal(r.status, 403);
});

test('a parent report link\'s token does not authenticate the API', async () => {
  const r = await authenticate(signReportToken(12, 7));
  assert.equal(r.next, false);
  assert.equal(r.status, 403);
});
