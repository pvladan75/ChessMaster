// puzzleSets.js — the puzzle sets „Review entire game" extracts, kept with
// the account rather than with the machine.
//
// Mounted at /puzzle-sets.
//
// Reported by the owner, 21.9.2026: the Library showed his sets on Windows
// and nothing at all on the phone, on the same account. It was not a display
// fault — `LocalPuzzleSetStorageService` writes them to `SharedPreferences`
// on the device that ran the extraction, and the server had never heard of
// them. Windows showed his sets because Windows made them.
//
// The puzzles are JSONB rather than a child table, for the reason
// `blunder_games.blunders` already gives: nothing ever queries inside a set.
// A set is at most five puzzles and an account keeps a few dozen, so the
// whole thing is small and is always read whole.
//
// Every query names `req.user.id`. A set id is minted on a device from a
// timestamp and is not a secret, so an id on its own must never reach another
// account's row — the same rule `accountGuard` and `trainerOwnsStudent`
// exist for elsewhere.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

// A device uploads what it already holds the first time it reaches the
// server — up to the thirty a device keeps — and after that writes one set
// per review. The cap is well above both and bites a client repeating itself.
const writeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many puzzle set writes. Please wait a moment.' },
});

/// The shape the app reads, which is `SavedPuzzleSet.fromJson` — the client's
/// own model is the one writer of this format, so the names are its names.
function asJson(row) {
  return {
    id: row.set_id,
    title: row.title,
    createdAt: new Date(row.created_at).toISOString(),
    puzzles: row.puzzles,
  };
}

// GET /puzzle-sets — every set this account keeps, newest first.
router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT set_id, title, puzzles, created_at
         FROM puzzle_sets
        WHERE user_id = $1
        ORDER BY created_at DESC`,
      [req.user.id]
    );
    res.json({ items: result.rows.map(asJson) });
  } catch (err) {
    logger.error('Error listing puzzle sets:', err);
    res.status(500).json({ error: 'Error listing puzzle sets.' });
  }
});

// PUT /puzzle-sets/:setId — create or replace one set.
//
// An upsert rather than a POST, because the id comes from the device that
// made the set: the first time a device reaches the server it uploads
// everything it holds, and that runs again on the next device and on the next
// start. A write that was not idempotent would multiply the owner's sets
// every time.
router.put('/:setId', authenticateToken, writeLimiter, async (req, res) => {
  const setId = String(req.params.setId || '').trim();
  const title = String(req.body?.title || '').trim();
  const puzzles = req.body?.puzzles;

  // Checked before anything is written, so a refusal costs no row. An empty
  // set is the one the app already refuses to open — storing it would spread
  // a card that answers nothing to every device.
  if (!setId || setId.length > 64) {
    return res.status(400).json({ error: 'A set needs an id.' });
  }
  if (!title) {
    return res.status(400).json({ error: 'A set needs a title.' });
  }
  if (!Array.isArray(puzzles) || puzzles.length === 0) {
    return res.status(400).json({ error: 'A set needs at least one puzzle.' });
  }

  // A date the device chose, so a set keeps the day it was made when it
  // travels. Anything unparseable falls back to now rather than refusing:
  // the puzzles are the thing worth keeping.
  const created = new Date(req.body?.createdAt);
  const createdAt = Number.isNaN(created.getTime()) ? new Date() : created;

  try {
    await pool.query(
      `INSERT INTO puzzle_sets (user_id, set_id, title, puzzles, created_at)
            VALUES ($1, $2, $3, $4::jsonb, $5)
       ON CONFLICT (user_id, set_id) DO UPDATE
               SET title = EXCLUDED.title,
                   puzzles = EXCLUDED.puzzles,
                   created_at = EXCLUDED.created_at`,
      [req.user.id, setId, title, JSON.stringify(puzzles), createdAt]
    );
    res.json({ id: setId });
  } catch (err) {
    logger.error('Error saving puzzle set:', err);
    res.status(500).json({ error: 'Error saving puzzle set.' });
  }
});

// DELETE /puzzle-sets/:setId
router.delete('/:setId', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM puzzle_sets
             WHERE user_id = $1 AND set_id = $2
         RETURNING set_id`,
      [req.user.id, String(req.params.setId || '')]
    );
    // Said rather than swallowed: a delete that matched nothing is either an
    // id that never existed or one belonging to somebody else, and answering
    // 200 to both teaches the client that it worked.
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No such puzzle set.' });
    }
    res.json({ id: result.rows[0].set_id });
  } catch (err) {
    logger.error('Error deleting puzzle set:', err);
    res.status(500).json({ error: 'Error deleting puzzle set.' });
  }
});

module.exports = router;
