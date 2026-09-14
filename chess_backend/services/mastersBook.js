// mastersBook.js — the masters statistics of a game, from a local database.
//
// Phase 2 of docs/PLAN-SKELET.md, decision D5 (owner, 14.9.2026): a game turned
// into a tutorial is walked through a SQLite file built from the Lumbras
// GigaBase OTB games in which both players are rated 2200+, rather than through
// the Lichess masters explorer. The measurement that decided it is in the plan:
// the same most-played move in 99% of positions, and no token, no rate limit
// and no 429 — which Lichess answered the measurement itself with, twice.
//
// **The file is keyed by the Polyglot Zobrist hash** python-chess computed when
// it was built, so the one thing this module must get right is the same 64
// bits for a FEN. A wrong key finds nothing, and nothing reads exactly like a
// game that left the book on its first move. `test/polyglot_keys.test.js` holds
// `polyglotKey` to python-chess on every position of the ten harness games and
// on the cases they do not reach.
//
// **What it answers is the explorer's shape** — counts for the position and for
// each move — because that is what the app's `applyMastersBook` reads, and it
// was ported from the harness against exactly that shape. Opening names are
// not here: the app names a position from the ECO data it already ships, which
// gave back all 52 of Lichess's names on the harness games word for word.

const { Chess } = require('chess.js');
const RANDOM = require('./polyglotRandom');

/// A walk longer than this is not a game's opening: the database holds the
/// first 30 plies, so a request for more positions can only be asking about
/// something else.
const MAX_POSITIONS = 64;

class MastersBookUnavailable extends Error {
  constructor(message, { reason, status = 503 } = {}) {
    super(message);
    this.name = 'MastersBookUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

const PIECE_INDEX = { p: 0, n: 1, b: 2, r: 3, q: 4, k: 5 };

function squareIndex(name) {
  return (name.charCodeAt(0) - 97) + 8 * (Number(name[1]) - 1);
}

/// python-chess's `chess.polyglot.zobrist_hash`, as a signed 64-bit BigInt —
/// the way SQLite stores it.
function polyglotKey(fen) {
  const [placement, turn, castling, ep] = fen.trim().split(/\s+/);
  const board = new Map(); // square index -> piece letter, upper case for White
  let rank = 7;
  let file = 0;
  for (const ch of placement) {
    if (ch === '/') {
      rank -= 1;
      file = 0;
    } else if (/\d/.test(ch)) {
      file += Number(ch);
    } else {
      board.set(file + 8 * rank, ch);
      file += 1;
    }
  }

  let key = 0n;
  for (const [square, piece] of board) {
    const white = piece === piece.toUpperCase();
    const kind = PIECE_INDEX[piece.toLowerCase()] * 2 + (white ? 1 : 0);
    key ^= RANDOM[64 * kind + square];
  }

  // python-chess hashes the *clean* castling rights: a right the FEN claims is
  // dropped unless the king and that rook stand on their home squares.
  const on = (square, piece) => board.get(squareIndex(square)) === piece;
  const rights = castling === '-' ? '' : castling;
  if (rights.includes('K') && on('e1', 'K') && on('h1', 'R')) key ^= RANDOM[768];
  if (rights.includes('Q') && on('e1', 'K') && on('a1', 'R')) key ^= RANDOM[769];
  if (rights.includes('k') && on('e8', 'k') && on('h8', 'r')) key ^= RANDOM[770];
  if (rights.includes('q') && on('e8', 'k') && on('a8', 'r')) key ^= RANDOM[771];

  // The en passant file counts only when a pawn of the side to move stands
  // beside the pawn that has just moved two squares. Whether the capture would
  // be legal is not asked — Polyglot's rule, and python-chess's.
  if (ep && ep !== '-') {
    const epFile = ep.charCodeAt(0) - 97;
    const pawnRank = turn === 'w' ? 4 : 3; // 0-based: rank 5 or rank 4
    const ours = turn === 'w' ? 'P' : 'p';
    const beside = [epFile - 1, epFile + 1].filter((f) => f >= 0 && f <= 7);
    if (beside.some((f) => board.get(f + 8 * pawnRank) === ours)) {
      key ^= RANDOM[772 + epFile];
    }
  }

  if (turn === 'w') key ^= RANDOM[780];
  return BigInt.asIntN(64, key);
}

const PROMOTION = [null, 'p', 'n', 'b', 'r', 'q', 'k'];
const squareName = (index) => 'abcdefgh'[index % 8] + String(Math.floor(index / 8) + 1);

function createMastersBook({
  path = process.env.MASTERS_BOOK_PATH,
  // Injected so the tests can hand over a database they built.
  openDatabase = (file) => {
    // eslint-disable-next-line global-require
    const { DatabaseSync } = require('node:sqlite');
    return new DatabaseSync(file, { readOnly: true });
  },
} = {}) {
  let db = null;
  let statement = null;

  function lookup() {
    if (statement) return statement;
    if (!path) {
      throw new MastersBookUnavailable(
        'The opening database is not configured on this server.',
        { reason: 'not-configured' }
      );
    }
    try {
      db = openDatabase(path);
    } catch (err) {
      throw new MastersBookUnavailable(
        'The opening database could not be opened.',
        { reason: 'unreadable', status: 503 }
      );
    }
    // The key is bound as a BigInt: as a JavaScript number its 64 bits would
    // round, and a rounded key is a position nobody played. Nothing read back
    // is that wide - the move and the three counts are small.
    statement = db.prepare('SELECT move, w, b, d FROM position_stats WHERE zobrist = ?');
    return statement;
  }

  /// One position, in the explorer's shape, most-played move first.
  function answer(fen) {
    const rows = lookup().all(polyglotKey(fen));
    const board = new Chess(fen);
    const moves = [];
    for (const row of rows) {
      const code = Number(row.move);
      const from = squareName(code & 63);
      const to = squareName((code >> 6) & 63);
      const promotion = PROMOTION[(code >> 12) & 7] || undefined;
      let played;
      try {
        played = board.move({ from, to, promotion });
      } catch (_) {
        // A move this position cannot play belongs to another position that
        // shares its 64 bits. It is left out rather than named.
        continue;
      }
      board.undo();
      moves.push({
        uci: from + to + (promotion || ''),
        san: played.san,
        white: Number(row.w),
        draws: Number(row.d),
        black: Number(row.b),
      });
    }
    const total = (m) => m.white + m.draws + m.black;
    moves.sort((a, b) => total(b) - total(a) || (a.uci < b.uci ? -1 : a.uci > b.uci ? 1 : 0));
    return {
      white: moves.reduce((n, m) => n + m.white, 0),
      draws: moves.reduce((n, m) => n + m.draws, 0),
      black: moves.reduce((n, m) => n + m.black, 0),
      moves,
    };
  }

  /// A game's positions in order, answered until the first no game reached.
  function walk(fens) {
    if (!Array.isArray(fens) || fens.length === 0 || fens.some((f) => typeof f !== 'string')) {
      throw new RangeError('fens must be a non-empty list of FEN strings.');
    }
    if (fens.length > MAX_POSITIONS) {
      throw new RangeError(`At most ${MAX_POSITIONS} positions can be walked at once.`);
    }
    const positions = [];
    for (const fen of fens) {
      try {
        new Chess(fen); // eslint-disable-line no-new
      } catch (_) {
        throw new RangeError(`Not a position: ${fen}`);
      }
      const here = answer(fen);
      if (here.white + here.draws + here.black === 0) break;
      positions.push({ fen, ...here });
    }
    return { positions };
  }

  /// Closes the file. The server keeps it open for its lifetime; a test that
  /// built its own database must close it before Windows lets it be deleted.
  function close() {
    if (db) db.close();
    db = null;
    statement = null;
  }

  return { walk, answer, close };
}

module.exports = {
  createMastersBook,
  polyglotKey,
  MastersBookUnavailable,
  MAX_POSITIONS,
};
