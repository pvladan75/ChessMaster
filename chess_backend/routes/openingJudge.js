// openingJudge.js — "what is this move: theory, playable, or a mistake?"
//
// Two guards, for two different dangers. `authenticateToken` keeps the route
// from becoming an open proxy the moment this server is reachable from the
// internet. The limiter keeps a client stuck in a loop from turning into a scan
// of a service somebody else runs.
//
// And one rule that is not a guard but a decision: **the Lichess token must be
// the caller's own**, sent in a header on each request. Judging one move costs
// up to four upstream questions, and the server's shared token is a single
// allowance for every child in the app - spending it here would take the
// opening book away from everyone the first time one person walked a long
// variation. Whoever has no token of their own is told so plainly, with the
// place to make one; nobody is served quietly from the shared quota.
//
// The token travels in a header and never in the query string, it is never
// written to the log, and it is not stored anywhere on this server.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { authenticateToken } = require('../middleware/auth');
const { pool } = require('../db');
const {
  openingJudge, OpeningJudgeUnavailable,
} = require('../services/openingJudgeService');
const { rememberReplies } = require('../services/repertoireDrillService');

// Judging is asked for by hand, one move at a time, and repeats come from the
// cache. This cap is far above a person clicking and only bites a loop.
const judgeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 40,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše upita za suđenje poteza. Sačekajte trenutak.' },
});

// GET /opening-judge?fen=...&move=...&minRating=1600
// Header: X-Lichess-Token: <the caller's own token>
router.get('/', authenticateToken, judgeLimiter, async (req, res) => {
  const { fen, move, minRating } = req.query;
  const token = req.get('X-Lichess-Token') || '';

  try {
    const verdict = await openingJudge.judge(fen, move, {
      token,
      minRating: minRating ?? null,
    });
    res.json(verdict);
  } catch (err) {
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    if (err instanceof OpeningJudgeUnavailable) {
      // A missing token is the caller's situation, not a fault of this server,
      // so it is not written to the error log - the other three are, because a
      // refused or spent token is invisible from the app and this line is the
      // only place the difference survives.
      if (err.reason !== 'no-token') {
        logger.error(`[JUDGE] ${err.reason}: ${err.message}`);
      }
      return res.status(err.status).json({ error: err.message, reason: err.reason });
    }
    logger.error(`[JUDGE] Neočekivana greška: ${err.message}`);
    res.status(500).json({ error: 'Greška pri suđenju poteza.' });
  }
});

// GET /opening-judge/replies?fen=...&minRating=1600
// Header: X-Lichess-Token
//
// The other half of the build loop: which of the opponent's answers are worth
// preparing for, and how much is left uncovered. Same route file because it is
// the same token, the same cache and the same queue - splitting it would give
// the pacing rule a second place to be forgotten.
router.get('/replies', authenticateToken, judgeLimiter, async (req, res) => {
  const { fen, minRating } = req.query;
  const token = req.get('X-Lichess-Token') || '';

  try {
    const answer = await openingJudge.replies(fen, {
      token,
      minRating: minRating ?? null,
    });

    // Kept for the drill, which then costs nobody anything. The rows are about
    // a position and a rating band and never about a person, so one student's
    // building makes the next student's drill free too. A failure to store is
    // not a failure to answer: the caller asked what the book says, and it
    // says it whether or not we managed to write it down.
    try {
      await rememberReplies(pool, {
        fen,
        minRating: answer.minRating ?? 0,
        moves: answer.all ?? [],
      });
    } catch (err) {
      logger.error(`[JUDGE] Odgovori nisu sačuvani: ${err.message}`);
    }

    res.json(answer);
  } catch (err) {
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    if (err instanceof OpeningJudgeUnavailable) {
      if (err.reason !== 'no-token') {
        logger.error(`[JUDGE] ${err.reason}: ${err.message}`);
      }
      return res.status(err.status).json({ error: err.message, reason: err.reason });
    }
    logger.error(`[JUDGE] Neočekivana greška: ${err.message}`);
    res.status(500).json({ error: 'Greška pri čitanju odgovora protivnika.' });
  }
});

module.exports = router;
