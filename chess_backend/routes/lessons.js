const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { acceptedTrainersOf } = require('../services/relationshipService');
const { buildLessonStep } = require('../services/lessonSteps');

// POST /lessons/save
router.post('/save', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  try {
    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list) VALUES ($1, $1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [req.user.id, title, description || null, tags || null, initialFen, pgn || null, positionList ? JSON.stringify(positionList) : null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Save lesson error:', err);
    res.status(500).json({ error: 'Server error while saving lesson' });
  }
});

// PUT /lessons/:id — update a lesson you own (either creator or the trainer who shared it)
router.put('/:id', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  try {
    const result = await pool.query(
      `UPDATE saved_lessons
       SET title = $1, description = $2, tags = $3, fen = $4, pgn = $5, position_list = $6
       WHERE id = $7 AND (user_id = $8 OR trainer_id = $8)
       RETURNING *`,
      [title, description || null, tags || null, initialFen, pgn || null, positionList ? JSON.stringify(positionList) : null, req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Lekcija nije pronađena ili nemate dozvolu za izmenu.' });
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
    return res.status(400).json({ error: 'Nepoznata lekcija.' });
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
        return res.status(404).json({ error: 'Lekcija nije pronađena ili nemate dozvolu za izmenu.' });
      }
      return res.status(409).json({
        error: 'To je pojedinačna pozicija, ne lekcija sa koracima. Napravite lekciju u editoru.',
      });
    }

    res.status(201).json({ success: true, lesson: result.rows[0] });
  } catch (err) {
    logger.error('Append lesson step error:', err);
    res.status(500).json({ error: 'Server error while appending lesson step' });
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
      return res.status(404).json({ error: 'Lekcija nije pronađena ili nemate dozvolu za brisanje.' });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Delete lesson error:', err);
    res.status(500).json({ error: 'Server error while deleting lesson' });
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
