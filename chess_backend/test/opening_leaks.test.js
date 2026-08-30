// opening_leaks.test.js — the report, its window, and the gap it must admit to.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  leakReport, backfillNodes, replayNodes, fenFromKey,
  DEFAULT_FROM_PLY, DEFAULT_MIN_GAMES, DEFAULT_MAX_SCORE,
} = require('../services/openingLeaks');
const { fenKey: archiveFenKey } = require('../services/gameArchive');
const { fenKey: repertoireFenKey } = require('../services/repertoireService');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Answers the two queries the report issues, and records what it was asked.
function stubPool({ nodes = [], coverage = { games: 0, without_nodes: 0 }, backfill = [] } = {}) {
  const calls = [];
  let backfillBatch = 0;
  return {
    calls,
    query: async (text, params = []) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      // Both of these read FROM user_games g WHERE g.user_id, so they are told
      // apart by what they select — matching the FROM clause silently served
      // the coverage row to the backfill and made a green test out of nothing.
      if (/COUNT\(\*\) FILTER/.test(flat)) return { rows: [coverage], rowCount: 1 };
      if (/SELECT g\.id, g\.subject,/.test(flat)) {
        const batch = backfill[backfillBatch] || [];
        backfillBatch += 1;
        return { rows: batch, rowCount: batch.length };
      }
      if (/INSERT INTO opening_nodes/.test(flat)) {
        return { rows: [], rowCount: params.length / 8 };
      }
      return { rows: nodes, rowCount: nodes.length };
    },
  };
}

function nodeRow(over = {}) {
  return {
    rk: 1,
    fen_key: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -',
    node_games: 35,
    node_points: '13.0',
    node_ply: 10,
    san: 'Nf3',
    move_games: 33,
    move_points: '12.0',
    ...over,
  };
}

test('the two fen keys are one key', () => {
  // This is the join between what a player does and the repertoire they meant
  // to have. Two spellings would not error — they would produce an empty diff,
  // which reads as "you never left your repertoire".
  const samples = [
    START,
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 6 12',
    'r1bqkb1r/pp2pppp/2np1n2/8/3NP3/2N5/PPP2PPP/R1BQKB1R w KQkq - 2 7',
  ];
  for (const fen of samples) {
    assert.equal(archiveFenKey(fen), repertoireFenKey(fen));
  }
});

test('a key becomes a board again by putting the counters back', () => {
  const key = archiveFenKey(START);
  assert.equal(fenFromKey(key), 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
});

test('the window cannot be widened past where the numbers mean anything', async () => {
  // Deliberately a refusal and not a silent clamp: a report that quietly
  // answered a narrower question than it was asked is the failure this codebase
  // keeps meeting.
  const pool = stubPool();
  await assert.rejects(
    () => leakReport(pool, 5, { subject: 'subjekat', toPly: 30 }),
    (err) => err instanceof RangeError && /dvadesetog/.test(err.message),
  );
  await assert.rejects(
    () => leakReport(pool, 5, { subject: 'subjekat', fromPly: 0 }),
    RangeError,
  );
  await assert.rejects(
    () => leakReport(pool, 5, { subject: 'subjekat', fromPly: 12, toPly: 8 }),
    RangeError,
  );
});

test('the defaults are the measured ones, and they reach the query', async () => {
  const pool = stubPool();
  const report = await leakReport(pool, 5, { subject: 'subjekat' });
  assert.deepEqual(report.window, { fromPly: DEFAULT_FROM_PLY, toPly: 20 });
  assert.deepEqual(report.thresholds, {
    minGames: DEFAULT_MIN_GAMES, maxScore: DEFAULT_MAX_SCORE,
  });
  const main = pool.calls[0];
  assert.equal(main.params[3], DEFAULT_FROM_PLY);
  assert.equal(main.params[4], 20);
  assert.equal(main.params[6], DEFAULT_MIN_GAMES);
  assert.equal(main.params[7], DEFAULT_MAX_SCORE);
});

test('rows become one position with the moves played in it', async () => {
  const pool = stubPool({
    nodes: [
      nodeRow(),
      nodeRow({ san: 'Qe2', move_games: 2, move_points: '1.0' }),
    ],
    coverage: { games: 4126, without_nodes: 0 },
  });
  const report = await leakReport(pool, 5, { subject: 'subjekat' });

  assert.equal(report.nodes.length, 1);
  const node = report.nodes[0];
  assert.equal(node.games, 35);
  assert.ok(Math.abs(node.score - 13 / 35) < 1e-9);
  assert.equal(node.ply, 10);
  assert.equal(node.fen.endsWith(' 0 1'), true, 'the client needs a drawable board');

  // The dominant move first: 33 of 35 is the finding, not the 2.
  assert.deepEqual(node.moves.map((m) => m.san), ['Nf3', 'Qe2']);
  assert.ok(Math.abs(node.moves[0].share - 33 / 35) < 1e-9);
  assert.ok(Math.abs(node.moves[0].score - 12 / 33) < 1e-9);
  assert.equal(report.games, 4126);
  assert.equal(report.gamesWithoutNodes, 0);
});

test('games whose openings were never recorded are reported, not hidden', async () => {
  // An archive imported before opening_nodes existed produces an empty report,
  // and an empty report reads exactly like a player with no weaknesses.
  const pool = stubPool({ nodes: [], coverage: { games: 4126, without_nodes: 4126 } });
  const report = await leakReport(pool, 5, { subject: 'subjekat' });
  assert.equal(report.nodes.length, 0);
  assert.equal(report.games, 4126);
  assert.equal(report.gamesWithoutNodes, 4126);
});

test('a colour that is not a colour is refused', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => leakReport(pool, 5, { subject: 'subjekat', color: 'white' }),
    RangeError,
  );
  await assert.rejects(() => leakReport(pool, 5, { subject: '  ' }), RangeError);
});

test('a stored game replays into the decisions its subject made', () => {
  const nodes = replayNodes({
    id: 1, subject: 'subjekat', subject_color: 'w', subject_score: 1,
    start_fen: START, moves: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4'],
  });
  assert.deepEqual(nodes.map((n) => `${n.ply}:${n.san}`), ['1:e4', '3:Nf3', '5:d4']);
  assert.equal(nodes[0].fen_key, archiveFenKey(START));
});

test('replaying stops at a move that does not fit rather than writing half a game', () => {
  const nodes = replayNodes({
    subject_color: 'w', start_fen: START, moves: ['e2e4', 'c7c5', 'e1e8'],
  });
  assert.deepEqual(nodes.map((n) => n.san), ['e4']);
});

test('replaying never looks past the window', () => {
  const moves = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'd2d3', 'f8c5',
    'c2c3', 'd7d6', 'b2b4', 'c5b6', 'a2a4', 'a7a6', 'b1d2', 'e8g8',
    'a4a5', 'b6a7', 'd1b3', 'd8e7', 'e1g1', 'c8e6'];
  const nodes = replayNodes({ subject_color: 'w', start_fen: START, moves });
  assert.equal(nodes.length, 10, 'ten of the first twenty plies are White\'s');
  assert.ok(nodes.every((n) => n.ply <= 20));
});

test('the backfill stops instead of asking for the same games forever', async () => {
  // A batch that yields no nodes at all — games too short to reach the window —
  // must end the loop. Without that the same query is issued until something
  // else times out.
  const pool = stubPool({
    backfill: [[{ id: 1, subject: 's', subject_color: 'w', subject_score: 1, start_fen: START, moves: [] }]],
  });
  const result = await backfillNodes(pool, 5);
  assert.equal(result.nodes, 0);
  assert.equal(result.games, 1);
});

test('the backfill writes what it replays', async () => {
  const pool = stubPool({
    backfill: [
      [{ id: 9, subject: 's', subject_color: 'w', subject_score: 0.5, start_fen: START, moves: ['e2e4', 'c7c5', 'g1f3'] }],
      [],
    ],
  });
  const result = await backfillNodes(pool, 5);
  assert.equal(result.games, 1);
  assert.equal(result.nodes, 2);
  const insert = pool.calls.find((c) => /INSERT INTO opening_nodes/.test(c.text));
  assert.equal(insert.params.length, 16);
  assert.equal(insert.params[1], 9, 'nodes belong to the game they were replayed from');
  assert.match(insert.text, /ON CONFLICT \(game_id, ply\) DO NOTHING/);
});
