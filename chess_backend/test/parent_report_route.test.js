// parent_report_route.test.js — POST /assignments/report/:studentId.
//
// The route freezes a report and tells the trainer whether the parent will see
// figures or „no practice recorded" (`hasData`, which the app turns into a
// warning). On 1.10.2026 the snapshot began counting puzzles instead of
// attempts, and the route still read `snapshot.totalAttempts` — a field that
// no longer existed — so every report would have told the trainer the student
// had done nothing. No test covered this answer; these do, through the handler
// with the pool stubbed by what each query asks (rule 7: assert on what goes
// out).

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/assignments');
const db = require('../db');

const NOW = Date.now();
const daysAgo = (n) => new Date(NOW - n * 24 * 60 * 60 * 1000).toISOString();

function row(id, solved, at, extra = {}) {
  return {
    puzzle_id: id, source: 'lichess', solved, skipped: false, hinted: false,
    themes: ['fork'], rating_before: null, rating_after: null, created_at: at, ...extra,
  };
}

/// Runs the route as trainer 9 for student 12 over [attempts], and returns
/// what it answered and the snapshot it stored.
async function report(attempts) {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === '/report/:studentId' && l.route.methods.post
  );
  assert.ok(layer, 'POST /report/:studentId is mounted');
  const handler = layer.route.stack[layer.route.stack.length - 1].handle;

  let stored = null;
  const original = db.pool.query;
  db.pool.query = async (text, values = []) => {
    const sql = String(text);
    if (/FROM trainer_students/.test(sql)) return { rows: [{ '?column?': 1 }] };
    if (/FROM users WHERE id = ANY/.test(sql)) return { rows: [{ id: 12, name: 'Ana' }, { id: 9, name: 'Coach' }] };
    if (/FROM user_puzzle_attempts/.test(sql)) return { rows: attempts };
    if (/FROM user_puzzle_ratings/.test(sql)) return { rows: [] };
    if (/FROM assignments WHERE student_id/.test(sql)) return { rows: [{ total: 0, completed: 0, overdue: 0 }] };
    if (/INSERT INTO student_reports/.test(sql)) {
      stored = JSON.parse(values[4]);
      return { rows: [{ id: 77, created_at: new Date() }] };
    }
    throw new Error(`unexpected query: ${sql}`);
  };
  const sent = { status: 200, json: null };
  const res = {
    status(code) { sent.status = code; return res; },
    json(payload) { sent.json = payload; return res; },
  };
  try {
    await handler({
      params: { studentId: '12' },
      body: { days: 30 },
      user: { id: 9 },
      protocol: 'https',
      get: () => 'example.test',
    }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, stored };
}

test('a period with puzzles is reported as having data, and stored as puzzles', async () => {
  const { status, json, stored } = await report([
    row('a', false, daysAgo(3)),
    row('a', true, daysAgo(2)),
    row('b', false, daysAgo(1), { skipped: true }),
  ]);
  assert.equal(status, 201);
  assert.equal(json.hasData, true, 'the trainer must not be told the student did nothing');
  assert.equal(stored.puzzles, 2);
  assert.equal(stored.solved, 1);
  assert.equal(stored.skipped, 1);
  assert.equal(stored.firstTries, 1);
  assert.equal(stored.accuracy, 0);
  assert.equal(stored.totalAttempts, undefined, 'the attempt count is not frozen any more');
});

test('a period with nothing in it is reported as having none', async () => {
  const { status, json, stored } = await report([row('old', true, daysAgo(60))]);
  assert.equal(status, 201);
  assert.equal(json.hasData, false);
  assert.equal(stored.puzzles, 0);
});
