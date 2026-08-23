// endgameDrill.js — playing an endgame out against a perfect opponent.
//
// The question after each move is not "was that good" but "did it keep the
// result", and that is a lookup rather than an opinion. An engine says -0.3 and
// leaves you to guess what it means; a tablebase says the win is gone. The
// whole mode rests on that difference, which is why nothing here degrades to a
// search when the tables cannot be reached — see tablebaseService.
//
// Two things this deliberately does not say.
//
// It does not tell a child how many moves are left. DTZ counts half-moves to
// the next capture or pawn move, not moves to mate, and after a conversion the
// counter starts again - so "eighteen moves to go" would be wrong twice over.
// What is honest, and what a child can act on, is the comparison: the result
// held, and you are nearer than you were, or you are not.
//
// And it does not treat a cursed win as a win. Those are wins only if the fifty
// move rule is ignored, which is the class the collection already excludes, so
// letting one through here would move the goalposts mid-drill.

const { Chess } = require('chess.js');
const { bestReply, wdlOf, TablebaseUnavailable } = require('./tablebaseService');

class DrillError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = 'DrillError';
    this.status = status;
  }
}

/// Lichess's five categories collapse to the three a drill can act on. A
/// cursed win is a draw here, and a blessed loss is a draw, because that is
/// what they are once the fifty move rule counts.
function drillOutcome(category) {
  const wdl = wdlOf(category);
  if (wdl === 2) return 'win';
  if (wdl === -2) return 'loss';
  return 'draw';
}

const RANK = { loss: 0, draw: 1, win: 2 };

/// The same result read from the other side of the board.
function flip(outcome) {
  if (outcome === 'win') return 'loss';
  if (outcome === 'loss') return 'win';
  return 'draw';
}

function pieceCount(fen) {
  return (String(fen).split(' ')[0].match(/[a-zA-Z]/g) || []).length;
}

function uciOf(move) {
  return `${move.from}${move.to}${move.promotion || ''}`;
}

/// Accepts either notation, because the app has both to hand and neither is
/// the obviously right one to force on it.
function applyMove(board, move) {
  const text = String(move || '').trim();
  if (!text) return null;
  try {
    return board.move(text);
  } catch {
    // Not SAN, so try it as UCI.
  }
  const match = /^([a-h][1-8])([a-h][1-8])([qrbn])?$/.exec(text.toLowerCase());
  if (!match) return null;
  try {
    return board.move({ from: match[1], to: match[2], promotion: match[3] || undefined });
  } catch {
    return null;
  }
}

/// How a finished game finished, or null while it is still going.
function endOf(board) {
  if (board.isCheckmate()) return 'mate';
  if (board.isStalemate()) return 'stalemate';
  if (board.isInsufficientMaterial()) return 'insufficient';
  if (board.isDraw()) return 'draw_rule';
  return null;
}

/**
 * Judge one move of a play-it-out drill and answer for the opponent.
 *
 * Two probes: the position the child moved from, which says both what they had
 * to hold and what their move left them with, and the position after it, which
 * is where the opponent's reply is chosen. Repeats cost nothing.
 */
async function judgeMove({ fen, move, tablebase }) {
  let board;
  try {
    board = new Chess(fen);
  } catch {
    throw new DrillError('Pozicija nije ispravna.');
  }

  // Seven is as far as any tablebase reaches. Asking about more would get an
  // answer the service does not stand behind, and this mode has no use for one.
  if (pieceCount(fen) > 7) {
    throw new DrillError('Pozicija ima više od sedam figura, pa se ne može presuditi iz tablica.');
  }

  const before = await tablebase.probe(fen);
  const goal = drillOutcome(before.category);
  if (goal === 'loss') {
    throw new DrillError('Ova pozicija je već izgubljena, pa nema šta da se drži.');
  }

  const played = applyMove(board, move);
  if (!played) {
    throw new DrillError('Taj potez nije moguć u ovoj poziciji.');
  }

  const entry = before.moves.find((m) => m.uci === uciOf(played));
  if (!entry) {
    // The tables listed every legal move and this one was not among them, so
    // one of the two is wrong about the position. Neither is worth guessing on.
    throw new TablebaseUnavailable(
      `Tablica ne poznaje potez ${played.san} u toj poziciji.`
    );
  }

  const after = flip(drillOutcome(entry.category));
  const held = RANK[after] >= RANK[goal];

  // A capture or a pawn move resets the counter, so the number jumping up
  // there is conversion rather than backsliding. Comparing the raw distances
  // across a zeroing move would report the one kind of progress that matters
  // most as a step backwards.
  const distanceBefore = before.dtz === null ? null : Math.abs(before.dtz);
  const distanceAfter = entry.dtz === null ? null : Math.abs(entry.dtz);
  let closer = null;
  if (held && goal === 'win') {
    if (entry.zeroing) closer = true;
    else if (distanceBefore !== null && distanceAfter !== null) {
      closer = distanceAfter < distanceBefore;
    }
  }

  const result = {
    playedSan: played.san,
    playedUci: uciOf(played),
    goal,
    outcome: after,
    held,
    closer,
    distanceBefore,
    distanceAfter,
    zeroing: entry.zeroing,
    reply: null,
    fen: board.fen(),
    finished: endOf(board),
  };

  // A lost result ends it here. Playing on would have the opponent defend a
  // position they have already won, which teaches the wrong lesson twice.
  if (!held || result.finished) return result;

  const afterMove = await tablebase.probe(board.fen());
  const reply = bestReply(afterMove.moves);
  if (reply) {
    const replied = board.move({
      from: reply.uci.slice(0, 2),
      to: reply.uci.slice(2, 4),
      promotion: reply.uci.slice(4) || undefined,
    });
    result.reply = { uci: reply.uci, san: replied.san };
    result.fen = board.fen();
    result.finished = endOf(board);
    // The reply's own distance is measured from the position the child now
    // faces, so it comes back for free rather than costing a third probe.
    result.distanceNext = reply.dtz === null ? null : Math.abs(reply.dtz);
  }

  return result;
}

/**
 * Best play for both sides from here, as far as it is worth showing.
 *
 * This is the answer to "why was my move bad": because of this. A move that
 * threw a draw away is refuted by a concrete line, and a line is a fact where
 * "-0.3" is an opinion.
 *
 * Both sides play the tables' best, which is not the same as both sides playing
 * well: the losing side takes the longest road and the winning side the
 * shortest, so it reads like a game rather than like a resignation. bestReply
 * carries that rule, and the same fix that made the drill terminate - a winning
 * zeroing move first - is what stops this from wandering too.
 */
async function bestLine({ fen, plies = 10, tablebase }) {
  let board;
  try {
    board = new Chess(fen);
  } catch {
    throw new DrillError('Pozicija nije ispravna.');
  }
  if (pieceCount(fen) > 7) {
    throw new DrillError('Pozicija ima više od sedam figura, pa se linija ne može izvesti.');
  }

  const start = await tablebase.probe(fen);
  const outcome = drillOutcome(start.category);
  const moves = [];

  for (let ply = 0; ply < plies; ply += 1) {
    if (endOf(board)) break;
    // Castling rights put a position outside the tables however few pieces
    // are on it, and the field in the FEN is the plain way to ask.
    const here = board.fen();
    if (pieceCount(here) > 7 || here.split(' ')[2] !== '-') break;
    const probed = await tablebase.probe(here);
    const next = bestReply(probed.moves);
    if (!next) break;
    const played = board.move({
      from: next.uci.slice(0, 2),
      to: next.uci.slice(2, 4),
      promotion: next.uci.slice(4) || undefined,
    });
    if (!played) break;
    moves.push(played.san);
  }

  return { outcome, moves, fen: board.fen(), finished: endOf(board) };
}

module.exports = {
  judgeMove,
  bestLine,
  drillOutcome,
  applyMove,
  endOf,
  pieceCount,
  flip,
  DrillError,
};
