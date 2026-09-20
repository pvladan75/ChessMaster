// exerciseAuthoring.js — an exercise a trainer makes by hand.
//
// Until this existed `custom_puzzles` had two writers, a scanned book and a
// student's own mistakes, so a trainer could not make a position that is
// judged: Preparation's „Save position" writes a `saved_lessons` row, which
// nothing can judge (`docs/PLAN-EXERCISE.md`, phase 2a).
//
// What is accepted here is exactly what `exercise.js` can read back — the
// payload is parsed by the same `readSolution` and `parseEngineGameTask` the
// readers use, and **what is stored is their output, not the payload**. A line
// the server would refuse to judge is refused when it is written, one screen
// away from the trainer who can fix it, not at a student's board.
const crypto = require('crypto');
const { Chess } = require('chess.js');

const { exerciseColumns, exerciseOf, readSolution, assignableProblem } = require('./exercise');
const { parseEngineGameTask } = require('./engineGameTask');
const { cleanThemes, deriveInstruction } = require('./scanIntake');

const MAX_NAME = 120;
const MAX_INSTRUCTION = 500;

// What the row asks comes through the one reader's own column list, so this
// file never names the columns it would be tempted to interpret.
const COLUMNS = `puzzle_id, side_to_move, name, instruction, themes, origin, created_at,
                 ${exerciseColumns()}`;

/// Reads what the editor sends, or says why it is not an exercise.
///
/// [keptFen] is the position of an exercise that already exists. **An exercise
/// keeps its position**: it may already be in a student's homework, and a new
/// board under an old id is a different question wearing the old one's
/// answers. A different position is a new exercise.
function parseExercise(raw, { keptFen = null } = {}) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ok: false, error: 'Nothing to save.' };
  }

  const name = typeof raw.name === 'string' ? raw.name.trim() : '';
  if (!name) return { ok: false, error: 'An exercise needs a name.' };
  if (name.length > MAX_NAME) return { ok: false, error: `The name is longer than ${MAX_NAME} characters.` };

  const sentFen = typeof raw.fen === 'string' ? raw.fen.trim() : '';
  if (keptFen !== null && sentFen && sentFen !== keptFen) {
    return { ok: false, status: 409, error: 'An exercise keeps its position. Make a new exercise for a new position.' };
  }
  const fen = keptFen ?? sentFen;
  if (!fen) return { ok: false, error: 'An exercise needs a position.' };
  let board;
  try {
    board = new Chess(fen);
  } catch (err) {
    return { ok: false, error: `That position is not valid: ${err.message}` };
  }

  const rawTask = raw.task && typeof raw.task === 'object' && !Array.isArray(raw.task) ? raw.task : null;
  if (rawTask === null) {
    return { ok: false, error: 'An exercise needs a task: what is the student asked to do?' };
  }

  let task;
  let solution = null;
  if (rawTask.type === 'find') {
    const read = readSolution(fen, raw.solution);
    if (!read.ok) return { ok: false, error: read.error };
    task = { type: 'find' };
    solution = read.steps;
  } else if (rawTask.type === 'game') {
    const parsed = parseEngineGameTask({ ...rawTask, fen });
    if (!parsed.ok) return { ok: false, error: parsed.error };
    // Stored without the position: the row has one, and `exerciseOf` puts it
    // back. A position kept twice is two positions.
    const { fen: _rowHasIt, ...rest } = parsed.task;
    task = { type: 'game', ...rest };
  } else {
    return { ok: false, error: 'The task must be "find" or "game".' };
  }

  const words = typeof raw.instruction === 'string' ? raw.instruction.trim().slice(0, MAX_INSTRUCTION) : '';
  return {
    ok: true,
    exercise: {
      fen,
      side: board.turn(),
      name,
      // The trainer's own words win; a derived one only fills an empty field.
      instruction: words || (solution ? deriveInstruction(fen, solution[0].accept[0]) : null),
      themes: cleanThemes(raw.themes),
      task,
      solution,
    },
  };
}

/// One exercise as the editor reads it — with its solution, because the only
/// reader of this shape is its owner.
function present(row) {
  const read = exerciseOf(row);
  const problem = assignableProblem(row, { as: read.task?.type ?? 'find' });
  return {
    id: row.puzzle_id,
    fen: row.fen,
    sideToMove: row.side_to_move,
    name: row.name,
    instruction: row.instruction,
    themes: row.themes || [],
    origin: row.origin,
    task: read.task,
    solution: read.solution,
    needsReview: row.needs_review === true,
    assignable: problem === null,
    blockedReason: problem,
  };
}

async function createExercise(pool, { ownerId, payload }) {
  const parsed = parseExercise(payload);
  if (!parsed.ok) return { ok: false, status: parsed.status ?? 422, error: parsed.error };
  const e = parsed.exercise;
  const puzzleId = `ex_${crypto.randomBytes(8).toString('hex')}`;
  const result = await pool.query(
    `INSERT INTO custom_puzzles
       (puzzle_id, owner_id, fen, side_to_move, name, instruction, themes, task, solution, origin)
     VALUES ($1, $2, $3, $4, $5, $6, $7::varchar[], $8, $9, 'manual')
     RETURNING ${COLUMNS}`,
    [puzzleId, ownerId, e.fen, e.side, e.name, e.instruction, e.themes,
      JSON.stringify(e.task), e.solution ? JSON.stringify(e.solution) : null]
  );
  return { ok: true, exercise: present(result.rows[0]) };
}

/// „No such exercise" and „not yours" are one answer, so a guessed id tells
/// nobody which exercises exist.
async function readExercise(pool, { ownerId, puzzleId }) {
  const found = await pool.query(
    `SELECT ${COLUMNS} FROM custom_puzzles WHERE puzzle_id = $1 AND owner_id = $2`,
    [puzzleId, ownerId]
  );
  if (found.rowCount === 0) return { ok: false, status: 404, error: 'No such exercise.' };
  return { ok: true, exercise: present(found.rows[0]) };
}

async function updateExercise(pool, { ownerId, puzzleId, payload }) {
  const found = await pool.query(
    'SELECT fen FROM custom_puzzles WHERE puzzle_id = $1 AND owner_id = $2',
    [puzzleId, ownerId]
  );
  if (found.rowCount === 0) return { ok: false, status: 404, error: 'No such exercise.' };

  const parsed = parseExercise(payload, { keptFen: found.rows[0].fen });
  if (!parsed.ok) return { ok: false, status: parsed.status ?? 422, error: parsed.error };
  const e = parsed.exercise;
  const result = await pool.query(
    `UPDATE custom_puzzles
        SET name = $3, instruction = $4, themes = $5::varchar[], task = $6, solution = $7
      WHERE puzzle_id = $1 AND owner_id = $2
      RETURNING ${COLUMNS}`,
    [puzzleId, ownerId, e.name, e.instruction, e.themes,
      JSON.stringify(e.task), e.solution ? JSON.stringify(e.solution) : null]
  );
  return { ok: true, exercise: present(result.rows[0]) };
}

module.exports = { parseExercise, createExercise, readExercise, updateExercise };
