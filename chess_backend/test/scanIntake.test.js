const test = require('node:test');
const assert = require('node:assert/strict');

const { prepareRow, prepareRows } = require('../services/scanIntake');

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
