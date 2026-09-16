// account_rate_limits.test.js
// Routes that spend a third party's service, the server's CPU or its mail sender
// refuse a loop.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 9, 10,
// 16 and 19): the opponent narrative (Gemini), a leaks report asking the opening
// judge, scanning a PDF, mailing a parent, and drawing preview frames each
// answered an account in a loop for as long as it cared to ask.
//
// Driven over a real socket against the mounted routers, with a real signed
// token — a limiter is middleware order and configuration, and both are only
// visible to a request. The fake database refuses every quota and knows every
// account, so no request reaches Gemini, a mail server or a PDF parser.

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const { mountBodyParsers } = require('../middleware/bodyParsers');

db.pool.query = async (text) => {
  const sql = String(text);
  if (/usage_counters/.test(sql)) return { rows: [], rowCount: 0 };
  if (/FROM users/.test(sql)) {
    return { rows: [{ id: 1, role: 'korisnik', account_type: 'free' }], rowCount: 1 };
  }
  return { rows: [], rowCount: 0 };
};

async function withApp(mount, fn) {
  const app = express();
  mountBodyParsers(app);
  mount(app);
  const server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  try {
    await fn(server.address().port);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

function request(port, { method, path, body, userId = 1 }) {
  const token = jwt.sign({ id: userId, email: 'x@example.test', role: 'korisnik' }, process.env.JWT_SECRET);
  const data = body === undefined ? undefined : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        port,
        path,
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          ...(data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let text = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => { text += chunk; });
        res.on('end', () => {
          let body = null;
          try { body = JSON.parse(text); } catch (_) { /* not JSON */ }
          resolve({ status: res.statusCode, body });
        });
      },
    );
    req.on('error', reject);
    req.end(data);
  });
}

/// Sends `max + 1` requests and returns the statuses.
async function hammer(port, spec, times) {
  const statuses = [];
  for (let i = 0; i < times; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    statuses.push((await request(port, spec)).status);
  }
  return statuses;
}

function assertLimitedAt(statuses, max) {
  assert.ok(statuses.slice(0, max).every((s) => s !== 429), `the first ${max} must not be limited: ${statuses}`);
  assert.equal(statuses[max], 429, `request ${max + 1} must be refused: ${statuses}`);
}

test('the opponent narrative is limited, and a spent quota refuses it before any model is asked', async () => {
  const router = require('../routes/userGames');
  await withApp((app) => app.use('/games', router), async (port) => {
    // The first answer must be the quota's own refusal. Another 403 — opponent
    // preparation being off — would pass a status check with the quota gone.
    const first = await request(port, { method: 'GET', path: '/games/prep/narrative?subject=someone' });
    assert.equal(first.status, 403);
    assert.equal(first.body?.quotaExceeded, true, JSON.stringify(first.body));
    const statuses = await hammer(port, { method: 'GET', path: '/games/prep/narrative?subject=someone' }, 10);
    assertLimitedAt([first.status, ...statuses], 10);
  });
});

test('a leaks report that asks the judge is limited, and one that does not is not', async () => {
  const router = require('../routes/userGames');
  await withApp((app) => app.use('/games', router), async (port) => {
    const plain = await hammer(port, { method: 'GET', path: '/games/openings/leaks?subject=someone', userId: 2 }, 12);
    assert.ok(!plain.includes(429), `a report without the judge must not be limited: ${plain}`);
    const judged = await hammer(port, { method: 'GET', path: '/games/openings/leaks?subject=someone&judge=true', userId: 3 }, 11);
    assertLimitedAt(judged, 10);
  });
});

test('the judge is asked about at most twenty positions per report', () => {
  const { judgeLimitOf } = require('../routes/userGames');
  assert.equal(judgeLimitOf({ judgeLimit: '200' }), 20);
  assert.equal(judgeLimitOf({ judgeLimit: '5' }), 5);
  assert.equal(judgeLimitOf({}), 10);
  assert.equal(judgeLimitOf({ judgeLimit: '-3' }), 10);
});

test('scanning a PDF is limited per account', async () => {
  const router = require('../routes/scans');
  await withApp((app) => app.use('/scans', router), async (port) => {
    const statuses = await hammer(port, { method: 'POST', path: '/scans', userId: 4 }, 21);
    assertLimitedAt(statuses, 20);
    // Counted per account: another account behind the same address — a school,
    // a family — is not refused for somebody else's loop.
    const other = await request(port, { method: 'POST', path: '/scans', userId: 40 });
    assert.notEqual(other.status, 429);
  });
});

test('the letter to a parent is limited per account', async () => {
  const router = require('../routes/account');
  await withApp((app) => app.use('/', router), async (port) => {
    const statuses = await hammer(
      port,
      { method: 'POST', path: '/me/parent-email', body: { parentEmail: 'not-an-address' }, userId: 5 },
      6,
    );
    assertLimitedAt(statuses, 5);
  });
});

test('preview frames are limited per account', async () => {
  const router = require('../routes/lessons');
  await withApp((app) => app.use('/lessons', router), async (port) => {
    const statuses = await hammer(port, { method: 'POST', path: '/lessons/1/preview-frames', body: { beats: [0] }, userId: 6 }, 31);
    assertLimitedAt(statuses, 30);
  });
});
