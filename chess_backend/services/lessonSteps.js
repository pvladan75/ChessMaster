// lessonSteps.js — what a lesson step is allowed to be.
//
// Kept out of the route so it can be tested without a server or a database:
// this is the point where a position from somewhere else becomes a step, and
// two things have to survive that crossing (the task and the solution) while
// everything else must not sneak in.

const crypto = require('crypto');
const { Chess } = require('chess.js');

const MAX_TITLE = 200;
const MAX_INSTRUCTION = 500;
const MAX_SAN = 20;

/// What a step id may look like. Kept narrow because this value becomes a
/// database key (`step_key VARCHAR(16)`) and travels in a URL.
const STEP_ID_PATTERN = /^[A-Za-z0-9_-]{1,16}$/;

/// A step's id, generated when one is not supplied.
///
/// Hex, so it can never come out shaped like `p3` — the namespace
/// [stepsOfLesson] backfills legacy steps into. If those two could collide, one
/// lesson's generated id would resolve to another lesson's backfilled step.
/// `generated ids never collide with the backfill namespace` in
/// `test/lesson_step_identity.test.js` is what keeps that true.
function generateStepId() {
  return crypto.randomBytes(4).toString('hex');
}

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

  // The step's identity, and the one field that must survive an edit unchanged.
  //
  // A step that is read, edited and written back has to come out the other side
  // as the same step. `review_items` and `assignment_items` name it by this
  // value, and nothing joins on it — so an id quietly regenerated is a
  // student's schedule quietly orphaned, with no error anywhere.
  //
  // Refused rather than repaired for the same reason: a client sending
  // something that cannot have been written here is a client that has lost the
  // id it was given, and minting a fresh one hides exactly that.
  let id;
  if (step.id === undefined || step.id === null) {
    id = generateStepId();
  } else if (typeof step.id === 'string' && STEP_ID_PATTERN.test(step.id)) {
    id = step.id;
  } else {
    return { ok: false, status: 400, error: 'Korak nosi neispravnu oznaku.' };
  }

  // Only the fields a step is made of. Anything else the caller sent stays out
  // rather than being stored because it happened to arrive.
  const entry = {
    id,
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

  const steps = (Array.isArray(list) && list.length > 0)
    ? list
    : [{ title, fen, pgn }];

  return steps.map(withBackfilledId);
}

/// Names a stored step that was written before ids existed.
///
/// `p<index>` and **not** a generated id, because this value is a database key
/// the moment a schedule row is written against it: a generator here would hand
/// out a different key on every read of the same lesson, and nothing would ever
/// resolve twice. The index is also exactly what those rows mean today, which
/// is what makes the backfill of `review_items` correct rather than a guess.
function withBackfilledId(step, index) {
  if (!step || typeof step !== 'object') return step;
  const id = typeof step.id === 'string' && STEP_ID_PATTERN.test(step.id)
    ? step.id
    : `p${index}`;
  return step.id === id ? step : { ...step, id };
}

/// Builds a whole lesson's steps, and is the only place that may.
///
/// One place rather than three, because uniqueness is a property of the list
/// and cannot be checked one step at a time — `buildLessonStep` sees a single
/// step and could not know another one already claims its id.
///
/// Returns `{ ok: true, entries }` or the same refusal shape one step gives,
/// with the position in the list named: saving three of four steps would leave
/// the trainer with a lesson they did not write and no way to see which part is
/// missing.
function buildLessonSteps(list) {
  if (!Array.isArray(list)) {
    return { ok: false, status: 400, error: 'Lekcija mora imati listu koraka.' };
  }

  const entries = [];
  const seen = new Set();

  for (let i = 0; i < list.length; i++) {
    const built = buildLessonStep(list[i]);
    if (!built.ok) {
      return { ok: false, status: built.status, error: `Korak ${i + 1}: ${built.error}` };
    }

    // Two steps claiming one id makes [stepByKey] ambiguous, and a schedule row
    // naming it would resolve to whichever happens to come first.
    if (seen.has(built.entry.id)) {
      return {
        ok: false,
        status: 400,
        error: `Korak ${i + 1}: oznaka „${built.entry.id}" je već uzeta u ovoj lekciji.`,
      };
    }
    seen.add(built.entry.id);
    entries.push(built.entry);
  }

  return { ok: true, entries };
}

/// The step a stored key names, or null.
///
/// Null and never a neighbour. A trainer may delete a step a student has a
/// schedule for, and handing back whichever step inherited its index would ask
/// the child about a board nobody ever showed them — worse than showing
/// nothing, which is what `getDue` already does with rows pointing past the end.
function stepByKey(steps, key) {
  if (!Array.isArray(steps) || typeof key !== 'string') return null;
  return steps.find((step) => step && step.id === key) || null;
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
  buildLessonSteps,
  stepsOfLesson,
  stepByKey,
  generateStepId,
  STEP_ID_PATTERN,
  MAX_TITLE,
  MAX_INSTRUCTION,
  MAX_SAN,
};
