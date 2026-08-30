// repertoireArchive.js — the bridge between what a player does and what they meant to.
//
// Section 4 of docs/PLAN-MOJE-PARTIJE.md, both halves:
//
//   * **seed** — build a repertoire out of the moves the player already plays,
//     so nobody types in a thousand games of their own French by hand;
//   * **diff** — the games where they left it.
//
// Both are joins rather than new machinery, and that is the payoff for a
// decision made two days into this work: `opening_nodes` keys on the same
// `fen_key` as `repertoire_moves` — the first four FEN fields — so a habit and
// an intention meet in the same row without anything being converted. Had the
// two spellings differed, the diff would not have errored. It would have come
// back empty, which reads as "you never left your repertoire".
//
// The seed writes through `addMove` in repertoireService.js rather than
// inserting directly. That function already holds the rule this feature could
// most easily break — one primary move per position, the rest alternates, held
// by a partial unique index — and a second copy of that condition is how the
// three hand-written trainer subqueries in this codebase each forgot a status.
// It costs two queries per move, which for a one-off seed is the cheaper
// mistake.

const { Chess } = require('chess.js');
const { addMove, ensureRepertoire } = require('./repertoireService');
const { fenFromKey } = require('./openingLeaks');
const logger = require('./logger');

/// What a seeded repertoire is called, per colour, and where it starts.
///
/// Serbian because it is a name the player reads in a list. One name per
/// colour, fixed, so a second seed finds the first one instead of making a
/// duplicate — `repertoires` is unique on (user, name), which is what makes
/// that work.
const SEED_NAMES = { w: 'Iz mojih partija — beli', b: 'Iz mojih partija — crni' };
const SEED_ROOT_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A position has to have been reached this often before it is worth calling
/// part of somebody's repertoire. Lower than the leak report's eight, because
/// this is describing what a player plays rather than judging it.
const DEFAULT_MIN_GAMES = 5;

/// How much of a position's games a second answer needs before it is a real
/// alternative rather than a slip. A move played twice out of forty is not a
/// repertoire choice.
const DEFAULT_MIN_SHARE = 0.15;

const DEFAULT_MAX_ALTERNATES = 2;

/// How many positions are written at once. Positions are independent of each
/// other; the moves inside one are not — see the comment in [seedFromArchive].
const SEED_CONCURRENCY = 8;

function requireColor(color) {
  if (color !== null && !['w', 'b'].includes(color)) {
    throw new RangeError('Boja mora biti „w" ili „b".');
  }
}

/// SAN is unique inside a position, but the repertoire stores UCI too, so the
/// move has to be played to find out what it is. Returns null for a SAN that
/// does not fit the board, which should not happen and is counted when it does.
function uciOf(fenKey, san) {
  try {
    const board = new Chess(fenFromKey(fenKey));
    const played = board.move(san, { strict: false });
    return played ? `${played.from}${played.to}${played.promotion ?? ''}` : null;
  } catch {
    return null;
  }
}

/// What the player actually plays, position by position, most-played first.
async function playedMoves(pool, userId, { subject, color, minGames }) {
  const { rows } = await pool.query(
    `SELECT fen_key, subject_color AS color, san,
            COUNT(*)::int AS games, MIN(ply)::int AS ply
       FROM opening_nodes
      WHERE user_id = $1 AND subject = $2
        AND ($3::char(1) IS NULL OR subject_color = $3)
      GROUP BY fen_key, subject_color, san`,
    [userId, subject, color],
  );

  const byPosition = new Map();
  for (const row of rows) {
    const key = `${row.color}|${row.fen_key}`;
    const position = byPosition.get(key)
      || { fenKey: row.fen_key, color: row.color, ply: row.ply, games: 0, moves: [] };
    position.games += row.games;
    position.ply = Math.min(position.ply, row.ply);
    position.moves.push({ san: row.san, games: row.games });
    byPosition.set(key, position);
  }

  return [...byPosition.values()]
    .filter((p) => p.games >= minGames)
    .map((p) => ({ ...p, moves: p.moves.sort((a, b) => b.games - a.games) }))
    .sort((a, b) => b.games - a.games);
}

/// Builds a repertoire out of the archive.
///
/// Never demotes anything: `addMove` makes the first move into a position the
/// primary and every later one an alternate, so a position the player has
/// already decided about keeps their decision and gains the rest as
/// alternatives. A seed that overwrote a hand-built repertoire would be the
/// worst possible way to introduce this feature.
async function seedFromArchive(pool, userId, {
  subject,
  color = null,
  minGames = DEFAULT_MIN_GAMES,
  minShare = DEFAULT_MIN_SHARE,
  maxAlternates = DEFAULT_MAX_ALTERNATES,
  dryRun = false,
} = {}) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  const handle = String(subject || '').trim();
  if (!handle) throw new RangeError('Nedostaje korisničko ime.');
  requireColor(color);

  const positions = await playedMoves(pool, userId, { subject: handle, color, minGames });

  const plan = [];
  let unplayable = 0;
  for (const position of positions) {
    const chosen = position.moves
      .filter((m, index) => index === 0 || m.games / position.games >= minShare)
      .slice(0, 1 + maxAlternates);

    for (const move of chosen) {
      const uci = uciOf(position.fenKey, move.san);
      if (!uci) {
        // A SAN that will not replay in its own position means the node was
        // written wrong. Counted rather than dropped, because the number being
        // above zero is a bug report.
        unplayable += 1;
        continue;
      }
      plan.push({
        color: position.color,
        fenKey: position.fenKey,
        fen: fenFromKey(position.fenKey),
        san: move.san,
        uci,
        games: move.games,
        share: move.games / position.games,
        ply: position.ply,
      });
    }
  }

  if (dryRun) {
    return {
      dryRun: true, positions: positions.length, moves: plan.length, unplayable, plan,
    };
  }

  // Measured on a ten-year archive: the default floor plans 648 positions and
  // 1132 moves, and `addMove` costs two queries each — 2264 round trips to a
  // managed database is far too long to hold a request open for.
  //
  // So positions are written in parallel and the moves **inside** one position
  // stay sequential. That is not a tuning choice: `addMove` decides primary
  // versus alternate by looking for an existing primary, so two moves into the
  // same position at once would both find none and both insert a primary — and
  // the partial unique index would refuse the second, failing a seed halfway
  // through for a reason that has nothing to do with the player.
  const grouped = new Map();
  for (const move of plan) {
    const key = `${move.color}|${move.fenKey}`;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(move);
  }

  let added = 0;
  let primary = 0;
  const queue = [...grouped.values()];
  const workers = Array.from({ length: Math.min(SEED_CONCURRENCY, queue.length) }, async () => {
    for (;;) {
      const group = queue.shift();
      if (!group) return;
      for (const move of group) {
        // eslint-disable-next-line no-await-in-loop
        const written = await addMove(pool, userId, {
          color: move.color, fen: move.fen, uci: move.uci, san: move.san,
        });
        added += 1;
        if (written && written.role === 'primary') primary += 1;
      }
    }
  });
  await Promise.all(workers);

  // The moves are written; now make them findable. Every colour that actually
  // received one gets its named row, because a colour with no moves does not
  // need a name and an empty repertoire in the list is worse than no entry.
  //
  // After the moves, never before: `ensureRepertoire` failing must not be able
  // to take down a seed that has already succeeded. Do the thing, then say it.
  const seededColors = [...new Set(plan.map((move) => move.color))].sort();
  const named = [];
  for (const color of seededColors) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const row = await ensureRepertoire(pool, userId, {
        name: SEED_NAMES[color], color, rootFen: SEED_ROOT_FEN,
      });
      if (row) named.push(row.name);
    } catch (err) {
      logger.error(`[REPERTOAR] Ime repertoara nije upisano: ${err.message}`);
    }
  }

  logger.info(
    `[REPERTOAR] Zasejano iz arhive: ${added} poteza u ${positions.length} pozicija.`,
  );
  return {
    dryRun: false,
    positions: positions.length,
    moves: plan.length,
    added,
    primary,
    unplayable,
    // One name only when one colour was seeded. A seed over both colours writes
    // two rows and there is no single answer, and a name the caller then shows
    // in "written into X" would be half a truth.
    repertoireName: named.length === 1 ? named[0] : null,
  };
}

/// Where the player left their own repertoire.
///
/// Only positions the repertoire actually covers are counted. A position it
/// says nothing about is not a deviation — it is a gap, which is a different
/// report and a different feeling.
async function repertoireDiff(pool, userId, {
  subject, color = null, limit = 40,
} = {}) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  const handle = String(subject || '').trim();
  if (!handle) throw new RangeError('Nedostaje korisničko ime.');
  requireColor(color);
  const cap = Number.isInteger(limit) && limit > 0 && limit <= 200 ? limit : 40;

  const { rows } = await pool.query(
    `WITH covered AS (
       SELECT DISTINCT color, fen_key FROM repertoire_moves WHERE user_id = $1
     ),
     played AS (
       SELECT n.fen_key, n.subject_color AS color, n.san, n.ply, n.subject_score,
              EXISTS (
                SELECT 1 FROM repertoire_moves r
                 WHERE r.user_id = $1 AND r.color = n.subject_color
                   AND r.fen_key = n.fen_key AND r.san = n.san
              ) AS in_repertoire
         FROM opening_nodes n
         JOIN covered c ON c.fen_key = n.fen_key AND c.color = n.subject_color
        WHERE n.user_id = $1 AND n.subject = $2
          AND ($3::char(1) IS NULL OR n.subject_color = $3)
     )
     SELECT fen_key, color, san, in_repertoire,
            COUNT(*)::int AS games,
            SUM(subject_score)::numeric AS points,
            MIN(ply)::int AS ply
       FROM played
      GROUP BY fen_key, color, san, in_repertoire`,
    [userId, handle, color],
  );

  const byPosition = new Map();
  let followed = 0;
  let left = 0;
  let unplayable = 0;
  for (const row of rows) {
    if (row.in_repertoire) followed += row.games;
    else left += row.games;

    const key = `${row.color}|${row.fen_key}`;
    const position = byPosition.get(key) || {
      fenKey: row.fen_key,
      fen: fenFromKey(row.fen_key),
      color: row.color,
      ply: row.ply,
      games: 0,
      leftGames: 0,
      prepared: [],
      played: [],
    };
    position.games += row.games;
    position.ply = Math.min(position.ply, row.ply);
    // `uci` travels beside the SAN for the same reason the seed plan carries
    // it: this report exists to hand positions to the drill, and a drill can
    // play a move only in the notation a board takes. Deriving it in the client
    // would mean a second replay of the same position, in a second chess
    // library, with its own opinion about an ambiguous SAN — and the two would
    // disagree silently, on exactly the positions that are hardest to read.
    //
    // Null when the SAN will not replay, which is a bug report rather than a
    // value: the node was written wrong. Counted below.
    const uci = uciOf(row.fen_key, row.san);
    if (!uci) unplayable += 1;
    const entry = {
      san: row.san,
      uci,
      games: row.games,
      score: Number(row.points) / row.games,
    };
    if (row.in_repertoire) position.prepared.push(entry);
    else {
      position.played.push(entry);
      position.leftGames += row.games;
    }
    byPosition.set(key, position);
  }

  const positions = [...byPosition.values()]
    .filter((p) => p.leftGames > 0)
    .map((p) => ({
      ...p,
      prepared: p.prepared.sort((a, b) => b.games - a.games),
      played: p.played.sort((a, b) => b.games - a.games),
    }))
    .sort((a, b) => b.leftGames - a.leftGames)
    .slice(0, cap);

  return {
    subject: handle,
    color,
    // The headline sentence: of the games that reached a position you had
    // prepared, this many did not follow the preparation.
    coveredGames: followed + left,
    followedGames: followed,
    leftGames: left,
    // Above zero means some stored SAN would not replay in its own position.
    // Reported rather than hidden, the same as in the seed: the number being
    // non-zero is the bug report.
    unplayable,
    positions,
  };
}

module.exports = {
  seedFromArchive,
  repertoireDiff,
  playedMoves,
  uciOf,
  DEFAULT_MIN_GAMES,
  DEFAULT_MIN_SHARE,
  DEFAULT_MAX_ALTERNATES,
};
