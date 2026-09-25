// assignmentService.js
// Homework: a trainer sets work, the student does it, the trainer sees what
// happened.
//
// This is the feature a trainer actually pays for, so two things matter more
// than anywhere else in the codebase: a trainer must never reach a student who
// is not theirs, and progress must reflect what the student really did rather
// than what they claim.

const logger = require('./logger');
const { notify } = require('./notifications');

/// Where a theme stops being something to work on and starts being a strength.
/// The gap between them is intentional: a child in the middle is neither, and
/// calling them both at once is what made the parent's report meaningless.
const STRONG_THEME_ACCURACY = 70;
const WEAK_THEME_ACCURACY = 50;
const { assignableProblem, exerciseColumns } = require('./exercise');
const { trainableThemes } = require('./puzzleSelectionService');
const { filmColumns, filmOf, filmFacts, noFilmReason } = require('./tutorialFilm');
const homework = require('./homeworkService');
const { judgeEngineGame, goalMetByTablebase } = require('./engineGameTask');

/// Refuses a write into a homework item that is still locked. Interpolated
/// into every UPDATE a student's answer goes through, so the gate holds at
/// the moment of writing and not only on the screen (homeworkService.js).
const NOT_LOCKED = `NOT ${homework.childLockedSql('a')}`;

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

/// Keeps only what a move can be made of.
///
/// The custom path builds this itself from `chess.js`, so it arrives clean. The
/// puzzle path takes it from the client — which already decides `solved` there,
/// so the move is trusted no further than the verdict it comes with. Stripping
/// anything that cannot appear in notation costs nothing and keeps whatever
/// arrives from ending up on a trainer's screen as-is.
function cleanSan(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().replace(/[^KQRBNOa-h1-8x=+#-]/g, '');
  return trimmed === '' ? null : trimmed.slice(0, 20);
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
  const filters = [minRating || 400, maxRating || 3200];

  if (cleanThemes.length > 0) {
    filters.push(cleanThemes);
    // Overlap, not containment: "pin or fork" is what a trainer means when they
    // tick two boxes, not "puzzles that are both at once".
    conditions.push(`p.themes && $${filters.length}::varchar[]`);
  }

  // The two queries below take different parameter lists, and that is the
  // point of building them apart. They used to share one: the fallback drops
  // the `NOT EXISTS`, so the student's id it still carried was a parameter
  // nothing referenced, and PostgreSQL cannot type one of those - "could not
  // determine data type of parameter $4". It fired only when the first query
  // came back empty, which is exactly what the fallback is for: a filter that
  // matches nothing answered 500 instead of "no puzzles match". Found
  // 17.9.2026 while sending a homework whose puzzle set was deliberately
  // impossible; no stub-pool test could have seen it.
  const unseenParams = [...filters, studentId, wanted];
  const studentParam = `$${filters.length + 1}`;
  const limitParam = `$${filters.length + 2}`;

  const unseen = await pool.query(
    `SELECT p.puzzle_id, p.rating FROM lichess_puzzles p
     WHERE ${conditions.join(' AND ')}
       AND NOT EXISTS (
         SELECT 1 FROM user_puzzle_attempts a
         WHERE a.user_id = ${studentParam} AND a.puzzle_id = p.puzzle_id
       )
     ORDER BY RANDOM()
     LIMIT ${limitParam}`,
    unseenParams
  );

  if (unseen.rows.length > 0) return unseen.rows;

  const anyMatch = await pool.query(
    `SELECT p.puzzle_id, p.rating FROM lichess_puzzles p
     WHERE ${conditions.join(' AND ')}
     ORDER BY RANDOM()
     LIMIT $${filters.length + 1}`,
    [...filters, wanted]
  );
  return anyMatch.rows;
}

/// Creates an assignment and materialises its puzzle list.
async function createPuzzleAssignment(pool, {
  trainerId, studentId, title, instructions, dueAt, themes, minRating, maxRating, count,
}) {
  if (!(await trainerOwnsStudent(pool, trainerId, studentId))) {
    return { ok: false, reason: 'That student is not on your list.' };
  }

  const puzzles = await resolvePuzzles(pool, { studentId, themes, minRating, maxRating, count });
  if (puzzles.length === 0) {
    return { ok: false, reason: 'No puzzles match the specified criteria.' };
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

/// Reads a tutorial the trainer is allowed to send, with its film.
///
/// `film` is null when there is none to give — never rendered, or its file is
/// gone. docs/PLAN-TUTORIJAL-VIDEO.md: a tutorial reaches a student only as its
/// film, so every door that sends one asks this first.
async function loadAssignableLesson(pool, trainerId, lessonId) {
  const result = await pool.query(
    `SELECT id, title, ${filmColumns()}
     FROM saved_lessons
     WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
    [lessonId, trainerId]
  );
  if (result.rows.length === 0) return null;

  const lesson = result.rows[0];
  return { id: lesson.id, title: lesson.title, film: filmOf(lesson) };
}

/// Sends one of the trainer's own tutorials — its film — to a student.
///
/// **One item, not one per part** (docs/PLAN-TUTORIJAL-VIDEO.md, phase 2): the
/// student has one thing to do, download the film, and the item's
/// `attempted_at` is the moment they did. The film is the tutorial's current
/// one (plan D1); a tutorial without a film is refused (D5).
async function createLessonAssignment(pool, {
  trainerId, studentId, lessonId, title, instructions, dueAt,
}) {
  if (!(await trainerOwnsStudent(pool, trainerId, studentId))) {
    return { ok: false, reason: 'That student is not on your list.' };
  }

  const lesson = await loadAssignableLesson(pool, trainerId, lessonId);
  if (!lesson) {
    return { ok: false, reason: 'Tutorial not found or is not yours.' };
  }
  if (!lesson.film) {
    return { ok: false, status: 422, reason: noFilmReason(lesson.title) };
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

    await client.query(
      'INSERT INTO assignment_items (assignment_id, position) VALUES ($1, 0)',
      [assignment.id]
    );

    await client.query('COMMIT');
    logger.info(
      { trainerId, studentId, assignmentId: assignment.id, lessonId },
      'Tutorial video sent'
    );
    return { ok: true, assignment: { ...assignment, itemCount: 1 } };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// The film of a student's own tutorial assignment, or null when [assignmentId]
/// is not a tutorial assignment of [studentId]'s. `film` inside is null when
/// the tutorial is gone or has no film on disk.
///
/// One query answers both „is this yours" and „which file": the link route and
/// the download route must never disagree about either.
async function videoOfAssignment(pool, { assignmentId, studentId }) {
  const result = await pool.query(
    `SELECT a.id, a.title, ${filmColumns('l')}
       FROM assignments a
       LEFT JOIN saved_lessons l ON l.id = a.lesson_id
      WHERE a.id = $1 AND a.student_id = $2 AND a.kind = 'lesson'`,
    [assignmentId, studentId]
  );
  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return { assignmentId: row.id, title: row.title, film: filmOf(row) };
}

/// Records that the student downloaded their tutorial's film — the first time
/// only (plan D3), which is also the moment the assignment is done.
///
/// Called by the download route once the file's last byte has gone out; the
/// route decides *that*, this writes it. Returns whether anything was written:
/// a second download, somebody else's assignment and a locked item all write
/// nothing.
async function recordVideoDownload(pool, { studentId, assignmentId }) {
  const result = await pool.query(
    `UPDATE assignment_items ai
     SET attempted_at = CURRENT_TIMESTAMP
     FROM assignments a
     WHERE ai.assignment_id = a.id
       AND a.id = $1
       AND a.student_id = $2
       AND a.kind = 'lesson'
       AND ai.attempted_at IS NULL
       AND ${NOT_LOCKED}
     RETURNING ai.id`,
    [assignmentId, studentId]
  );
  if (result.rows.length === 0) return false;
  await markCompleteIfDone(pool, assignmentId);
  return true;
}

/// Stamps an assignment as finished the moment its last item lands, and tells
/// the trainer — who otherwise had to keep opening the list to find out.
///
/// `completed_at IS NULL` in the UPDATE is what makes "once" true: re-walking a
/// finished lesson or re-solving a puzzle updates no row, so no second notice
/// goes out. The student's name comes back from the same statement rather than
/// from a second query, which would see a different instant.
async function markCompleteIfDone(pool, assignmentId) {
  // `kind <> 'homework'`: a sent homework has no items of its own, so the
  // NOT EXISTS below would be vacuously true and stamp it complete the first
  // time anything asked. Its completion is its children's, and is decided in
  // homeworkService.markHomeworkCompleteIfDone.
  const done = await pool.query(
    `WITH finished AS (
       UPDATE assignments SET completed_at = CURRENT_TIMESTAMP
        WHERE id = $1 AND completed_at IS NULL AND kind <> 'homework'
          AND NOT EXISTS (
            SELECT 1 FROM assignment_items
            WHERE assignment_id = $1 AND attempted_at IS NULL
          )
       RETURNING id, trainer_id, student_id, title, parent_id, kind
     )
     SELECT f.id, f.trainer_id, f.title, f.parent_id, f.kind, u.name AS student_name
       FROM finished f LEFT JOIN users u ON u.id = f.student_id`,
    [assignmentId]
  );
  if (done.rows.length === 0) return null;

  const row = done.rows[0];
  // An item of a homework tells nobody on its own — five notices for one
  // homework is noise the trainer learns to ignore. The homework tells them
  // once, when its last item lands.
  if (row.parent_id) {
    await homework.markHomeworkCompleteIfDone(pool, row.parent_id);
    return row;
  }
  // A tutorial is done when its film is downloaded, and that is all the
  // trainer can be told — never that it was watched (plan D3).
  const video = row.kind === 'lesson';
  await notify(pool, {
    recipientId: row.trainer_id,
    senderId: row.student_id,
    title: video ? 'Video downloaded' : 'Assignment completed',
    message: video
      ? `${row.student_name || 'Student'} downloaded the video: ${row.title}`
      : `${row.student_name || 'Student'} completed the assignment: ${row.title}`,
    kind: 'assignment_done',
    refId: row.id,
  });
  return row;
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
/// `playedSan` is what the student tried, where the caller knows it. Optional,
/// because not every path has something to say: a puzzle solved at the first
/// attempt has no wrong move to report, and that is not the same as "unknown".
///
/// The two paths mean slightly different things by it, and both are honest:
/// homework from the trainer's own positions is answered once, so it is *the*
/// move; a Lichess puzzle refuses a wrong move and lets the user try again, so
/// it is the **first wrong** one — what they thought before they found it.
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
         AND ${NOT_LOCKED}
       RETURNING ai.assignment_id`,
      [
        solved,
        Number.isInteger(msTaken) ? msTaken : null,
        studentId,
        puzzleId,
        cleanSan(playedSan),
      ]
    );

    // Stamp any assignment whose last item just landed.
    for (const row of result.rows) {
      await markCompleteIfDone(pool, row.assignment_id);
    }

    return result.rows.length;
  } catch (err) {
    // Homework bookkeeping must never fail the puzzle the student just solved.
    logger.error({ studentId, puzzleId }, `Failed to record assignment result: ${err.message}`);
    return 0;
  }
}

/// Records a „play it out" game the student has finished against the engine.
///
/// The moves are judged here, from the task, and not taken on trust: the app
/// plays the game on its own board and has to decide there when it is over,
/// but „the goal was met" arriving from a student's device would be the client
/// marking its own work — which no other answer in this app does.
///
/// Refuses rather than records: a game that is not over yet, a move the
/// position cannot play, an item already answered. Only the first attempt
/// counts, the same rule as every other item.
/// What the tablebase says of the position a game reached — or that it said
/// nothing.
///
/// Three answers, and the third is the point: `{ judged: false }` is „the
/// tablebase did not answer", which is not „the goal was missed". Only
/// `TablebaseUnavailable` is that answer; anything else is a fault and is
/// thrown, because swallowing it would turn a bug into a homework that waits
/// for ever.
async function askTablebase(tablebase, { task, fen }) {
  const { wdlOf, TablebaseUnavailable } = require('./tablebaseService');
  try {
    // A caller with a student waiting does not queue behind a block.
    if (typeof tablebase.blockedForMs === 'function' && tablebase.blockedForMs() > 0) {
      return { judged: false };
    }
    const probed = await tablebase.probe(fen);
    return { judged: true, goalMet: goalMetByTablebase({ task, fen, category: probed.category, wdlOf }) };
  } catch (err) {
    if (err instanceof TablebaseUnavailable) {
      logger.warn(`[GAME] Tablebase gave no verdict, the game waits: ${err.message}`);
      return { judged: false };
    }
    throw err;
  }
}

/// The shared tablebase, required late: importing it builds a pacer, and most
/// callers of this file never judge a game.
function sharedTablebase() {
  return require('./tablebaseService').tablebase;
}

async function recordEngineGameResult(pool, {
  studentId, assignmentId, moves, resigned = false, tablebase = sharedTablebase(),
}) {
  const found = await pool.query(
    `SELECT a.id, a.task
       FROM assignments a
      WHERE a.id = $1 AND a.student_id = $2 AND a.kind = 'engine_game'
        AND ${NOT_LOCKED}`,
    [assignmentId, studentId]
  );
  if (found.rows.length === 0) return { ok: false, status: 404, error: 'That game is not yours to play.' };

  const verdict = judgeEngineGame({ task: found.rows[0].task, moves, resigned });
  if (!verdict.ok) return { ok: false, status: 422, error: verdict.error };
  if (verdict.ending === null) {
    return { ok: false, status: 422, error: 'The game is not over yet.' };
  }

  // A game that stopped at its move target is judged by the position it
  // reached, when a tablebase can say what that is. When it cannot be asked
  // the game is still recorded — played, attempted for the gate — with no
  // verdict, and `judgePendingGames` asks again on a later read.
  //
  // A game with no goal is recorded the same way — played, no verdict — and
  // waits for the trainer (`recordTrainerVerdict`), not for a tablebase.
  let goalMet = verdict.goalMet;
  let judgedBy = verdict.needsTrainer ? null : 'rules';
  if (verdict.needsTablebase) {
    const asked = await askTablebase(tablebase, { task: verdict.task, fen: verdict.fen });
    goalMet = asked.judged ? asked.goalMet : null;
    judgedBy = asked.judged ? 'tablebase' : null;
  }

  const written = await pool.query(
    `UPDATE assignment_items
        SET solved = $2,
            attempted_at = CURRENT_TIMESTAMP,
            game_moves = $3,
            game_ending = $4,
            judged_by = $5
      WHERE assignment_id = $1 AND attempted_at IS NULL
      RETURNING id`,
    [assignmentId, goalMet, verdict.moves.join(' '), verdict.ending, judgedBy]
  );
  if (written.rows.length === 0) {
    return { ok: false, status: 409, error: 'This game has already been played.' };
  }

  await markCompleteIfDone(pool, assignmentId);
  return {
    ok: true,
    goalMet,
    judgedBy,
    pending: judgedBy === null,
    ending: verdict.ending,
    outcome: verdict.outcome,
    ownMoves: verdict.ownMoves,
  };
}

/// The trainer's own verdict on a played game (`docs/PLAN-EXERCISE.md`, phase
/// 15): „Play N moves", which has no other judge, and any game the tablebase
/// never answered — the judge of last resort phase 9 named and gave no button.
///
/// One `UPDATE`, so there is no moment between the check and the write. It
/// writes only where the game was **played**, is the trainer's **own**
/// assignment, and carries **no verdict but the trainer's**: what the rules or
/// a tablebase said is not an opinion to overrule. Which of those failed is
/// asked only afterwards, to choose between 404 and 409.
async function recordTrainerVerdict(pool, { trainerId, assignmentId, met }) {
  const found = await pool.query(
    `SELECT a.student_id FROM assignments a
      WHERE a.id = $1 AND a.trainer_id = $2 AND a.kind = 'engine_game'`,
    [assignmentId, trainerId]
  );
  if (found.rows.length === 0 || !(await trainerOwnsStudent(pool, trainerId, found.rows[0].student_id))) {
    return { ok: false, status: 404, error: 'There is no game of yours to judge here.' };
  }
  const written = await pool.query(
    `UPDATE assignment_items
        SET solved = $2, judged_by = 'trainer'
      WHERE assignment_id = $1
        AND attempted_at IS NOT NULL AND game_ending IS NOT NULL
        AND (judged_by IS NULL OR judged_by = 'trainer')
      RETURNING id`,
    [assignmentId, met]
  );
  if (written.rows.length > 0) {
    return { ok: true, goalMet: met, judgedBy: 'trainer', pending: false };
  }
  const played = await pool.query(
    `SELECT 1 FROM assignment_items
      WHERE assignment_id = $1 AND attempted_at IS NOT NULL AND game_ending IS NOT NULL`,
    [assignmentId]
  );
  return played.rows.length === 0
    ? { ok: false, status: 404, error: 'There is no game of yours to judge here.' }
    : { ok: false, status: 409, error: 'This game has been judged already, and not by you.' };
}

/// Games that were played and not judged, under [assignmentId] — itself, or
/// its children when it is a homework — asked again.
///
/// Called on a read by either side. **Best effort and silent about it**: a
/// tablebase that still does not answer leaves the row exactly as it was, and
/// the read goes on; this must never be able to fail the screen it is called
/// from. The verdict is re-derived from the stored moves, not from a position
/// kept beside them — the moves are the record.
async function judgePendingGames(pool, { assignmentId, tablebase = sharedTablebase() }) {
  const pending = await pool.query(
    `SELECT ai.id, ai.game_moves, a.task
       FROM assignment_items ai
       JOIN assignments a ON a.id = ai.assignment_id
      WHERE (a.id = $1 OR a.parent_id = $1)
        AND a.kind = 'engine_game'
        AND ai.attempted_at IS NOT NULL
        AND ai.judged_by IS NULL
        AND ai.solved IS NULL
        AND ai.game_ending = 'moveTarget'`,
    [assignmentId]
  );
  let judged = 0;
  for (const row of pending.rows) {
    const verdict = judgeEngineGame({ task: row.task, moves: row.game_moves || '' });
    if (!verdict.ok || !verdict.needsTablebase) continue;
    // eslint-disable-next-line no-await-in-loop
    const asked = await askTablebase(tablebase, { task: verdict.task, fen: verdict.fen });
    if (!asked.judged) continue;
    // eslint-disable-next-line no-await-in-loop
    const written = await pool.query(
      `UPDATE assignment_items SET solved = $2, judged_by = 'tablebase'
        WHERE id = $1 AND judged_by IS NULL`,
      [row.id, asked.goalMet]
    );
    judged += written.rowCount;
  }
  return judged;
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
    return { ok: false, reason: 'That student is not on your list.' };
  }
  const ids = Array.isArray(puzzleIds) ? puzzleIds.filter((id) => typeof id === 'string') : [];
  if (ids.length === 0) {
    return { ok: false, reason: 'No positions selected.' };
  }

  // Owner-scoped in the query: a trainer can only set their own positions, and
  // an id belonging to someone else simply does not come back.
  const found = await pool.query(
    `SELECT puzzle_id, ${exerciseColumns()} FROM custom_puzzles
      WHERE owner_id = $1 AND puzzle_id = ANY($2::varchar[])`,
    [trainerId, ids]
  );
  const byId = new Map(found.rows.map((row) => [row.puzzle_id, row]));

  const usable = [];
  const refused = [];
  for (const id of ids) {
    const row = byId.get(id);
    if (!row) {
      refused.push({ puzzleId: id, reason: 'not your position' });
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
    return { ok: false, reason: 'None of the selected positions can be assigned.', refused };
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
  COUNT(*) FILTER (WHERE ai.solved)::int AS solved_items,
  (SELECT COUNT(*)::int FROM assignments c WHERE c.parent_id = a.id) AS child_total,
  (SELECT COUNT(c.completed_at)::int FROM assignments c WHERE c.parent_id = a.id) AS child_completed
`;

/// Everything a student needs to see their own homework.
async function getStudentAssignments(pool, studentId) {
  const result = await pool.query(
    `SELECT ${PROGRESS_COLUMNS}, u.name AS trainer_name
     FROM assignments a
     LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
     LEFT JOIN users u ON u.id = a.trainer_id
     WHERE a.student_id = $1 AND a.parent_id IS NULL
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
    `SELECT ${PROGRESS_COLUMNS}, u.name AS student_name
     FROM assignments a
     LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
     LEFT JOIN users u ON u.id = a.student_id
     WHERE a.trainer_id = $1 AND a.parent_id IS NULL ${filter}
     GROUP BY a.id, u.name
     ORDER BY a.created_at DESC`,
    params
  );
  return result.rows;
}

async function getAssignmentDetail(pool, assignmentId, userId, { tablebase } = {}) {
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

  // A locked item is not opened for the student — the gate holds on the
  // server, not only on their screen. The trainer who set it reads it freely.
  if (assignment.student_id === userId && assignment.trainer_id !== userId) {
    const lock = await homework.lockOf(pool, assignmentId);
    if (lock.locked) return { locked: true, blockedBy: lock.blockedBy };
  }

  // A game the tablebase could not judge when it ended is asked about again
  // now, before anything is counted. Do the thing, then say it — and the
  // asking must not be able to stop the reading: a fault here is logged and
  // the homework opens as it was.
  if (assignment.kind === 'homework' || assignment.kind === 'engine_game') {
    try {
      await judgePendingGames(pool, { assignmentId, ...(tablebase ? { tablebase } : {}) });
    } catch (err) {
      logger.error('A waiting game could not be judged on this read:', err);
    }
  }

  if (assignment.kind === 'homework') {
    // The same two numbers the lists carry (`PROGRESS_COLUMNS`), counted off
    // the rows this read already holds. Without them the app's
    // `itemsSummary` fell back to zero and a homework of three opened as
    // „0 of 0 items" (the live pass of 19.9.2026) — an absent number that
    // read as a number.
    const children = await homework.childrenOf(pool, assignmentId);
    return {
      ...assignment,
      child_total: children.length,
      child_completed: children.filter((c) => c.completed_at !== null).length,
      children,
    };
  }

  const items = await pool.query(
    `SELECT puzzle_id, position, puzzle_rating, solved, ms_taken, played_san, attempted_at
     FROM assignment_items WHERE assignment_id = $1 ORDER BY position`,
    [assignmentId]
  );

  // A tutorial assignment carries what its film is — never a part, a line or
  // a file name (docs/PLAN-TUTORIJAL-VIDEO.md). The link is its own request,
  // signed for the student (`GET /assignments/:id/video`).
  let video = null;
  if (assignment.kind === 'lesson') {
    const found = assignment.lesson_id
      ? await pool.query(
        `SELECT ${filmColumns()} FROM saved_lessons WHERE id = $1`,
        [assignment.lesson_id]
      )
      : { rows: [] };
    video = filmFacts(filmOf(found.rows[0]));
  }

  const customPositions = await loadCustomPositions(pool, items.rows);

  return { ...assignment, items: items.rows, video, customPositions };
}

/// The trainer's own positions among an assignment's items, or null when there
/// are none.
///
/// They travel with the assignment, exactly as lesson steps do, so the
/// student's solver needs one request rather than a lookup against a table they
/// are not allowed to read. **The solution is deliberately absent**: it is the
/// answer to the question being asked, and it stays on the server until the
/// student has actually answered.
///
/// **The table is asked; the id is not read.** This used to keep only ids that
/// start with `cust_`, from when a scanned book was the only writer of
/// `custom_puzzles`. An exercise made by hand is `ex_…` and one made from
/// mistakes is `hw_…`: both travelled without their position, the app took them
/// for Lichess ids, could load none, skipped each in silence and told a student
/// who had never seen the board „Assignment complete" (found live, 20.9.2026).
/// A prefix is not a column.
async function loadCustomPositions(pool, itemRows) {
  const ids = [...new Set(
    (itemRows || []).map((item) => item && item.puzzle_id).filter((id) => typeof id === 'string' && id)
  )];
  if (ids.length === 0) return null;
  const positions = await pool.query(
    `SELECT puzzle_id, fen, side_to_move, instruction, themes, source_title, source_page, source_label
       FROM custom_puzzles WHERE puzzle_id = ANY($1::varchar[])`,
    [ids]
  );
  return positions.rows.length > 0 ? positions.rows : null;
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
       FROM assignments WHERE student_id = $1 AND parent_id IS NULL`,
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
  cleanSan,
  resolvePuzzles,
  createPuzzleAssignment,
  createCustomAssignment,
  loadAssignableLesson,
  createLessonAssignment,
  videoOfAssignment,
  recordVideoDownload,
  markCompleteIfDone,
  recordPuzzleResult,
  recordEngineGameResult,
  // One home for asking the tablebase about a played game — a homework's and,
  // since docs/PLAN-MATERIJAL.md phase 5, one's own exercise's.
  askTablebase,
  sharedTablebase,
  recordTrainerVerdict,
  judgePendingGames,
  getStudentAssignments,
  getTrainerAssignments,
  getAssignmentDetail,
  loadCustomPositions,
  summariseAttempts,
  getStudentProgress,
};
