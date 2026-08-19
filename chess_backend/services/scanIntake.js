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

module.exports = { prepareRow, prepareRows, MAX_POSITIONS_PER_CONFIRM };
