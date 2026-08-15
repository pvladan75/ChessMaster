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
const reports = require('../services/reportService');

/// How long a parent's link stays alive. Long enough to be useful, short enough
/// that a forwarded link does not expose a child's record indefinitely.
const REPORT_TTL_DAYS = 60;

/// Trainer notes land in a page a parent opens; a cap keeps one from bloating
/// the row and the rendered page.
const MAX_NOTE_LENGTH = 2000;

// POST /assignments — a trainer sets homework for one of their students.
router.post('/', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const { studentId, title, instructions, dueAt, themes, minRating, maxRating, count } = req.body;

  const targetId = Number.parseInt(studentId, 10);
  if (!Number.isInteger(targetId) || !title || title.trim() === '') {
    await refundQuota(req);
    return res.status(400).json({ error: 'studentId i naslov su obavezni.' });
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

    res.status(201).json({ success: true, assignment: result.assignment });
  } catch (err) {
    await refundQuota(req);
    logger.error('Error creating assignment:', err);
    res.status(500).json({ error: 'Greška pri kreiranju zadatka.' });
  }
});

// POST /assignments/lesson — a trainer assigns one of their own lessons.
router.post('/lesson', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const { studentId, lessonId, title, instructions, dueAt } = req.body;

  const targetId = Number.parseInt(studentId, 10);
  const lesson = Number.parseInt(lessonId, 10);
  if (!Number.isInteger(targetId) || !Number.isInteger(lesson)) {
    await refundQuota(req);
    return res.status(400).json({ error: 'studentId i lessonId su obavezni.' });
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

    res.status(201).json({ success: true, assignment: result.assignment });
  } catch (err) {
    await refundQuota(req);
    logger.error('Error creating lesson assignment:', err);
    res.status(500).json({ error: 'Greška pri zadavanju lekcije.' });
  }
});

// POST /assignments/:id/step/:position — the student marks a lesson step reviewed.
router.post('/:id/step/:position', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const position = Number.parseInt(req.params.position, 10);

  if (!Number.isInteger(id) || !Number.isInteger(position) || position < 0) {
    return res.status(400).json({ error: 'Neispravan zadatak ili korak.' });
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
    res.status(500).json({ error: 'Greška pri beleženju koraka.' });
  }
});

// GET /assignments/mine — what the caller has been set.
router.get('/mine', authenticateToken, async (req, res) => {
  try {
    res.json({ assignments: await assignments.getStudentAssignments(pool, req.user.id) });
  } catch (err) {
    logger.error('Error fetching student assignments:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zadataka.' });
  }
});

// GET /assignments/given — what the caller has set, with each student's progress.
router.get('/given', authenticateToken, async (req, res) => {
  const studentId = req.query.studentId ? Number.parseInt(req.query.studentId, 10) : null;

  try {
    if (studentId && !(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'Taj učenik nije na vašoj listi.' });
    }
    res.json({
      assignments: await assignments.getTrainerAssignments(pool, req.user.id, { studentId }),
    });
  } catch (err) {
    logger.error('Error fetching trainer assignments:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zadataka.' });
  }
});

// GET /assignments/:id — readable by the trainer who set it and the student who got it.
router.get('/:id', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Neispravan ID zadatka.' });
  }

  try {
    const detail = await assignments.getAssignmentDetail(pool, id, req.user.id);
    if (!detail) {
      // Same answer for "does not exist" and "not yours", so the endpoint cannot
      // be used to discover which assignment ids are real.
      return res.status(404).json({ error: 'Zadatak nije pronađen.' });
    }
    res.json(detail);
  } catch (err) {
    logger.error('Error fetching assignment detail:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zadatka.' });
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
      return res.status(404).json({ error: 'Zadatak nije pronađen ili nije vaš.' });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Error deleting assignment:', err);
    res.status(500).json({ error: 'Greška pri brisanju zadatka.' });
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
    return res.status(400).json({ error: 'Neispravan ID učenika.' });
  }

  try {
    if (!(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'Taj učenik nije na vašoj listi.' });
    }

    const namesRes = await pool.query(
      'SELECT id, name FROM users WHERE id = ANY($1::int[])',
      [[studentId, req.user.id]]
    );
    const names = Object.fromEntries(namesRes.rows.map((row) => [row.id, row.name]));

    const snapshot = await reports.buildSnapshot(pool, {
      studentId,
      studentName: names[studentId] || 'Učenik',
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
    res.status(500).json({ error: 'Greška pri izradi izveštaja.' });
  }
});

// GET /assignments/progress/me — the caller's own report.
router.get('/progress/me', authenticateToken, async (req, res) => {
  const days = Math.min(Math.max(Number.parseInt(req.query.days, 10) || 30, 1), 365);
  try {
    res.json(await assignments.getStudentProgress(pool, req.user.id, { days }));
  } catch (err) {
    logger.error('Error building own progress report:', err);
    res.status(500).json({ error: 'Greška pri izradi izveštaja.' });
  }
});

// GET /assignments/progress/:studentId — a trainer's view of one of their students.
router.get('/progress/:studentId', authenticateToken, async (req, res) => {
  const studentId = Number.parseInt(req.params.studentId, 10);
  const days = Math.min(Math.max(Number.parseInt(req.query.days, 10) || 30, 1), 365);

  if (!Number.isInteger(studentId)) {
    return res.status(400).json({ error: 'Neispravan ID učenika.' });
  }

  try {
    if (!(await assignments.trainerOwnsStudent(pool, req.user.id, studentId))) {
      return res.status(403).json({ error: 'Taj učenik nije na vašoj listi.' });
    }
    res.json(await assignments.getStudentProgress(pool, studentId, { days }));
  } catch (err) {
    logger.error('Error building student progress report:', err);
    res.status(500).json({ error: 'Greška pri izradi izveštaja.' });
  }
});

module.exports = router;
