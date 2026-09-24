// The engine's judgements of a player's habits, on a real database
// (docs/PLAN-MOJE-PARTIJE.md §9.2): a deeper judgement is never replaced by a
// shallower one, a position the caller never reached is refused, another
// user's judgements are never read, and a position no archive reaches any more
// takes its judgements with it.
//
// On a real database because each of these is a WHERE clause: a stub can see
// that a question was asked, not which one.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

// After 1.e4 e5, White to move; and after 1.d4 d5.
const KEY = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6';
const OTHER = 'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq d6';

function item(over = {}) {
  return {
    fenKey: KEY,
    moveUci: 'f1c4',
    wBest: 55,
    wMove: 40,
    bestUci: 'g1f3',
    bestLine: ['Nf3', 'Nc6'],
    moveLine: ['Bc4', 'Nf6'],
    verdict: 'mistake',
    reason: 'lostChances',
    bookGames: 3,
    engine: 'sf19',
    depth: 20,
    ...over,
  };
}

describe('opening judgements on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let judgements;
  let archiveDeletion;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    judgements = require('../services/openingJudgements');
    archiveDeletion = require('../services/archiveDeletion');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function user() {
    minted++;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Player') RETURNING id`,
      [`oj${process.pid}_${minted}@test.invalid`]
    );
    return r.rows[0].id;
  }

  /// One game of [subject] for [userId] that reached [fenKey].
  async function reached(userId, fenKey, subject = 'me') {
    minted++;
    const g = await pool.query(
      `INSERT INTO user_games
         (user_id, source, external_id, subject, subject_is_owner, subject_color,
          result, subject_score, start_fen, moves, ply_count, min_men)
       VALUES ($1, 'lichess', $2, $3, true, 'w', '1-0', 1,
               'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', '{e2e4}', 1, 32)
       RETURNING id`,
      [userId, `ext${minted}`, subject]
    );
    await pool.query(
      `INSERT INTO opening_nodes (user_id, game_id, subject, subject_color, subject_score, ply, fen_key, san)
       VALUES ($1, $2, $3, 'w', 1, 3, $4, 'Bc4')`,
      [userId, g.rows[0].id, subject, fenKey]
    );
  }

  const row = async (userId, fenKey = KEY, move = 'f1c4') =>
    (await pool.query(
      'SELECT depth, verdict FROM opening_judgements WHERE user_id = $1 AND fen_key = $2 AND move_uci = $3',
      [userId, fenKey, move]
    )).rows[0];

  test('a judgement is stored, and a deeper one replaces it', async () => {
    const me = await user();
    await reached(me, KEY);
    const first = await judgements.recordJudgements(pool, me, [item({ depth: 18 })]);
    assert.equal(first.stored, 1);
    const deeper = await judgements.recordJudgements(pool, me, [item({ depth: 22, verdict: 'holds', reason: null, wMove: 54 })]);
    assert.equal(deeper.replaced, 1);
    assert.deepEqual(await row(me), { depth: 22, verdict: 'holds' });
  });

  test('a shallower judgement never replaces a deeper one', async () => {
    const me = await user();
    await reached(me, KEY);
    await judgements.recordJudgements(pool, me, [item({ depth: 24 })]);
    const shallow = await judgements.recordJudgements(pool, me, [item({ depth: 16, verdict: 'holds', reason: null, wMove: 54 })]);
    assert.equal(shallow.kept_deeper, 1);
    assert.equal(shallow.stored + shallow.replaced, 0);
    assert.deepEqual(await row(me), { depth: 24, verdict: 'mistake' });
  });

  test('a position the caller never reached is refused, even if somebody else did', async () => {
    const me = await user();
    const other = await user();
    await reached(other, KEY);
    const tally = await judgements.recordJudgements(pool, me, [item()]);
    assert.deepEqual(tally.rejected_by_reason, { 'position-not-yours': 1 });
    assert.equal(await row(me), undefined);
  });

  test('another user\'s judgements are never read', async () => {
    const me = await user();
    const other = await user();
    await reached(me, KEY);
    await reached(other, KEY);
    await judgements.recordJudgements(pool, other, [item()]);
    const nodes = [{ fenKey: KEY, fen: `${KEY} 0 1`, moves: [{ san: 'Bc4' }] }];
    await judgements.attachJudgements(pool, me, nodes);
    assert.equal(nodes[0].moves[0].judgement, null);
  });

  test('the table refuses a mistake without a reason, whoever writes it', async () => {
    const me = await user();
    await assert.rejects(pool.query(
      `INSERT INTO opening_judgements
         (user_id, fen_key, move_uci, w_best, w_move, best_uci, best_line, move_line,
          verdict, reason, engine, depth)
       VALUES ($1, $2, 'f1c4', 55, 40, 'g1f3', '["Nf3"]', '["Bc4"]', 'mistake', NULL, 'e', 20)`,
      [me, KEY]
    ), /opening_judgements_reason/);
  });

  test('deleting an archive takes the judgements no other game still reaches', async () => {
    const me = await user();
    const other = await user();
    await reached(me, KEY, 'me');
    await reached(me, OTHER, 'me');
    await reached(me, OTHER, 'rival'); // a second archive of the same account
    // Somebody else reaching the same position must not keep this account's
    // judgement alive: the reaper asks about this account's games only.
    await reached(other, KEY);
    await judgements.recordJudgements(pool, me, [
      item(),
      item({ fenKey: OTHER, moveUci: 'c2c4', bestUci: 'c2c4', bestLine: ['c4'], moveLine: ['c4'], verdict: 'holds', reason: null, wMove: 55 }),
    ]);

    const result = await archiveDeletion.deleteSubjectGames(pool, { userId: me, subject: 'me' });
    assert.equal(result.ok, true);
    assert.equal(await row(me, KEY), undefined, 'a position nothing reaches kept its judgement');
    assert.deepEqual(await row(me, OTHER, 'c2c4'), { depth: 20, verdict: 'holds' },
      'a position another archive still reaches lost its judgement');
  });
});
