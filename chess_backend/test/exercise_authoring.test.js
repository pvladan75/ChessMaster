// An exercise made by hand, on a real PostgreSQL, through the real routes
// (`docs/PLAN-EXERCISE.md`, phase 2a). Stands on the fixture the line judge
// and the app's writer share.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');
const { parseExercise } = require('../services/exerciseAuthoring');
const { assignableProblem, exerciseColumns } = require('../services/exercise');

const fixture = require(path.join(__dirname, '..', '..', 'docs', 'gates', 'exercise_line_cases.json'));
const SCHOLAR = fixture.positions.scholar;
const LINE = fixture.solutions.scholarLine;

const find = (over = {}) => ({
  name: 'Queen out early', fen: SCHOLAR, task: { type: 'find' }, solution: LINE.steps, ...over,
});
const game = (over = {}) => ({
  name: 'Win it', fen: fixture.positions.backRank, task: { type: 'game', side: 'w', goal: 'win' }, ...over,
});

// ---- the parser, which needs no database ---------------------------------

test('what is stored is what the readers read back, not what was sent', () => {
  const parsed = parseExercise(find({
    name: '  Queen out early  ',
    solution: fixture.solutions.backRankMate.steps,
    fen: fixture.positions.backRank,
  }));
  assert.equal(parsed.ok, true, parsed.error);
  assert.equal(parsed.exercise.name, 'Queen out early');
  assert.equal(parsed.exercise.side, 'w');
  assert.deepEqual(parsed.exercise.solution, fixture.solutions.backRankMate.normalised);
  // The one task the position states for itself.
  assert.equal(parsed.exercise.instruction, 'White mates in one move.');
  // The trainer's own words win.
  assert.equal(parseExercise(find({ instruction: ' Look at f7. ' })).exercise.instruction, 'Look at f7.');
});

test('a game task is stored without the position the row already has', () => {
  const parsed = parseExercise(game());
  assert.equal(parsed.ok, true, parsed.error);
  assert.equal(parsed.exercise.task.type, 'game');
  assert.equal(parsed.exercise.task.goal, 'win');
  assert.equal('fen' in parsed.exercise.task, false);
  assert.equal(parsed.exercise.solution, null);
});

test('every line the fixture refuses is refused at the door, with its reason', () => {
  for (const c of fixture.refused) {
    const parsed = parseExercise(find({ fen: fixture.positions[c.position], solution: c.steps }));
    assert.equal(parsed.ok, false, c.name);
    assert.ok(parsed.error.includes(c.why), `${c.name}: "${parsed.error}"`);
  }
});

test('an exercise without a name, a position or a task is not one', () => {
  assert.match(parseExercise(find({ name: '   ' })).error, /needs a name/);
  assert.match(parseExercise(find({ name: 'x'.repeat(121) })).error, /longer than 120/);
  assert.match(parseExercise(find({ fen: '' })).error, /needs a position/);
  assert.match(parseExercise(find({ fen: '8/8/8/8/8/8/8/8 w - - 0 1' })).error, /not valid/);
  assert.match(parseExercise(find({ task: undefined })).error, /needs a task/);
  assert.match(parseExercise(find({ task: { type: 'essay' } })).error, /"find" or "game"/);
  assert.match(parseExercise(find({ solution: undefined })).error, /at least one move/);
  assert.match(parseExercise(game({ task: { type: 'game', side: 'w', goal: 'crush' } })).error, /goal must be/);
  assert.match(parseExercise(null).error, /Nothing to save/);
});

test('an exercise keeps its position', () => {
  const moved = parseExercise(find({ fen: fixture.positions.backRank }), { keptFen: SCHOLAR });
  assert.equal(moved.ok, false);
  assert.equal(moved.status, 409);
  // Saying nothing about the position, or repeating it, is not a change.
  assert.equal(parseExercise(find({ fen: undefined }), { keptFen: SCHOLAR }).ok, true);
  assert.equal(parseExercise(find(), { keptFen: SCHOLAR }).exercise.fen, SCHOLAR);
});

// ---- the routes, on the real table ---------------------------------------

describe('exercises on a real database', skipUnlessDatabase() ?? {}, () => {
  let db;
  let pool;
  let trainerId;
  let strangerId;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    const mint = async (tag) => (await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`${tag}_${process.pid}@test.invalid`, tag]
    )).rows[0].id;
    trainerId = await mint('extrainer');
    strangerId = await mint('exstranger');
  });
  after(async () => { await db.drop(); });

  async function route(method, routePath, { userId, params = {}, body = {} }) {
    const dbModule = require('../db');
    const router = require('../routes/exercises');
    const layer = router.stack.find((l) => l.route && l.route.path === routePath && l.route.methods[method]);
    assert.ok(layer, `${method.toUpperCase()} ${routePath} must be mounted`);
    const handler = layer.route.stack[layer.route.stack.length - 1].handle;
    const original = dbModule.pool.query;
    dbModule.pool.query = (text, values) => pool.query(text, values);
    const answered = { status: 200, body: null };
    const res = {
      status(code) { answered.status = code; return this; },
      json(payload) { answered.body = payload; return this; },
    };
    try {
      await handler({ user: { id: userId }, params, query: {}, body, headers: {} }, res);
    } finally {
      dbModule.pool.query = original;
    }
    return answered;
  }

  test('the routes are mounted where the app will look for them', () => {
    const fs = require('node:fs');
    const server = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
    assert.match(server, /^app\.use\('\/exercises', exerciseRoutes\);$/m);
    assert.match(server, /^const exerciseRoutes = require\('\.\/routes\/exercises'\);$/m);
  });

  test('a find-the-move exercise is written, comes back whole, and can be set as homework', async () => {
    const made = await route('post', '/', { userId: trainerId, body: find({ themes: ['opening', ' trap '] }) });
    assert.equal(made.status, 201, JSON.stringify(made.body));
    const e = made.body.exercise;
    assert.match(e.id, /^ex_[0-9a-f]{16}$/);
    assert.equal(e.origin, 'manual');
    assert.equal(e.sideToMove, 'w');
    assert.deepEqual(e.task, { type: 'find' });
    assert.deepEqual(e.solution, LINE.normalised);
    assert.deepEqual(e.themes, ['opening', 'trap']);
    assert.equal(e.assignable, true);
    assert.equal(e.blockedReason, null);

    const read = await route('get', '/:id', { userId: trainerId, params: { id: e.id } });
    assert.equal(read.status, 200);
    assert.deepEqual(read.body.exercise, e);

    // The row is what every other path reads: it must pass the rule they ask.
    const row = await pool.query(
      `SELECT puzzle_id, ${exerciseColumns()} FROM custom_puzzles WHERE puzzle_id = $1`, [e.id]
    );
    assert.equal(assignableProblem(row.rows[0]), null);
    assert.equal(row.rows[0].solution_san, null, 'one home: the line is not also kept as a printed move');
  });

  test('a game exercise is written, and is assignable as a game and only as a game', async () => {
    const made = await route('post', '/', { userId: trainerId, body: game() });
    assert.equal(made.status, 201, JSON.stringify(made.body));
    const e = made.body.exercise;
    assert.equal(e.task.type, 'game');
    assert.equal(e.task.fen, fixture.positions.backRank, 'read back with the row\'s position');
    assert.equal(e.solution, null);
    assert.equal(e.assignable, true);

    const row = await pool.query(
      `SELECT task, ${exerciseColumns()} FROM custom_puzzles WHERE puzzle_id = $1`, [e.id]
    );
    assert.equal('fen' in row.rows[0].task, false, 'stored without it');
    assert.match(assignableProblem(row.rows[0]), /cannot be answered with one move/);
  });

  test('a refusal writes nothing', async () => {
    const before = (await pool.query('SELECT COUNT(*)::int AS n FROM custom_puzzles')).rows[0].n;
    const refused = await route('post', '/', { userId: trainerId, body: find({ solution: [{ accept: ['Qh6'] }] }) });
    assert.equal(refused.status, 422);
    assert.match(refused.body.error, /"Qh6" cannot be played/);
    const after = (await pool.query('SELECT COUNT(*)::int AS n FROM custom_puzzles')).rows[0].n;
    assert.equal(after, before);
  });

  test('an edit changes the words, the task and the line, and never the position', async () => {
    const made = await route('post', '/', { userId: trainerId, body: find() });
    const id = made.body.exercise.id;

    const edited = await route('put', '/:id', {
      userId: trainerId,
      params: { id },
      body: find({ name: 'Renamed', fen: undefined, solution: [{ accept: ['Qh5'], reply: null }] }),
    });
    assert.equal(edited.status, 200, JSON.stringify(edited.body));
    assert.equal(edited.body.exercise.name, 'Renamed');
    assert.equal(edited.body.exercise.fen, SCHOLAR);
    assert.deepEqual(edited.body.exercise.solution, [{ accept: ['Qh5'], reply: null }]);

    const moved = await route('put', '/:id', {
      userId: trainerId, params: { id }, body: find({ fen: fixture.positions.backRank }),
    });
    assert.equal(moved.status, 409);
    const still = await route('get', '/:id', { userId: trainerId, params: { id } });
    assert.equal(still.body.exercise.name, 'Renamed', 'a refused edit changes nothing');
    assert.equal(still.body.exercise.fen, SCHOLAR);

    // find → game: the line goes, because a game has none.
    const asGame = await route('put', '/:id', {
      userId: trainerId, params: { id }, body: game({ fen: undefined, name: 'Now a game' }),
    });
    assert.equal(asGame.status, 200, JSON.stringify(asGame.body));
    assert.equal(asGame.body.exercise.task.type, 'game');
    assert.equal(asGame.body.exercise.solution, null);
  });

  test('somebody else\'s exercise does not exist', async () => {
    const made = await route('post', '/', { userId: trainerId, body: find() });
    const id = made.body.exercise.id;
    const read = await route('get', '/:id', { userId: strangerId, params: { id } });
    assert.equal(read.status, 404);
    const edit = await route('put', '/:id', { userId: strangerId, params: { id }, body: find({ name: 'Mine now' }) });
    assert.equal(edit.status, 404);
    const mine = await route('get', '/:id', { userId: trainerId, params: { id } });
    assert.equal(mine.body.exercise.name, 'Queen out early');
    const nothing = await route('get', '/:id', { userId: trainerId, params: { id: 'ex_doesnotexist' } });
    assert.equal(nothing.status, 404);
    assert.deepEqual(nothing.body, read.body, 'not yours and not there are one answer');
  });

  test('a scanned position can be given a name and accepted alternatives', async () => {
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, solution_san, origin)
       VALUES ('cust_scanned_one', $1, $2, 'w', 'Rd8#', 'book')`,
      [trainerId, fixture.positions.backRank]
    );
    const before = await route('get', '/:id', { userId: trainerId, params: { id: 'cust_scanned_one' } });
    assert.deepEqual(before.body.exercise.solution, [{ accept: ['Rd8#'], reply: null }]);

    const edited = await route('put', '/:id', {
      userId: trainerId,
      params: { id: 'cust_scanned_one' },
      body: { name: 'Back rank', task: { type: 'find' }, solution: [{ accept: ['Rd8', 'Re8'] }] },
    });
    assert.equal(edited.status, 200, JSON.stringify(edited.body));
    assert.equal(edited.body.exercise.origin, 'book', 'where it came from does not change');
    assert.deepEqual(edited.body.exercise.solution, [{ accept: ['Rd8#', 'Re8#'], reply: null }]);
  });
});
