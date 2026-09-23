// exerciseSolo.js — solving one's own exercises (docs/PLAN-MATERIJAL.md,
// phase 1).
//
// Until this existed an exercise could be solved only as homework: the one
// route that judged an answer (`POST /assignments/:id/custom-attempt`) asked
// for an assignment, so a trainer testing their own exercise, a student who
// scanned their own book and anybody training alone had no way to answer one.
//
// The judge is the homework's, and only the homework's: `firstMoveOf` reads
// the answer, `judgeAttempt` decides. Nothing here names `solution_san`
// (`test/exercise_one_reader.test.js`).
//
// The verdict is logged in `user_puzzle_attempts` with `source = 'own'`, and
// **this file is that source's only writer**: `POST /api/puzzles/attempt`
// takes `solved` from the client, which is right for a drill the app judges
// and wrong for an exercise the server judges, so that route refuses `own`
// (`puzzleProgress.SERVER_JUDGED`). Nothing touches `assignment_items`: an
// answer given alone is not homework handed in.

const { exerciseColumns, exerciseOf, firstMoveOf, assignableProblem } = require('./exercise');
const { judgeAttempt } = require('./customPuzzleJudge');
const { judgeEngineGame } = require('./engineGameTask');
const { attemptsOf, retryIds } = require('./puzzleProgress');

const SOURCE = 'own';

/// What the solver draws of one exercise: the fields `CustomPosition.fromJson`
/// reads in the app, and **never the answer** — the solution is released by
/// the attempt, as it is in homework.
const POSITION_COLUMNS =
  'puzzle_id, name, side_to_move, instruction, themes, source_title, source_label';

function present(row) {
  return {
    puzzle_id: row.puzzle_id,
    name: row.name ?? null,
    fen: row.fen,
    side_to_move: row.side_to_move,
    instruction: row.instruction ?? null,
    themes: row.themes ?? [],
    source_title: row.source_title ?? null,
    source_label: row.source_label ?? null,
  };
}

/**
 * One answer to one of the owner's own exercises.
 *
 * Answers `{ ok: true, result: { correct, reason, playedSan, solutionSan } }` —
 * the homework route's shape, which the app's `CustomAttemptResult` reads — or
 * `{ ok: false, status, error }`: 400 for no move, 404 for „no such exercise"
 * and „not yours" alike (as every route of `/exercises`), 409 for a row that
 * cannot be solved as one move, with the sentence `assignableProblem` gives.
 */
async function attemptOwn(pool, { ownerId, puzzleId, moveSan, msTaken }) {
  if (typeof puzzleId !== 'string' || typeof moveSan !== 'string' || !moveSan.trim()) {
    return { ok: false, status: 400, error: 'A move is required.' };
  }
  const found = await pool.query(
    `SELECT puzzle_id, ${exerciseColumns()}
       FROM custom_puzzles
      WHERE puzzle_id = $1 AND owner_id = $2`,
    [puzzleId, ownerId]
  );
  if (found.rowCount === 0) return { ok: false, status: 404, error: 'No such exercise.' };
  const row = found.rows[0];

  // A bare position, a row still marked for review and a game exercise are
  // all refused here as they are refused as homework: nothing could judge the
  // move, or the move is not what the row asks.
  const problem = assignableProblem(row);
  if (problem) return { ok: false, status: 409, error: `This exercise ${problem}.` };

  const answer = firstMoveOf(row);
  const verdict = judgeAttempt({ fen: row.fen, moveSan, ...(answer || {}) });

  // Written from the server's own verdict, never from anything the client
  // said about it.
  await pool.query(
    `INSERT INTO user_puzzle_attempts (user_id, puzzle_id, source, solved, ms_taken)
     VALUES ($1, $2, $3, $4, $5)`,
    [ownerId, row.puzzle_id, SOURCE, verdict.correct, Number.parseInt(msTaken, 10) || null]
  );

  return {
    ok: true,
    result: {
      correct: verdict.correct,
      reason: verdict.reason,
      playedSan: verdict.playedSan,
      solutionSan: answer ? answer.solutionSan : null,
    },
  };
}

/**
 * What „Solve" on Practise works through: `{ fresh, retry }`, each a list of
 * positions (`present`).
 *
 * - `fresh` — the owner's find exercises that can be solved and have never
 *   been tried alone, oldest first.
 * - `retry` — those whose latest own attempt failed, oldest failure first:
 *   `retryIds`, the fold every other drill's „Retry failed" goes through.
 *
 * A game exercise is in neither: it is played, not answered with a move, and
 * its card is its door (phase 5). An exercise deleted since it was tried
 * leaves its attempts in the log but is not served.
 */
async function queueOf(pool, ownerId) {
  const [exercises, attempts] = await Promise.all([
    pool.query(
      `SELECT ${POSITION_COLUMNS}, ${exerciseColumns()}
         FROM custom_puzzles
        WHERE owner_id = $1
        ORDER BY created_at ASC, puzzle_id ASC`,
      [ownerId]
    ),
    attemptsOf(pool, ownerId),
  ]);

  const solvable = exercises.rows.filter((row) => assignableProblem(row, { as: 'find' }) === null);
  const byId = new Map(solvable.map((row) => [String(row.puzzle_id), row]));
  const tried = new Set(
    attempts.filter((a) => a.source === SOURCE).map((a) => String(a.puzzle_id))
  );

  return {
    fresh: solvable.filter((row) => !tried.has(String(row.puzzle_id))).map(present),
    retry: retryIds(attempts, SOURCE).filter((id) => byId.has(id)).map((id) => present(byId.get(id))),
  };
}

/**
 * One's own game exercise, played to its end (docs/PLAN-MATERIJAL.md,
 * phase 5). The body carries the moves and nothing about who won: the verdict
 * is the server's, from the task — the rules, then a tablebase where the game
 * stopped at its move target — exactly as a homework's game is judged
 * (`recordEngineGameResult`), and through the same two calls.
 *
 * An `own` attempt is logged **only when something judged the game**:
 * - „Play N moves" has no goal, and alone there is no trainer to give one —
 *   „played and nothing more" (decision 4): nothing is written, and nothing
 *   is pending either, because nothing will ever come.
 * - A tablebase that does not answer leaves the game unjudged: nothing is
 *   written, and the answer says `pending` — absence is a third answer.
 *
 * Answers `{ goalMet, judgedBy, pending, ending, outcome }`, the homework
 * route's shape; 404 for „no such exercise" and „not yours" alike, 409 for a
 * row that is not a game to play, 422 for moves that are not a finished game.
 */
async function gameResultOwn(pool, { ownerId, puzzleId, moves, resigned, tablebase }) {
  if (typeof puzzleId !== 'string' || (!Array.isArray(moves) && typeof moves !== 'string')) {
    return { ok: false, status: 400, error: 'The moves are required.' };
  }
  const found = await pool.query(
    `SELECT puzzle_id, ${exerciseColumns()}
       FROM custom_puzzles
      WHERE puzzle_id = $1 AND owner_id = $2`,
    [puzzleId, ownerId]
  );
  if (found.rowCount === 0) return { ok: false, status: 404, error: 'No such exercise.' };
  const row = found.rows[0];

  const problem = assignableProblem(row, { as: 'game' });
  if (problem) return { ok: false, status: 409, error: `This exercise ${problem}.` };

  // The task as the one reader gives it, with the row's position in it; the
  // judge reads the engine-game task, which has no `type`.
  const { type: _game, ...task } = exerciseOf(row).task;
  const verdict = judgeEngineGame({ task, moves, resigned: resigned === true });
  if (!verdict.ok) return { ok: false, status: 422, error: verdict.error };
  if (verdict.ending === null) return { ok: false, status: 422, error: 'The game is not over yet.' };

  let goalMet = verdict.needsTrainer ? null : verdict.goalMet;
  let judgedBy = verdict.needsTrainer ? null : 'rules';
  let pending = false;
  if (verdict.needsTablebase) {
    // Required late, as its home does: the tablebase builds a pacer.
    const { askTablebase, sharedTablebase } = require('./assignmentService');
    const asked = await askTablebase(tablebase ?? sharedTablebase(), { task: verdict.task, fen: verdict.fen });
    goalMet = asked.judged ? asked.goalMet : null;
    judgedBy = asked.judged ? 'tablebase' : null;
    pending = !asked.judged;
  }

  if (judgedBy !== null) {
    await pool.query(
      `INSERT INTO user_puzzle_attempts (user_id, puzzle_id, source, solved)
       VALUES ($1, $2, $3, $4)`,
      [ownerId, row.puzzle_id, SOURCE, goalMet === true]
    );
  }

  return {
    ok: true,
    result: { goalMet, judgedBy, pending, ending: verdict.ending, outcome: verdict.outcome },
  };
}

module.exports = { SOURCE, attemptOwn, queueOf, gameResultOwn };
