// openingJudgements.js — what the device's engine said about a player's habits.
//
// docs/PLAN-MOJE-PARTIJE.md §9.2. Section 1's report counts results and
// nothing else, and measured on the owner's 4126 games that is mostly a report
// about something else than it says: 82 of its 84 flagged positions have no
// losing habit at all — the move the player keeps choosing holds, and the low
// score comes later. The engine tells the two apart, and it runs on the device,
// never on the 960 MB droplet; this file stores what it said and hands it back
// beside the report.
//
// **The mistake rule is not here** (rule 12). The device judges with its one
// rule (`lib/core/services/mistake_rule.dart`) and hands over the verdict with
// the numbers behind it. What this file checks is what can be checked without
// the rule: the position is one the caller reached, the moves are legal, the
// lines replay, the chances are chances. A verdict is stored as given.
//
// **Per user, and gone with the games.** A position from a private game names
// the game, so a judgement belongs to the account that reached it, and a
// position no archive of that account reaches any more takes its judgements
// with it (archiveDeletion.js).

const { Chess } = require('chess.js');
const { fenFromKey } = require('./openingLeaks');
const { OpeningBookUnavailable } = require('./openingBook');

/// One batch from the device. The owner's archive holds 573 habit moves; a
/// device sends them as they are judged, a few dozen at a time.
const MAX_ITEMS_PER_CALL = 200;

/// A line longer than this is not a line to show; the reveal cuts at 12 plies
/// and the store keeps what the engine gave (PLAN-ZAGONETKE-IZ-PARTIJE.md §3).
const MAX_LINE_PLIES = 40;

const VERDICTS = new Set(['mistake', 'holds']);
const REASONS = new Set(['lostChances', 'grossInBook', 'missedMate']);

function isFenKey(value) {
  return typeof value === 'string' && value.trim().split(/\s+/).length === 4;
}

/// Plays [uci] on [fen] and answers the board after it, or null when the move
/// is not legal there.
function play(fen, uci) {
  if (typeof uci !== 'string' || !/^[a-h][1-8][a-h][1-8][qrbn]?$/.test(uci)) return null;
  const board = new Chess(fen);
  try {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
  } catch (_) {
    return null;
  }
  return board;
}

/// Whether [sans] replays from [fen] and starts with the move [uci].
function replays(fen, uci, sans) {
  if (!Array.isArray(sans) || sans.length === 0 || sans.length > MAX_LINE_PLIES) return false;
  const board = new Chess(fen);
  for (let i = 0; i < sans.length; i++) {
    if (typeof sans[i] !== 'string') return false;
    let move;
    try {
      move = board.move(sans[i]);
    } catch (_) {
      return false;
    }
    if (i === 0 && `${move.from}${move.to}${move.promotion || ''}` !== uci) return false;
  }
  return true;
}

function isChances(value) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 100;
}

/// Why one judgement cannot be stored, or null. Everything but ownership, which
/// needs the database.
function whyNotStorable(item) {
  if (!item || typeof item !== 'object') return 'not-an-object';
  if (!isFenKey(item.fenKey)) return 'no-position';
  const fen = fenFromKey(item.fenKey.trim());
  try {
    new Chess(fen); // eslint-disable-line no-new
  } catch (_) {
    return 'no-position';
  }
  if (!play(fen, item.moveUci)) return 'illegal-move';
  if (!play(fen, item.bestUci)) return 'illegal-best';
  if (!replays(fen, item.bestUci, item.bestLine)) return 'best-line-does-not-replay';
  if (!replays(fen, item.moveUci, item.moveLine)) return 'move-line-does-not-replay';
  if (!isChances(item.wBest) || !isChances(item.wMove)) return 'not-chances';
  if (!VERDICTS.has(item.verdict)) return 'no-verdict';
  // A mistake says why, and a move that holds has no reason to give: the rule's
  // own shape, which the table's check holds as well.
  if ((item.verdict === 'mistake') !== REASONS.has(item.reason)) return 'no-reason';
  if (!Number.isInteger(item.depth) || item.depth < 1 || item.depth > 99) return 'no-depth';
  if (typeof item.engine !== 'string' || !item.engine.trim() || item.engine.length > 64) {
    return 'no-engine';
  }
  if (item.bookGames !== undefined && item.bookGames !== null
    && !(Number.isInteger(item.bookGames) && item.bookGames >= 0)) {
    return 'no-book-count';
  }
  return null;
}

/// Stores the judgements that hold up. The answer is a tally — every item is
/// stored (new or replacing a shallower one), kept out by a deeper one already
/// there, or rejected with a named reason — and it refuses to return when
/// those do not add up, as the importer and the mistakes door do.
async function recordJudgements(pool, userId, items = []) {
  if (!Number.isInteger(userId)) throw new TypeError('userId is required');
  if (!Array.isArray(items)) throw new RangeError('A list of judgements is required.');
  if (items.length > MAX_ITEMS_PER_CALL) {
    throw new RangeError(`At most ${MAX_ITEMS_PER_CALL} judgements per call.`);
  }

  const rejected = [];
  const candidates = [];
  items.forEach((item, index) => {
    const reason = whyNotStorable(item);
    if (reason) rejected.push({ index, reason });
    else candidates.push({ item, index, fenKey: item.fenKey.trim() });
  });

  // The position has to be one the caller reached. It arrives from a client,
  // and a judgement filed under a position nobody here played would sit in
  // this account's report as if it were a habit.
  let reached = new Set();
  if (candidates.length > 0) {
    const { rows } = await pool.query(
      `SELECT DISTINCT fen_key FROM opening_nodes
        WHERE user_id = $1 AND fen_key = ANY($2::text[])`,
      [userId, [...new Set(candidates.map((c) => c.fenKey))]],
    );
    reached = new Set(rows.map((r) => r.fen_key));
  }

  const storable = [];
  for (const c of candidates) {
    if (reached.has(c.fenKey)) storable.push(c);
    else rejected.push({ index: c.index, reason: 'position-not-yours' });
  }

  // Two judgements of one move in one batch: the deeper wins, and the other is
  // counted as kept out — never silently dropped, never two rows in one insert
  // (which PostgreSQL refuses for ON CONFLICT DO UPDATE).
  const byMove = new Map();
  let keptOut = 0;
  for (const c of storable) {
    const k = `${c.fenKey}|${c.item.moveUci}`;
    const there = byMove.get(k);
    if (!there) byMove.set(k, c);
    else if (c.item.depth > there.item.depth) { byMove.set(k, c); keptOut += 1; } else keptOut += 1;
  }

  let stored = 0;
  let replaced = 0;
  const unique = [...byMove.values()];
  if (unique.length > 0) {
    const params = [];
    const tuples = unique.map(({ item, fenKey }) => {
      const values = [
        userId, fenKey, item.moveUci, item.wBest, item.wMove, item.bestUci,
        JSON.stringify(item.bestLine), JSON.stringify(item.moveLine),
        item.verdict, item.verdict === 'mistake' ? item.reason : null,
        item.bookGames ?? null, item.engine.trim(), item.depth,
      ];
      const start = params.length;
      params.push(...values);
      return `(${values.map((_, i) => `$${start + i + 1}`).join(', ')})`;
    });
    // A shallower judgement never replaces a deeper one: the WHERE of the
    // update, so the rule lives in the one statement that could break it.
    const result = await pool.query(
      `INSERT INTO opening_judgements
         (user_id, fen_key, move_uci, w_best, w_move, best_uci, best_line,
          move_line, verdict, reason, book_games, engine, depth)
       VALUES ${tuples.join(', ')}
       ON CONFLICT (user_id, fen_key, move_uci) DO UPDATE SET
         w_best = EXCLUDED.w_best, w_move = EXCLUDED.w_move,
         best_uci = EXCLUDED.best_uci, best_line = EXCLUDED.best_line,
         move_line = EXCLUDED.move_line, verdict = EXCLUDED.verdict,
         reason = EXCLUDED.reason, book_games = EXCLUDED.book_games,
         engine = EXCLUDED.engine, depth = EXCLUDED.depth, judged_at = NOW()
       WHERE opening_judgements.depth <= EXCLUDED.depth
       RETURNING (xmax = 0) AS inserted`,
      params,
    );
    for (const row of result.rows) {
      if (row.inserted) stored += 1;
      else replaced += 1;
    }
    keptOut += unique.length - result.rows.length;
  }

  const tally = {
    read: items.length,
    stored,
    replaced,
    kept_deeper: keptOut,
    rejected: rejected.length,
    rejected_by_reason: rejected.reduce((acc, r) => {
      acc[r.reason] = (acc[r.reason] || 0) + 1;
      return acc;
    }, {}),
  };
  const accounted = tally.stored + tally.replaced + tally.kept_deeper + tally.rejected;
  if (accounted !== tally.read) {
    throw new Error(`judgements lost: handed ${tally.read}, accounted ${accounted}`);
  }
  return tally;
}

/// The caller's judgements of the moves of [nodes], by position and move.
async function judgementsOf(pool, userId, fenKeys) {
  const byKey = new Map();
  if (fenKeys.length === 0) return byKey;
  const { rows } = await pool.query(
    `SELECT fen_key, move_uci, w_best, w_move, best_uci, best_line, move_line,
            verdict, reason, book_games, engine, depth
       FROM opening_judgements
      WHERE user_id = $1 AND fen_key = ANY($2::text[])`,
    [userId, fenKeys],
  );
  for (const r of rows) {
    if (!byKey.has(r.fen_key)) byKey.set(r.fen_key, new Map());
    byKey.get(r.fen_key).set(r.move_uci, {
      verdict: r.verdict,
      reason: r.reason,
      lostChances: Math.max(0, Number(r.w_best) - Number(r.w_move)),
      bestUci: r.best_uci,
      bestSan: Array.isArray(r.best_line) ? r.best_line[0] : null,
      bestLine: r.best_line,
      moveLine: r.move_line,
      bookGames: r.book_games,
      depth: r.depth,
      engine: r.engine,
    });
  }
  return byKey;
}

/// The UCI of [san] on the board of [fenKey], or null.
function uciOf(fenKey, san) {
  const board = new Chess(fenFromKey(fenKey));
  try {
    const m = board.move(san);
    return `${m.from}${m.to}${m.promotion || ''}`;
  } catch (_) {
    return null;
  }
}

/// Puts each move's judgement on [nodes] (in place) — `judgement: null` for a
/// move never judged, so a client can never read silence as „holds".
async function attachJudgements(pool, userId, nodes) {
  const byKey = await judgementsOf(pool, userId, nodes.map((n) => n.fenKey));
  for (const node of nodes) {
    const here = byKey.get(node.fenKey);
    for (const move of node.moves) {
      move.uci = move.uci || uciOf(node.fenKey, move.san);
      move.judgement = (here && move.uci && here.get(move.uci)) || null;
    }
  }
  return nodes;
}

/// The habits the engine called mistakes among [nodes] — every frequent node,
/// whatever its score — for the list the score alone does not show.
function losingHabits(nodes) {
  const out = [];
  for (const node of nodes) {
    for (const move of node.moves) {
      if (move.habit && move.judgement && move.judgement.verdict === 'mistake') {
        out.push({
          fenKey: node.fenKey,
          fen: node.fen,
          ply: node.ply,
          nodeGames: node.games,
          nodeScore: node.score,
          ...move,
          cost: move.judgement.lostChances * move.games,
        });
      }
    }
  }
  return out.sort((a, b) => b.cost - a.cost);
}

/// Puts on each move of [nodes] how many master games played it (`bookGames`)
/// and its UCI, asking [book] once per node. A book that cannot answer is said
/// — `{ available: false, reason }`, every count null — never a count of 0,
/// which would read as „no master played this" and make theory a mistake.
function attachBookCounts(nodes, book) {
  for (const node of nodes) {
    for (const move of node.moves) move.uci = move.uci || uciOf(node.fenKey, move.san);
  }
  try {
    for (const node of nodes) {
      const answer = book.answer(node.fen);
      const played = new Map(answer.moves.map((m) => [m.uci, m.white + m.draws + m.black]));
      for (const move of node.moves) move.bookGames = played.get(move.uci) ?? 0;
    }
    return { available: true };
  } catch (err) {
    for (const node of nodes) {
      for (const move of node.moves) move.bookGames = null;
    }
    if (err instanceof OpeningBookUnavailable) return { available: false, reason: err.reason };
    throw err;
  }
}

/// Deletes the judgements of positions no game of [userId] reaches any more —
/// called inside the transaction that deleted the games.
async function reapOrphans(client, userId) {
  const { rowCount } = await client.query(
    `DELETE FROM opening_judgements j
      WHERE j.user_id = $1
        AND NOT EXISTS (
          SELECT 1 FROM opening_nodes n WHERE n.user_id = $1 AND n.fen_key = j.fen_key
        )`,
    [userId],
  );
  return rowCount;
}

module.exports = {
  recordJudgements,
  attachJudgements,
  attachBookCounts,
  losingHabits,
  reapOrphans,
  whyNotStorable,
  uciOf,
  MAX_ITEMS_PER_CALL,
  MAX_LINE_PLIES,
};
