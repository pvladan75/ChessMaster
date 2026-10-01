// puzzleList.js — which puzzles an account has met, one row each, newest first.
//
// docs/PLAN-NAPREDAK-VEZBI.md §7, phase 5. The Practise cards count the
// attempt log; this shows it, a puzzle at a time, with the board the player
// was asked about. It decides nothing about a puzzle itself: where a puzzle
// stands and whether its first meeting solved it are `stateOf` and
// `solvedFirstTry` over `puzzlesOf`, the cards' own fold, so the list cannot
// disagree with the numbers above it.
//
// **Each account's own, and only its own.** The owner's answer of 1.10.2026
// (§7.5, D3): not every user is a trainer or a student, the puzzles are an
// individual's own work, and roles play no part in them. The caller is the
// signed-in account; nothing in a request can name another.

const { Chess } = require('chess.js');
const {
  attemptsOf, puzzlesOf, stateOf, solvedFirstTry, isKnownSource,
} = require('./puzzleProgress');
const { splitSolution } = require('./puzzleSelectionService');
const { labelOf } = require('./endgameCatalog');

/// Where a puzzle can stand — `stateOf`'s three answers.
const STATES = Object.freeze(['solved', 'failed', 'skipped']);
const DEFAULT_LIMIT = 30;
const MAX_LIMIT = 100;

/// A request the list cannot answer as asked: a 400, never a guess.
class ListError extends Error {}

function timeOf(row) {
  return new Date(row.created_at).getTime();
}

function keyOf(source, puzzleId) {
  return `${source}\u0000${puzzleId}`;
}

function compareText(a, b) {
  if (a < b) return -1;
  return a > b ? 1 : 0;
}

/// Newest first, and a fixed order for two puzzles last tried at one moment,
/// so that a page boundary between them is a place rather than a guess.
function inListOrder(a, b) {
  return (b.at - a.at) || compareText(a.source, b.source) || compareText(a.puzzleId, b.puzzleId);
}

// ── the cursor ─────────────────────────────────────────────────────────────
//
// Where a page ended, and the moment the first page read the log. Later pages
// read the log as it stood then: a puzzle tried again while the list is being
// read keeps its place, instead of jumping above the cursor where no page
// would ever show it, and the new try appears when the list is read again
// from the top. An offset would skip a row the same way.

function encodeCursor(asOf, item) {
  return Buffer.from(JSON.stringify([asOf, item.at, item.source, item.puzzleId])).toString('base64url');
}

function decodeCursor(text) {
  let parsed;
  try {
    parsed = JSON.parse(Buffer.from(String(text), 'base64url').toString('utf8'));
  } catch {
    throw new ListError('The page cursor is not valid.');
  }
  if (!Array.isArray(parsed) || parsed.length !== 4) {
    throw new ListError('The page cursor is not valid.');
  }
  const [asOf, at, source, puzzleId] = parsed;
  if (!Number.isFinite(asOf) || !Number.isFinite(at) || !isKnownSource(source)
      || typeof puzzleId !== 'string') {
    throw new ListError('The page cursor is not valid.');
  }
  return { asOf, at, source, puzzleId };
}

function isBlank(value) {
  return value === undefined || value === null || value === '';
}

function optionsOf({ source, state, before, limit } = {}) {
  if (!isBlank(source) && !isKnownSource(source)) {
    throw new ListError(`Unknown puzzle source: ${source}`);
  }
  if (!isBlank(state) && !STATES.includes(state)) {
    throw new ListError(`Unknown puzzle state: ${state}`);
  }
  let size = DEFAULT_LIMIT;
  if (!isBlank(limit)) {
    size = Number(limit);
    if (!Number.isInteger(size) || size < 1) {
      throw new ListError('The page size must be a whole number of at least 1.');
    }
  }
  return {
    source: isBlank(source) ? null : source,
    state: isBlank(state) ? null : state,
    before: isBlank(before) ? null : decodeCursor(before),
    limit: Math.min(size, MAX_LIMIT),
  };
}

// ── the boards ─────────────────────────────────────────────────────────────

/// The board a Lichess puzzle asks about. The stored FEN is the position
/// before the opponent's move, and the drill plays that move first
/// (`toClientPuzzle`'s `setup_move`): drawn from the stored FEN, every
/// tactics row would show a position the player never saw. Null when the move
/// cannot be played — a wrong board is worse than none.
function afterSetupMove(row) {
  const { setupMove } = splitSolution(row.moves);
  if (!setupMove) return null;
  try {
    const board = new Chess(row.fen);
    board.move({
      from: setupMove.slice(0, 2),
      to: setupMove.slice(2, 4),
      promotion: setupMove.slice(4) || undefined,
    });
    return board.fen();
  } catch {
    return null;
  }
}

/// A basic mate's board is in its own id — `basic:<preset>:<the first four
/// FEN fields>` (`PuzzleSource.basicMateId` in the app) — so it needs no
/// table. Null for an id that does not hold a position.
function basicMateBoard(puzzleId) {
  const match = /^basic:([^:]+):(.+)$/.exec(puzzleId);
  if (!match) return null;
  const fen = `${match[2]} 0 1`;
  try {
    // eslint-disable-next-line no-new
    new Chess(fen);
  } catch {
    return null;
  }
  return { fen, detail: { preset: match[1] } };
}

/// `<game_id>:<ply>`. The game id is the table's text column and may itself
/// hold a colon, so the ply is what follows the last one.
function blunderStop(puzzleId) {
  const cut = puzzleId.lastIndexOf(':');
  if (cut <= 0) return null;
  const ply = Number(puzzleId.slice(cut + 1));
  return Number.isInteger(ply) ? { gameId: puzzleId.slice(0, cut), ply } : null;
}

/// The boards of one page: **each table asked once, never once per row** —
/// at most five queries however long the page, none for a table the page
/// does not need. A puzzle with no board here is `available: false`.
async function boardsOf(pool, userId, page) {
  const boards = new Map();
  const put = (source, puzzleId, fen, detail) => boards.set(keyOf(source, puzzleId), { fen, detail });
  const idsOf = (source) => [...new Set(page.filter((i) => i.source === source).map((i) => i.puzzleId))];

  const lichess = idsOf('lichess');
  const mates = idsOf('mate_puzzle');
  const winning = idsOf('winning_position');
  const endgames = idsOf('endgame');
  const stops = idsOf('blunder_game').map((id) => ({ id, stop: blunderStop(id) })).filter((s) => s.stop);
  const own = idsOf('own');
  const asked = [];

  if (lichess.length > 0) {
    asked.push(pool.query(
      `SELECT puzzle_id, fen, moves, rating, themes
         FROM lichess_puzzles WHERE puzzle_id = ANY($1::varchar[])`,
      [lichess]
    ).then(({ rows }) => {
      for (const row of rows) {
        const fen = afterSetupMove(row);
        if (fen) put('lichess', row.puzzle_id, fen, { rating: row.rating, themes: row.themes || [] });
      }
    }));
  }

  if (mates.length + winning.length > 0) {
    // Mates and winning positions share one table, and so one question.
    asked.push(pool.query(
      `SELECT puzzle_id, fen, type, mate_depth
         FROM puzzles WHERE puzzle_id = ANY($1::varchar[])`,
      [[...mates, ...winning]]
    ).then(({ rows }) => {
      for (const row of rows) {
        if (mates.includes(row.puzzle_id)) put('mate_puzzle', row.puzzle_id, row.fen, { mateDepth: row.mate_depth });
        if (winning.includes(row.puzzle_id)) put('winning_position', row.puzzle_id, row.fen, {});
      }
    }));
  }

  if (endgames.length > 0) {
    asked.push(pool.query(
      `SELECT puzzle_id, fen, mode, endgame_type, material
         FROM endgame_puzzles WHERE puzzle_id = ANY($1::varchar[])`,
      [endgames]
    ).then(({ rows }) => {
      for (const row of rows) {
        put('endgame', row.puzzle_id, row.fen, {
          mode: row.mode,
          type: row.endgame_type,
          material: row.material,
          // The picker's own words for the ending, as the trainer's chip
          // shows them (buildEndgamePayload).
          materialLabel: row.material == null ? null : labelOf(row.material),
        });
      }
    }));
  }

  if (stops.length > 0) {
    asked.push(pool.query(
      `SELECT game_id, white, black, blunders
         FROM blunder_games WHERE game_id = ANY($1::varchar[])`,
      [[...new Set(stops.map((s) => s.stop.gameId))]]
    ).then(({ rows }) => {
      const games = new Map(rows.map((game) => [game.game_id, game]));
      for (const { id, stop } of stops) {
        const game = games.get(stop.gameId);
        const blunder = game && (game.blunders || []).find((b) => Number(b.ply) === stop.ply);
        if (blunder && blunder.fen) {
          put('blunder_game', id, blunder.fen, {
            ply: stop.ply, side: blunder.side, white: game.white, black: game.black,
          });
        }
      }
    }));
  }

  if (own.length > 0) {
    // The caller's own exercises only: an id in the log is not a key to
    // another account's board.
    asked.push(pool.query(
      `SELECT puzzle_id, fen, instruction, source_title
         FROM custom_puzzles WHERE puzzle_id = ANY($1::varchar[]) AND owner_id = $2`,
      [own, userId]
    ).then(({ rows }) => {
      for (const row of rows) {
        put('own', row.puzzle_id, row.fen, { instruction: row.instruction, sourceTitle: row.source_title });
      }
    }));
  }

  await Promise.all(asked);

  for (const id of idsOf('basic_mate')) {
    const board = basicMateBoard(id);
    if (board) put('basic_mate', id, board.fen, board.detail);
  }
  return boards;
}

// ── the list ───────────────────────────────────────────────────────────────

function describe(item, boards) {
  const { entry } = item;
  // A try is an answer; a skip is not one (stateOf's own distinction).
  const answers = entry.rows.filter((row) => !row.skipped);
  const solvedAt = answers.findIndex((row) => row.solved);
  const board = boards.get(keyOf(item.source, item.puzzleId)) || null;
  return {
    source: item.source,
    puzzleId: item.puzzleId,
    state: item.state,
    firstTry: solvedFirstTry(entry),
    tries: answers.length,
    solvedOnTry: solvedAt === -1 ? null : solvedAt + 1,
    firstAt: new Date(entry.first.at).toISOString(),
    latestAt: new Date(entry.latest.at).toISOString(),
    available: board !== null,
    fen: board ? board.fen : null,
    detail: board ? board.detail : {},
  };
}

/// One page of the account's puzzles, newest first:
/// `{ puzzles: [...], next: cursor | null }`. `source` and `state` narrow the
/// list; `before` is the `next` of the page before; `limit` is the page size.
async function puzzleListOf(pool, userId, options = {}) {
  const wanted = optionsOf(options);
  const log = await attemptsOf(pool, userId);

  const asOf = wanted.before
    ? wanted.before.asOf
    : log.reduce((latest, row) => Math.max(latest, timeOf(row)), -Infinity);
  if (!Number.isFinite(asOf)) return { puzzles: [], next: null };

  let items = puzzlesOf(log.filter((row) => timeOf(row) <= asOf)).map((entry) => ({
    entry,
    source: entry.latest.source,
    puzzleId: entry.latest.puzzleId,
    at: entry.latest.at,
    state: stateOf(entry),
  }));
  if (wanted.source) items = items.filter((item) => item.source === wanted.source);
  if (wanted.state) items = items.filter((item) => item.state === wanted.state);
  items.sort(inListOrder);
  if (wanted.before) items = items.filter((item) => inListOrder(item, wanted.before) > 0);

  const page = items.slice(0, wanted.limit);
  const boards = await boardsOf(pool, userId, page);
  return {
    puzzles: page.map((item) => describe(item, boards)),
    next: items.length > page.length ? encodeCursor(asOf, page[page.length - 1]) : null,
  };
}

module.exports = {
  puzzleListOf,
  ListError,
  STATES,
  DEFAULT_LIMIT,
  MAX_LIMIT,
};
