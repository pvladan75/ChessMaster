// The masters walk over a database built here, in the shape the extraction
// writes: `position_stats (zobrist, move, w, b, d)`, one row per position and
// move, the move packed as from | to << 6 | promotion << 12.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  createOpeningBook, polyglotKey, plyOf, OpeningBookUnavailable, MAX_POSITIONS,
} = require('../services/openingBook');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const AFTER_E4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
const AFTER_E4_E5 = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
const CASTLE = 'r3k2r/pppqbppp/2np1n2/4p3/4P3/2NP1N2/PPPQBPPP/R3K2R w KQkq - 4 8';
const PROMOTE = '4k3/1P6/8/8/8/8/8/4K3 w - - 0 1';

const sq = (name) => (name.charCodeAt(0) - 97) + 8 * (Number(name[1]) - 1);
const code = (from, to, promotion = 0) => sq(from) | (sq(to) << 6) | (promotion << 12);

/// A database file with [rows] = [fen, from, to, promotion, w, b, d], removed
/// when the test [t] ends.
function bookWith(t, rows) {
  const { DatabaseSync } = require('node:sqlite');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'masters-book-'));
  const file = path.join(dir, 'book.sqlite');
  const db = new DatabaseSync(file);
  db.exec(`CREATE TABLE position_stats (zobrist INTEGER, move INTEGER, w INTEGER,
           b INTEGER, d INTEGER, PRIMARY KEY (zobrist, move)) WITHOUT ROWID`);
  const insert = db.prepare('INSERT INTO position_stats VALUES (?, ?, ?, ?, ?)');
  for (const [fen, from, to, promotion, w, b, d] of rows) {
    insert.run(polyglotKey(fen), code(from, to, promotion), w, b, d);
  }
  db.close();
  const book = createOpeningBook({ path: file });
  // Closed before it is removed: Windows will not delete an open file.
  t.after(() => {
    book.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });
  return book;
}

test('a position answers in the explorer\'s shape, most-played first', (t) => {
  const book = bookWith(t, [
    [START, 'd2', 'd4', 0, 30, 20, 50],
    [START, 'e2', 'e4', 0, 40, 30, 60],
    [START, 'g1', 'f3', 0, 5, 5, 10],
  ]);
  const here = book.answer(START);
  assert.deepEqual(here.moves.map((m) => m.san), ['e4', 'd4', 'Nf3']);
  assert.deepEqual(here.moves[0], { uci: 'e2e4', san: 'e4', white: 40, draws: 60, black: 30 });
  assert.deepEqual([here.white, here.draws, here.black], [75, 120, 55]);
});

test('castling and promotion are read from the packed move', (t) => {
  const book = bookWith(t, [
    [CASTLE, 'e1', 'g1', 0, 3, 1, 2],
    [CASTLE, 'e1', 'c1', 0, 1, 1, 1],
    [PROMOTE, 'b7', 'b8', 5, 4, 0, 0],
    [PROMOTE, 'b7', 'b8', 2, 1, 0, 0],
  ]);
  assert.deepEqual(book.answer(CASTLE).moves.map((m) => m.san), ['O-O', 'O-O-O']);
  const promoted = book.answer(PROMOTE).moves;
  assert.deepEqual(promoted.map((m) => [m.san, m.uci]), [['b8=Q+', 'b7b8q'], ['b8=N', 'b7b8n']]);
});

test('a move the position cannot play is left out, not named', (t) => {
  const book = bookWith(t, [
    [START, 'e2', 'e4', 0, 1, 0, 0],
    [START, 'e1', 'e5', 0, 9, 9, 9], // shares the key, is not this position's
  ]);
  assert.deepEqual(book.answer(START).moves.map((m) => m.san), ['e4']);
  assert.equal(book.answer(START).white, 1);
});

test('the walk answers in order and stops at the first position nobody reached', (t) => {
  const book = bookWith(t, [
    [START, 'e2', 'e4', 0, 2, 1, 1],
    [AFTER_E4, 'e7', 'e5', 0, 1, 1, 0],
  ]);
  // AFTER_E4_E5 is not in the book. START comes after it in the list and is in
  // the book, and must not be reported: the walk ends at the first gap.
  const later = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2';
  const { positions } = book.walk([START, AFTER_E4, AFTER_E4_E5, START, later]);
  assert.deepEqual(positions.map((p) => p.fen), [START, AFTER_E4]);
  assert.equal(positions[1].moves[0].san, 'e5');
});

test('the walk answers exactly what the app is tested against (shared fixture)', (t) => {
  // chess_app/test/game_tutorial_masters_walk_test.dart reads `answer` from the
  // same file as the server's reply. If this answer changes shape, this test
  // goes red before the app reads something it was never tested with.
  const fixture = require('./fixtures/masters_walk_answer.json');
  const book = bookWith(t, fixture.rows);
  assert.deepEqual(book.walk(fixture.fens), fixture.answer);
});

test('a walk that is not a list of positions is refused as a bad request', (t) => {
  const book = bookWith(t, [[START, 'e2', 'e4', 0, 1, 0, 0]]);
  assert.throws(() => book.walk([]), RangeError);
  assert.throws(() => book.walk('fen'), RangeError);
  assert.throws(() => book.walk([START, 42]), RangeError);
  assert.throws(() => book.walk(['not a fen']), RangeError);
  assert.throws(() => book.walk(Array(MAX_POSITIONS + 1).fill(START)), RangeError);
});

test('no database configured is a sentence and a 503, not a crash', () => {
  const book = createOpeningBook({ path: '' });
  assert.throws(() => book.walk([START]), (err) => err instanceof OpeningBookUnavailable
    && err.reason === 'not-configured' && err.status === 503);
});

test('a database that cannot be opened says so', () => {
  const book = createOpeningBook({
    path: 'somewhere.sqlite',
    openDatabase: () => { throw new Error('ENOENT'); },
  });
  assert.throws(() => book.walk([START]), (err) => err instanceof OpeningBookUnavailable
    && err.reason === 'unreadable');
});

// --- What a built file can carry: the counts it kept, and how deep it goes ---
//
// `docs/PLAN-OTVARANJA-LOKALNO.md`. A file may have had every row played by a
// single game deleted; the number of games a position was reached is then in a
// table of its own. And every file stops after a fixed number of half-moves, so
// a position past that is one it cannot speak about rather than one nobody
// played.

/// A database with [rows] as above, plus optional `meta` and `position_totals`.
function fileWith(t, { rows = [], meta = null, totals = null }) {
  const { DatabaseSync } = require('node:sqlite');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'opening-book-'));
  const file = path.join(dir, 'book.sqlite');
  const db = new DatabaseSync(file);
  db.exec(`CREATE TABLE position_stats (zobrist INTEGER, move INTEGER, w INTEGER,
           b INTEGER, d INTEGER, PRIMARY KEY (zobrist, move)) WITHOUT ROWID`);
  const insert = db.prepare('INSERT INTO position_stats VALUES (?, ?, ?, ?, ?)');
  for (const [fen, from, to, promotion, w, b, d] of rows) {
    insert.run(polyglotKey(fen), code(from, to, promotion), w, b, d);
  }
  if (meta) {
    db.exec('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
    const put = db.prepare('INSERT INTO meta VALUES (?, ?)');
    for (const [key, value] of Object.entries(meta)) put.run(key, String(value));
  }
  if (totals) {
    db.exec(`CREATE TABLE position_totals (zobrist INTEGER PRIMARY KEY,
             w INTEGER, b INTEGER, d INTEGER) WITHOUT ROWID`);
    const put = db.prepare('INSERT INTO position_totals VALUES (?, ?, ?, ?)');
    for (const [fen, w, b, d] of totals) put.run(polyglotKey(fen), w, b, d);
  }
  db.close();
  const book = createOpeningBook({ path: file });
  t.after(() => {
    book.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });
  return book;
}

test('a pruned file answers with the games it counted, not the ones it kept', (t) => {
  // Two moves survived with 90 games between them; the position was reached
  // 100 times, and the other ten are in rows that were deleted.
  const book = fileWith(t, {
    rows: [[START, 'e2', 'e4', 0, 30, 20, 10], [START, 'd2', 'd4', 0, 10, 10, 10]],
    meta: { max_ply: 50, pruned: 1 },
    totals: [[START, 45, 35, 20]],
  });
  const here = book.answer(START);
  assert.deepEqual([here.white, here.black, here.draws], [45, 35, 20]);
  assert.equal(here.unlisted, 10);
  assert.deepEqual(here.moves.map((m) => m.san), ['e4', 'd4']);
});

test('a file with no totals answers from its rows, as it always did', (t) => {
  const book = fileWith(t, {
    rows: [[START, 'e2', 'e4', 0, 30, 20, 10]],
  });
  const here = book.answer(START);
  assert.deepEqual([here.white, here.black, here.draws], [30, 20, 10]);
  assert.equal(here.unlisted, 0);
});

test('a file that says it was pruned and kept no totals is refused', (t) => {
  // Every number it gave would be too small, and nothing would say so.
  assert.throws(
    () => fileWith(t, {
      rows: [[START, 'e2', 'e4', 0, 30, 20, 10]],
      meta: { max_ply: 50, pruned: 1 },
    }).answer(START),
    (err) => err instanceof OpeningBookUnavailable && err.reason === 'inconsistent'
  );
});

test('a position past the last ply is not a position nobody played', (t) => {
  const book = fileWith(t, { rows: [[START, 'e2', 'e4', 0, 5, 5, 5]], meta: { max_ply: 30 } });
  // Ply 30 is White to move on move 16 — the first position a 30-ply file
  // cannot have seen.
  assert.equal(book.answer('8/8/4k3/8/8/4K3/8/8 w - - 0 16').beyondBook, true);
  assert.equal(book.answer('8/8/4k3/8/8/4K3/8/8 b - - 0 15').beyondBook, false);
  assert.equal(book.answer(START).beyondBook, false);
});

test('a FEN that is not a position is a bad request, not an empty book', (t) => {
  const book = fileWith(t, { rows: [[START, 'e2', 'e4', 0, 5, 5, 5]] });
  assert.throws(() => book.answer('not a fen'), RangeError);
  assert.throws(() => book.answer(''), RangeError);
  // The key of a malformed FEN is a number like any other; answering it would
  // have read as „nobody has ever played this".
  assert.throws(() => book.answer('8/8/8/8/8/8/8/8 w - - 0 1'), RangeError);
});

test('the ply is counted from the move number and whose move it is', () => {
  // Asked directly, because through a threshold the two halves of the sum
  // cannot be told apart: a file 30 plies deep answers the same for 28 and 29.
  assert.equal(plyOf(START), 0);
  assert.equal(plyOf(AFTER_E4), 1);
  assert.equal(plyOf(AFTER_E4_E5), 2);
  assert.equal(plyOf('8/8/4k3/8/8/4K3/8/8 b - - 0 15'), 29);
  assert.equal(plyOf('8/8/4k3/8/8/4K3/8/8 w - - 0 16'), 30);
  // A position that does not say where it stands is not one this file can
  // place past its own end.
  assert.equal(plyOf('8/8/4k3/8/8/4K3/8/8 w - -'), null);
  assert.equal(plyOf('8/8/4k3/8/8/4K3/8/8 w - - 0 0'), null);
});

test('a file that does not say how deep it goes never claims a position is past it', (t) => {
  const book = fileWith(t, { rows: [[START, 'e2', 'e4', 0, 5, 5, 5]] });
  assert.equal(book.answer('8/8/4k3/8/8/4K3/8/8 w - - 0 60').beyondBook, false);
});

test('the walk says why it stopped, and the three reasons are different', (t) => {
  const book = fileWith(t, {
    rows: [[START, 'e2', 'e4', 0, 5, 5, 5], [AFTER_E4, 'e7', 'e5', 0, 4, 4, 4]],
    meta: { max_ply: 30 },
  });
  assert.equal(book.walk([START, AFTER_E4]).stoppedBecause, 'end');
  assert.equal(book.walk([START, AFTER_E4, AFTER_E4_E5]).stoppedBecause, 'unplayed');
  assert.equal(book.walk([START, '8/8/4k3/8/8/4K3/8/8 w - - 0 16']).stoppedBecause,
    'beyond-book');
});

test('a walked position carries only the five keys the app was tested with', (t) => {
  // `walkMastersBook` copies a position whole into the facts a tutorial is
  // built from and a model is asked about. A field added to `answer` must not
  // arrive there because somebody spread it.
  const book = fileWith(t, {
    rows: [[START, 'e2', 'e4', 0, 5, 5, 5]],
    meta: { max_ply: 50, pruned: 1 },
    totals: [[START, 6, 5, 5]],
  });
  const { positions } = book.walk([START]);
  assert.deepEqual(Object.keys(positions[0]).sort(),
    ['black', 'draws', 'fen', 'moves', 'white']);
});

test('the file says what it is, and a file that says nothing says so', (t) => {
  const built = fileWith(t, {
    rows: [[START, 'e2', 'e4', 0, 5, 5, 5]],
    meta: { min_elo: 2200, elo_rule: 'min', max_ply: 50, pruned: 1 },
    totals: [[START, 5, 5, 5]],
  });
  assert.deepEqual(built.describe(),
    { minElo: 2200, eloRule: 'min', maxPly: 50, pruned: true });

  const plain = fileWith(t, { rows: [[START, 'e2', 'e4', 0, 5, 5, 5]] });
  assert.deepEqual(plain.describe(),
    { minElo: null, eloRule: null, maxPly: null, pruned: false });
});
