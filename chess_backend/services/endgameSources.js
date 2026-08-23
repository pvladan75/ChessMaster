// Which database a position or a game came out of, and what that is worth.
//
// The collection is mined from three places: the Lumbras over-the-board base,
// forty-three single-player master bases, and the Lumbras online base. The
// first two are the same thing for teaching purposes - a game played at a
// board, by people whose rating means what it usually means - and they are
// pooled. The online base is not.
//
// The reason is the rating, which is where difficulty comes from: an online
// 2200 and an over-the-board 2200 are not the same player, so one number would
// mean two things on one ladder. The positions are still worth having, which is
// why they are here at all; they are just kept askable-for rather than mixed in
// by default.
//
// One place knows the name, because two would drift: `endgame_puzzles` and
// `blunder_games` both store the file they came from, and both routes filter on
// it.

const ONLINE_SOURCE_DB = 'LumbrasGigaBase_Online_Complete.pgn';

/// Whether a stored source name is the online base.
function isOnlineSource(sourceDb) {
  return sourceDb === ONLINE_SOURCE_DB;
}

/// A WHERE clause that leaves the online games out.
///
/// `IS DISTINCT FROM` rather than `<>`, and that is the whole point of writing
/// it once: the mined positions carry no source at all, and `source_db <> '...'`
/// is null for them, so a plain comparison would silently drop every position
/// the miner found - most of the collection - while looking like it filtered
/// one base.
function excludeOnlineClause(column = 'source_db') {
  return `${column} IS DISTINCT FROM '${ONLINE_SOURCE_DB}'`;
}

module.exports = { ONLINE_SOURCE_DB, isOnlineSource, excludeOnlineClause };
