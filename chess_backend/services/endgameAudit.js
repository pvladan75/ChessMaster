// endgameAudit.js — the endings a player let slip, as a fact rather than an opinion.
//
// Section 2 of docs/PLAN-MOJE-PARTIJE.md. It walks the part of every archived
// game that reached seven men or fewer, asks the Syzygy tables what each
// position was worth to the player, and records the moves where that worth went
// down: a win turned into a draw, a draw into a loss.
//
// Why this feature is worth more than an engine pass over the same games: the
// verdict is exact. "You had a win here and gave it away" is not a depth-14
// opinion that a deeper search might overturn — it is what the position *is*.
// That is also the constraint the whole file is written around. A position the
// tables will not commit to ('unknown', 'maybe-win', 'maybe-loss') is counted
// and skipped, never rounded to the nearest verdict, because the moment one
// guess is dressed as a fact the feature's only promise is gone.
//
// Two things make it affordable. One probe answers a whole position — the
// response carries a category for every legal move — so the position before a
// move is enough and the position after never has to be asked about. And every
// answer is written to `tablebase_cache`, which is shared by every user, so the
// 8673 positions in a ten-year archive are twenty-odd minutes once and almost
// nothing afterwards.

const { Chess } = require('chess.js');
const { wdlOf, bestReply, TablebaseUnavailable } = require('./tablebaseService');
const logger = require('./logger');

/// Tablebase range. Seven is what Lichess serves.
const MAX_MEN = 7;

/// A run left 'running' after this long lost its process — see the same
/// reasoning in gameArchiveImport.js.
const STALE_RUN_MS = 60 * 60 * 1000;

class EndgameAuditUnavailable extends Error {
  constructor(message, { reason = 'error', status = 500 } = {}) {
    super(message);
    this.name = 'EndgameAuditUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

function menInFen(fen) {
  return String(fen).split(' ')[0].replace(/[^a-zA-Z]/g, '').length;
}

/// The cache key: the first five FEN fields.
///
/// Four everywhere else in this codebase, because the move counters make one
/// position look like two. Five here, because the halfmove clock is what
/// separates a win from a `cursed-win` — a win the fifty-move rule takes away.
/// Dropping it would cache one position's answer under another's question.
function tablebaseKey(fen) {
  return String(fen).trim().split(/\s+/).slice(0, 5).join(' ');
}

/// Walks one game and returns the moves that threw away what the tables say the
/// player had.
///
/// [probe] takes a FEN and returns `{ category, moves: [{ uci, category }] }` —
/// the shape `tablebaseService.probe` already produces. Injected so this, the
/// part with all the reasoning in it, is testable without a network.
///
/// Returns `{ findings, probed, unknown }`. `unknown` is carried out rather than
/// swallowed: it is the count of positions nobody judged, and a run that
/// reported only findings would look identical whether the tables answered or
/// not.
async function auditGame({ start_fen: startFen, moves, subject_color: color }, probe) {
  const board = new Chess(startFen);
  const findings = [];
  let probed = 0;
  let unknown = 0;

  for (let i = 0; i < (moves || []).length; i += 1) {
    const uci = moves[i];
    const fenBefore = board.fen();
    const subjectToMove = board.turn() === color;
    const inRange = menInFen(fenBefore) <= MAX_MEN;

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
    // A stored game that will not replay is a bug worth seeing rather than a
    // reason to audit the half that happened to work.
    if (!played) break;

    if (!inRange || !subjectToMove) continue;

    // eslint-disable-next-line no-await-in-loop
    const answer = await probe(fenBefore);
    probed += 1;

    const after = (answer.moves || []).find((m) => m.uci === uci);
    let before;
    let outcomeAfter;
    try {
      // The position's category is for the side to move, which here is the
      // player. Each move's category is for whoever moves *next* — the
      // opponent — so the player's own result after it is the negation.
      before = wdlOf(answer.category);
      // `0 - x` rather than `-x`: negating a drawn position gives JavaScript's
      // negative zero, which is stored as 0 and compares as 0 everywhere except
      // where somebody uses Object.is and spends an afternoon on it.
      outcomeAfter = 0 - wdlOf(after?.category);
    } catch (err) {
      if (err instanceof TablebaseUnavailable) {
        unknown += 1;
        continue;
      }
      throw err;
    }

    if (outcomeAfter >= before) continue;

    const best = bestReply(answer.moves);
    findings.push({
      ply: i + 1,
      fenBefore,
      playedUci: uci,
      playedSan: played.san,
      bestUci: best && best.uci !== uci ? best.uci : null,
      wdlBefore: before,
      wdlAfter: outcomeAfter,
    });
  }

  return { findings, probed, unknown };
}

function createEndgameAuditor({
  pool,
  tablebase = require('./tablebaseService').tablebase,
  staleRunMs = STALE_RUN_MS,
} = {}) {
  if (!pool) throw new TypeError('createEndgameAuditor requires a pool');

  let probes = 0;
  let hits = 0;

  /// The tables, with the shared table in front of them.
  async function cachedProbe(fen) {
    const key = tablebaseKey(fen);
    const hit = await pool.query(
      'SELECT category, dtz, moves FROM tablebase_cache WHERE fen = $1', [key],
    );
    if (hit.rowCount > 0) {
      hits += 1;
      const row = hit.rows[0];
      return { category: row.category, dtz: row.dtz, moves: row.moves || [] };
    }

    const value = await tablebase.probe(fen);
    probes += 1;
    // A cached answer is never wrong later — a tablebase result is a fact about
    // chess, not a measurement — so nothing here expires and a race just leaves
    // the row that got there first.
    await pool.query(
      `INSERT INTO tablebase_cache (fen, category, dtz, moves)
       VALUES ($1, $2, $3, $4::jsonb) ON CONFLICT (fen) DO NOTHING`,
      [key, value.category, value.dtz, JSON.stringify(value.moves || [])],
    );
    return value;
  }

  async function reapStale(userId) {
    await pool.query(
      `UPDATE endgame_audits
          SET status = 'failed',
              error = 'Provera završnica je prekinuta pre nego što se završila.',
              finished_at = NOW()
        WHERE user_id = $1 AND status = 'running'
          AND started_at < NOW() - ($2::int * INTERVAL '1 millisecond')`,
      [userId, staleRunMs],
    );
  }

  async function saveProgress(auditId, counts, { status, error } = {}) {
    await pool.query(
      `UPDATE endgame_audits
          SET games_total = $2, games_done = $3, positions_probed = $4,
              cache_hits = $5, positions_unknown = $6, mistakes_found = $7,
              status = COALESCE($8, status),
              error = COALESCE($9, error),
              finished_at = CASE WHEN $8 IN ('done', 'failed') THEN NOW() ELSE finished_at END
        WHERE id = $1`,
      [
        auditId, counts.gamesTotal, counts.gamesDone, counts.probed,
        counts.hits, counts.unknown, counts.mistakes, status || null, error || null,
      ],
    );
  }

  /// Every finding of one game, written where the spaced-repetition drill will
  /// find them. `mistake_reviews` was built for exactly this: its check
  /// constraint refuses a tablebase row that does not carry both verdicts.
  async function writeFindings(userId, gameId, findings) {
    if (findings.length === 0) return 0;
    const params = [];
    const tuples = findings.map((f) => {
      const values = [
        userId, gameId, f.ply, f.fenBefore, f.playedUci, f.bestUci,
        'tablebase', f.wdlBefore, f.wdlAfter,
      ];
      const start = params.length;
      params.push(...values);
      return `(${values.map((_, i) => `$${start + i + 1}`).join(', ')})`;
    });
    const result = await pool.query(
      `INSERT INTO mistake_reviews
         (user_id, game_id, ply, fen_before, played_uci, best_uci,
          kind, wdl_before, wdl_after)
       VALUES ${tuples.join(', ')}
       ON CONFLICT (user_id, game_id, ply) DO NOTHING`,
      params,
    );
    return result.rowCount;
  }

  async function run({ auditId, userId, subject }) {
    const counts = {
      gamesTotal: 0, gamesDone: 0, probed: 0, hits: 0, unknown: 0, mistakes: 0,
    };
    probes = 0;
    hits = 0;

    try {
      // Only the games that ever reached the tables — about one in nine. This
      // is what `min_men` and its partial index were written at import for.
      const { rows: games } = await pool.query(
        `SELECT id, start_fen, moves, subject_color
           FROM user_games
          WHERE user_id = $1 AND subject = $2 AND min_men <= $3
          ORDER BY id`,
        [userId, subject, MAX_MEN],
      );
      counts.gamesTotal = games.length;
      await saveProgress(auditId, counts);

      for (const game of games) {
        // eslint-disable-next-line no-await-in-loop
        const { findings, unknown } = await auditGame(game, cachedProbe);
        counts.unknown += unknown;
        // eslint-disable-next-line no-await-in-loop
        counts.mistakes += await writeFindings(userId, game.id, findings);
        counts.gamesDone += 1;
        counts.probed = probes;
        counts.hits = hits;
        if (counts.gamesDone % 20 === 0) {
          // eslint-disable-next-line no-await-in-loop
          await saveProgress(auditId, counts);
        }
      }

      await saveProgress(auditId, counts, { status: 'done' });
      logger.info(
        `[ZAVRŠNICE] Provera ${auditId} gotova: ${JSON.stringify(counts)}`,
      );
      return counts;
    } catch (err) {
      const message = err instanceof TablebaseUnavailable
        ? 'Tablica nije dostupna, pa je provera zaustavljena umesto da nagađa.'
        : `Provera završnica nije uspela: ${err.message}`;
      logger.error(`[ZAVRŠNICE] Provera ${auditId} pala: ${err.message}`);
      await saveProgress(auditId, counts, { status: 'failed', error: message })
        .catch((saveErr) => logger.error(
          `[ZAVRŠNICE] Provera ${auditId} nije mogla ni da upiše neuspeh: ${saveErr.message}`,
        ));
      throw err;
    }
  }

  async function start({ userId, subject }) {
    if (!Number.isInteger(userId)) throw new TypeError('userId is required');
    const handle = String(subject || '').trim();
    if (!handle) {
      throw new EndgameAuditUnavailable('Nedostaje korisničko ime.', {
        reason: 'bad-request', status: 400,
      });
    }

    await reapStale(userId);
    const running = await pool.query(
      `SELECT id FROM endgame_audits WHERE user_id = $1 AND status = 'running' LIMIT 1`,
      [userId],
    );
    if (running.rowCount > 0) {
      throw new EndgameAuditUnavailable('Provera završnica je već u toku.', {
        reason: 'already-running', status: 409,
      });
    }

    const created = await pool.query(
      `INSERT INTO endgame_audits (user_id, subject, status)
       VALUES ($1, $2, 'running') RETURNING id`,
      [userId, handle],
    );
    const auditId = created.rows[0].id;
    return { auditId, finished: run({ auditId, userId, subject: handle }) };
  }

  async function getRun(userId, auditId) {
    const { rows } = await pool.query(
      'SELECT * FROM endgame_audits WHERE id = $1 AND user_id = $2',
      [auditId, userId],
    );
    return rows[0] || null;
  }

  /// The findings themselves, newest game first, for the drill and the report.
  async function listMistakes(userId, { limit = 50 } = {}) {
    const { rows } = await pool.query(
      `SELECT m.id, m.game_id, m.ply, m.fen_before, m.played_uci, m.best_uci,
              m.wdl_before, m.wdl_after, m.due_at,
              g.played_at, g.opponent, g.result
         FROM mistake_reviews m
         JOIN user_games g ON g.id = m.game_id
        WHERE m.user_id = $1 AND m.kind = 'tablebase'
        ORDER BY (m.wdl_before - m.wdl_after) DESC, g.played_at DESC NULLS LAST
        LIMIT $2`,
      [userId, limit],
    );
    return rows;
  }

  return { start, getRun, listMistakes, reapStale, cachedProbe };
}

module.exports = {
  auditGame,
  createEndgameAuditor,
  EndgameAuditUnavailable,
  tablebaseKey,
  MAX_MEN,
};
