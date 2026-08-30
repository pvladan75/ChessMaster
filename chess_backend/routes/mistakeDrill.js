// mistakeDrill.js — drilling the mistakes a player actually made.
//
// Mounted at /games/mistakes. Separate from userGames.js because it is a
// different job: that file fills the archive, this one teaches from it.
//
// Every query is scoped to `req.user.id`, and `recordMistakes` re-checks that
// each `game_id` it is handed belongs to the caller. A game id arriving from a
// client is a number somebody could have guessed.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
  GRADES, recordMistakes, dueItems, gradeItem, stats, recurrence,
} = require('../services/mistakeReviews');

// A batch of findings is written after an engine pass over many games, so this
// is not a per-click endpoint. The cap is well above a real batch and bites a
// client that has started repeating itself.
const writeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše upisa grešaka. Sačekajte malo.' },
});

function fail(res, err, whatFailed) {
  if (err instanceof RangeError) return res.status(400).json({ error: err.message });
  if (err instanceof TypeError) return res.status(400).json({ error: err.message });
  logger.error(`[GREŠKE] ${whatFailed}: ${err.message}`);
  return res.status(500).json({ error: whatFailed });
}

// POST /games/mistakes  { items: [ { gameId, ply, fenBefore, playedUci, bestUci?, theme?, swingCp } ] }
//
// Where engine findings come in. The engine pass itself runs on the client —
// a whole archive is roughly 273k positions and an overnight desktop job, which
// is not something a 960 MB droplet should be asked to do.
//
// The answer is a tally, not an "ok": handed in, stored, already known, and
// rejected with reasons. A drill quietly missing the mistakes a player most
// wants to see is the failure this shape exists to prevent.
router.post('/', authenticateToken, writeLimiter, async (req, res) => {
  try {
    return res.json(await recordMistakes(pool, req.user.id, req.body?.items));
  } catch (err) {
    return fail(res, err, 'Greške nisu mogle da se upišu.');
  }
});

// GET /games/mistakes/due?limit=20
router.get('/due', authenticateToken, async (req, res) => {
  const limit = Number(req.query?.limit);
  try {
    return res.json({
      items: await dueItems(pool, req.user.id, {
        limit: Number.isInteger(limit) && limit > 0 ? limit : 20,
      }),
    });
  } catch (err) {
    return fail(res, err, 'Greške za ponavljanje nisu dostupne.');
  }
});

// POST /games/mistakes/:id/grade  { grade: 'again'|'hard'|'good'|'easy' }
//
// Four buttons and not six. Asking a child to distinguish six shades of
// remembering produces noise rather than data — the same reasoning, and the
// same map, as the lesson reviews.
router.post('/:id/grade', authenticateToken, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Loš id.' });

  const asked = req.body?.grade;
  const quality = typeof asked === 'string' ? GRADES[asked] : Number(asked);
  if (quality === undefined) {
    return res.status(400).json({
      error: `Ocena mora biti jedna od: ${Object.keys(GRADES).join(', ')}.`,
    });
  }

  try {
    const outcome = await gradeItem(pool, { userId: req.user.id, itemId: id, quality });
    if (!outcome.ok) return res.status(400).json({ error: outcome.reason });
    return res.json(outcome);
  } catch (err) {
    return fail(res, err, 'Ocena nije mogla da se upiše.');
  }
});

// GET /games/mistakes/stats — totals, split by where the mistake came from.
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    return res.json(await stats(pool, req.user.id));
  } catch (err) {
    return fail(res, err, 'Statistika grešaka nije dostupna.');
  }
});

// GET /games/mistakes/recurrence — what keeps happening.
//
// The difference between a bad evening and a weakness, and the reason this is
// a server query: it ranks over the whole archive, and a client could only ever
// rank what it had already been sent.
router.get('/recurrence', authenticateToken, async (req, res) => {
  try {
    return res.json(await recurrence(pool, req.user.id));
  } catch (err) {
    return fail(res, err, 'Pregled ponavljanja nije dostupan.');
  }
});

module.exports = router;
