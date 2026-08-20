// assignmentService.js
// Homework: a trainer sets work, the student does it, the trainer sees what
// happened.
//
// This is the feature a trainer actually pays for, so two things matter more
// than anywhere else in the codebase: a trainer must never reach a student who
// is not theirs, and progress must reflect what the student really did rather
// than what they claim.

const logger = require('./logger');

/// Where a theme stops being something to work on and starts being a strength.
/// The gap between them is intentional: a child in the middle is neither, and
/// calling them both at once is what made the parent's report meaningless.
const STRONG_THEME_ACCURACY = 70;
const WEAK_THEME_ACCURACY = 50;
const { assignableProblem } = require('./customPuzzleJudge');
const { trainableThemes } = require('./puzzleSelectionService');
const { ensureItem: ensureReviewItem } = require('./spacedRepetitionService');

/// Ceiling on one assignment, so a mis-typed count cannot materialise thousands
/// of rows or hand a child an impossible pile of work.
const MAX_ITEMS = 50;
const DEFAULT_ITEMS = 10;

/// Confirms the student is linked to this trainer *and* agreed to it.
///
/// Every read and write below goes through this. Without it, an assignment id or
/// a student id guessed by hand would expose another trainer's students — and
/// these are mostly children's records.
///
/// The `status` condition is the whole security fix. The row alone proves only
/// that somebody typed an email address: until consent existed, whoever clicked
/// "add student" first became the trainer, so two people who added each other
/// could both set the other homework. An edge is a claim; an accepted edge is a
/// relationship.
async function trainerOwnsStudent(pool, trainerId, studentId) {
  const result = await pool.query(
    `SELECT 1 FROM trainer_students
      WHERE trainer_id = $1 AND student_id = $2 AND status = 'accepted'`,
    [trainerId, studentId]
  );
  return result.rows.length > 0;
}

/// The two people one assignment belongs to, and which of them is asking.
///
/// Homework is read by exactly two accounts — the trainer who set it and the
/// student who got it — so this is the single condition behind everything that
/// reads or writes around one assignment. Returns null for both "no such
/// assignment" and "not yours", so an id guessed by hand cannot be used to find
/// out which assignments exist.
///
/// It deliberately does **not** re-check the relationship. The assignment row is
/// the older fact: a trainer who set homework and was later unlinked must still
/// be able to read what was done, and the student must not lose their own work
/// because an edge changed.
async function assignmentParticipant(pool, assignmentId, userId) {
  const result = await pool.query(
    `SELECT a.*, t.name AS trainer_name, s.name AS student_name
       FROM assignments a
       LEFT JOIN users t ON t.id = a.trainer_id
       LEFT JOIN users s ON s.id = a.student_id
      WHERE a.id = $1 AND (a.trainer_id = $2 OR a.student_id = $2)`,
    [assignmentId, userId]
  );
  if (result.rows.length === 0) return null;

  const assignment = result.rows[0];
  return {
    assignment,
    isTrainer: assignment.trainer_id === userId,
    isStudent: assignment.student_id === userId,
  };
}

/// Picks the puzzles for an assignment.
///
/// Prefers puzzles the student has not already seen: re-issuing something they
/// solved last week measures recall, not skill. Falls back to the full set only
/// if the filters leave nothing, so an assignment is never silently empty.
async function resolvePuzzles(pool, { studentId, themes, minRating, maxRating, count }) {
  const wanted = Math.min(Math.max(count || DEFAULT_ITEMS, 1), MAX_ITEMS);
  const cleanThemes = trainableThemes(themes || []);

  const conditions = ['p.rating BETWEEN $1 AND $2'];
  const params = [minRating || 400, maxRating || 3200];

  if (cleanThemes.length > 0) {
    params.push(cleanThemes);
    // Overlap, not containment: "pin or fork" is what a trainer means when they
    // tick two boxes, not "puzzles that are both at once".
    conditions.push(`p.themes && $${params.length}::varchar[]`);
  }

  params.push(studentId);
  const studentParam = `$${params.length}`;
  params.push(wanted);
  const limitParam = `$${params.length}`;

  const unseen = await pool.query(
    `SELECT p.puzzle_id, p.rating FROM lichess_puzzles p
     WHERE ${conditions.join(' AND ')}
       AND NOT EXISTS (
         SELECT 1 FROM user_puzzle_attempts a
         WHERE a.user_id = ${studentParam} AND a.puzzle_id = p.puzzle_id
       )
     ORDER BY RANDOM()
     LIMIT ${limitParam}`,
    params
  );

  if (unseen.rows.length > 0) return unseen.rows;

  const anyMatch = await pool.query(
    `SELECT p.puzzle_id, p.rating FROM lichess_puzzles p
     WHERE ${conditions.join(' AND ')}
     ORDER BY RANDOM()
     LIMIT ${limitParam}`,
    params
  );
  return anyMatch.rows;
}

/// Creates an assignment and materialises its puzzle list.
async function createPuzzleAssignment(pool, {
  trainerId, studentId, title, instructions, dueAt, themes, minRating, maxRating, count,
}) {
  if (!(await trainerOwnsStudent(pool, trainerId, studentId))) {
    return { ok: false, reason: 'Taj učenik nije na vašoj listi.' };
  }

  const puzzles = await resolvePuzzles(pool, { studentId, themes, minRating, maxRating, count });
  if (puzzles.length === 0) {
    return { ok: false, reason: 'Nema zagonetki koje odgovaraju zadatim kriterijumima.' };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const assignmentRes = await client.query(
      `INSERT INTO assignments
         (trainer_id, student_id, title, instructions, kind, themes, min_rating, max_rating, due_at)
       VALUES ($1, $2, $3, $4, 'puzzles', $5, $6, $7, $8)
       RETURNING *`,
      [
        trainerId, studentId, title, instructions || null,
        trainableThemes(themes || []), minRating || null, maxRating || null, dueAt || null,
      ]
    );
    const assignment = assignmentRes.rows[0];

    const values = [];
    const tuples = puzzles.map((puzzle, index) => {
      const base = index * 4;
      values.push(assignment.id, puzzle.puzzle_id, index, puzzle.rating);
      return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4})`;
    });

    await client.query(
      `INSERT INTO assignment_items (assignment_id, puzzle_id, position, puzzle_rating)
       VALUES ${tuples.join(', ')}`,
      values
    );

    await client.query('COMMIT');
    logger.info(
      { trainerId, studentId, assignmentId: assignment.id, items: puzzles.length },
      'Assignment created'
    );
    return { ok: true, assignment: { ...assignment, itemCount: puzzles.length } };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Reads a lesson the trainer is allowed to assign, with its steps.
///
/// A lesson saved as a single position has no `position_list`; it is treated as
/// a one-step lesson so both shapes assign the same way.
async function loadAssignableLesson(pool, trainerId, lessonId) {
  const result = await pool.query(
    `SELECT id, title, fen, pgn, position_list
     FROM saved_lessons
     WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
    [lessonId, trainerId]
  );
  if (result.rows.length === 0) return null;

  const lesson = result.rows[0];
  const raw = lesson.position_list;
  const list = Array.isArray(raw) ? raw : (typeof raw === 'string' ? JSON.parse(raw) : null);

  const steps = list && list.length > 0
    ? list
    : [{ title: lesson.title, fen: lesson.fen, pgn: lesson.pgn }];

  return { ...lesson, steps };
}

/// Assigns one of the trainer's own lessons as homework.
///
/// The steps are copied into assignment_items at creation time, like puzzles
/// are: if the trainer later edits the lesson, the assignment still records what
/// was actually set, and a step count that shifts underneath a half-finished
/// assignment would make progress meaningless.
async function createLessonAssignment(pool, {
  trainerId, studentId, lessonId, title, instructions, dueAt,
}) {
  if (!(await trainerOwnsStudent(pool, trainerId, studentId))) {
    return { ok: false, reason: 'Taj učenik nije na vašoj listi.' };
  }

  const lesson = await loadAssignableLesson(pool, trainerId, lessonId);
  if (!lesson) {
    return { ok: false, reason: 'Lekcija nije pronađena ili nije vaša.' };
  }
  if (lesson.steps.length === 0) {
    return { ok: false, reason: 'Lekcija nema nijedan korak.' };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const assignmentRes = await client.query(
      `INSERT INTO assignments
         (trainer_id, student_id, title, instructions, kind, lesson_id, due_at)
       VALUES ($1, $2, $3, $4, 'lesson', $5, $6)
       RETURNING *`,
      [trainerId, studentId, title || lesson.title, instructions || null, lessonId, dueAt || null]
    );
    const assignment = assignmentRes.rows[0];

    const values = [];
    const tuples = lesson.steps.map((_, index) => {
      const base = index * 2;
      values.push(assignment.id, index);
      return `($${base + 1}, $${base + 2})`;
    });

    await client.query(
      `INSERT INTO assignment_items (assignment_id, position) VALUES ${tuples.join(', ')}`,
      values
    );

    await client.query('COMMIT');
    logger.info(
      { trainerId, studentId, assignmentId: assignment.id, lessonId, steps: lesson.steps.length },
      'Lesson assignment created'
    );
    return { ok: true, assignment: { ...assignment, itemCount: lesson.steps.length } };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Marks one step of a lesson assignment as reviewed.
///
/// `solved` stays null: stepping through a lesson has no right answer, and
/// recording it as "solved" would feed a meaningless accuracy figure into the
/// student's report.
async function markLessonStepDone(pool, { studentId, assignmentId, position }) {
  const result = await pool.query(
    `UPDATE assignment_items ai
     SET attempted_at = CURRENT_TIMESTAMP
     FROM assignments a
     WHERE ai.assignment_id = a.id
       AND a.id = $1
       AND a.student_id = $2
       AND a.kind = 'lesson'
       AND ai.position = $3
       AND ai.attempted_at IS NULL
     RETURNING ai.id, a.lesson_id`,
    [assignmentId, studentId, position]
  );

  if (result.rows.length === 0) return false;

  // Reading a step enrols it for review. Without this the schedule would only
  // ever fill from grading, and nothing would be there to grade — the student
  // would have to seek out a review session for material it does not yet hold.
  const lessonId = result.rows[0].lesson_id;
  if (lessonId) {
    try {
      await ensureReviewItem(pool, { userId: studentId, lessonId, position });
    } catch (err) {
      // Enrolment is a bonus on top of marking homework; failing it must not
      // undo the step the student just completed.
      logger.error({ studentId, lessonId, position }, `Review enrolment failed: ${err.message}`);
    }
  }

  await pool.query(
    `UPDATE assignments SET completed_at = CURRENT_TIMESTAMP
     WHERE id = $1 AND completed_at IS NULL
       AND NOT EXISTS (
         SELECT 1 FROM assignment_items
         WHERE assignment_id = $1 AND attempted_at IS NULL
       )`,
    [assignmentId]
  );
  return true;
}

/// Marks any pending assignment item for this puzzle as done.
///
/// Called from the puzzle attempt route rather than from a separate "submit
/// homework" action: the student solves puzzles the same way whether they were
/// assigned or not, and asking them to remember which is which would guarantee
/// half the homework never gets marked.
///
/// Only the *first* attempt counts. Letting a retry overwrite a failure would
/// turn the report into a record of persistence rather than of ability.
///
/// `playedSan` is the move the student actually made, where the caller knows
/// it. It is optional because not every path does: a Lichess attempt reports
/// only whether it was solved, and that stays NULL rather than being guessed.
async function recordPuzzleResult(pool, { studentId, puzzleId, solved, msTaken, playedSan }) {
  try {
    const result = await pool.query(
      `UPDATE assignment_items ai
       SET solved = $1, ms_taken = $2, played_san = $5, attempted_at = CURRENT_TIMESTAMP
       FROM assignments a
       WHERE ai.assignment_id = a.id
         AND a.student_id = $3
         AND ai.puzzle_id = $4
         AND ai.attempted_at IS NULL
       RETURNING ai.assignment_id`,
      [
        solved,
        Number.isInteger(msTaken) ? msTaken : null,
        studentId,
        puzzleId,
        typeof playedSan === 'string' && playedSan.trim() !== '' ? playedSan.trim().slice(0, 20) : null,
      ]
    );

    // Stamp any assignment whose last item just landed.
    for (const row of result.rows) {
      await pool.query(
        `UPDATE assignments SET completed_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND completed_at IS NULL
           AND NOT EXISTS (
             SELECT 1 FROM assignment_items
             WHERE assignment_id = $1 AND attempted_at IS NULL
           )`,
        [row.assignment_id]
      );
    }

    return result.rows.length;
  } catch (err) {
    // Homework bookkeeping must never fail the puzzle the student just solved.
    logger.error({ studentId, puzzleId }, `Failed to record assignment result: ${err.message}`);
    return 0;
  }
}

/// Sets homework from positions the trainer scanned or typed themselves.
///
/// Unlike the Lichess flow this takes an explicit list rather than a query: the
/// trainer has already chosen these, one by one, off their own screen. The set
/// is resolved at creation like every other assignment, so the trainer knows
/// exactly what they gave.
///
/// Two kinds of position are refused rather than quietly skipped — one with no
/// solution cannot be judged, and one still marked for review is a doubt we
/// already hold. Homework in front of a child is the wrong place for either.
async function createCustomAssignment(pool, {
  trainerId, studentId, title, instructions, dueAt, puzzleIds,
}) {
  if (!(await trainerOwnsStudent(pool, trainerId, studentId))) {
    return { ok: false, reason: 'Taj učenik nije na vašoj listi.' };
  }
  const ids = Array.isArray(puzzleIds) ? puzzleIds.filter((id) => typeof id === 'string') : [];
  if (ids.length === 0) {
    return { ok: false, reason: 'Nije izabrana nijedna pozicija.' };
  }

  // Owner-scoped in the query: a trainer can only set their own positions, and
  // an id belonging to someone else simply does not come back.
  const found = await pool.query(
    `SELECT puzzle_id, solution_san, needs_review FROM custom_puzzles
      WHERE owner_id = $1 AND puzzle_id = ANY($2::varchar[])`,
    [trainerId, ids]
  );
  const byId = new Map(found.rows.map((row) => [row.puzzle_id, row]));

  const usable = [];
  const refused = [];
  for (const id of ids) {
    const row = byId.get(id);
    if (!row) {
      refused.push({ puzzleId: id, reason: 'nije vaša pozicija' });
      continue;
    }
    const problem = assignableProblem(row);
    if (problem) {
      refused.push({ puzzleId: id, reason: problem });
      continue;
    }
    usable.push(id);
  }

  if (usable.length === 0) {
    return { ok: false, reason: 'Nijedna izabrana pozicija ne može da se zada.', refused };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const assignmentRes = await client.query(
      `INSERT INTO assignments (trainer_id, student_id, title, instructions, kind, due_at)
       VALUES ($1, $2, $3, $4, 'puzzles', $5)
       RETURNING *`,
      [trainerId, studentId, title, instructions || null, dueAt || null]
    );
    const assignment = assignmentRes.rows[0];

    const values = [];
    const tuples = usable.map((id, index) => {
      const base = index * 3;
      values.push(assignment.id, id, index);
      return `($${base + 1}, $${base + 2}, $${base + 3})`;
    });
    await client.query(
      `INSERT INTO assignment_items (assignment_id, puzzle_id, position) VALUES ${tuples.join(', ')}`,
      values
    );

    await client.query('COMMIT');
    logger.info(
      { trainerId, studentId, assignmentId: assignment.id, items: usable.length, refused: refused.length },
      'Custom assignment created'
    );
    return { ok: true, assignment, refused };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

const PROGRESS_COLUMNS = `
  a.*,
  COUNT(ai.id)::int AS total_items,
  COUNT(ai.attempted_at)::int AS attempted_items,
  COUNT(*) FILTER (WHERE ai.solved)::int AS solved_items
`;

/// Everything a student needs to see their own homework.
async function getStudentAssignments(pool, studentId) {
  const result = await pool.query(
    `SELECT ${PROGRESS_COLUMNS}, u.name AS trainer_name
     FROM assignments a
     LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
     LEFT JOIN users u ON u.id = a.trainer_id
     WHERE a.student_id = $1
     GROUP BY a.id, u.name
     ORDER BY a.completed_at NULLS FIRST, a.due_at NULLS LAST, a.created_at DESC`,
    [studentId]
  );
  return result.rows;
}

/// Everything a trainer set, with how far each student has got.
async function getTrainerAssignments(pool, trainerId, { studentId = null } = {}) {
  const params = [trainerId];
  let filter = '';
  if (studentId) {
    params.push(studentId);
    filter = `AND a.student_id = $${params.length}`;
  }

  const result = await pool.query(
    `SELECT ${PROGRESS_COLUMNS}, u.name AS student_name, u.email AS student_email
     FROM assignments a
     LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
     LEFT JOIN users u ON u.id = a.student_id
     WHERE a.trainer_id = $1 ${filter}
     GROUP BY a.id, u.name, u.email
     ORDER BY a.created_at DESC`,
    params
  );
  return result.rows;
}

async function getAssignmentDetail(pool, assignmentId, userId) {
  const result = await pool.query(
    `SELECT a.*, t.name AS trainer_name, s.name AS student_name
     FROM assignments a
     LEFT JOIN users t ON t.id = a.trainer_id
     LEFT JOIN users s ON s.id = a.student_id
     WHERE a.id = $1 AND (a.trainer_id = $2 OR a.student_id = $2)`,
    [assignmentId, userId]
  );
  if (result.rows.length === 0) return null;

  const assignment = result.rows[0];
  const items = await pool.query(
    `SELECT puzzle_id, position, puzzle_rating, solved, ms_taken, played_san, attempted_at
     FROM assignment_items WHERE assignment_id = $1 ORDER BY position`,
    [assignmentId]
  );

  // A lesson assignment carries its board positions inline, so the student's
  // viewer needs one request rather than a second lookup against a lesson they
  // may not otherwise be allowed to read.
  let steps = null;
  if (assignment.kind === 'lesson' && assignment.lesson_id) {
    const lessonRes = await pool.query(
      'SELECT title, fen, pgn, position_list FROM saved_lessons WHERE id = $1',
      [assignment.lesson_id]
    );
    const lesson = lessonRes.rows[0];
    if (lesson) {
      const raw = lesson.position_list;
      const list = Array.isArray(raw) ? raw : (typeof raw === 'string' ? JSON.parse(raw) : null);
      steps = list && list.length > 0
        ? list
        : [{ title: lesson.title, fen: lesson.fen, pgn: lesson.pgn }];
    }
  }

  // Positions the trainer scanned travel with the assignment, exactly as lesson
  // steps do, so the student's solver needs one request rather than a lookup
  // against a table they are not allowed to read.
  //
  // The solution is deliberately absent. It is the answer to the question being
  // asked, and it stays on the server until the student has actually answered.
  let customPositions = null;
  const customIds = items.rows
    .map((item) => item.puzzle_id)
    .filter((id) => typeof id === 'string' && id.startsWith('cust_'));
  if (customIds.length > 0) {
    const positions = await pool.query(
      `SELECT puzzle_id, fen, side_to_move, instruction, themes, source_title, source_page, source_label
         FROM custom_puzzles WHERE puzzle_id = ANY($1::varchar[])`,
      [customIds]
    );
    customPositions = positions.rows;
  }

  return { ...assignment, items: items.rows, steps, customPositions };
}

/// Turns raw attempt rows into the summary a trainer reads.
///
/// Pure so the arithmetic is testable: accuracy that silently divides by zero,
/// or a "weakest motif" drawn from two attempts, is exactly the kind of number
/// that gets repeated to a parent.
function summariseAttempts(rows, { minAttemptsPerTheme = 4 } = {}) {
  const total = rows.length;
  const solved = rows.filter((row) => row.solved).length;

  const byTheme = new Map();
  for (const row of rows) {
    for (const theme of row.themes || []) {
      if (!byTheme.has(theme)) byTheme.set(theme, { theme, attempts: 0, solved: 0 });
      const entry = byTheme.get(theme);
      entry.attempts++;
      if (row.solved) entry.solved++;
    }
  }

  const themes = [...byTheme.values()].map((entry) => ({
    ...entry,
    accuracy: entry.attempts === 0 ? null : Math.round((entry.solved / entry.attempts) * 100),
  }));

  // Only themes with enough attempts can be called a weakness; the rest are
  // simply unmeasured, and saying otherwise would misinform the trainer.
  const measured = themes.filter((entry) => entry.attempts >= minAttemptsPerTheme);
  measured.sort((a, b) => a.accuracy - b.accuracy);

  // Split by how the child is actually doing, not by position in a sorted list.
  //
  // Taking the first five and the last five put every theme in *both* lists
  // whenever fewer than six were measured — so a parent's report announced 25%
  // under "what is going well" and 70% under "what we work on next", the same
  // two lines twice, which is worse than saying nothing.
  //
  // A theme now has to earn its place, and can only be in one: clearly solid,
  // clearly not, or neither. The middle band is deliberately left out of both —
  // "you get about two thirds of these right" is not a headline in either
  // direction, and it still appears in the full per-theme list.
  const strongestThemes = measured
    .filter((entry) => entry.accuracy >= STRONG_THEME_ACCURACY)
    .sort((a, b) => b.accuracy - a.accuracy)
    .slice(0, 5);
  const weakestThemes = measured
    .filter((entry) => entry.accuracy < WEAK_THEME_ACCURACY)
    .sort((a, b) => a.accuracy - b.accuracy)
    .slice(0, 5);

  return {
    totalAttempts: total,
    solvedAttempts: solved,
    accuracy: total === 0 ? null : Math.round((solved / total) * 100),
    themes: themes.sort((a, b) => b.attempts - a.attempts),
    weakestThemes,
    strongestThemes,
  };
}

/// A student's report, readable by the student themselves or by their trainer.
async function getStudentProgress(pool, studentId, { days = 30 } = {}) {
  const [attemptRes, ratingRes, assignmentRes] = await Promise.all([
    pool.query(
      `SELECT solved, themes, puzzle_rating, rating_before, rating_after, created_at
       FROM user_puzzle_attempts
       WHERE user_id = $1 AND created_at >= CURRENT_TIMESTAMP - ($2 || ' days')::interval
       ORDER BY created_at DESC`,
      [studentId, days]
    ),
    pool.query(
      'SELECT overall_rating, theme_ratings, puzzles_solved, puzzles_failed FROM user_puzzle_ratings WHERE user_id = $1',
      [studentId]
    ),
    pool.query(
      `SELECT
         COUNT(*)::int AS total,
         COUNT(completed_at)::int AS completed,
         COUNT(*) FILTER (WHERE completed_at IS NULL AND due_at < CURRENT_TIMESTAMP)::int AS overdue
       FROM assignments WHERE student_id = $1`,
      [studentId]
    ),
  ]);

  const summary = summariseAttempts(attemptRes.rows);
  const activeDays = new Set(
    attemptRes.rows.map((row) => new Date(row.created_at).toISOString().slice(0, 10))
  ).size;

  // Movement across the period, from the attempts themselves. The rows come
  // back newest-first, so the oldest one holds where the student started.
  // Null when there is nothing in the window — a parent report must not show
  // "+0" where the honest answer is "no data".
  const oldest = attemptRes.rows[attemptRes.rows.length - 1];
  const newest = attemptRes.rows[0];
  const ratingChange =
    oldest && newest && oldest.rating_before !== null && newest.rating_after !== null
      ? newest.rating_after - oldest.rating_before
      : null;

  return {
    periodDays: days,
    overallRating: ratingRes.rows[0]?.overall_rating || 1500,
    ratingChange,
    themeRatings: ratingRes.rows[0]?.theme_ratings || {},
    lifetimeSolved: ratingRes.rows[0]?.puzzles_solved || 0,
    lifetimeFailed: ratingRes.rows[0]?.puzzles_failed || 0,
    activeDays,
    assignments: assignmentRes.rows[0],
    ...summary,
  };
}

module.exports = {
  MAX_ITEMS,
  DEFAULT_ITEMS,
  trainerOwnsStudent,
  assignmentParticipant,
  resolvePuzzles,
  createPuzzleAssignment,
  createCustomAssignment,
  loadAssignableLesson,
  createLessonAssignment,
  markLessonStepDone,
  recordPuzzleResult,
  getStudentAssignments,
  getTrainerAssignments,
  getAssignmentDetail,
  summariseAttempts,
  getStudentProgress,
};
