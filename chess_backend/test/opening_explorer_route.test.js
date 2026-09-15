// GET /opening-explorer — one position, answered from the file on this server.
//
// The route used to be a proxy in front of the Lichess explorer, on a token
// every student shared. It reads `services/openingBook.js` now
// (`docs/PLAN-OTVARANJA-LOKALNO.md`), and what is asked here is what the
// module being right cannot say: that the route is mounted and behind sign-in,
// that the arithmetic it does on top of the module is the arithmetic a panel
// needs, and that each refusal becomes an answer a client can act on.

const test = require('node:test');
const assert = require('node:assert/strict');

// Requiring a route drags in the whole server chain, and `middleware/auth`
// calls process.exit at import without this.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/openingExplorer');
const { authenticateToken } = require('../middleware/auth');
const { createOpeningBook, OpeningBookUnavailable } = require('../services/openingBook');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const move = (san, games) => ({
  uci: 'a1a2', san, white: games, draws: 0, black: 0,
});

function layer() {
  const found = router.stack.find(
    (l) => l.route && l.route.path === '/' && l.route.methods.get
  );
  assert.ok(found, 'GET /opening-explorer must be mounted');
  return found.route.stack.map((s) => s.handle);
}

/// Calls the handler itself, past the sign-in and the limiter in front of it.
async function ask(query) {
  const handlers = layer();
  const res = {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  await handlers[handlers.length - 1]({ query }, res);
  return res;
}

/// A book that answers [here] for any position, restored when the test ends.
function bookAnswering(t, here) {
  const asked = [];
  router.useOpeningBook({
    answer: (fen) => {
      asked.push(fen);
      if (typeof here === 'function') return here(fen);
      return here;
    },
  });
  t.after(() => router.useOpeningBook(createOpeningBook({ path: '' })));
  return asked;
}

test('the opening book is behind sign-in', () => {
  assert.equal(layer()[0], authenticateToken);
});

test('a position answers in the shape the app parses', async (t) => {
  bookAnswering(t, {
    white: 40, draws: 30, black: 30, unlisted: 0, beyondBook: false,
    moves: [move('e4', 60), move('d4', 40)],
  });
  const res = await ask({ fen: START });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.fen, START);
  assert.deepEqual(
    [res.body.white, res.body.draws, res.body.black], [40, 30, 30]
  );
  assert.deepEqual(res.body.moves.map((m) => m.san), ['e4', 'd4']);
  // The file holds no names. The app names the position from the ECO data it
  // already ships, which is where the tutorial's names come from too.
  assert.equal(res.body.opening, null);
});

test('the count is the position, and the moves shown are what fits the limit', async (t) => {
  // 200 games reached this position; the two moves asked for hold 150 of them,
  // a third holds 40, and ten are in rows a pruned file no longer lists.
  bookAnswering(t, {
    white: 200, draws: 0, black: 0, unlisted: 10, beyondBook: false,
    moves: [move('e4', 100), move('d4', 50), move('Nf3', 40)],
  });
  const res = await ask({ fen: START, moves: '2' });
  assert.deepEqual(res.body.moves.map((m) => m.san), ['e4', 'd4']);
  assert.deepEqual(
    [res.body.white, res.body.draws, res.body.black], [200, 0, 0]
  );
  // Everything the panel is not being shown: the trimmed move and the pruned
  // rows together. A panel that subtracts what it can see from the total gets
  // this number; one that is told a smaller total draws the wrong shares.
  assert.equal(res.body.unlisted, 50);
});

test('the number of moves is bounded at both ends', async (t) => {
  const many = Array.from({ length: 40 }, (_, i) => move(`m${i}`, 40 - i));
  bookAnswering(t, {
    white: 820, draws: 0, black: 0, unlisted: 0, beyondBook: false, moves: many,
  });
  assert.equal((await ask({ fen: START })).body.moves.length, 12);
  assert.equal((await ask({ fen: START, moves: '0' })).body.moves.length, 12);
  assert.equal((await ask({ fen: START, moves: '-5' })).body.moves.length, 12);
  assert.equal((await ask({ fen: START, moves: '99' })).body.moves.length, 30);
  assert.equal((await ask({ fen: START, moves: 'many' })).body.moves.length, 12);
});

test('a position past the end of the file is an answer, not a failure', async (t) => {
  // "This file does not go that far" and "nobody played this" are two
  // different sentences, and the panel can only write them apart if the
  // difference survives the route.
  bookAnswering(t, {
    white: 0, draws: 0, black: 0, unlisted: 0, beyondBook: true, moves: [],
  });
  const res = await ask({ fen: START });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.beyondBook, true);
  assert.deepEqual(res.body.moves, []);
});

test('the rating filter is gone, and two values answer the same', async (t) => {
  // An older app still sends `minRating`. There is one book, so it selects
  // nothing — and this is what stops the next reader believing it still does.
  const asked = bookAnswering(t, {
    white: 10, draws: 0, black: 0, unlisted: 0, beyondBook: false,
    moves: [move('e4', 10)],
  });
  const low = await ask({ fen: START, minRating: '1600' });
  const high = await ask({ fen: START, minRating: '2500' });
  assert.deepEqual(low.body, high.body);
  assert.deepEqual(asked, [START, START]);
});

test('a FEN that is not a position is a bad request', async (t) => {
  bookAnswering(t, () => { throw new RangeError('Not a position: x'); });
  const res = await ask({ fen: 'not a fen' });
  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /position/i);
});

test('a missing FEN is the caller’s mistake, not an empty book', async (t) => {
  bookAnswering(t, () => { throw new RangeError('Not a position: '); });
  assert.equal((await ask({})).statusCode, 400);
});

test('a server with no file says so, with a reason', async (t) => {
  // Loud on purpose: a missing file looks exactly like an opening nobody has
  // ever played, and only this tells them apart afterwards.
  bookAnswering(t, () => {
    throw new OpeningBookUnavailable('The opening database is not configured on this server.',
      { reason: 'not-configured', status: 503 });
  });
  const res = await ask({ fen: START });
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.reason, 'not-configured');
});

test('anything else is a 500 and not a stack trace', async (t) => {
  bookAnswering(t, () => { throw new Error('disk on fire'); });
  const res = await ask({ fen: START });
  assert.equal(res.statusCode, 500);
  assert.doesNotMatch(JSON.stringify(res.body), /disk on fire/);
});

test('nothing in this route reaches Lichess any more', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'openingExplorer.js'), 'utf8'
  );
  // Asked of the code and not of the prose: the header explains what this
  // route used to be, and a test that matched the word would fail the
  // explanation. Same family as the gate that failed a comment saying why
  // `PgnExporterService` is *not* called.
  const code = source
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/\s\/\/.*$/gm, '');
  assert.doesNotMatch(code, /lichess/i);
  assert.doesNotMatch(code, /fetch\s*\(/);
  assert.doesNotMatch(code, /openingExplorerService/);
  // And the service it used to call is gone rather than left unreferenced,
  // where the next reader would find a cache and a pacer nothing runs.
  assert.equal(
    fs.existsSync(path.join(__dirname, '..', 'services', 'openingExplorerService.js')),
    false
  );
});
