// exercise.js — what a row of `custom_puzzles` asks, and how it is answered.
//
// A trainer does not send a position, they send an exercise: a position plus a
// task (`docs/PLAN-EXERCISE.md`). The row grew into that — first a board and
// the move a book printed, then an instruction, now a task and an answer — and
// every consumer used to read `solution_san` for itself. This file is the one
// place that knows what the columns mean; everything that decides whether an
// exercise can be sent, judges an answer or reveals one reads it through
// `exerciseOf`. `test/exercise_one_reader.test.js` fails if another file under
// `routes/` or `services/` starts reading the column again.
//
// The scan pipeline (`routes/scans.js`, `services/scanIntake.js`) and the
// homework made from mistakes are the *writers* of `solution_san`: a book
// prints one move, and that is what they verify and store. They are allowed
// the column; they are not allowed to decide what it means to a student.
const { Chess } = require('chess.js');
const { parseEngineGameTask } = require('./engineGameTask');

const ORIGINS = ['book', 'manual', 'mistakes'];
const MAX_ACCEPTED = 8;

/// The columns `exerciseOf` needs, for a SELECT list. With an alias:
/// `exerciseColumns('cp')` → `cp.fen, cp.task, cp.solution, cp.solution_san, …`.
///
/// A fragment rather than a convention, for the reason `homeworkService.js`
/// has its own: a reader that forgets a column gets `undefined`, and
/// `undefined` reads as „no solution" — a wrong answer, not an error.
function exerciseColumns(alias) {
  const p = alias ? `${alias}.` : '';
  return `${p}fen, ${p}task, ${p}solution, ${p}solution_san, ${p}needs_review`;
}

/// What a longer list is told. The app's reader says the same sentence
/// (`exercise_line.dart`), and the shared fixture holds both to it.
const ONE_MOVE = 'A find exercise asks for one move. For more, use Checkmate in N or Play N moves.';

/// Reads a stored solution from [fen], or says why it cannot be read.
///
/// The shape is `[{ accept: [san, …] }]` — **a list of exactly one entry**, the
/// one move a find exercise asks of the student (`docs/PLAN-EXERCISE.md`,
/// phases 14 and 16). `accept[0]` is the author's move; the others are right as
/// well. Every accepted move must be legal in the position — the app's writer
/// reads its work back the same way before it saves, so a solution the server
/// refuses is one the app should never have sent.
///
/// It is a list because that is how the rows were stored while a solution
/// could be a line; this is the reader *and* the writer's rule, so a row that
/// still holds a line is refused aloud, never judged on its first move.
function readSolution(fen, raw) {
  if (!Array.isArray(raw) || raw.length === 0) {
    return { ok: false, error: 'The solution must be a list of at least one move.' };
  }
  if (raw.length > 1) {
    return { ok: false, error: ONE_MOVE };
  }
  let board;
  try {
    board = new Chess(fen);
  } catch {
    return { ok: false, error: 'The position is not valid.' };
  }

  const entry = raw[0];
  const accept = entry && Array.isArray(entry.accept)
    ? entry.accept.filter((san) => typeof san === 'string' && san.trim()).map((san) => san.trim())
    : [];
  if (accept.length === 0) {
    return { ok: false, error: 'The solution accepts nothing, so nothing can be right.' };
  }
  if (accept.length > MAX_ACCEPTED) {
    return { ok: false, error: `More than ${MAX_ACCEPTED} accepted moves.` };
  }

  // Every accepted move is tried on its own copy of the position.
  const played = [];
  for (const san of accept) {
    const probe = new Chess(board.fen());
    let move = null;
    try {
      move = probe.move(san);
    } catch {
      move = null;
    }
    if (!move) return { ok: false, error: `"${san}" cannot be played here.` };
    played.push(move.san);
  }
  if (new Set(played).size !== played.length) {
    return { ok: false, error: 'The same move is accepted twice.' };
  }
  return { ok: true, steps: [{ accept: played }] };
}

/**
 * Reads one `custom_puzzles` row as an exercise.
 *
 * Returns `{ task, solution, problem }`:
 * - `task` — `{ type: 'find' }`, or `{ type: 'game', …the engine-game task }`
 *   with the row's own position in it. The stored task carries no FEN: the row
 *   has one, and a position kept twice is two positions.
 * - `solution` — the one step of a `find` task as it was read, `null` otherwise.
 * - `problem` — why this row cannot be read as an exercise, or `null`.
 *
 * **A row with no `task` and no `solution` is a find-the-move exercise whose
 * solution is the one move a book printed.** That is every row written before
 * the columns existed, and they are judged exactly as they were.
 */
function exerciseOf(row) {
  if (!row || typeof row !== 'object') {
    return { task: null, solution: null, problem: 'is not an exercise' };
  }
  const rawTask = row.task && typeof row.task === 'object' && !Array.isArray(row.task)
    ? row.task
    : null;
  const type = rawTask === null ? 'find' : rawTask.type;

  if (type === 'game') {
    const parsed = parseEngineGameTask({ ...rawTask, fen: row.fen });
    if (!parsed.ok) {
      return { task: null, solution: null, problem: `has a task that cannot be played: ${parsed.error}` };
    }
    return { task: { type: 'game', ...parsed.task }, solution: null, problem: null };
  }
  if (type !== 'find') {
    return { task: null, solution: null, problem: 'has a task nobody defined' };
  }

  const task = { type: 'find' };
  if (row.solution !== null && row.solution !== undefined) {
    const read = readSolution(row.fen, row.solution);
    if (!read.ok) {
      return { task, solution: null, problem: `has a solution that cannot be read: ${read.error}` };
    }
    return { task, solution: read.steps, problem: null };
  }
  if (row.solution_san) {
    // Not replayed: the scan pipeline verified this move when it stored it,
    // and several readers select the row without its position.
    return { task, solution: [{ accept: [String(row.solution_san).trim()] }], problem: null };
  }
  return { task, solution: null, problem: 'has no solution, so an answer cannot be judged' };
}

/// The move a one-move judge compares against, and the others it accepts.
/// `null` when the row has no answer to give.
function firstMoveOf(row) {
  const { solution } = exerciseOf(row);
  if (!solution) return null;
  const [main, ...others] = solution[0].accept;
  return { solutionSan: main, acceptedSans: others };
}

/**
 * Can this exercise be given to a student — as the kind of item [as] names?
 *
 * Refusals, all loud. Without a solution nothing can judge the answer, and a
 * student would be told "wrong" whatever they played. A row still marked for
 * review is one we know we are unsure about, and homework is the last place
 * to find that out. And **a game exercise is not a find-the-move item**: every
 * path that existed before games were exercises builds a puzzle-kind
 * assignment, whose solver asks for one move and would have nothing to judge
 * it with — so `as` defaults to `'find'`, and a caller that can really send a
 * game says so.
 */
function assignableProblem(row, { as = 'find' } = {}) {
  const { task, problem } = exerciseOf(row);
  if (problem) return problem;
  if (row.needs_review) return 'is marked for review';
  if (task.type !== as) {
    return as === 'find'
      ? 'is played out against the engine, so it cannot be answered with one move'
      : 'asks for a move, so it cannot be played out against the engine';
  }
  return null;
}

module.exports = {
  ORIGINS,
  exerciseColumns,
  exerciseOf,
  firstMoveOf,
  readSolution,
  assignableProblem,
};
