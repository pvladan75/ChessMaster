// lessonSteps.js — what a lesson step is allowed to be.
//
// Kept out of the route so it can be tested without a server or a database:
// this is the point where a position from somewhere else becomes a step, and
// two things have to survive that crossing (the task and the solution) while
// everything else must not sneak in.

const { Chess } = require('chess.js');

const MAX_TITLE = 200;
const MAX_INSTRUCTION = 500;
const MAX_SAN = 20;

/// Builds one step from what a client sent.
///
/// Returns `{ ok: true, entry }`, or `{ ok: false, status, error }` with the
/// reason in the trainer's language. It refuses rather than repairs: a board
/// nothing can load would otherwise be found by the student, inside a lesson.
function buildLessonStep(step) {
  if (!step || typeof step !== 'object' || Array.isArray(step)) {
    return { ok: false, status: 400, error: 'step je obavezan.' };
  }

  const fen = typeof step.fen === 'string' ? step.fen.trim() : '';
  if (fen === '') {
    return { ok: false, status: 400, error: 'Korak mora da nosi poziciju.' };
  }

  // The client is not the authority on the position, here as everywhere else.
  try {
    new Chess(fen);
  } catch {
    return { ok: false, status: 422, error: 'Pozicija nije ispravna.' };
  }

  // Only the fields a step is made of. Anything else the caller sent stays out
  // rather than being stored because it happened to arrive.
  const entry = {
    title: text(step.title, MAX_TITLE) ?? 'Pozicija',
    fen,
  };

  const pgn = text(step.pgn, 100000);
  if (pgn) entry.pgn = pgn;

  // The task travels with the position. A step without one is a board with no
  // question on it, which is the oldest complaint about this feature.
  const instruction = text(step.instruction, MAX_INSTRUCTION);
  if (instruction) entry.instruction = instruction;

  // Kept, and unused for now: a lesson is read rather than solved, but the same
  // step may later be set as homework and the move would otherwise be gone.
  const solutionSan = text(step.solutionSan, MAX_SAN);
  if (solutionSan) entry.solutionSan = solutionSan;

  return { ok: true, entry };
}

function text(value, limit) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed.slice(0, limit);
}

/// The steps of a saved lesson, however it was saved.
///
/// A lesson made in the builder has a `position_list`. One saved as a single
/// position — from the analysis board, the scanner, or the library — has none,
/// and *is* one step, built from the lesson's own `fen`/`pgn` columns.
///
/// This was written out four times: when a lesson is assigned, in the student's
/// viewer, in the spaced-repetition queue, and in the review screen. The review
/// screen's copy read `position_list` and stopped there, so a single-position
/// lesson came back with no steps at all — the trainer opened "Pregled i
/// komentari" and saw "Pozicija 1" over an empty square reading "tabla nije
/// dostupna", while the same lesson worked everywhere else. Nothing failed;
/// one of four readings simply knew less than the other three.
///
/// Callers pass their own column names, because two of them arrive aliased.
function stepsOfLesson({ positionList, title, fen, pgn }) {
  const list = Array.isArray(positionList)
    ? positionList
    : (typeof positionList === 'string' ? safeParse(positionList) : null);

  if (Array.isArray(list) && list.length > 0) return list;
  return [{ title, fen, pgn }];
}

function safeParse(text) {
  try {
    const parsed = JSON.parse(text);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    // Unreadable is the same as absent: the lesson still has its own position,
    // and that is better than a screen with nothing on it.
    return null;
  }
}

module.exports = {
  buildLessonStep,
  stepsOfLesson,
  MAX_TITLE,
  MAX_INSTRUCTION,
  MAX_SAN,
};
