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
/// `extras` are the opponent moves the student entered; `book` is what the
/// opening book says about positions, joined in for its numbers only. Keyed
/// rather than a list of canned results in order: the walk asks once per level
/// and the number of levels is what is being tested.
function stubPool({ moves = [], extras = [], book = [] } = {}) {
  let levels = 0;
  const calls = [];
  return {
    calls,
    levels: () => levels,
    query: async (text, params) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      if (flat.includes('FROM repertoire_moves')) {
        // The decisions-only condition is honoured here only when the query
        // asks for it, so taking it out of the query lets a draft through.
        const rows = flat.includes("source = 'chosen'")
          ? moves.filter((m) => (m.source ?? 'chosen') === 'chosen')
          : moves;
        return { rows, rowCount: rows.length };
      }
      if (flat.includes('FROM repertoire_extra_replies e')) {
        levels += 1;
        const keys = params[2];
        const rows = extras
          .filter((e) => keys.includes(e.fen_key))
          .map((e) => {
            const known = book.find(
              (b) => b.fen_key === e.fen_key && b.uci === e.uci);
            return {
              ...e,
              games: known ? known.games : 0,
              share: known ? known.share : 0,
            };
          })
          .sort((a, b) => b.games - a.games);
        return { rows, rowCount: rows.length };
      }
      throw new Error(`Unexpected query: ${flat}`);
    },
  };
}

/// 1.e4; the student entered 1...c5 and 1...e5 for Black. Against the Sicilian
/// they play 2.Nf3 and entered 2...d6, which they have not answered yet.
/// Against 1...e5 they play 2.Bc4 and entered nothing after it.
function sicilianAndOpenGame() {
  return {
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'e7e5'), uci: 'f1c4', san: 'Bc4', role: 'primary' },
    ],
    extras: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5' },
      { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5' },
      { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'), uci: 'd7d6', san: 'd6' },
    ],
    book: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', games: 500, share: '0.50000' },
      { fen_key: keyAfter('e2e4'), uci: 'e7e5', games: 200, share: '0.20000' },
      { fen_key: keyAfter('e2e4'), uci: 'e7e6', games: 150, share: '0.15000' },
      { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'), uci: 'd7d6', games: 300, share: '0.60000' },
    ],
  };
}

test('the queue is the positions after entered moves that have no answer yet',
  async () => {
    const pool = stubPool(sicilianAndOpenGame());
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    assert.deepEqual(walk.open.map((n) => n.path), [['e4', 'c5', 'Nf3', 'd6']]);
    assert.equal(walk.open[0].kind, 'undecided');
    assert.equal(walk.summary.decided, 3);
    assert.equal(walk.summary.open, 1);
    assert.equal(walk.summary.truncated, false);
  });

test('a move of the student\'s with nothing entered after it ends the line',
  async () => {
    // 2.Bc4 has no reply entered. That is where the repertoire stops, not a
    // question: the book's replies are a reference, and a line the student has
    // not extended is not work the app invents for them.
    const pool = stubPool(sicilianAndOpenGame());
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    assert.equal(walk.open.some((n) => n.path.includes('e5')), false);
  });

test('the book decides nothing: a reply it knows and nobody entered is not walked',
  async () => {
    // 1...e6 is in the book at 15% and was never entered.
    const pool = stubPool(sicilianAndOpenGame());
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    assert.equal(walk.open.some((n) => n.path.includes('e6')), false);
    assert.equal(walk.branches.some((b) => b.key === 'e4 e6'), false);
  });

test('an opponent move the book does not know is walked like any other',
  async () => {
    const base = sicilianAndOpenGame();
    const pool = stubPool({
      ...base,
      extras: [...base.extras, { fen_key: keyAfter('e2e4'), uci: 'a7a6', san: 'a6' }],
    });
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    const added = walk.open.find((n) => n.path.includes('a6'));
    assert.ok(added, 'a move the book has never seen was dropped');
    assert.deepEqual(added.path, ['e4', 'a6']);
    const branch = walk.branches.find((b) => b.key === 'e4 a6');
    assert.equal(branch.share, 0);
  });

test('open positions come back shallower first', async () => {
  const base = sicilianAndOpenGame();
  const pool = stubPool({
    ...base,
    extras: [...base.extras, { fen_key: keyAfter('e2e4'), uci: 'a7a6', san: 'a6' }],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.deepEqual(walk.open.map((n) => n.ply), [2, 4]);
});

test('a position reached two ways is queued once', async () => {
  // Black meets 1.e4 with 1...c5 and answers both 2.Nf3 and 2.Nc3 with 2...Nc6.
  // White's next move transposes the two: 2.Nf3 Nc6 3.Nc3 and 2.Nc3 Nc6 3.Nf3
  // are one board. A walk that queued it twice would ask the same question
  // twice and report a repertoire bigger than it is.
  const pool = stubPool({
    moves: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'), uci: 'b8c6', san: 'Nc6', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'c7c5', 'b1c3'), uci: 'b8c6', san: 'Nc6', role: 'primary' },
    ],
    extras: [
      { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3' },
      { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'b1c3', san: 'Nc3' },
      { fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6'), uci: 'b1c3', san: 'Nc3' },
      { fen_key: keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6'), uci: 'g1f3', san: 'Nf3' },
    ],
  });
  const walk = await frontier(pool, 7, {
    color: 'b', rootFen: after('e2e4'), rootPath: ['e4'],
  });

  const keys = walk.open.map((node) => node.fenKey);
  assert.equal(new Set(keys).size, keys.length, 'one position queued twice');
  assert.equal(walk.open.length, 1, 'a transposition is one position, not two');
  assert.equal(
    walk.open[0].fenKey,
    keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6', 'b1c3'),
  );
});

test('the entered moves are asked for once per wave, not once per branch',
  async () => {
    const pool = stubPool(sicilianAndOpenGame());
    await frontier(pool, 7, { color: 'w', rootFen: START });

    // Two: the wave after 1.e4, and the wave after 2.Nf3 / 2.Bc4. The last wave
    // has nothing decided in it, so there is nothing to look up.
    assert.equal(pool.levels(), 2, `queries: ${pool.levels()}`);
  });

test('the entered moves are read for this student and this colour', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  await frontier(pool, 7, { color: 'w', rootFen: START });

  const read = pool.calls.find((c) => c.text.includes('repertoire_extra_replies'));
  assert.deepEqual(read.params.slice(0, 2), [7, 'w']);
  // The book is joined at its one band and its own source, and only there.
  assert.match(read.text, /LEFT JOIN opening_replies/);
  assert.deepEqual(read.params.slice(3, 5), [0, 'book']);
});

test('a move the retired spine wrote is not a decision and is not walked',
  async () => {
    const base = sicilianAndOpenGame();
    const pool = stubPool({
      ...base,
      moves: base.moves.map((m) => (
        m.fen_key === keyAfter('e2e4', 'c7c5') ? { ...m, source: 'auto' } : m)),
    });
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    assert.equal(walk.summary.decided, 2);
    assert.deepEqual(walk.open.map((n) => n.path), [['e4', 'c5']]);
  });

test('an empty repertoire is a walk with one question in it', async () => {
  const pool = stubPool();
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 1);
  assert.equal(walk.open[0].kind, 'undecided');
  assert.deepEqual(walk.open[0].path, []);
  assert.equal(walk.summary.decided, 0);
  assert.deepEqual(walk.branches, []);
});

test('the moves that led to the root travel with the walk', async () => {
  const pool = stubPool();
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
    () => frontier(pool, 7, { color: 'w', rootFen: 'not a fen' }),
    RangeError,
  );
  await assert.rejects(
    () => frontier(pool, 7, { color: 'x', rootFen: START }),
    RangeError,
  );
});

test('a move that no longer fits its position drops its branch, not the walk', async () => {
  // A walk that throws here would take out the whole screen for one bad row,
  // and the rest of the repertoire is still worth showing.
  const pool = stubPool({
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
      { fen_key: fenKey(START), uci: 'h7h5', san: '??', role: 'alternate' },
    ],
    extras: [{ fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5' }],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 1);
  assert.deepEqual(walk.open[0].path, ['e4', 'c5']);
});

test('the walk counts how far each of the opponent\'s answers has been taken',
  async () => {
    // A branch is one of the opponent's first answers: the student's own first
    // move is decided, and it is the opponent's choice that names the thing.
    const pool = stubPool(sicilianAndOpenGame());
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    // Most played first.
    assert.deepEqual(walk.branches.map((b) => b.key), ['e4 c5', 'e4 e5']);
    const [sicilian, openGame] = walk.branches;
    assert.equal(sicilian.share, 0.5);
    assert.equal(sicilian.maxPly, 4);
    assert.equal(sicilian.decided, 1);
    assert.equal(sicilian.open, 1);
    assert.equal(openGame.decided, 1);
    assert.equal(openGame.open, 0);
    assert.equal('found' in sicilian, false, 'the ordering key leaked out');
  });

test('the answer carries counts and no book-weighted percentages', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.deepEqual(Object.keys(walk.summary).sort(),
    ['decided', 'maxPly', 'open', 'truncated']);
  assert.equal('reach' in walk.open[0], false);
});
