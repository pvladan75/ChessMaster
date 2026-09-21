const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

// POST /analysis — save the current variation tree
router.post('/', authenticateToken, async (req, res) => {
  const { title, startingFen, tree } = req.body;

  if (!title || !startingFen || !tree) {
    return res.status(400).json({ error: 'title, startingFen and tree are required.' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO saved_analyses (user_id, title, starting_fen, tree_json) VALUES ($1, $2, $3, $4) RETURNING id, title, starting_fen, created_at',
      [req.user.id, title, startingFen, JSON.stringify(tree)]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Save analysis error:', err);
    res.status(500).json({ error: 'Server error saving analysis.' });
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
    res.status(500).json({ error: 'Server error loading analysis list.' });
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
      return res.status(404).json({ error: 'Analysis not found.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Load analysis error:', err);
    res.status(500).json({ error: 'Server error loading analysis.' });
  }
});

// PUT /analysis/:id — write a new tree over one saved analysis.
//
// Added 21.9.2026 for the owner's report on TODO-provera 201.9: saving under a
// name that is already taken made a second, identical-looking row, because
// POST only ever inserts. The app now asks „Replace / Keep both", and this is
// „Replace". Scoped by `user_id` as well as `id`: an analysis id is a small
// integer, and on its own it must never reach another account's row.
router.put('/:id', authenticateToken, async (req, res) => {
  const { title, startingFen, tree } = req.body;

  if (!title || !startingFen || !tree) {
    return res.status(400).json({ error: 'title, startingFen and tree are required.' });
  }

  try {
    const result = await pool.query(
      `UPDATE saved_analyses SET title = $1, starting_fen = $2, tree_json = $3
        WHERE id = $4 AND user_id = $5
        RETURNING id, title, starting_fen, created_at`,
      [title, startingFen, JSON.stringify(tree), req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Analysis not found.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Replace analysis error:', err);
    res.status(500).json({ error: 'Server error replacing analysis.' });
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
      return res.status(404).json({ error: 'Analysis not found.' });
    }
    res.json({ success: true });
  } catch (err) {
    logger.error('Delete analysis error:', err);
    res.status(500).json({ error: 'Server error deleting analysis.' });
  }
});

module.exports = router;
