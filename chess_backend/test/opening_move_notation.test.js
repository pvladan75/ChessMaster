const test = require('node:test');
const assert = require('node:assert/strict');

const {
  standardUci, withStandardUci,
} = require('../services/openingMoveNotation');

/// Lichess writes castling as "king takes rook"; this application's board does
/// not. The difference is silent — a castling move in their notation is simply
/// unplayable here, so whatever tries to play it drops it — and it took a
/// reader looking at a screen to find it: the list said "O-O", and the line
/// under it said the move they had just played was not in the list.
const ITALIAN =
  'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2P2N2/PP1P1PPP/RNBQK2R w KQkq - 4 5';
const BLACK_TO_CASTLE =
  'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2P2N2/PP1P1PPP/RNBQ1RK1 b kq - 5 5';

test('castling comes back in this board\'s notation, not Lichess\'s', () => {
  // Verified against the live cloud evaluation on 25.8.2026, which answers with
  // `e1h1` and `e8h8` in its principal variations.
  assert.equal(standardUci(ITALIAN, 'O-O', 'e1h1'), 'e1g1');
  assert.equal(standardUci(BLACK_TO_CASTLE, 'O-O', 'e8h8'), 'e8g8');
});

test('an ordinary move is unchanged', () => {
  assert.equal(standardUci(ITALIAN, 'd4', 'd2d4'), 'd2d4');
  assert.equal(standardUci(ITALIAN, 'Bxf7+', 'c4f7'), 'c4f7');
});

test('a promotion keeps the piece it promotes to', () => {
  const fen = '8/P6k/8/8/8/8/7K/8 w - - 0 1';
  assert.equal(standardUci(fen, 'a8=Q', 'a7a8'), 'a7a8q');
});

test('a move that cannot be read here is passed through, not dropped', () => {
  // A book entry this server cannot parse is still a book entry the caller
  // asked about. Silently losing it would hide a move rather than report one.
  assert.equal(standardUci(ITALIAN, 'Qz9', 'x1y2'), 'x1y2');
  assert.equal(standardUci('nije fen', 'O-O', 'e1h1'), 'e1h1');
  assert.equal(standardUci(ITALIAN, '', 'e1h1'), 'e1h1');
});

test('a whole list is rewritten off one board', () => {
  const moves = [
    { uci: 'e1h1', san: 'O-O', games: 900 },
    { uci: 'd2d4', san: 'd4', games: 400 },
    { uci: 'c4f7', san: 'Bxf7+', games: 30 },
  ];

  const fixed = withStandardUci(ITALIAN, moves);

  assert.deepEqual(fixed.map((m) => m.uci), ['e1g1', 'd2d4', 'c4f7']);
  // Everything else rides along untouched.
  assert.equal(fixed[0].games, 900);
  assert.equal(fixed[0].san, 'O-O');
});

test('each move is taken back, so the list is read from one position', () => {
  // Without the undo the second move would be read from the position after the
  // first, and a legal list would come out mangled — quietly, since each move
  // would still parse.
  const moves = [
    { uci: 'e1h1', san: 'O-O' },
    { uci: 'e1h1', san: 'O-O' },
  ];

  assert.deepEqual(
    withStandardUci(ITALIAN, moves).map((m) => m.uci),
    ['e1g1', 'e1g1'],
  );
});

test('an empty list and a broken position answer without throwing', () => {
  assert.deepEqual(withStandardUci(ITALIAN, []), []);
  const moves = [{ uci: 'e1h1', san: 'O-O' }];
  assert.deepEqual(withStandardUci('nije fen', moves), moves);
});
