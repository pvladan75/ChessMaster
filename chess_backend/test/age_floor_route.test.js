// age_floor_route.test.js
// Below thirteen there is no account — asserted on the route that decides it.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/tests.md`, 5): the
// 13+ floor was enforced in `POST /me/age` and tested only in `ageService`. The
// helper being right proves nothing about the route asking it, and the route is
// what makes the app's General Audience declaration true: deleting its `if` left
// every suite green while an eleven-year-old's `birth_year` was written.
//
// Years are taken relative to the current year, because the route reads the
// clock. The boundary is the conservative one `statedAge` uses: a year alone
// counts the age certainly reached.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const router = require('../routes/account');

function ageHandler() {
  const layer = router.stack.find((l) => l.route && l.route.path === '/me/age' && l.route.methods.post);
  assert.ok(layer, 'POST /me/age must be mounted');
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

async function stateYear(birthYear) {
  const writes = [];
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    const sql = String(text).replace(/\s+/g, ' ');
    if (/UPDATE users SET birth_year/.test(sql)) {
      writes.push(params);
      return { rows: [{ birth_year: params[0] }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
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
  try {
    await ageHandler()({ user: { id: 3 }, body: { birthYear: birthYear } }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...answered, writes };
}

const thisYear = new Date().getFullYear();

test('a stated year under thirteen is refused and not written', async () => {
  const r = await stateYear(thisYear - 11);
  assert.equal(r.status, 403);
  assert.equal(r.body.minimumAge, 13);
  assert.deepEqual(r.writes, [], 'the year must not be stored');
});

test('the boundary is the conservative age: thirteen calendar years ago is still twelve', async () => {
  const r = await stateYear(thisYear - 13);
  assert.equal(r.status, 403);
  assert.deepEqual(r.writes, []);
});

test('fourteen calendar years ago is thirteen, and is written', async () => {
  const r = await stateYear(thisYear - 14);
  assert.notEqual(r.status, 403, JSON.stringify(r.body));
  assert.equal(r.writes.length, 1);
  assert.equal(r.writes[0][0], thisYear - 14);
});
