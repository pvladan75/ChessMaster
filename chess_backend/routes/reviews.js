// reviews.js
// Spaced repetition endpoints.
//
// Everything here is scoped to the calling user: a review schedule is personal,
// and there is no route that takes someone else's id.

const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const srs = require('../services/spacedRepetitionService');
const { acceptedTrainersOf } = require('../services/relationshipService');
const { stepsOfLesson } = require('../services/lessonSteps');

// GET /reviews/due — positions ready to be reviewed now.
router.get('/due', authenticateToken, async (req, res) => {
  const limit = Number.parseInt(req.query.limit, 10) || 30;

  try {
    const [items, stats] = await Promise.all([
      srs.getDue(pool, req.user.id, { limit }),
      srs.getStats(pool, req.user.id),
    ]);
    res.json({ items, stats });
  } catch (err) {
    logger.error('Error fetching due reviews:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju ponavljanja.' });
  }
});

// GET /reviews/stats — counts for the home screen badge.
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    res.json(await srs.getStats(pool, req.user.id));
  } catch (err) {
    logger.error('Error fetching review stats:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju statistike.' });
  }
});

// POST /reviews/grade — records how well the student recalled a position.
router.post('/grade', authenticateToken, async (req, res) => {
  const lessonId = Number.parseInt(req.body.lessonId, 10);
  const position = Number.parseInt(req.body.position, 10);
  const quality = Number.parseInt(req.body.quality, 10);

  // `stepKey` names the step; `position` only orders it. A client that still
  // sends `position` alone is one built before this change, and it is answered
  // rather than refused — but the fallback resolves the index against the
  // lesson as it is *now*, which is exactly the drift this phase removed. It is
  // a bridge, not a second way of doing this.
  //
  // Remove it once the shipped app sends `stepKey`, which it does from the
  // build that carries `docs/PLAN-INTERAKTIVNA-LEKCIJA.md` phase 1.
  const stepKey = typeof req.body.stepKey === 'string' && req.body.stepKey !== ''
    ? req.body.stepKey
    : null;

  if (!Number.isInteger(lessonId)) {
    return res.status(400).json({ error: 'lessonId je obavezan.' });
  }
  if (!stepKey && (!Number.isInteger(position) || position < 0)) {
    return res.status(400).json({ error: 'stepKey ili position su obavezni.' });
  }

  try {
    // The lesson must be one the student can actually reach — their own, their
    // trainer's, or one assigned to them. Otherwise a guessed lesson id would
    // seed a schedule against someone else's material.
    const allowed = await pool.query(
      `SELECT 1 FROM saved_lessons l
       WHERE l.id = $1
         AND (l.user_id = $2
              OR l.trainer_id = $2
              OR l.trainer_id IN (${acceptedTrainersOf('$2')})
              OR EXISTS (SELECT 1 FROM assignments a WHERE a.lesson_id = l.id AND a.student_id = $2))`,
      [lessonId, req.user.id]
    );
    if (allowed.rows.length === 0) {
      return res.status(403).json({ error: 'Nemate pristup tom tutorijalu.' });
    }

    // The bridge for an older client: turn its index into the step's name,
    // using the same reader every other caller uses.
    let key = stepKey;
    if (!key) {
      const lesson = await pool.query(
        'SELECT title, fen, pgn, position_list FROM saved_lessons WHERE id = $1',
        [lessonId]
      );
      const steps = lesson.rows.length === 0 ? [] : stepsOfLesson({
        positionList: lesson.rows[0].position_list,
        title: lesson.rows[0].title,
        fen: lesson.rows[0].fen,
        pgn: lesson.rows[0].pgn,
      });
      key = steps[position] ? steps[position].id : null;
      if (!key) {
        return res.status(404).json({ error: 'Taj korak više ne postoji u tutorijalu.' });
      }
    }

    const result = await srs.grade(pool, {
      userId: req.user.id,
      lessonId,
      stepKey: key,
      position: Number.isInteger(position) && position >= 0 ? position : 0,
      quality,
    });

    if (!result.ok) {
      return res.status(400).json({ error: result.reason });
    }

    res.json({
      success: true,
      intervalDays: result.intervalDays,
      dueAt: result.dueAt,
      description: result.description,
    });
  } catch (err) {
    logger.error('Error grading review:', err);
    res.status(500).json({ error: 'Greška pri beleženju ocene.' });
  }
});

module.exports = router;
