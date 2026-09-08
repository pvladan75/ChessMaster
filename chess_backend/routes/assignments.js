// assignments.js
// Homework endpoints.
//
// Every route here touches one student's record, and most of those students are
// children. So the authorisation rule is uniform and deliberately boring: a
// trainer reaches a student only through `trainer_students`, and a student
// reaches only themselves. There is no route that takes a student id and trusts
// it.

const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken, signReportToken } = require('../middleware/auth');
const { requireQuota, refundQuota } = require('../middleware/entitlements');
const { ENT } = require('../services/entitlementService');
const assignments = require('../services/assignmentService');
const { OWN_GAMES_SQL } = require('../services/archiveScope');
const { notify } = require('../services/notifications');
const reports = require('../services/reportService');
const { judgeAttempt } = require('../services/customPuzzleJudge');
const { stepsOfLesson } = require('../services/lessonSteps');
const { buildReview } = require('../services/assignmentReview');
const notes = require('../services/assignmentNotes');
const { markReviewed } = require('../services/trainerPanelService');
const {
  homeworkFromArchive, HomeworkRefused,
} = require('../services/homeworkFromArchive');
const { leakReport } = require('../services/openingLeaks');
const { stats: mistakeStats, recurrence } = require('../services/mistakeReviews');
const { monthlyTrend } = require('../services/playerProfile');

/// How long a parent's link stays alive. Long enough to be useful, short enough
/// that a forwarded link does not expose a child's record indefinitely.
const REPORT_TTL_DAYS = 60;

/// Trainer notes land in a page a parent opens; a cap keeps one from bloating
/// the row and the rendered page.
const MAX_NOTE_LENGTH = 2000;

/// Tells the student that homework arrived.
///
/// Here rather than in the service because the trainer's name is already on the
/// request; the service would have to go and look it up. Best effort inside
/// [notify]: homework that was created must not fail because the note about it
/// did.
async function tellStudent(req, assignment) {
  await notify(pool, {
    recipientId: assignment.student_id,
    senderId: req.user.id,
    title: 'New assignment',
    message: `${req.user.name || 'Trainer'} assigned you: ${assignment.title}`,
    kind: 'assignment_new',
    refId: assignment.id,
  });
}

/// The handle a student's own archive is filed under.
///
/// A trainer knows a student by account, not by Lichess name, and the reports
/// are keyed by handle because one account can hold more than one archive. This
/// picks the one the student imported as **their own** and has the most games
/// in; an opponent's profile the student once looked up is never it.
async function ownArchiveSubject(studentId) {
  const { rows } = await pool.query(
    `SELECT subject, COUNT(*)::int AS games
       FROM user_games
      WHERE user_id = $1 AND ${OWN_GAMES_SQL}
      GROUP BY subject ORDER BY games DESC LIMIT 1`,
    [studentId],
  );
  return rows[0] || null;
}

// POST /assignments/from-archive
//   { studentId, count?, kind?, title?, instructions?, dueAt?, dryRun? }
//
// Homework built from the student's own mistakes. What makes this different
// from every other way of setting homework is that nobody chose the positions:
// they are the ones that child actually got wrong.
//
// `dryRun: true` returns the chosen positions and writes nothing, which is what
// a trainer should see before a child does.
router.post('/from-archive', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const body = req.body ?? {};
  try {
    const outcome = await homeworkFromArchive(pool, {
      trainerId: req.user.id,
      studentId: Number(body.studentId),
      title: body.title,
      instructions: body.instructions ?? null,
      dueAt: body.dueAt ?? null,
      count: body.count,
      kind: body.kind ?? null,
      dryRun: body.dryRun === true,
    });

    if (outcome.dryRun) {
      // Nothing was created, so nothing was spent.
      await refundQuota(req);
      return res.json(outcome);
    }
    await tellStudent(req, outcome.assignment);
    return res.status(201).json(outcome);
  } catch (err) {
    await refundQuota(req);
    if (err instanceof HomeworkRefused) {
      return res.status(err.status).json({ error: err.message });
    }
    if (err instanceof TypeError) return res.status(400).json({ error: err.message });
    logger.error(`[DOMACI] Iz arhive nije uspelo: ${err.message}`);
    return res.status(500).json({ error: 'Failed to create homework from archive.' });
  }
});

// GET /assignments/student/:id/archive
//
// What the trainer can see of a student's archive: the counts, what keeps
// recurring, and the opening leaks. Positions and numbers — not a browsable
// game history, which is a wider read than the relationship needs.
router.get('/student/:id/archive', authenticateToken, async (req, res) => {
  const studentId = Number(req.params.id);
  if (!Number.isInteger(studentId)) return res.status(400).json({ error: 'Invalid ID.' });

  try {
    if (!(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'That student is not on your list.' });
    }
    const archive = await ownArchiveSubject(studentId);
    if (!archive) {
      return res.json({ subject: null, games: 0, leaks: null, mistakes: null });
    }
    const [leaks, mistakes, repeats, trend] = await Promise.all([
      leakReport(pool, studentId, { subject: archive.subject, limit: 10 }),
      mistakeStats(pool, studentId),
      recurrence(pool, studentId),
      monthlyTrend(pool, studentId, archive.subject),
    ]);
    return res.json({
      subject: archive.subject,
      games: archive.games,
      leaks,
      mistakes,
      recurrence: repeats,
      // Named `trend` and not `beforeAfter`: a real before-and-after needs a
      // date to compare across, and nothing here records when a student started
      // working on something.
      trend,
    });
  } catch (err) {
    if (err instanceof RangeError) return res.status(400).json({ error: err.message });
    logger.error(`[DOMACI] Arhiva učenika nije dostupna: ${err.message}`);
    return res.status(500).json({ error: 'Student archive is not available.' });
  }
});

// POST /assignments — a trainer sets homework for one of their students.
router.post('/', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const { studentId, title, instructions, dueAt, themes, minRating, maxRating, count } = req.body;

  const targetId = Number.parseInt(studentId, 10);
  if (!Number.isInteger(targetId) || !title || title.trim() === '') {
    await refundQuota(req);
    return res.status(400).json({ error: 'studentId and title are required.' });
  }

  try {
    const result = await assignments.createPuzzleAssignment(pool, {
      trainerId: req.user.id,
      studentId: targetId,
      title: title.trim(),
      instructions,
      dueAt: dueAt || null,
      themes: Array.isArray(themes) ? themes : [],
      minRating: Number.parseInt(minRating, 10) || null,
      maxRating: Number.parseInt(maxRating, 10) || null,
      count: Number.parseInt(count, 10) || null,
    });

    if (!result.ok) {
      // Nothing was created, so the quota unit goes back.
      await refundQuota(req);
      return res.status(400).json({ error: result.reason });
    }

    await tellStudent(req, result.assignment);
    res.status(201).json({ success: true, assignment: result.assignment });
  } catch (err) {
    await refundQuota(req);
    logger.error('Error creating assignment:', err);
    res.status(500).json({ error: 'Error creating assignment.' });
  }
});

// POST /assignments/custom — homework from the trainer's own scanned positions.
//
// Separate from POST / because the two choose their work in opposite ways: that
// one asks for twenty puzzles about pins, this one is handed an exact list the
// trainer picked off their screen. Folding them together would mean branching
// on which fields happened to arrive.
router.post('/custom', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const { studentId, title, instructions, dueAt, puzzleIds } = req.body;

  const targetId = Number.parseInt(studentId, 10);
  if (!Number.isInteger(targetId) || !title || title.trim() === '') {
    await refundQuota(req);
    return res.status(400).json({ error: 'studentId and title are required.' });
  }

  try {
    const result = await assignments.createCustomAssignment(pool, {
      trainerId: req.user.id,
      studentId: targetId,
      title: title.trim(),
      instructions,
      dueAt: dueAt || null,
      puzzleIds,
    });

    if (!result.ok) {
      await refundQuota(req);
      // The refusals travel with the error: "nothing could be set" without
      // saying which position and why leaves the trainer guessing.
      return res.status(400).json({ error: result.reason, refused: result.refused || [] });
    }

    await tellStudent(req, result.assignment);
    res.status(201).json({
      success: true,
      assignment: result.assignment,
      refused: result.refused,
    });
  } catch (err) {
    await refundQuota(req);
    logger.error('Error creating custom assignment:', err);
    res.status(500).json({ error: 'Error creating assignment.' });
  }
});

// POST /assignments/:id/custom-attempt — the student answers one position.
//
// The move is judged on the server because the answer lives there: sending the
// solution to the client so it could mark its own work would hand the student
// the very thing being asked of them.
router.post('/:id/custom-attempt', authenticateToken, async (req, res) => {
  const assignmentId = Number.parseInt(req.params.id, 10);
  const { puzzleId, moveSan, msTaken } = req.body || {};

  if (!Number.isInteger(assignmentId) || typeof puzzleId !== 'string' || typeof moveSan !== 'string') {
    return res.status(400).json({ error: 'puzzleId and moveSan are required.' });
  }

  try {
    // One query establishes both that this assignment is the caller's own
    // homework and that the position is part of it.
    const item = await pool.query(
      `SELECT cp.fen, cp.solution_san, cp.instruction
         FROM assignment_items ai
         JOIN assignments a ON a.id = ai.assignment_id
         JOIN custom_puzzles cp ON cp.puzzle_id = ai.puzzle_id
        WHERE ai.assignment_id = $1 AND ai.puzzle_id = $2 AND a.student_id = $3`,
      [assignmentId, puzzleId, req.user.id]
    );
    if (item.rowCount === 0) {
      return res.status(404).json({ error: 'That position is not part of your assignment.' });
    }

    const { fen, solution_san: solutionSan } = item.rows[0];
    const verdict = judgeAttempt({ fen, solutionSan, moveSan });

    // A move the board cannot play means the client and the server disagree
    // about the position — the student's board offered a move this one refuses.
    // It is recorded as unknown, which is honest, but it must not pass in
    // silence: nothing else would ever show it.
    if (verdict.playedSan === null) {
      logger.warn(
        { assignmentId, puzzleId, moveSan, reason: verdict.reason },
        'Custom attempt could not be resolved to a move'
      );
    }

    // The move goes in beside the verdict. `judgeAttempt` has already resolved
    // it against the position, so this is the move as the board understood it,
    // not as the client spelled it.
    await assignments.recordPuzzleResult(pool, {
      studentId: req.user.id,
      puzzleId,
      solved: verdict.correct,
      msTaken: Number.parseInt(msTaken, 10) || null,
      playedSan: verdict.playedSan,
    });

    // The solution is released only now, once the question has been answered.
    res.json({
      correct: verdict.correct,
      reason: verdict.reason,
      playedSan: verdict.playedSan,
      solutionSan,
    });
  } catch (err) {
    logger.error('Error judging custom attempt:', err);
    res.status(500).json({ error: 'Error checking answer.' });
  }
});

// POST /assignments/lesson — a trainer assigns one of their own lessons.
router.post('/lesson', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const { studentId, lessonId, title, instructions, dueAt } = req.body;

  const targetId = Number.parseInt(studentId, 10);
  const lesson = Number.parseInt(lessonId, 10);
  if (!Number.isInteger(targetId) || !Number.isInteger(lesson)) {
    await refundQuota(req);
    return res.status(400).json({ error: 'studentId and lessonId are required.' });
  }

  try {
    const result = await assignments.createLessonAssignment(pool, {
      trainerId: req.user.id,
      studentId: targetId,
      lessonId: lesson,
      title: typeof title === 'string' ? title.trim() : null,
      instructions,
      dueAt: dueAt || null,
    });

    if (!result.ok) {
      await refundQuota(req);
      return res.status(400).json({ error: result.reason });
    }

    await tellStudent(req, result.assignment);
    res.status(201).json({ success: true, assignment: result.assignment });
  } catch (err) {
    await refundQuota(req);
    logger.error('Error creating lesson assignment:', err);
    res.status(500).json({ error: 'Error assigning tutorial.' });
  }
});

// POST /assignments/:id/step/:position — the student marks a lesson step reviewed.
router.post('/:id/step/:position', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const position = Number.parseInt(req.params.position, 10);

  if (!Number.isInteger(id) || !Number.isInteger(position) || position < 0) {
    return res.status(400).json({ error: 'Invalid assignment or step.' });
  }

  try {
    const marked = await assignments.markLessonStepDone(pool, {
      studentId: req.user.id,
      assignmentId: id,
      position,
    });
    // Already-marked steps answer 200 too: re-opening a lesson and stepping
    // back through it is normal and must not read as an error.
    res.json({ success: true, marked });
  } catch (err) {
    logger.error('Error marking lesson step:', err);
    res.status(500).json({ error: 'Error recording step.' });
  }
});

// POST /assignments/:id/step/:position/answer — the student answers a step.
//
// Judged here, never on the client. `getAssignmentDetail` redacts the answer
// out of what the student is served, so the client could not mark its own work
// even if it wanted to — which is the point.
router.post('/:id/step/:position/answer', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const position = Number.parseInt(req.params.position, 10);
  if (!Number.isInteger(id) || !Number.isInteger(position) || position < 0) {
    return res.status(400).json({ error: 'Invalid assignment or step.' });
  }

  try {
    const step = await lessonStepOfAssignment(pool, id, req.user.id, position);
    if (!step) {
      return res.status(404).json({ error: 'That step is not part of your assignment.' });
    }

    let verdict;
    if (step.kind === 'ask_move') {
      verdict = judgeAttempt({
        fen: step.fen,
        solutionSan: step.solutionSan,
        acceptedSans: step.acceptedSans || [],
        moveSan: String(req.body?.moveSan || ''),
      });
      // The client and this server disagreeing about the position is not a
      // wrong answer, and must not pass in silence — nothing else would ever
      // show it.
      if (verdict.playedSan === null) {
        logger.warn({ assignmentId: id, position, moveSan: req.body?.moveSan },
          'Lesson step attempt could not be resolved to a move');
      }
    } else if (step.kind === 'ask_choice') {
      const picked = Number.parseInt(req.body?.choiceIndex, 10);
      const choices = Array.isArray(step.choices) ? step.choices : [];
      if (!Number.isInteger(picked) || picked < 0 || picked >= choices.length) {
        return res.status(400).json({ error: 'No choice was selected.' });
      }
      verdict = {
        correct: choices[picked].correct === true,
        reason: choices[picked].correct === true ? 'correct answer' : 'incorrect answer',
        playedSan: null,
      };
    } else {
      return res.status(409).json({ error: 'This step is for reading, not solving.' });
    }

    await assignments.recordLessonStepAnswer(pool, {
      studentId: req.user.id,
      assignmentId: id,
      position,
      correct: verdict.correct,
      playedSan: verdict.playedSan,
    });

    // The solution is released only now, once the question has been answered.
    res.json({
      correct: verdict.correct,
      reason: verdict.reason,
      playedSan: verdict.playedSan,
      solutionSan: step.solutionSan ?? null,
      correctIndex: step.kind === 'ask_choice'
        ? step.choices.findIndex((c) => c.correct === true)
        : null,
    });
  } catch (err) {
    logger.error('Error judging lesson step:', err);
    res.status(500).json({ error: 'Error checking answer.' });
  }
});

// POST /assignments/:id/step/:position/reveal — „Pokaži mi".
//
// The escape that keeps a stuck child from being unable to finish. Recorded as
// its own thing rather than as a wrong answer: „rešenje otkriveno" and
// „netačno" are different facts about a child.
router.post('/:id/step/:position/reveal', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const position = Number.parseInt(req.params.position, 10);
  if (!Number.isInteger(id) || !Number.isInteger(position) || position < 0) {
    return res.status(400).json({ error: 'Invalid assignment or step.' });
  }

  try {
    const step = await lessonStepOfAssignment(pool, id, req.user.id, position);
    if (!step) {
      return res.status(404).json({ error: 'That step is not part of your assignment.' });
    }

    await assignments.revealLessonStep(pool, {
      studentId: req.user.id, assignmentId: id, position,
    });

    res.json({
      solutionSan: step.solutionSan ?? null,
      acceptedSans: step.acceptedSans ?? [],
      correctIndex: step.kind === 'ask_choice'
        ? step.choices.findIndex((c) => c.correct === true)
        : null,
    });
  } catch (err) {
    logger.error('Error revealing lesson step:', err);
    res.status(500).json({ error: 'Error displaying solution.' });
  }
});

/// The step, **with** its answer, for the caller's own lesson assignment.
///
/// One query establishes both that this is the student's own homework and which
/// lesson it came from. Returns null for "not yours" and for "no such step", so
/// a guessed id cannot be used to find out which assignments exist.
async function lessonStepOfAssignment(pool, assignmentId, studentId, position) {
  const found = await pool.query(
    `SELECT l.title, l.fen, l.pgn, l.position_list
       FROM assignments a
       JOIN saved_lessons l ON l.id = a.lesson_id
      WHERE a.id = $1 AND a.student_id = $2 AND a.kind = 'lesson'`,
    [assignmentId, studentId]
  );
  if (found.rowCount === 0) return null;

  const lesson = found.rows[0];
  const steps = stepsOfLesson({
    positionList: lesson.position_list,
    title: lesson.title,
    fen: lesson.fen,
    pgn: lesson.pgn,
  });
  return steps[position] || null;
}

// GET /assignments/mine — what the caller has been set.
router.get('/mine', authenticateToken, async (req, res) => {
  try {
    res.json({ assignments: await assignments.getStudentAssignments(pool, req.user.id) });
  } catch (err) {
    logger.error('Error fetching student assignments:', err);
    res.status(500).json({ error: 'Error fetching assignments.' });
  }
});

// GET /assignments/given — what the caller has set, with each student's progress.
router.get('/given', authenticateToken, async (req, res) => {
  const studentId = req.query.studentId ? Number.parseInt(req.query.studentId, 10) : null;

  try {
    if (studentId && !(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'That student is not on your list.' });
    }
    res.json({
      assignments: await assignments.getTrainerAssignments(pool, req.user.id, { studentId }),
    });
  } catch (err) {
    logger.error('Error fetching trainer assignments:', err);
    res.status(500).json({ error: 'Error fetching assignments.' });
  }
});

// GET /assignments/:id — readable by the trainer who set it and the student who got it.
router.get('/:id', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Invalid assignment ID.' });
  }

  try {
    const detail = await assignments.getAssignmentDetail(pool, id, req.user.id);
    if (!detail) {
      // Same answer for "does not exist" and "not yours", so the endpoint cannot
      // be used to discover which assignment ids are real.
      return res.status(404).json({ error: 'Assignment not found.' });
    }
    res.json(detail);
  } catch (err) {
    logger.error('Error fetching assignment detail:', err);
    res.status(500).json({ error: 'Error fetching assignment.' });
  }
});

// GET /assignments/:id/review — what happened, position by position.
//
// Readable by both sides of the assignment. The trainer sees why an answer went
// wrong; the student sees what they played and what the answer was, which they
// could not see anywhere until now.
router.get('/:id/review', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Invalid assignment ID.' });
  }

  try {
    const review = await buildReview(pool, id, req.user.id);
    if (!review) {
      return res.status(404).json({ error: 'Assignment not found.' });
    }
    res.json(review);
  } catch (err) {
    logger.error('Error building assignment review:', err);
    res.status(500).json({ error: 'Error fetching review.' });
  }
});

// POST /assignments/:id/reviewed — the trainer has looked at finished homework.
//
// Its own route rather than a side effect of `GET /:id/review`, because the
// student reads that same review: a read that writes would have the child
// emptying their trainer's queue by looking at their own feedback. It is also
// what the notifications route does — reading the bell and marking it read are
// two calls, for the same reason.
//
// Idempotent by construction: the UPDATE carries the whole rule, so a second
// call, somebody else's assignment, and one that is not finished yet all write
// nothing and answer the same way.
router.post('/:id/reviewed', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Invalid assignment ID.' });
  }

  try {
    const marked = await markReviewed(pool, { assignmentId: id, trainerId: req.user.id });
    res.json({ ok: true, marked });
  } catch (err) {
    logger.error('Error marking assignment reviewed:', err);
    res.status(500).json({ error: 'Error marking assignment.' });
  }
});

// POST /assignments/:id/notes — a word about the assignment, or about one
// position in it.
//
// `itemId` decides which: absent means the whole assignment. Both sides write
// through the same route, and which of them wrote it is read from the account
// rather than sent.
router.post('/:id/notes', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Invalid assignment ID.' });
  }

  const rawItem = req.body?.itemId;
  const itemId = rawItem === null || rawItem === undefined
    ? null
    : Number.parseInt(rawItem, 10);
  if (itemId !== null && !Number.isInteger(itemId)) {
    return res.status(400).json({ error: 'Invalid position ID.' });
  }

  try {
    const result = await notes.addNote(pool, {
      assignmentId: id,
      itemId,
      authorId: req.user.id,
      body: req.body?.body,
    });
    if (!result.ok) {
      return res.status(result.status).json({ error: result.error });
    }

    // The other side of the assignment, whichever side that is: a trainer's
    // comment reaches the student, a student's question reaches the trainer.
    await notify(pool, {
      recipientId: result.recipientId,
      senderId: req.user.id,
      title: 'Assignment note',
      message: `${req.user.name || 'User'} posted a note on assignment: ${result.assignmentTitle}`,
      kind: 'assignment_note',
      refId: id,
    });

    res.status(201).json({ success: true, note: result.note });
  } catch (err) {
    logger.error('Error adding assignment note:', err);
    res.status(500).json({ error: 'Error saving note.' });
  }
});

// DELETE /assignments/:id/notes/:noteId — the author takes back their own words.
router.delete('/:id/notes/:noteId', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const noteId = Number.parseInt(req.params.noteId, 10);
  if (!Number.isInteger(id) || !Number.isInteger(noteId)) {
    return res.status(400).json({ error: 'Invalid ID.' });
  }

  try {
    const result = await notes.deleteNote(pool, {
      assignmentId: id,
      noteId,
      authorId: req.user.id,
    });
    if (!result.ok) {
      return res.status(result.status).json({ error: result.error });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Error deleting assignment note:', err);
    res.status(500).json({ error: 'Error deleting note.' });
  }
});

// DELETE /assignments/:id — only the trainer who set it may withdraw it.
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM assignments WHERE id = $1 AND trainer_id = $2 RETURNING id',
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Assignment not found or not yours.' });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Error deleting assignment:', err);
    res.status(500).json({ error: 'Error deleting assignment.' });
  }
});

// POST /assignments/report/:studentId — freezes a report and returns a link the
// trainer can send to a parent.
router.post('/report/:studentId', authenticateToken, async (req, res) => {
  const studentId = Number.parseInt(req.params.studentId, 10);
  const days = Math.min(Math.max(Number.parseInt(req.body.days, 10) || 30, 7), 365);
  const note = typeof req.body.note === 'string'
    ? req.body.note.trim().slice(0, MAX_NOTE_LENGTH)
    : null;

  if (!Number.isInteger(studentId)) {
    return res.status(400).json({ error: 'Invalid student ID.' });
  }

  try {
    if (!(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'That student is not on your list.' });
    }

    const namesRes = await pool.query(
      'SELECT id, name FROM users WHERE id = ANY($1::int[])',
      [[studentId, req.user.id]]
    );
    const names = Object.fromEntries(namesRes.rows.map((row) => [row.id, row.name]));

    const snapshot = await reports.buildSnapshot(pool, {
      studentId,
      studentName: names[studentId] || 'Student',
      trainerName: names[req.user.id] || null,
      days,
    });

    const expiresAt = new Date(Date.now() + REPORT_TTL_DAYS * 24 * 60 * 60 * 1000);
    const inserted = await pool.query(
      `INSERT INTO student_reports (trainer_id, student_id, period_days, note, snapshot, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, created_at`,
      [req.user.id, studentId, days, note, JSON.stringify(snapshot), expiresAt]
    );

    const report = inserted.rows[0];
    const token = signReportToken(report.id, REPORT_TTL_DAYS);
    const url = `${req.protocol}://${req.get('host')}/reports/${report.id}?token=${encodeURIComponent(token)}`;

    logger.info(
      { trainerId: req.user.id, studentId, reportId: report.id, days },
      'Parent report generated'
    );

    res.status(201).json({
      success: true,
      reportId: report.id,
      url,
      expiresAt: expiresAt.toISOString(),
      hasData: snapshot.totalAttempts > 0,
    });
  } catch (err) {
    logger.error('Error generating parent report:', err);
    res.status(500).json({ error: 'Error generating report.' });
  }
});

// GET /assignments/progress/me — the caller's own report.
router.get('/progress/me', authenticateToken, async (req, res) => {
  const days = Math.min(Math.max(Number.parseInt(req.query.days, 10) || 30, 1), 365);
  try {
    res.json(await assignments.getStudentProgress(pool, req.user.id, { days }));
  } catch (err) {
    logger.error('Error building own progress report:', err);
    res.status(500).json({ error: 'Error generating report.' });
  }
});

// GET /assignments/progress/:studentId — a trainer's view of one of their students.
router.get('/progress/:studentId', authenticateToken, async (req, res) => {
  const studentId = Number.parseInt(req.params.studentId, 10);
  const days = Math.min(Math.max(Number.parseInt(req.query.days, 10) || 30, 1), 365);

  if (!Number.isInteger(studentId)) {
    return res.status(400).json({ error: 'Invalid student ID.' });
  }

  try {
    if (!(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'That student is not on your list.' });
    }
    res.json(await assignments.getStudentProgress(pool, studentId, { days }));
  } catch (err) {
    logger.error('Error building student progress report:', err);
    res.status(500).json({ error: 'Error generating report.' });
  }
});

module.exports = router;
