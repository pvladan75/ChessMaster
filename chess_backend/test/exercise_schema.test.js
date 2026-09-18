// The exercise's columns on a real PostgreSQL (`docs/PLAN-EXERCISE.md`, phase
// 1): a stub pool cannot prove a NOT NULL, a CHECK or a backfill.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');
const { ORIGINS } = require('../services/exercise');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';

describe('the exercise columns on a real database', skipUnlessDatabase() ?? {}, () => {
  let db;
  let pool;
  let ownerId;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    const user = await pool.query(
      `INSERT INTO users (email, password_hash, name)
       VALUES ('exercise_owner@test.invalid', 'x', 'Trainer') RETURNING id`
    );
    ownerId = user.rows[0].id;
  });
  after(async () => { await db.drop(); });

  const insert = (puzzleId, origin) => pool.query(
    `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, solution_san, origin)
     VALUES ($1, $2, $3, 'w', 'Rd8#', $4)`,
    [puzzleId, ownerId, FEN, origin]
  );

  test('a row must say where it came from, and only from the list', async () => {
    await assert.rejects(
      pool.query(
        `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move) VALUES ('cust_noorigin', $1, $2, 'w')`,
        [ownerId, FEN]
      ),
      (err) => err.code === '23502' && /origin/.test(err.message)
    );
    await assert.rejects(insert('cust_badorigin', 'somewhere'), (err) => err.code === '23514');
    for (const origin of ORIGINS) await insert(`cust_ok_${origin}`, origin);
  });

  test('task and solution are absent until somebody writes them', async () => {
    await insert('cust_plain', 'book');
    const row = await pool.query(
      `SELECT name, task, solution FROM custom_puzzles WHERE puzzle_id = 'cust_plain'`
    );
    assert.deepEqual(row.rows[0], { name: null, task: null, solution: null });
  });

  test('running the migration again backfills rows from before the column, by what wrote them', async () => {
    // The state a database is in before this migration: no NOT NULL, no value.
    // `hwx` is the trap — in a LIKE an unescaped `_` matches any character, so
    // `'hw_%'` would file a scan whose id merely starts with „hw" under
    // mistakes.
    await pool.query('ALTER TABLE custom_puzzles ALTER COLUMN origin DROP NOT NULL');
    const old = { hw_abc123: 'mistakes', cust_abc123: 'book', hwxabc123: 'book' };
    for (const puzzleId of Object.keys(old)) await insert(puzzleId, null);
    await insert('cust_kept', 'manual');

    const { initDB } = require('../db');
    await initDB(pool);
    await initDB(pool); // and it is safe to run on every start

    const rows = await pool.query(
      'SELECT puzzle_id, origin FROM custom_puzzles WHERE puzzle_id = ANY($1::varchar[])',
      [[...Object.keys(old), 'cust_kept']]
    );
    const got = Object.fromEntries(rows.rows.map((r) => [r.puzzle_id, r.origin]));
    assert.deepEqual(got, { ...old, cust_kept: 'manual' });

    // And the NOT NULL is back.
    await assert.rejects(insert('cust_after', null), (err) => err.code === '23502');
  });

  // ---- the two writers, on the real table --------------------------------
  //
  // Every other test of them fakes the pool, and a fake pool accepts an INSERT
  // that the table refuses: a writer that forgot `origin` was green everywhere
  // and would have answered 500 to every scan a trainer confirmed.

  test('a confirmed scan is stored as coming from a book', async () => {
    const dbModule = require('../db');
    const router = require('../routes/scans');
    const layer = router.stack.find((l) => l.route && l.route.path === '/confirm' && l.route.methods.post);
    assert.ok(layer, 'POST /confirm must be mounted');
    const handler = layer.route.stack[layer.route.stack.length - 1].handle;

    const original = dbModule.pool.connect;
    dbModule.pool.connect = () => pool.connect();
    const answered = { status: 200, body: null };
    const res = {
      status(code) { answered.status = code; return this; },
      json(payload) { answered.body = payload; return this; },
    };
    try {
      await handler({
        user: { id: ownerId },
        body: { sourceTitle: 'A book', positions: [{ fen: FEN, solutionSan: 'Rd8#', label: '7', page: 3 }] },
        headers: {},
      }, res);
    } finally {
      dbModule.pool.connect = original;
    }
    assert.equal(answered.status, 201, JSON.stringify(answered.body));
    assert.equal(answered.body.saved, 1);
    const row = await pool.query(
      'SELECT origin, solution_san, task, solution FROM custom_puzzles WHERE puzzle_id = $1',
      [answered.body.puzzles[0].puzzle_id]
    );
    assert.deepEqual(row.rows[0], { origin: 'book', solution_san: 'Rd8#', task: null, solution: null });
  });

  test('a position made from a mistake is stored as coming from mistakes', async () => {
    const { storePositions, puzzleIdFor } = require('../services/homeworkFromArchive');
    const mistake = { id: 1, kind: 'tactic', theme: 'mate', fen_before: FEN, best_uci: 'd1d8', played_uci: 'd1e1' };
    const { stored, skipped } = await storePositions(pool, ownerId, [mistake]);
    assert.equal(stored.length, 1, JSON.stringify(skipped));
    const row = await pool.query('SELECT origin FROM custom_puzzles WHERE puzzle_id = $1', [puzzleIdFor(mistake)]);
    assert.equal(row.rows[0].origin, 'mistakes');
  });
});
