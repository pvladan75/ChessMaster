// puzzle_progress_routes.test.js — the gate of docs/PLAN-NAPREDAK-VEZBI.md
// phase 1. Copied into chess_backend/test/ by the implementer as the first
// step and left there green. Written 17.9.2026 and red on master at 516bc53:
// /submit writes no attempt row, /attempt knows no source, and neither
// /puzzles/progress nor /puzzles/retry is mounted.
//
// Handlers are called directly with a fake request, the pool is the real
// module's object with `query` replaced for the test — the idiom of
// endgame_routes_auth.test.js and mistake_reviews.test.js. Fake the client,
// assert the request (rule 7): every test reads what the route asked the
// database, not what a stub answered.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/puzzles');
const { authenticateToken } = require('../middleware/auth');
const db = require('../db');

function handlersOf(method, path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

/// Runs the route's last handler with a fake request; answers every query by
/// reading the statement through `answer`; returns what the route sent.
async function call(method, path, { body = {}, query = {}, params = {}, userId = 5, answer = () => ({ rows: [] }) } = {}) {
  const handlers = handlersOf(method, path);
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

const insertsOf = (calls) => calls.filter((c) => /INSERT INTO user_puzzle_attempts/.test(c.text));

// ── the four routes are behind sign-in ──────────────────────────────────

for (const [method, path] of [
  ['post', '/puzzles/submit'],
  ['post', '/puzzles/attempt'],
  ['get', '/puzzles/progress'],
  ['get', '/puzzles/retry'],
  ['get', '/puzzles/by-id/:puzzleId'],
]) {
  test(`${method.toUpperCase()} /api${path} is behind sign-in`, () => {
    assert.equal(handlersOf(method, path)[0], authenticateToken);
  });
}

// ── /submit writes the row the plan needs ────────────────────────────────

test('/submit inserts one attempt row, sourced from the puzzle\'s own type', async () => {
  const out = await call('post', '/puzzles/submit', {
    body: { puzzleId: 'm2-0042', solved: false, hinted: true },
    answer: (text) => {
      if (/FROM puzzles WHERE puzzle_id/.test(text)) return { rows: [{ eval_value: 3, type: 'mate_puzzle' }] };
      if (/FROM user_puzzle_ratings/.test(text)) return { rows: [] };
      return { rows: [] };
    },
  });
  assert.equal(out.status, 200);
  const inserts = insertsOf(out.calls);
  assert.equal(inserts.length, 1, 'exactly one attempt row per submit');
  const { text, params } = inserts[0];
  assert.match(text, /\(user_id, puzzle_id, source, solved, skipped, hinted/);
  assert.deepEqual(params.slice(0, 6), [5, 'm2-0042', 'mate_puzzle', false, false, true]);
});

test('/submit reads the type with the eval, in one query', async () => {
  const out = await call('post', '/puzzles/submit', {
    body: { puzzleId: 'w-7', solved: true },
    answer: (text) => (/FROM puzzles WHERE puzzle_id/.test(text)
      ? { rows: [{ eval_value: 1, type: 'winning_position' }] } : { rows: [] }),
  });
  const read = out.calls.find((c) => /FROM puzzles WHERE puzzle_id/.test(c.text));
  assert.ok(read, 'the puzzle row is read');
  assert.match(read.text, /SELECT eval_value, type FROM puzzles/);
  assert.deepEqual(insertsOf(out.calls)[0].params.slice(2, 5), ['winning_position', true, false]);
});

test('/submit still refuses a missing puzzleId', async () => {
  const out = await call('post', '/puzzles/submit', { body: { solved: true } });
  assert.equal(out.status, 400);
  assert.equal(insertsOf(out.calls).length, 0);
});

// ── /attempt takes a source, a skip and a hint ───────────────────────────

test('/attempt without a source is the Lichess path it always was', async () => {
  const out = await call('post', '/puzzles/attempt', {
    body: { puzzleId: 'abcde', solved: true, msTaken: 900 },
    answer: (text) => {
      if (/FROM lichess_puzzles/.test(text)) return { rows: [{ rating: 1600, themes: ['fork'] }] };
      return { rows: [] };
    },
  });
  assert.equal(out.status, 200);
  const [ins] = insertsOf(out.calls);
  assert.ok(ins, 'a row is written');
  assert.match(ins.text, /source, solved, skipped, hinted/);
  const i = ins.params.indexOf('lichess');
  assert.ok(i >= 0, 'source is lichess');
  assert.ok(out.calls.some((c) => /user_puzzle_ratings/.test(c.text)), 'the rating still moves');
});

test('/attempt with source endgame writes the row and touches no rating', async () => {
  const out = await call('post', '/puzzles/attempt', {
    body: { puzzleId: 'eg-91', source: 'endgame', solved: false, skipped: true },
  });
  assert.equal(out.status, 200);
  const [ins] = insertsOf(out.calls);
  assert.ok(ins, 'a row is written');
  assert.deepEqual(ins.params.slice(0, 6), [5, 'eg-91', 'endgame', false, true, false]);
  assert.equal(out.calls.some((c) => /lichess_puzzles|user_puzzle_ratings/.test(c.text)), false,
    'no Lichess lookup, no Elo, for a source that has neither');
});

test('/attempt refuses a source the plan does not name', async () => {
  const out = await call('post', '/puzzles/attempt', {
    body: { puzzleId: 'x', source: 'tactics', solved: true },
  });
  assert.equal(out.status, 400);
  assert.equal(insertsOf(out.calls).length, 0);
});

test('/attempt stores a hinted solve as hinted', async () => {
  const out = await call('post', '/puzzles/attempt', {
    body: { puzzleId: 'b:easy:8/8/8/8 w - -', source: 'basic_mate', solved: true, hinted: true },
  });
  const [ins] = insertsOf(out.calls);
  assert.deepEqual(ins.params.slice(2, 6), ['basic_mate', true, false, true]);
});

// ── /progress and /retry read the log through the service ────────────────

test('/progress answers with the fold of the user\'s log', async () => {
  const rows = [
    { puzzle_id: 'a', source: 'mate_puzzle', solved: true, skipped: false, hinted: false, bucket: '2', created_at: '2026-09-01T10:00:00Z' },
    { puzzle_id: 'b', source: 'mate_puzzle', solved: false, skipped: false, hinted: false, bucket: '2', created_at: '2026-09-01T10:01:00Z' },
    { puzzle_id: 'e', source: 'endgame', solved: false, skipped: true, hinted: false, bucket: 'win', created_at: '2026-09-01T10:02:00Z' },
  ];
  const out = await call('get', '/puzzles/progress', {
    userId: 9,
    answer: (text) => (/FROM user_puzzle_attempts a/.test(text) ? { rows } : { rows: [] }),
  });
  assert.equal(out.status, 200);
  const read = out.calls.find((c) => /FROM user_puzzle_attempts a/.test(c.text));
  assert.deepEqual(read.params, [9], 'asks for the signed-in user and nobody else');
  assert.equal(out.json.mate_puzzle.seen, 2);
  assert.equal(out.json.mate_puzzle.toRetry, 1);
  assert.equal(out.json.mate_puzzle.buckets['2'].solved, 1);
  assert.equal(out.json.endgame.skipped, 1);
  assert.equal(out.json.endgame.buckets.win.toRetry, 1);
  assert.equal('lichess' in out.json, false, 'a source with nothing seen is absent');
});

test('/retry lists the unsolved of one source, oldest first', async () => {
  const rows = [
    { puzzle_id: 'late', source: 'endgame', solved: false, skipped: false, hinted: false, created_at: '2026-09-01T10:00:00Z' },
    { puzzle_id: 'early', source: 'endgame', solved: false, skipped: false, hinted: false, created_at: '2026-09-01T10:05:00Z' },
    { puzzle_id: 'fixed', source: 'endgame', solved: false, skipped: false, hinted: false, created_at: '2026-09-01T10:06:00Z' },
    { puzzle_id: 'fixed', source: 'endgame', solved: true, skipped: false, hinted: false, created_at: '2026-09-01T10:07:00Z' },
    { puzzle_id: 'm', source: 'mate_puzzle', solved: false, skipped: false, hinted: false, created_at: '2026-09-01T10:08:00Z' },
  ];
  const out = await call('get', '/puzzles/retry', {
    query: { source: 'endgame' },
    answer: (text) => (/FROM user_puzzle_attempts a/.test(text) ? { rows } : { rows: [] }),
  });
  assert.equal(out.status, 200);
  assert.deepEqual(out.json, { source: 'endgame', ids: ['late', 'early'] });
});

test('/retry without a known source is a 400, not an empty list', async () => {
  assert.equal((await call('get', '/puzzles/retry', { query: {} })).status, 400);
  assert.equal((await call('get', '/puzzles/retry', { query: { source: 'tactics' } })).status, 400);
});

// ── /by-id serves the other pools in their own drill's shape ─────────────

test('/by-id without a source is the Lichess route it always was', async () => {
  const out = await call('get', '/puzzles/by-id/:puzzleId', {
    params: { puzzleId: 'abcde' },
    answer: (text) => (/FROM lichess_puzzles WHERE puzzle_id/.test(text)
      ? { rows: [{ puzzle_id: 'abcde', fen: '8/8/8/8/8/8/8/K6k w - - 0 1', moves: 'a1a2', rating: 1500, themes: ['fork'] }] }
      : { rows: [] }),
  });
  assert.equal(out.status, 200);
  assert.ok(out.json.puzzle, 'the Lichess shape');
});

test('/by-id?source=mate_puzzle reads `puzzles` and answers in /puzzles/next\'s shape', async () => {
  const row = {
    puzzle_id: 'm2-0042', source: 'mined', fen: '8/8/8/8/8/8/8/K6k w - - 0 1', side_to_move: 'w',
    eval: '#2', eval_value: 3, type: 'mate_puzzle', mate_depth: 2, winning_move_uci: 'a1a2',
    winning_move_san: 'Ka2', solutions: {},
  };
  const out = await call('get', '/puzzles/by-id/:puzzleId', {
    params: { puzzleId: 'm2-0042' }, query: { source: 'mate_puzzle' },
    answer: (text, values) => {
      if (/FROM puzzles WHERE puzzle_id = \$1/.test(text)) {
        assert.deepEqual(values, ['m2-0042']);
        return { rows: [row] };
      }
      return { rows: [] };
    },
  });
  assert.equal(out.status, 200);
  assert.equal(out.json.puzzle.puzzle_id, 'm2-0042');
  assert.equal(out.json.puzzle.mate_depth, 2);
  assert.deepEqual(out.json.puzzle.moves, ['a1a2']);
  assert.equal(out.calls.some((c) => /lichess_puzzles/.test(c.text)), false);
});

test('/by-id?source=endgame reads `endgame_puzzles` and answers in /puzzles/endgame/next\'s shape', async () => {
  const row = {
    puzzle_id: 'eg-91', fen: '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1', endgame_type: 'KPvK', mode: 'win',
    side_to_move: 'w', winning_moves: ['e1d2'], solution: ['e1d2'], solution_san: ['Kd2'],
    difficulty: 'easy', difficulty_score: 10, piece_count: 3, pawn_count: 1, source: 'tablebase',
    material: 'KPvK', blunder_elo: null, played_move: null, evaluation: 'win', wdl: 2, dtz: 10,
    game_white: null,
  };
  const out = await call('get', '/puzzles/by-id/:puzzleId', {
    params: { puzzleId: 'eg-91' }, query: { source: 'endgame' },
    answer: (text) => (/FROM endgame_puzzles WHERE puzzle_id = \$1/.test(text) ? { rows: [row] } : { rows: [] }),
  });
  assert.equal(out.status, 200);
  assert.equal(out.json.endgame.puzzle_id, 'eg-91');
  assert.equal(out.json.endgame.mode, 'win');
  assert.deepEqual(out.json.endgame.winning_moves, ['e1d2']);
});

test('/by-id with an unknown source is a 400; a missing row is a 404', async () => {
  assert.equal((await call('get', '/puzzles/by-id/:puzzleId', {
    params: { puzzleId: 'x' }, query: { source: 'tactics' },
  })).status, 400);
  assert.equal((await call('get', '/puzzles/by-id/:puzzleId', {
    params: { puzzleId: 'nope' }, query: { source: 'endgame' },
  })).status, 404);
});
