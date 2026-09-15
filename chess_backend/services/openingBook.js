// openingBook.js — what was played in this position, from a local database.
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
//
// Two things the file can carry that the first version of this reader did not
// know about (`docs/PLAN-OTVARANJA-LOKALNO.md`):
//
// **`position_totals`.** A built file may have every row played by a single
// game deleted — 85% of them, and 87% of positions with it. The count a
// position was reached is written to a table of its own *before* that delete,
// because computing it from what survived under-reports by 2.2% on average and
// by up to 80% for one thin position, and that number is what a panel prints
// and what the narration says out loud. A file without the table answers from
// its rows exactly as before.
//
// **The last ply.** The extraction stops after a fixed number of half-moves, so
// a position past it is not a position nobody played: it is one this file
// cannot speak about. The two are told apart — `beyondBook` — because a book
// that ends silently is the oldest recurring bug in this repository. The ply is
// read from the FEN's own move counter, which is the only thing that knows
// where the counting started; a position set up by hand carries whatever
// counter it was given.

const { Chess } = require('chess.js');
const RANDOM = require('./polyglotRandom');

/// A walk longer than this is not a game's opening: the file holds the first
/// few dozen plies, so a request for more positions can only be asking about
/// something else.
const MAX_POSITIONS = 64;

class OpeningBookUnavailable extends Error {
  constructor(message, { reason, status = 503 } = {}) {
    super(message);
    this.name = 'OpeningBookUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

/// How many half-moves have been played before [fen], counted from the FEN's
/// own move number. A game that started anywhere but the standard position
/// carries its own counter, and nothing else in a FEN knows better.
function plyOf(fen) {
  const parts = fen.trim().split(/\s+/);
  const fullmove = Number(parts[5]);
  if (!Number.isFinite(fullmove) || fullmove < 1) return null;
  return (fullmove - 1) * 2 + (parts[1] === 'b' ? 1 : 0);
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

function createOpeningBook({
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
  // Null when the file was never pruned, which is every file built before
  // 15.9.2026 and every one a test writes by hand.
  let totals = null;
  let meta = {};

  function lookup() {
    if (statement) return statement;
    if (!path) {
      throw new OpeningBookUnavailable(
        'The opening database is not configured on this server.',
        { reason: 'not-configured' }
      );
    }
    try {
      db = openDatabase(path);
    } catch (err) {
      throw new OpeningBookUnavailable(
        'The opening database could not be opened.',
        { reason: 'unreadable', status: 503 }
      );
    }
    const hasTable = (name) => {
      try {
        return Boolean(db.prepare(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?"
        ).get(name));
      } catch (err) {
        return false;
      }
    };
    // A file says what it is, and a file built by hand says nothing — both are
    // read the same way, so a fixture needs no `meta` to be a book.
    meta = hasTable('meta')
      ? Object.fromEntries(db.prepare('SELECT key, value FROM meta').all()
        .map((row) => [row.key, row.value]))
      : {};
    if (hasTable('position_totals')) {
      totals = db.prepare('SELECT w, b, d FROM position_totals WHERE zobrist = ?');
    } else if (meta.pruned === '1') {
      // It says its one-game rows were deleted and it has nowhere to have kept
      // the real counts. Every number it gave would be too small, quietly.
      throw new OpeningBookUnavailable(
        'The opening database says it was pruned but carries no totals.',
        { reason: 'inconsistent', status: 503 }
      );
    }
    // The key is bound as a BigInt: as a JavaScript number its 64 bits would
    // round, and a rounded key is a position nobody played. Nothing read back
    // is that wide - the move and the three counts are small.
    statement = db.prepare('SELECT move, w, b, d FROM position_stats WHERE zobrist = ?');
    return statement;
  }

  /// The last ply this file can speak about, or null when it does not say.
  function maxPly() {
    const value = Number(meta.max_ply);
    return Number.isFinite(value) && value > 0 ? value : null;
  }

  /// One position, in the explorer's shape, most-played move first.
  ///
  /// A position this is not is the caller's mistake and says so: the key of a
  /// malformed FEN is a number like any other, and it would have been answered
  /// with „nobody has played this".
  function answer(fen) {
    let board;
    try {
      board = new Chess(fen);
    } catch (_) {
      throw new RangeError(`Not a position: ${fen}`);
    }
    const key = polyglotKey(fen);
    const rows = lookup().all(key);
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

    const listed = {
      white: moves.reduce((n, m) => n + m.white, 0),
      draws: moves.reduce((n, m) => n + m.draws, 0),
      black: moves.reduce((n, m) => n + m.black, 0),
    };
    // The counts a pruned file kept are the ones a position was really
    // reached; the rows are only what is left to show.
    const stored = totals && moves.length > 0 ? totals.get(key) : null;
    const here = stored
      ? { white: Number(stored.w), draws: Number(stored.d), black: Number(stored.b) }
      : listed;
    const ply = plyOf(fen);
    const last = maxPly();
    return {
      ...here,
      moves,
      // Games played here in moves this file no longer lists. Zero everywhere
      // but a pruned file, and the difference between "12 games" and "12 games,
      // of which these nine".
      unlisted: (here.white + here.draws + here.black)
        - (listed.white + listed.draws + listed.black),
      // Not "nobody played this" — "this file does not go that far".
      beyondBook: last !== null && ply !== null && ply >= last,
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
    // Why it ended, always: a game that walked out of the book and one that
    // walked off the end of the file are two different sentences a tutorial
    // can write, and 'end' is neither.
    let stoppedBecause = 'end';
    for (const fen of fens) {
      const here = answer(fen);
      if (here.beyondBook) {
        stoppedBecause = 'beyond-book';
        break;
      }
      if (here.white + here.draws + here.black === 0) {
        stoppedBecause = 'unplayed';
        break;
      }
      // Spelled out rather than spread. `walkMastersBook` in the app copies a
      // position whole into the facts a tutorial is built from and a model is
      // asked about, so a field added here would arrive in a prompt and in the
      // harness comparison without anybody choosing it.
      positions.push({
        fen, white: here.white, draws: here.draws, black: here.black, moves: here.moves,
      });
    }
    return { positions, stoppedBecause };
  }

  /// Closes the file. The server keeps it open for its lifetime; a test that
  /// built its own database must close it before Windows lets it be deleted.
  function close() {
    if (db) db.close();
    db = null;
    statement = null;
  }

  /// What this file is: the filter that built it, how deep it goes, and
  /// whether its one-game rows were deleted. Empty for a file that does not
  /// say. Read by the route so a server can tell a trainer what it is
  /// answering from.
  function describe() {
    lookup();
    return {
      minElo: meta.min_elo ? Number(meta.min_elo) : null,
      eloRule: meta.elo_rule ?? null,
      maxPly: maxPly(),
      pruned: meta.pruned === '1',
    };
  }

  return { walk, answer, describe, close };
}

let shared = null;

/// The server's one book. The explorer, the judge and the repertoire all read
/// the same file, and each opening its own handle onto several hundred
/// megabytes would be three caches of one fact. Created on the first call and
/// opened on the first question, so a server without the file still starts.
function sharedOpeningBook() {
  if (shared === null) shared = createOpeningBook();
  return shared;
}

module.exports = {
  sharedOpeningBook,
  createOpeningBook,
  polyglotKey,
  plyOf,
  OpeningBookUnavailable,
  MAX_POSITIONS,
};
