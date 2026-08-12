const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

// POST /analysis — save the current variation tree
router.post('/', authenticateToken, async (req, res) => {
  const { title, startingFen, tree } = req.body;

  if (!title || !startingFen || !tree) {
    return res.status(400).json({ error: 'title, startingFen i tree su obavezni.' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO saved_analyses (user_id, title, starting_fen, tree_json) VALUES ($1, $2, $3, $4) RETURNING id, title, starting_fen, created_at',
      [req.user.id, title, startingFen, JSON.stringify(tree)]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Save analysis error:', err);
    res.status(500).json({ error: 'Greška na serveru pri čuvanju analize.' });
  }
});

// GET /analysis — list the current user's saved analyses (no tree_json, keeps it light)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, title, starting_fen, created_at FROM saved_analyses WHERE user_id = $1 ORDER BY created_at DESC',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    logger.error('List analyses error:', err);
    res.status(500).json({ error: 'Greška na serveru pri učitavanju liste analiza.' });
  }
});

// GET /analysis/:id — load one saved analysis, including its full tree
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, title, starting_fen, tree_json, created_at FROM saved_analyses WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Analiza nije pronađena.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Load analysis error:', err);
    res.status(500).json({ error: 'Greška na serveru pri učitavanju analize.' });
  }
});

// DELETE /analysis/:id
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM saved_analyses WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Analiza nije pronađena.' });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Delete analysis error:', err);
    res.status(500).json({ error: 'Greška na serveru pri brisanju analize.' });
  }
});

module.exports = router;
