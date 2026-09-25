// homework_gate.test.js
//
// Phase 1 of docs/PLAN-DOMACI-ZADATAK.md, proven on a real PostgreSQL: the
// schema's constraints, when an item of a sent homework is locked, when it has
// passed, and when the homework is complete. Everything here is a WHERE clause
// or a CHECK, which the stub pools elsewhere in the suite cannot see.
//
// Needs TEST_DATABASE_URL (see test/support/pgTestDb.js). Skipped with a reason
// on a workstation without one; fails in CI without one.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const realtime = require('../services/realtime');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

realtime.init({ to: () => ({ emit: () => {} }) });

const skip = skipUnlessDatabase();

describe('homework on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let assignments;
  let homework;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    assignments = require('../services/assignmentService');
    homework = require('../services/homeworkService');
  });

  after(async () => {
    if (db) await db.drop();
  });

  // One pair of accounts per test: nothing a test writes can decide another.
  let minted = 0;
  async function people() {
    minted++;
    const tag = `${process.pid}_${minted}`;
    const t = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Trainer') RETURNING id`,
      [`t${tag}@test.invalid`]
    );
    const s = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Ana') RETURNING id`,
      [`s${tag}@test.invalid`]
    );
    return { trainerId: t.rows[0].id, studentId: s.rows[0].id, tag };
  }

  /// A sent homework as phase 4 will write it: a parent, and one child per
  /// item. Each child is a puzzle set of `puzzles` items, or a tutorial's film
  /// (`video`) — one item, done when it is downloaded.
  async function sent({ trainerId, studentId, tag }, items) {
    const parent = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, 'Thursday', 'homework') RETURNING id`,
      [trainerId, studentId]
    );
    const parentId = parent.rows[0].id;
    const children = [];
    for (const [index, item] of items.entries()) {
      const kind = item.video ? 'lesson' : 'puzzles';
      const child = await pool.query(
        `INSERT INTO assignments
           (trainer_id, student_id, title, kind, parent_id, position, item_key, gate)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
        [trainerId, studentId, `item ${index}`, kind, parentId, index * 10, `k${index}`,
          item.gate === true]
      );
      const id = child.rows[0].id;
      const puzzleIds = [];
      if (item.video) {
        await pool.query(
          'INSERT INTO assignment_items (assignment_id, position) VALUES ($1, 0)',
          [id]
        );
      } else {
        for (let p = 0; p < (item.puzzles || 1); p++) {
          const puzzleId = `hw${tag}_${index}_${p}`;
          puzzleIds.push(puzzleId);
          await pool.query(
            `INSERT INTO assignment_items (assignment_id, puzzle_id, position) VALUES ($1, $2, $3)`,
            [id, puzzleId, p]
          );
        }
      }
      children.push({ id, puzzleIds });
    }
    return { parentId, children };
  }

  async function states(parentId) {
    const rows = await homework.childrenOf(pool, parentId);
    return rows.map((r) => (r.passed ? 'passed' : r.locked ? 'locked' : 'open'));
  }

  async function solve(studentId, puzzleId, solved = true) {
    return assignments.recordPuzzleResult(pool, { studentId, puzzleId, solved, msTaken: 1000 });
  }

  async function completedAt(id) {
    const r = await pool.query('SELECT completed_at FROM assignments WHERE id = $1', [id]);
    return r.rows[0].completed_at;
  }

  async function notices(trainerId) {
    const r = await pool.query(
      `SELECT title, ref_id FROM user_notifications WHERE user_id = $1 AND kind = 'assignment_done'`,
      [trainerId]
    );
    return r.rows;
  }

  // ---- the schema ----------------------------------------------------------

  test('the kind check takes the two new kinds and nothing else', async () => {
    const who = await people();
    for (const kind of ['puzzles', 'lesson', 'homework', 'engine_game']) {
      await pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind) VALUES ($1, $2, 't', $3)`,
        [who.trainerId, who.studentId, kind]
      );
    }
    await assert.rejects(
      pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind) VALUES ($1, $2, 't', 'course')`,
        [who.trainerId, who.studentId]
      ),
      /assignments_kind_check/
    );
  });

  test('a homework cannot sit inside another, and a child must know its place', async () => {
    const who = await people();
    const { parentId } = await sent(who, [{}]);
    await assert.rejects(
      pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind, parent_id, position, item_key)
         VALUES ($1, $2, 'nested', 'homework', $3, 5, 'kx')`,
        [who.trainerId, who.studentId, parentId]
      ),
      /assignments_homework_shape/
    );
    await assert.rejects(
      pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind, parent_id, item_key)
         VALUES ($1, $2, 'no place', 'puzzles', $3, 'ky')`,
        [who.trainerId, who.studentId, parentId]
      ),
      /assignments_homework_shape/
    );
  });

  test('two children of one homework cannot share a position or an item', async () => {
    const who = await people();
    const { parentId } = await sent(who, [{}]); // position 0, key k0
    await assert.rejects(
      pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind, parent_id, position, item_key)
         VALUES ($1, $2, 'dup', 'puzzles', $3, 0, 'other')`,
        [who.trainerId, who.studentId, parentId]
      ),
      /idx_assignments_child_position/
    );
    await assert.rejects(
      pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind, parent_id, position, item_key)
         VALUES ($1, $2, 'dup', 'puzzles', $3, 99, 'k0')`,
        [who.trainerId, who.studentId, parentId]
      ),
      /idx_assignments_child_item/
    );
  });

  test('a homework template keeps item keys unique and task an object', async () => {
    const who = await people();
    const h = await pool.query(
      `INSERT INTO homeworks (trainer_id, title) VALUES ($1, 'T') RETURNING id`,
      [who.trainerId]
    );
    const hid = h.rows[0].id;
    await pool.query(
      `INSERT INTO homework_items (homework_id, item_key, position, kind) VALUES ($1, 'a', 0, 'lesson')`,
      [hid]
    );
    await assert.rejects(
      pool.query(
        `INSERT INTO homework_items (homework_id, item_key, position, kind) VALUES ($1, 'a', 1, 'puzzles')`,
        [hid]
      ),
      /homework_items_homework_id_item_key_key/
    );
    await assert.rejects(
      pool.query(
        `INSERT INTO homework_items (homework_id, item_key, position, kind, task)
         VALUES ($1, 'b', 1, 'puzzles', '[1]')`,
        [hid]
      ),
      /homework_items_task_check/
    );
    await assert.rejects(
      pool.query(
        `INSERT INTO homework_items (homework_id, item_key, position, kind) VALUES ($1, 'c', 2, 'video')`,
        [hid]
      ),
      /homework_items_kind_check/
    );
  });

  test('withdrawing the homework takes its items; deleting the template keeps what was sent', async () => {
    const who = await people();
    const h = await pool.query(
      `INSERT INTO homeworks (trainer_id, title) VALUES ($1, 'T') RETURNING id`,
      [who.trainerId]
    );
    const { parentId, children } = await sent(who, [{}, {}]);
    await pool.query('UPDATE assignments SET homework_id = $1 WHERE id = $2', [h.rows[0].id, parentId]);

    await pool.query('DELETE FROM homeworks WHERE id = $1', [h.rows[0].id]);
    const kept = await pool.query('SELECT homework_id FROM assignments WHERE id = $1', [parentId]);
    assert.equal(kept.rows[0].homework_id, null, 'the sent copy outlives its template');

    assert.equal(
      await homework.withdrawAssignment(pool, { assignmentId: children[0].id, trainerId: who.trainerId }),
      'child',
      'an item alone is refused'
    );
    assert.equal(
      await homework.withdrawAssignment(pool, { assignmentId: parentId, trainerId: who.studentId }),
      'not_found',
      'not the trainer'
    );
    assert.equal(
      await homework.withdrawAssignment(pool, { assignmentId: parentId, trainerId: who.trainerId }),
      'ok'
    );
    const left = await pool.query(
      'SELECT COUNT(*)::int AS n FROM assignments WHERE id = ANY($1::int[])',
      [[parentId, ...children.map((c) => c.id)]]
    );
    assert.equal(left.rows[0].n, 0);
  });

  // ---- the gate ------------------------------------------------------------

  test('a gated item is locked until the one before it is done, down the chain', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, { gate: true }, { gate: true }]);

    assert.deepEqual(await states(parentId), ['open', 'locked', 'locked']);
    const rows = await homework.childrenOf(pool, parentId);
    assert.equal(rows[1].blocked_by, children[0].id);
    assert.equal(rows[2].blocked_by, children[1].id);

    await solve(who.studentId, children[0].puzzleIds[0]);
    assert.deepEqual(await states(parentId), ['passed', 'open', 'locked']);
  });

  test('an item without a gate is open whatever comes before it', async () => {
    const who = await people();
    const { parentId } = await sent(who, [{}, {}, { gate: true }]);
    assert.deepEqual(await states(parentId), ['open', 'open', 'locked']);
  });

  test('a gate on the first item locks nothing', async () => {
    const who = await people();
    const { parentId } = await sent(who, [{ gate: true }]);
    assert.deepEqual(await states(parentId), ['open']);
  });

  test('„done" is attempted by default: a wrong answer passes the gate', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, { gate: true }]);
    await solve(who.studentId, children[0].puzzleIds[0], false);
    assert.deepEqual(await states(parentId), ['passed', 'open']);
  });

  test('done is attempted and nothing else: a wrong answer and a downloaded film both pass', async () => {
    // There was a „must be solved" switch. The owner removed it on 18.9.2026
    // (`docs/PLAN-EXERCISE.md` §8.3): it was the one thing in a homework that
    // could hold a student on a board for good, and the review already shows
    // the trainer what was solved.
    const who = await people();
    const wrong = await sent(who, [{ puzzles: 2 }, { gate: true }]);
    await solve(who.studentId, wrong.children[0].puzzleIds[0], true);
    await solve(who.studentId, wrong.children[0].puzzleIds[1], false);
    assert.ok(await completedAt(wrong.children[0].id));
    assert.deepEqual(await states(wrong.parentId), ['passed', 'open']);

    const other = await people();
    const film = await sent(other, [{ video: true }, { gate: true }]);
    await assignments.recordVideoDownload(pool, {
      studentId: other.studentId, assignmentId: film.children[0].id,
    });
    assert.deepEqual(await states(film.parentId), ['passed', 'open']);
  });

  test('the column that narrowed „done" to „solved" is gone from both tables', async () => {
    // A fresh database never had it, so this plants it the way every database
    // made before 18.9.2026 has it, and runs the migration: a test of a DROP
    // on a table that was never given the column cannot fail.
    await pool.query('ALTER TABLE assignments ADD COLUMN IF NOT EXISTS require_solved BOOLEAN NOT NULL DEFAULT FALSE');
    await pool.query('ALTER TABLE homework_items ADD COLUMN IF NOT EXISTS require_solved BOOLEAN NOT NULL DEFAULT FALSE');
    const { initDB } = require('../db');
    await initDB(pool);

    const found = await pool.query(
      `SELECT table_name FROM information_schema.columns
        WHERE column_name = 'require_solved' AND table_schema = current_schema()`
    );
    assert.deepEqual(found.rows, []);
  });

  test('the trainer opens a locked item for that student, and only the trainer can', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, { gate: true }]);

    assert.equal(
      await homework.openGate(pool, { assignmentId: children[1].id, trainerId: who.studentId }),
      false,
      'the student cannot open their own gate'
    );
    assert.equal(
      await homework.openGate(pool, { assignmentId: parentId, trainerId: who.trainerId }),
      false,
      'a homework is not an item'
    );
    assert.equal(
      await homework.openGate(pool, { assignmentId: children[1].id, trainerId: who.trainerId }),
      true
    );
    assert.deepEqual(await states(parentId), ['open', 'open']);
  });

  test('a completed item is never locked again', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, { gate: true }]);
    await homework.openGate(pool, { assignmentId: children[1].id, trainerId: who.trainerId });
    await solve(who.studentId, children[1].puzzleIds[0]);
    // The trainer closes the gate again after the work is done.
    await pool.query('UPDATE assignments SET gate_opened_at = NULL WHERE id = $1', [children[1].id]);
    assert.deepEqual(await states(parentId), ['open', 'passed']);
    // Asked directly, not through `states`, which reports „passed" before it
    // looks at „locked" and so could not see this mutation (it survived once).
    const rows = await homework.childrenOf(pool, parentId);
    assert.equal(rows[1].locked, false);
    assert.deepEqual(await homework.lockOf(pool, children[1].id), { locked: false, blockedBy: null });
    const reopened = await assignments.getAssignmentDetail(pool, children[1].id, who.studentId);
    assert.equal(reopened.id, children[1].id, 'the student can reopen finished work');
  });

  // ---- the gate holds where answers are written ---------------------------

  test('an answer to a locked puzzle is not recorded', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { gate: true }]);
    assert.equal(await solve(who.studentId, children[1].puzzleIds[0]), 0);
    const item = await pool.query(
      'SELECT attempted_at FROM assignment_items WHERE puzzle_id = $1',
      [children[1].puzzleIds[0]]
    );
    assert.equal(item.rows[0].attempted_at, null);
  });

  test('a locked film cannot be recorded as downloaded', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { video: true, gate: true }]);
    const args = { studentId: who.studentId, assignmentId: children[1].id };
    assert.equal(await assignments.recordVideoDownload(pool, args), false);
    const item = await pool.query(
      'SELECT attempted_at, solved FROM assignment_items WHERE assignment_id = $1',
      [children[1].id]
    );
    assert.deepEqual(item.rows[0], { attempted_at: null, solved: null });
  });

  test('the student is refused a locked item; the trainer reads it', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { gate: true }]);
    assert.deepEqual(
      await assignments.getAssignmentDetail(pool, children[1].id, who.studentId),
      { locked: true, blockedBy: children[0].id }
    );
    const asTrainer = await assignments.getAssignmentDetail(pool, children[1].id, who.trainerId);
    assert.equal(asTrainer.id, children[1].id);
    assert.equal(asTrainer.items.length, 1);
  });

  // ---- completion ----------------------------------------------------------

  test('the homework completes when its last item does, and tells the trainer once', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, {}]);

    await solve(who.studentId, children[0].puzzleIds[0]);
    assert.equal(await completedAt(parentId), null, 'one item of two');
    assert.deepEqual(await notices(who.trainerId), [], 'an item tells nobody on its own');

    await solve(who.studentId, children[1].puzzleIds[0]);
    assert.ok(await completedAt(parentId));
    const told = await notices(who.trainerId);
    assert.equal(told.length, 1);
    assert.equal(told[0].ref_id, parentId);
    assert.equal(told[0].title, 'Homework completed');

    // Asked again, nothing more happens.
    await assignments.markCompleteIfDone(pool, children[1].id);
    await homework.markHomeworkCompleteIfDone(pool, parentId);
    assert.equal((await notices(who.trainerId)).length, 1);
  });

  test('a homework with no items never completes by itself', async () => {
    const who = await people();
    const empty = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, 'empty', 'homework') RETURNING id`,
      [who.trainerId, who.studentId]
    );
    const id = empty.rows[0].id;
    assert.equal(await assignments.markCompleteIfDone(pool, id), null);
    assert.equal(await homework.markHomeworkCompleteIfDone(pool, id), null);
    assert.equal(await completedAt(id), null);
  });

  test('an ordinary assignment still completes and notifies as before', async () => {
    const who = await people();
    const plain = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, 'plain', 'puzzles') RETURNING id`,
      [who.trainerId, who.studentId]
    );
    const id = plain.rows[0].id;
    const puzzleId = `plain${who.tag}`;
    await pool.query(
      'INSERT INTO assignment_items (assignment_id, puzzle_id, position) VALUES ($1, $2, 0)',
      [id, puzzleId]
    );
    await solve(who.studentId, puzzleId);
    assert.ok(await completedAt(id));
    assert.equal((await notices(who.trainerId)).length, 1);
  });

  // The owner, 20.9.2026: he solved an exercise sent to him directly and found
  // it done inside a homework he had never opened. It is the rule, and it was
  // pinned nowhere: an answer is recorded by student and puzzle, not by the
  // assignment it arrived through. The reason is stronger than convenience — a
  // one-move exercise gives up its solution once it is answered, so a second
  // copy of the same position is a question that can no longer be failed.
  test('one answer marks every open copy of that position for that student, once, and no one else\'s', async () => {
    const who = await people();
    const other = await people();
    const puzzleId = `same${who.tag}`;

    async function direct(person, title) {
      const a = await pool.query(
        `INSERT INTO assignments (trainer_id, student_id, title, kind)
         VALUES ($1, $2, $3, 'puzzles') RETURNING id`,
        [who.trainerId, person.studentId, title]
      );
      await pool.query(
        'INSERT INTO assignment_items (assignment_id, puzzle_id, position) VALUES ($1, $2, 0)',
        [a.rows[0].id, puzzleId]
      );
      return a.rows[0].id;
    }
    async function repoint(childId) {
      await pool.query('UPDATE assignment_items SET puzzle_id = $1 WHERE assignment_id = $2', [puzzleId, childId]);
    }
    async function item(assignmentId) {
      const r = await pool.query(
        'SELECT solved, attempted_at FROM assignment_items WHERE assignment_id = $1', [assignmentId]
      );
      return r.rows[0];
    }

    const directId = await direct(who, 'sent directly');
    // The same position inside a homework — open, its only item…
    const open = await sent(who, [{}]);
    await repoint(open.children[0].id);
    // …and inside another, behind a gate nobody has passed.
    const gated = await sent(who, [{}, { gate: true }]);
    await repoint(gated.children[1].id);
    // Somebody else has it too.
    const theirs = await direct(other, 'another student');

    // Answered once, wrongly, through no assignment in particular.
    assert.equal(await solve(who.studentId, puzzleId, false), 2, 'the direct one and the open homework item');

    assert.equal((await item(directId)).solved, false);
    assert.equal((await item(open.children[0].id)).solved, false, 'the copy he never opened has the same verdict');
    assert.ok(await completedAt(directId));
    assert.ok(await completedAt(open.parentId), 'and the homework it was the last item of is complete');

    assert.equal((await item(gated.children[1].id)).attempted_at, null, 'a locked copy is left for when it opens');
    assert.equal((await item(theirs)).attempted_at, null, 'another student\'s copy is theirs to answer');

    // A second answer — the right one this time — changes nothing already said.
    assert.equal(await solve(who.studentId, puzzleId, true), 0);
    assert.equal((await item(directId)).solved, false, 'the first verdict is the one the report keeps');
    assert.equal((await item(open.children[0].id)).solved, false);
  });

  // ---- the readers see one homework, not its pieces -----------------------

  test('lists and the trainer panel show the homework once, with its progress', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, {}, {}]);
    await solve(who.studentId, children[0].puzzleIds[0]);
    await solve(who.studentId, children[1].puzzleIds[0]);

    // The homework opened says the same two numbers the list says, to both
    // readers — asked at two of three, where neither number can be a constant
    // or the other one. It said neither until 19.9.2026, and the screen read
    // the absence as „0 of 0 items".
    const listed = (await assignments.getStudentAssignments(pool, who.studentId))[0];
    assert.equal(listed.child_total, 3);
    assert.equal(listed.child_completed, 2);
    for (const reader of [who.studentId, who.trainerId]) {
      const opened = await assignments.getAssignmentDetail(pool, parentId, reader);
      assert.equal(opened.child_total, listed.child_total);
      assert.equal(opened.child_completed, listed.child_completed);
    }

    await solve(who.studentId, children[2].puzzleIds[0]);

    const mine = await assignments.getStudentAssignments(pool, who.studentId);
    assert.deepEqual(mine.map((a) => a.id), [parentId]);
    assert.equal(mine[0].child_total, 3);
    assert.equal(mine[0].child_completed, 3);

    const given = await assignments.getTrainerAssignments(pool, who.trainerId);
    assert.deepEqual(given.map((a) => a.id), [parentId]);

    const { awaitingReview } = require('../services/trainerPanelService');
    const waiting = await awaitingReview(pool, who.trainerId);
    assert.deepEqual(waiting.map((a) => a.id), [parentId], 'three finished items are not three reviews');

    const progress = await assignments.getStudentProgress(pool, who.studentId, { days: 30 });
    assert.deepEqual(progress.assignments, { total: 1, completed: 1, overdue: 0 },
      'a parent report counts one homework, not four assignments');
  });
  // ---- the routes: the gate holds before anything is judged or revealed ---

  /// Runs a real handler from routes/assignments.js as [userId], with the
  /// route module's pool pointed at this test's database for the call.
  async function route(method, path, { userId, params = {}, body = {} }) {
    const dbModule = require('../db');
    const router = require('../routes/assignments');
    const layer = router.stack.find(
      (l) => l.route && l.route.path === path && l.route.methods[method]
    );
    assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
    const handlers = layer.route.stack.map((x) => x.handle);
    const handler = handlers[handlers.length - 1];

    const original = dbModule.pool.query;
    dbModule.pool.query = (text, values) => pool.query(text, values);
    const answered = { status: 200, body: null };
    const res = {
      status(code) { answered.status = code; return this; },
      json(payload) { answered.body = payload; return this; },
      send() { return this; },
    };
    try {
      await handler({ user: { id: userId }, params, query: {}, body, headers: {} }, res);
    } finally {
      dbModule.pool.query = original;
    }
    return answered;
  }

  test('a locked position is refused before it is judged: no verdict, no solution, nothing written', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { gate: true }]);
    const puzzleId = `cust_${who.tag}`;
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, solution_san, origin)
       VALUES ($1, $2, '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'w', 'Rd8#', 'book')`,
      [puzzleId, who.trainerId]
    );
    await pool.query(
      'UPDATE assignment_items SET puzzle_id = $1 WHERE assignment_id = $2',
      [puzzleId, children[1].id]
    );

    const r = await route('post', '/:id/custom-attempt', {
      userId: who.studentId,
      params: { id: String(children[1].id) },
      body: { puzzleId, moveSan: 'Rd8#', msTaken: 900 },
    });
    assert.equal(r.status, 423);
    assert.equal(r.body.blockedBy, children[0].id);
    assert.equal('solutionSan' in r.body, false, 'the answer must not travel');
    assert.equal('correct' in r.body, false, 'nor the verdict');
    const item = await pool.query(
      'SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [children[1].id]
    );
    assert.equal(item.rows[0].attempted_at, null);

    // The control: opened, the same request is judged.
    await homework.openGate(pool, { assignmentId: children[1].id, trainerId: who.trainerId });
    const opened = await route('post', '/:id/custom-attempt', {
      userId: who.studentId,
      params: { id: String(children[1].id) },
      body: { puzzleId, moveSan: 'Rd8#', msTaken: 900 },
    });
    assert.equal(opened.status, 200);
    assert.equal(opened.body.correct, true);
  });

  test('an answer is judged by what the exercise stores, not by the printed move beside it', async () => {
    // `docs/PLAN-EXERCISE.md` phase 1: the route reads the row through
    // `exerciseOf`. The printed move here is deliberately NOT the stored main
    // move, so a route that still read `solution_san` answers differently on
    // every assertion below.
    const who = await people();
    const { children } = await sent(who, [{ puzzles: 3 }]);
    const asked = [];
    for (const [index, itemId] of children[0].puzzleIds.entries()) {
      const puzzleId = `cust_${who.tag}_ex${index}`;
      asked.push(puzzleId);
      await pool.query(
        `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, solution_san, solution, origin)
         VALUES ($1, $2, '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'w', 'Re1', $3, 'manual')`,
        [puzzleId, who.trainerId, JSON.stringify([{ accept: ['Rd8#', 'Kf1'] }])]
      );
      await pool.query(
        'UPDATE assignment_items SET puzzle_id = $1 WHERE assignment_id = $2 AND puzzle_id = $3',
        [puzzleId, children[0].id, itemId]
      );
    }
    const attempt = (puzzleId, moveSan) => route('post', '/:id/custom-attempt', {
      userId: who.studentId,
      params: { id: String(children[0].id) },
      body: { puzzleId, moveSan, msTaken: 500 },
    });

    const alternative = await attempt(asked[0], 'Kf1');
    assert.equal(alternative.status, 200);
    assert.equal(alternative.body.correct, true);
    assert.equal(alternative.body.reason, 'another correct move');
    assert.equal(alternative.body.solutionSan, 'Rd8#', 'the stored main move is what is revealed');

    const main = await attempt(asked[1], 'Rd8');
    assert.equal(main.body.correct, true);

    // The printed move is just a move now.
    const printed = await attempt(asked[2], 'Re1');
    assert.equal(printed.body.correct, false);
    assert.equal('retry' in printed.body, false, 'nothing is tried again: the word left the wire');
    assert.equal(printed.body.solutionSan, 'Rd8#');

    const review = await route('get', '/:id/review', {
      userId: who.trainerId, params: { id: String(children[0].id) },
    });
    assert.equal(review.status, 200);
    const shown = review.body.items.filter((item) => asked.includes(item.puzzleId));
    assert.equal(shown.length, 3);
    for (const item of shown) assert.equal(item.solutionSan, 'Rd8#');
  });

  // ---- a hand-made find exercise: one move (PLAN-EXERCISE.md, 14 and 16) ---

  /// A homework whose first item is one hand-made exercise holding [steps],
  /// and whose second item waits behind it.
  async function sentExercise(who, steps) {
    const fixture = require('../../docs/gates/exercise_line_cases.json');
    const { parentId, children } = await sent(who, [{ puzzles: 1 }, { gate: true }]);
    const puzzleId = `ex_${who.tag}_${Math.random().toString(36).slice(2, 8)}`;
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, task, solution, origin)
       VALUES ($1, $2, $3, 'w', '{"type":"find"}', $4, 'manual')`,
      [puzzleId, who.trainerId, fixture.positions.scholar,
        JSON.stringify(steps || fixture.solutions.scholarFirst.steps)]
    );
    await pool.query(
      'UPDATE assignment_items SET puzzle_id = $1 WHERE assignment_id = $2',
      [puzzleId, children[0].id]
    );
    const answer = (body) => route('post', '/:id/custom-attempt', {
      userId: who.studentId,
      params: { id: String(children[0].id) },
      body: { puzzleId, msTaken: 700, ...body },
    });
    const item = async () => (await pool.query(
      'SELECT attempted_at, solved, played_san FROM assignment_items WHERE assignment_id = $1',
      [children[0].id]
    )).rows[0];
    return { parentId, answer, item };
  }

  test('an accepted alternative is right, is written at once, and the answer says four things', async () => {
    const who = await people();
    const { parentId, answer, item } = await sentExercise(who);

    const r = await answer({ moveSan: 'Qf3' });
    assert.equal(r.status, 200);
    // The whole wire: nothing of the line machinery travels any more. Since
    // docs/PLAN-ZAGONETKE-IZ-PARTIJE.md phase 2 it carries the puzzle's review
    // too, released with the answer — null for an exercise that has none.
    assert.deepEqual(r.body, {
      correct: true, reason: 'another correct move', playedSan: 'Qf3', solutionSan: 'Qh5', review: null,
    });
    const written = await item();
    assert.notEqual(written.attempted_at, null);
    assert.equal(written.solved, true);
    assert.equal(written.played_san, 'Qf3');
    assert.deepEqual(await states(parentId), ['passed', 'open']);
  });

  test('a wrong answer is final: it is shown the solution, and a second answer changes nothing', async () => {
    const who = await people();
    const { parentId, answer, item } = await sentExercise(who);

    const wrong = await answer({ moveSan: 'd4' });
    assert.equal(wrong.body.correct, false);
    assert.equal(wrong.body.solutionSan, 'Qh5');
    const first = await item();
    assert.equal(first.solved, false);
    assert.equal(first.played_san, 'd4');
    // Attempted is done, for a gate that did not ask for solved.
    assert.deepEqual(await states(parentId), ['passed', 'open']);

    const again = await answer({ moveSan: 'Qh5' });
    assert.equal(again.body.correct, true);
    const after = await item();
    assert.equal(after.solved, false, 'the first verdict stands');
    assert.equal(after.played_san, 'd4');
    assert.deepEqual(after.attempted_at, first.attempted_at);
  });

  test('a row that still holds a line is not judged on its first move', async () => {
    const who = await people();
    const { answer } = await sentExercise(who, [{ accept: ['Qh5'] }, { accept: ['Qxe5+'] }]);
    const r = await answer({ moveSan: 'Qh5' });
    assert.equal(r.body.correct, false, 'the first move of a line is not the answer to anything');
    assert.match(r.body.reason, /solution is missing/);
    assert.equal(r.body.solutionSan, null);
  });

  test('an answer that is not one move is refused before anything is read', async () => {
    const who = await people();
    const { answer, item } = await sentExercise(who);
    for (const bad of [{ moves: ['Qh5'] }, { moveSan: ['Qh5'] }, { moveSan: null }, {}]) {
      const r = await answer(bad);
      assert.equal(r.status, 400, JSON.stringify(bad));
    }
    assert.equal((await item()).attempted_at, null);
  });

  test('a locked film is refused on every student route, its link included', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { video: true, gate: true }]);
    for (const path of ['/:id', '/:id/review', '/:id/video']) {
      const r = await route('get', path, { userId: who.studentId, params: { id: String(children[1].id) } });
      assert.equal(r.status, 423, path);
    }
  });

  test('the trainer reads a locked item and cannot withdraw it alone', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, { gate: true }]);
    const read = await route('get', '/:id', { userId: who.trainerId, params: { id: String(children[1].id) } });
    assert.equal(read.status, 200);
    assert.equal(read.body.id, children[1].id);
    // The review goes through the same guard as the student's routes; the gate
    // is the student's, and a trainer refused here could not see the work.
    const review = await route('get', '/:id/review', {
      userId: who.trainerId, params: { id: String(children[1].id) },
    });
    assert.notEqual(review.status, 423);

    const parent = await route('get', '/:id', { userId: who.studentId, params: { id: String(parentId) } });
    assert.equal(parent.status, 200);
    assert.deepEqual(parent.body.children.map((c) => c.locked), [false, true]);

    const alone = await route('delete', '/:id', { userId: who.trainerId, params: { id: String(children[0].id) } });
    assert.equal(alone.status, 409);
    const whole = await route('delete', '/:id', { userId: who.trainerId, params: { id: String(parentId) } });
    assert.equal(whole.status, 200);
  });

  // ---- „play it out", recorded from the moves (phase 2) ------------------

  /// A sent engine_game item: one assignment with a task and one item to hold
  /// the game, as phase 4 will write it.
  async function sentGame({ trainerId, studentId }, task, { gate = false } = {}) {
    const parent = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, 'Thursday', 'homework') RETURNING id`,
      [trainerId, studentId]
    );
    const parentId = parent.rows[0].id;
    const ids = [];
    for (const [index, entry] of [{ kind: 'puzzles' }, { kind: 'engine_game', task }].entries()) {
      const child = await pool.query(
        `INSERT INTO assignments
           (trainer_id, student_id, title, kind, parent_id, position, item_key, gate, task)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
        [trainerId, studentId, `item ${index}`, entry.kind, parentId, index, `k${index}`,
          index === 1 ? gate : false, entry.task ? JSON.stringify(entry.task) : null]
      );
      const id = child.rows[0].id;
      ids.push(id);
      await pool.query(
        'INSERT INTO assignment_items (assignment_id, position) VALUES ($1, 0)',
        [id]
      );
    }
    return { parentId, gameId: ids[1] };
  }

  const HOLD_TASK = {
    fen: '7k/8/6K1/8/8/8/8/5Q2 w - - 0 1',
    side: 'w',
    goal: 'hold',
    level: 'srednje',
    thinkSeconds: 2,
    plyCap: 40,
  };

  test('a finished game is judged from its moves and recorded', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, HOLD_TASK);

    const r = await route('post', '/:id/game-result', {
      userId: who.studentId,
      params: { id: String(gameId) },
      body: { moves: ['Qf7'] },
    });
    assert.equal(r.status, 200);
    assert.deepEqual(
      { goalMet: r.body.goalMet, ending: r.body.ending, outcome: r.body.outcome },
      { goalMet: true, ending: 'stalemate', outcome: 'drawn' }
    );

    const item = await pool.query(
      'SELECT solved, game_moves, game_ending, attempted_at FROM assignment_items WHERE assignment_id = $1',
      [gameId]
    );
    assert.equal(item.rows[0].solved, true);
    assert.equal(item.rows[0].game_moves, 'Qf7');
    assert.equal(item.rows[0].game_ending, 'stalemate');
    assert.ok(item.rows[0].attempted_at, 'the item counts as attempted');
    assert.ok(await completedAt(gameId), 'its one item is done, so the item is');
  });

  test('a game the student lost is recorded as not met, and still counts as done', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, { ...HOLD_TASK, goal: 'win' });
    const r = await route('post', '/:id/game-result', {
      userId: who.studentId, params: { id: String(gameId) }, body: { moves: ['Qf7'] },
    });
    assert.equal(r.body.goalMet, false, 'a draw is not a win');
    const item = await pool.query(
      'SELECT solved FROM assignment_items WHERE assignment_id = $1', [gameId]
    );
    assert.equal(item.rows[0].solved, false);
    assert.ok(await completedAt(gameId));
  });

  test('an unfinished game, an impossible move and a second attempt are all refused', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, HOLD_TASK);

    const running = await route('post', '/:id/game-result', {
      userId: who.studentId, params: { id: String(gameId) }, body: { moves: ['Qf2'] },
    });
    assert.equal(running.status, 422);
    assert.match(running.body.error, /not over/);

    const illegal = await route('post', '/:id/game-result', {
      userId: who.studentId, params: { id: String(gameId) }, body: { moves: ['Qd8'] },
    });
    assert.equal(illegal.status, 422);

    const nothing = await pool.query(
      'SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [gameId]
    );
    assert.equal(nothing.rows[0].attempted_at, null, 'neither refusal wrote anything');

    const done = await route('post', '/:id/game-result', {
      userId: who.studentId, params: { id: String(gameId) }, body: { moves: ['Qf7'] },
    });
    assert.equal(done.status, 200);
    const again = await route('post', '/:id/game-result', {
      userId: who.studentId, params: { id: String(gameId) }, body: { moves: ['Qf7'] },
    });
    assert.equal(again.status, 409, 'only the first attempt counts');
  });

  test("a game is not somebody else's to play, and a locked one is not played at all", async () => {
    const who = await people();
    const { gameId } = await sentGame(who, HOLD_TASK, { gate: true });

    const locked = await route('post', '/:id/game-result', {
      userId: who.studentId, params: { id: String(gameId) }, body: { moves: ['Qf7'] },
    });
    assert.equal(locked.status, 423);

    // On an **open** game, so it is ownership refusing and not the lock: with
    // the lock in front, a mutation that let anyone play survived this test.
    const other = await people();
    const open = await sentGame(other, HOLD_TASK);
    const asTrainer = await route('post', '/:id/game-result', {
      userId: other.trainerId, params: { id: String(open.gameId) }, body: { moves: ['Qf7'] },
    });
    assert.equal(asTrainer.status, 404, 'the trainer does not answer their own homework');
    const untouched = await pool.query(
      'SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [open.gameId]
    );
    assert.equal(untouched.rows[0].attempted_at, null);

    const item = await pool.query(
      'SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [gameId]
    );
    assert.equal(item.rows[0].attempted_at, null);

    // Straight at the service, past the route's guard: the write has its own,
    // because a check made only in the route is a check one caller can miss.
    const direct = await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: ['Qf7'],
    });
    assert.equal(direct.ok, false);
    assert.equal(direct.status, 404);
    const still = await pool.query(
      'SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [gameId]
    );
    assert.equal(still.rows[0].attempted_at, null);
  });

  test('the student is given the task, and the engine it must be played against', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, HOLD_TASK);
    const detail = await assignments.getAssignmentDetail(pool, gameId, who.studentId);
    assert.equal(detail.kind, 'engine_game');
    assert.deepEqual(detail.task, HOLD_TASK);
  });

  test('only the trainer opens a gate through the route', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { gate: true }]);
    const params = { id: String(children[1].id) };
    assert.equal((await route('post', '/:id/open-gate', { userId: who.studentId, params })).status, 404);
    assert.equal((await route('post', '/:id/open-gate', { userId: who.trainerId, params })).status, 200);
    assert.equal((await route('get', '/:id', { userId: who.studentId, params })).status, 200);
  });

  // ---- „for N moves", judged by the position reached (PLAN-EXERCISE 3a) ----

  const fm = require('../../docs/gates/engine_game_cases.json').forMoves;
  const { pieceCount } = require('../services/engineGameTask');
  // A draw held for two moves as Black, king and pawn: it stops at its move
  // target with three pieces on, so a tablebase says what was reached. Until
  // 19.9.2026 this was the fixture's „win kept for two moves"; a win with a
  // number is now „checkmate in N moves", which the rules judge alone. Found
  // by what it is, not by where it stands in the list. The tablebase's word is
  // for the side to move in the position reached — White, the engine.
  const HELD = fm.judged.find((c) => c.task.goal === 'hold' && c.expect.needsTablebase);
  const MATE_MISSED = fm.judged.find((c) => c.task.goal === 'win'
    && c.expect.ending === 'moveTarget' && pieceCount(c.expect.fen) <= 7);
  const { createTablebase } = require('../services/tablebaseService');

  /// A tablebase **client** with a fake network under it — the real probe, the
  /// real cache, the real error mapping — that remembers what it was asked.
  function tablebaseAnswering(category, { down = false } = {}) {
    const asked = [];
    const tablebase = createTablebase({
      retries: 0,
      minGapMs: 0,
      sleep: async () => {},
      fetchImpl: async (url) => {
        asked.push(String(url));
        if (down) throw new Error('network down');
        return { ok: true, status: 200, json: async () => ({ category, moves: [] }) };
      },
    });
    return { tablebase, asked };
  }

  const gameItem = async (gameId) => (await pool.query(
    'SELECT solved, judged_by, game_ending, attempted_at FROM assignment_items WHERE assignment_id = $1',
    [gameId]
  )).rows[0];

  test('a draw held for N moves is judged by the tablebase, asked about the position reached', async () => {
    for (const [category, met] of [['draw', true], ['win', false]]) {
      const who = await people();
      const { gameId } = await sentGame(who, HELD.task);
      const { tablebase, asked } = tablebaseAnswering(category);

      const r = await assignments.recordEngineGameResult(pool, {
        studentId: who.studentId, assignmentId: gameId, moves: HELD.moves, tablebase,
      });
      assert.equal(r.ok, true, r.error);
      assert.deepEqual(
        { goalMet: r.goalMet, judgedBy: r.judgedBy, pending: r.pending, ending: r.ending },
        { goalMet: met, judgedBy: 'tablebase', pending: false, ending: 'moveTarget' }
      );
      assert.equal(asked.length, 1);
      assert.ok(
        asked[0].includes(encodeURIComponent(HELD.expect.fen)),
        `asked about the final position, not the first: ${asked[0]}`
      );
      const item = await gameItem(gameId);
      assert.equal(item.solved, met);
      assert.equal(item.judged_by, 'tablebase');
    }
  });

  test('a tablebase that does not answer leaves the game played, not judged — and a later read judges it', async () => {
    const who = await people();
    const { parentId, gameId } = await sentGame(who, HELD.task);

    const r = await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: HELD.moves,
      tablebase: tablebaseAnswering('draw', { down: true }).tablebase,
    });
    assert.equal(r.ok, true, r.error);
    assert.deepEqual({ goalMet: r.goalMet, judgedBy: r.judgedBy, pending: r.pending },
      { goalMet: null, judgedBy: null, pending: true });

    const waiting = await gameItem(gameId);
    assert.ok(waiting.attempted_at, 'played');
    assert.equal(waiting.solved, null, 'not failed: not judged');
    assert.equal(waiting.judged_by, null);
    assert.ok(await completedAt(gameId), 'attempted is done, for the gate and for completion');
    const before = (await homework.childrenOf(pool, parentId)).find((c) => c.id === gameId);
    assert.deepEqual({ pending: before.pending_items, solved: before.solved_items }, { pending: 1, solved: 0 });

    // Still down on the next read: the homework opens all the same, unchanged.
    const stillDown = await assignments.getAssignmentDetail(pool, parentId, who.studentId, {
      tablebase: tablebaseAnswering('draw', { down: true }).tablebase,
    });
    assert.equal(stillDown.children.find((c) => c.id === gameId).pending_items, 1);

    // Back up: either side's read judges it.
    const { tablebase, asked } = tablebaseAnswering('draw');
    const read = await assignments.getAssignmentDetail(pool, parentId, who.trainerId, { tablebase });
    const after = read.children.find((c) => c.id === gameId);
    assert.deepEqual({ pending: after.pending_items, solved: after.solved_items }, { pending: 0, solved: 1 });
    assert.ok(asked[0].includes(encodeURIComponent(HELD.expect.fen)));
    assert.equal((await gameItem(gameId)).judged_by, 'tablebase');

    // And it is asked once: a judged game is not asked about again.
    const again = tablebaseAnswering('win');
    await assignments.getAssignmentDetail(pool, parentId, who.studentId, { tablebase: again.tablebase });
    assert.equal(again.asked.length, 0);
    assert.equal((await gameItem(gameId)).solved, true);
  });

  test('a blocked tablebase is not queued behind: the game waits', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, HELD.task);
    const r = await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: HELD.moves,
      tablebase: { blockedForMs: () => 40000, probe: async () => { throw new Error('must not be asked'); } },
    });
    assert.equal(r.pending, true);
  });

  test('a fault is not „no answer": recording fails loudly and writes nothing, reading still reads', async () => {
    const who = await people();
    const { parentId, gameId } = await sentGame(who, HELD.task);
    const broken = { blockedForMs: () => 0, probe: async () => { throw new TypeError('a bug, not the network'); } };

    await assert.rejects(
      assignments.recordEngineGameResult(pool, {
        studentId: who.studentId, assignmentId: gameId, moves: HELD.moves, tablebase: broken,
      }),
      TypeError
    );
    assert.equal((await gameItem(gameId)).attempted_at, null);

    await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: HELD.moves,
      tablebase: tablebaseAnswering('draw', { down: true }).tablebase,
    });
    const read = await assignments.getAssignmentDetail(pool, parentId, who.studentId, { tablebase: broken });
    assert.equal(read.children.length, 2, 'the asking cannot stop the reading');
    assert.equal(read.children.find((c) => c.id === gameId).pending_items, 1);
  });

  test('the review of a played game is the game: both sides read the moves, the end and the verdict', async () => {
    // Phase 9. The shaping is tested pure in `assignment_review.test.js`; this
    // is the half that can only fail here — the query naming the three
    // columns, and the task reaching the shaper off the assignment's own row.
    const { buildReview } = require('../services/assignmentReview');
    const who = await people();
    const { gameId } = await sentGame(who, MATE_MISSED.task);

    const unplayed = (await buildReview(pool, gameId, who.trainerId)).items;
    assert.equal(unplayed.length, 1);
    assert.deepEqual(
      { kind: unplayed[0].kind, moves: unplayed[0].moves, fen: unplayed[0].fen },
      { kind: 'game', moves: [], fen: MATE_MISSED.task.fen }
    );

    const r = await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: MATE_MISSED.moves,
      tablebase: tablebaseAnswering('loss').tablebase,
    });
    assert.equal(r.ok, true, r.error);

    for (const reader of [who.trainerId, who.studentId]) {
      const [item] = (await buildReview(pool, gameId, reader)).items;
      assert.deepEqual(
        {
          kind: item.kind, moves: item.moves, finalFen: item.finalFen, ending: item.ending,
          judgedBy: item.judgedBy, solved: item.solved, pending: item.pending, goal: item.task.goal,
          n: item.task.surviveMoves,
        },
        {
          kind: 'game', moves: MATE_MISSED.moves, finalFen: MATE_MISSED.expect.fen, ending: 'moveTarget',
          judgedBy: 'rules', solved: false, pending: false, goal: 'win',
          n: MATE_MISSED.task.surviveMoves,
        }
      );
    }
  });

  test('the rules judge what no tablebase is needed for, and nobody is asked', async () => {
    const big = fm.judged.find((c) => c.task.goal === 'hold'
      && c.expect.ending === 'moveTarget' && !c.expect.needsTablebase);
    const mate = fm.judged.find((c) => c.expect.ending === 'checkmate');
    // The third is the one the old rule got wrong: three pieces, still won,
    // and a tablebase standing by that would say so — „checkmate in two" is
    // missed all the same, by the rules, and nobody is asked.
    assert.equal(MATE_MISSED.expect.goalMet, false);
    for (const c of [big, mate, MATE_MISSED]) {
      const who = await people();
      const { gameId } = await sentGame(who, c.task);
      const { tablebase, asked } = tablebaseAnswering('loss');
      const r = await assignments.recordEngineGameResult(pool, {
        studentId: who.studentId, assignmentId: gameId, moves: c.moves, tablebase,
      });
      assert.equal(r.ok, true, r.error);
      assert.deepEqual({ goalMet: r.goalMet, judgedBy: r.judgedBy, pending: r.pending },
        { goalMet: c.expect.goalMet, judgedBy: 'rules', pending: false }, c.name);
      assert.equal(asked.length, 0, c.name);
    }
  });

  test('judged_by is one of four words, or nothing', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, HELD.task);
    await assert.rejects(
      pool.query(`UPDATE assignment_items SET judged_by = 'guess' WHERE assignment_id = $1`, [gameId]),
      (err) => err.code === '23514'
    );
    // The fourth, since phase 15 of PLAN-EXERCISE: the trainer.
    await pool.query(`UPDATE assignment_items SET judged_by = 'trainer' WHERE assignment_id = $1`, [gameId]);
  });

  // ---- „Play N moves": no goal, the trainer judges (PLAN-EXERCISE 15) ------

  const play = require('../../docs/gates/engine_game_cases.json').play;
  const PLAYED = play.judged.find((c) => c.expect.ending === 'moveTarget' && c.task.side === 'w');
  const MATED = play.judged.find((c) => c.expect.ending === 'checkmate');

  /// The edge that makes a trainer a trainer: `people()` mints two strangers.
  const teaches = ({ trainerId, studentId }, status = 'accepted') => pool.query(
    `INSERT INTO trainer_students (trainer_id, student_id, status) VALUES ($1, $2, $3)`,
    [trainerId, studentId, status]
  );
  const verdict = (userId, gameId, body) => route('post', '/:id/game-verdict', {
    userId, params: { id: String(gameId) }, body,
  });

  test('a played game with no goal waits for the trainer — and no tablebase is asked, then or later', async () => {
    assert.ok(pieceCount(PLAYED.task.fen) <= 7, 'a tablebase would answer here: that is the point');
    for (const c of [PLAYED, MATED]) {
      const who = await people();
      const { parentId, gameId } = await sentGame(who, c.task);
      const { tablebase, asked } = tablebaseAnswering('win');

      const r = await assignments.recordEngineGameResult(pool, {
        studentId: who.studentId, assignmentId: gameId, moves: c.moves, tablebase,
      });
      assert.equal(r.ok, true, r.error);
      assert.deepEqual(
        { goalMet: r.goalMet, judgedBy: r.judgedBy, pending: r.pending, ending: r.ending },
        { goalMet: null, judgedBy: null, pending: true, ending: c.expect.ending },
        c.name
      );
      const item = await gameItem(gameId);
      assert.ok(item.attempted_at, 'played');
      assert.equal(item.solved, null);
      assert.equal(item.judged_by, null);
      assert.ok(await completedAt(gameId), 'played is done, for the gate and for completion');

      // A read by either side asks again for what waits on a tablebase. This
      // does not: it waits on a person.
      for (const reader of [who.studentId, who.trainerId]) {
        const detail = await assignments.getAssignmentDetail(pool, parentId, reader, { tablebase });
        assert.equal(detail.children.find((k) => k.id === gameId).pending_items, 1, c.name);
      }
      assert.equal(asked.length, 0, `${c.name}: nobody is asked`);
      assert.equal((await gameItem(gameId)).judged_by, null);
    }
  });

  test('the trainer gives the verdict, and may change it', async () => {
    const who = await people();
    await teaches(who);
    const { parentId, gameId } = await sentGame(who, PLAYED.task);
    await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: PLAYED.moves,
      tablebase: tablebaseAnswering('win').tablebase,
    });

    const said = await verdict(who.trainerId, gameId, { met: true });
    assert.equal(said.status, 200, JSON.stringify(said.body));
    assert.deepEqual(said.body, { goalMet: true, judgedBy: 'trainer', pending: false });
    let item = await gameItem(gameId);
    assert.deepEqual({ solved: item.solved, judged_by: item.judged_by }, { solved: true, judged_by: 'trainer' });
    const child = (await homework.childrenOf(pool, parentId)).find((k) => k.id === gameId);
    assert.deepEqual({ pending: child.pending_items, solved: child.solved_items }, { pending: 0, solved: 1 });

    // A second look: the trainer's own word is the trainer's to change.
    assert.equal((await verdict(who.trainerId, gameId, { met: false })).status, 200);
    item = await gameItem(gameId);
    assert.deepEqual({ solved: item.solved, judged_by: item.judged_by }, { solved: false, judged_by: 'trainer' });
  });

  test('only the trainer of this student, only with a verdict, only on a game that was played', async () => {
    const who = await people();
    const { gameId } = await sentGame(who, PLAYED.task);
    const record = () => assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: PLAYED.moves,
      tablebase: tablebaseAnswering('win').tablebase,
    });

    // Not played yet: there is nothing to judge.
    await teaches(who);
    assert.equal((await verdict(who.trainerId, gameId, { met: true })).status, 404);
    await record();

    // A request that was never answered grants nothing — the rule every
    // trainer's right is read through (`trainerOwnsStudent`).
    await pool.query(
      `UPDATE trainer_students SET status = 'pending' WHERE trainer_id = $1 AND student_id = $2`,
      [who.trainerId, who.studentId]
    );
    assert.equal((await verdict(who.trainerId, gameId, { met: true })).status, 404);
    await pool.query(
      `UPDATE trainer_students SET status = 'accepted' WHERE trainer_id = $1 AND student_id = $2`,
      [who.trainerId, who.studentId]
    );

    // The student does not mark their own work, and neither does somebody
    // else who happens to teach them.
    assert.equal((await verdict(who.studentId, gameId, { met: true })).status, 404);
    const other = await people();
    await teaches({ trainerId: other.trainerId, studentId: who.studentId });
    assert.equal((await verdict(other.trainerId, gameId, { met: true })).status, 404);

    // „met" is a yes or a no: absence is not a no.
    for (const body of [{}, { met: 'yes' }, { met: null }, { met: 1 }]) {
      assert.equal((await verdict(who.trainerId, gameId, body)).status, 400, JSON.stringify(body));
    }
    assert.equal((await gameItem(gameId)).judged_by, null, 'nothing above wrote anything');

    assert.equal((await verdict(who.trainerId, gameId, { met: false })).status, 200);
  });

  test('a verdict the rules or the tablebase gave is not for the trainer to overrule', async () => {
    for (const [c, category, by] of [[MATE_MISSED, 'loss', 'rules'], [HELD, 'draw', 'tablebase']]) {
      const who = await people();
      await teaches(who);
      const { gameId } = await sentGame(who, c.task);
      const r = await assignments.recordEngineGameResult(pool, {
        studentId: who.studentId, assignmentId: gameId, moves: c.moves,
        tablebase: tablebaseAnswering(category).tablebase,
      });
      assert.equal(r.judgedBy, by);
      const before = await gameItem(gameId);
      assert.equal((await verdict(who.trainerId, gameId, { met: !before.solved })).status, 409, by);
      const after = await gameItem(gameId);
      assert.deepEqual({ solved: after.solved, judged_by: after.judged_by },
        { solved: before.solved, judged_by: by });
    }
  });

  test('a game the tablebase never answered is the trainer to judge too — the judge of last resort', async () => {
    const who = await people();
    await teaches(who);
    const { gameId } = await sentGame(who, HELD.task);
    await assignments.recordEngineGameResult(pool, {
      studentId: who.studentId, assignmentId: gameId, moves: HELD.moves,
      tablebase: tablebaseAnswering('draw', { down: true }).tablebase,
    });
    assert.equal((await verdict(who.trainerId, gameId, { met: true })).status, 200);
    const item = await gameItem(gameId);
    assert.deepEqual({ solved: item.solved, judged_by: item.judged_by }, { solved: true, judged_by: 'trainer' });
  });
});
