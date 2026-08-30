// openingLeaks.js — where a player keeps making the same early choice badly.
//
// Section 1 of docs/PLAN-MOJE-PARTIJE.md, and the cheapest thing in the plan:
// no engine, no network, no tablebase. It is a GROUP BY over `opening_nodes`.
//
// What it looks for is not "you score badly here" — that is mostly variance
// over eight games — but "you score badly here **and you keep choosing the same
// move**". On the archive that sized this plan, one position at ply 10 came up
// 35 times and the same knight move was played in 33 of them, for 37%. That is
// a habit, and a habit is fixable in a way a list of one-off blunders is not.
//
// Two rules are held here rather than left to the caller:
//
// **The window is 6 to 20 plies and cannot be widened.** Past about move ten
// every game in a real archive is nearly unique, so a per-position score stops
// being a statistic and starts being one game with a percentage next to it.
// `opening_nodes` stores nothing past ply 20, and asking for more is a
// RangeError rather than a quietly shorter answer.
//
// **Games whose nodes were never written are counted and reported.** An archive
// imported before this table existed produces an empty report, and an empty
// report reads exactly like a player with no weaknesses. So the report carries
// `gamesWithoutNodes`, and the caller is expected to say so.

const { Chess } = require('chess.js');
const { NODE_WINDOW_PLIES, fenKey } = require('./gameArchive');
const logger = require('./logger');

const MIN_PLY = 1;
const DEFAULT_FROM_PLY = 6;
const DEFAULT_TO_PLY = NODE_WINDOW_PLIES;

/// Eight games is where a percentage stops being an anecdote. Below it, one
/// unlucky evening is a 30% score and the report would name it a weakness.
const DEFAULT_MIN_GAMES = 8;

/// Under 42% over a repeated position is a losing habit rather than noise: an
/// even player scores 50, and the archive that sized this plan sits at 49.9.
const DEFAULT_MAX_SCORE = 0.42;

const DEFAULT_LIMIT = 40;

function requirePly(value, name, fallback) {
  if (value === undefined || value === null || value === '') return fallback;
  const ply = Number(value);
  if (!Number.isInteger(ply) || ply < MIN_PLY || ply > NODE_WINDOW_PLIES) {
    throw new RangeError(
      `${name} mora biti između ${MIN_PLY} i ${NODE_WINDOW_PLIES}. `
      + 'Dublje od dvadesetog poluteza svaka partija je gotovo jedinstvena, '
      + 'pa procenat po poziciji više ništa ne meri.',
    );
  }
  return ply;
}

function requireNumber(value, name, fallback, { min, max }) {
  if (value === undefined || value === null || value === '') return fallback;
  const number = Number(value);
  if (!Number.isFinite(number) || number < min || number > max) {
    throw new RangeError(`${name} mora biti između ${min} i ${max}.`);
  }
  return number;
}

/// A board the client can draw from a stored key. `fen_key` is four fields by
/// design — the move counters are exactly what would make one position look
/// like two — so the counters are put back as the neutral pair.
function fenFromKey(key) {
  return `${key} 0 1`;
}

/// The report.
///
/// Returns positions the subject reached at least [minGames] times inside the
/// window and scored below [maxScore] in, each with the moves they chose there
/// and how each one did. Ordered by how often the position came up, because a
/// bad habit in 35 games matters more than a worse one in 9.
async function leakReport(pool, userId, {
  subject,
  color = null,
  fromPly,
  toPly,
  minGames,
  maxScore,
  speed = null,
  limit,
} = {}) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  const handle = String(subject || '').trim();
  if (!handle) throw new RangeError('Nedostaje korisničko ime.');
  if (color !== null && !['w', 'b'].includes(color)) {
    throw new RangeError('Boja mora biti „w" ili „b".');
  }

  const from = requirePly(fromPly, 'Početni polupotez', DEFAULT_FROM_PLY);
  const to = requirePly(toPly, 'Krajnji polupotez', DEFAULT_TO_PLY);
  if (from > to) throw new RangeError('Početni polupotez je posle krajnjeg.');

  const floor = requireNumber(minGames, 'Najmanji broj partija', DEFAULT_MIN_GAMES,
    { min: 2, max: 1000 });
  const ceiling = requireNumber(maxScore, 'Gornji prag prolaznosti', DEFAULT_MAX_SCORE,
    { min: 0, max: 1 });
  const cap = requireNumber(limit, 'Broj pozicija', DEFAULT_LIMIT, { min: 1, max: 200 });

  const { rows } = await pool.query(
    `WITH picked AS (
       SELECT n.fen_key, n.san, n.ply, n.subject_score
         FROM opening_nodes n
         JOIN user_games g ON g.id = n.game_id
        WHERE n.user_id = $1
          AND n.subject = $2
          AND ($3::char(1) IS NULL OR n.subject_color = $3)
          AND n.ply BETWEEN $4 AND $5
          AND ($6::varchar IS NULL OR g.speed = $6)
     ),
     by_move AS (
       SELECT fen_key, san, COUNT(*)::int AS games,
              SUM(subject_score)::numeric AS points, MIN(ply)::int AS ply
         FROM picked GROUP BY fen_key, san
     ),
     by_node AS (
       SELECT fen_key, SUM(games)::int AS games,
              SUM(points)::numeric AS points, MIN(ply)::int AS ply
         FROM by_move GROUP BY fen_key
     ),
     ranked AS (
       SELECT *, ROW_NUMBER() OVER (ORDER BY games DESC, points ASC) AS rk
         FROM by_node
        WHERE games >= $7 AND (points / games) < $8
     )
     SELECT r.rk, r.fen_key, r.games AS node_games, r.points AS node_points,
            r.ply AS node_ply, m.san, m.games AS move_games, m.points AS move_points
       FROM ranked r
       JOIN by_move m ON m.fen_key = r.fen_key
      WHERE r.rk <= $9
      ORDER BY r.rk, m.games DESC, m.san`,
    [userId, handle, color, from, to, speed, floor, ceiling, cap],
  );

  const byKey = new Map();
  for (const row of rows) {
    if (!byKey.has(row.fen_key)) {
      byKey.set(row.fen_key, {
        fenKey: row.fen_key,
        fen: fenFromKey(row.fen_key),
        ply: row.node_ply,
        games: row.node_games,
        score: Number(row.node_points) / row.node_games,
        moves: [],
      });
    }
    byKey.get(row.fen_key).moves.push({
      san: row.san,
      games: row.move_games,
      score: Number(row.move_points) / row.move_games,
      share: row.move_games / row.node_games,
    });
  }

  const nodes = [...byKey.values()];
  const coverage = await coverageOf(pool, userId, handle, color);

  return {
    subject: handle,
    color,
    window: { fromPly: from, toPly: to },
    thresholds: { minGames: floor, maxScore: ceiling },
    ...coverage,
    nodes,
  };
}

/// How much of the archive the report actually saw.
///
/// `gamesWithoutNodes` is the loud half: games imported before `opening_nodes`
/// existed contribute nothing, and a report that stayed silent about them would
/// be a smaller answer wearing the same shape as a complete one.
async function coverageOf(pool, userId, subject, color) {
  const { rows } = await pool.query(
    `SELECT COUNT(*)::int AS games,
            COUNT(*) FILTER (
              WHERE NOT EXISTS (SELECT 1 FROM opening_nodes n WHERE n.game_id = g.id)
            )::int AS without_nodes
       FROM user_games g
      WHERE g.user_id = $1 AND g.subject = $2
        AND ($3::char(1) IS NULL OR g.subject_color = $3)`,
    [userId, subject, color],
  );
  const row = rows[0] || { games: 0, without_nodes: 0 };
  return { games: row.games, gamesWithoutNodes: row.without_nodes };
}

/// Fills `opening_nodes` for games stored before it existed, by replaying the
/// UCI moves already on the row. Idempotent, and safe to re-run.
async function backfillNodes(pool, userId, { batchGames = 200, maxGames = 20000 } = {}) {
  let games = 0;
  let nodes = 0;

  for (;;) {
    const { rows } = await pool.query(
      `SELECT g.id, g.subject, g.subject_color, g.subject_score, g.start_fen, g.moves
         FROM user_games g
        WHERE g.user_id = $1
          AND NOT EXISTS (SELECT 1 FROM opening_nodes n WHERE n.game_id = g.id)
        ORDER BY g.id
        LIMIT $2`,
      [userId, batchGames],
    );
    if (rows.length === 0) break;

    const params = [];
    const tuples = [];
    for (const game of rows) {
      for (const node of replayNodes(game)) {
        const values = [
          userId, game.id, game.subject, game.subject_color, game.subject_score,
          node.ply, node.fen_key, node.san,
        ];
        const start = params.length;
        params.push(...values);
        tuples.push(`(${values.map((_, i) => `$${start + i + 1}`).join(', ')})`);
      }
    }
    games += rows.length;

    if (tuples.length > 0) {
      await pool.query(
        `INSERT INTO opening_nodes
           (user_id, game_id, subject, subject_color, subject_score, ply, fen_key, san)
         VALUES ${tuples.join(', ')}
         ON CONFLICT (game_id, ply) DO NOTHING`,
        params,
      );
      nodes += tuples.length;
    } else {
      // Every game in this batch produced nothing — a game of fewer than six
      // plies can. Without this the loop would ask for the same batch forever.
      break;
    }
    if (games >= maxGames) break;
  }

  logger.info(`[OTVARANJA] Dopunjeno ${nodes} čvorova iz ${games} partija.`);
  return { games, nodes };
}

/// Replays one stored game far enough to recover its early decisions.
function replayNodes(game) {
  const board = new Chess(game.start_fen);
  const wanted = game.subject_color;
  const out = [];
  const moves = game.moves || [];
  for (let i = 0; i < moves.length && i < NODE_WINDOW_PLIES; i += 1) {
    const uci = moves[i];
    const before = board.fen();
    const toMove = board.turn();
    let played;
    try {
      played = board.move({
        from: uci.slice(0, 2),
        to: uci.slice(2, 4),
        promotion: uci.length > 4 ? uci.slice(4, 5) : undefined,
      });
    } catch {
      played = null;
    }
    // A game whose stored moves do not replay is a bug worth seeing, not a
    // reason to write half an opening: stop at the break rather than skipping.
    if (!played) break;
    if (toMove === wanted) {
      out.push({ ply: i + 1, fen_key: fenKey(before), san: played.san });
    }
  }
  return out;
}

module.exports = {
  leakReport,
  backfillNodes,
  replayNodes,
  fenFromKey,
  DEFAULT_FROM_PLY,
  DEFAULT_TO_PLY,
  DEFAULT_MIN_GAMES,
  DEFAULT_MAX_SCORE,
};
