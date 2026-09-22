// Deleting what could not be deleted until 22.9.2026, on a real database:
// one player's imported games (services/archiveDeletion.js), one mistake out
// of the drill, and notifications — one, or every one already read.
//
// On a real database because each rule is a WHERE clause and a cascade: a stub
// cannot see a missing `user_id`, and it cannot see what ON DELETE CASCADE
// takes with it.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

describe('deleting games, mistakes and notifications on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let archiveDeletion;
  let mistakes;
  let notifications;
  let importer;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    archiveDeletion = require('../services/archiveDeletion');
    mistakes = require('../services/mistakeReviews');
    notifications = require('../services/notifications');
    const { createArchiveImporter } = require('../services/gameArchiveImport');
    importer = createArchiveImporter({ pool, staleRunMs: 60 * 60 * 1000 });
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function user(name = 'Vladan') {
    minted++;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`ud${process.pid}_${minted}@test.invalid`, name]
    );
    return r.rows[0].id;
  }

  /// One game of [subject] for [userId], with a mistake drilled from it and an
  /// opening node counted from it. Answers the three ids.
  async function game(userId, subject, { own = true, source = 'lichess' } = {}) {
    minted++;
    const g = await pool.query(
      `INSERT INTO user_games
         (user_id, source, external_id, subject, subject_is_owner, subject_color,
          result, subject_score, start_fen, moves, ply_count, min_men)
       VALUES ($1, $2, $3, $4, $5, 'w', '1-0', 1,
               'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', '{e2e4}', 1, 32)
       RETURNING id`,
      [userId, source, `ext${minted}`, subject, own]
    );
    const gameId = g.rows[0].id;
    const m = await pool.query(
      `INSERT INTO mistake_reviews (user_id, game_id, ply, fen_before, played_uci, kind, swing_cp)
       VALUES ($1, $2, 1, '8/8/8/8/8/8/8/K6k w - - 0 1', 'a1a2', 'engine', 250) RETURNING id`,
      [userId, gameId]
    );
    await pool.query(
      `INSERT INTO opening_nodes (user_id, game_id, subject, subject_color, subject_score, ply, fen_key, san)
       VALUES ($1, $2, $3, 'w', 1, 1, 'k', 'e4')`,
      [userId, gameId, subject]
    );
    return { gameId, mistakeId: m.rows[0].id };
  }

  async function run(userId, subject, status = 'done', startedAgo = '1 minute') {
    await pool.query(
      `INSERT INTO user_game_imports (user_id, source, subject, status, started_at, finished_at)
       VALUES ($1, 'lichess', $2, $3::varchar, NOW() - $4::interval,
               CASE WHEN $3::varchar = 'running' THEN NULL ELSE NOW() END)`,
      [userId, subject, status, startedAgo]
    );
  }

  const count = async (sql, params) => Number((await pool.query(sql, params)).rows[0].n);

  // ---- games -----------------------------------------------------------------

  test("a player's own games go, and what was computed from them", async () => {
    const me = await user();
    const a = await game(me, 'pvladan');
    await game(me, 'pvladan', { source: 'pgn' });
    const keep = await game(me, 'someone_else');
    await run(me, 'pvladan');

    const result = await archiveDeletion.deleteSubjectGames(pool, { userId: me, subject: 'pvladan' });
    assert.deepEqual(result, { ok: true, deleted: 2 }, 'every source of that handle');

    assert.equal(await count('SELECT COUNT(*) n FROM user_games WHERE user_id = $1 AND subject = $2', [me, 'pvladan']), 0);
    assert.equal(await count('SELECT COUNT(*) n FROM mistake_reviews WHERE game_id = $1', [a.gameId]), 0,
      'the drill kept a mistake from a deleted game');
    assert.equal(await count('SELECT COUNT(*) n FROM opening_nodes WHERE game_id = $1', [a.gameId]), 0);
    assert.equal(await count("SELECT COUNT(*) n FROM user_game_imports WHERE user_id = $1 AND subject = 'pvladan'", [me]), 0,
      'the import history outlived the games');

    assert.equal(await count('SELECT COUNT(*) n FROM user_games WHERE id = $1', [keep.gameId]), 1,
      'another player was deleted with it');
    assert.equal(await count('SELECT COUNT(*) n FROM mistake_reviews WHERE id = $1', [keep.mistakeId]), 1);
  });

  test('another account with the same handle keeps its games', async () => {
    const me = await user();
    const other = await user();
    await game(me, 'shared_handle');
    const theirs = await game(other, 'shared_handle');
    await archiveDeletion.deleteSubjectGames(pool, { userId: me, subject: 'shared_handle' });
    assert.equal(await count('SELECT COUNT(*) n FROM user_games WHERE id = $1', [theirs.gameId]), 1);
  });

  test("an opponent's preparation games of the same handle stay, with their history", async () => {
    const me = await user();
    await game(me, 'rival');
    const prep = await game(me, 'rival', { own: false });
    await run(me, 'rival');
    const result = await archiveDeletion.deleteSubjectGames(pool, { userId: me, subject: 'rival' });
    assert.deepEqual(result, { ok: true, deleted: 1 });
    assert.equal(await count('SELECT COUNT(*) n FROM user_games WHERE id = $1', [prep.gameId]), 1);
    assert.equal(await count("SELECT COUNT(*) n FROM user_game_imports WHERE user_id = $1 AND subject = 'rival'", [me]), 1,
      'history went while games of that handle are still there');
  });

  test('refused while an import of that player is running', async () => {
    const me = await user();
    await game(me, 'busy');
    await run(me, 'busy', 'running');
    const result = await archiveDeletion.deleteSubjectGames(pool, {
      userId: me, subject: 'busy', reapStale: importer.reapStale,
    });
    assert.deepEqual(result, { ok: false, status: 409 });
    assert.equal(await count("SELECT COUNT(*) n FROM user_games WHERE user_id = $1 AND subject = 'busy'", [me]), 1);
  });

  test('a run that died without saying so does not hold the delete off', async () => {
    const me = await user();
    await game(me, 'stuck');
    await run(me, 'stuck', 'running', '2 hours');
    const result = await archiveDeletion.deleteSubjectGames(pool, {
      userId: me, subject: 'stuck', reapStale: importer.reapStale,
    });
    assert.deepEqual(result, { ok: true, deleted: 1 });
  });

  test('a player with no games is not found', async () => {
    const me = await user();
    const result = await archiveDeletion.deleteSubjectGames(pool, { userId: me, subject: 'nobody' });
    assert.equal(result.status, 404);
  });

  // ---- mistakes --------------------------------------------------------------

  test('a mistake leaves the drill; its game stays', async () => {
    const me = await user();
    const { gameId, mistakeId } = await game(me, 'drill');
    assert.equal(await mistakes.removeItem(pool, { userId: me, itemId: mistakeId }), true);
    assert.equal(await count('SELECT COUNT(*) n FROM mistake_reviews WHERE id = $1', [mistakeId]), 0);
    assert.equal(await count('SELECT COUNT(*) n FROM user_games WHERE id = $1', [gameId]), 1);
  });

  test("somebody else's mistake is not removed", async () => {
    const me = await user();
    const other = await user();
    const { mistakeId } = await game(other, 'theirs');
    assert.equal(await mistakes.removeItem(pool, { userId: me, itemId: mistakeId }), false);
    assert.equal(await count('SELECT COUNT(*) n FROM mistake_reviews WHERE id = $1', [mistakeId]), 1);
  });

  // ---- notifications ---------------------------------------------------------

  async function note(userId, read) {
    const r = await pool.query(
      `INSERT INTO user_notifications (user_id, title, message, is_read, kind)
       VALUES ($1, 't', 'm', $2, 'room') RETURNING id`,
      [userId, read]
    );
    return r.rows[0].id;
  }

  test('one notification is deleted, and only its owner can', async () => {
    const me = await user();
    const other = await user();
    const mine = await note(me, false);
    const theirs = await note(other, false);
    assert.equal(await notifications.removeOne(pool, { userId: me, id: theirs }), false);
    assert.equal(await notifications.removeOne(pool, { userId: me, id: mine }), true);
    assert.equal(await count('SELECT COUNT(*) n FROM user_notifications WHERE id = ANY($1)', [[mine, theirs]]), 1);
  });

  test('clearing takes what was read, keeps the unread and other accounts', async () => {
    const me = await user();
    const other = await user();
    await note(me, true);
    await note(me, true);
    const unread = await note(me, false);
    const theirs = await note(other, true);
    assert.equal(await notifications.clearRead(pool, { userId: me }), 2);
    assert.equal(await count('SELECT COUNT(*) n FROM user_notifications WHERE user_id = $1', [me]), 1);
    assert.equal(await count('SELECT COUNT(*) n FROM user_notifications WHERE id = $1', [unread]), 1);
    assert.equal(await count('SELECT COUNT(*) n FROM user_notifications WHERE id = $1', [theirs]), 1);
  });
});
