const path = require('path');
const fs = require('fs');
const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken, signDownloadToken } = require('../middleware/auth');
const { requireEntitlement } = require('../middleware/entitlements');
const { ENT, METRIC, recordUsage } = require('../services/entitlementService');
const videoRenderer = require('../videoRenderer');
const { acceptedTrainersOf } = require('../services/relationshipService');
const { buildLessonStep, buildLessonSteps } = require('../services/lessonSteps');

/// Runs a submitted step list through the one builder, or answers the caller.
///
/// Returns the built entries, or null after having already sent the refusal —
/// so a route reads `if (steps === null) return;`.
function buildOrReject(res, positionList) {
  if (!positionList || (Array.isArray(positionList) && positionList.length === 0)) {
    return [];
  }
  const built = buildLessonSteps(positionList);
  if (!built.ok) {
    res.status(built.status).json({ error: built.error });
    return null;
  }
  return built.entries;
}

/// The default name for a copy, kept inside the column it has to fit.
///
/// `title` is `VARCHAR(255)`. Appending „ (kopija)" to a title already near the
/// limit is a 22001 from the driver and a 500 to the trainer, which reads as
/// „cloning is broken" rather than „your title is long" — so the base is
/// shortened instead, and only as much as it must be.
const COPY_SUFFIX = ' (copy)';
const MAX_LESSON_TITLE = 255;

function copyTitle(title) {
  const base = typeof title === 'string' ? title : '';
  const room = MAX_LESSON_TITLE - COPY_SUFFIX.length;
  return `${base.length > room ? base.slice(0, room) : base}${COPY_SUFFIX}`;
}

// POST /lessons/save
router.post('/save', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  // Every step gets its id here, once, and keeps it for the rest of its life.
  const steps = buildOrReject(res, positionList);
  if (steps === null) return;

  try {
    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list) VALUES ($1, $1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [req.user.id, title, description || null, tags || null, initialFen, pgn || null, steps.length > 0 ? JSON.stringify(steps) : null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Save lesson error:', err);
    res.status(500).json({ error: 'Server error while saving lesson' });
  }
});

/// Did this request say anything at all about the steps?
///
/// The difference between "leave them alone" and "there are none now", and the
/// two used to be one thing. `_editSinglePosition` in the app renames a saved
/// position and sends no `positionList` — which wrote `position_list = NULL`
/// over whatever was there, because a missing list and an empty one both came
/// out of `buildOrReject` as `[]`.
///
/// Nothing lost data, and only because the *caller* was careful: the list in
/// the app offers that rename for a single position and the course dialog for a
/// course, so the nulling path was never handed a lesson with steps in it. That
/// is a guarantee living in a widget's `isCourse ? ... : ...`, two files and one
/// refactor away from the write that would destroy every step of a lesson —
/// silently, since nothing joins on them and nothing would log it. The same
/// shape as every bug in the CLAUDE.md list.
///
/// `lesson_rename_keeps_steps.test.js` drives the mounted route rather than
/// this function: the helper being right and the route asking it are two
/// different things, and on the last occasion it was the second one missing.
function sentPositionList(body) {
  return Object.prototype.hasOwnProperty.call(body || {}, 'positionList')
    && body.positionList !== null
    && body.positionList !== undefined;
}

// PUT /lessons/:id — update a lesson you own (either creator or the trainer who shared it)
router.put('/:id', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;
  const touchesSteps = sentPositionList(req.body);

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  const steps = touchesSteps ? buildOrReject(res, positionList) : [];
  if (steps === null) return;

  try {
    // A client that sends back a list of the same length with every id stripped
    // has lost the ids it was given, and writing it would orphan every schedule
    // row and every recorded answer naming those steps — silently, because
    // nothing joins on them.
    //
    // So it fails loudly instead. A lesson whose stored steps never had ids has
    // nothing to lose and is let through; this only fires where a real identity
    // would be destroyed.
    const stored = await pool.query(
      'SELECT position_list FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)',
      [req.params.id, req.user.id]
    );
    const storedList = Array.isArray(stored.rows[0]?.position_list) ? stored.rows[0].position_list : [];
    const hasId = (s) => typeof s?.id === 'string' && s.id !== '';
    if (
      touchesSteps
      && storedList.length > 0
      && storedList.length === steps.length
      && storedList.some(hasId)
      && !(positionList || []).some(hasId)
    ) {
      return res.status(409).json({
        error: 'Steps arrived without their IDs. Refresh the tutorial and save again.',
      });
    }

    // A request that said nothing about the steps leaves the column alone. It
    // is written as two statements rather than one clever `CASE`, because the
    // thing being protected here is a list that cannot be reconstructed once it
    // is gone, and the reader of this file should be able to see which
    // statement runs without evaluating an expression in their head.
    const result = touchesSteps
      ? await pool.query(
        `UPDATE saved_lessons
         SET title = $1, description = $2, tags = $3, fen = $4, pgn = $5, position_list = $6
         WHERE id = $7 AND (user_id = $8 OR trainer_id = $8)
         RETURNING *`,
        [title, description || null, tags || null, initialFen, pgn || null, steps.length > 0 ? JSON.stringify(steps) : null, req.params.id, req.user.id]
      )
      : await pool.query(
        `UPDATE saved_lessons
         SET title = $1, description = $2, tags = $3, fen = $4, pgn = $5
         WHERE id = $6 AND (user_id = $7 OR trainer_id = $7)
         RETURNING *`,
        [title, description || null, tags || null, initialFen, pgn || null, req.params.id, req.user.id]
      );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to edit it.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Update lesson error:', err);
    res.status(500).json({ error: 'Server error while updating lesson' });
  }
});

// POST /lessons/:id/steps — append one position to an existing course.
//
// The other half of "add to lesson": a trainer looking at a position wants it
// in a lesson without opening the editor and rebuilding the list.
//
// It appends server-side, in one statement, rather than having the client read
// the lesson, push a step and PUT the whole thing back. Two people editing the
// same lesson that way lose one of the edits, and the loser is silent.
router.post('/:id/steps', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Unknown tutorial.' });
  }

  const built = buildLessonStep(req.body?.step);
  if (!built.ok) {
    return res.status(built.status).json({ error: built.error });
  }

  try {
    const result = await pool.query(
      `UPDATE saved_lessons
          SET position_list = position_list || $1::jsonb
        WHERE id = $2
          AND (user_id = $3 OR trainer_id = $3)
          AND position_list IS NOT NULL
        RETURNING id, title, jsonb_array_length(position_list) AS step_count`,
      [JSON.stringify([built.entry]), id, req.user.id]
    );

    if (result.rows.length === 0) {
      // Three different reasons look identical from a failed UPDATE, and the
      // trainer can act on only two of them. Worth one more query to say which.
      const existing = await pool.query(
        `SELECT (user_id = $2 OR trainer_id = $2) AS mine, position_list IS NULL AS bare
           FROM saved_lessons WHERE id = $1`,
        [id, req.user.id]
      );
      if (existing.rows.length === 0 || existing.rows[0].mine !== true) {
        return res.status(404).json({ error: 'Tutorial not found or you do not have permission to edit it.' });
      }
      return res.status(409).json({
        error: 'This is a single position, not a tutorial with steps. Create a tutorial in the editor.',
      });
    }

    res.status(201).json({ success: true, lesson: result.rows[0] });
  } catch (err) {
    logger.error('Append lesson step error:', err);
    res.status(500).json({ error: 'Server error while appending lesson step' });
  }
});

// POST /lessons/:id/clone — save a tutorial as a new version.
//
// Phase 3a of `docs/PLAN-TUTORIJAL.md`. The trainer keeps one tutorial and makes
// an easier or harder version of it for another group, and the original must
// come out untouched — which is the whole reason this is a route and not a
// client that reads, edits and PUTs back.
//
// **Every copied step gets a fresh id.** A step id is the identity of a step
// *in this tutorial*: `stepByKey` resolves a schedule row and a recorded answer
// by it, and two tutorials carrying one id is an ambiguity nobody would find
// until a child's progress showed up in the wrong copy. Stripping the ids and
// running the list back through `buildLessonSteps` mints new ones from the one
// place allowed to build a step, and validates the copy on the way — a stored
// list written before a validation rule existed is refused here rather than
// duplicated.
//
// The copy belongs to whoever asked for it, even when they were the trainer on
// the original rather than its owner: „sačuvaj kao novu verziju" makes *your*
// version.
router.post('/:id/clone', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Unknown tutorial.' });
  }

  const asked = typeof req.body?.title === 'string' ? req.body.title.trim() : '';

  try {
    const found = await pool.query(
      `SELECT title, description, tags, fen, pgn, position_list
         FROM saved_lessons
        WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
      [id, req.user.id]
    );
    if (found.rows.length === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to edit it.' });
    }

    const source = found.rows[0];
    const title = asked !== '' ? asked : copyTitle(source.title);

    let steps = null;
    const stored = Array.isArray(source.position_list) ? source.position_list : [];
    if (stored.length > 0) {
      const stripped = stored.map((step) => {
        const { id: _replaced, ...rest } = step || {};
        return rest;
      });
      const built = buildLessonSteps(stripped);
      if (!built.ok) {
        return res.status(built.status).json({ error: built.error });
      }
      steps = built.entries;
    }

    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list) VALUES ($1, $1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [req.user.id, title, source.description || null, source.tags || null, source.fen, source.pgn || null, steps ? JSON.stringify(steps) : null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Clone lesson error:', err);
    res.status(500).json({ error: 'Server error while cloning lesson' });
  }
});

// DELETE /lessons/:id — delete a lesson you own
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2) RETURNING id',
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to delete it.' });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Delete lesson error:', err);
    res.status(500).json({ error: 'Server error while deleting lesson' });
  }
});

// POST /lessons/:id/export-video
// Renders a saved tutorial as a silent MP4 video with moves, comments, arrows,
// and highlighted squares.
router.post('/:id/export-video', authenticateToken, requireEntitlement(ENT.MP4_EXPORT), async (req, res) => {
  const lessonId = req.params.id;

  try {
    const lessonRes = await pool.query(
      'SELECT id, title FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)',
      [lessonId, req.user.id]
    );
    const lesson = lessonRes.rows[0];
    if (!lesson) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to export it.' });
    }

    const {
      events,
      seconds,
      title,
      resolution,
      pieceStyle,
      boardTheme,
    } = req.body;

    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'events must be a non-empty array.' });
    }
    if (!Number.isInteger(seconds) || seconds <= 0) {
      return res.status(400).json({ error: 'seconds must be a positive integer.' });
    }

    const duration = Math.min(seconds, 3600);

    const filename = `tutorial_${lessonId}_${pieceStyle || 'classic'}_${boardTheme || 'wood'}_${resolution || '720p'}_${Date.now()}.mp4`;
    const exportsDir = path.join(__dirname, '..', 'exports');
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir, { recursive: true });
    }

    const exportPath = path.join(exportsDir, filename);

    await videoRenderer.renderRecordingToMP4({
      title: title || lesson.title || 'Tutorial',
      timelineEvents: events,
      audioFilePath: null,
      durationSeconds: duration,
      perspective: 'trainer',
      resolution: resolution || '720p',
      pieceStyle: pieceStyle || 'classic',
      boardTheme: boardTheme || 'wood',
      showTitle: true,
      showTimer: true,
      showCoords: true,
      showMoveText: false,
      outputPath: exportPath,
    });

    const downloadToken = signDownloadToken(req.user.id, filename);
    const downloadUrl =
      `/recordings/export-download/${encodeURIComponent(filename)}` +
      `?token=${encodeURIComponent(downloadToken)}`;

    await recordUsage(pool, req.user.id, METRIC.MP4_RENDERS, 1);
    await recordUsage(pool, req.user.id, METRIC.MP4_RENDER_SECONDS, duration);

    res.json({
      message: 'Video rendered successfully, saved, and ready for download!',
      jobId: `job_${lessonId}_${Date.now()}`,
      status: 'completed',
      downloadUrl: downloadUrl,
      filename: filename,
    });
  } catch (err) {
    logger.error('Error initiating video export:', err);
    res.status(500).json({ error: 'Error initiating video export.' });
  }
});

// GET /lessons/labels
router.get('/labels', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT DISTINCT unnest(tags) AS label 
       FROM saved_lessons 
       WHERE user_id = $1 
          OR trainer_id = $1 
          OR trainer_id IN (${acceptedTrainersOf('$1')})
       ORDER BY label ASC`,
      [req.user.id]
    );
    const labels = result.rows.map(row => row.label).filter(Boolean);
    res.json(labels);
  } catch (err) {
    logger.error('Fetch labels error:', err);
    res.status(500).json({ error: 'Server error while fetching labels' });
  }
});

// GET /lessons
router.get('/', authenticateToken, async (req, res) => {
  const { search, includeTags, excludeTags, matchMode } = req.query;
  try {
    let query = `
      SELECT id, title, description, tags, fen, pgn, position_list, created_at,
             (trainer_id != $1 AND user_id != $1) AS is_trainer_lesson
      FROM saved_lessons 
      WHERE (user_id = $1 OR trainer_id = $1 OR trainer_id IN (${acceptedTrainersOf('$1')}))
    `;
    const params = [req.user.id];

    if (search && search.trim() !== '') {
      params.push(`%${search.trim()}%`);
      query += ` AND (title ILIKE $${params.length} OR description ILIKE $${params.length} OR fen ILIKE $${params.length})`;
    }

    if (includeTags && includeTags.trim() !== '') {
      const includesArr = includeTags.split(',').map(t => t.trim()).filter(Boolean);
      if (includesArr.length > 0) {
        params.push(includesArr);
        if (matchMode === 'any') {
          query += ` AND tags && $${params.length}::varchar[]`;
        } else {
          query += ` AND tags @> $${params.length}::varchar[]`;
        }
      }
    }

    if (excludeTags && excludeTags.trim() !== '') {
      const excludesArr = excludeTags.split(',').map(t => t.trim()).filter(Boolean);
      if (excludesArr.length > 0) {
        params.push(excludesArr);
        query += ` AND NOT (tags && $${params.length}::varchar[])`;
      }
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    logger.error('Fetch lessons error:', err);
    res.status(500).json({ error: 'Server error while fetching lessons' });
  }
});

module.exports = router;
