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
  /// item. Each child is a puzzle set of `puzzles` items or a lesson of `steps`.
  async function sent({ trainerId, studentId, tag }, items) {
    const parent = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, 'Thursday', 'homework') RETURNING id`,
      [trainerId, studentId]
    );
    const parentId = parent.rows[0].id;
    const children = [];
    for (const [index, item] of items.entries()) {
      const kind = item.steps ? 'lesson' : 'puzzles';
      const child = await pool.query(
        `INSERT INTO assignments
           (trainer_id, student_id, title, kind, parent_id, position, item_key, gate, require_solved)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
        [trainerId, studentId, `item ${index}`, kind, parentId, index * 10, `k${index}`,
          item.gate === true, item.requireSolved === true]
      );
      const id = child.rows[0].id;
      const puzzleIds = [];
      if (item.steps) {
        for (let step = 0; step < item.steps; step++) {
          await pool.query(
            `INSERT INTO assignment_items (assignment_id, position, step_key) VALUES ($1, $2, $3)`,
            [id, step, `s${step}`]
          );
        }
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

  test('„must be solved": a wrong answer keeps the next item locked', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{ requireSolved: true, puzzles: 2 }, { gate: true }]);
    await solve(who.studentId, children[0].puzzleIds[0], true);
    await solve(who.studentId, children[0].puzzleIds[1], false);

    assert.ok(await completedAt(children[0].id), 'attempted in full, so complete');
    assert.deepEqual(await states(parentId), ['open', 'locked'], 'complete is not passed');
  });

  test('„must be solved": a revealed step is not a solved one', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{ steps: 2, requireSolved: true }, { gate: true }]);
    await assignments.markLessonStepDone(pool, {
      studentId: who.studentId, assignmentId: children[0].id, position: 0,
    });
    await assignments.revealLessonStep(pool, {
      studentId: who.studentId, assignmentId: children[0].id, position: 1,
    });
    assert.ok(await completedAt(children[0].id));
    assert.deepEqual(await states(parentId), ['open', 'locked']);

    // And a read step — solved NULL — never fails it.
    const other = await people();
    const clean = await sent(other, [{ steps: 1, requireSolved: true }, { gate: true }]);
    await assignments.markLessonStepDone(pool, {
      studentId: other.studentId, assignmentId: clean.children[0].id, position: 0,
    });
    assert.deepEqual(await states(clean.parentId), ['passed', 'open']);
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

  test('a locked lesson step cannot be marked, answered or revealed', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { steps: 1, gate: true }]);
    const args = { studentId: who.studentId, assignmentId: children[1].id, position: 0 };
    assert.equal(await assignments.markLessonStepDone(pool, args), false);
    assert.equal(await assignments.recordLessonStepAnswer(pool, { ...args, correct: true }), false);
    assert.equal(await assignments.revealLessonStep(pool, args), false);
    const item = await pool.query(
      'SELECT attempted_at, revealed_at, solved FROM assignment_items WHERE assignment_id = $1',
      [children[1].id]
    );
    assert.deepEqual(item.rows[0], { attempted_at: null, revealed_at: null, solved: null });
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

  // ---- the readers see one homework, not its pieces -----------------------

  test('lists and the trainer panel show the homework once, with its progress', async () => {
    const who = await people();
    const { parentId, children } = await sent(who, [{}, {}, {}]);
    await solve(who.studentId, children[0].puzzleIds[0]);
    await solve(who.studentId, children[1].puzzleIds[0]);
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
        [puzzleId, who.trainerId, JSON.stringify([{ accept: ['Rd8#', 'Kf1'], reply: null }])]
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

    const review = await route('get', '/:id/review', {
      userId: who.trainerId, params: { id: String(children[0].id) },
    });
    assert.equal(review.status, 200);
    const shown = review.body.items.filter((item) => asked.includes(item.puzzleId));
    assert.equal(shown.length, 3);
    for (const item of shown) assert.equal(item.solutionSan, 'Rd8#');
  });

  // ---- a line: docs/PLAN-EXERCISE.md, phase 2a ----------------------------

  /// A homework whose first item is one exercise asking for the fixture's
  /// two-move line, and whose second item waits behind it.
  async function sentLine(who, { requireSolved = false } = {}) {
    const fixture = require('../../docs/gates/exercise_line_cases.json');
    const { parentId, children } = await sent(who, [{ puzzles: 1, requireSolved }, { gate: true }]);
    const puzzleId = `ex_${who.tag}_${Math.random().toString(36).slice(2, 8)}`;
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, task, solution, origin)
       VALUES ($1, $2, $3, 'w', '{"type":"find"}', $4, 'manual')`,
      [puzzleId, who.trainerId, fixture.positions.scholar, JSON.stringify(fixture.solutions.scholarLine.steps)]
    );
    await pool.query(
      'UPDATE assignment_items SET puzzle_id = $1 WHERE assignment_id = $2',
      [puzzleId, children[0].id]
    );
    const play = (moves) => route('post', '/:id/custom-attempt', {
      userId: who.studentId,
      params: { id: String(children[0].id) },
      body: { puzzleId, moves, msTaken: 700 },
    });
    const item = async () => (await pool.query(
      'SELECT attempted_at, solved, played_san FROM assignment_items WHERE assignment_id = $1',
      [children[0].id]
    )).rows[0];
    return { parentId, play, item };
  }

  test('a line gives up one reply at a time, and a line half played is not an attempt', async () => {
    const who = await people();
    const { parentId, play, item } = await sentLine(who);

    const first = await play(['Qf3']);
    assert.equal(first.status, 200);
    assert.equal(first.body.correct, true);
    assert.equal(first.body.done, false);
    assert.equal(first.body.reply, 'g6');
    assert.equal(first.body.continuesOn, 'Qh5', 'an accepted alternative goes on from the author\'s move');
    assert.equal(first.body.solutionSan, null);
    assert.equal(JSON.stringify(first.body).includes('Qxe5'), false, 'move two must not travel with move one');

    assert.equal((await item()).attempted_at, null, 'nothing is written in the middle of a line');
    assert.deepEqual(await states(parentId), ['open', 'locked'], 'and the gate behind it stays shut');

    const second = await play(['Qf3', 'Qxe5']);
    assert.equal(second.body.correct, true);
    assert.equal(second.body.done, true);
    assert.equal(second.body.reply, null);
    const written = await item();
    assert.notEqual(written.attempted_at, null);
    assert.equal(written.solved, true);
    assert.equal(written.played_san, 'Qxe5+');
    assert.deepEqual(await states(parentId), ['passed', 'open']);
  });

  test('a wrong move in a line may be tried again, and the report keeps the first verdict', async () => {
    const who = await people();
    const { parentId, play, item } = await sentLine(who);

    await play(['Qh5']);
    const wrong = await play(['Qh5', 'Qxh7']);
    assert.equal(wrong.body.correct, false);
    assert.equal(wrong.body.done, false);
    assert.equal(wrong.body.step, 1);
    assert.equal(wrong.body.reply, null);
    assert.equal(wrong.body.solutionSan, null, 'an answer shown is an answer no longer asked');
    assert.equal(JSON.stringify(wrong.body).includes('Qxe5'), false);
    const first = await item();
    assert.equal(first.solved, false);
    assert.equal(first.played_san, 'Qxh7');
    // Attempted is done, for a gate that did not ask for solved.
    assert.deepEqual(await states(parentId), ['passed', 'open']);

    const again = await play(['Qh5', 'Qxe5+']);
    assert.equal(again.body.correct, true);
    assert.equal(again.body.done, true);
    const after = await item();
    assert.equal(after.solved, false, 'the first verdict stands');
    assert.equal(after.played_san, 'Qxh7');
    assert.deepEqual(after.attempted_at, first.attempted_at);
  });

  test('measured for the owner: with "must be solved", one wrong move in a line locks what follows until the trainer opens it', async () => {
    // `docs/PLAN-EXERCISE.md` §8.3. Not a rule anybody chose for lines — the
    // consequence of two rules that were chosen: the first verdict is final,
    // and "done means solved" reads that verdict. Pinned so that changing
    // either one is a decision and shows up here.
    const who = await people();
    const { parentId, play } = await sentLine(who, { requireSolved: true });

    await play(['Qh5']);
    await play(['Qh5', 'Qxh7']);
    const finished = await play(['Qh5', 'Qxe5+']);
    assert.equal(finished.body.done, true, 'the student did finish the line, on the second try');
    assert.deepEqual(await states(parentId), ['open', 'locked']);
  });

  test('moves that are not moves are refused before anything is read', async () => {
    const who = await people();
    const { play, item } = await sentLine(who);
    for (const bad of [[1, 2], 'Qh5', [null]]) {
      const r = await play(bad);
      assert.equal(r.status, 400, JSON.stringify(bad));
    }
    assert.equal((await item()).attempted_at, null);
  });

  test('a locked lesson step is refused on every student route', async () => {
    const who = await people();
    const { children } = await sent(who, [{}, { steps: 1, gate: true }]);
    const params = { id: String(children[1].id), position: '0' };
    for (const path of ['/:id/step/:position', '/:id/step/:position/answer', '/:id/step/:position/reveal']) {
      const r = await route('post', path, { userId: who.studentId, params, body: { moveSan: 'e4' } });
      assert.equal(r.status, 423, path);
    }
    for (const path of ['/:id', '/:id/review']) {
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
        `INSERT INTO assignment_items (assignment_id, position, step_key) VALUES ($1, 0, 'game')`,
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
});
