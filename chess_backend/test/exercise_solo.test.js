// exercise_solo.test.js — the gate of docs/PLAN-MATERIJAL.md, phase 1 (server).
//
// One's own exercise is solved alone: `POST /exercises/:id/attempt` judges
// with the homework's judge and logs an `own` attempt from its own verdict;
// `GET /exercises/queue` serves what was never tried and what failed last.
// `POST /api/puzzles/attempt`, which takes `solved` from the client, refuses
// `own`.
//
// Handlers are called directly and `db.pool.query` is replaced for the test —
// the idiom of puzzle_progress_routes.test.js. Every case reads what the route
// asked the database (rule 7), not only what it answered.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const exercisesRouter = require('../routes/exercises');
const puzzlesRouter = require('../routes/puzzles');
const { authenticateToken } = require('../middleware/auth');
const db = require('../db');
const { getStudentProgress } = require('../services/assignmentService');
const { idleStudents } = require('../services/trainerPanelService');

// Two mates in one: the author printed Ra8#, and Rb8# mates as well.
const MATE_FEN = '6k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1';

function exerciseRow(over = {}) {
  return {
    puzzle_id: 'cust_1',
    name: 'Back rank',
    fen: MATE_FEN,
    side_to_move: 'w',
    instruction: 'White mates in one.',
    themes: ['backRankMate'],
    source_title: 'A book',
    source_label: '12',
    task: null,
    solution: null,
    solution_san: 'Ra8#',
    needs_review: false,
    ...over,
  };
}

function handlersOf(router, method, path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

async function call(router, method, path, { body = {}, query = {}, params = {}, userId = 5, answer = () => ({ rows: [] }) } = {}) {
  const handlers = handlersOf(router, method, path);
  const handler = handlers[handlers.length - 1];
  const calls = [];
  const original = db.pool.query;
  db.pool.query = async (text, values = []) => {
    const flat = String(text).replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params: values });
    const out = answer(flat, values) || { rows: [] };
    return { rowCount: out.rows.length, ...out };
  };
  const sent = { status: 200, json: null };
  const res = {
    status(code) { sent.status = code; return res; },
    json(payload) { sent.json = payload; return res; },
  };
  try {
    await handler({ body, query, params, user: { id: userId } }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls };
}

/// The attempt route over one stored row, which the database hands back only
/// when it was asked for that id *and* that owner.
function attempt({ row = exerciseRow(), body, userId = 5, ownerId = 5 }) {
  return call(exercisesRouter, 'post', '/:id/attempt', {
    params: { id: row.puzzle_id },
    body,
    userId,
    answer: (text, values) => {
      if (/FROM custom_puzzles/.test(text)) {
        const [id, owner] = values;
        return { rows: id === row.puzzle_id && owner === ownerId ? [row] : [] };
      }
      return { rows: [] };
    },
  });
}

const attemptInserts = (calls) => calls.filter((c) => /INSERT INTO user_puzzle_attempts/.test(c.text));

// ── behind sign-in ────────────────────────────────────────────────────────

for (const [method, path] of [['post', '/:id/attempt'], ['get', '/queue']]) {
  test(`${method.toUpperCase()} /exercises${path} is behind sign-in`, () => {
    assert.equal(handlersOf(exercisesRouter, method, path)[0], authenticateToken);
  });
}

test('/queue is matched before /:id, or „queue" would be read as an id', () => {
  const paths = exercisesRouter.stack.filter((l) => l.route && l.route.methods.get).map((l) => l.route.path);
  assert.ok(paths.indexOf('/queue') < paths.indexOf('/:id'), paths.join(', '));
});

// ── the verdict ──────────────────────────────────────────────────────────

test('the author\'s move is correct, and the answer carries the solution', async () => {
  const out = await attempt({ body: { moveSan: 'Ra8#' } });
  assert.equal(out.status, 200);
  assert.deepEqual(out.json, {
    correct: true, reason: "the author's move", playedSan: 'Ra8#', solutionSan: 'Ra8#',
  });
});

test('a wrong move is not correct, and the solution is released', async () => {
  const out = await attempt({ body: { moveSan: 'h3' } });
  assert.equal(out.status, 200);
  assert.equal(out.json.correct, false);
  assert.equal(out.json.playedSan, 'h3');
  assert.equal(out.json.solutionSan, 'Ra8#');
});

test('a different mate is correct, with the label the app reads', async () => {
  const out = await attempt({ body: { moveSan: 'Rb8#' } });
  assert.equal(out.json.correct, true);
  assert.equal(out.json.reason, 'a different mate, but mate');
});

// ── who, and what ────────────────────────────────────────────────────────

test('somebody else\'s exercise is 404, and the query was scoped by owner', async () => {
  const out = await attempt({ body: { moveSan: 'Ra8#' }, userId: 6, ownerId: 5 });
  assert.equal(out.status, 404);
  const select = out.calls.find((c) => /FROM custom_puzzles/.test(c.text));
  assert.match(select.text, /owner_id = \$2/);
  assert.deepEqual(select.params, ['cust_1', 6]);
  assert.equal(attemptInserts(out.calls).length, 0);
});

test('a bare position is 409 with the reason, and nothing is logged', async () => {
  const out = await attempt({ row: exerciseRow({ solution_san: null }), body: { moveSan: 'Ra8#' } });
  assert.equal(out.status, 409);
  assert.match(out.json.error, /has no solution/);
  assert.equal(attemptInserts(out.calls).length, 0);
});

test('a game exercise is 409 with the reason — it is played, not answered', async () => {
  const row = exerciseRow({ solution_san: null, task: { type: 'game', side: 'w', goal: 'win' } });
  const out = await attempt({ row, body: { moveSan: 'Ra8#' } });
  assert.equal(out.status, 409);
  assert.match(out.json.error, /played out against the engine/);
  assert.equal(attemptInserts(out.calls).length, 0);
});

test('a row still marked for review is 409', async () => {
  const out = await attempt({ row: exerciseRow({ needs_review: true }), body: { moveSan: 'Ra8#' } });
  assert.equal(out.status, 409);
  assert.match(out.json.error, /marked for review/);
});

test('no move is 400, and nothing is asked of the database', async () => {
  const out = await attempt({ body: {} });
  assert.equal(out.status, 400);
  assert.equal(out.calls.length, 0);
});

// ── the log ──────────────────────────────────────────────────────────────

test('the attempt is logged as `own`, from the server\'s verdict and not the client\'s', async () => {
  // The client claims a solve it did not make.
  const out = await attempt({ body: { moveSan: 'h3', solved: true, msTaken: 4200 } });
  const [insert] = attemptInserts(out.calls);
  assert.ok(insert, 'no attempt row was written');
  assert.deepEqual(insert.params, [5, 'cust_1', 'own', false, 4200]);

  const right = await attempt({ body: { moveSan: 'Rb8#', solved: false } });
  assert.equal(attemptInserts(right.calls)[0].params[3], true);
});

test('an answer given alone touches no homework', async () => {
  const out = await attempt({ body: { moveSan: 'Ra8#' } });
  assert.equal(out.calls.filter((c) => /assignment_items|assignments/.test(c.text)).length, 0,
    out.calls.map((c) => c.text).join('\n'));
});

test('POST /api/puzzles/attempt refuses `own`: its `solved` is the client\'s word', async () => {
  const out = await call(puzzlesRouter, 'post', '/puzzles/attempt', {
    body: { puzzleId: 'cust_1', solved: true, source: 'own' },
  });
  assert.equal(out.status, 400);
  assert.equal(attemptInserts(out.calls).length, 0);
});

// ── the queue ────────────────────────────────────────────────────────────

test('the queue serves the never-tried as fresh and the last-failed as retry', async () => {
  const t = (s) => new Date(`2026-09-2${s}T10:00:00Z`);
  const rows = [
    exerciseRow({ puzzle_id: 'cust_new' }),
    exerciseRow({ puzzle_id: 'cust_failed' }),
    exerciseRow({ puzzle_id: 'cust_solved' }),
    exerciseRow({ puzzle_id: 'cust_fixed' }),
    exerciseRow({ puzzle_id: 'ex_game', solution_san: null, task: { type: 'game', side: 'w', goal: 'win' } }),
    exerciseRow({ puzzle_id: 'cust_bare', solution_san: null }),
  ];
  const attempts = [
    { puzzle_id: 'cust_failed', source: 'own', solved: false, created_at: t(1) },
    { puzzle_id: 'cust_solved', source: 'own', solved: true, created_at: t(1) },
    { puzzle_id: 'cust_fixed', source: 'own', solved: false, created_at: t(1) },
    { puzzle_id: 'cust_fixed', source: 'own', solved: true, created_at: t(2) },
    // The same id under another source is not an own attempt.
    { puzzle_id: 'cust_new', source: 'mate_puzzle', solved: false, created_at: t(1) },
    // An exercise deleted since it was failed.
    { puzzle_id: 'cust_gone', source: 'own', solved: false, created_at: t(1) },
  ];
  const out = await call(exercisesRouter, 'get', '/queue', {
    answer: (text) => {
      if (/FROM custom_puzzles/.test(text)) return { rows };
      if (/FROM user_puzzle_attempts/.test(text)) return { rows: attempts };
      return { rows: [] };
    },
  });
  assert.equal(out.status, 200);
  assert.deepEqual(out.json.fresh.map((p) => p.puzzle_id), ['cust_new']);
  assert.deepEqual(out.json.retry.map((p) => p.puzzle_id), ['cust_failed']);

  const select = out.calls.find((c) => /FROM custom_puzzles/.test(c.text));
  assert.match(select.text, /WHERE owner_id = \$1/);
  assert.deepEqual(select.params, [5]);
});

test('the queue hands out positions, never their answers', async () => {
  const out = await call(exercisesRouter, 'get', '/queue', {
    answer: (text) => (/FROM custom_puzzles/.test(text) ? { rows: [exerciseRow()] } : { rows: [] }),
  });
  const [position] = out.json.fresh;
  assert.equal(position.fen, MATE_FEN);
  assert.equal(position.side_to_move, 'w');
  assert.equal(position.instruction, 'White mates in one.');
  const wire = JSON.stringify(out.json);
  assert.doesNotMatch(wire, /Ra8/);
  assert.doesNotMatch(wire, /solution/);
});

// ── an own attempt is activity, deliberately ─────────────────────────────

// A trainer reading a student's progress, and the panel naming who has gone
// quiet, both read the whole log. An exercise solved alone *is* activity, so
// neither filters by source — and if one ever starts to, this is where that
// choice has to be made on purpose.
test('a student\'s progress counts `own` rows, in accuracy too', async () => {
  const calls = [];
  const pool = {
    query: async (text, values) => {
      calls.push(String(text));
      if (/FROM user_puzzle_attempts/.test(text)) {
        return { rows: [
          { solved: true, themes: [], puzzle_rating: null, rating_before: null, rating_after: null, created_at: new Date(), source: 'own' },
          { solved: false, themes: [], puzzle_rating: null, rating_before: null, rating_after: null, created_at: new Date(), source: 'own' },
        ] };
      }
      if (/COUNT\(\*\)/.test(text)) return { rows: [{ total: 0, completed: 0, overdue: 0 }] };
      return { rows: [] };
    },
  };
  const progress = await getStudentProgress(pool, 9);
  const attemptsSql = calls.find((t) => /FROM user_puzzle_attempts/.test(t));
  assert.doesNotMatch(attemptsSql, /source/);
  assert.equal(progress.totalAttempts, 2);
  assert.equal(progress.accuracy, 50);
});

test('the panel\'s „gone quiet" reads every source', async () => {
  let sql = '';
  await idleStudents({ query: async (text) => { sql = String(text); return { rows: [] }; } }, 1);
  assert.match(sql, /user_puzzle_attempts/);
  assert.doesNotMatch(sql, /source/);
});

test('GET /api/puzzles/retry?source=own answers through the existing fold', async () => {
  const out = await call(puzzlesRouter, 'get', '/puzzles/retry', {
    query: { source: 'own' },
    answer: (text) => (/FROM user_puzzle_attempts/.test(text)
      ? { rows: [
        { puzzle_id: 'cust_a', source: 'own', solved: false, created_at: new Date('2026-09-20') },
        { puzzle_id: 'cust_b', source: 'own', solved: true, created_at: new Date('2026-09-20') },
      ] }
      : { rows: [] }),
  });
  assert.equal(out.status, 200);
  assert.deepEqual(out.json, { source: 'own', ids: ['cust_a'] });
});
