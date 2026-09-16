// registration_takeover.test.js
// Whoever proves the address decides the password — not whoever typed it first.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 1).
// Registering an address that was already registered but never verified mailed
// a fresh code and **kept the first registrant's password and name**. So anyone
// could register a stranger's address with a password of their own; the owner
// registering later was told a new code had been sent, entered it from their own
// inbox, and verified an account whose password the first registrant still held.
// There is no password reset, so the owner could not take it back either. The
// Google path had already been taught this exact hazard (`auth.js`, „Adopting an
// unverified account") and the password path had not.
//
// Two rules close it, and each has a test below:
//   - a registration of an unverified address replaces the password and name, so
//     the pre-registration is simply overwritten;
//   - a verification that carries a password must match the stored one, so a
//     registration slipped in *between* the owner's and their code entry cannot
//     win silently either.
//
// This drives the mounted routes with an in-memory users table, not the helpers:
// the helpers were right all along, and the route was where the password went.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const mailService = require('../services/mailService');
const authRouter = require('../routes/auth');

/// The last handler of a mounted POST route, without the rate limiter.
function handler(path) {
  const layer = authRouter.stack.find((l) => {
    if (!l.route || !l.route.methods.post) return false;
    const paths = Array.isArray(l.route.path) ? l.route.path : [l.route.path];
    return paths.includes(path);
  });
  assert.ok(layer, `POST ${path} must be mounted`);
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// An in-memory `users` table answering exactly the queries these routes run.
/// Anything else throws, so a route that starts asking something new is noticed
/// here rather than answered with a plausible row.
function usersTable() {
  const rows = [];
  let nextId = 1;
  const query = async (text, params) => {
    const sql = text.replace(/\s+/g, ' ').trim();
    if (sql === 'SELECT * FROM users WHERE email = $1') {
      return { rows: rows.filter((r) => r.email === params[0]).map((r) => ({ ...r })) };
    }
    if (sql.startsWith('INSERT INTO users')) {
      const [email, password_hash, name, role, verification_code] = params;
      const row = { id: nextId++, email, password_hash, name, role, is_verified: false, verification_code };
      rows.push(row);
      return { rows: [{ ...row }], rowCount: 1 };
    }
    if (sql.startsWith('UPDATE users SET verification_code = $1, password_hash = $2, name = $3 WHERE id = $4 AND is_verified = FALSE')) {
      const row = rows.find((r) => r.id === params[3] && r.is_verified === false);
      if (!row) return { rows: [], rowCount: 0 };
      Object.assign(row, { verification_code: params[0], password_hash: params[1], name: params[2] });
      return { rows: [], rowCount: 1 };
    }
    if (sql.startsWith('UPDATE users SET verification_code = $1 WHERE email = $2')) {
      const row = rows.find((r) => r.email === params[1]);
      if (row) row.verification_code = params[0];
      return { rows: [], rowCount: row ? 1 : 0 };
    }
    if (sql.startsWith('UPDATE users SET is_verified = TRUE, verification_code = NULL WHERE id = $1')) {
      const row = rows.find((r) => r.id === params[0]);
      Object.assign(row, { is_verified: true, verification_code: null });
      const { id, email, name, role } = row;
      return { rows: [{ id, email, name, role }], rowCount: 1 };
    }
    if (sql.startsWith('DELETE FROM users WHERE id = $1')) {
      const i = rows.findIndex((r) => r.id === params[0]);
      if (i >= 0) rows.splice(i, 1);
      return { rows: [], rowCount: i >= 0 ? 1 : 0 };
    }
    throw new Error(`unexpected query in test: ${sql}`);
  };
  return { rows, query };
}

async function call(path, body) {
  const answered = { status: 200, body: null };
  const res = {
    status(code) {
      answered.status = code;
      return this;
    },
    json(payload) {
      answered.body = payload;
      return this;
    },
  };
  await handler(path)({ body, headers: {}, ip: '127.0.0.1' }, res);
  return answered;
}

/// Runs `scenario` against a fresh table, capturing the codes that were mailed.
async function withServer(scenario) {
  const table = usersTable();
  const mailed = [];
  const originalQuery = db.pool.query;
  const originalSend = mailService.sendVerificationCode;
  db.pool.query = table.query;
  mailService.sendVerificationCode = async (email, code) => {
    mailed.push({ email, code });
  };
  try {
    await scenario({ table, mailed, lastCode: () => mailed[mailed.length - 1].code });
  } finally {
    db.pool.query = originalQuery;
    mailService.sendVerificationCode = originalSend;
  }
}

const ADDRESS = 'owner@example.test';

test('a pre-registration of somebody else\'s address leaves the first password dead', async () => {
  await withServer(async ({ lastCode }) => {
    // The stranger registers first.
    let r = await call('/register', { email: ADDRESS, password: 'stranger-password', name: 'Stranger' });
    assert.equal(r.status, 201);

    // The owner registers later and verifies with the code from their inbox,
    // exactly as the app does — no password on the verification.
    r = await call('/register', { email: ADDRESS, password: 'owner-password', name: 'Owner' });
    assert.equal(r.status, 200);
    assert.equal(r.body.requiresVerification, true);
    r = await call('/verify-email', { email: ADDRESS, code: lastCode() });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    assert.equal(r.body.user.name, 'Owner');

    const stranger = await call('/login', { email: ADDRESS, password: 'stranger-password' });
    assert.equal(stranger.status, 400, 'the password set before the address was proven must not sign in');
    assert.equal(stranger.body.token, undefined);

    const owner = await call('/login', { email: ADDRESS, password: 'owner-password' });
    assert.equal(owner.status, 200, JSON.stringify(owner.body));
    assert.ok(owner.body.token);
  });
});

test('a registration slipped in before the owner enters the code does not win silently', async () => {
  await withServer(async ({ table, lastCode }) => {
    await call('/register', { email: ADDRESS, password: 'owner-password', name: 'Owner' });
    await call('/register', { email: ADDRESS, password: 'stranger-password', name: 'Stranger' });

    // The owner verifies with the newest code — the one in their inbox — and
    // their own password, which the app still holds from the form.
    const r = await call('/verify-email', { email: ADDRESS, code: lastCode(), password: 'owner-password' });
    assert.equal(r.status, 400);
    assert.equal(r.body.token, undefined);
    assert.equal(r.body.passwordChanged, true);
    assert.equal(table.rows[0].is_verified, false, 'the account must stay unverified');

    const stranger = await call('/login', { email: ADDRESS, password: 'stranger-password' });
    assert.equal(stranger.body.token, undefined, 'an unverified account never signs in');
  });
});

test('a verification carrying the right password goes through', async () => {
  await withServer(async ({ lastCode }) => {
    await call('/register', { email: ADDRESS, password: 'owner-password', name: 'Owner' });
    const r = await call('/verify-email', { email: ADDRESS, code: lastCode(), password: 'owner-password' });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    assert.ok(r.body.token);
  });
});

test('a verified address is not reopened by registering it again', async () => {
  await withServer(async ({ table, lastCode }) => {
    await call('/register', { email: ADDRESS, password: 'owner-password', name: 'Owner' });
    await call('/verify-email', { email: ADDRESS, code: lastCode() });
    const hashBefore = table.rows[0].password_hash;

    const r = await call('/register', { email: ADDRESS, password: 'stranger-password', name: 'Stranger' });
    assert.equal(r.status, 400);
    assert.equal(table.rows[0].password_hash, hashBefore);
    assert.equal(table.rows[0].name, 'Owner');
  });
});

test('a wrong password on the login route is refused', async () => {
  // The audit's test track found `POST /login` pinned only as text order in a
  // source-reading test. This runs it.
  await withServer(async ({ lastCode }) => {
    await call('/register', { email: ADDRESS, password: 'owner-password', name: 'Owner' });
    await call('/verify-email', { email: ADDRESS, code: lastCode() });

    const wrong = await call('/login', { email: ADDRESS, password: 'not-the-password' });
    assert.equal(wrong.status, 400);
    assert.equal(wrong.body.token, undefined);
  });
});

test('an unverified account with the right password is asked to verify, not signed in', async () => {
  await withServer(async () => {
    await call('/register', { email: ADDRESS, password: 'owner-password', name: 'Owner' });
    const r = await call('/login', { email: ADDRESS, password: 'owner-password' });
    assert.equal(r.status, 400);
    assert.equal(r.body.requiresVerification, true);
    assert.equal(r.body.token, undefined);
  });
});
