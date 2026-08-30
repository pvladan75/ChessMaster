const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { frontier } = require('../services/repertoireFrontier');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

/// The FEN after a line of UCI moves from the start, and its repertoire key.
///
/// Computed rather than pasted. Every hand-written FEN in a test like this is a
/// chance to assert against a position that does not exist, and the walk being
/// tested would then be right while the test was wrong.
function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

function keyAfter(...ucis) {
  return fenKey(after(...ucis));
}

/// A pool that answers the two questions the walk asks, from tables held here.
///
/// Keyed rather than a list of canned results in order: the walk asks once per
/// level and the number of levels is what is being tested, so a stub that
/// replays answers positionally would pass for the wrong reason.
function stubPool({ moves = [], replies = [] } = {}) {
  let levels = 0;
  return {
    levels: () => levels,
    query: async (text, params) => {
      if (text.includes('FROM repertoire_moves')) {
        return { rows: moves, rowCount: moves.length };
      }
      if (text.includes('FROM opening_replies')) {
        levels += 1;
        const [band, keys] = params;
        const rows = replies.filter(
          (r) => Number(r.min_rating ?? 0) === band && keys.includes(r.fen_key),
        );
        return { rows, rowCount: rows.length };
      }
      throw new Error(`Neočekivan upit: ${text}`);
    },
  };
}

/// 1.e4, answered by 1...c5 (50%) and 1...e5 (20%).
/// Against the Sicilian the student plays 2.Nf3 and Black replies 2...d6 (60%),
/// leaving 1.e4 c5 2.Nf3 d6 unanswered at a reach of 0.30.
/// Against 1...e5 they have decided on 2.Bc4 but never took the replies.
function sicilianAndOpenGame() {
  return {
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'e7e5'), uci: 'f1c4', san: 'Bc4', role: 'primary' },
    ],
    replies: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', games: 500, share: '0.50000' },
      { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5', games: 200, share: '0.20000' },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
        uci: 'd7d6', san: 'd6', games: 300, share: '0.60000',
      },
      // Nothing for the position after 2.Bc4 — that branch was decided and
      // then left, which is the whole point of the second kind of open node.
    ],
  };
}

test('the queue comes back from what was stored, without asking Lichess', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 2);
  assert.equal(walk.summary.decided, 3);
  assert.equal(walk.summary.undecided, 1);
  assert.equal(walk.summary.unopened, 1);
  assert.equal(walk.summary.truncated, false);
});

test('the main line outranks a shallower sideline, because it is reached more', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  // 0.5 × 0.6 = 0.30 at ply four beats 0.20 at ply two. This is the whole
  // ordering: neither breadth-first nor depth-first, but how often a game
  // actually arrives — which goes deep down a main line and widens on its own
  // once that line's probability has decayed.
  const [first, second] = walk.open;
  assert.deepEqual(first.path, ['e4', 'c5', 'Nf3', 'd6']);
  assert.equal(first.ply, 4);
  assert.ok(Math.abs(first.reach - 0.3) < 1e-9, `reach je ${first.reach}`);
  assert.equal(first.kind, 'undecided');

  assert.deepEqual(second.path, ['e4', 'e5']);
  assert.ok(Math.abs(second.reach - 0.2) < 1e-9, `reach je ${second.reach}`);
});

test('a decided position whose replies were never taken comes back as unopened', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  const dangling = walk.open.find((node) => node.kind === 'unopened');
  assert.ok(dangling, 'grana bez knjige mora da se vrati');
  // The position handed back is the one *before* the student's move: that is
  // the board the build screen puts up, and where the button that takes the
  // replies lives. Handing back the position after 2.Bc4 would be a board the
  // screen cannot ask a question about.
  assert.deepEqual(dangling.path, ['e4', 'e5']);
  assert.equal(dangling.fenKey, keyAfter('e2e4', 'e7e5'));
});

test('a position reached two ways is queued once', async () => {
  // Black meets 1.e4 with 1...c5 and answers both 2.Nf3 and 2.Nc3 with 2...Nc6.
  // White's next move transposes the two: 2.Nf3 Nc6 3.Nc3 and 2.Nc3 Nc6 3.Nf3
  // are one board. A walk that queued it twice would ask the same question
  // twice and report a repertoire bigger than it is.
  const pool = stubPool({
    moves: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', role: 'primary' },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
        uci: 'b8c6', san: 'Nc6', role: 'primary',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'b1c3'),
        uci: 'b8c6', san: 'Nc6', role: 'primary',
      },
    ],
    replies: [
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        uci: 'g1f3', san: 'Nf3', games: 5, share: '0.50000',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        uci: 'b1c3', san: 'Nc3', games: 5, share: '0.50000',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6'),
        uci: 'b1c3', san: 'Nc3', games: 5, share: '1.00000',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6'),
        uci: 'g1f3', san: 'Nf3', games: 5, share: '1.00000',
      },
    ],
  });
  const walk = await frontier(pool, 7, {
    color: 'b', rootFen: after('e2e4'), rootPath: ['e4'],
  });

  const keys = walk.open.map((node) => node.fenKey);
  assert.equal(new Set(keys).size, keys.length, 'ista pozicija dva puta u redu');
  assert.equal(walk.open.length, 1, 'transpozicija je jedna pozicija, ne dve');
  assert.equal(
    walk.open[0].fenKey,
    keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6', 'b1c3'),
  );
});

test('the book is asked once per wave, not once per branch', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  await frontier(pool, 7, { color: 'w', rootFen: START });

  // Two: the wave after 1.e4, and the wave after 2.Nf3 / 2.Bc4. The last wave
  // has nothing decided in it, so there is no branch to look up and the walk
  // does not ask — five branches, two queries. That is the shape that keeps a
  // wide repertoire from turning one request into a minute of database time.
  assert.equal(pool.levels(), 2, `upita: ${pool.levels()}`);
});

test('an empty repertoire is a walk with one question in it', async () => {
  const pool = stubPool({ moves: [], replies: [] });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 1);
  assert.equal(walk.open[0].kind, 'undecided');
  assert.deepEqual(walk.open[0].path, []);
  assert.equal(walk.open[0].reach, 1);
  assert.equal(walk.summary.decided, 0);
});

test('the moves that led to the root travel with the walk', async () => {
  const pool = stubPool({ moves: [], replies: [] });
  const walk = await frontier(pool, 7, {
    color: 'b',
    rootFen: after('e2e4', 'c7c5', 'd2d4'),
    rootPath: ['e4', 'c5', 'd4'],
  });

  // Each node's own path starts at the root; the root's path is handed back
  // once. Without it a breadcrumb for a repertoire built from move four reads
  // as though the game began there.
  assert.deepEqual(walk.root.path, ['e4', 'c5', 'd4']);
  assert.deepEqual(walk.open[0].path, []);
});

test('a broken position is a bad request rather than an empty answer', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => frontier(pool, 7, { color: 'w', rootFen: 'nije fen' }),
    RangeError,
  );
  await assert.rejects(
    () => frontier(pool, 7, { color: 'x', rootFen: START }),
    RangeError,
  );
});

test('a move that no longer fits its position drops its branch, not the walk', async () => {
  // The repertoire is a graph keyed on positions, so this should not happen —
  // but a walk that throws here would take out the whole screen for one bad
  // row, and the rest of the repertoire is still worth showing.
  const pool = stubPool({
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
      { fen_key: fenKey(START), uci: 'h7h5', san: '??', role: 'alternate' },
    ],
    replies: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', games: 5, share: '1.00000' },
    ],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 1);
  assert.deepEqual(walk.open[0].path, ['e4', 'c5']);
});
