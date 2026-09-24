// The review a puzzle from a game carries — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// phase 2.
//
// A puzzle kept from „Review entire game" is the position before the mistake
// (phase 1.3). What it teaches is shown once the student has moved: the
// game's move and the line that punishes it, the line behind the best move,
// the engine's second line, the words, the chances. That is `review`, one
// JSONB column, and three rules hold it:
//
// - **the writer replays it**: every line is played on the position with
//   chess.js before it is stored, and the best line must start with the
//   exercise's own answer — a review of another puzzle is refused;
// - **it never reaches a student before their move**: only the owner's editor,
//   the answer to an attempt and a homework item already attempted carry it;
// - **it round-trips**: what the owner reads back is what was stored, and an
//   edit that says nothing about it keeps it — while it still fits the answer.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');
const { parseExercise } = require('../services/exerciseAuthoring');
const { readReview, reviewOf } = require('../services/exercise');

/// 1.e4 e5 2.Nf3 Nc6, White to move. The game played 3.Bc4; 3.d4 is the
/// answer, 3.Nc3 the second line.
const FEN = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

const review = (over = {}) => ({
  played: 'Bc4',
  bestLine: ['d4', 'exd4', 'Nxd4'],
  refutationLine: ['Nf6', 'd3'],
  secondLine: ['Nc3', 'Nf6'],
  words: 'The centre first: after d4 Black has to take.',
  chances: { best: 58.2, played: 47.9, second: 52.4 },
  ...over,
});

const puzzle = (over = {}) => ({
  name: 'Game of 24.9.2026, move 3',
  fen: FEN,
  task: { type: 'find' },
  solution: [{ accept: ['d4'] }],
  origin: 'mistakes',
  instruction: 'A mistake was made in this position. Find the best move.',
  review: review(),
  ...over,
});

// ---- the writer's rule, which needs no database ---------------------------

test('a review is stored as the board spells it, and only what it holds', () => {
  const parsed = parseExercise(puzzle({
    review: review({
      played: ' Bc4 ',
      bestLine: ['d4', 'exd4', 'Nxd4'],
      secondLine: ['Nc3', 'Nf6'],
      extra: 'not a field',
    }),
  }));
  assert.equal(parsed.ok, true, parsed.error);
  assert.deepEqual(parsed.exercise.review, {
    played: 'Bc4',
    bestLine: ['d4', 'exd4', 'Nxd4'],
    refutationLine: ['Nf6', 'd3'],
    secondLine: ['Nc3', 'Nf6'],
    words: 'The centre first: after d4 Black has to take.',
    chances: { best: 58.2, played: 47.9, second: 52.4 },
  });
});

test('a line that does not replay is refused, and says which line', () => {
  const cases = [
    [{ bestLine: ['d4', 'exd4', 'Qxh7'] }, /best line does not play: "Qxh7" after 2 moves/],
    [{ secondLine: ['Nc3', 'Kd6'] }, /second line does not play: "Kd6"/],
    // Replayed from the position after the game's move, not from the puzzle.
    [{ refutationLine: ['d4'] }, /refutation line does not play: "d4"/],
    [{ played: 'Bb6' }, /game's move does not play/],
  ];
  for (const [over, why] of cases) {
    const parsed = parseExercise(puzzle({ review: review(over) }));
    assert.equal(parsed.ok, false, JSON.stringify(over));
    assert.match(parsed.error, why);
  }
});

test('the refutation is played after the game\'s move', () => {
  // Nf6 is Black's move: legal only once 3.Bc4 is on the board.
  assert.equal(parseExercise(puzzle()).ok, true);
  const fromPuzzle = readReview(FEN, [{ accept: ['d4'] }], review({ refutationLine: ['Bc4'] }));
  assert.equal(fromPuzzle.ok, false);
});

test('a best line that starts with another move explains another puzzle', () => {
  const parsed = parseExercise(puzzle({ review: review({ bestLine: ['Nc3', 'Nf6'] }) }));
  assert.equal(parsed.ok, false);
  assert.match(parsed.error, /starts with Nc3, but the answer is d4/);
  const empty = parseExercise(puzzle({ review: review({ bestLine: [] }) }));
  assert.equal(empty.ok, false);
  assert.match(empty.error, /best line is empty/);
});

test('a game exercise has no review, and the chances are numbers from 0 to 100', () => {
  const asGame = parseExercise(puzzle({ task: { type: 'game', side: 'w', goal: 'win' }, solution: undefined }));
  assert.equal(asGame.ok, false);
  assert.match(asGame.error, /Only a find exercise has a review/);
  for (const chances of [{ best: 101, played: 40 }, { best: 58, played: '40' }, null]) {
    const parsed = parseExercise(puzzle({ review: review({ chances }) }));
    assert.equal(parsed.ok, false, JSON.stringify(chances));
  }
  const noSecond = parseExercise(puzzle({ review: review({ chances: { best: 58, played: 40 } }) }));
  assert.equal(noSecond.ok, true, noSecond.error);
  assert.equal(noSecond.exercise.review.chances.second, null);
});

test('absent, null and a value are three answers', () => {
  assert.equal(parseExercise(puzzle({ review: undefined })).exercise.review, undefined);
  assert.equal(parseExercise(puzzle({ review: null })).exercise.review, null);
  assert.equal(typeof parseExercise(puzzle()).exercise.review, 'object');
  assert.equal(reviewOf({ review: null }), null);
  assert.equal(reviewOf({}), null);
});

// ---- on a real database, through the real routes --------------------------

describe('the review on a real database', skipUnlessDatabase() ?? {}, () => {
  let db;
  let pool;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
  });
  after(async () => { await db.drop(); });

  let minted = 0;
  async function people() {
    minted++;
    const tag = `${process.pid}_${minted}`;
    const mint = async (who) => (await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`${who}${tag}@test.invalid`, who]
    )).rows[0].id;
    return { trainerId: await mint('trainer'), studentId: await mint('student'), tag };
  }

  /// Runs a real handler of [routerPath] as [userId], its pool pointed here.
  async function route(routerPath, method, routePath, { userId, params = {}, body = {} }) {
    const dbModule = require('../db');
    const router = require(routerPath);
    const layer = router.stack.find((l) => l.route && l.route.path === routePath && l.route.methods[method]);
    assert.ok(layer, `${method.toUpperCase()} ${routePath} must be mounted`);
    const handler = layer.route.stack[layer.route.stack.length - 1].handle;
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
  const exercises = (...a) => route('../routes/exercises', ...a);
  const assignmentsRoute = (...a) => route('../routes/assignments', ...a);

  async function keep(trainerId, body = puzzle()) {
    const made = await exercises('post', '/', { userId: trainerId, body });
    assert.equal(made.status, 201, JSON.stringify(made.body));
    return made.body.exercise;
  }

  test('a kept review comes back to its owner exactly as it was stored', async () => {
    const { trainerId } = await people();
    const e = await keep(trainerId);
    const stored = (await pool.query('SELECT review FROM custom_puzzles WHERE puzzle_id = $1', [e.id])).rows[0].review;
    assert.deepEqual(stored, parseExercise(puzzle()).exercise.review);
    assert.deepEqual(e.review, stored);
    // Value for value: JSONB keeps every value and orders keys its own way, so
    // „byte for byte" means what the reader parses, not the text sent.
    const read = await exercises('get', '/:id', { userId: trainerId, params: { id: e.id } });
    assert.deepEqual(read.body.exercise.review, parseExercise(puzzle()).exercise.review);
  });

  test('a refused review writes nothing', async () => {
    const { trainerId } = await people();
    const count = async () => (await pool.query(
      'SELECT COUNT(*)::int AS n FROM custom_puzzles WHERE owner_id = $1', [trainerId])).rows[0].n;
    const refused = await exercises('post', '/', {
      userId: trainerId, body: puzzle({ review: review({ bestLine: ['d4', 'Qxd4', 'Ke2'] }) }),
    });
    assert.equal(refused.status, 422);
    assert.match(refused.body.error, /best line does not play/);
    assert.equal(await count(), 0);
  });

  test('an edit that says nothing keeps the review; null clears it; a new answer drops one that no longer fits', async () => {
    const { trainerId } = await people();
    const e = await keep(trainerId);
    const put = (body) => exercises('put', '/:id', { userId: trainerId, params: { id: e.id }, body });

    const renamed = await put(puzzle({ fen: undefined, name: 'Renamed', review: undefined }));
    assert.equal(renamed.status, 200, JSON.stringify(renamed.body));
    assert.deepEqual(renamed.body.exercise.review, e.review, 'the editor sends no review, and it is kept');

    const other = await put(puzzle({ fen: undefined, solution: [{ accept: ['Nc3'] }], review: undefined }));
    assert.equal(other.status, 200, JSON.stringify(other.body));
    assert.equal(other.body.exercise.review, null, 'lines that start with d4 do not explain Nc3');

    await put(puzzle({ fen: undefined }));
    const cleared = await put(puzzle({ fen: undefined, review: null }));
    assert.equal(cleared.body.exercise.review, null);
    const row = await pool.query('SELECT review FROM custom_puzzles WHERE puzzle_id = $1', [e.id]);
    assert.equal(row.rows[0].review, null);
  });

  test('solving one\'s own puzzle: the attempt carries the review', async () => {
    const { trainerId } = await people();
    const e = await keep(trainerId);
    const wrong = await exercises('post', '/:id/attempt', {
      userId: trainerId, params: { id: e.id }, body: { moveSan: 'Nc3' },
    });
    assert.equal(wrong.status, 200, JSON.stringify(wrong.body));
    assert.equal(wrong.body.correct, false);
    assert.deepEqual(wrong.body.review, e.review, 'right or wrong, the review follows the move');
  });

  test('as homework, the review reaches the student only after their move', async () => {
    const who = await people();
    const e = await keep(who.trainerId);
    const assignment = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind)
       VALUES ($1, $2, 'From the game', 'puzzles') RETURNING id`,
      [who.trainerId, who.studentId]
    );
    const id = assignment.rows[0].id;
    await pool.query(
      'INSERT INTO assignment_items (assignment_id, puzzle_id, position) VALUES ($1, $2, 0)',
      [id, e.id]
    );
    const { buildReview } = require('../services/assignmentReview');
    const itemFor = async (viewer) => (await buildReview(pool, id, viewer)).items[0];

    const beforeMove = await itemFor(who.studentId);
    assert.equal(beforeMove.attempted, false);
    assert.equal(beforeMove.review, null, 'nothing of the review before the move');
    assert.equal(JSON.stringify(beforeMove).includes('exd4'), false, 'not under any other name either');
    assert.deepEqual((await itemFor(who.trainerId)).review, e.review, 'the trainer sees it whenever');

    // Somebody else's move on this homework reveals nothing.
    const stranger = await people();
    const refused = await assignmentsRoute('post', '/:id/custom-attempt', {
      userId: stranger.studentId, params: { id: String(id) }, body: { puzzleId: e.id, moveSan: 'd4' },
    });
    assert.equal(refused.status, 404);
    assert.equal(JSON.stringify(refused.body).includes('exd4'), false);

    const answered = await assignmentsRoute('post', '/:id/custom-attempt', {
      userId: who.studentId, params: { id: String(id) }, body: { puzzleId: e.id, moveSan: 'Bc4' },
    });
    assert.equal(answered.status, 200, JSON.stringify(answered.body));
    assert.equal(answered.body.correct, false);
    assert.deepEqual(answered.body.review, e.review);
    assert.deepEqual((await itemFor(who.studentId)).review, e.review, 'and on the homework once answered');
  });

  test('an exercise without a review answers null, not an absent field', async () => {
    const { trainerId } = await people();
    const e = await keep(trainerId, puzzle({ review: undefined }));
    assert.equal(e.review, null);
    const attempt = await exercises('post', '/:id/attempt', {
      userId: trainerId, params: { id: e.id }, body: { moveSan: 'd4' },
    });
    assert.equal(attempt.body.correct, true);
    assert.equal(attempt.body.review, null);
  });
});
