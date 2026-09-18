// What a `custom_puzzles` row asks, read in one place (`services/exercise.js`,
// `docs/PLAN-EXERCISE.md` phase 1).
const test = require('node:test');
const assert = require('node:assert');
const {
  exerciseOf, firstMoveOf, readSolution, assignableProblem, exerciseColumns,
} = require('../services/exercise');

// White mates with Rd8; Re1 and Kf1 are legal and do not.
const BACK_RANK = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';
// A two-move line: 1.Qh5 g6 2.Qxe5+.
const LINE = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';

test('a row written before the columns existed is a one-move find-the-move exercise', () => {
  const read = exerciseOf({ fen: BACK_RANK, solution_san: 'Rd8#', needs_review: false });
  assert.deepEqual(read.task, { type: 'find' });
  assert.deepEqual(read.solution, [{ accept: ['Rd8#'], reply: null }]);
  assert.equal(read.problem, null);
});

test('a stored solution wins over the printed move, and comes back as the board spells it', () => {
  const read = exerciseOf({
    fen: BACK_RANK,
    solution_san: 'Re1',
    solution: [{ accept: ['Rd8', 'Re1'], reply: null }],
  });
  assert.deepEqual(read.solution, [{ accept: ['Rd8#', 'Re1'], reply: null }]);
  assert.deepEqual(firstMoveOf({ fen: BACK_RANK, solution: [{ accept: ['Rd8', 'Re1'] }] }),
    { solutionSan: 'Rd8#', acceptedSans: ['Re1'] });
});

test('a row with neither has nothing to judge with, and says so', () => {
  const read = exerciseOf({ fen: BACK_RANK, solution_san: null });
  assert.equal(read.solution, null);
  assert.match(read.problem, /has no solution/);
  assert.equal(firstMoveOf({ fen: BACK_RANK, solution_san: null }), null);
});

test('a line replays: every accepted move legal where asked, every reply after the main move', () => {
  const read = readSolution(LINE, [
    { accept: ['Qh5', 'Qf3'], reply: 'g6' },
    { accept: ['Qxe5+'] },
  ]);
  assert.equal(read.ok, true);
  assert.deepEqual(read.steps, [
    { accept: ['Qh5', 'Qf3'], reply: 'g6' },
    { accept: ['Qxe5+'], reply: null },
  ]);
});

test('a line that does not replay is refused, with the move that broke it', () => {
  const cases = [
    [[], /at least one move/],
    [[{ accept: [] }], /move 1: nothing is accepted/],
    [[{ accept: ['Qh6'] }], /move 1: "Qh6" cannot be played/],
    [[{ accept: ['Qh5', 'Qh5'] }], /accepted twice/],
    [[{ accept: ['Qh5'], reply: 'g6' }, { accept: ['Qxe5+'], reply: 'Qe7' }], /move 2: the line ends on a reply/],
    // After ...g6 the pawn stands between the queen and f7.
    [[{ accept: ['Qh5'], reply: 'g6' }, { accept: ['Qxf7#'] }], /move 2: "Qxf7#" cannot be played/],
    [[{ accept: ['Qh5'], reply: 'Ke8' }, { accept: ['Qxe5+'] }], /the reply "Ke8" cannot be played/],
    [[{ accept: ['Qh5'] }, { accept: ['Qxe5+'] }], /no reply to go on from/],
  ];
  for (const [raw, why] of cases) {
    const read = readSolution(LINE, raw);
    assert.equal(read.ok, false, JSON.stringify(raw));
    assert.match(read.error, why);
  }
  // The alternative is checked where it is asked, not only the main move.
  assert.match(readSolution(LINE, [{ accept: ['Qh5', 'Qh6'] }]).error, /"Qh6"/);
});

test('a stored solution that does not replay makes the row unusable, not silently one-move', () => {
  const row = { fen: BACK_RANK, solution_san: 'Rd8#', solution: [{ accept: ['Qd8'] }] };
  assert.match(exerciseOf(row).problem, /does not replay/);
  assert.match(assignableProblem(row), /does not replay/);
});

test('a game task is read with the row\'s own position, by the engine-game parser', () => {
  const row = { fen: BACK_RANK, task: { type: 'game', side: 'w', goal: 'win' } };
  const read = exerciseOf(row);
  assert.equal(read.problem, null);
  assert.equal(read.task.type, 'game');
  assert.equal(read.task.goal, 'win');
  assert.equal(read.task.fen, BACK_RANK);
  assert.equal(read.solution, null);

  // A FEN smuggled into the task does not replace the row's.
  const other = exerciseOf({ fen: BACK_RANK, task: { type: 'game', side: 'w', goal: 'win', fen: LINE } });
  assert.equal(other.task.fen, BACK_RANK);

  assert.match(exerciseOf({ fen: BACK_RANK, task: { type: 'game', side: 'w', goal: 'crush' } }).problem,
    /cannot be played/);
  assert.match(exerciseOf({ fen: BACK_RANK, task: { type: 'essay' } }).problem, /nobody defined/);
});

test('a position with no solution cannot be set as homework', () => {
  assert.match(assignableProblem({ fen: BACK_RANK, solution_san: null, needs_review: false }), /has no solution/);
  assert.match(assignableProblem({}), /has no solution/);
});

test('a position still marked for review cannot be set either', () => {
  // Homework in front of a student is the last place to discover our own doubt.
  assert.match(assignableProblem({ fen: BACK_RANK, solution_san: 'Rd8#', needs_review: true }), /marked for review/);
});

test('a verified position is assignable', () => {
  assert.equal(assignableProblem({ fen: BACK_RANK, solution_san: 'Rd8#', needs_review: false }), null);
});

test('a game exercise is not a find-the-move item unless the caller can really send a game', () => {
  const game = { fen: BACK_RANK, task: { type: 'game', side: 'w', goal: 'win' }, needs_review: false };
  assert.match(assignableProblem(game), /cannot be answered with one move/);
  assert.equal(assignableProblem(game, { as: 'game' }), null);
  const find = { fen: BACK_RANK, solution_san: 'Rd8#', needs_review: false };
  assert.match(assignableProblem(find, { as: 'game' }), /cannot be played out/);
});

test('the column fragment names every column the reader reads', () => {
  assert.equal(exerciseColumns(), 'fen, task, solution, solution_san, needs_review');
  assert.equal(exerciseColumns('cp'), 'cp.fen, cp.task, cp.solution, cp.solution_san, cp.needs_review');
});
