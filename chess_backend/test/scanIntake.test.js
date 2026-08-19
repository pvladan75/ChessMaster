const test = require('node:test');
const assert = require('node:assert/strict');

const {
  prepareRow,
  prepareRows,
  mergePlan,
  withSideToMove,
  solutionPlaysIn,
} = require('../services/scanIntake');

const MATE_IN_ONE = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

test('a valid position becomes a row, with the side taken from the FEN', () => {
  const row = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', page: 32, label: '97' });
  assert.equal(row.fen, MATE_IN_ONE);
  assert.equal(row.side, 'w');
  assert.equal(row.solutionSan, 'Qf1#');
  assert.equal(row.needsReview, false);
  assert.match(row.puzzleId, /^cust_[0-9a-f]{16}$/);
});

test('the side to move is never taken from the client, only from the FEN', () => {
  const row = prepareRow({ fen: MATE_IN_ONE, sideToMove: 'b', side: 'b' });
  assert.equal(row.side, 'w');
});

test('a FEN that is not a position is rejected and named', () => {
  const { rows, rejected } = prepareRows([
    { fen: MATE_IN_ONE },
    { fen: 'ovo nije fen' },
    { fen: '' },
    {},
  ]);
  assert.equal(rows.length, 1);
  assert.equal(rejected.length, 3);
  assert.deepEqual(rejected.map((r) => r.index), [1, 2, 3]);
  assert.ok(rejected[0].error.length > 0, 'a rejection must say why');
});

test('a solution that will not play is dropped, and the position is flagged', () => {
  // The board is fine; the move printed beside it was misread.
  const row = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Rh8#' });
  assert.equal(row.solutionSan, null, 'an unplayable move must not be stored as the solution');
  assert.equal(row.needsReview, true, 'and the position must carry the doubt forward');
});

test('a position with no solution at all is not flagged', () => {
  const row = prepareRow({ fen: MATE_IN_ONE });
  assert.equal(row.solutionSan, null);
  assert.equal(row.needsReview, false);
});

test("the trainer's own doubt survives a solution that verifies", () => {
  const row = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', needsReview: true });
  assert.equal(row.solutionSan, 'Qf1#');
  assert.equal(row.needsReview, true);
});

test('themes are trimmed, capped and stripped of anything that is not a string', () => {
  const row = prepareRow({
    fen: MATE_IN_ONE,
    themes: ['  mateIn1 ', '', null, 42, 'x'.repeat(60), ...Array(20).fill('pin')],
  });
  assert.equal(row.themes[0], 'mateIn1');
  assert.ok(row.themes.every((t) => typeof t === 'string' && t.length <= 40));
  assert.ok(row.themes.length <= 12);
});

test('castling rights the scanner restored survive intake', () => {
  // Diagram 305 of the first test book: mate in one by castling. If the rights
  // are lost anywhere along the way the puzzle becomes unsolvable.
  const fen = '8/8/8/8/8/5N2/1pr3PP/r1k1K2R w K - 0 1';
  const row = prepareRow({ fen, solutionSan: 'O-O#' });
  assert.equal(row.solutionSan, 'O-O#');
  assert.equal(row.fen.split(' ')[2], 'K');
  assert.equal(row.needsReview, false);
});

test('a re-scan fills a gap without touching what is already there', () => {
  // Measured on a real overlap: the same diagram arrived twice with identical
  // boards, but only one copy carried the solution.
  const existing = { fen: MATE_IN_ONE, solution_san: null, themes: [] };
  const incoming = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', themes: ['mateIn1'] });
  const plan = mergePlan(existing, incoming);
  assert.equal(plan.action, 'fill');
  assert.equal(plan.fields.solution_san, 'Qf1#');
  assert.deepEqual(plan.fields.themes, ['mateIn1']);
  assert.equal(plan.fields.needs_review, false, 'a verified solution settles the doubt');
});

test('a re-scan never overwrites a value that is already set', () => {
  // The trainer may have corrected this by hand; a scanner reading the same
  // page again does not outrank them.
  const existing = { fen: MATE_IN_ONE, solution_san: 'Qf1#', themes: ['moja-tema'] };
  const incoming = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Qf1#', themes: ['druga'] });
  assert.equal(mergePlan(existing, incoming).action, 'unchanged');
});

test('a solution that will not play in the stored position is a conflict, not a fill', () => {
  // Most likely the two disagree about whose move it is. Reported, not smoothed.
  const existing = { fen: MATE_IN_ONE, solution_san: null, themes: [] };
  const incoming = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Qf1#' });
  const stored = { ...existing, fen: MATE_IN_ONE.replace(' w ', ' b ') };
  const plan = mergePlan(stored, incoming);
  assert.equal(plan.action, 'conflict');
  assert.equal(plan.fields.solution_san, undefined, 'nothing may be written on a conflict');
});

test('nothing to add means nothing changes', () => {
  const existing = { fen: MATE_IN_ONE, solution_san: null, themes: [] };
  const incoming = prepareRow({ fen: MATE_IN_ONE });
  assert.equal(mergePlan(existing, incoming).action, 'unchanged');
});

test('settling the side rewrites the FEN and drops the en passant square', () => {
  // The en passant square records the other side's last move; keeping it after
  // the mover changes makes the position illegal.
  const fen = 'rb6/k1p4R/P1P5/PpK5/8/8/8/5B2 w - b6 0 1';
  const flipped = withSideToMove(fen, 'b');
  assert.equal(flipped.split(' ')[1], 'b');
  assert.equal(flipped.split(' ')[3], '-');
  assert.equal(flipped.split(' ')[0], fen.split(' ')[0], 'the pieces must not move');
});

test('settling the side keeps castling rights', () => {
  const fen = '8/8/8/8/8/5N2/1pr3PP/r1k1K2R w K - 0 1';
  assert.equal(withSideToMove(fen, 'b').split(' ')[2], 'K');
});

test('an answer that is not a side is refused', () => {
  assert.throws(() => withSideToMove(MATE_IN_ONE, 'beli'), /mora biti/);
  assert.throws(() => withSideToMove(MATE_IN_ONE, ''), /mora biti/);
});

test('a position with no solution is not in doubt, only unfinished', () => {
  // The two states must not share a warning: nothing here disagrees with
  // anything, there is simply nothing recorded yet.
  assert.equal(solutionPlaysIn(MATE_IN_ONE, null), true);
  assert.equal(solutionPlaysIn(MATE_IN_ONE, ''), true);
});

test('settling the side can break a stored solution, and that must stay visible', () => {
  const white = MATE_IN_ONE;
  const black = white.replace(' w ', ' b ');
  assert.equal(solutionPlaysIn(white, 'Qf1#'), true);
  assert.equal(solutionPlaysIn(black, 'Qf1#'), false,
    'flipping the side made the stored move unplayable — the flag must not be cleared');
});

test('a conflict names the likely cause instead of just refusing', () => {
  // Measured on a real re-scan: all nine conflicts were positions stored with
  // the wrong side, where the book's move plays perfectly once flipped.
  const stored = { fen: MATE_IN_ONE.replace(' w ', ' b '), solution_san: null, themes: [] };
  const incoming = prepareRow({ fen: MATE_IN_ONE, solutionSan: 'Qf1#' });
  const plan = mergePlan(stored, incoming);

  assert.equal(plan.action, 'conflict');
  assert.equal(plan.sideLikelyWrong, true);
  assert.match(plan.reason, /druga strana/);
});

test('a conflict with no such explanation says only what it knows', () => {
  // Built by hand rather than through prepareRow, which drops a move that will
  // not play in its own position — so this shape can only reach mergePlan from
  // a row written before that check existed.
  const stored = { fen: MATE_IN_ONE, solution_san: null, themes: [] };
  const plan = mergePlan(stored, { solutionSan: 'Rh8#', themes: [] });

  assert.equal(plan.action, 'conflict');
  assert.ok(!plan.sideLikelyWrong, 'flipping the side does not rescue this one');
  assert.match(plan.reason, /ne igra/);
});
