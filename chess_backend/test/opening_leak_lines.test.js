// opening_leak_lines.test.js — the moves that led to a position of the report.
//
// The owner, 30.9.2026: a position of the opening report opens in Analysis
// with the moves from the start of the game to it. The server keeps those
// moves (`user_games.moves`) and the app does not, so the report carries, for
// every position it shows — flagged or a losing habit — the line to it from
// the latest game that reached it.
//
// Arithmetic and wiring here, with a stub; which game is read, and whose, is
// a WHERE clause and an ORDER BY, and is proved on a real database in
// `opening_leak_lines_db.test.js`.

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { Chess } = require('chess.js');

// The route's own imports demand these; CI has no `.env` (CLAUDE.md).
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { linesTo, attachLines } = require('../services/openingLeaks');
const { fenKey } = require('../services/gameArchive');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 c5 2.Nf3 d6 3.d4 — every UCI move, and the key of the board before
/// each White move (the node the report shows at that ply).
const GAME = ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4'];

function keyBefore(ply) {
  const board = new Chess();
  for (const uci of GAME.slice(0, ply - 1)) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return fenKey(board.fen());
}

const AFTER_C5 = keyBefore(3); // White to play Nf3
const AFTER_D6 = keyBefore(5); // White to play d4
const AFTER_NF3 = keyBefore(4); // Black to play d6

/// Answers the lines query with [rows], and remembers what it was asked.
function linesPool(rows) {
  const calls = [];
  return {
    calls,
    query: async (text, params = []) => {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      return { rows, rowCount: rows.length };
    },
  };
}

test('the line to a position is its game\'s moves before it, from the game\'s start', async () => {
  const pool = linesPool([
    { fen_key: AFTER_D6, ply: 5, start_fen: START, moves: GAME },
  ]);
  const lines = await linesTo(pool, 7, { subject: 'me', color: 'w' }, [AFTER_D6]);
  assert.deepEqual(lines.get(AFTER_D6), {
    startFen: START,
    moves: ['e2e4', 'c7c5', 'g1f3', 'd7d6'],
  });

  // And the four moves really do reach the position the key names.
  const board = new Chess(START);
  for (const uci of lines.get(AFTER_D6).moves) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  assert.equal(fenKey(board.fen()), AFTER_D6);
});

test('the start is a line with no moves, and a broken row is no line at all', async () => {
  const startKey = fenKey(START);
  const pool = linesPool([
    { fen_key: startKey, ply: 1, start_fen: START, moves: GAME },
    // A node at ply 9 of a six-ply game cannot be reached by it.
    { fen_key: AFTER_C5, ply: 9, start_fen: START, moves: GAME },
  ]);
  const lines = await linesTo(pool, 7, { subject: 'me', color: null }, [startKey, AFTER_C5]);
  assert.deepEqual(lines.get(startKey), { startFen: START, moves: [] });
  assert.equal(lines.has(AFTER_C5), false);
});

test('the lines are asked for once, for this account, subject and colour', async () => {
  const pool = linesPool([]);
  await linesTo(pool, 7, { subject: 'me', color: 'b' }, [AFTER_C5, AFTER_D6, AFTER_C5]);
  assert.equal(pool.calls.length, 1);
  assert.deepEqual(pool.calls[0].params, [7, 'me', 'b', [AFTER_C5, AFTER_D6]]);

  const idle = linesPool([]);
  await linesTo(idle, 7, { subject: 'me' }, []);
  assert.equal(idle.calls.length, 0, 'no position, no query');
});

test('every item gets its line, and one no game reaches gets null', async () => {
  const pool = linesPool([
    { fen_key: AFTER_C5, ply: 3, start_fen: START, moves: GAME },
  ]);
  const node = { fenKey: AFTER_C5 };
  const habit = { fenKey: AFTER_C5, san: 'Nf3' };
  const lost = { fenKey: AFTER_D6 };
  await attachLines(pool, 7, { subject: 'me', color: 'w' }, [node, habit, lost]);
  assert.deepEqual(node.line, { startFen: START, moves: ['e2e4', 'c7c5'] });
  assert.deepEqual(habit.line, node.line);
  assert.equal(lost.line, null);
});

// ---------------------------------------------------------------------------
// The route: both lists the screen draws carry their lines. Driven over a real
// socket with a signed token, like `account_rate_limits.test.js` — what this
// guards is that the route calls the helper on the right lists, and only a
// request sees that.

const db = require('../db');

function nodeRow(fenKeyOf, ply, san, over = {}) {
  return {
    rk: 1,
    fen_key: fenKeyOf,
    node_games: 10,
    node_points: '3.0',
    node_ply: ply,
    san,
    move_games: 9,
    move_points: '3.0',
    ...over,
  };
}

test('the leaks report carries a line on every flagged node and every losing habit', async () => {
  const asked = [];
  db.pool.query = async (text, params = []) => {
    const sql = String(text).replace(/\s+/g, ' ');
    if (/FROM users/.test(sql)) {
      return { rows: [{ id: 1, role: 'korisnik', account_type: 'free' }], rowCount: 1 };
    }
    if (/COUNT\(\*\) FILTER/.test(sql)) return { rows: [{ games: 20, without_nodes: 0 }], rowCount: 1 };
    if (/WITH picked AS/.test(sql)) {
      // The flagged report asks with a score ceiling; the losing habits' pass
      // asks for every frequent node, ceiling null.
      const rows = params[7] === null
        ? [nodeRow(AFTER_C5, 3, 'Nf3'), nodeRow(AFTER_D6, 5, 'd4', { node_points: '7.0', move_points: '7.0' })]
        : [nodeRow(AFTER_C5, 3, 'Nf3')];
      return { rows, rowCount: rows.length };
    }
    if (/FROM opening_judgements/.test(sql)) {
      // d4 after 2...d6 judged a mistake: a losing habit whose node the score
      // does not flag.
      const rows = [{
        fen_key: AFTER_D6, move_uci: 'd2d4', w_best: 55, w_move: 40, best_uci: 'f1b5',
        best_line: ['Bb5+'], move_line: ['d4'], verdict: 'mistake', reason: 'lostChances',
        book_games: 0, loss_cp: 60, engine: 'sf', depth: 20,
      }];
      return { rows, rowCount: rows.length };
    }
    if (/DISTINCT ON \(n\.fen_key\)/.test(sql)) {
      asked.push(params);
      const rows = [
        { fen_key: AFTER_C5, ply: 3, start_fen: START, moves: GAME },
        { fen_key: AFTER_D6, ply: 5, start_fen: START, moves: GAME },
      ];
      return { rows, rowCount: rows.length };
    }
    return { rows: [], rowCount: 0 };
  };

  const router = require('../routes/userGames');
  const app = express();
  app.use('/games', router);
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    const token = jwt.sign({ id: 1, email: 'x@example.test', role: 'korisnik' }, process.env.JWT_SECRET);
    const body = await new Promise((resolve, reject) => {
      http.get({
        port: server.address().port,
        path: '/games/openings/leaks?subject=me&color=w',
        headers: { Authorization: `Bearer ${token}` },
      }, (res) => {
        let text = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => { text += chunk; });
        res.on('end', () => {
          try { resolve({ status: res.statusCode, json: JSON.parse(text) }); } catch (e) { reject(e); }
        });
      }).on('error', reject);
    });

    assert.equal(body.status, 200, JSON.stringify(body.json));
    const report = body.json;
    assert.equal(report.nodes.length, 1);
    assert.deepEqual(report.nodes[0].line, { startFen: START, moves: ['e2e4', 'c7c5'] });
    assert.equal(report.losingHabits.length, 1);
    assert.equal(report.losingHabits[0].fenKey, AFTER_D6);
    assert.deepEqual(report.losingHabits[0].line, {
      startFen: START, moves: ['e2e4', 'c7c5', 'g1f3', 'd7d6'],
    });
    // One question for both lists, for the report's own subject and colour.
    assert.equal(asked.length, 1);
    assert.deepEqual(asked[0].slice(0, 3), [1, 'me', 'w']);
    assert.deepEqual([...asked[0][3]].sort(), [AFTER_C5, AFTER_D6].sort());
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

// ---------------------------------------------------------------------------
// The games that reached a position (30.9.2026): the owner reads a position
// game by game, and opens one in Analysis standing on it.

const { positionGames, MAX_POSITION_GAMES } = require('../services/openingLeaks');

function gameRow(over = {}) {
  return {
    id: '41', played_at: new Date('2026-09-01T10:00:00Z'), opponent: 'someone',
    opponent_elo: 1810, subject_elo: 1795, result: '0-1', subject_score: '0.0',
    speed: 'blitz', time_control: '180+2', subject_is_owner: true,
    san: 'd4', ply: 5, total: '12', ...over,
  };
}

test('a position\'s games are asked for this account, subject, colour and position', async () => {
  const pool = linesPool([gameRow()]);
  const answer = await positionGames(pool, 7, { subject: ' me ', color: 'w', fenKey: AFTER_D6 });
  assert.equal(pool.calls.length, 1);
  assert.deepEqual(pool.calls[0].params, [7, 'me', 'w', AFTER_D6, MAX_POSITION_GAMES]);
  assert.equal(answer.total, 12, 'the total is every game, not the rows sent');
  assert.deepEqual(answer.games[0], {
    id: '41', playedAt: '2026-09-01T10:00:00.000Z', opponent: 'someone',
    opponentElo: 1810, subjectElo: 1795, result: '0-1', score: 0,
    speed: 'blitz', timeControl: '180+2', own: true, san: 'd4', ply: 5,
  });
});

test('no game is a total of none, and a game with no date says so', async () => {
  const none = await positionGames(linesPool([]), 7, { subject: 'me', fenKey: AFTER_D6 });
  assert.deepEqual(none.games, []);
  assert.equal(none.total, 0);
  const undated = await positionGames(linesPool([gameRow({ played_at: null, subject_is_owner: false })]), 7,
    { subject: 'me', fenKey: AFTER_D6 });
  assert.equal(undated.games[0].playedAt, null);
  assert.equal(undated.games[0].own, false);
});

test('a position\'s games refuse a missing player, a bad colour and a missing position', async () => {
  const pool = linesPool([]);
  await assert.rejects(() => positionGames(pool, 7, { subject: ' ', fenKey: AFTER_D6 }), RangeError);
  await assert.rejects(() => positionGames(pool, 7, { subject: 'me', color: 'white', fenKey: AFTER_D6 }), RangeError);
  await assert.rejects(() => positionGames(pool, 7, { subject: 'me', fenKey: 'rnbqkbnr/8 w' }), RangeError);
  await assert.rejects(() => positionGames(pool, 7, { subject: 'me' }), RangeError);
  assert.equal(pool.calls.length, 0, 'nothing is asked for a question that is not one');
});

test('GET /games/openings/games answers the position\'s games, and 400 without a position', async () => {
  const asked = [];
  db.pool.query = async (text, params = []) => {
    const sql = String(text).replace(/\s+/g, ' ');
    if (/FROM users/.test(sql)) {
      return { rows: [{ id: 1, role: 'korisnik', account_type: 'free' }], rowCount: 1 };
    }
    if (/WITH hits AS/.test(sql)) {
      asked.push(params);
      return { rows: [gameRow()], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
  const router = require('../routes/userGames');
  const app = express();
  app.use('/games', router);
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const get = (path) => new Promise((resolve, reject) => {
    const token = jwt.sign({ id: 1, email: 'x@example.test', role: 'korisnik' }, process.env.JWT_SECRET);
    http.get({ port: server.address().port, path, headers: { Authorization: `Bearer ${token}` } }, (res) => {
      let text = '';
      res.setEncoding('utf8');
      res.on('data', (c) => { text += c; });
      res.on('end', () => resolve({ status: res.statusCode, json: JSON.parse(text) }));
    }).on('error', reject);
  });
  try {
    const ok = await get(`/games/openings/games?subject=me&color=b&fenKey=${encodeURIComponent(AFTER_NF3)}`);
    assert.equal(ok.status, 200, JSON.stringify(ok.json));
    assert.equal(ok.json.games[0].san, 'd4');
    assert.deepEqual(asked[0].slice(0, 4), [1, 'me', 'b', AFTER_NF3]);
    const bad = await get('/games/openings/games?subject=me');
    assert.equal(bad.status, 400);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
