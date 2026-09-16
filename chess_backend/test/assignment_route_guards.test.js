// assignment_route_guards.test.js
// A trainer reaches a student's record only through an accepted relationship —
// asserted on the routes, not only on the helper.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/tests.md`, 1): no
// test reached `routes/assignments.js` at all. Its four `trainerOwnsStudent`
// guards — in front of a student's game archive, their homework list, their
// progress, and `POST /report/:studentId`, which mints a link a parent opens
// without an account — could each be deleted with both suites green. The helper
// is tested; whether each route asks it was not.
//
// Each route is driven as a trainer with **no** accepted relationship to the
// student. It must answer 403 and must not have asked the database anything but
// that one question: a guard that refuses after reading the record has already
// leaked it into a log or a timing, and one that refuses after writing a report
// has written it.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const router = require('../routes/assignments');

function handlerFor(method, path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// Runs a route as trainer 1 against student 42. `owns` decides the answer to
/// the relationship question; everything else the route asks is recorded and
/// answered empty.
async function drive({ method, path, params = {}, query = {}, body = {}, owns }) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (text, values) => {
    const sql = String(text).replace(/\s+/g, ' ').trim();
    queries.push(sql);
    if (/FROM trainer_students WHERE trainer_id = \$1 AND student_id = \$2 AND status = 'accepted'/.test(sql)) {
      return owns ? { rows: [{ '?column?': 1 }], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    return { rows: [], rowCount: 0 };
  };
  const answered = { status: 200 };
  const res = {
    status(code) {
      answered.status = code;
      return this;
    },
    json() {
      return this;
    },
    send() {
      return this;
    },
  };
  try {
    await handlerFor(method, path)({ user: { id: 1 }, params, query, body, headers: {} }, res);
  } finally {
    db.pool.query = original;
  }
  return { status: answered.status, queries };
}

const ROUTES = [
  { name: 'a student\'s game archive', method: 'get', path: '/student/:id/archive', params: { id: '42' } },
  { name: 'a student\'s homework list', method: 'get', path: '/given', query: { studentId: '42' } },
  { name: 'a parent report link', method: 'post', path: '/report/:studentId', params: { studentId: '42' }, body: { days: 7 } },
  { name: 'a student\'s progress', method: 'get', path: '/progress/:studentId', params: { studentId: '42' } },
];

for (const route of ROUTES) {
  test(`${route.name}: refused without an accepted relationship, before anything else is read`, async () => {
    const r = await drive({ ...route, owns: false });
    assert.equal(r.status, 403, `${route.method.toUpperCase()} ${route.path}`);
    assert.equal(r.queries.length, 1, `only the relationship may be asked; asked: ${r.queries.join(' | ')}`);
    assert.match(r.queries[0], /FROM trainer_students/);
  });

  test(`${route.name}: with the relationship, the route goes on past the guard`, async () => {
    // The control: without it, a route that refused everybody would pass the
    // test above.
    const r = await drive({ ...route, owns: true });
    assert.notEqual(r.status, 403);
    assert.ok(r.queries.length > 1, 'an accepted trainer must reach the record');
  });
}
