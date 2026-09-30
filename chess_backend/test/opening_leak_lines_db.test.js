// The line to a position of the opening report, on a real database: it comes
// from the latest game of this account's subject that reached the position,
// never from another account's or another subject's game, and a game with no
// date never wins over one with a date.
//
// On a real database because each of these is a WHERE clause or an ORDER BY:
// a stub can see that a question was asked, not which one.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');
const { fenKey } = require('../services/gameArchive');

const skip = skipUnlessDatabase();

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Three move orders into one position — White to move after e4, Nf3, …c5,
/// …d6 — so which game the line came from is visible in the line itself.
const SICILIAN = ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4'];
const RETI_FIRST = ['g1f3', 'd7d6', 'e2e4', 'c7c5', 'd2d4'];
const PIRC_FIRST = ['e2e4', 'd7d6', 'g1f3', 'c7c5', 'd2d4'];
const LEFT_OUT = ['g1f3', 'c7c5', 'e2e4', 'd7d6', 'd2d4'];

function keyAfter(moves) {
  const board = new Chess(START);
  for (const uci of moves) board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  return fenKey(board.fen());
}

const KEY = keyAfter(SICILIAN.slice(0, 4));

describe('the line to a report position, on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let openingLeaks;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    openingLeaks = require('../services/openingLeaks');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function user() {
    minted++;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Player') RETURNING id`,
      [`ol${process.pid}_${minted}@test.invalid`]
    );
    return r.rows[0].id;
  }

  /// A game of [subject] for [userId], played on [playedAt], whose fifth ply is
  /// White's move from [KEY].
  async function game(userId, moves, playedAt, subject = 'me') {
    minted++;
    const g = await pool.query(
      `INSERT INTO user_games
         (user_id, source, external_id, subject, subject_is_owner, played_at,
          subject_color, result, subject_score, start_fen, moves, ply_count, min_men)
       VALUES ($1, 'lichess', $2, $3, true, $4, 'w', '1-0', 1, $5, $6, $7, 32)
       RETURNING id`,
      [userId, `ext${minted}`, subject, playedAt, START, moves, moves.length]
    );
    await pool.query(
      `INSERT INTO opening_nodes (user_id, game_id, subject, subject_color, subject_score, ply, fen_key, san)
       VALUES ($1, $2, $3, 'w', 1, 5, $4, 'd4')`,
      [userId, g.rows[0].id, subject, KEY]
    );
  }

  test('the three move orders really are one position', () => {
    assert.equal(keyAfter(RETI_FIRST.slice(0, 4)), KEY);
    assert.equal(keyAfter(PIRC_FIRST.slice(0, 4)), KEY);
    assert.equal(keyAfter(LEFT_OUT.slice(0, 4)), KEY);
  });

  test('the line comes from the latest game of this account and subject', async () => {
    const me = await user();
    const other = await user();
    await game(me, SICILIAN, '2026-01-01T12:00:00Z');
    await game(me, RETI_FIRST, '2026-03-01T12:00:00Z'); // the latest of mine
    await game(me, PIRC_FIRST, null); // no date: never the latest
    await game(me, LEFT_OUT, '2026-05-01T12:00:00Z', 'someone'); // prepared opponent
    await game(other, LEFT_OUT, '2026-06-01T12:00:00Z'); // another account

    const lines = await openingLeaks.linesTo(pool, me, { subject: 'me', color: 'w' }, [KEY]);
    assert.deepEqual(lines.get(KEY), { startFen: START, moves: RETI_FIRST.slice(0, 4) });

    // The other subject has a line of its own, from its own game.
    const theirs = await openingLeaks.linesTo(pool, me, { subject: 'someone', color: 'w' }, [KEY]);
    assert.deepEqual(theirs.get(KEY), { startFen: START, moves: LEFT_OUT.slice(0, 4) });
  });

  test('a position lists this account\'s games of the subject, one row per game, newest first', async () => {
    const me = await user();
    const other = await user();
    await game(me, SICILIAN, '2026-01-01T12:00:00Z');
    await game(me, RETI_FIRST, '2026-03-01T12:00:00Z');
    await game(me, PIRC_FIRST, null);
    await game(me, LEFT_OUT, '2026-05-01T12:00:00Z', 'someone');
    await game(other, LEFT_OUT, '2026-06-01T12:00:00Z');
    // A game that comes back to the position later (a repetition inside the
    // window): one game, listed at its first visit.
    await game(me, SICILIAN, '2026-02-01T12:00:00Z');
    const { rows: [latest] } = await pool.query(
      'SELECT id FROM user_games WHERE user_id = $1 ORDER BY id DESC LIMIT 1', [me]);
    await pool.query(
      `INSERT INTO opening_nodes (user_id, game_id, subject, subject_color, subject_score, ply, fen_key, san)
       VALUES ($1, $2, 'me', 'w', 1, 9, $3, 'Nc3')`,
      [me, latest.id, KEY]
    );

    const answer = await openingLeaks.positionGames(pool, me, { subject: 'me', color: 'w', fenKey: KEY });
    assert.equal(answer.total, 4);
    assert.deepEqual(answer.games.map((g) => g.playedAt && g.playedAt.slice(0, 10)),
      ['2026-03-01', '2026-02-01', '2026-01-01', null]);
    const repeated = answer.games[1];
    assert.equal(repeated.id, String(latest.id));
    assert.deepEqual([repeated.ply, repeated.san], [5, 'd4']);
    assert.ok(answer.games.every((g) => g.own === true));

    const theirs = await openingLeaks.positionGames(pool, me, { subject: 'someone', color: 'w', fenKey: KEY });
    assert.equal(theirs.total, 1);
    const black = await openingLeaks.positionGames(pool, me, { subject: 'me', color: 'b', fenKey: KEY });
    assert.equal(black.total, 0);
  });

  test('a colour the position was never reached with gives no line', async () => {
    const me = await user();
    await game(me, SICILIAN, '2026-01-01T12:00:00Z');
    const lines = await openingLeaks.linesTo(pool, me, { subject: 'me', color: 'b' }, [KEY]);
    assert.equal(lines.has(KEY), false);
  });
});
