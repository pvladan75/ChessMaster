// lessonSteps.js — what a tutorial's part is allowed to be.
//
// Kept out of the route so it can be tested without a server or a database:
// this is the point where a position from somewhere else becomes a part.
//
// **Every part shows** (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4): a position, a
// line, and what is said and drawn on it. A tutorial is material for a film,
// and a question for a student is an exercise — so the task, the solution, the
// accepted moves and the offered answers a part used to carry are neither
// accepted nor stored.

const crypto = require('crypto');
const { Chess } = require('chess.js');

const MAX_TITLE = 200;
const MAX_PGN = 100000;

/// What a part may be. An absent kind means `show`, and `show` is all there is.
const KINDS = ['show'];

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
    return { ok: false, status: 400, error: 'step is required.' };
  }

  const fen = typeof step.fen === 'string' ? step.fen.trim() : '';
  if (fen === '') {
    return { ok: false, status: 400, error: 'A step must have a position.' };
  }

  // The client is not the authority on the position, here as everywhere else.
  try {
    new Chess(fen);
  } catch {
    return { ok: false, status: 422, error: 'Invalid position.' };
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
    return { ok: false, status: 400, error: 'Invalid step ID.' };
  }

  // Over a cap is refused with the number, never cut to fit. A line cut
  // mid-token is the step that does not replay, stored past the app's own
  // read-back; a title or a task cut at 200 or 500 characters is the trainer's
  // words lost with „saved" on the screen. Audit of 16.9.2026
  // (`docs/audit/contract.md`, 9); refusing prose too was the owner's decision
  // the same day, replacing the older rule that a pasted paragraph is cut.
  const tooLong = overLimit(step.title, MAX_TITLE, 'The title')
    ?? overLimit(step.pgn, MAX_PGN, 'The line');
  if (tooLong) {
    return { ok: false, status: 400, error: tooLong };
  }

  // Only the fields a step is made of. Anything else the caller sent stays out
  // rather than being stored because it happened to arrive.
  const entry = {
    id,
    title: text(step.title, MAX_TITLE) ?? 'Position',
    fen,
  };

  const pgn = text(step.pgn, MAX_PGN);
  if (pgn) entry.pgn = pgn;

  // Which way round the board stands when a child opens this step.
  //
  // Stored only when the client actually says, because absent is a third
  // answer and not a synonym for `false`: the student's viewer works the
  // orientation out from whose turn it is when nothing says otherwise, and
  // every step written before this field existed relies on that. A trainer
  // who left a black-to-move position deliberately the white way round is
  // saying something a computed orientation would overrule.
  if (typeof step.blackOrientation === 'boolean') {
    entry.blackOrientation = step.blackOrientation;
  }

  // Only `show`. An absent kind is `show`, which is what every part stored
  // before kinds existed is. A part that asks — `ask_move`, `ask_choice` — is
  // refused with the reason, not stored as a show part: a trainer whose
  // question silently turned into a picture would never know it had.
  const kind = step.kind === undefined || step.kind === null ? 'show' : step.kind;
  if (!KINDS.includes(kind)) {
    return {
      ok: false,
      status: 400,
      error: 'A part only shows a position and a line; a question is an exercise.',
    };
  }
  entry.kind = kind;

  return { ok: true, entry };
}

/// The trimmed text, or null when there is none. Every field is measured by
/// [overLimit] before it reaches here, so the slice never cuts what a caller
/// sent; it is the last line of defence, not the rule.
function text(value, limit) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed.slice(0, limit);
}

/// The sentence refusing [value] for being longer than [limit], or null.
function overLimit(value, limit, what) {
  if (typeof value !== 'string') return null;
  const length = value.trim().length;
  return length > limit
    ? `${what} is ${length} characters long; a part can hold at most ${limit}.`
    : null;
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
/// `p<index>` and **not** a generated id, because a part's id is its identity
/// across saves: the app sends it back, and `PUT /lessons/:id` refuses a save
/// that would drop the stored ones. A generator here would hand out a different
/// id on every read of the same lesson, so nothing would ever match twice.
/// (It was first a key for `review_items` schedule rows, which went with
/// phase 2 of docs/PLAN-TUTORIJAL-VIDEO.md.)
function withBackfilledId(step, index) {
  if (!step || typeof step !== 'object') return step;
  const id = typeof step.id === 'string' && STEP_ID_PATTERN.test(step.id)
    ? step.id
    : `p${index}`;
  // And its kind, for the same reason the id is filled in: every reader may
  // then ask what a step is without first checking whether the field is there.
  // A stored step with no kind is a `show` step — that is what all of them
  // were before this existed.
  const kind = KINDS.includes(step.kind) ? step.kind : 'show';
  return step.id === id && step.kind === kind ? step : { ...step, id, kind };
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
    return { ok: false, status: 400, error: 'A tutorial must have a list of steps.' };
  }

  const entries = [];
  const seen = new Set();

  for (let i = 0; i < list.length; i++) {
    const built = buildLessonStep(list[i]);
    if (!built.ok) {
      return { ok: false, status: built.status, error: `Step ${i + 1}: ${built.error}` };
    }

    // Two steps claiming one id is two parts with one identity: [stepByKey]
    // and the app, which keeps the id across saves, would each find whichever
    // happens to come first.
    if (seen.has(built.entry.id)) {
      return {
        ok: false,
        status: 400,
        error: `Step ${i + 1}: identifier "${built.entry.id}" is already used in this tutorial.`,
      };
    }
    seen.add(built.entry.id);
    entries.push(built.entry);
  }

  return { ok: true, entries };
}

/// The step a stored key names, or null.
///
/// Null and never a neighbour: a part that was deleted is not whichever part
/// inherited its index. No route reads it since the schedule rows went (phase 2
/// of docs/PLAN-TUTORIJAL-VIDEO.md); `lesson_step_identity.test.js` still holds
/// the rule, for the day a reader by id comes back.
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
  KINDS,
  buildLessonSteps,
  stepsOfLesson,
  stepByKey,
  generateStepId,
  STEP_ID_PATTERN,
  MAX_TITLE,
};
