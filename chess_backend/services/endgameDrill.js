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
  // Repetition and the fifty-move rule are both draws and are not the same
  // thing to say. isDraw() covers both, and calling either one "fifty moves
  // without a capture" is false in the commoner of the two: a dead drawn rook
  // ending repeats within a few moves, and the drill ended it by naming a
  // counter that had barely started.
  if (board.isThreefoldRepetition()) return 'repetition';
  if (board.isDrawByFiftyMoves()) return 'fifty_moves';
  if (board.isDraw()) return 'draw_rule';
  return null;
}

/// Whether a capture is available that simply wins a piece.
///
/// "For free" means nothing takes back on that square. An exchange is not a
/// gift, and in the endings this is asked about — a rook apiece, a queen
/// apiece — the exchange is the draw itself.
function capturesForFree(board) {
  for (const move of board.moves({ verbose: true })) {
    if (!move.captured || move.captured === 'k') continue;
    board.move(move);
    const answered = board
      .moves({ verbose: true })
      .some((reply) => reply.to === move.to && reply.captured);
    board.undo();
    if (!answered) return true;
  }
  return false;
}

/// Whether a move is a plain oversight: it loses a piece for nothing.
///
/// The trainer's wording, and the reason it is not simply "the piece is en
/// prise": a fork or a skewer takes the piece one move later and is the same
/// mistake with a move's delay. So this looks two of the opponent's moves
/// ahead — the capture now, and the capture that no defence prevents.
///
/// A forced move is never an oversight. If there is nothing else to play,
/// nothing was overlooked.
function losesPieceOutright(fen, uci) {
  let board;
  try {
    board = new Chess(fen);
  } catch {
    return false;
  }
  if (board.moves().length <= 1) return false;
  const move = applyMove(board, uci);
  if (!move) return false;

  // The piece goes at once: the opponent takes and nothing takes back.
  if (capturesForFree(board)) return true;

  // Or it goes whatever we try. One move of theirs, every answer of ours, and
  // a free capture at the end of each — which is what a fork or a skewer is.
  for (const theirs of board.moves({ verbose: true })) {
    board.move(theirs);
    const answers = board.moves({ verbose: true });
    const lost = answers.length > 0 &&
      answers.every((ours) => {
        board.move(ours);
        const gone = capturesForFree(board);
        board.undo();
        return gone;
      });
    board.undo();
    if (lost) return true;
  }
  return false;
}

/// The narrow half of the same question, kept because it is what a reader
/// means by "hanging": the piece just moved can be taken and nothing defends
/// it.
function hangsAfter(fen, uci) {
  let board;
  try {
    board = new Chess(fen);
  } catch {
    return false;
  }
  const move = applyMove(board, uci);
  if (!move) return false;
  const mine = move.color;
  const theirs = mine === 'w' ? 'b' : 'w';
  if (board.attackers(move.to, theirs).length === 0) return false;
  return board.attackers(move.to, mine).length === 0;
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
/// The material a draw cannot be lost from except by giving a piece away.
///
/// The trainer's list, written out rather than derived, because these are the
/// endings a player recognises by name and the list is closed - not a category
/// that grows with the next mining run. Both sides are written as sorted
/// letters, weaker side first, so KRvKR is one entry and not two.
///
/// Same-coloured bishops against a bare king are here for a different reason
/// from the rest: they cannot mate at all, so nothing can happen. Two bishops
/// on different colours are missing from the list for exactly that reason.
const DEAD_DRAWN_MATERIAL = new Set([
  // Piece against the same piece.
  'R|R', 'Q|Q',
  // A minor against a rook, which the rook cannot convert.
  'B|R', 'N|R',
  // A minor against a minor, whichever two.
  'B|B', 'B|N', 'N|N',
  // Against a bare king, where the material cannot mate at all.
  '|N', '|B', '|NN', '|BB',
]);

/// The letters each side has, kings dropped, sorted, weaker side first.
function materialShape(fen) {
  const board = String(fen).split(' ')[0];
  const white = [];
  const black = [];
  const bishops = { w: [], b: [] };
  let file = 0;
  let rank = 7;
  for (const ch of board) {
    if (ch === '/') { rank -= 1; file = 0; continue; }
    if (/[1-8]/.test(ch)) { file += Number(ch); continue; }
    const isWhite = ch === ch.toUpperCase();
    const letter = ch.toUpperCase();
    if (letter !== 'K') (isWhite ? white : black).push(letter);
    if (letter === 'B') bishops[isWhite ? 'w' : 'b'].push((file + rank) % 2);
    file += 1;
  }
  const one = white.sort().join('');
  const two = black.sort().join('');
  const shape = one <= two ? `${one}|${two}` : `${two}|${one}`;
  return { shape, bishops };
}

/// Whether the material on the board is one of the dead drawn shapes.
function deadDrawnMaterial(fen) {
  const { shape, bishops } = materialShape(fen);
  if (!DEAD_DRAWN_MATERIAL.has(shape)) return false;
  if (shape === '|BB') {
    // Only if they stand on one colour. Two bishops on opposite colours mate,
    // and the tables would call it a win anyway - but this must not be the
    // thing that says otherwise.
    const pair = bishops.w.length === 2 ? bishops.w : bishops.b;
    return pair.length === 2 && pair[0] === pair[1];
  }
  return true;
}

/**
 * Everything the tables say about one position, for a reader who is stuck.
 *
 * The whole finding rather than a hint: what the position is worth, and every
 * legal move with what it leaves behind. Asked for by hand and never
 * volunteered - a drill that answers itself is a demonstration.
 *
 * Two things about the numbers, which the sort makes visible without a
 * paragraph of explanation:
 *
 *   - DTZ is the distance to the next capture or pawn move, not to mate. It is
 *     what the fifty-move rule is counted against, which is why the tables
 *     store it, and why a small one does not mean mate is near.
 *   - A move that holds is not a move that progresses. Shuffling the king keeps
 *     a win and arrives nowhere, so among the moves that hold, the ones that
 *     zero the counter come first.
 */
async function readout({ fen, goal = 'win', tablebase }) {
  try {
    // eslint-disable-next-line no-new
    new Chess(fen);
  } catch {
    throw new DrillError('Pozicija nije ispravna.');
  }
  if (pieceCount(fen) > 7) {
    throw new DrillError('Pozicija ima vise od sedam figura, pa je tablice ne pokrivaju.');
  }
  if (!(goal in RANK)) throw new DrillError(`Nepoznat cilj: ${goal}.`);

  const probed = await tablebase.probe(fen);
  const outcome = drillOutcome(probed.category);

  const moves = probed.moves.map((m) => {
    // Categories on a move are read from the far side of it, as everywhere
    // else here, so they are turned round to the mover's own view.
    const after = flip(drillOutcome(m.category));
    return {
      san: m.san,
      uci: m.uci,
      outcome: after,
      holds: RANK[after] >= RANK[goal],
      dtz: m.dtz === null || m.dtz === undefined ? null : m.dtz,
      zeroing: Boolean(m.zeroing),
    };
  });

  moves.sort((a, b) => {
    if (a.holds !== b.holds) return a.holds ? -1 : 1;
    if (a.zeroing !== b.zeroing) return a.zeroing ? -1 : 1;
    const da = a.dtz === null ? Infinity : Math.abs(a.dtz);
    const db = b.dtz === null ? Infinity : Math.abs(b.dtz);
    if (da !== db) return da - db;
    return String(a.san).localeCompare(String(b.san));
  });

  const pawnless = !/[pP]/.test(String(fen).split(' ')[0]);
  const dropped = moves.filter((m) => !m.holds);
  // The trainer's rule, written down as he put it: every move draws except the
  // ones that give a piece away, and there are no pawns left. Then there is
  // nothing to hold and nothing to promote, and the draw can be closed instead
  // of shuffled out to a repetition.
  //
  // Both tests, not either. The shape has to be one of the ones a player names
  // on sight - rook against rook, queen against queen, a minor against a rook,
  // anything at all against a bare king that cannot mate - *and* every move
  // that loses has to be a plain oversight, a piece given away now or forked
  // and skewered off the board next move.
  //
  // Requiring both is the cautious way round, and deliberately so: closing a
  // draw that was not finished takes away the exercise, while leaving one open
  // only costs a few more moves. The verdict from the tables guards both - a
  // shape on the list that the tables call won is won, and the list has no say.
  const deadDraw =
    outcome === 'draw' &&
    goal === 'draw' &&
    pawnless &&
    deadDrawnMaterial(fen) &&
    dropped.every((m) => losesPieceOutright(fen, m.uci));

  return {
    goal,
    outcome,
    dtz: probed.dtz,
    holding: moves.filter((m) => m.holds).length,
    total: moves.length,
    pawnless,
    deadDraw,
    moves,
  };
}

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
  readout,
  hangsAfter,
  losesPieceOutright,
  deadDrawnMaterial,
  drillOutcome,
  applyMove,
  endOf,
  pieceCount,
  flip,
  DrillError,
};
