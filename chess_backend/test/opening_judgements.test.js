// opening_judgements.test.js — what the device's engine hands in about a
// player's habits, what is refused, and how it reaches the report
// (docs/PLAN-MOJE-PARTIJE.md §9.2). The upsert's depth rule and the ownership
// check run on a real database in opening_judgements_db.test.js.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  recordJudgements, attachJudgements, attachBookCounts, losingHabits,
  whyNotStorable, MAX_ITEMS_PER_CALL,
} = require('../services/openingJudgements');
const { leakReport } = require('../services/openingLeaks');
const { OpeningBookUnavailable } = require('../services/openingBook');

// After 1.e4 e5: White to move.
const KEY = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6';
const OTHER_KEY = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -';

function item(over = {}) {
  return {
    fenKey: KEY,
    moveUci: 'f1c4',
    wBest: 55.1,
    wMove: 52.0,
    bestUci: 'g1f3',
    bestLine: ['Nf3', 'Nc6', 'Bb5'],
    moveLine: ['Bc4', 'Nf6', 'd3'],
    verdict: 'holds',
    reason: null,
    bookGames: 5120,
    lossCp: 40,
    engine: '123-456',
    depth: 20,
    ...over,
  };
}

/// Answers the two statements the store issues. `reached` are the positions
/// the caller has; `insertedOf` decides, for each offered row, whether it came
/// back as a new row, an update, or nothing (a deeper one kept it out).
function stubPool({ reached = [KEY], answer = (n) => Array(n).fill({ inserted: true }) } = {}) {
  const calls = [];
  return {
    calls,
    query: async (text, params = []) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      if (/SELECT DISTINCT fen_key FROM opening_nodes/.test(flat)) {
        const asked = params[1] || [];
        const rows = asked.filter((k) => reached.includes(k)).map((fen_key) => ({ fen_key }));
        return { rows, rowCount: rows.length };
      }
      if (/INSERT INTO opening_judgements/.test(flat)) {
        const rows = answer(params.length / 14);
        return { rows, rowCount: rows.length };
      }
      return { rows: [], rowCount: 0 };
    },
  };
}

// ---- what is refused ------------------------------------------------------------

test('a judgement that holds up has no reason to be refused', () => {
  assert.equal(whyNotStorable(item()), null);
  assert.equal(whyNotStorable(item({
    verdict: 'mistake', reason: 'lostChances', wMove: 40,
  })), null);
});

test('each thing a device could get wrong is refused by name', () => {
  const cases = [
    [null, 'not-an-object'],
    [item({ fenKey: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq' }), 'no-position'],
    [item({ moveUci: 'e1e3' }), 'illegal-move'],
    [item({ bestUci: 'a1a5' }), 'illegal-best'],
    // The line must start with the move it is the line of.
    [item({ bestLine: ['Nc3', 'Nc6'] }), 'best-line-does-not-replay'],
    [item({ bestLine: ['Nf3', 'Qxf7'] }), 'best-line-does-not-replay'],
    [item({ moveLine: [] }), 'move-line-does-not-replay'],
    [item({ moveLine: ['Bc4', 'Bc4'] }), 'move-line-does-not-replay'],
    [item({ wBest: 100.5 }), 'not-chances'],
    [item({ wMove: -1 }), 'not-chances'],
    [item({ wMove: '40' }), 'not-chances'],
    [item({ verdict: 'blunder' }), 'no-verdict'],
    // A mistake says why; a move that holds has nothing to say.
    [item({ verdict: 'mistake', reason: null }), 'no-reason'],
    [item({ verdict: 'holds', reason: 'lostChances' }), 'no-reason'],
    [item({ depth: 0 }), 'no-depth'],
    [item({ depth: 20.5 }), 'no-depth'],
    [item({ engine: ' ' }), 'no-engine'],
    [item({ bookGames: -1 }), 'no-book-count'],
    // The drill ranks by it (§9.4); a judgement without it cannot be drilled.
    [item({ lossCp: undefined }), 'no-loss-cp'],
    [item({ lossCp: -5 }), 'no-loss-cp'],
    [item({ lossCp: 12.5 }), 'no-loss-cp'],
  ];
  for (const [it, reason] of cases) {
    assert.equal(whyNotStorable(it), reason, JSON.stringify(it));
  }
});

// ---- the tally ----------------------------------------------------------------------

test('a batch comes back as a tally that adds up', async () => {
  const pool = stubPool({
    answer: () => [{ inserted: true }, { inserted: false }],
  });
  const tally = await recordJudgements(pool, 5, [
    item(),
    item({ moveUci: 'g1f3', moveLine: ['Nf3', 'Nc6'] }),
    item({ moveUci: 'e1e3' }),
  ]);
  assert.deepEqual(tally, {
    read: 3, stored: 1, replaced: 1, kept_deeper: 0, rejected: 1,
    rejected_by_reason: { 'illegal-move': 1 },
  });
});

test('a position the caller never reached is refused, and never asked to be stored', async () => {
  const pool = stubPool({ reached: [] });
  const tally = await recordJudgements(pool, 5, [item()]);
  assert.equal(tally.rejected_by_reason['position-not-yours'], 1);
  assert.equal(pool.calls.filter((c) => /INSERT/.test(c.text)).length, 0);
  // The ownership question names the caller.
  assert.equal(pool.calls[0].params[0], 5);
});

test('two judgements of one move in one batch: the deeper is offered, the other counted', async () => {
  const pool = stubPool();
  const tally = await recordJudgements(pool, 5, [item({ depth: 18 }), item({ depth: 22 })]);
  const insert = pool.calls.find((c) => /INSERT/.test(c.text));
  assert.equal(insert.params.length, 14, 'one row offered');
  assert.equal(insert.params[13], 22, 'the deeper one');
  assert.equal(tally.stored, 1);
  assert.equal(tally.kept_deeper, 1);
});

test('a row the database kept out for a deeper one is counted, not lost', async () => {
  const pool = stubPool({ answer: () => [] });
  const tally = await recordJudgements(pool, 5, [item()]);
  assert.equal(tally.kept_deeper, 1);
  assert.equal(tally.stored + tally.replaced + tally.kept_deeper + tally.rejected, tally.read);
});

test('the upsert keeps a deeper judgement in its own WHERE', async () => {
  const pool = stubPool();
  await recordJudgements(pool, 5, [item()]);
  const insert = pool.calls.find((c) => /INSERT/.test(c.text));
  assert.match(insert.text, /WHERE opening_judgements\.depth <= EXCLUDED\.depth/);
});

test('too many at once is a refusal, not a truncation', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => recordJudgements(pool, 5, Array(MAX_ITEMS_PER_CALL + 1).fill(item())),
    RangeError,
  );
});

// ---- the book on the node list --------------------------------------------------

function nodes() {
  return [{
    fenKey: KEY,
    fen: `${KEY} 0 1`,
    ply: 3,
    games: 20,
    score: 0.4,
    moves: [
      { san: 'Nf3', games: 12, score: 0.5, share: 0.6, habit: true },
      { san: 'Bc4', games: 8, score: 0.25, share: 0.4, habit: true },
    ],
  }];
}

test('each move carries how many master games played it, and its UCI', () => {
  const n = nodes();
  const book = {
    answer: () => ({ moves: [{ uci: 'g1f3', white: 100, draws: 50, black: 30 }] }),
  };
  assert.deepEqual(attachBookCounts(n, book), { available: true });
  assert.equal(n[0].moves[0].bookGames, 180);
  assert.equal(n[0].moves[0].uci, 'g1f3');
  assert.equal(n[0].moves[1].bookGames, 0, 'a move the book does not list');
  assert.equal(n[0].moves[1].uci, 'f1c4');
});

test('a book that cannot answer is said, and no count reads as zero', () => {
  const n = nodes();
  const book = {
    answer: () => { throw new OpeningBookUnavailable('no book', { reason: 'not-configured' }); },
  };
  assert.deepEqual(attachBookCounts(n, book), { available: false, reason: 'not-configured' });
  assert.equal(n[0].moves[0].bookGames, null);
  assert.equal(n[0].moves[1].bookGames, null);
});

// ---- judgements on the report --------------------------------------------------------

function judgedPool(rows) {
  return {
    query: async (text, params) => {
      assert.equal(params[0], 5, 'the caller\'s judgements, nobody else\'s');
      return { rows, rowCount: rows.length };
    },
  };
}

test('a move never judged carries null, never „holds"', async () => {
  const n = nodes();
  await attachJudgements(judgedPool([{
    fen_key: KEY, move_uci: 'f1c4', w_best: 55, w_move: 40, best_uci: 'g1f3',
    best_line: ['Nf3'], move_line: ['Bc4'], verdict: 'mistake', reason: 'lostChances',
    book_games: 5, engine: 'e', depth: 20,
  }]), 5, n);
  assert.equal(n[0].moves[0].judgement, null);
  assert.equal(n[0].moves[1].judgement.verdict, 'mistake');
  assert.equal(n[0].moves[1].judgement.bestSan, 'Nf3');
  assert.equal(n[0].moves[1].judgement.lostChances, 15);
});

test('losing habits: judged mistakes among habits, whatever the score, costliest first', () => {
  const judged = (verdict, lost) => ({ verdict, lostChances: lost });
  const list = losingHabits([
    {
      fenKey: 'a', fen: 'a 0 1', ply: 8, games: 30, score: 0.7,
      moves: [
        { san: 'x', games: 10, habit: true, judgement: judged('mistake', 12) },
        { san: 'y', games: 2, habit: false, judgement: judged('mistake', 40) },
      ],
    },
    {
      fenKey: 'b', fen: 'b 0 1', ply: 6, games: 20, score: 0.3,
      moves: [
        { san: 'z', games: 6, habit: true, judgement: judged('mistake', 30) },
        { san: 'w', games: 9, habit: true, judgement: judged('holds', 2) },
        { san: 'v', games: 5, habit: true, judgement: null },
      ],
    },
  ]);
  assert.deepEqual(list.map((h) => h.san), ['z', 'x'],
    'a move played twice is not a habit, a move that holds is not losing, one never judged is neither');
  assert.equal(list[1].nodeScore, 0.7, 'a node the score calls fine is listed');
  assert.equal(list[0].cost, 180);
});

// ---- the habit, one home ------------------------------------------------------------

test('a habit is played at least three times and in at least a tenth of the node', async () => {
  const row = (san, games, key = KEY, nodeGames = 40) => ({
    rk: key === KEY ? 1 : 2, fen_key: key, node_games: nodeGames, node_points: '16.0',
    node_ply: 3, san, move_games: games, move_points: '1.0',
  });
  const pool = {
    query: async (text) => {
      if (/COUNT\(\*\) FILTER/.test(text)) return { rows: [{ games: 52, without_nodes: 0 }] };
      return {
        rows: [
          row('Nf3', 4), row('Bc4', 3), row('d4', 2), row('Nc3', 31),
          // A small node: 2 of 12 is a sixth, far above a tenth, and still
          // too few games — so the count is tested on its own, not through
          // the share.
          row('e4', 2, OTHER_KEY, 12), row('c4', 10, OTHER_KEY, 12),
        ],
      };
    },
  };
  const report = await leakReport(pool, 5, { subject: 's' });
  const habits = report.nodes.map((n) => Object.fromEntries(n.moves.map((m) => [m.san, m.habit])));
  // 4 of 40 is a tenth; 3 of 40 is not; 2 is too few whatever the share.
  assert.deepEqual(habits, [
    { Nf3: true, Bc4: false, d4: false, Nc3: true },
    { e4: false, c4: true },
  ]);
});
