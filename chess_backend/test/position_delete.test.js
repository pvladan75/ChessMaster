// Deleting a position of one's own, on a real database — the owner's rule of
// 22.9.2026 (services/positionDeletion.js): refused while a homework that is
// not finished holds it, and the refusal names the homework.
//
// On a real database because the rule is a question asked inside a DELETE: a
// stub can see that a question was asked, not which one.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

describe('deleting a position on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let deletion;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    deletion = require('../services/positionDeletion');
  });

  after(async () => {
    if (db) await db.drop();
  });

  // A trainer, a student and a position of the trainer's, minted per test.
  let minted = 0;
  async function world() {
    minted++;
    const tag = `${process.pid}_${minted}`;
    const t = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Trainer') RETURNING id`,
      [`pt${tag}@test.invalid`]
    );
    const s = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Ana') RETURNING id`,
      [`ps${tag}@test.invalid`]
    );
    const puzzleId = `cust_pd${tag}`;
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, origin)
       VALUES ($1, $2, '8/8/8/8/8/8/8/K6k w - - 0 1', 'w', 'book')`,
      [puzzleId, t.rows[0].id]
    );
    return { trainerId: t.rows[0].id, studentId: s.rows[0].id, puzzleId, tag };
  }

  /// A sent homework holding the position: a parent and one child item.
  async function sent({ trainerId, studentId, puzzleId }, { title = 'Thursday' } = {}) {
    const parent = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, $3, 'homework') RETURNING id`,
      [trainerId, studentId, title]
    );
    const child = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind, parent_id, position, item_key)
       VALUES ($1, $2, 'item 0', 'puzzles', $3, 0, 'k0') RETURNING id`,
      [trainerId, studentId, parent.rows[0].id]
    );
    await pool.query(
      'INSERT INTO assignment_items (assignment_id, puzzle_id, position) VALUES ($1, $2, 0)',
      [child.rows[0].id, puzzleId]
    );
    return { parentId: parent.rows[0].id, childId: child.rows[0].id };
  }

  async function complete(id) {
    await pool.query('UPDATE assignments SET completed_at = NOW() WHERE id = $1', [id]);
  }

  async function exists(puzzleId) {
    const r = await pool.query('SELECT 1 FROM custom_puzzles WHERE puzzle_id = $1', [puzzleId]);
    return r.rowCount === 1;
  }

  test('a position nothing holds is deleted', async () => {
    const w = await world();
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.deepEqual(result, { ok: true });
    assert.equal(await exists(w.puzzleId), false);
  });

  test("somebody else's position is not found, and stays", async () => {
    const w = await world();
    const other = await world();
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: other.trainerId });
    assert.equal(result.status, 404);
    assert.equal(await exists(w.puzzleId), true);
  });

  test('a sent homework not yet done keeps it, and is named with its student', async () => {
    const w = await world();
    await sent(w, { title: 'Rook endings' });
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.equal(result.status, 409);
    assert.deepEqual(result.uses, [{ kind: 'sent', title: 'Rook endings', student: 'Ana' }]);
    assert.equal(await exists(w.puzzleId), true);
    assert.match(deletion.inUseMessage(result.uses), /Rook endings.*Ana/);
  });

  test('an answered item in a homework still open keeps it', async () => {
    const w = await world();
    const { childId } = await sent(w);
    await complete(childId);
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.equal(result.status, 409, 'the homework it belongs to is not finished');
    assert.equal(await exists(w.puzzleId), true);
  });

  test('once the homework is finished, the position can go', async () => {
    const w = await world();
    const { parentId, childId } = await sent(w);
    await complete(childId);
    await complete(parentId);
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.deepEqual(result, { ok: true });
  });

  test('a withdrawn homework no longer holds it', async () => {
    const w = await world();
    const { parentId } = await sent(w);
    await pool.query('DELETE FROM assignments WHERE id = $1', [parentId]);
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.deepEqual(result, { ok: true });
  });

  test('a saved homework not yet sent keeps it; one holding other positions does not', async () => {
    const w = await world();
    const plan = async (title, ids) => {
      const h = await pool.query(
        'INSERT INTO homeworks (trainer_id, title) VALUES ($1, $2) RETURNING id', [w.trainerId, title]
      );
      await pool.query(
        `INSERT INTO homework_items (homework_id, item_key, position, kind, task)
         VALUES ($1, 'a', 0, 'positions', $2)`,
        [h.rows[0].id, JSON.stringify({ puzzleIds: ids })]
      );
      return h.rows[0].id;
    };
    await plan('Unrelated', [`${w.puzzleId}_other`]);
    const holding = await plan('Next week', ['cust_x', w.puzzleId]);

    const refused = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.equal(refused.status, 409);
    assert.deepEqual(refused.uses, [{ kind: 'plan', title: 'Next week' }]);

    await pool.query('DELETE FROM homeworks WHERE id = $1', [holding]);
    const result = await deletion.deleteOwnPosition(pool, { puzzleId: w.puzzleId, ownerId: w.trainerId });
    assert.deepEqual(result, { ok: true });
  });
});
