// tutorial_video_db.test.js — phase 2 of docs/PLAN-TUTORIJAL-VIDEO.md on a
// real PostgreSQL: what a stub would accept whatever the SQL said.
//
//  1. the schema has lost what the parts needed: `review_items`,
//     `assignment_items.step_key` and `revealed_at`;
//  2. a homework's tutorial item is one item, sent only with a film, and its
//     download opens the gated item after it — not before;
//  3. the download is recorded once: a second one keeps the first time;
//  4. a student reads their trainer's single positions and not their
//     tutorials, through the list route, the labels and the Library shelf.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const realtime = require('../services/realtime');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');
const { EXPORTS_DIR } = require('../services/tutorialFilm');

realtime.init({ to: () => ({ emit: () => {} }) });

const skip = skipUnlessDatabase();
const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

describe('a tutorial sent as its film, on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let template;
  let send;
  let homework;
  let assignments;
  let lib;
  const films = [];

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    template = require('../services/homeworkTemplate');
    send = require('../services/homeworkSend');
    homework = require('../services/homeworkService');
    assignments = require('../services/assignmentService');
    lib = require('../services/positionLibrary');
  });

  after(async () => {
    for (const film of films) fs.rmSync(path.join(EXPORTS_DIR, film), { force: true });
    if (db) await db.drop();
  });

  let minted = 0;
  async function person(name) {
    minted++;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`tv${process.pid}_${minted}@test.invalid`, name]
    );
    return r.rows[0].id;
  }

  async function pair() {
    const trainerId = await person('Trainer');
    const studentId = await person('Ana');
    await pool.query(
      `INSERT INTO trainer_students (trainer_id, student_id, status) VALUES ($1, $2, 'accepted')`,
      [trainerId, studentId]
    );
    return { trainerId, studentId };
  }

  /// A tutorial of three parts, with a film on disk unless [film] is false.
  async function tutorialOf(trainerId, { film = true, tags = null } = {}) {
    let filename = null;
    if (film) {
      fs.mkdirSync(EXPORTS_DIR, { recursive: true });
      filename = `tutorial_db_${process.pid}_${crypto.randomBytes(4).toString('hex')}.mp4`;
      fs.writeFileSync(path.join(EXPORTS_DIR, filename), 'mp4');
      films.push(filename);
    }
    const parts = JSON.stringify([1, 2, 3].map((n) => ({ id: `q${n}z`, title: `Part ${n}`, fen: START })));
    const r = await pool.query(
      `INSERT INTO saved_lessons (user_id, trainer_id, title, fen, position_list, video_filename, tags)
       VALUES ($1, $1, 'Broken pawns', $2, $3::jsonb, $4, $5) RETURNING id`,
      [trainerId, START, parts, filename, tags]
    );
    return r.rows[0].id;
  }

  const GAME_TASK = {
    fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1', side: 'w', goal: 'hold', level: 'lako', thinkSeconds: 2, plyCap: 40,
  };

  async function templateOf(trainerId, items) {
    const saved = await template.saveHomework(pool, {
      trainerId, payload: { title: 'Thursday', instructions: null, items },
    });
    assert.equal(saved.ok, true, saved.error);
    return saved.homework;
  }

  /// `GET /lessons` as [userId], on this database.
  async function listAs(userId) {
    return (await runLessonsRoute('/', userId)).body;
  }

  /// A `GET` route of `routes/lessons.js`, driven against this database.
  async function runLessonsRoute(routePath, userId) {
    const appDb = require('../db');
    const lessonsRouter = require('../routes/lessons');
    const original = appDb.pool.query;
    appDb.pool.query = (...args) => pool.query(...args);
    try {
      const layer = lessonsRouter.stack.find((l) => l.route && l.route.path === routePath && l.route.methods.get);
      const handlers = layer.route.stack.map((h) => h.handle);
      const res = {
        statusCode: 200, body: null,
        status(code) { this.statusCode = code; return this; },
        json(payload) { this.body = payload; return this; },
      };
      await handlers[handlers.length - 1]({ query: {}, params: {}, user: { id: userId } }, res);
      return res;
    } finally {
      appDb.pool.query = original;
    }
  }

  test('the schema has lost what the parts needed', async () => {
    // A fresh database never had them, which proves only that nothing creates
    // them. The owner's database has them: put them back, as it has them, and
    // start again — the drop is what must take them.
    await pool.query(`
      ALTER TABLE assignment_items ADD COLUMN step_key VARCHAR(16), ADD COLUMN revealed_at TIMESTAMPTZ;
      CREATE UNIQUE INDEX idx_assignment_items_step_key
        ON assignment_items(assignment_id, step_key) WHERE step_key IS NOT NULL;
      CREATE TABLE review_items (id SERIAL PRIMARY KEY, step_key VARCHAR(16));
    `);
    await require('../db').initDB(pool);

    const columns = await pool.query(
      `SELECT column_name FROM information_schema.columns
        WHERE table_name = 'assignment_items' AND column_name IN ('step_key', 'revealed_at')`
    );
    assert.deepEqual(columns.rows, []);
    const table = await pool.query(`SELECT to_regclass('review_items') AS t`);
    assert.equal(table.rows[0].t, null);
  });

  test('a homework’s tutorial is one item, and its download opens the gated item after it', async () => {
    const { trainerId, studentId } = await pair();
    const lessonId = await tutorialOf(trainerId);
    const tpl = await templateOf(trainerId, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'engine_game', task: GAME_TASK, gate: true },
    ]);
    const sent = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(sent.ok, true, sent.error);

    const [video, game] = await homework.childrenOf(pool, sent.assignment.id);
    assert.equal(video.kind, 'lesson');
    assert.equal(video.total_items, 1, 'one item, not one per part');
    assert.equal((await homework.lockOf(pool, game.id)).locked, true, 'locked before the download');

    assert.equal(await assignments.recordVideoDownload(pool, { studentId, assignmentId: video.id }), true);

    const done = await pool.query('SELECT completed_at FROM assignments WHERE id = $1', [video.id]);
    assert.notEqual(done.rows[0].completed_at, null, 'the download is what finishes it');
    assert.equal((await homework.lockOf(pool, game.id)).locked, false, 'and the next item opens');
  });

  test('a download is recorded once: a second keeps the first time', async () => {
    const { trainerId, studentId } = await pair();
    const lessonId = await tutorialOf(trainerId);
    const sent = await assignments.createLessonAssignment(pool, { trainerId, studentId, lessonId });
    assert.equal(sent.ok, true, sent.reason);
    const id = sent.assignment.id;

    // The trainer's list says one student has not downloaded it yet (D13) …
    assert.equal((await listAs(trainerId)).find((row) => row.id === lessonId).waiting_downloads, 1);

    assert.equal(await assignments.recordVideoDownload(pool, { studentId, assignmentId: id }), true);
    // … and none once they have.
    assert.equal((await listAs(trainerId)).find((row) => row.id === lessonId).waiting_downloads, 0);
    const first = await pool.query('SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [id]);
    assert.equal(await assignments.recordVideoDownload(pool, { studentId, assignmentId: id }), false);
    const second = await pool.query('SELECT attempted_at FROM assignment_items WHERE assignment_id = $1', [id]);
    assert.deepEqual(second.rows, first.rows);

    // Nobody else's download lands on it.
    const stranger = await person('Stranger');
    assert.equal(await assignments.recordVideoDownload(pool, { studentId: stranger, assignmentId: id }), false);
  });

  test('a homework with a tutorial that has no film is not sent, and names it', async () => {
    const { trainerId, studentId } = await pair();
    const lessonId = await tutorialOf(trainerId, { film: false });
    const tpl = await templateOf(trainerId, [{ kind: 'lesson', task: { lessonId } }]);
    const sent = await send.sendHomework(pool, { trainerId, studentId, homeworkId: tpl.id });
    assert.equal(sent.ok, false);
    assert.equal(sent.status, 422);
    assert.match(sent.error, /"Broken pawns" has no video yet/);
    const count = await pool.query('SELECT COUNT(*)::int AS n FROM assignments WHERE student_id = $1', [studentId]);
    assert.equal(count.rows[0].n, 0, 'nothing arrives');
  });

  test('a student reads the trainer’s positions and not the trainer’s tutorials', async () => {
    const { trainerId, studentId } = await pair();
    await tutorialOf(trainerId, { tags: ['tutorial-label'] });
    await pool.query(
      `INSERT INTO saved_lessons (user_id, trainer_id, title, fen, tags)
       VALUES ($1, $1, 'A position', $2, ARRAY['position-label'])`,
      [trainerId, START]
    );

    const shelf = await lib.listTutorials(pool, studentId, { search: null });
    assert.deepEqual(shelf, [], 'no trainer tutorial on the student’s shelf');
    const positions = await lib.listSavedPositions(pool, studentId, { search: null });
    assert.deepEqual(positions.map((p) => p.title), ['A position']);

    // The list route and the labels, through the one condition they share.
    const list = await runLessonsRoute('/', studentId);
    assert.equal(list.statusCode, 200);
    assert.deepEqual(list.body.map((row) => row.title), ['A position']);
    const labels = await runLessonsRoute('/labels', studentId);
    assert.deepEqual(labels.body, ['position-label']);

    // And the trainer still reads their own tutorial.
    const own = await lib.listTutorials(pool, trainerId, { search: null });
    assert.equal(own.length, 1);
  });
});
