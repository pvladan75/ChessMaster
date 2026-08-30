// archiveScope.js — the one place that says "the player's own games".
//
// `user_games` was built to hold two different things under one roof: the games
// the player imported about themselves (`subject_is_owner = TRUE`), and — from
// section 7 — an opponent's public archive, pulled to prepare for a match.
// Those rows are the same shape, sit in the same table, and belong to the same
// `user_id`. Only that one column tells them apart.
//
// Which means every query that answers a question **about the player** has to
// say so, and the ones that forgot were invisible until the day the second kind
// of row existed:
//
//   - the archive summary counted every row for the user, so "your archive has
//     4126 games" silently became "4126 of yours plus 200 of your opponent's";
//   - the engine-mistake door re-checked that a `game_id` belonged to the
//     caller and stopped there, so an opponent's blunder could be filed as the
//     player's own and then ranked in their recurrence report — "you keep
//     hanging pieces", built out of somebody else's games;
//   - the endgame audit took a subject and read every game under it, which is
//     the same door one step earlier.
//
// This is the codebase's recurring bug in its usual costume: nothing throws,
// nothing is logged, and a number the player believes quietly stops being true.
// So the condition is written here once and imported, the way `trainerOwnsStudent`
// and `acceptedTrainersOf` are — and `test/archive_scope.test.js` fails if a
// fourth hand-written copy appears.
//
// Reports *about an opponent* are not a violation of this; they are the point
// of section 7. They scope by `subject` instead, and they must never use the
// helpers here.

/// The condition itself. Interpolated into SQL rather than parameterised
/// because it is a fixed predicate, not a value — there is no version of this
/// that takes user input.
const OWN_GAMES_SQL = 'subject_is_owner = TRUE';

/// Of the game ids handed in, the ones that are the caller's **own** games.
///
/// Two conditions and not one. `user_id` alone answers "is this row mine",
/// which an opponent archive I imported also satisfies; the second answers "is
/// this a game about me", which is the question every teaching feature is
/// actually asking. A game id arriving from a client is a number somebody could
/// have guessed, so this is also the ownership check — it has to be both.
async function ownGameIds(pool, userId, ids) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  const wanted = [...new Set((ids || []).map(Number).filter(Number.isFinite))];
  if (wanted.length === 0) return new Set();

  const { rows } = await pool.query(
    `SELECT id FROM user_games
      WHERE user_id = $1 AND ${OWN_GAMES_SQL} AND id = ANY($2::bigint[])`,
    [userId, wanted],
  );
  // Ids come back from `pg` as strings for `bigint`, and callers compare
  // against values that may be either. Normalising here means no caller has to
  // remember which it holds.
  return new Set(rows.map((r) => String(r.id)));
}

/// True when this handle is one the player imported about themselves.
///
/// The gate in front of anything that teaches from a subject: the endgame audit
/// takes a username and would otherwise happily walk an opponent's archive and
/// write the findings into the caller's own drill.
async function isOwnSubject(pool, userId, subject) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  const handle = String(subject || '').trim();
  if (!handle) return false;

  const { rows } = await pool.query(
    `SELECT 1 FROM user_games
      WHERE user_id = $1 AND subject = $2 AND ${OWN_GAMES_SQL} LIMIT 1`,
    [userId, handle],
  );
  return rows.length > 0;
}

module.exports = { OWN_GAMES_SQL, ownGameIds, isOwnSubject };
