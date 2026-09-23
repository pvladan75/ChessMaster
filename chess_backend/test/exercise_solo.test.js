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

// ── one's own game exercise, played out (docs/PLAN-MATERIJAL.md, phase 5) ──
//
// Judged as a homework's game is — the rules, then a tablebase where the game
// stopped at its move target — and logged as `own` only when something judged
// it. „Play N moves" has no goal and alone no trainer: nothing is written. A
// silent tablebase writes nothing and says `pending`.

const soloService = require('../services/exerciseSolo');
const { TablebaseUnavailable } = require('../services/tablebaseService');

const ROOK_FEN = '4k3/8/8/8/8/8/8/4K2R w - - 0 1';
const THREE_MOVES = 'Rh2 Kd8 Rh3 Ke8 Rh4';

function gameRow(task, over = {}) {
  return {
    puzzle_id: 'ex_game', fen: ROOK_FEN, task: { type: 'game', ...task },
    solution: null, solution_san: null, needs_review: false, ...over,
  };
}

/// The service over one stored row, recording every query and every probe.
async function playOwn(row, { moves, resigned, probe } = {}) {
  const calls = [];
  const probed = [];
  const pool = {
    query: async (text, values = []) => {
      const flat = String(text).replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params: values });
      return /FROM custom_puzzles/.test(flat) ? { rowCount: 1, rows: [row] } : { rowCount: 0, rows: [] };
    },
  };
  const tablebase = {
    probe: async (fen) => {
      probed.push(fen);
      if (probe instanceof Error) throw probe;
      return { category: probe ?? 'draw' };
    },
  };
  const out = await soloService.gameResultOwn(pool, {
    ownerId: 5, puzzleId: row.puzzle_id, moves, resigned, tablebase,
  });
  return { out, inserts: attemptInserts(calls), probed };
}

test('POST /exercises/:id/game-result is mounted and behind sign-in', () => {
  assert.equal(handlersOf(exercisesRouter, 'post', '/:id/game-result')[0], authenticateToken);
});

test('a win judged by the rules writes a solved own attempt', async () => {
  const row = gameRow({ side: 'w', goal: 'win' }, { fen: '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1' });
  const { out, inserts, probed } = await playOwn(row, { moves: 'Rd8#' });
  assert.deepEqual(out.result, { goalMet: true, judgedBy: 'rules', pending: false, ending: 'checkmate', outcome: 'won' });
  assert.deepEqual(inserts.map((c) => c.params), [[5, 'ex_game', 'own', true]]);
  assert.deepEqual(probed, [], 'a win is never asked of a tablebase');
});

test('a hold stopped at its move target asks the tablebase, and writes by its answer', async () => {
  const row = gameRow({ side: 'w', goal: 'hold', surviveMoves: 3 });
  const held = await playOwn(row, { moves: THREE_MOVES, probe: 'draw' });
  assert.deepEqual(held.probed, ['4k3/8/8/8/7R/8/8/4K3 b - - 5 3'], 'the position the game reached');
  assert.equal(held.out.result.judgedBy, 'tablebase');
  assert.deepEqual(held.inserts.map((c) => c.params[3]), [true]);

  // Black to move and winning: White did not hold.
  const lost = await playOwn(row, { moves: THREE_MOVES, probe: 'win' });
  assert.equal(lost.out.result.goalMet, false);
  assert.deepEqual(lost.inserts.map((c) => c.params[3]), [false]);
});

test('a silent tablebase writes nothing and says pending', async () => {
  const row = gameRow({ side: 'w', goal: 'hold', surviveMoves: 3 });
  const { out, inserts } = await playOwn(row, { moves: THREE_MOVES, probe: new TablebaseUnavailable('down') });
  assert.deepEqual(out.result, { goalMet: null, judgedBy: null, pending: true, ending: 'moveTarget', outcome: 'undecided' });
  assert.equal(inserts.length, 0);
});

test('„Play N moves" alone is played and nothing more: no row, no judge, nothing pending', async () => {
  const row = gameRow({ side: 'w', goal: 'play', surviveMoves: 3 });
  const { out, inserts, probed } = await playOwn(row, { moves: THREE_MOVES });
  assert.equal(out.result.judgedBy, null);
  assert.equal(out.result.goalMet, null);
  assert.equal(out.result.pending, false, 'nothing will ever judge it, so nothing waits');
  assert.equal(inserts.length, 0);
  assert.deepEqual(probed, []);
});

test('a game not over yet is refused, and nothing is written', async () => {
  const row = gameRow({ side: 'w', goal: 'hold', surviveMoves: 3 });
  const { out, inserts } = await playOwn(row, { moves: 'Rh2 Kd8' });
  assert.equal(out.status, 422);
  assert.equal(inserts.length, 0);
});

test('a find exercise is not played out: 409, with the reason', async () => {
  const { out, inserts } = await playOwn(exerciseRow({ puzzle_id: 'ex_game' }), { moves: 'Ra8#' });
  assert.equal(out.status, 409);
  assert.match(out.error, /asks for a move/);
  assert.equal(inserts.length, 0);
});

test('somebody else\'s game exercise is 404, asked by owner', async () => {
  const out = await call(exercisesRouter, 'post', '/:id/game-result', {
    params: { id: 'ex_game' },
    body: { moves: 'Rd8#' },
    userId: 6,
    answer: () => ({ rows: [] }),
  });
  assert.equal(out.status, 404);
  const select = out.calls.find((c) => /FROM custom_puzzles/.test(c.text));
  assert.match(select.text, /owner_id = \$2/);
  assert.deepEqual(select.params, ['ex_game', 6]);
});

test('an own game touches no homework', async () => {
  const row = gameRow({ side: 'w', goal: 'win' }, { fen: '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1' });
  const calls = [];
  const pool = {
    query: async (text, values) => {
      calls.push(String(text));
      return /FROM custom_puzzles/.test(text) ? { rowCount: 1, rows: [row] } : { rowCount: 0, rows: [] };
    },
  };
  await soloService.gameResultOwn(pool, { ownerId: 5, puzzleId: 'ex_game', moves: 'Rd8#' });
  assert.equal(calls.filter((t) => /assignment/.test(t)).length, 0);
});
