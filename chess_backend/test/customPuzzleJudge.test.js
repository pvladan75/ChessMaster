const test = require('node:test');
const assert = require('node:assert/strict');

const { judgeAttempt, assignableProblem, bareSan } = require('../services/customPuzzleJudge');

// Diagram 97 of the trainer's first scanned set: white mates with Qf1#, and it
// is the only mate there.
const MATE_IN_ONE = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

// Diagram 122 of the same set. The book prints Qe6#, but Qh7# mates just as
// well — one of four such positions in 198, so about two per cent of this
// homework would have called a correct mate wrong.
const TWO_MATES = '6R1/5k2/8/4K3/8/7Q/8/8 w - - 0 1';

test("the author's own move is right", () => {
  const r = judgeAttempt({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', moveSan: 'Qf1#' });
  assert.equal(r.correct, true);
  assert.equal(r.playedSan, 'Qf1#');
});

test('decoration on the move does not decide anything', () => {
  // The board already knows whether a move checks or mates; the suffix a
  // student's client happens to send must not change the verdict.
  assert.equal(judgeAttempt({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', moveSan: 'Qf1' }).correct, true);
  assert.equal(bareSan('Qf1#'), bareSan('Qf1'));
});

test('a different mate is still a mate, and the task was to mate', () => {
  // The heart of it: a child who finds the other mate has solved the exercise,
  // and telling them otherwise teaches them to distrust the app.
  const r = judgeAttempt({ fen: TWO_MATES, solutionSan: 'Qe6#', moveSan: 'Qh7#' });
  assert.equal(r.correct, true);
  assert.equal(r.reason, 'drugi mat, ali mat');
});

test('an underpromotion that mates counts too', () => {
  // Diagram 220: the book promotes to a queen, a rook mates as well.
  const fen = 'r2qk2r/pbppPppp/1p6/8/2P2n1Q/BP6/P4PPP/3RR1K1 w - - 0 1';
  assert.equal(judgeAttempt({ fen, solutionSan: 'exd8=Q#', moveSan: 'exd8=R#' }).correct, true);
});

test('a move that does not mate is wrong even though it is legal', () => {
  const r = judgeAttempt({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', moveSan: 'Qh8' });
  assert.equal(r.correct, false);
  assert.equal(r.playedSan, 'Qh8', 'what was actually tried is worth recording');
});

test('an impossible move is refused without pretending it was played', () => {
  const r = judgeAttempt({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', moveSan: 'Ra1' });
  assert.equal(r.correct, false);
  assert.equal(r.playedSan, null);
  assert.match(r.reason, /nije moguć/);
});

test('when the task was not a mate, only the printed move counts', () => {
  // Nothing here knows what else the position was meant to teach, so the
  // author's move is the only safe answer.
  const fen = '8/8/8/8/8/8/4k3/4K2R w K - 0 1';
  const r = judgeAttempt({ fen, solutionSan: 'O-O', moveSan: 'Rh2+' });
  assert.equal(r.correct, false);
});

test('a position with no solution cannot be set as homework', () => {
  assert.match(assignableProblem({ solution_san: null, needs_review: false }), /nema rešenje/);
});

test('a position still marked for review cannot be set either', () => {
  // Homework in front of a child is the last place to discover our own doubt.
  assert.match(assignableProblem({ solution_san: 'Qf1#', needs_review: true }), /proveru/);
});

test('a verified position is assignable', () => {
  assert.equal(assignableProblem({ solution_san: 'Qf1#', needs_review: false }), null);
});
