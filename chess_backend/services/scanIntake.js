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
const multer = require('multer');
const { Chess } = require('chess.js');

const MAX_POSITIONS_PER_CONFIRM = 300;
const MAX_THEMES = 12;
const MAX_DOCUMENT_BYTES = 25 * 1024 * 1024;

/**
 * What to answer when the *upload* failed, before any scanning happened.
 *
 * Multer aborts mid-stream, so the route handler never runs and its own error
 * handling never gets a turn: the error walks out to Express, which answers
 * with an HTML page and a bare 500. A trainer then reads "Skeniranje nije
 * uspelo (500)" for the most ordinary thing that can go wrong — a book bigger
 * than the ceiling — and has no way to guess that a smaller file would work.
 *
 * Returns null when there is nothing to refuse, so the caller can pass the
 * request on untouched.
 */
function uploadRejection(err) {
  if (!err) return null;
  if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
    return {
      status: 413,
      body: {
        error: `Knjiga je veća od ${Math.round(MAX_DOCUMENT_BYTES / (1024 * 1024))} MB. Podeli PDF na manje delove pa skeniraj deo po deo.`,
        code: 'file_too_large',
      },
    };
  }
  return {
    status: 400,
    body: { error: err.message || 'Dokument nije prihvaćen.', code: 'upload_rejected' },
  };
}

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
    // The trainer's own words win; a derived one only fills an empty field.
    instruction:
      typeof position.instruction === 'string' && position.instruction.trim()
        ? position.instruction.trim().slice(0, 500)
        : deriveInstruction(fen, verifiedSan),
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
      // Saying only "it does not fit" leaves the trainer nothing to act on. The
      // commonest cause by far is the side to move, so check that before
      // reporting: measured on a real re-scan, all nine conflicts were
      // positions stored as black where the book's move plays for white.
      let playsFlipped = false;
      try {
        const other = existing.fen.split(' ')[1] === 'w' ? 'b' : 'w';
        playsFlipped = Boolean(
          new Chess(withSideToMove(existing.fen, other)).move(incoming.solutionSan)
        );
      } catch {
        playsFlipped = false;
      }

      return {
        action: 'conflict',
        fields: {},
        reason: playsFlipped
          ? `rešenje "${incoming.solutionSan}" igra tek ako je druga strana na potezu — strana je verovatno pogrešna`
          : `rešenje "${incoming.solutionSan}" ne igra u već sačuvanoj poziciji`,
        sideLikelyWrong: playsFlipped,
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

  // A task the position can state about itself, once a solution is known. Never
  // over an instruction somebody wrote: those are teaching words, not data.
  if (!existing.instruction) {
    const derived =
      incoming.instruction ??
      deriveInstruction(existing.fen, fields.solution_san ?? existing.solution_san);
    if (derived) fields.instruction = derived;
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

/**
 * What the student is being asked to do, when the position itself can say.
 *
 * A board with no task is not an exercise — until now a trainer could assign a
 * position and the child would see pieces and nothing else. Most of the time the
 * words have to come from the trainer, but one case the data settles on its own:
 * a solution that has been verified to mate immediately *is* "mate in one", and
 * saying so is reporting, not guessing.
 *
 * Everything else returns null on purpose. A single stored move does not reveal
 * whether the task was to win material, to hold a draw, or to find the only
 * defence, and inventing a task is worse than leaving the field for a person.
 */
function deriveInstruction(fen, solutionSan) {
  if (!solutionSan) return null;
  try {
    const board = new Chess(fen);
    const side = board.turn() === 'w' ? 'Beli' : 'Crni';
    const move = board.move(solutionSan);
    if (!move) return null;
    if (board.isCheckmate()) return `${side} matira u jednom potezu.`;
    return null;
  } catch {
    return null;
  }
}

module.exports = {
  prepareRow,
  uploadRejection,
  MAX_DOCUMENT_BYTES,
  prepareRows,
  mergePlan,
  withSideToMove,
  solutionPlaysIn,
  deriveInstruction,
  MAX_POSITIONS_PER_CONFIRM,
};
