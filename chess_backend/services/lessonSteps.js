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
const MAX_CHOICE_TEXT = 200;
const MAX_ACCEPTED = 6;
const MIN_CHOICES = 2;
const MAX_CHOICES = 4;

/// What a step may ask. An absent kind means `show`; see [buildLessonStep].
const KINDS = ['show', 'ask_move', 'ask_choice'];

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

  // What the step asks, if it asks anything.
  //
  // An absent kind is `show`, which is what every lesson stored before this
  // existed is — so the whole back catalogue is already valid and no migration
  // was needed. An *unknown* kind is refused rather than treated as `show`:
  // falling back would turn a typo in the editor into a step that silently
  // stops asking the child anything, and the trainer would watch their question
  // disappear with no error.
  const kind = step.kind === undefined || step.kind === null ? 'show' : step.kind;
  if (!KINDS.includes(kind)) {
    return { ok: false, status: 400, error: 'Korak može da bude prikaz, pitanje o potezu ili pitanje sa ponuđenim odgovorima.' };
  }
  entry.kind = kind;

  // The solution travels on **any** step, and is required only where something
  // is asked. It is a property of the position rather than of the question: a
  // position scanned out of a book carries the move the author printed, and
  // every step the course builder makes from the library has had one since
  // before kinds existed.
  //
  // An earlier draft of this contract dropped it from `show` steps, on the
  // reasoning that an answer nothing judges is also an answer nothing redacts.
  // The second half is false — [redactStepForStudent] takes it out whatever the
  // kind — and the first half would have deleted a scanned move the next time a
  // trainer saved an old lesson. The test that said otherwise was the lead's
  // and was wrong; `lesson_steps.test.js` had it right since the day it was
  // written.
  if (kind === 'ask_move') {
    const built = buildMoveAnswer(fen, step);
    if (!built.ok) return built;
    entry.solutionSan = built.solutionSan;
    if (built.acceptedSans.length > 0) entry.acceptedSans = built.acceptedSans;
  } else {
    const solutionSan = text(step.solutionSan, MAX_SAN);
    if (solutionSan) entry.solutionSan = solutionSan;
  }

  // Choices are different, and are gated: they have no meaning at all without a
  // question, and a step carrying options nobody is ever shown is a step whose
  // author thinks they asked something.
  if (kind === 'ask_choice') {
    const built = buildChoices(step.choices);
    if (!built.ok) return built;
    entry.choices = built.choices;
  }

  return { ok: true, entry };
}

/// The answer to an `ask_move` step: the author's move, and the others that are
/// also right.
///
/// Refuses rather than repairs, like the position does. A step with no solution
/// is a board on which every answer is wrong — the same refusal `canAssign` in
/// `customPuzzleJudge.js` already makes, and the scanner can produce exactly
/// that row, since `solution_san` is null when the printed move did not verify.
function buildMoveAnswer(fen, step) {
  const solutionSan = text(step.solutionSan, MAX_SAN);
  if (!solutionSan) {
    return { ok: false, status: 400, error: 'Pitanje o potezu mora da nosi rešenje.' };
  }
  if (!playsIn(fen, solutionSan)) {
    return { ok: false, status: 422, error: `Rešenje „${solutionSan}" ne može da se odigra u ovoj poziciji.` };
  }

  const raw = Array.isArray(step.acceptedSans) ? step.acceptedSans : [];
  if (raw.length > MAX_ACCEPTED) {
    return { ok: false, status: 400, error: `Najviše ${MAX_ACCEPTED} dodatnih tačnih poteza.` };
  }

  const acceptedSans = [];
  for (const value of raw) {
    const san = text(value, MAX_SAN);
    if (!san) continue;
    // The same right answer written twice is not a mistake about chess, so it
    // is dropped rather than refused. A move that cannot be played is a mistake
    // about chess, and the refusal names it — otherwise a child finds it by
    // being told „netačno" for a move their trainer believed was accepted.
    if (bare(san) === bare(solutionSan) || acceptedSans.some((a) => bare(a) === bare(san))) continue;
    if (!playsIn(fen, san)) {
      return { ok: false, status: 422, error: `Potez „${san}" ne može da se odigra u ovoj poziciji.` };
    }
    acceptedSans.push(san);
  }

  return { ok: true, solutionSan, acceptedSans };
}

/// The options of an `ask_choice` step.
///
/// Two to four, exactly one of them right. Both ways of getting that wrong fail
/// differently on screen and both are refused: none correct is a question no
/// child can pass, two correct is a question that calls a right answer wrong.
/// One correct answer in v1 — a trainer who wants two writes two steps.
function buildChoices(value) {
  if (!Array.isArray(value) || value.length < MIN_CHOICES || value.length > MAX_CHOICES) {
    return { ok: false, status: 400, error: `Pitanje mora da ima između ${MIN_CHOICES} i ${MAX_CHOICES} ponuđenih odgovora.` };
  }

  const choices = [];
  for (const raw of value) {
    const body = text(raw && raw.text, MAX_CHOICE_TEXT);
    if (!body) {
      return { ok: false, status: 400, error: 'Svaki ponuđeni odgovor mora da ima tekst.' };
    }
    choices.push({ text: body, correct: raw.correct === true });
  }

  if (choices.filter((c) => c.correct).length !== 1) {
    return { ok: false, status: 400, error: 'Tačno jedan ponuđeni odgovor mora da bude tačan.' };
  }

  return { ok: true, choices };
}

function playsIn(fen, san) {
  try {
    return Boolean(new Chess(fen).move(san));
  } catch {
    return false;
  }
}

/// Strips the decoration SAN carries, so `Qf1#` and `Qf1` compare equal.
function bare(san) {
  return String(san || '').trim().replace(/[+#!?]+$/g, '');
}

/// The step as the **student** may see it.
///
/// `POST /assignments/:id/custom-attempt` already states the rule this keeps:
/// „the move is judged on the server because the answer lives there: sending
/// the solution to the client so it could mark its own work would hand the
/// student the very thing being asked of them."
///
/// So the answer is taken out here, once, and every reader that serves a
/// student goes through it. A `show` step has no answer to take out and comes
/// back untouched.
function redactStepForStudent(step) {
  if (!step || typeof step !== 'object') return step;
  const { solutionSan, acceptedSans, choices, ...rest } = step;
  if (!Array.isArray(choices)) return rest;
  return { ...rest, choices: choices.map(({ text: body }) => ({ text: body })) };
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
  redactStepForStudent,
  KINDS,
  buildLessonSteps,
  stepsOfLesson,
  stepByKey,
  generateStepId,
  STEP_ID_PATTERN,
  MAX_TITLE,
  MAX_INSTRUCTION,
  MAX_SAN,
};
