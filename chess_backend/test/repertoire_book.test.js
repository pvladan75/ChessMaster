// The book beside the board, and the one opponent move it enters
// (docs/PLAN-REPERTOAR-RUCNO.md). Two rules, and each has a way to go wrong
// quietly: a book that has to be opened by hand, and a top reply that comes
// back after the student deleted it.

const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { bookAt, keepMove } = require('../services/repertoireBook');
const { fenKey } = require('../services/repertoireService');
const { OpeningBookUnavailable } = require('../services/openingBook');

const START = new Chess().fen();

function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

/// The tables `keepMove` and `bookAt` touch, held here.
function stubPool({ kept = [], extras = [], book = {} } = {}) {
  const state = {
    kept: new Set(kept),
    extras: [...extras],
    book: { ...book },
    remembered: 0,
  };
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    if (flat.startsWith('SELECT 1 FROM repertoire_moves')) {
      const rowCount = state.kept.size > 0 ? 1 : 0;
      return { rows: [], rowCount };
    }
    if (flat.startsWith('INSERT INTO repertoire_moves')) {
      const uci = params[3];
      const inserted = !state.kept.has(uci);
      state.kept.add(uci);
      return {
        rows: [{ uci, san: params[4], role: params[5], inserted }],
        rowCount: 1,
      };
    }
    // Before the entered moves: the book's own read mentions
    // `repertoire_extra_replies e` inside its subquery, and matched second it
    // would be answered as the other query.
    if (flat.includes('FROM opening_replies r')) {
      const rows = (state.book[params[0]] ?? [])
        .map((r) => ({ covered: false, prepared: false, ...r }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('FROM repertoire_extra_replies e')) {
      const keys = params[2];
      const rows = state.extras
        .filter((e) => keys.includes(e.fen_key))
        .map((e) => ({ games: 0, share: 0, ...e }));
      return { rows, rowCount: rows.length };
    }
    if (flat.startsWith('INSERT INTO repertoire_extra_replies')) {
      state.extras.push({ fen_key: params[2], uci: params[3], san: params[4] });
      return { rows: [{}], rowCount: 1 };
    }
    if (flat.startsWith('DELETE FROM opening_replies')) {
      return { rows: [], rowCount: 0 };
    }
    if (flat.startsWith('INSERT INTO opening_replies')) {
      state.remembered += 1;
      const rows = [];
      for (let at = 3; at < params.length; at += 5) {
        rows.push({
          uci: params[at], san: params[at + 1], games: params[at + 2], share: params[at + 3],
        });
      }
      state.book[params[0]] = rows.sort((a, b) => b.games - a.games);
      return { rows: [], rowCount: rows.length };
    }
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(flat)) {
      return { rows: [], rowCount: 0 };
    }
    throw new Error(`Unexpected query: ${flat}`);
  };
  return { state, query, connect: async () => ({ query, release: () => {} }) };
}

/// A judge whose book answers with a fixed list of replies, and counts how
/// often it was asked.
function judgeWith(all) {
  const judge = {
    asked: 0,
    replies: async (fen) => {
      judge.asked += 1;
      return { fen, total: 100, beyondBook: false, replies: [], all };
    },
  };
  return judge;
}

const E4_REPLIES = [
  { uci: 'c7c5', san: 'c5', games: 500, share: 0.5, covered: true },
  { uci: 'e7e5', san: 'e5', games: 300, share: 0.3, covered: true },
];

test('a new move enters the book\'s most played reply after it', async () => {
  const pool = stubPool();
  const out = await keepMove(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', judge: judgeWith(E4_REPLIES),
  });

  assert.deepEqual(out.topReply, { uci: 'c7c5', san: 'c5', fen: after('e2e4') });
  assert.deepEqual(pool.state.extras,
    [{ fen_key: fenKey(after('e2e4')), uci: 'c7c5', san: 'c5' }]);
});

test('only the one reply: the second most played is left to the student',
  async () => {
    const pool = stubPool();
    await keepMove(pool, 7, {
      color: 'w', fen: START, uci: 'e2e4', san: 'e4', judge: judgeWith(E4_REPLIES),
    });

    assert.equal(pool.state.extras.some((e) => e.uci === 'e7e5'), false);
  });

test('a move played again does not bring back a reply the student deleted',
  async () => {
    const pool = stubPool({ kept: ['e2e4'] });
    const judge = judgeWith(E4_REPLIES);
    const out = await keepMove(pool, 7, {
      color: 'w', fen: START, uci: 'e2e4', san: 'e4', judge,
    });

    assert.equal(out.topReply, null);
    assert.deepEqual(pool.state.extras, []);
    assert.equal(judge.asked, 0, 'the book is not read for a move already kept');
  });

test('a position the student already entered replies in is left as it is',
  async () => {
    // Reached by transposition, with the student's own reply already there.
    const pool = stubPool({
      extras: [{ fen_key: fenKey(after('e2e4')), uci: 'e7e5', san: 'e5' }],
    });
    const out = await keepMove(pool, 7, {
      color: 'w', fen: START, uci: 'e2e4', san: 'e4', judge: judgeWith(E4_REPLIES),
    });

    assert.equal(out.topReply, null);
    assert.equal(pool.state.extras.length, 1);
  });

test('a position the book has no games for enters nothing', async () => {
  const pool = stubPool();
  const out = await keepMove(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', judge: judgeWith([]),
  });

  assert.equal(out.topReply, null);
  assert.deepEqual(pool.state.extras, []);
});

test('the book is read on first sight and stored, and not asked again', async () => {
  const pool = stubPool();
  const judge = judgeWith(E4_REPLIES);
  const first = await bookAt(pool, 7, { color: 'b', fen: after('e2e4'), judge });
  const second = await bookAt(pool, 7, { color: 'b', fen: after('e2e4'), judge });

  assert.equal(first.opened, true);
  assert.deepEqual(first.replies.map((r) => r.uci), ['c7c5', 'e7e5']);
  assert.equal(second.opened, true);
  assert.equal(judge.asked, 1);
  assert.equal(pool.state.remembered, 1);
});

test('a book that cannot be read says so instead of an empty list', async () => {
  const pool = stubPool();
  const judge = {
    replies: async () => {
      throw new OpeningBookUnavailable('No book here.', {
        reason: 'not-configured', status: 503,
      });
    },
  };
  const out = await bookAt(pool, 7, { color: 'b', fen: after('e2e4'), judge });

  assert.equal(out.opened, false);
  assert.equal(out.unavailable, 'not-configured');
});

test('any other failure of the book is not swallowed', async () => {
  const pool = stubPool();
  const judge = { replies: async () => { throw new Error('boom'); } };
  await assert.rejects(
    () => bookAt(pool, 7, { color: 'b', fen: after('e2e4'), judge }),
    /boom/,
  );
});
