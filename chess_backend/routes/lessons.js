const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

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
    console.error('Save lesson error:', err);
    res.status(500).json({ error: 'Server error while saving lesson' });
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
          OR trainer_id IN (SELECT trainer_id FROM trainer_students WHERE student_id = $1) 
       ORDER BY label ASC`,
      [req.user.id]
    );
    const labels = result.rows.map(row => row.label).filter(Boolean);
    res.json(labels);
  } catch (err) {
    console.error('Fetch labels error:', err);
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
      WHERE (user_id = $1 OR trainer_id = $1 OR trainer_id IN (SELECT trainer_id FROM trainer_students WHERE student_id = $1))
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
    console.error('Fetch lessons error:', err);
    res.status(500).json({ error: 'Server error while fetching lessons' });
  }
});

module.exports = router;
