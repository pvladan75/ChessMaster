// homework_send.test.js
//
// Phase 4 of docs/PLAN-DOMACI-ZADATAK.md: sending a homework. A real
// PostgreSQL, because the whole phase is one transaction and a set of rows
// that must all arrive together — a stub pool would accept a half-written
// homework without noticing.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const realtime = require('../services/realtime');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

realtime.init({ to: () => ({ emit: () => {} }) });

const skip = skipUnlessDatabase();

describe('sending a homework', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let template;
  let send;
  let homework;
  let assignments;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    template = require('../services/homeworkTemplate');
    send = require('../services/homeworkSend');
    homework = require('../services/homeworkService');
    assignments = require('../services/assignmentService');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function person(name) {
    minted++;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`s${process.pid}_${minted}@test.invalid`, name]
    );
    return r.rows[0].id;
  }

  /// A trainer with an accepted student — the only relationship that grants
  /// anything (`trainerOwnsStudent`).
  async function pair({ accepted = true } = {}) {
    const trainerId = await person('Trainer');
    const studentId = await person('Ana');
    await pool.query(
      `INSERT INTO trainer_students (trainer_id, student_id, status)
       VALUES ($1, $2, $3)`,
      [trainerId, studentId, accepted ? 'accepted' : 'pending']
    );
    return { trainerId, studentId };
  }

  async function lessonOf(trainerId, steps = 2) {
    const positionList = JSON.stringify(
      // Ids that are nothing like an index, on purpose: with `p0, p1, p2` a
      // key derived from the position is indistinguishable from the step's own
      // name, and a mutation that did exactly that survived this test once
      // (CLAUDE.md rule 6 — a fixture luckier than the real thing).
      Array.from({ length: steps }, (_, i) => ({
        id: `s${(i + 3) * 7}x`,
        title: `Step ${i + 1}`,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        pgn: '',
      }))
    );
    const r = await pool.query(
      `INSERT INTO saved_lessons (user_id, title, fen, pgn, position_list)
       VALUES ($1, 'Pins', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', '', $2::jsonb)
       RETURNING id`,
      [trainerId, positionList]
    );
    return r.rows[0].id;
  }

  async function positionOf(trainerId, { needsReview = false } = {}) {
    const id = `cust_${process.pid}_${minted}_${Math.random().toString(36).slice(2, 8)}`;
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, solution_san, needs_review, origin)
       VALUES ($1, $2, '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'w', 'Rd8#', $3, 'book')`,
      [id, trainerId, needsReview]
    );
    return id;
  }

  /// Lichess puzzles for a „puzzles" item to resolve against.
  async function lichessPuzzles(n = 3) {
    for (let i = 0; i < n; i++) {
      await pool.query(
        `INSERT INTO lichess_puzzles (puzzle_id, fen, moves, rating, themes)
         VALUES ($1, '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'd1d8', 1500, ARRAY['pin'])
         ON CONFLICT (puzzle_id) DO NOTHING`,
        [`lp${process.pid}_${minted}_${i}`]
      );
    }
  }

  const GAME_TASK = {
    fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
    side: 'w',
    goal: 'hold',
    level: 'lako',
    thinkSeconds: 2,
    plyCap: 40,
  };

  async function templateOf(trainerId, items, title = 'Thursday') {
    const saved = await template.saveHomework(pool, {
      trainerId,
      payload: { title, instructions: 'Read first, then solve.', items },
    });
    assert.equal(saved.ok, true, saved.error);
    return saved.homework;
  }

  async function countAll(studentId) {
    const r = await pool.query(
      `SELECT COUNT(*)::int AS n FROM assignments WHERE student_id = $1`,
      [studentId]
    );
    return r.rows[0].n;
  }

  // ---- the whole homework arrives -----------------------------------------

  test('every kind of item becomes an assignment of its own, in order, with its key', async () => {
    const { trainerId, studentId } = await pair();
    await lichessPuzzles();
    const lessonId = await lessonOf(trainerId, 3);
    const positionId = await positionOf(trainerId);
    const tpl = await templateOf(trainerId, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'positions', task: { puzzleIds: [positionId] }, gate: true },
      { kind: 'puzzles', task: { count: 2, themes: ['pin'] } },
      { kind: 'engine_game', task: GAME_TASK, gate: true, requireSolved: true },
    ]);

    const sent = await send.sendHomework(pool, {
      trainerId, studentId, homeworkId: tpl.id, dueAt: null, note: null,
    });
    assert.equal(sent.ok, true, sent.error);

    const parent = sent.assignment;
    assert.equal(parent.kind, 'homework');
    assert.equal(parent.homework_id, tpl.id);
    assert.equal(parent.title, 'Thursday');
    assert.equal(parent.parent_id, null);

    const children = await homework.childrenOf(pool, parent.id);
    assert.equal(children.length, 4);
    assert.deepEqual(children.map((c) => c.kind),
      ['lesson', 'puzzles', 'puzzles', 'engine_game']);
    assert.deepEqual(children.map((c) => c.item_key), tpl.items.map((i) => i.item_key));
    assert.deepEqual(children.map((c) => c.position), tpl.items.map((i) => i.position));
    assert.deepEqual(children.map((c) => c.gate), [false, true, false, true]);
    assert.deepEqual(children.map((c) => c.require_solved), [false, false, false, true]);

    // Each child's items: the tutorial's steps, the position, the puzzles, and
    // one row for the game.
    assert.deepEqual(children.map((c) => c.total_items), [3, 1, 2, 1]);

    // The tutorial's steps travel by key, not by index.
    const steps = await pool.query(
      'SELECT step_key FROM assignment_items WHERE assignment_id = $1 ORDER BY position',
      [children[0].id]
    );
    assert.deepEqual(steps.rows.map((r) => r.step_key), ['s21x', 's28x', 's35x']);
    assert.equal(children[0].lesson_id, lessonId);

    // The game's task is the trainer's, including the engine it must be played
    // against.
    // As `parseEngineGameTask` stores it: the goal's own field is present and
    // null, because „hold" asks for no number of moves.
    assert.deepEqual(children[3].task, { ...GAME_TASK, surviveMoves: null });

    // The gate chain arrives working: the second item is locked behind the
    // first, and the first is open.
    assert.deepEqual(children.map((c) => c.locked), [false, true, false, true]);
  });

  test('the homework is one row in the student\'s list, and its items are not', async () => {
    const { trainerId, studentId } = await pair();
    const lessonId = await lessonOf(trainerId);
    const tpl = await templateOf(trainerId, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'engine_game', task: GAME_TASK },
    ]);
    const sent = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(sent.ok, true, sent.error);

    const mine = await assignments.getStudentAssignments(pool, studentId);
    assert.deepEqual(mine.map((a) => a.id), [sent.assignment.id]);
    assert.equal(mine[0].child_total, 2);
    assert.equal(mine[0].child_completed, 0);
    assert.equal(await countAll(studentId), 3, 'a parent and two children exist');
  });

  test('a deadline and a note of this sending do not touch the template', async () => {
    const { trainerId, studentId } = await pair();
    const tpl = await templateOf(trainerId, [{ kind: 'engine_game', task: GAME_TASK }]);
    const due = '2026-10-01T18:00:00.000Z';
    const sent = await send.sendHomework(pool, {
      trainerId, studentId, homeworkId: tpl.id, dueAt: due, note: 'Before Thursday, please.',
    });
    assert.equal(sent.ok, true, sent.error);
    assert.equal(new Date(sent.assignment.due_at).toISOString(), due);
    assert.equal(sent.assignment.instructions, 'Before Thursday, please.');

    const still = await template.loadHomework(pool, tpl.id, trainerId);
    assert.equal(still.instructions, 'Read first, then solve.');
    assert.equal(still.sent.length, 1);
    assert.equal(still.sent[0].id, sent.assignment.id);
  });

  test('a homework sent twice is two homeworks, and each keeps its own progress', async () => {
    const { trainerId, studentId } = await pair();
    const second = await person('Bojan');
    await pool.query(
      `INSERT INTO trainer_students (trainer_id, student_id, status) VALUES ($1, $2, 'accepted')`,
      [trainerId, second]
    );
    const tpl = await templateOf(trainerId, [{ kind: 'engine_game', task: GAME_TASK }]);

    const toAna = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    const toBojan = await send.sendHomework(pool, { trainerId, studentId: second, homeworkId: tpl.id });
    assert.equal(toAna.ok, true);
    assert.equal(toBojan.ok, true);
    assert.notEqual(toAna.assignment.id, toBojan.assignment.id);

    // Ana finishes her copy; Bojan's is untouched.
    const anaGame = (await homework.childrenOf(pool, toAna.assignment.id))[0];
    const played = await assignments.recordEngineGameResult(pool, {
      studentId, assignmentId: anaGame.id, moves: ['Rh2', 'Ke7'], resigned: true,
    });
    assert.equal(played.ok, true, played.error);

    const anaParent = await pool.query('SELECT completed_at FROM assignments WHERE id = $1',
      [toAna.assignment.id]);
    const bojanParent = await pool.query('SELECT completed_at FROM assignments WHERE id = $1',
      [toBojan.assignment.id]);
    assert.ok(anaParent.rows[0].completed_at);
    assert.equal(bojanParent.rows[0].completed_at, null);

    const list = await template.loadHomework(pool, tpl.id, trainerId);
    assert.equal(list.sent.length, 2);
  });

  test('editing the template afterwards changes nothing that was sent', async () => {
    const { trainerId, studentId } = await pair();
    const lessonId = await lessonOf(trainerId);
    const tpl = await templateOf(trainerId, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'engine_game', task: GAME_TASK },
    ]);
    const sent = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    const before = await homework.childrenOf(pool, sent.assignment.id);

    await template.saveHomework(pool, {
      trainerId,
      homeworkId: tpl.id,
      payload: { title: 'Changed', items: [] },
    });

    const after = await homework.childrenOf(pool, sent.assignment.id);
    assert.deepEqual(after.map((c) => c.item_key), before.map((c) => c.item_key));
    assert.deepEqual(after.map((c) => c.kind), before.map((c) => c.kind));
    const parent = await pool.query('SELECT title FROM assignments WHERE id = $1',
      [sent.assignment.id]);
    assert.equal(parent.rows[0].title, 'Thursday');
  });

  // ---- refusals write nothing ---------------------------------------------

  test('a student who has not accepted gets nothing', async () => {
    const { trainerId, studentId } = await pair({ accepted: false });
    const tpl = await templateOf(trainerId, [{ kind: 'engine_game', task: GAME_TASK }]);
    const refused = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(refused.ok, false);
    assert.equal(refused.status, 403);
    assert.equal(await countAll(studentId), 0);
  });

  test('an empty homework, a stranger\'s homework and one that does not exist are refused', async () => {
    const { trainerId, studentId } = await pair();
    const empty = await templateOf(trainerId, [], 'Empty');
    const emptyRefused = await send.sendHomework(pool, {
      trainerId, studentId, homeworkId: empty.id,
    });
    assert.equal(emptyRefused.ok, false);
    assert.equal(emptyRefused.status, 422);

    const stranger = await person('Other trainer');
    const theirs = await templateOf(stranger, [{ kind: 'engine_game', task: GAME_TASK }]);
    const notMine = await send.sendHomework(pool, {
      trainerId, studentId, homeworkId: theirs.id,
    });
    assert.equal(notMine.ok, false);
    assert.equal(notMine.status, 404);

    const missing = await send.sendHomework(pool, {
      trainerId, studentId, homeworkId: 9_999_999,
    });
    assert.equal(missing.ok, false);
    assert.equal(missing.status, 404);
    assert.equal(await countAll(studentId), 0);
  });

  test('content that went bad since it was written refuses the whole send', async () => {
    const { trainerId, studentId } = await pair();
    const lessonId = await lessonOf(trainerId);
    const positionId = await positionOf(trainerId);
    const tpl = await templateOf(trainerId, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'positions', task: { puzzleIds: [positionId] } },
    ]);

    // The position is marked for review after the homework was written.
    await pool.query('UPDATE custom_puzzles SET needs_review = TRUE WHERE puzzle_id = $1',
      [positionId]);
    const refused = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(refused.ok, false);
    assert.equal(refused.status, 422);
    assert.match(refused.error, /marked for review/);
    assert.equal(await countAll(studentId), 0,
      'not even the tutorial item, which was fine — the whole homework or nothing');

    // And with the tutorial gone instead.
    await pool.query('UPDATE custom_puzzles SET needs_review = FALSE WHERE puzzle_id = $1',
      [positionId]);
    await pool.query('DELETE FROM saved_lessons WHERE id = $1', [lessonId]);
    const gone = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(gone.ok, false);
    assert.match(gone.error, /no longer yours/);
    assert.equal(await countAll(studentId), 0);
  });

  test('a puzzle set that resolves to nothing refuses the send', async () => {
    const { trainerId, studentId } = await pair();
    // No lichess_puzzles rows with this theme at all.
    const tpl = await templateOf(trainerId, [
      { kind: 'puzzles', task: { count: 3, themes: ['zugzwang'], minRating: 3200, maxRating: 3400 } },
    ]);
    const refused = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(refused.ok, false);
    assert.equal(refused.status, 422);
    assert.equal(await countAll(studentId), 0);
  });

  // ---- the routes ---------------------------------------------------------

  async function route(method, path, { userId, params = {}, body = {} }) {
    const dbModule = require('../db');
    const router = require('../routes/homeworks');
    const layer = router.stack.find(
      (l) => l.route && l.route.path === path && l.route.methods[method]
    );
    assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
    // The last handler is the route's own; the quota middleware in front of it
    // is not run here, and is asserted to be mounted by the test below.
    const handler = layer.route.stack.map((x) => x.handle).at(-1);

    const original = dbModule.pool.query;
    const originalConnect = dbModule.pool.connect;
    dbModule.pool.query = (text, values) => pool.query(text, values);
    dbModule.pool.connect = () => pool.connect();
    const answered = { status: 200, body: null };
    const res = {
      status(code) { answered.status = code; return this; },
      json(payload) { answered.body = payload; return this; },
      send() { return this; },
    };
    try {
      await handler({ user: { id: userId, name: 'Trainer' }, params, query: {}, body, headers: {} }, res);
    } finally {
      dbModule.pool.query = original;
      dbModule.pool.connect = originalConnect;
    }
    return answered;
  }

  test('the send route answers 201 and tells the student once', async () => {
    const { trainerId, studentId } = await pair();
    const tpl = await templateOf(trainerId, [
      { kind: 'engine_game', task: GAME_TASK },
      { kind: 'engine_game', task: { ...GAME_TASK, goal: 'win' } },
    ]);

    const r = await route('post', '/:id/send', {
      userId: trainerId,
      params: { id: String(tpl.id) },
      body: { studentId, note: 'Tonight' },
    });
    assert.equal(r.status, 201, JSON.stringify(r.body));
    assert.equal(r.body.children.length, 2);

    const told = await pool.query(
      `SELECT title, ref_id FROM user_notifications
        WHERE user_id = $1 AND kind = 'assignment_new'`,
      [studentId]
    );
    assert.equal(told.rows.length, 1, 'one notice for the homework, none for its items');
    assert.equal(told.rows[0].ref_id, r.body.id);
    assert.equal(told.rows[0].title, 'New homework');
  });

  test('the send route refuses a bad body and a student who is not theirs', async () => {
    const { trainerId, studentId } = await pair();
    const tpl = await templateOf(trainerId, [{ kind: 'engine_game', task: GAME_TASK }]);

    const noStudent = await route('post', '/:id/send', {
      userId: trainerId, params: { id: String(tpl.id) }, body: {},
    });
    assert.equal(noStudent.status, 400);

    const stranger = await person('Not mine');
    const notMine = await route('post', '/:id/send', {
      userId: trainerId, params: { id: String(tpl.id) }, body: { studentId: stranger },
    });
    assert.equal(notMine.status, 403);
    assert.equal(await countAll(stranger), 0);
    assert.equal(await countAll(studentId), 0);
  });

  test('sending costs quota, and every way out without a homework refunds it', () => {
    // The unit is the homework per student, not the item: the middleware sits
    // on this one route. Read from the source because the handler tests above
    // call the handler directly and never run the middleware — so this is the
    // only place that can say the charge and the refunds are wired at all.
    const fs = require('fs');
    const path = require('path');
    const source = fs.readFileSync(
      path.join(__dirname, '..', 'routes', 'homeworks.js'), 'utf8'
    );
    const CLOSE = String.fromCharCode(10) + '});';
    const from = source.indexOf("router.post('/:id/send'");
    assert.ok(from > 0, 'the send route must exist');
    const body = source.slice(from, source.indexOf(CLOSE, from));

    assert.match(body, /requireQuota\(ENT\.ASSIGNMENTS\)/, 'the route charges one unit');

    // Every refusal hands the unit back, and the refund comes *before* the
    // answer: a trainer must not pay for a homework nobody received.
    const refusals = [...body.matchAll(/return res\.status\([^)]+\)/g)];
    assert.ok(refusals.length >= 2, `refusals found: ${refusals.length}`);
    for (const refusal of refusals) {
      const before = body.slice(Math.max(0, refusal.index - 220), refusal.index);
      assert.match(before, /await refundQuota\(req\)/,
        `no refund before ${refusal[0]}`);
    }

    // And the one path that is not a `return`: the catch.
    const caught = body.slice(body.indexOf('} catch'));
    assert.match(caught, /await refundQuota\(req\)/, 'a thrown error refunds too');

    // The success path does not refund — that would make sending free. It ends
    // at the catch, which is further down the file and refunds on purpose.
    const success = body.slice(body.indexOf('res.status(201)'), body.indexOf('} catch'));
    assert.doesNotMatch(success, /refundQuota/);
    assert.match(success, /res\.status\(201\)/, 'and it is the one that answers 201');
  });
});
