// openingExplorer.js — one position of the opening book, for a signed-in user.
//
// The route exists because the token behind it must not travel: it is the
// server's, not the caller's. That also decides the two guards. `authenticateToken`
// keeps the endpoint from becoming an open proxy the moment the backend is
// reachable from the internet — without it, anyone who found the URL would be
// spending our allowance. The limiter is the second half of the same thought:
// a client stuck in a loop must not become a scan of a service someone else
// pays to run.
//
// Guests get no answer here, and that is not a gap. The app falls back to
// ChessDB, which needs no account and is what a guest saw before this route
// existed.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { authenticateToken } = require('../middleware/auth');
const {
  openingExplorer, OpeningExplorerUnavailable,
} = require('../services/openingExplorerService');

// A child clicking through an opening asks once per move, and repeats cost
// nothing because they are served from the cache. This cap is well above that
// and only bites a client that has stopped asking questions and started
// hammering.
const explorerLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 90,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše upita ka bazi otvaranja. Sačekajte trenutak.' },
});

// GET /opening-explorer?fen=...&moves=12&minRating=2000
router.get('/', authenticateToken, explorerLimiter, async (req, res) => {
  const { fen, moves, minRating } = req.query;

  try {
    const result = await openingExplorer.probe(fen, {
      moves: moves ?? 12,
      minRating: minRating ?? null,
    });
    res.json(result);
  } catch (err) {
    // A bad filter or a missing FEN is the caller's mistake and is answered as
    // one; everything else is the upstream being unreachable in one of four
    // distinguishable ways.
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    if (err instanceof OpeningExplorerUnavailable) {
      // Loud on purpose. A refused or spent token looks exactly like an opening
      // nobody has played, and only this line tells them apart afterwards.
      logger.error(`[EXPLORER] ${err.reason}: ${err.message}`);
      return res.status(err.status).json({ error: err.message, reason: err.reason });
    }
    logger.error(`[EXPLORER] Neočekivana greška: ${err.message}`);
    res.status(500).json({ error: 'Greška pri čitanju baze otvaranja.' });
  }
});

module.exports = router;
