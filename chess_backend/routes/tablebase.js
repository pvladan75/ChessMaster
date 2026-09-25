// tablebase.js — GET /api/tablebase?fen=…
//
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1t: the app's whole-game review
// asks the server for a tablebase answer instead of asking Lichess itself, so
// the phone gets the owner's own tables (five men or fewer) whenever it can
// reach the backend, and Lichess's pacing and permanent cache for the rest —
// `services/tablebaseService.js` is the one place that asks.
//
// The answer is in **the explorer's shape** (`tablebase.lichess.ovh/standard`),
// so the app's `SyzygyResult.fromJson` reads it unchanged. A tablebase that
// cannot be reached is a 503 with its reason, never a guess; the app then says
// the tablebase did not answer, as it always has.

const express = require('express');
const rateLimit = require('express-rate-limit');
const { Chess } = require('chess.js');
const logger = require('../services/logger');
const { authenticateToken } = require('../middleware/auth');
const {
  tablebase: defaultTablebase, pieceCount, TablebaseUnavailable,
} = require('../services/tablebaseService');

/// A review asks about every position with seven men or fewer — phase 0's
/// longest ending had about fifty — so this only bites a client in a loop.
const tablebaseLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many tablebase questions. Please wait a while.' },
});

/// The service's probe, back in the explorer's field names.
function explorerShape(probed) {
  return {
    category: probed.category,
    dtz: probed.dtz,
    checkmate: probed.checkmate,
    stalemate: probed.stalemate,
    insufficient_material: probed.insufficientMaterial,
    moves: probed.moves.map((m) => ({
      uci: m.uci,
      san: m.san,
      category: m.category,
      dtz: m.dtz,
      zeroing: m.zeroing,
      checkmate: m.checkmate,
      stalemate: m.stalemate,
    })),
  };
}

function createTablebaseHandler({ tablebase = defaultTablebase } = {}) {
  return async (req, res) => {
    const fen = typeof req.query.fen === 'string' ? req.query.fen.replace(/_/g, ' ').trim() : '';
    try {
      // eslint-disable-next-line no-new
      new Chess(fen);
    } catch {
      return res.status(400).json({ error: 'The position is not valid.' });
    }
    if (pieceCount(fen) > 7) {
      return res.status(400).json({ error: 'A tablebase answers for seven men or fewer.' });
    }
    try {
      return res.json(explorerShape(await tablebase.probe(fen)));
    } catch (err) {
      if (err instanceof TablebaseUnavailable) {
        return res.status(503).json({ error: err.message, reason: err.reason });
      }
      logger.error(`[TABLEBASE] Neočekivana greška: ${err.message}`);
      return res.status(500).json({ error: 'Error reading the tablebase.' });
    }
  };
}

const router = express.Router();
router.get('/', authenticateToken, tablebaseLimiter, createTablebaseHandler());

module.exports = router;
module.exports.createTablebaseHandler = createTablebaseHandler;
module.exports.explorerShape = explorerShape;
