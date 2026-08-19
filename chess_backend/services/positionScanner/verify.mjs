// Turning a read board into a position, and checking it against the book.
//
// A diagram prints pieces and nothing else. Side to move, castling rights and
// the en passant square are not on the page, and the prototype that produced
// the first measurements hard-coded them to `- -`. That is why 14 castling
// solutions and 2 en passant solutions came out "illegal": the pieces were read
// correctly and the metadata threw the answer away. A mate in one by castling
// imported that way is an unsolvable puzzle.
//
// So: derive what the book's own solution proves, repair only that, and flag
// anything still unexplained instead of shipping a position nobody checked.
import { Chess } from 'chess.js';

/** Rights a castling move needs, given the side. */
function castlingRightsFor(san, side) {
  if (/^O-O-O/.test(san)) return side === 'w' ? 'Q' : 'q';
  if (/^O-O/.test(san)) return side === 'w' ? 'K' : 'k';
  return null;
}

function makeFen(placement, side, castling, ep) {
  return `${placement} ${side} ${castling || '-'} ${ep || '-'} 0 1`;
}

function tryMove(fen, san) {
  try {
    const board = new Chess(fen);
    const move = board.move(san);
    return move ? { ok: true, move } : { ok: false, reason: 'odbijen potez' };
  } catch (err) {
    return { ok: false, reason: err.message };
  }
}

function isLegalPosition(fen) {
  try {
    new Chess(fen);
    return true;
  } catch (err) {
    return { error: err.message };
  }
}

/**
 * Build a verified position from a diagram and, when the book has one, its
 * solution.
 *
 * Returns { fen, side, sideSource, solutionLegal, repairs, problem }.
 * `problem` set means a human has to look at this one — that is the intended
 * outcome for anything uncertain, not a reason to drop the position silently.
 */
export function buildPosition(diagram, solution) {
  const repairs = [];
  const placement = diagram.placement;

  let side = solution?.side ?? null;
  let sideSource = solution ? 'resenje' : null;

  // With no solution to lean on, keep the position but say so. The trainer's
  // confirmation screen is where this gets settled; an engine can narrow it
  // further, and neither belongs in the parser.
  if (!side) {
    const whiteOk = isLegalPosition(makeFen(placement, 'w', '-', '-')) === true;
    const blackOk = isLegalPosition(makeFen(placement, 'b', '-', '-')) === true;
    if (whiteOk && !blackOk) {
      side = 'w';
      sideSource = 'jedina legalna strana';
    } else if (blackOk && !whiteOk) {
      side = 'b';
      sideSource = 'jedina legalna strana';
    } else {
      side = 'w';
      sideSource = 'nepoznato';
    }
  }

  let castling = '-';
  let ep = '-';
  let fen = makeFen(placement, side, castling, ep);

  const legality = isLegalPosition(fen);
  if (legality !== true) {
    return { fen, side, sideSource, solutionLegal: null, repairs, problem: `nelegalna pozicija: ${legality.error}` };
  }

  if (!solution) {
    return { fen, side, sideSource, solutionLegal: null, repairs, problem: null };
  }

  // The notation may be ambiguous once the typesetter's spaces are gone, so the
  // solution arrives as candidates, shortest first. The board decides.
  let attempt = { ok: false, reason: 'nema kandidata' };
  let san = solution.san;

  for (const candidate of solution.sans ?? [solution.san]) {
    san = candidate;

    // 1. Straight attempt.
    attempt = tryMove(fen, candidate);
    if (attempt.ok) break;

    // 2. Castling: the diagram cannot show rights, so grant exactly the right
    //    the solution proves must have existed.
    const right = castlingRightsFor(candidate, side);
    if (right) {
      const withRight = makeFen(placement, side, right, ep);
      const retry = tryMove(withRight, candidate);
      if (retry.ok) {
        castling = right;
        fen = withRight;
        attempt = retry;
        repairs.push(`rokada: postavljeno pravo ${right}`);
        break;
      }
    }

    // 3. En passant: a pawn capture onto an empty square can only be en
    //    passant, and the target square is the missing field.
    const pawnCapture = /^[a-h]x([a-h][36])/.exec(candidate);
    if (pawnCapture) {
      const target = pawnCapture[1];
      if (!new Chess(fen).get(target)) {
        const withEp = makeFen(placement, side, castling, target);
        const retry = tryMove(withEp, candidate);
        if (retry.ok) {
          ep = target;
          fen = withEp;
          attempt = retry;
          repairs.push(`en passant: postavljeno polje ${target}`);
          break;
        }
      }
    }
  }

  return {
    fen,
    side,
    sideSource,
    solutionLegal: attempt.ok,
    solutionSan: attempt.ok ? san : solution.san,
    solutionMove: attempt.ok ? attempt.move.lan : null,
    repairs,
    problem: attempt.ok ? null : `potez iz knjige "${solution.san}" nije legalan (${attempt.reason})`,
  };
}
