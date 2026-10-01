// puzzle_list.test.js — which puzzles an account met, one row each.
//
// docs/PLAN-NAPREDAK-VEZBI.md §7, phase 5: `puzzleListOf` and
// GET /api/puzzles/list. The gate the plan wrote for it:
//
//   - the list decides no state of its own: summed by source, its rows are
//     the Practise cards' fold over the same log (a property over random
//     logs, ties in time included);
//   - pages show every puzzle exactly once, even when the account tries
//     puzzles again between two pages;
//   - each table is asked once for a page, never once per row;
//   - the board is the one the player was asked about — for a Lichess puzzle
//     the position after its setup move, not the stored FEN (real rows of the
//     Lichess database);
//   - a puzzle whose row is gone stays in the list, with no board;
//   - the list is the caller's alone (the owner's D3 answer of 1.10.2026:
//     roles play no part, no account reads another's): the account comes from
//     the session, and an own exercise of another account named in the log
//     comes back with no board.
//
// Every table is answered by a stub that reads what it was asked (rule 7), and
// the own-exercise stub applies the owner condition only when the SQL carries
// one — so a query that lost it would hand over another account's board.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { puzzleListOf, ListError, DEFAULT_LIMIT, MAX_LIMIT } = require('../services/puzzleList');
const { foldAttempts, SOURCES } = require('../services/puzzleProgress');

// ── a log, and a database that answers by what it is asked ────────────────

const T0 = Date.parse('2026-09-01T08:00:00Z');
const at = (minutes) => new Date(T0 + minutes * 60 * 1000).toISOString();

function row(source, id, minutes, { solved = false, skipped = false, hinted = false } = {}) {
  return {
    puzzle_id: id, source, solved, skipped, hinted, themes: [],
    rating_before: null, rating_after: null, bucket: null, created_at: at(minutes),
  };
}

/// A pool over the log and the puzzle tables. `log` is read at each call, so a
/// test may add rows between two pages, as a player trying puzzles would.
function poolOver(log, tables = {}) {
  const calls = [];
  const byId = (rows, ids, key = 'puzzle_id') => rows.filter((r) => ids.includes(r[key]));
  return {
    calls,
    async query(text, params = []) {
      const sql = String(text);
      const table = (/FROM\s+(\w+)/.exec(sql) || [])[1];
      calls.push({ table, sql, params });
      switch (table) {
        case 'user_puzzle_attempts':
          return { rows: log.slice() };
        case 'lichess_puzzles':
          return { rows: byId(tables.lichess || [], params[0]) };
        case 'puzzles':
          return { rows: byId(tables.puzzles || [], params[0]) };
        case 'endgame_puzzles':
          return { rows: byId(tables.endgame || [], params[0]) };
        case 'blunder_games':
          return { rows: byId(tables.blunder || [], params[0], 'game_id') };
        case 'custom_puzzles': {
          // As the database would: the owner condition holds only if the
          // statement says it.
          const named = byId(tables.own || [], params[0]);
          return {
            rows: /owner_id\s*=\s*\$2/.test(sql) ? named.filter((r) => r.owner_id === params[1]) : named,
          };
        }
        default:
          throw new Error(`unexpected query: ${sql}`);
      }
    },
  };
}

/// Every page of a list, in order, by following `next`.
async function allPages(pool, userId, options = {}, limitOf = () => undefined) {
  const pages = [];
  let before;
  for (let guard = 0; guard < 1000; guard += 1) {
    const page = await puzzleListOf(pool, userId, { ...options, before, limit: limitOf(pages.length) });
    pages.push(page);
    if (!page.next) return pages;
    before = page.next;
  }
  throw new Error('the list never ended');
}

const keyOf = (item) => `${item.source}:${item.puzzleId}`;

// ── the list is the cards' fold, puzzle for puzzle ────────────────────────

/// A small seeded generator, so a failing log can be named by its seed.
function random(seed) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

function randomLog(seed) {
  const r = random(seed);
  const pick = (list) => list[Math.floor(r() * list.length)];
  const log = [];
  const puzzles = 1 + Math.floor(r() * 40);
  for (let p = 0; p < puzzles; p += 1) {
    const source = pick(SOURCES);
    const id = `${source}-${p}`;
    const tries = 1 + Math.floor(r() * 5);
    for (let t = 0; t < tries; t += 1) {
      const skipped = r() < 0.2;
      const solved = !skipped && r() < 0.5;
      // A small range of minutes, so two rows often share a moment.
      log.push(row(source, id, Math.floor(r() * 30), { solved, skipped, hinted: !skipped && r() < 0.2 }));
    }
  }
  // A row of a source the fold does not know is read by neither.
  log.push(row('nonsense', 'x', 3, { solved: true }));
  // The order rows arrive in is no promise.
  for (let i = log.length - 1; i > 0; i -= 1) {
    const j = Math.floor(r() * (i + 1));
    [log[i], log[j]] = [log[j], log[i]];
  }
  return log;
}

for (const seed of [1, 2, 3, 7, 42, 99, 1234, 2026]) {
  test(`the list's states are the cards' fold, puzzle for puzzle (seed ${seed})`, async () => {
    const log = randomLog(seed);
    const r = random(seed + 1);
    const pages = await allPages(poolOver(log), 5, {}, () => 1 + Math.floor(r() * 12));
    const items = pages.flatMap((p) => p.puzzles);

    assert.equal(new Set(items.map(keyOf)).size, items.length, 'no puzzle twice');
    const fold = foldAttempts(log);
    const tally = {};
    for (const item of items) {
      const t = tally[item.source] || (tally[item.source] = { seen: 0, solved: 0, failed: 0, skipped: 0, firstTry: 0 });
      t.seen += 1;
      t[item.state] += 1;
      if (item.firstTry) t.firstTry += 1;
    }
    for (const source of Object.keys(fold)) {
      const { seen, solved, failed, skipped, firstTry } = fold[source];
      assert.deepEqual(tally[source], { seen, solved, failed, skipped, firstTry }, source);
    }
    assert.deepEqual(Object.keys(tally).sort(), Object.keys(fold).sort());
  });
}

test('each puzzle stands where its own latest row leaves it, whatever order the rows arrive in', async () => {
  // Per puzzle, not in total. puzzle_progress.test.js holds the same rule
  // over two mirror-image puzzles and asserts only the totals, so a fold that
  // lost the time order — every puzzle trading its first and latest row —
  // came out with the same counts and stayed green (a surviving mutation,
  // 1.10.2026). Here each puzzle says where it stands.
  const log = [
    row('lichess', 'a', 2, { solved: true }), row('lichess', 'a', 1),
    row('lichess', 'b', 4), row('lichess', 'b', 3, { solved: true }),
    row('endgame', 'c', 7, { skipped: true }), row('endgame', 'c', 5), row('endgame', 'c', 6, { solved: true }),
  ];
  const page = await puzzleListOf(poolOver(log), 5);
  const by = Object.fromEntries(page.puzzles.map((p) => [p.puzzleId, p]));

  assert.equal(by.a.state, 'solved');
  assert.equal(by.a.firstTry, false);
  assert.equal(by.a.solvedOnTry, 2);
  assert.equal(by.b.state, 'failed');
  assert.equal(by.b.firstTry, true);
  assert.equal(by.c.state, 'skipped', 'its latest row is the skip, whatever arrived last');
  assert.equal(by.c.firstAt, at(5));
  assert.equal(by.c.latestAt, at(7));
});

test('newest first, and two puzzles last tried at one moment keep one order', async () => {
  const log = [
    row('lichess', 'b', 5), row('lichess', 'a', 5), row('endgame', 'z', 5),
    row('own', 'old', 1), row('mate_puzzle', 'new', 9),
  ];
  const [page] = await allPages(poolOver(log), 5);
  assert.deepEqual(page.puzzles.map(keyOf),
    ['mate_puzzle:new', 'endgame:z', 'lichess:a', 'lichess:b', 'own:old']);
});

// ── pages ──────────────────────────────────────────────────────────────────

test('pages show every puzzle once, while the account goes on trying puzzles', async () => {
  const log = [];
  for (let i = 0; i < 9; i += 1) log.push(row('lichess', `p${i}`, i, { solved: false }));
  const pool = poolOver(log);

  const first = await puzzleListOf(pool, 5, { limit: 3 });
  assert.deepEqual(first.puzzles.map((p) => p.puzzleId), ['p8', 'p7', 'p6']);
  assert.ok(first.next);

  // Between two pages: p7 (already shown) is tried again, p2 (not yet shown)
  // is solved, and a puzzle never met before is tried.
  log.push(row('lichess', 'p7', 20, { solved: true }));
  log.push(row('lichess', 'p2', 21, { solved: true }));
  log.push(row('lichess', 'fresh', 22));

  const pages = [first];
  let before = first.next;
  while (before) {
    const page = await puzzleListOf(pool, 5, { before, limit: 3 });
    pages.push(page);
    before = page.next;
  }
  const ids = pages.flatMap((p) => p.puzzles.map((x) => x.puzzleId));
  assert.deepEqual(ids, ['p8', 'p7', 'p6', 'p5', 'p4', 'p3', 'p2', 'p1', 'p0'],
    'the list as it stood when it was first read: each once, none skipped, nothing new');
  const p2 = pages.flatMap((p) => p.puzzles).find((x) => x.puzzleId === 'p2');
  assert.equal(p2.state, 'failed', 'a later page reads the log as the first page did');

  // Read again from the top, the tries are there.
  const again = await puzzleListOf(pool, 5, { limit: 3 });
  assert.deepEqual(again.puzzles.map((p) => p.puzzleId), ['fresh', 'p2', 'p7']);
});

test('the last page says there is no next one; an empty log is an empty list', async () => {
  const log = [row('lichess', 'a', 1), row('lichess', 'b', 2)];
  const page = await puzzleListOf(poolOver(log), 5, { limit: 2 });
  assert.equal(page.puzzles.length, 2);
  assert.equal(page.next, null);

  assert.deepEqual(await puzzleListOf(poolOver([]), 5), { puzzles: [], next: null });
});

test('a page is the default size unless asked, and never larger than the most', async () => {
  const log = [];
  for (let i = 0; i < MAX_LIMIT + 20; i += 1) log.push(row('lichess', `p${i}`, i));
  assert.equal((await puzzleListOf(poolOver(log), 5)).puzzles.length, DEFAULT_LIMIT);
  assert.equal((await puzzleListOf(poolOver(log), 5, { limit: '7' })).puzzles.length, 7);
  assert.equal((await puzzleListOf(poolOver(log), 5, { limit: 5000 })).puzzles.length, MAX_LIMIT);
});

// ── filters ────────────────────────────────────────────────────────────────

test('the state and the source each cut, and together they cut what neither cuts alone', async () => {
  // Each filter must cut something the other would not, or composing them
  // tests one filter twice (PLAN-LISTE phase 7).
  const log = [
    row('lichess', 'l-failed', 1),
    row('lichess', 'l-solved', 2, { solved: true }),
    row('endgame', 'e-failed', 3),
    row('endgame', 'e-skipped', 4, { skipped: true }),
    row('own', 'o-solved', 5, { solved: true }),
  ];
  const ids = async (options) => (await puzzleListOf(poolOver(log), 5, options)).puzzles.map((p) => p.puzzleId).sort();

  assert.deepEqual(await ids({ state: 'failed' }), ['e-failed', 'l-failed']);
  assert.deepEqual(await ids({ source: 'endgame' }), ['e-failed', 'e-skipped']);
  assert.deepEqual(await ids({ state: 'failed', source: 'endgame' }), ['e-failed']);
  assert.deepEqual(await ids({ state: 'skipped' }), ['e-skipped']);
  assert.deepEqual(await ids({ state: 'solved', source: 'own' }), ['o-solved']);
});

test('a request the list cannot answer is refused, not guessed', async () => {
  const pool = poolOver([row('lichess', 'a', 1)]);
  for (const options of [
    { source: 'chess960' },
    { state: 'nearly' },
    { before: 'not a cursor' },
    { before: Buffer.from(JSON.stringify({ a: 1 })).toString('base64url') },
    { limit: 0 },
    { limit: 'many' },
  ]) {
    await assert.rejects(() => puzzleListOf(pool, 5, options), ListError, JSON.stringify(options));
  }
});

// ── a puzzle's tries ───────────────────────────────────────────────────────

test('tries count answers, not skips, and say which try solved it', async () => {
  const log = [
    row('endgame', 'eg', 1),
    row('endgame', 'eg', 2, { skipped: true }),
    row('endgame', 'eg', 3),
    row('endgame', 'eg', 4, { solved: true }),
    row('lichess', 'once', 5, { solved: true }),
    row('lichess', 'never', 6),
    row('lichess', 'hint', 7, { solved: true, hinted: true }),
  ];
  const page = await puzzleListOf(poolOver(log), 5);
  const by = Object.fromEntries(page.puzzles.map((p) => [p.puzzleId, p]));

  assert.equal(by.eg.state, 'solved');
  assert.equal(by.eg.tries, 3);
  assert.equal(by.eg.solvedOnTry, 3);
  assert.equal(by.eg.firstTry, false);
  assert.equal(by.eg.firstAt, at(1));
  assert.equal(by.eg.latestAt, at(4));

  assert.equal(by.once.firstTry, true);
  assert.equal(by.once.solvedOnTry, 1);
  assert.equal(by.never.solvedOnTry, null);
  assert.equal(by.never.state, 'failed');
  assert.equal(by.hint.firstTry, false, 'a hinted solve is not a first-try solve');
  assert.equal(by.hint.solvedOnTry, 1);
});

// ── boards ─────────────────────────────────────────────────────────────────

// Two real rows of the Lichess puzzle database (puzzles/lichess_db_puzzle.csv.zst,
// its first and third lines). The stored FEN is the position before the
// opponent's move; the drill plays that move first. The boards after it were
// worked out by hand, rank by rank: in 00008 Black's bishop takes the rook on
// g3; in 0008Q White's rook goes quietly from e7 to f7.
const LICHESS_00008 = {
  puzzle_id: '00008',
  fen: 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24',
  moves: 'f2g3 e6e7 b2b1 b3c1 b1c1 h6c1',
  rating: 1939,
  themes: ['crushing', 'hangingPiece', 'long', 'middlegame'],
};
const LICHESS_0008Q = {
  puzzle_id: '0008Q',
  fen: '8/4R3/1p2P3/p4r2/P6p/1P3Pk1/4K3/8 w - - 1 64',
  moves: 'e7f7 f5e5 e2f1 e5e6',
  rating: 1383,
  themes: ['advantage', 'endgame', 'rookEndgame', 'short'],
};

test('a Lichess puzzle shows the board after its setup move, not the stored one', async () => {
  const log = [row('lichess', '00008', 1), row('lichess', '0008Q', 2, { solved: true })];
  const page = await puzzleListOf(poolOver(log, { lichess: [LICHESS_00008, LICHESS_0008Q] }), 5);
  const by = Object.fromEntries(page.puzzles.map((p) => [p.puzzleId, p]));

  assert.equal(by['00008'].fen, 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25');
  assert.equal(by['0008Q'].fen, '8/5R2/1p2P3/p4r2/P6p/1P3Pk1/4K3/8 b - - 2 64');
  assert.equal(by['00008'].available, true);
  // Motifs only (trainableThemes): of crushing, hangingPiece, long and
  // middlegame, one names something a reader can learn.
  assert.deepEqual(by['00008'].detail, { rating: 1939, themes: ['hangingPiece'] });
  assert.deepEqual(by['0008Q'].detail.themes, [], 'advantage, endgame, rookEndgame and short are none');
});

test('a Lichess row whose setup move cannot be played shows no board rather than a wrong one', async () => {
  const broken = { ...LICHESS_00008, moves: 'a1a2 e6e7' };
  const page = await puzzleListOf(poolOver([row('lichess', '00008', 1)], { lichess: [broken] }), 5);
  assert.equal(page.puzzles[0].available, false);
  assert.equal(page.puzzles[0].fen, null);
});

const MATE_FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const WIN_FEN = 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4';
const ENDGAME_FEN = '8/8/4k3/8/3PK3/8/r7/7R w - - 0 1';
const BLUNDER_FEN = '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55';
const OWN_FEN = '6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1';

test('every source draws its own board, and says what kind of puzzle it is', async () => {
  const log = [
    row('mate_puzzle', 'm1', 1),
    row('winning_position', 'w1', 2),
    row('endgame', 'eg_1', 3),
    // A game id with a colon in it: the ply is what follows the last one.
    row('blunder_game', 'tw:42:57', 4),
    row('basic_mate', 'basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -', 5),
    row('own', 'ex_1', 6),
  ];
  const page = await puzzleListOf(poolOver(log, {
    puzzles: [
      { puzzle_id: 'm1', fen: MATE_FEN, type: 'mate_puzzle', mate_depth: 2 },
      { puzzle_id: 'w1', fen: WIN_FEN, type: 'winning_position', mate_depth: null },
    ],
    endgame: [{ puzzle_id: 'eg_1', fen: ENDGAME_FEN, mode: 'win', endgame_type: 'RookEndgame', material: 'KRPvKR' }],
    blunder: [{
      game_id: 'tw:42', white: 'Chiburdanidze, Maia', black: 'Gaprindashvili, Nona',
      blunders: [
        { ply: 31, fen: '8/8/8/8/8/8/8/K6k w - - 0 16', side: 'white' },
        { ply: 57, fen: BLUNDER_FEN, side: 'black' },
      ],
    }],
    own: [{ puzzle_id: 'ex_1', owner_id: 5, fen: OWN_FEN, instruction: 'White mates in one.', source_title: 'My book' }],
  }), 5);
  const by = Object.fromEntries(page.puzzles.map((p) => [p.puzzleId, p]));

  assert.equal(by.m1.fen, MATE_FEN);
  assert.deepEqual(by.m1.detail, { mateDepth: 2 });
  assert.equal(by.w1.fen, WIN_FEN);
  assert.deepEqual(by.w1.detail, {});
  assert.equal(by.eg_1.fen, ENDGAME_FEN);
  assert.deepEqual(by.eg_1.detail, {
    mode: 'win', type: 'RookEndgame', material: 'KRPvKR', materialLabel: 'rook and pawn versus rook',
  });
  assert.equal(by['tw:42:57'].fen, BLUNDER_FEN);
  assert.deepEqual(by['tw:42:57'].detail, {
    ply: 57, side: 'black', white: 'Chiburdanidze, Maia', black: 'Gaprindashvili, Nona',
  });
  assert.equal(by['basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -'].fen, '4k3/8/4K3/8/8/8/8/7Q w - - 0 1');
  assert.deepEqual(by['basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -'].detail, { preset: 'easy' });
  assert.equal(by.ex_1.fen, OWN_FEN);
  assert.deepEqual(by.ex_1.detail, { instruction: 'White mates in one.', sourceTitle: 'My book' });
  for (const item of page.puzzles) assert.equal(item.available, true, item.puzzleId);
});

test('a puzzle whose row is gone stays in the list, with no board', async () => {
  // An own exercise deleted since, a game no longer in the table, a ply the
  // game does not have, a basic-mate id that is not a position. They still
  // count on the cards — the fold reads the log — so hiding them would make
  // the list shorter than the number above it.
  const log = [
    row('own', 'ex_deleted', 1),
    row('blunder_game', 'gone:12', 2),
    row('blunder_game', 'tw:42:99', 3),
    row('basic_mate', 'basic:easy:not a board', 4),
    row('lichess', 'nowhere', 5),
  ];
  const page = await puzzleListOf(poolOver(log, {
    blunder: [{ game_id: 'tw:42', white: 'A', black: 'B', blunders: [{ ply: 57, fen: BLUNDER_FEN, side: 'black' }] }],
  }), 5);
  assert.equal(page.puzzles.length, 5);
  for (const item of page.puzzles) {
    assert.equal(item.available, false, item.puzzleId);
    assert.equal(item.fen, null, item.puzzleId);
    assert.deepEqual(item.detail, {}, item.puzzleId);
  }
});

test('each table is asked once for a page, never once per row', async () => {
  const log = [];
  const tables = { lichess: [], puzzles: [], endgame: [], blunder: [], own: [] };
  for (let i = 0; i < 6; i += 1) {
    log.push(row('lichess', `l${i}`, i));
    tables.lichess.push({ ...LICHESS_00008, puzzle_id: `l${i}` });
    log.push(row('mate_puzzle', `m${i}`, i));
    log.push(row('winning_position', `w${i}`, i));
    tables.puzzles.push({ puzzle_id: `m${i}`, fen: MATE_FEN, type: 'mate_puzzle', mate_depth: 1 });
    tables.puzzles.push({ puzzle_id: `w${i}`, fen: WIN_FEN, type: 'winning_position', mate_depth: null });
    log.push(row('endgame', `e${i}`, i));
    tables.endgame.push({ puzzle_id: `e${i}`, fen: ENDGAME_FEN, mode: 'draw', endgame_type: 'X', material: null });
    log.push(row('blunder_game', `g${i % 2}:${i}`, i));
    // The queen on a different square of the first rank each time (a FEN
    // rank never writes a zero).
    log.push(row('basic_mate', `basic:hard:4k3/8/4K3/8/8/8/8/${i || ''}Q${7 - i} w - -`, i));
    log.push(row('own', `o${i}`, i));
    tables.own.push({ puzzle_id: `o${i}`, owner_id: 5, fen: OWN_FEN, instruction: null, source_title: null });
  }
  tables.blunder.push({ game_id: 'g0', white: 'A', black: 'B', blunders: [0, 2, 4].map((ply) => ({ ply, fen: BLUNDER_FEN, side: 'white' })) });
  tables.blunder.push({ game_id: 'g1', white: 'A', black: 'B', blunders: [1, 3, 5].map((ply) => ({ ply, fen: BLUNDER_FEN, side: 'black' })) });

  const pool = poolOver(log, tables);
  const page = await puzzleListOf(pool, 5, { limit: MAX_LIMIT });
  assert.equal(page.puzzles.length, 42);
  assert.ok(page.puzzles.every((p) => p.available), 'every board found');

  const asked = (table) => pool.calls.filter((c) => c.table === table);
  assert.equal(asked('user_puzzle_attempts').length, 1);
  for (const table of ['lichess_puzzles', 'puzzles', 'endgame_puzzles', 'blunder_games', 'custom_puzzles']) {
    assert.equal(asked(table).length, 1, table);
  }
  assert.equal(pool.calls.length, 6, 'and a basic mate needs no table at all');
  assert.deepEqual([...asked('blunder_games')[0].params[0]].sort(), ['g0', 'g1'], 'one game is asked once, whatever its plies');
});

test('a page asks only the tables its own rows need', async () => {
  const pool = poolOver([row('basic_mate', 'basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -', 1)]);
  await puzzleListOf(pool, 5);
  assert.deepEqual(pool.calls.map((c) => c.table), ['user_puzzle_attempts']);
});

// ── whose list ─────────────────────────────────────────────────────────────

test('an own exercise of another account, named in the log, comes back with no board', async () => {
  // The writer refuses another account's exercise, so the log should never
  // hold one; the list does not lean on that. The board is read only for the
  // caller's own exercise.
  const log = [row('own', 'mine', 1), row('own', 'theirs', 2)];
  const pool = poolOver(log, {
    own: [
      { puzzle_id: 'mine', owner_id: 5, fen: OWN_FEN, instruction: null, source_title: null },
      { puzzle_id: 'theirs', owner_id: 6, fen: MATE_FEN, instruction: 'Secret', source_title: 'Their book' },
    ],
  });
  const page = await puzzleListOf(pool, 5);
  const by = Object.fromEntries(page.puzzles.map((p) => [p.puzzleId, p]));
  assert.equal(by.mine.available, true);
  assert.equal(by.theirs.available, false);
  assert.equal(by.theirs.fen, null);
  assert.ok(!JSON.stringify(page).includes('Secret'));
});

// ── GET /api/puzzles/list ──────────────────────────────────────────────────

const router = require('../routes/puzzles');
const { authenticateToken } = require('../middleware/auth');
const db = require('../db');

async function get(query, { userId = 5, log = [] } = {}) {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === '/puzzles/list' && l.route.methods.get
  );
  assert.ok(layer, 'GET /puzzles/list is mounted');
  const handler = layer.route.stack[layer.route.stack.length - 1].handle;
  const pool = poolOver(log);
  const original = db.pool.query;
  db.pool.query = (text, params) => pool.query(text, params);
  const sent = { status: 200, json: null };
  const res = {
    status(code) { sent.status = code; return res; },
    json(payload) { sent.json = payload; return res; },
  };
  try {
    await handler({ query, user: { id: userId }, params: {}, body: {} }, res);
  } finally {
    db.pool.query = original;
  }
  return { ...sent, calls: pool.calls, layer };
}

test('the route is behind sign-in', async () => {
  const { layer } = await get({});
  assert.equal(layer.route.stack[0].handle, authenticateToken);
});

test('the route reads the signed-in account, whatever the query names', async () => {
  const { status, json, calls } = await get(
    { userId: '99', studentId: '99', user_id: '99' },
    { userId: 5, log: [row('lichess', 'a', 1)] },
  );
  assert.equal(status, 200);
  assert.deepEqual(calls[0].params, [5]);
  assert.equal(json.puzzles.length, 1);
  assert.equal(json.next, null);
});

test('the route passes the filters on, and refuses what the list refuses', async () => {
  const log = [row('lichess', 'a', 1), row('endgame', 'b', 2, { solved: true })];
  const solved = await get({ state: 'solved' }, { log });
  assert.deepEqual(solved.json.puzzles.map((p) => p.puzzleId), ['b']);
  const lichess = await get({ source: 'lichess', limit: '1' }, { log });
  assert.deepEqual(lichess.json.puzzles.map((p) => p.puzzleId), ['a']);

  for (const query of [{ source: 'chess960' }, { state: 'nearly' }, { before: 'x' }, { limit: '0' }]) {
    const { status, json } = await get(query, { log });
    assert.equal(status, 400, JSON.stringify(query));
    assert.equal(typeof json.error, 'string');
  }
});
