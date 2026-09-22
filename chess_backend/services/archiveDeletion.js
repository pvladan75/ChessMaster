// archiveDeletion.js — deleting one player's games from the account's archive.
//
// Until 22.9.2026 imported games could not be deleted at all, by anybody. A
// player's card on „My games" is one handle's **own** games (`OWN_GAMES_SQL`),
// across every source, and that is what this deletes. What was computed from
// them goes with them by the schema's own cascade: the mistakes drilled from
// those games (`mistake_reviews`) and the opening statistics
// (`opening_nodes`) both reference `user_games` ON DELETE CASCADE.
//
// Two rules, both in one transaction:
//   * **Not while an import for that player is running.** A run still writing
//     would put games back behind the delete. A run that died without saying
//     so is reaped first, so it cannot hold the delete off for ever.
//   * **The import history goes too, once nothing of that handle is left**, so
//     „My games" does not keep a „last import" for a player it no longer has.
//     An opponent-preparation import of the same handle keeps its history while
//     its games are there.
const { OWN_GAMES_SQL } = require('./archiveScope');

/// Deletes [subject]'s own games for [userId]. Answers `{ ok: true, deleted }`,
/// `{ ok: false, status: 404 }` when there are none, or
/// `{ ok: false, status: 409 }` while an import of that handle is running.
async function deleteSubjectGames(pool, { userId, subject, reapStale = null }) {
  if (typeof subject !== 'string' || !subject.trim()) return { ok: false, status: 404 };
  if (reapStale) await reapStale(userId);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const running = await client.query(
      `SELECT id FROM user_game_imports
        WHERE user_id = $1 AND subject = $2 AND status = 'running'
        FOR UPDATE`,
      [userId, subject]
    );
    if (running.rowCount > 0) {
      await client.query('ROLLBACK');
      return { ok: false, status: 409 };
    }
    const games = await client.query(
      `DELETE FROM user_games
        WHERE user_id = $1 AND subject = $2 AND ${OWN_GAMES_SQL}
        RETURNING id`,
      [userId, subject]
    );
    if (games.rowCount === 0) {
      await client.query('ROLLBACK');
      return { ok: false, status: 404 };
    }
    await client.query(
      `DELETE FROM user_game_imports
        WHERE user_id = $1 AND subject = $2
          AND NOT EXISTS (SELECT 1 FROM user_games g WHERE g.user_id = $1 AND g.subject = $2)`,
      [userId, subject]
    );
    await client.query('COMMIT');
    return { ok: true, deleted: games.rowCount };
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { deleteSubjectGames };
