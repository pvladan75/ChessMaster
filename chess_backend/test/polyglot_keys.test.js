// The server's Polyglot key against python-chess's, which built the database.
//
// Every expectation here was computed by python-chess
// (tools/opening_book/export_polyglot.py): every position of the ten harness
// games, and the cases those games may not reach — an en passant square with
// and without a pawn to take, castling rights the board cannot honour. A key
// that is wrong by one bit finds nothing, and nothing looks like a game that
// left the book on its first move.

const test = require('node:test');
const assert = require('node:assert/strict');

const { polyglotKey } = require('../services/mastersBook');
const RANDOM = require('../services/polyglotRandom');
const { cases } = require('./fixtures/polyglot_keys.json');

test('the table is Polyglot\'s: 781 numbers, first and last as published', () => {
  assert.equal(RANDOM.length, 781);
  assert.equal(RANDOM[0], 0x9d39247e33776d41n);
  assert.equal(RANDOM[780], 0xf8d626aaaf278509n);
});

test('every key python-chess computed is computed here', () => {
  assert.ok(cases.length > 700, 'the fixture holds the ten games');
  const wrong = cases.filter((c) => polyglotKey(c.fen).toString() !== c.key);
  assert.deepEqual(wrong.slice(0, 3), [], `${wrong.length} of ${cases.length} keys differ`);
});

test('an en passant square nobody can take changes nothing', () => {
  const written = 'rnbqkbnr/pppp1ppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
  const omitted = 'rnbqkbnr/pppp1ppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
  assert.equal(polyglotKey(written), polyglotKey(omitted));
});

test('an en passant square a pawn can take changes the key', () => {
  const written = 'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3';
  const omitted = 'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3';
  assert.notEqual(polyglotKey(written), polyglotKey(omitted));
});

test('a castling right the board cannot honour is not hashed', () => {
  // The FEN claims White may castle short with no rook on h1.
  const claimed = 'r3k2r/8/8/8/8/8/8/R3K3 w KQkq - 0 1';
  const honest = 'r3k2r/8/8/8/8/8/8/R3K3 w Qkq - 0 1';
  assert.equal(polyglotKey(claimed), polyglotKey(honest));
});
