const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { buildSpine, MIN_SPINE_GAMES } = require('../services/repertoireSpine');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

/// A book that answers from a table keyed by position, and counts what it was
/// asked. How many requests a spine costs is one of the things being tested, so
/// a stub replaying answers in order would pass for the wrong reason.
function stubJudge(byKey, { games = 5000 } = {}) {
  const asked = [];
  return {
    asked,
    replies: async (fen) => {
      asked.push(fenKey(fen));
      const uci = byKey[fenKey(fen)];
      if (!uci) return { fen, minRating: 1600, all: [], replies: [] };
      const board = new Chess(fen);
      const played = board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
      const top = {
        uci, san: played.san, games, share: 0.5, covered: true,
      };
      return { fen, minRating: 1600, all: [top], replies: [top] };
    },
  };
}

/// A pool that remembers the moves written into it, and answers `nodeMoves`
/// from what is there — so "the spine does not overwrite a decision" is a
/// property of the run rather than of a canned answer.
function stubPool({ moves = [] } = {}) {
  const rows = [...moves];
  const calls = [];
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (flat.includes('SELECT uci, san, role, verdict, source')) {
      const [, , key] = params;
      const here = rows.filter((r) => r.fen_key === key);
      return { rows: here, rowCount: here.length };
    }
    if (flat.startsWith('SELECT 1 FROM repertoire_moves')) {
      const [, , key] = params;
      const primary = rows.filter(
        (r) => r.fen_key === key && r.role === 'primary');
      return { rows: primary, rowCount: primary.length };
    }
    if (flat.includes('INSERT INTO repertoire_moves')) {
      const [, , key, uci, san, role, verdict, source] = params;
      const row = {
        fen_key: key, uci, san, role, verdict, source, added_at: new Date(),
      };
      rows.push(row);
      return { rows: [row], rowCount: 1 };
    }
    if (flat.includes('DELETE FROM opening_replies')
        || flat.includes('INSERT INTO opening_replies')
        || flat === 'BEGIN' || flat === 'COMMIT' || flat === 'ROLLBACK') {
      return { rows: [], rowCount: 0 };
    }
    throw new Error(`Neočekivan upit: ${flat}`);
  };
  return {
    rows,
    calls,
    query,
    connect: async () => ({ query, release: () => {} }),
    written: () => rows.filter((r) => r.source === 'auto').length,
  };
}

/// 1.e4 e5 2.Nf3 Nc6 — the most played move at every turn.
const OPEN_GAME = {
  [fenKey(START)]: 'e2e4',
  [fenKey(after('e2e4'))]: 'e7e5',
  [fenKey(after('e2e4', 'e7e5'))]: 'g1f3',
  [fenKey(after('e2e4', 'e7e5', 'g1f3'))]: 'b8c6',
};

test('a spine writes the trunk, both sides, to the depth asked for', async () => {
  // The whole point: a trunk in one action instead of thirty questions before
  // anything looks like an opening.
  const pool = stubPool();
  const judge = stubJudge(OPEN_GAME);
  const out = await buildSpine(pool, 7, {
    color: 'w', rootFen: START, depth: 2, judge,
  });

  assert.deepEqual(out.path, ['e4', 'e5', 'Nf3', 'Nc6']);
  assert.equal(out.plies, 4);
  assert.equal(out.written, 2);
  assert.equal(out.stopped.reason, 'depth');
});

test('everything a spine writes is a draft', async () => {
  // The column exists because of this function. A move nobody chose must never
  // be able to look like a decision — that is the archive seed's failure, and
  // a spine writes moves the student did not choose too.
  const pool = stubPool();
  const out = await buildSpine(pool, 7, {
    color: 'w', rootFen: START, depth: 2, judge: stubJudge(OPEN_GAME),
  });

  assert.equal(out.written, 2);
  assert.equal(pool.written(), 2);
  assert.equal(pool.rows.every((r) => r.source === 'auto'), true);
});

test('a spine never overwrites a decision, and follows it instead', async () => {
  // What makes it safe to re-run, and what makes "continue from here" the same
  // operation as "start here".
  const pool = stubPool({
    moves: [{
      fen_key: fenKey(START), uci: 'd2d4', san: 'd4',
      role: 'primary', source: 'chosen',
    }],
  });
  const judge = stubJudge({
    ...OPEN_GAME,
    [fenKey(after('d2d4'))]: 'd7d5',
  });
  const out = await buildSpine(pool, 7, {
    color: 'w', rootFen: START, depth: 1, judge,
  });

  // 1.d4 was the student's, so the book was never asked about the root.
  assert.equal(out.followed, 1);
  assert.equal(out.written, 0);
  assert.deepEqual(out.path, ['d4', 'd5']);
  assert.equal(judge.asked.includes(fenKey(START)), false,
    'kičma je pitala knjigu o poziciji o kojoj je učenik već odlučio');
});

test('a line that runs thin stops, and the answer says where and why',
  async () => {
    // Top-1 at ply twenty is sometimes forty games. A spine that ran to the
    // depth it was asked for regardless would hand back authoritative-looking
    // noise, which is every silent truncation this codebase has had to fix.
    const pool = stubPool();
    const judge = stubJudge(OPEN_GAME, { games: 30 });
    const out = await buildSpine(pool, 7, {
      color: 'w', rootFen: START, depth: 6, judge, minGames: 100,
    });

    assert.equal(out.stopped.reason, 'thin');
    assert.equal(out.stopped.games, 30);
    assert.equal(out.written, 0);
    assert.deepEqual(out.path, []);
  });

test('a position the book knows nothing about stops the spine', async () => {
  const pool = stubPool();
  const out = await buildSpine(pool, 7, {
    color: 'w', rootFen: START, depth: 4, judge: stubJudge({}),
  });

  assert.equal(out.stopped.reason, 'thin');
  assert.equal(out.stopped.games, 0);
});

test('the book is asked twice per move and never twice about one position',
  async () => {
    // One token serves every child using this app, so what a spine costs is
    // part of what it is.
    const pool = stubPool();
    const judge = stubJudge(OPEN_GAME);
    await buildSpine(pool, 7, {
      color: 'w', rootFen: START, depth: 2, judge });

    assert.equal(judge.asked.length, 4, `upita: ${judge.asked.length}`);
    assert.equal(new Set(judge.asked).size, 4);
  });

test('every book a spine opens is stored on the way past', async () => {
  // It had to be fetched anyway, and storing it is what makes the drill and the
  // derived queue free afterwards.
  const pool = stubPool();
  await buildSpine(pool, 7, {
    color: 'w', rootFen: START, depth: 1, judge: stubJudge(OPEN_GAME),
  });

  const stored = pool.calls.filter(
    (c) => c.text.includes('INSERT INTO opening_replies')).length;
  assert.equal(stored, 2);
});

test('the depth and the floor are clamped rather than trusted', async () => {
  const pool = stubPool();
  const out = await buildSpine(pool, 7, {
    color: 'w', rootFen: START, depth: 999, minGames: 0,
    judge: stubJudge({}),
  });

  assert.equal(out.minGames, 5);
  assert.equal(out.stopped.reason, 'thin');
});

test('a colour that is not a colour, and a position that is not one, are refused',
  async () => {
    const pool = stubPool();
    await assert.rejects(
      () => buildSpine(pool, 7, { color: 'white', rootFen: START }), RangeError);
    await assert.rejects(
      () => buildSpine(pool, 7, { color: 'w', rootFen: 'nije fen' }), RangeError);
    assert.equal(pool.calls.length, 0);
  });

test('the floor a spine defaults to is not the judge\'s', () => {
  // The judge's five answers "is this played at all". This one answers "is this
  // still the main line", and eighty games is not a main line.
  assert.equal(MIN_SPINE_GAMES, 100);
});
