// puzzle_selection.test.js
// Covers how a puzzle's solution is decoded and how the next one is chosen —
// the two places where a silent mistake would either show the user the wrong
// position or train them on the wrong thing forever.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  splitSolution,
  trainableThemes,
  pickTargetTheme,
  ratingBand,
  toClientPuzzle,
  MIN_ATTEMPTS_FOR_WEAKNESS,
  TRAINABLE_THEMES,
} = require('../services/puzzleSelectionService');

const { parseRow } = require('../import_lichess_puzzles');

test('the first move is the opponent\'s mistake, not part of the solution', () => {
  // From the real dataset: FEN is before f2g3; the puzzle starts after it.
  const split = splitSolution('f2g3 e6e7 b2b1 b3c1 b1c1 h6c1');

  assert.equal(split.setupMove, 'f2g3');
  assert.deepEqual(split.solution, ['e6e7', 'b2b1', 'b3c1', 'b1c1', 'h6c1']);
  // Treating the setup move as the answer is the classic way to get this wrong.
  assert.equal(split.userMoves[0], 'e6e7');
  assert.deepEqual(split.userMoves, ['e6e7', 'b3c1', 'h6c1']);
  assert.deepEqual(split.opponentMoves, ['b2b1', 'b1c1']);
});

test('a degenerate move line yields no solution rather than a wrong one', () => {
  assert.deepEqual(splitSolution('').solution, []);
  assert.equal(splitSolution('e2e4').setupMove, null);
  assert.equal(splitSolution(null).setupMove, null);
});

test('only skill themes are kept for rating', () => {
  const kept = trainableThemes(['crushing', 'hangingPiece', 'long', 'middlegame', 'fork', 'master']);
  // Outcome, length and provenance tags describe the puzzle, not an ability.
  assert.deepEqual(kept.sort(), ['fork', 'hangingPiece']);
  assert.deepEqual(trainableThemes(undefined), []);
});

test('the weakest sufficiently-measured theme is chosen', () => {
  const themeRatings = { fork: 1600, pin: 1200, skewer: 1450 };
  const themeAttempts = { fork: 20, pin: 20, skewer: 20 };

  // random() = 0.99 keeps exploration out of the way.
  const picked = pickTargetTheme(themeRatings, themeAttempts, { random: () => 0.99 });
  assert.equal(picked, 'pin');
});

test('a theme with too few attempts is not treated as a weakness', () => {
  const themeRatings = { fork: 1600, pin: 900 };
  const themeAttempts = { fork: 20, pin: MIN_ATTEMPTS_FOR_WEAKNESS - 1 };

  const picked = pickTargetTheme(themeRatings, themeAttempts, { random: () => 0.99 });
  // One unlucky puzzle must not brand a motif as the user's weakness.
  assert.equal(picked, 'fork');
});

test('a user with no history explores instead of returning nothing', () => {
  const picked = pickTargetTheme({}, {}, { random: () => 0.5 });
  assert.ok(TRAINABLE_THEMES.includes(picked), 'must pick some trainable theme');
});

test('exploration serves an untried theme, not the known weakest', () => {
  const themeRatings = { fork: 1000 };
  const themeAttempts = { fork: 50 };

  // random() = 0 forces the exploration branch and selects the first untried.
  const explored = pickTargetTheme(themeRatings, themeAttempts, { random: () => 0 });
  assert.notEqual(explored, 'fork');
  assert.ok(TRAINABLE_THEMES.includes(explored));
});

test('once every theme is measured, exploration cannot break the pick', () => {
  const themeRatings = {};
  const themeAttempts = {};
  for (const theme of TRAINABLE_THEMES) {
    themeRatings[theme] = 1500;
    themeAttempts[theme] = 10;
  }
  themeRatings.zugzwang = 1100;

  // Even with random() = 0, there is nothing untried to explore into.
  assert.equal(pickTargetTheme(themeRatings, themeAttempts, { random: () => 0 }), 'zugzwang');
});

test('the rating band sits slightly below the user and widens on retry', () => {
  const first = ratingBand(1500, 0);
  const second = ratingBand(1500, 1);

  // Centred just under the user's rating: a training set should be mostly solvable.
  assert.ok(first.max - 1500 < 1500 - first.min, 'band must lean below the user rating');
  assert.ok(second.max - second.min > first.max - first.min, 'retry must widen the search');
  assert.ok(ratingBand(500, 2).min >= 400, 'band must not fall below the dataset floor');
});

test('a database row becomes a client payload with the solution split out', () => {
  const payload = toClientPuzzle({
    puzzle_id: '00008',
    fen: 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24',
    moves: 'f2g3 e6e7 b2b1 b3c1 b1c1 h6c1',
    rating: 1939,
    popularity: 95,
    nb_plays: 10000,
    themes: ['crushing', 'hangingPiece', 'long', 'middlegame'],
    game_url: 'https://lichess.org/787zsVup/black#48',
    opening_tags: null,
  });

  assert.equal(payload.source, 'lichess');
  assert.equal(payload.setup_move, 'f2g3');
  assert.equal(payload.rating, 1939);
  assert.deepEqual(payload.trainable_themes, ['hangingPiece']);
  assert.deepEqual(payload.opening_tags, []);
});

test('a real CSV line parses into the columns the importer writes', () => {
  const row = parseRow(
    '00008,r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24,f2g3 e6e7 b2b1 b3c1 b1c1 h6c1,1939,77,95,10000,crushing hangingPiece long middlegame,https://lichess.org/787zsVup/black#48,,'
  );

  assert.equal(row.puzzleId, '00008');
  assert.equal(row.rating, 1939);
  assert.equal(row.popularity, 95);
  assert.deepEqual(row.themes, ['crushing', 'hangingPiece', 'long', 'middlegame']);
  assert.deepEqual(row.openingTags, []);
});

test('an opening-tagged row keeps its tags as an array', () => {
  const row = parseRow(
    '0000D,5rk1/1p3ppp/pq3b2/8/8/1P1Q1N2/P4PPP/3R2K1 w - - 2 27,d3d6 f8d8 d6d8 f6d8,1559,74,96,37137,advantage endgame short,https://lichess.org/F8M8OS71#53,Italian_Game Italian_Game_Classical_Variation,'
  );

  assert.deepEqual(row.openingTags, ['Italian_Game', 'Italian_Game_Classical_Variation']);
});

test('malformed rows are rejected instead of imported as garbage', () => {
  assert.equal(parseRow(''), null);
  assert.equal(parseRow('too,few,columns'), null);
  // A non-numeric rating would otherwise land in the table as NaN.
  assert.equal(parseRow('id,fen,moves,notanumber,77,95,100,fork,url,,'), null);
});
