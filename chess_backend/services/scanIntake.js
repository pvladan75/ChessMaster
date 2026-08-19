// scanIntake.js — deciding what a confirmed scan is allowed to become.
//
// Split out of the route because this is the part that must not be wrong. What
// arrives is whatever a trainer edited on a board in the app, and the client is
// not the authority on whether that is a chess position: an unplayable FEN
// stored here becomes an unsolvable puzzle in front of a child.
//
// Nothing is silently repaired. A position that will not parse is rejected and
// named; a solution that will not play is dropped while the position is kept
// and flagged, because the board can still be worth studying when the move
// printed next to it was misread.
const crypto = require('crypto');
const { Chess } = require('chess.js');

const MAX_POSITIONS_PER_CONFIRM = 300;
const MAX_THEMES = 12;

function cleanThemes(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((theme) => typeof theme === 'string' && theme.trim())
    .map((theme) => theme.trim().slice(0, 40))
    .slice(0, MAX_THEMES);
}

/**
 * Validate one candidate position.
 * Returns a row ready to insert, or throws with a message naming the problem.
 */
function prepareRow(position) {
  const fen = typeof position?.fen === 'string' ? position.fen.trim() : '';
  if (!fen) throw new Error('Pozicija nema FEN.');

  // Throws on anything that is not a position; that is the point of the call.
  const board = new Chess(fen);

  const claimed = typeof position.solutionSan === 'string' ? position.solutionSan.trim().slice(0, 20) : '';
  let verifiedSan = null;
  if (claimed) {
    try {
      verifiedSan = new Chess(fen).move(claimed) ? claimed : null;
    } catch {
      verifiedSan = null;
    }
  }

  return {
    puzzleId: `cust_${crypto.randomBytes(8).toString('hex')}`,
    fen,
    side: board.turn(),
    solutionSan: verifiedSan,
    themes: cleanThemes(position.themes),
    page: Number.isFinite(Number(position.page)) ? Number(position.page) : null,
    label: position.label ? String(position.label).slice(0, 16) : null,
    // Two sources of doubt: the trainer's, and a solution that did not verify.
    needsReview: Boolean(position.needsReview) || (claimed !== '' && verifiedSan === null),
  };
}

/** Validate a batch, keeping the good rows and naming the bad ones. */
function prepareRows(positions) {
  const rows = [];
  const rejected = [];
  positions.forEach((position, index) => {
    try {
      rows.push(prepareRow(position));
    } catch (err) {
      rejected.push({ index, error: err.message });
    }
  });
  return { rows, rejected };
}

/**
 * What to do when a scan meets a diagram that is already saved.
 *
 * Re-scanning is normal — a trainer works through a book a chapter at a time and
 * the ranges overlap. Measured on a real overlap: 42 diagrams arrived twice with
 * byte-identical boards, but only one copy of each pair carried the solution.
 * So the two copies are not interchangeable, and "keep the first" would have
 * been wrong had the ranges been scanned the other way round.
 *
 * The rule is therefore to fill gaps and never to overwrite. What is already
 * there stays: a trainer who corrected the side to move by hand outranks a
 * scanner that has just read the same page again.
 *
 * A solution is only filled in if it actually plays in the *stored* position.
 * If it does not, the two disagree about something real — the side to move,
 * most likely — and that is reported rather than smoothed over.
 */
function mergePlan(existing, incoming) {
  const fields = {};

  if (!existing.solution_san && incoming.solutionSan) {
    let plays = false;
    try {
      plays = Boolean(new Chess(existing.fen).move(incoming.solutionSan));
    } catch {
      plays = false;
    }
    if (!plays) {
      return {
        action: 'conflict',
        fields: {},
        reason: `rešenje "${incoming.solutionSan}" ne igra u već sačuvanoj poziciji`,
      };
    }
    fields.solution_san = incoming.solutionSan;
    // The move verifying against the stored board settles what the row was
    // unsure about, so the flag goes with it.
    fields.needs_review = false;
  }

  if ((!existing.themes || existing.themes.length === 0) && incoming.themes.length > 0) {
    fields.themes = incoming.themes;
  }

  return Object.keys(fields).length > 0
    ? { action: 'fill', fields }
    : { action: 'unchanged', fields: {} };
}

/**
 * Rewrite a stored FEN to put the other side to move.
 *
 * A FEN has no way to say "nobody knows whose move it is", so a scanned diagram
 * whose book never said is stored with white and a `needs_review` flag beside
 * it. The flag is the only carrier of the doubt: the FEN itself looks exactly
 * like a position somebody verified, which is how an unconfirmed guess ends up
 * being stated as fact by the analysis board two screens later.
 *
 * Settling it is therefore a real edit, and it belongs here rather than in the
 * client: the en passant square records the *other* side's last move and makes
 * the position illegal once the mover changes, and the result is validated
 * before it can be written back.
 */
function withSideToMove(fen, side) {
  if (side !== 'w' && side !== 'b') {
    throw new Error(`Strana na potezu mora biti 'w' ili 'b', dobijeno ${JSON.stringify(side)}.`);
  }
  const parts = fen.trim().split(/\s+/);
  if (parts.length < 4) throw new Error('FEN nije potpun.');
  parts[1] = side;
  parts[3] = '-';
  const rewritten = parts.join(' ');
  new Chess(rewritten); // throws if the choice makes the position impossible
  return rewritten;
}

/**
 * Does this move still play in this position?
 *
 * A position with no solution is not in doubt — it is merely incomplete, and
 * answers true, because there is nothing here that disagrees with anything.
 * Being unfinished and being wrong are different states and must not share a
 * warning.
 */
function solutionPlaysIn(fen, san) {
  if (!san) return true;
  try {
    return Boolean(new Chess(fen).move(san));
  } catch {
    return false;
  }
}

module.exports = {
  prepareRow,
  prepareRows,
  mergePlan,
  withSideToMove,
  solutionPlaysIn,
  MAX_POSITIONS_PER_CONFIRM,
};
