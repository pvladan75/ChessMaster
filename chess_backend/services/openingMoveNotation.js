// openingMoveNotation.js — one move, written the way this application writes
// moves rather than the way Lichess writes them.
//
// **Lichess writes castling as "king takes rook".** Its UCI is `e1h1` for
// short and `e1a1` for long, the Chess960 convention; the board in this app,
// like most, writes `e1g1` and `e1c1`. Verified against the live cloud
// evaluation on 25.8.2026, which answered with the line
// `d2d3 d7d6 e1h1 a7a5 f1e1 e8h8 …` for an Italian position.
//
// That difference is a quiet one, which is why it is worth a file. It does not
// throw and it does not log: a castling move fetched from the opening book
// simply cannot be played on our board, so it is dropped by whatever tries —
// the drill's opponent never castles, the build screen's next wave silently
// loses a branch, and the move the reader just played is reported as "not in
// the book" while sitting in the list under the name O-O. That last one is how
// it was finally noticed, by somebody looking at the screen.
//
// The conversion goes through the move's SAN rather than through a rule about
// squares, because the library already knows how to read SAN and a hand-written
// castling rule is one more thing to get wrong.

const { Chess } = require('chess.js');

/// Our own UCI for `san` played from `fen`, or `fallback` when it cannot be
/// read there.
///
/// The fallback is deliberate: a move this server cannot parse is still a move
/// the caller asked about, and dropping it would hide a book entry rather than
/// report it.
function standardUci(fen, san, fallback) {
  if (typeof san !== 'string' || san.trim() === '') return fallback;
  try {
    const board = new Chess(fen);
    const played = board.move(san, { strict: false });
    if (!played) return fallback;
    return `${played.from}${played.to}${played.promotion ?? ''}`;
  } catch {
    return fallback;
  }
}

/// The same, over a whole list of book moves, reusing one board.
///
/// Each move is played and taken back, so the list costs one position rather
/// than one per move.
function withStandardUci(fen, moves) {
  if (!Array.isArray(moves) || moves.length === 0) return [];
  let board;
  try {
    board = new Chess(fen);
  } catch {
    return moves;
  }
  return moves.map((move) => {
    let played = null;
    try {
      played = board.move(move.san, { strict: false });
    } catch {
      played = null;
    }
    if (!played) return move;
    board.undo();
    return { ...move, uci: `${played.from}${played.to}${played.promotion ?? ''}` };
  });
}

module.exports = { standardUci, withStandardUci };
