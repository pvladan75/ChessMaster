// puzzle_resolution.test.js
//
// `resolvePuzzles` against a real PostgreSQL. The existing
// `assignment.test.js` drives it with a stub pool, which answers whatever it
// was told and therefore cannot see the query itself be wrong — and it was:
// the fallback (the one that runs when the filters leave nothing unseen)
// carried a parameter it no longer referenced, so PostgreSQL refused to type
// it and a filter that matched nothing answered 500 rather than „no puzzles
// match". Found 17.9.2026, while sending a homework with an impossible set.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

describe('choosing the puzzles for an assignment', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let resolvePuzzles;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    ({ resolvePuzzles } = require('../services/assignmentService'));
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function student() {
    minted++;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Ana') RETURNING id`,
      [`pz${process.pid}_${minted}@test.invalid`]
    );
    return r.rows[0].id;
  }

  async function puzzle(id, { rating = 1500, themes = ['pin'] } = {}) {
    await pool.query(
      `INSERT INTO lichess_puzzles (puzzle_id, fen, moves, rating, themes)
       VALUES ($1, '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'd1d8', $2, $3::varchar[])
       ON CONFLICT (puzzle_id) DO NOTHING`,
      [id, rating, themes]
    );
    return id;
  }

  async function attempted(studentId, puzzleId) {
    await pool.query(
      `INSERT INTO user_puzzle_attempts (user_id, puzzle_id, solved, themes)
       VALUES ($1, $2, TRUE, ARRAY['pin'])`,
      [studentId, puzzleId]
    );
  }

  test('a filter that matches nothing answers with nothing, and does not throw', async () => {
    const who = await student();
    await puzzle(`pz_${process.pid}_low`, { rating: 1200 });

    // Both halves of the query run here: nothing is unseen *and* nothing
    // matches at all. This is the shape that used to throw.
    const rows = await resolvePuzzles(pool, {
      studentId: who,
      themes: ['zugzwang'],
      minRating: 3200,
      maxRating: 3400,
      count: 3,
    });
    assert.deepEqual(rows, []);
  });

  test('and with no themes at all, which numbers the parameters differently', async () => {
    const who = await student();
    const rows = await resolvePuzzles(pool, {
      studentId: who, themes: [], minRating: 3200, maxRating: 3400, count: 3,
    });
    assert.deepEqual(rows, []);
  });

  test('puzzles the student has not attempted come first', async () => {
    const who = await student();
    const seen = await puzzle(`pz_${process.pid}_seen`, { rating: 1500 });
    const fresh = await puzzle(`pz_${process.pid}_fresh`, { rating: 1500 });
    await attempted(who, seen);

    const rows = await resolvePuzzles(pool, {
      studentId: who, themes: ['pin'], minRating: 1400, maxRating: 1600, count: 5,
    });
    assert.deepEqual(rows.map((r) => r.puzzle_id), [fresh]);
  });

  test('when everything matching has been attempted, the set is offered again', async () => {
    const who = await student();
    const only = await puzzle(`pz_${process.pid}_only`, { rating: 2000, themes: ['fork'] });
    await attempted(who, only);

    // The fallback: better to re-issue than to send an empty assignment.
    const rows = await resolvePuzzles(pool, {
      studentId: who, themes: ['fork'], minRating: 1900, maxRating: 2100, count: 3,
    });
    assert.deepEqual(rows.map((r) => r.puzzle_id), [only]);
  });

  test('two themes mean either, and the rating range binds', async () => {
    const who = await student();
    const pin = await puzzle(`pz_${process.pid}_pin`, { rating: 1000, themes: ['pin'] });
    const fork = await puzzle(`pz_${process.pid}_fork`, { rating: 1000, themes: ['fork'] });
    await puzzle(`pz_${process.pid}_high`, { rating: 2900, themes: ['pin'] });

    const rows = await resolvePuzzles(pool, {
      studentId: who, themes: ['pin', 'fork'], minRating: 900, maxRating: 1100, count: 10,
    });
    assert.deepEqual(rows.map((r) => r.puzzle_id).sort(), [fork, pin].sort());
  });
});
